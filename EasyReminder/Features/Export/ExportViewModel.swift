import Foundation
import Observation
import EasyReminderKit

@MainActor
@Observable
final class ExportViewModel {
    // 目标：提醒（智能筛选 + 列表）与日历分区显示；targets = 两者拼接，供按 id 查找
    var reminderTargets: [ExportTarget] = []
    var calendarTargets: [ExportTarget] = []
    var targets: [ExportTarget] { reminderTargets + calendarTargets }
    var selectedID: String?

    var items: [ReminderItem] = []
    var eventItems: [EventItem] = []
    var selectedItemIDs: Set<UUID> = []
    var selectedEventIDs: Set<UUID> = []

    // 日历导出的时间范围（EventKit 只能按有界时间段枚举事件）
    var rangeStart: Date
    var rangeEnd: Date

    var status: String = String(localized: "选择要导出的列表")
    var document: ICSDocument?
    var showingExporter = false
    var suggestedName = "reminders"

    private let service: RemindersService
    private let calendarService: CalendarService
    private let exporter = ICSExporter()

    init(service: RemindersService, calendarService: CalendarService) {
        self.service = service
        self.calendarService = calendarService
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        rangeStart = today
        rangeEnd = cal.date(byAdding: .year, value: 1, to: today) ?? today
    }

    var selectedTarget: ExportTarget? { targets.first { $0.id == selectedID } }

    var isCalendarTarget: Bool {
        if case .calendar = selectedTarget?.kind { return true }
        return false
    }

    var allSelected: Bool {
        if isCalendarTarget {
            return !eventItems.isEmpty && selectedEventIDs.count == eventItems.count
        }
        return !items.isEmpty && selectedItemIDs.count == items.count
    }

    var hasNothingToExport: Bool {
        isCalendarTarget ? selectedEventIDs.isEmpty : selectedItemIDs.isEmpty
    }

    func load() async {
        do {
            var t: [ExportTarget] = [
                ExportTarget(id: "smart.all", title: String(localized: "全部（所有列表）"), kind: .all),
                ExportTarget(id: "smart.today", title: String(localized: "今天"), kind: .today),
                ExportTarget(id: "smart.scheduled", title: String(localized: "计划"), kind: .scheduled),
                ExportTarget(id: "smart.completed", title: String(localized: "已完成"), kind: .completed),
            ]
            t.append(contentsOf: try await service.fetchLists())
            reminderTargets = t
        } catch RemindersError.accessDenied {
            reminderTargets = []
            status = String(localized: "提醒事项权限被拒绝")
        } catch {
            reminderTargets = []
            status = String(localized: "加载列表失败：\(error.localizedDescription)")
        }

        // 日历目标读不到（如权限被拒）不阻塞提醒导出，只是不出现日历分区
        if let cals = try? await calendarService.fetchCalendars() {
            calendarTargets = cals.map { info in
                let duplicated = cals.filter { $0.title == info.title }.count > 1
                let title = duplicated && !info.account.isEmpty ? "\(info.title) — \(info.account)" : info.title
                return ExportTarget(id: "cal.\(info.id)", title: title,
                                    kind: .calendar(calendarID: info.id))
            }
        } else {
            calendarTargets = []
        }

        if selectedID == nil { selectedID = targets.first?.id }
        await loadItems()
    }

    /// 选中的目标 / 时间范围变化时重新拉取条目，默认全选。
    func loadItems() async {
        // 快照请求参数：await 期间用户可能切换目标/范围，慢的旧请求回来不许覆盖新结果
        let requestedID = selectedID
        let reqStart = rangeStart, reqEnd = rangeEnd
        let stillCurrent = { [weak self] in
            self.map { $0.selectedID == requestedID && $0.rangeStart == reqStart && $0.rangeEnd == reqEnd } ?? false
        }

        guard let target = targets.first(where: { $0.id == requestedID }) else {
            items = []; eventItems = []; selectedItemIDs = []; selectedEventIDs = []
            return
        }
        if case .calendar(let calendarID) = target.kind {
            // 「到」那天要含在内（用户选 8/31 期望 8/31 的事件也导出）：转成 [当天零点, 次日零点)
            let cal = Calendar.current
            let from = cal.startOfDay(for: reqStart)
            let to = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: reqEnd)) ?? reqEnd
            do {
                let fetched = try await calendarService.fetchEvents(in: calendarID, from: from, to: to)
                guard stillCurrent() else { return }
                eventItems = fetched
                selectedEventIDs = Set(fetched.map(\.id))
                items = []; selectedItemIDs = []
                status = fetched.isEmpty
                    ? String(localized: "「\(target.title)」在所选时间范围内没有事件")
                    : String(localized: "共 \(fetched.count) 个事件，默认全选（重复事件导出为规则）")
            } catch {
                guard stillCurrent() else { return }
                eventItems = []; selectedEventIDs = []
                status = String(localized: "读取事件失败：\(error.localizedDescription)")
            }
        } else {
            do {
                let fetched = try await service.fetchReminders(for: target.kind)
                guard stillCurrent() else { return }
                items = fetched
                selectedItemIDs = Set(fetched.map(\.id))
                eventItems = []; selectedEventIDs = []
                status = fetched.isEmpty
                    ? String(localized: "「\(target.title)」里没有条目")
                    : String(localized: "共 \(fetched.count) 条，默认全选")
            } catch {
                guard stillCurrent() else { return }
                items = []; selectedItemIDs = []
                status = String(localized: "读取条目失败：\(error.localizedDescription)")
            }
        }
    }

    func toggle(_ id: UUID) {
        if isCalendarTarget {
            if selectedEventIDs.contains(id) { selectedEventIDs.remove(id) }
            else { selectedEventIDs.insert(id) }
        } else {
            if selectedItemIDs.contains(id) { selectedItemIDs.remove(id) }
            else { selectedItemIDs.insert(id) }
        }
    }

    func isSelected(_ id: UUID) -> Bool {
        isCalendarTarget ? selectedEventIDs.contains(id) : selectedItemIDs.contains(id)
    }

    func setSelectAll(_ on: Bool) {
        if isCalendarTarget {
            selectedEventIDs = on ? Set(eventItems.map(\.id)) : []
        } else {
            selectedItemIDs = on ? Set(items.map(\.id)) : []
        }
    }

    /// 当前勾选内容的 ICS 文本；没勾选返回 nil（iOS ShareLink 与导出共用）。
    func currentExportText() -> String? {
        if isCalendarTarget {
            let chosen = eventItems.filter { selectedEventIDs.contains($0.id) }
            return chosen.isEmpty ? nil : exporter.export(events: chosen)
        }
        let chosen = items.filter { selectedItemIDs.contains($0.id) }
        return chosen.isEmpty ? nil : exporter.export(chosen)
    }

    func prepareExport() async {
        guard let target = selectedTarget else {
            status = String(localized: "请先选择一个列表"); return
        }
        guard let text = currentExportText() else {
            status = String(localized: "请至少勾选一条要导出的项目"); return
        }
        let count = isCalendarTarget ? selectedEventIDs.count : selectedItemIDs.count
        document = ICSDocument(text: text)
        suggestedName = sanitize(target.title)
        showingExporter = true
        status = String(localized: "已准备好 \(count) 条，请选择保存位置")
    }

    /// iOS 分享用的文件名（含扩展名）。
    var exportFilename: String {
        sanitize(selectedTarget?.title ?? "export") + ".ics"
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
