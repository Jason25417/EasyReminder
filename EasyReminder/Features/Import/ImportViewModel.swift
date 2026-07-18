import Foundation
import Observation
import EasyReminderKit

/// 一次导入完成后的摘要（弹窗展示导入了什么）。
struct ImportSummary: Identifiable {
    struct Entry: Identifiable {
        let id = UUID()
        let isEvent: Bool          // true=日历事件 false=待办
        let title: String
        let dateText: String?
        let detail: String?        // 地点 / 提醒 / 重复等
    }
    let id = UUID()
    let headline: String           // "23 条待办 → 列表「课程」；4 个事件 → 日历「学校」"
    let entries: [Entry]
    let ignoredNote: String?
}

@MainActor
@Observable
final class ImportViewModel {

    enum ListChoice: Hashable {
        case defaultList
        case existing(String)   // 现有列表标题
        case newList            // 新建列表（名字见 newListName）
    }

    enum CalendarChoice: Hashable {
        case defaultCalendar
        case existing(String)   // 现有日历标题
        case newCalendar        // 新建日历（名字见 newCalendarName）
    }

    var status: String = String(localized: "请选择一个或多个 .ics 文件导入，或用本 App 打开 .ics 文件")

    // 目的地选择弹框（待办列表 + 事件日历，按内容显示对应区块）
    var availableLists: [ExportTarget] = []
    var listChoice: ListChoice = .defaultList
    var newListName: String = ""
    var availableCalendars: [String] = []
    var calendarChoice: CalendarChoice = .defaultCalendar
    var newCalendarName: String = ""
    var showingListPrompt = false
    var hasPendingTodos = false
    var hasPendingEvents = false

    // 重复导入提示
    var showingDuplicatePrompt = false
    var duplicateCount = 0
    var newCount = 0

    // 导入完成摘要（sheet(item:) 弹出）
    var importSummary: ImportSummary?

    private var pendingContent = ICSContent()
    private var pendingNewContent = ICSContent()
    private var pendingListName: String?
    private var pendingCalendarName: String?

    private let parser = ICSParser()
    private let service: RemindersService
    private let calendarService: CalendarService
    private let importedUIDsKey = "EasyReminder.importedUIDs"

    init(service: RemindersService, calendarService: CalendarService) {
        self.service = service
        self.calendarService = calendarService
    }

    /// Open-With 单个文件的便捷入口。
    func beginImport(at url: URL) async { await beginImport(at: [url]) }

    /// 选好文件（可多选）或被打开后：先解析，再按内容弹目的地选择框。
    func beginImport(at urls: [URL]) async {
        var content = ICSContent()
        do {
            for url in urls {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let text = try String(contentsOf: url, encoding: .utf8)
                let c = parser.parseContent(text)
                content.todos.append(contentsOf: c.todos)
                content.events.append(contentsOf: c.events)
            }
        } catch {
            status = String(localized: "失败：\(error.localizedDescription)")
            return
        }
        guard !content.isEmpty else {
            status = String(localized: "没解析到任何待办或事件（共 \(urls.count) 个文件）")
            return
        }
        pendingContent = content
        hasPendingTodos = !content.todos.isEmpty
        hasPendingEvents = !content.events.isEmpty
        listChoice = .defaultList; newListName = ""
        calendarChoice = .defaultCalendar; newCalendarName = ""
        availableLists = hasPendingTodos ? ((try? await service.fetchLists()) ?? []) : []
        availableCalendars = hasPendingEvents ? ((try? await calendarService.fetchCalendars()) ?? []) : []
        showingListPrompt = true
    }

    /// 选完目的地点"导入"：查重，有重复先弹提示，否则直接导入。
    func confirmImport() async {
        guard !pendingContent.isEmpty else { return }
        showingListPrompt = false

        let listName: String?
        switch listChoice {
        case .defaultList: listName = nil
        case .existing(let title): listName = title
        case .newList:
            let n = newListName.trimmingCharacters(in: .whitespaces)
            listName = n.isEmpty ? nil : n
        }
        let calendarName: String?
        switch calendarChoice {
        case .defaultCalendar: calendarName = nil
        case .existing(let title): calendarName = title
        case .newCalendar:
            let n = newCalendarName.trimmingCharacters(in: .whitespaces)
            calendarName = n.isEmpty ? nil : n
        }

        let content = pendingContent
        pendingContent = ICSContent()

        // 查重（todos + events 共用 UID 记录）
        let known = recordedUIDs()
        let newTodos = content.todos.filter { $0.uid.map { !known.contains($0) } ?? true }
        let newEvents = content.events.filter { $0.uid.map { !known.contains($0) } ?? true }
        let total = content.todos.count + content.events.count
        let fresh = newTodos.count + newEvents.count
        if total == fresh {
            await performImport(content, listName: listName, calendarName: calendarName)
        } else {
            pendingContent = content
            pendingNewContent = ICSContent(todos: newTodos, events: newEvents)
            pendingListName = listName
            pendingCalendarName = calendarName
            duplicateCount = total - fresh
            newCount = fresh
            showingDuplicatePrompt = true
        }
    }

    func cancelImport() {
        showingListPrompt = false
        pendingContent = ICSContent()
    }

    /// 重复提示里的选择：全部 / 只导新的。
    func resolveDuplicate(importAll: Bool) async {
        showingDuplicatePrompt = false
        let content = importAll ? pendingContent : pendingNewContent
        let listName = pendingListName
        let calendarName = pendingCalendarName
        pendingContent = ICSContent(); pendingNewContent = ICSContent()
        await performImport(content, listName: listName, calendarName: calendarName)
    }

    func cancelDuplicate() {
        showingDuplicatePrompt = false
        pendingContent = ICSContent(); pendingNewContent = ICSContent()
        status = String(localized: "已取消导入")
    }

    // MARK: - 内部

    private func performImport(_ content: ICSContent, listName: String?, calendarName: String?) async {
        guard !content.isEmpty else {
            status = String(localized: "没有要导入的条目")
            return
        }
        var lines: [String] = []
        var headParts: [String] = []
        var entries: [ImportSummary.Entry] = []

        // 待办 → 提醒事项
        if !content.todos.isEmpty {
            do {
                let count = try await service.importReminders(content.todos, intoListNamed: listName)
                record(content.todos.compactMap(\.uid))
                let dest = listName.map { String(localized: "列表「\($0)」") } ?? String(localized: "默认列表")
                headParts.append(String(localized: "\(count) 条待办 → \(dest)"))
                entries += content.todos.map(Self.entry(for:))
            } catch RemindersError.accessDenied {
                lines.append(String(localized: "待办失败：提醒事项权限被拒绝"))
            } catch RemindersError.noDefaultList {
                lines.append(String(localized: "待办失败：没有可用的提醒列表，请先在提醒事项里建一个列表"))
            } catch {
                lines.append(String(localized: "待办失败：\(error.localizedDescription)"))
            }
        }

        // 事件 → 日历
        if !content.events.isEmpty {
            do {
                let count = try await calendarService.importEvents(content.events, intoCalendarNamed: calendarName)
                record(content.events.compactMap(\.uid))
                let dest = calendarName.map { String(localized: "日历「\($0)」") } ?? String(localized: "默认日历")
                headParts.append(String(localized: "\(count) 个事件 → \(dest)"))
                entries += content.events.map(Self.entry(for:))
            } catch CalendarError.accessDenied {
                lines.append(String(localized: "事件失败：日历权限被拒绝"))
            } catch CalendarError.noDefaultCalendar {
                lines.append(String(localized: "事件失败：没有可用的日历"))
            } catch {
                lines.append(String(localized: "事件失败：\(error.localizedDescription)"))
            }
        }

        let ignoredNote = Self.ignoredSummary(content.todos)
        if !headParts.isEmpty {
            let headline = headParts.joined(separator: String(localized: "；"))
            lines.insert(String(localized: "成功导入：\(headline)"), at: 0)
            importSummary = ImportSummary(headline: headline, entries: entries, ignoredNote: ignoredNote)
        }
        if let ignoredNote { lines.append(ignoredNote) }
        status = lines.joined(separator: "\n")
    }

    // MARK: - 摘要条目

    private static func entry(for item: ReminderItem) -> ImportSummary.Entry {
        var parts: [String] = []
        if item.isCompleted { parts.append(String(localized: "已完成")) }
        if !item.alarms.isEmpty { parts.append(String(localized: "提醒×\(item.alarms.count)")) }
        if let r = item.recurrence { parts.append(Self.recurrenceText(r)) }
        if item.url != nil { parts.append(String(localized: "网址")) }
        return .init(isEvent: false,
                     title: item.title,
                     dateText: item.dueDate.map(Self.dateText),
                     detail: parts.isEmpty ? nil : parts.joined(separator: " · "))
    }

    private static func entry(for item: EventItem) -> ImportSummary.Entry {
        var parts: [String] = []
        if let loc = item.location, !loc.isEmpty { parts.append(loc) }
        if item.isAllDay { parts.append(String(localized: "全天")) }
        if !item.alarms.isEmpty { parts.append(String(localized: "提醒×\(item.alarms.count)")) }
        if let r = item.recurrence { parts.append(Self.recurrenceText(r)) }
        var dateText: String?
        if let start = item.startDate {
            if item.isAllDay {
                dateText = Self.dayText(start)
            } else if let end = item.endDate {
                dateText = "\(Self.dateText(start)) – \(Self.timeText(end))"
            } else {
                dateText = Self.dateText(start)
            }
        }
        return .init(isEvent: true,
                     title: item.title,
                     dateText: dateText,
                     detail: parts.isEmpty ? nil : parts.joined(separator: " · "))
    }

    private static func recurrenceText(_ r: RecurrenceRule) -> String {
        // 整句本地化（组合式“每 N 单位”在英/西语里没法正确变形）
        switch (r.frequency, r.interval > 1) {
        case (.daily, false):   return String(localized: "每天重复")
        case (.daily, true):    return String(localized: "每 \(r.interval) 天重复")
        case (.weekly, false):  return String(localized: "每周重复")
        case (.weekly, true):   return String(localized: "每 \(r.interval) 周重复")
        case (.monthly, false): return String(localized: "每月重复")
        case (.monthly, true):  return String(localized: "每 \(r.interval) 个月重复")
        case (.yearly, false):  return String(localized: "每年重复")
        case (.yearly, true):   return String(localized: "每 \(r.interval) 年重复")
        }
    }

    private static func dateText(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: d)
    }
    private static func dayText(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none
        return f.string(from: d)
    }
    private static func timeText(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .none; f.timeStyle = .short
        return f.string(from: d)
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
