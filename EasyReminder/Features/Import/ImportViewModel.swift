import Foundation
import Observation
import EasyReminderKit

/// 一次导入完成后的摘要（弹窗展示导入了什么）。
struct ImportSummary: Identifiable {
    struct DetailRow: Identifiable {
        let id = UUID()
        let label: String
        let value: String
    }
    struct Entry: Identifiable {
        let id = UUID()
        let isEvent: Bool          // true=日历事件 false=待办
        let title: String
        let subtitle: String?      // 列表行第二行（截止/时间段）
        let monthText: String?     // 事件迷你日历块：月
        let dayText: String?       // 事件迷你日历块：日
        let detailRows: [DetailRow]// 点开后的完整字段
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
        case existing(String)   // 现有日历的 calendarIdentifier（同名日历不混淆）
        case newCalendar        // 新建日历（名字见 newCalendarName）
    }

    var status: String = String(localized: "请选择一个或多个 .ics 文件导入，或用本 App 打开 .ics 文件")

    // 目的地选择弹框（待办列表 + 事件日历，按内容显示对应区块）
    var availableLists: [ExportTarget] = []
    var listChoice: ListChoice = .defaultList
    var newListName: String = ""
    var availableCalendars: [CalendarInfo] = []
    var calendarChoice: CalendarChoice = .defaultCalendar
    var newCalendarName: String = ""
    var showingListPrompt = false
    var hasPendingTodos = false
    var hasPendingEvents = false
    // 权限被拒时选择器换成引导文案，而不是渲染一个空列表还让用户白填新建名
    var listAccessDenied = false
    var calendarAccessDenied = false

    // 重复导入提示
    var showingDuplicatePrompt = false
    var duplicateCount = 0
    var newCount = 0

    // 导入完成摘要（sheet(item:) 弹出）
    var importSummary: ImportSummary?

    private var pendingContent = ICSContent()
    private var pendingNewContent = ICSContent()
    private var pendingListName: String?
    private var pendingCalendarDest: CalendarDestination = .defaultCalendar
    private var pendingCalendarTitle: String?

    private let parser = ICSParser()
    private let service: RemindersService
    private let calendarService: CalendarService
    private let ledger = ImportLedger()

    init(service: RemindersService, calendarService: CalendarService) {
        self.service = service
        self.calendarService = calendarService
    }

    /// Open-With 单个文件的便捷入口。
    func beginImport(at url: URL) async { await beginImport(at: [url]) }

    /// 选好文件（可多选）或被打开后：先解析，再按内容弹目的地选择框。
    func beginImport(at urls: [URL]) async {
        var incoming = ICSContent()
        do {
            for url in urls {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                // 协调读取：Files/共享表单给的是就地 URL，iCloud 占位文件要先物化
                let text = try await ICSFileReader.readText(at: url)
                let c = parser.parseContent(text)
                incoming.todos.append(contentsOf: c.todos)
                incoming.events.append(contentsOf: c.events)
                incoming.skippedOverrides += c.skippedOverrides
                incoming.skippedCancelled += c.skippedCancelled
            }
        } catch {
            status = String(localized: "失败：\(error.localizedDescription)")
            return
        }
        guard !incoming.isEmpty else {
            var msg = String(localized: "没解析到任何待办或事件（共 \(urls.count) 个文件）")
            if let skipped = Self.skippedNote(incoming) { msg += "\n" + skipped }
            status = msg
            return
        }

        if showingDuplicatePrompt {
            // 查重弹窗还开着又来新文件：收起弹窗，新旧批次并起来重新走目的地确认
            //（pendingContent 此时还持有上一批完整内容，见 confirmImport 的查重分支）
            showingDuplicatePrompt = false
            pendingNewContent = ICSContent()
            pendingContent.todos.append(contentsOf: incoming.todos)
            pendingContent.events.append(contentsOf: incoming.events)
            pendingContent.skippedOverrides += incoming.skippedOverrides
            pendingContent.skippedCancelled += incoming.skippedCancelled
        } else if showingListPrompt {
            // 目的地弹框还开着又送来新文件（如 Finder 多选逐个送达）：并入，别覆盖
            pendingContent.todos.append(contentsOf: incoming.todos)
            pendingContent.events.append(contentsOf: incoming.events)
            pendingContent.skippedOverrides += incoming.skippedOverrides
            pendingContent.skippedCancelled += incoming.skippedCancelled
        } else {
            pendingContent = incoming
            listChoice = .defaultList; newListName = ""
            calendarChoice = .defaultCalendar; newCalendarName = ""
        }
        hasPendingTodos = !pendingContent.todos.isEmpty
        hasPendingEvents = !pendingContent.events.isEmpty

        listAccessDenied = false
        calendarAccessDenied = false
        if hasPendingTodos {
            do { availableLists = try await service.fetchLists() }
            catch RemindersError.accessDenied { availableLists = []; listAccessDenied = true }
            catch { availableLists = [] }
        } else {
            availableLists = []
        }
        if hasPendingEvents {
            do { availableCalendars = try await calendarService.fetchCalendars().filter(\.isWritable) }
            catch CalendarError.accessDenied { availableCalendars = []; calendarAccessDenied = true }
            catch { availableCalendars = [] }
        } else {
            availableCalendars = []
        }
        showingListPrompt = true
    }

    /// 选完目的地点"导入"：查重，有重复先弹提示，否则直接导入。
    func confirmImport() async {
        // 先收起弹框再检查内容——空内容时留着弹框会变成一个点不动的「导入」死按钮
        showingListPrompt = false
        guard !pendingContent.isEmpty else { return }

        let listName: String?
        switch listChoice {
        case .defaultList: listName = nil
        case .existing(let title): listName = title
        case .newList:
            let n = newListName.trimmingCharacters(in: .whitespaces)
            listName = n.isEmpty ? nil : n
        }
        let calendarDest: CalendarDestination
        let calendarTitle: String?
        switch calendarChoice {
        case .defaultCalendar:
            calendarDest = .defaultCalendar; calendarTitle = nil
        case .existing(let id):
            calendarDest = .existing(id: id)
            calendarTitle = availableCalendars.first { $0.id == id }?.title
        case .newCalendar:
            let n = newCalendarName.trimmingCharacters(in: .whitespaces)
            if n.isEmpty { calendarDest = .defaultCalendar; calendarTitle = nil }
            else { calendarDest = .named(n); calendarTitle = n }
        }

        let content = pendingContent
        pendingContent = ICSContent()

        // 查重（todos + events 共用 UID 记录）
        let known = ledger.recordedUIDs()
        let newTodos = content.todos.filter { $0.uid.map { !known.contains($0) } ?? true }
        let newEvents = content.events.filter { $0.uid.map { !known.contains($0) } ?? true }
        let total = content.todos.count + content.events.count
        let fresh = newTodos.count + newEvents.count
        if total == fresh {
            await performImport(content, listName: listName,
                                calendarDest: calendarDest, calendarTitle: calendarTitle)
        } else {
            pendingContent = content
            pendingNewContent = ICSContent(todos: newTodos, events: newEvents,
                                           skippedOverrides: content.skippedOverrides,
                                           skippedCancelled: content.skippedCancelled)
            pendingListName = listName
            pendingCalendarDest = calendarDest
            pendingCalendarTitle = calendarTitle
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
        let calendarDest = pendingCalendarDest
        let calendarTitle = pendingCalendarTitle
        pendingContent = ICSContent(); pendingNewContent = ICSContent()
        await performImport(content, listName: listName,
                            calendarDest: calendarDest, calendarTitle: calendarTitle)
    }

    func cancelDuplicate() {
        showingDuplicatePrompt = false
        pendingContent = ICSContent(); pendingNewContent = ICSContent()
        status = String(localized: "已取消导入")
    }

    // MARK: - 内部

    private func performImport(_ content: ICSContent, listName: String?,
                               calendarDest: CalendarDestination, calendarTitle: String?) async {
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
                ledger.record(content.todos.compactMap(\.uid))
                let dest = listName.map { String(localized: "列表「\($0)」") } ?? String(localized: "默认列表")
                headParts.append(String(localized: "\(count) 条待办 → \(dest)"))
                entries += content.todos.map { Self.entry(for: $0, destination: dest) }
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
                let count = try await calendarService.importEvents(content.events, into: calendarDest)
                ledger.record(content.events.compactMap(\.uid))
                let dest = calendarTitle.map { String(localized: "日历「\($0)」") } ?? String(localized: "默认日历")
                headParts.append(String(localized: "\(count) 个事件 → \(dest)"))
                entries += content.events.map { Self.entry(for: $0, destination: dest) }
            } catch CalendarError.accessDenied {
                lines.append(String(localized: "事件失败：日历权限被拒绝"))
            } catch CalendarError.noDefaultCalendar {
                lines.append(String(localized: "事件失败：没有可用的日历"))
            } catch {
                lines.append(String(localized: "事件失败：\(error.localizedDescription)"))
            }
        }

        let ignoredNote = Self.ignoredSummary(content)
        if !headParts.isEmpty {
            let headline = headParts.joined(separator: String(localized: "；"))
            lines.insert(String(localized: "成功导入：\(headline)"), at: 0)
            importSummary = ImportSummary(headline: headline, entries: entries, ignoredNote: ignoredNote)
        }
        if let ignoredNote { lines.append(ignoredNote) }
        status = lines.joined(separator: "\n")
    }

    // MARK: - 摘要条目

    private static func entry(for item: ReminderItem, destination: String) -> ImportSummary.Entry {
        var rows: [ImportSummary.DetailRow] = []
        rows.append(.init(label: String(localized: "类型"), value: String(localized: "待办")))
        if let d = item.dueDate { rows.append(.init(label: String(localized: "截止"), value: dateText(d))) }
        if let s = item.startDate { rows.append(.init(label: String(localized: "开始"), value: dateText(s))) }
        if let p = priorityText(item.priority) { rows.append(.init(label: String(localized: "优先级"), value: p)) }
        if item.isCompleted { rows.append(.init(label: String(localized: "状态"), value: String(localized: "已完成"))) }
        if !item.alarms.isEmpty {
            rows.append(.init(label: String(localized: "提醒"),
                              value: item.alarms.map(alarmText).joined(separator: String(localized: "、"))))
        }
        if let r = item.recurrence { rows.append(.init(label: String(localized: "重复"), value: recurrenceText(r))) }
        if let u = item.url { rows.append(.init(label: String(localized: "网址"), value: u.absoluteString)) }
        if let n = item.notes, !n.isEmpty { rows.append(.init(label: String(localized: "备注"), value: n)) }
        rows.append(.init(label: String(localized: "去向"), value: destination))

        return .init(isEvent: false,
                     title: item.title,
                     subtitle: item.dueDate.map { String(localized: "\(dateText($0)) 截止") },
                     monthText: nil, dayText: nil,
                     detailRows: rows)
    }

    private static func entry(for item: EventItem, destination: String) -> ImportSummary.Entry {
        var rows: [ImportSummary.DetailRow] = []
        rows.append(.init(label: String(localized: "类型"),
                          value: item.isAllDay ? String(localized: "日历事件（全天）") : String(localized: "日历事件")))
        var subtitle: String?
        if let start = item.startDate {
            if item.isAllDay {
                rows.append(.init(label: String(localized: "日期"), value: dayText(start)))
                subtitle = String(localized: "全天")
            } else if let end = item.endDate {
                rows.append(.init(label: String(localized: "时间"), value: "\(dateText(start)) – \(timeText(end))"))
                subtitle = "\(timeText(start)) – \(timeText(end))"
            } else {
                rows.append(.init(label: String(localized: "时间"), value: dateText(start)))
                subtitle = timeText(start)
            }
        }
        if let loc = item.location, !loc.isEmpty { rows.append(.init(label: String(localized: "地点"), value: loc)) }
        if !item.alarms.isEmpty {
            rows.append(.init(label: String(localized: "提醒"),
                              value: item.alarms.map(alarmText).joined(separator: String(localized: "、"))))
        }
        if let r = item.recurrence {
            rows.append(.init(label: String(localized: "重复"), value: recurrenceText(r)))
            if let sub = subtitle { subtitle = "\(sub) · \(recurrenceText(r))" }
        }
        if let u = item.url { rows.append(.init(label: String(localized: "网址"), value: u.absoluteString)) }
        if let n = item.notes, !n.isEmpty { rows.append(.init(label: String(localized: "备注"), value: n)) }
        rows.append(.init(label: String(localized: "去向"), value: destination))

        var month: String?, day: String?
        if let start = item.startDate {
            let mf = DateFormatter(); mf.setLocalizedDateFormatFromTemplate("MMM")
            let df = DateFormatter(); df.setLocalizedDateFormatFromTemplate("d")
            month = mf.string(from: start); day = df.string(from: start)
        }
        return .init(isEvent: true,
                     title: item.title,
                     subtitle: subtitle,
                     monthText: month, dayText: day,
                     detailRows: rows)
    }

    private static func alarmText(_ a: ReminderAlarm) -> String {
        switch a {
        case .relative(let off):
            if off == 0 { return String(localized: "准时") }
            let mins = Int(abs(off)) / 60
            let span: String
            if mins >= 1440, mins % 1440 == 0 { span = String(localized: "\(mins / 1440) 天") }
            else if mins >= 60, mins % 60 == 0 { span = String(localized: "\(mins / 60) 小时") }
            else { span = String(localized: "\(mins) 分钟") }
            return off < 0 ? String(localized: "提前 \(span)") : String(localized: "延后 \(span)")
        case .absolute(let d):
            return dateText(d)
        case .location(let loc):
            return loc.onArrival ? String(localized: "到达「\(loc.title)」时") : String(localized: "离开「\(loc.title)」时")
        }
    }

    private static func priorityText(_ p: Int) -> String? {
        switch p {
        case 1...4: return String(localized: "高")
        case 5:     return String(localized: "中")
        case 6...9: return String(localized: "低")
        default:    return nil
        }
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

    /// 汇总被忽略的字段与被跳过的事件，生成给用户的提示；没有则返回 nil。
    private static func ignoredSummary(_ content: ICSContent) -> String? {
        let all = content.todos.map(\.ignoredFields) + content.events.map(\.ignoredFields)
        let affected = all.filter { !$0.isEmpty }.count
        var lines: [String] = []
        if affected > 0 {
            var subtasks = 0, tags = 0, attachments = 0, attendees = 0, exdates = 0
            var badTZIDs: Set<String> = []
            for field in all.joined() {
                switch field {
                case .subtasks(let n):            subtasks += n
                case .tags(let n):                tags += n
                case .attachments(let n):         attachments += n
                case .attendees(let n):           attendees += n
                case .exceptionDates(let n):      exdates += n
                case .unresolvedTimeZone(let tz): badTZIDs.insert(tz)
                }
            }
            var parts: [String] = []
            if subtasks > 0    { parts.append(String(localized: "\(subtasks) 个子任务")) }
            if tags > 0        { parts.append(String(localized: "\(tags) 个标签")) }
            if attachments > 0 { parts.append(String(localized: "\(attachments) 个附件")) }
            if attendees > 0   { parts.append(String(localized: "\(attendees) 个参与者")) }
            if exdates > 0     { parts.append(String(localized: "\(exdates) 个重复例外日")) }
            if !badTZIDs.isEmpty {
                let names = badTZIDs.sorted().joined(separator: String(localized: "、"))
                parts.append(String(localized: "无法识别的时区 \(names)（已按本机时区处理）"))
            }
            let detail = parts.joined(separator: String(localized: "、"))
            lines.append(String(localized: "注意：\(affected) 条含本 App 写不进的字段（\(detail)），已忽略"))
        }
        if let skipped = skippedNote(content) { lines.append(skipped) }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    /// 被整块跳过的事件（重复覆盖块 / 已取消）的说明；没有则返回 nil。
    private static func skippedNote(_ content: ICSContent) -> String? {
        var lines: [String] = []
        if content.skippedOverrides > 0 {
            lines.append(String(localized: "已跳过 \(content.skippedOverrides) 个对重复条目单次的修改（暂不支持，避免生成重复内容）"))
        }
        if content.skippedCancelled > 0 {
            lines.append(String(localized: "已跳过 \(content.skippedCancelled) 个已取消的条目"))
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
}
