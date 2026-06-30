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

/// 快捷指令：导入 .ics 到「提醒事项」。
struct ImportICSIntent: AppIntent {
    static var title: LocalizedStringResource = "导入 ICS 到提醒事项"
    static var description = IntentDescription("把 .ics(VTODO) 文件里的待办导入「提醒事项」。")

    @Parameter(title: "ICS 文件")
    var file: IntentFile

    @Parameter(title: "目标列表（留空＝默认列表）")
    var listName: String?

    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let text = String(decoding: file.data, as: UTF8.self)
        let items = ICSParser().parse(text)
        let name = listName?.trimmingCharacters(in: .whitespaces)
        let count = try await EventKitRemindersService()
            .importReminders(items, intoListNamed: (name?.isEmpty == false) ? name : nil)
        return .result(value: count)
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
                              type: UTType("com.apple.ical.ics") ?? .text)
        return .result(value: file)
    }
}

/// 把上面两个意图暴露给「快捷指令」App。
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
    }
}
