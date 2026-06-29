import Foundation
import Observation
import EasyReminderKit

@MainActor
@Observable
final class ExportViewModel {
    var targets: [ExportTarget] = []
    var selectedID: String?

    var items: [ReminderItem] = []
    var selectedItemIDs: Set<UUID> = []

    var status: String = String(localized: "选择要导出的列表")
    var document: ICSDocument?
    var showingExporter = false
    var suggestedName = "reminders"

    private let service: RemindersService
    private let exporter = ICSExporter()

    init(service: RemindersService) { self.service = service }

    var allSelected: Bool { !items.isEmpty && selectedItemIDs.count == items.count }

    func load() async {
        do {
            var t: [ExportTarget] = [
                ExportTarget(id: "smart.all", title: String(localized: "全部（所有列表）"), kind: .all),
                ExportTarget(id: "smart.today", title: String(localized: "今天"), kind: .today),
                ExportTarget(id: "smart.scheduled", title: String(localized: "计划"), kind: .scheduled),
                ExportTarget(id: "smart.completed", title: String(localized: "已完成"), kind: .completed),
            ]
            t.append(contentsOf: try await service.fetchLists())
            targets = t
            if selectedID == nil { selectedID = t.first?.id }
            await loadItems()
        } catch RemindersError.accessDenied {
            status = String(localized: "提醒事项权限被拒绝")
        } catch {
            status = String(localized: "加载列表失败：\(error.localizedDescription)")
        }
    }

    /// 选中的列表变化时重新拉取条目，默认全选。
    func loadItems() async {
        guard let id = selectedID, let target = targets.first(where: { $0.id == id }) else {
            items = []; selectedItemIDs = []; return
        }
        do {
            let fetched = try await service.fetchReminders(for: target.kind)
            items = fetched
            selectedItemIDs = Set(fetched.map(\.id))
            status = fetched.isEmpty
                ? String(localized: "「\(target.title)」里没有条目")
                : String(localized: "共 \(fetched.count) 条，默认全选")
        } catch {
            items = []; selectedItemIDs = []
            status = String(localized: "读取条目失败：\(error.localizedDescription)")
        }
    }

    func toggle(_ id: UUID) {
        if selectedItemIDs.contains(id) { selectedItemIDs.remove(id) }
        else { selectedItemIDs.insert(id) }
    }

    func setSelectAll(_ on: Bool) {
        selectedItemIDs = on ? Set(items.map(\.id)) : []
    }

    func prepareExport() async {
        guard let id = selectedID, let target = targets.first(where: { $0.id == id }) else {
            status = String(localized: "请先选择一个列表"); return
        }
        let chosen = items.filter { selectedItemIDs.contains($0.id) }
        guard !chosen.isEmpty else {
            status = String(localized: "请至少勾选一条要导出的项目"); return
        }
        document = ICSDocument(text: exporter.export(chosen))
        suggestedName = sanitize(target.title)
        showingExporter = true
        status = String(localized: "已准备好 \(chosen.count) 条，请选择保存位置")
    }

    func exportCompleted(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url): status = String(localized: "已导出到：\(url.lastPathComponent)")
        case .failure(let e):   status = String(localized: "保存失败：\(e.localizedDescription)")
        }
        document = nil
    }

    private func sanitize(_ s: String) -> String {
        s.replacingOccurrences(of: "/", with: "_")
         .replacingOccurrences(of: ":", with: "_")
    }
}
