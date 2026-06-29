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

    var status: String = "请选择一个 .ics 文件导入，或用本 App 打开 .ics 文件"

    // 列表选择弹框相关
    var availableLists: [ExportTarget] = []
    var listChoice: ListChoice = .defaultList
    var newListName: String = ""
    var showingListPrompt = false
    private var pendingURL: URL?

    private let parser = ICSParser()
    private let service: RemindersService

    init(service: RemindersService) { self.service = service }

    /// 选好文件或被 Open-With 打开后调用：先读现有列表并弹出选择框，暂不导入。
    func beginImport(at url: URL) async {
        pendingURL = url
        listChoice = .defaultList
        newListName = ""
        do { availableLists = try await service.fetchLists() }
        catch { availableLists = [] }
        showingListPrompt = true
    }

    /// 弹框里点“导入”后调用：按选择决定列表名，再真正导入。
    func confirmImport() async {
        guard let url = pendingURL else { return }
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
        await runImport(url: url, listName: listName)
        pendingURL = nil
    }

    func cancelImport() {
        showingListPrompt = false
        pendingURL = nil
    }

    private func runImport(url: URL, listName: String?) async {
        do {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            let text = try String(contentsOf: url, encoding: .utf8)
            let items = parser.parse(text)
            guard !items.isEmpty else {
                status = "没解析到任何 VTODO 条目，请检查文件：\(url.lastPathComponent)"
                return
            }
            let count = try await service.importReminders(items, intoListNamed: listName)
            status = "成功导入 \(count) 条" + (listName == nil ? "（默认列表）" : "（列表：\(listName!)）")
        } catch RemindersError.accessDenied {
            status = "失败：提醒事项权限被拒绝"
        } catch RemindersError.noDefaultList {
            status = "失败：没有可用的提醒列表，请先在提醒事项里建一个列表"
        } catch {
            status = "失败：\(error.localizedDescription)"
        }
    }
}
