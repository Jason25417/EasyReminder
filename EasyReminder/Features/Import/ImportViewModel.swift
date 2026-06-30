import Foundation
import Observation
import EasyReminderKit

@MainActor
@Observable
final class ImportViewModel {

    enum ListChoice: Hashable {
        case defaultList
        case existing(String)   // 现有列表标题
        case newList            // 新建列表（名字见 newListName）
    }

    var status: String = String(localized: "请选择一个或多个 .ics 文件导入，或用本 App 打开 .ics 文件")

    // 列表选择弹框
    var availableLists: [ExportTarget] = []
    var listChoice: ListChoice = .defaultList
    var newListName: String = ""
    var showingListPrompt = false

    // 重复导入提示
    var showingDuplicatePrompt = false
    var duplicateCount = 0
    var newCount = 0

    private var pendingURLs: [URL] = []
    private var pendingItems: [ReminderItem] = []
    private var pendingNewItems: [ReminderItem] = []
    private var pendingListName: String?

    private let parser = ICSParser()
    private let service: RemindersService
    private let importedUIDsKey = "EasyReminder.importedUIDs"

    init(service: RemindersService) { self.service = service }

    /// Open-With 单个文件的便捷入口。
    func beginImport(at url: URL) async { await beginImport(at: [url]) }

    /// 选好文件（可多选）或被打开后：读现有列表并弹列表选择框。
    func beginImport(at urls: [URL]) async {
        pendingURLs = urls
        listChoice = .defaultList
        newListName = ""
        do { availableLists = try await service.fetchLists() }
        catch { availableLists = [] }
        showingListPrompt = true
    }

    /// 选完列表点"导入"：解析 + 查重，有重复先弹提示，否则直接导入。
    func confirmImport() async {
        guard !pendingURLs.isEmpty else { return }
        showingListPrompt = false
        let listName: String?
        switch listChoice {
        case .defaultList:
            listName = nil
        case .existing(let title):
            listName = title
        case .newList:
            let n = newListName.trimmingCharacters(in: .whitespaces)
            listName = n.isEmpty ? nil : n
        }
        let urls = pendingURLs
        pendingURLs = []
        await prepare(urls: urls, listName: listName)
    }

    func cancelImport() {
        showingListPrompt = false
        pendingURLs = []
    }

    /// 重复提示里的选择：全部 / 只导新的。
    func resolveDuplicate(importAll: Bool) async {
        showingDuplicatePrompt = false
        let items = importAll ? pendingItems : pendingNewItems
        let listName = pendingListName
        pendingItems = []; pendingNewItems = []
        await performImport(items, listName: listName)
    }

    func cancelDuplicate() {
        showingDuplicatePrompt = false
        pendingItems = []; pendingNewItems = []
        status = String(localized: "已取消导入")
    }

    // MARK: - 内部

    private func prepare(urls: [URL], listName: String?) async {
        var allItems: [ReminderItem] = []
        do {
            for url in urls {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let text = try String(contentsOf: url, encoding: .utf8)
                allItems.append(contentsOf: parser.parse(text))
            }
        } catch {
            status = String(localized: "失败：\(error.localizedDescription)")
            return
        }
        guard !allItems.isEmpty else {
            status = String(localized: "没解析到任何 VTODO 条目（共 \(urls.count) 个文件）")
            return
        }

        let known = recordedUIDs()
        let newItems = allItems.filter { item in
            guard let uid = item.uid else { return true }   // 无 UID 无法判重，当作新条目
            return !known.contains(uid)
        }
        let dupCount = allItems.count - newItems.count
        if dupCount == 0 {
            await performImport(allItems, listName: listName)
        } else {
            pendingItems = allItems
            pendingNewItems = newItems
            pendingListName = listName
            duplicateCount = dupCount
            newCount = newItems.count
            showingDuplicatePrompt = true
        }
    }

    private func performImport(_ items: [ReminderItem], listName: String?) async {
        guard !items.isEmpty else {
            status = String(localized: "没有要导入的条目")
            return
        }
        do {
            let count = try await service.importReminders(items, intoListNamed: listName)
            record(items.compactMap(\.uid))
            var lines: [String] = []
            if let listName {
                lines.append(String(localized: "成功导入 \(count) 条到列表「\(listName)」"))
            } else {
                lines.append(String(localized: "成功导入 \(count) 条到默认列表"))
            }
            if let note = Self.ignoredSummary(items) { lines.append(note) }
            status = lines.joined(separator: "\n")
        } catch RemindersError.accessDenied {
            status = String(localized: "失败：提醒事项权限被拒绝")
        } catch RemindersError.noDefaultList {
            status = String(localized: "失败：没有可用的提醒列表，请先在提醒事项里建一个列表")
        } catch {
            status = String(localized: "失败：\(error.localizedDescription)")
        }
    }

    /// 已导入过的 ICS UID（本地记录，用于判重）。
    private func recordedUIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: importedUIDsKey) ?? [])
    }
    private func record(_ uids: [String]) {
        guard !uids.isEmpty else { return }
        var s = recordedUIDs(); s.formUnion(uids)
        UserDefaults.standard.set(Array(s), forKey: importedUIDsKey)
    }

    /// 汇总被忽略的私有字段，生成给用户的一句提示；没有则返回 nil。
    private static func ignoredSummary(_ items: [ReminderItem]) -> String? {
        let affected = items.filter { !$0.ignoredFields.isEmpty }
        guard !affected.isEmpty else { return nil }
        var subtasks = 0, tags = 0, attachments = 0
        for field in items.flatMap(\.ignoredFields) {
            switch field {
            case .subtasks(let n):    subtasks += n
            case .tags(let n):        tags += n
            case .attachments(let n): attachments += n
            }
        }
        var parts: [String] = []
        if subtasks > 0    { parts.append(String(localized: "\(subtasks) 个子任务")) }
        if tags > 0        { parts.append(String(localized: "\(tags) 个标签")) }
        if attachments > 0 { parts.append(String(localized: "\(attachments) 个附件")) }
        let detail = parts.joined(separator: String(localized: "、"))
        return String(localized: "注意：\(affected.count) 条含本 App 写不进的字段（\(detail)），已忽略")
    }
}
