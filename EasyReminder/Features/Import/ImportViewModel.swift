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

    var status: String = "请选择一个或多个 .ics 文件导入，或用本 App 打开 .ics 文件"

    // 列表选择弹框相关
    var availableLists: [ExportTarget] = []
    var listChoice: ListChoice = .defaultList
    var newListName: String = ""
    var showingListPrompt = false
    private var pendingURLs: [URL] = []

    private let parser = ICSParser()
    private let service: RemindersService

    init(service: RemindersService) { self.service = service }

    /// Open-With 单个文件的便捷入口。
    func beginImport(at url: URL) async { await beginImport(at: [url]) }

    /// 选好文件（可多选）或被打开后调用：先读现有列表并弹出选择框，暂不导入。
    func beginImport(at urls: [URL]) async {
        pendingURLs = urls
        listChoice = .defaultList
        newListName = ""
        do { availableLists = try await service.fetchLists() }
        catch { availableLists = [] }
        showingListPrompt = true
    }

    /// 弹框里点"导入"后调用：按选择决定列表名，再真正导入（所有文件并入同一列表）。
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
        await runImport(urls: pendingURLs, listName: listName)
        pendingURLs = []
    }

    func cancelImport() {
        showingListPrompt = false
        pendingURLs = []
    }

    private func runImport(urls: [URL], listName: String?) async {
        do {
            var allItems: [ReminderItem] = []
            for url in urls {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let text = try String(contentsOf: url, encoding: .utf8)
                allItems.append(contentsOf: parser.parse(text))
            }
            guard !allItems.isEmpty else {
                status = "没解析到任何 VTODO 条目（共 \(urls.count) 个文件）"
                return
            }
            let count = try await service.importReminders(allItems, intoListNamed: listName)
            let fileNote = urls.count > 1 ? "（来自 \(urls.count) 个文件）" : ""
            var message = "成功导入 \(count) 条\(fileNote)" + (listName == nil ? "（默认列表）" : "（列表：\(listName!)）")
            if let note = Self.ignoredSummary(allItems) { message += "\n" + note }
            status = message
        } catch RemindersError.accessDenied {
            status = "失败：提醒事项权限被拒绝"
        } catch RemindersError.noDefaultList {
            status = "失败：没有可用的提醒列表，请先在提醒事项里建一个列表"
        } catch {
            status = "失败：\(error.localizedDescription)"
        }
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
        if subtasks > 0    { parts.append("\(subtasks) 个子任务") }
        if tags > 0        { parts.append("\(tags) 个标签") }
        if attachments > 0 { parts.append("\(attachments) 个附件") }
        return "注意：\(affected.count) 条含本 App 写不进的字段（\(parts.joined(separator: "、"))），已忽略"
    }
}
