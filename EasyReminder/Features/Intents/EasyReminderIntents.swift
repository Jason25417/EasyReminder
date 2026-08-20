import AppIntents
import Foundation
import UniformTypeIdentifiers
import EasyReminderKit

/// 导出范围（对应导出页的智能筛选）。
enum ICSExportScope: String, AppEnum {
    case all, today, scheduled, completed

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "导出范围"
    static var caseDisplayRepresentations: [ICSExportScope: DisplayRepresentation] = [
        .all: "全部",
        .today: "今天",
        .scheduled: "计划",
        .completed: "已完成",
    ]

    var kind: ExportTarget.Kind {
        switch self {
        case .all:       return .all
        case .today:     return .today
        case .scheduled: return .scheduled
        case .completed: return .completed
        }
    }
}

private func trimmedOrNil(_ s: String?) -> String? {
    let t = s?.trimmingCharacters(in: .whitespaces)
    return (t?.isEmpty == false) ? t : nil
}

private var icsUTType: UTType { UTType("com.apple.ical.ics") ?? .text }

/// 快捷指令：导入 .ics（待办 → 提醒事项，事件 → 日历）。
struct ImportICSIntent: AppIntent {
    static var title: LocalizedStringResource = "导入 ICS 到提醒事项 / 日历"
    static var description = IntentDescription("把 .ics 文件里的待办（VTODO）导入「提醒事项」，日历事件（VEVENT）导入「日历」。")

    @Parameter(title: "ICS 文件")
    var file: IntentFile

    @Parameter(title: "目标列表（留空＝默认列表）")
    var listName: String?

    @Parameter(title: "目标日历（留空＝默认日历）")
    var calendarName: String?

    @Parameter(title: "跳过已导入过的条目", default: true)
    var skipDuplicates: Bool

    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let text = String(decoding: file.data, as: UTF8.self)
        var content = ICSParser().parseContent(text)

        // 与 App 界面共用同一份 UID 账本：循环自动化不会每天重复建条目
        let ledger = ImportLedger()
        if skipDuplicates {
            let known = ledger.recordedUIDs()
            content.todos = content.todos.filter { $0.uid.map { !known.contains($0) } ?? true }
            content.events = content.events.filter { $0.uid.map { !known.contains($0) } ?? true }
        }

        var total = 0
        if !content.todos.isEmpty {
            total += try await EventKitRemindersService()
                .importReminders(content.todos, intoListNamed: trimmedOrNil(listName))
            ledger.record(content.todos.compactMap(\.uid))
        }
        if !content.events.isEmpty {
            total += try await EventKitCalendarService()
                .importEvents(content.events, intoCalendarNamed: trimmedOrNil(calendarName))
            ledger.record(content.events.compactMap(\.uid))
        }
        return .result(value: total)
    }
}

/// 快捷指令：从「提醒事项」导出为 .ics 文件。
struct ExportICSIntent: AppIntent {
    static var title: LocalizedStringResource = "从提醒事项导出 ICS"
    static var description = IntentDescription("把「提醒事项」里的待办按范围导出为 .ics 文件。")

    @Parameter(title: "范围", default: .all)
    var scope: ICSExportScope

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let items = try await EventKitRemindersService().fetchReminders(for: scope.kind)
        let ics = ICSExporter().export(items)
        let file = IntentFile(data: Data(ics.utf8),
                              filename: "reminders.ics",
                              type: icsUTType)
        return .result(value: file)
    }
}

/// 快捷指令：从「日历」导出为 .ics 文件（v1.6）。
struct ExportCalendarICSIntent: AppIntent {
    static var title: LocalizedStringResource = "从日历导出 ICS"
    static var description = IntentDescription("把「日历」的事件按时间范围导出为 .ics 文件。")

    @Parameter(title: "日历名（留空＝所有日历）")
    var calendarName: String?

    @Parameter(title: "导出未来天数（从今天起）", default: 365)
    var daysAhead: Int

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let service = EventKitCalendarService()
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: max(1, daysAhead), to: start) ?? start

        var calendarID: String?
        if let name = trimmedOrNil(calendarName) {
            guard let match = try await service.fetchCalendars().first(where: { $0.title == name }) else {
                throw CalendarError.calendarNotFound
            }
            calendarID = match.id
        }
        let events = try await service.fetchEvents(in: calendarID, from: start, to: end)
        let ics = ICSExporter().export(events: events)
        let file = IntentFile(data: Data(ics.utf8),
                              filename: "calendar.ics",
                              type: icsUTType)
        return .result(value: file)
    }
}

/// 把意图暴露给「快捷指令」App。
struct EasyReminderShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ImportICSIntent(),
                    phrases: ["用 \(.applicationName) 导入 ICS"],
                    shortTitle: "导入 ICS",
                    systemImageName: "square.and.arrow.down")
        AppShortcut(intent: ExportICSIntent(),
                    phrases: ["用 \(.applicationName) 导出 ICS"],
                    shortTitle: "导出 ICS",
                    systemImageName: "square.and.arrow.up")
        AppShortcut(intent: ExportCalendarICSIntent(),
                    phrases: ["用 \(.applicationName) 导出日历"],
                    shortTitle: "导出日历 ICS",
                    systemImageName: "calendar")
    }
}
