import Foundation
import EasyReminderKit

// EasyReminder 命令行工具：复用 EasyReminderKit 做 .ics ↔ 提醒事项 / 日历桥接。
//   easyreminder import <file.ics> [列表名] [日历名]
//   easyreminder export [all|today|scheduled|completed] [输出.ics]
//   easyreminder export-events <日历名|all> [输出.ics] [天数=365]
// 注意：访问「提醒事项 / 日历」需在首次运行时授予权限（TCC）。

func usage() {
    FileHandle.standardError.write(Data("""
    用法:
      easyreminder import <file.ics> [列表名] [日历名]
          待办（VTODO）导入提醒事项，事件（VEVENT）导入日历；
          列表名/日历名留空用系统默认。
      easyreminder export [all|today|scheduled|completed] [输出.ics]
      easyreminder export-events <日历名|all> [输出.ics] [天数=365]
          导出从今天起 N 天内的日历事件（重复事件导出为规则）。

    """.utf8))
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("错误：\(message)\n".utf8))
    exit(1)
}

let args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first else { usage(); exit(1) }

do {
    switch command {
    case "import":
        guard args.count >= 2 else { usage(); exit(1) }
        let path = args[1]
        let listName = args.count >= 3 ? args[2] : nil
        let calendarName = args.count >= 4 ? args[3] : nil
        let text = try String(contentsOfFile: path, encoding: .utf8)
        let content = ICSParser().parseContent(text)
        guard !content.isEmpty else {
            // 内容可能全被有意跳过（覆盖块/已取消）——说清原因，别误报「没解析到」
            var msg = "没有可导入的待办或事件：\(path)"
            if content.skippedOverrides > 0 { msg += "\n已跳过 \(content.skippedOverrides) 个对重复条目单次的修改（暂不支持）" }
            if content.skippedCancelled > 0 { msg += "\n已跳过 \(content.skippedCancelled) 个已取消的条目" }
            fail(msg)
        }

        var parts: [String] = []
        if !content.todos.isEmpty {
            let count = try await EventKitRemindersService()
                .importReminders(content.todos, intoListNamed: listName)
            parts.append("\(count) 条待办 → " + (listName.map { "列表「\($0)」" } ?? "默认列表"))
        }
        if !content.events.isEmpty {
            let count = try await EventKitCalendarService()
                .importEvents(content.events, intoCalendarNamed: calendarName)
            parts.append("\(count) 个事件 → " + (calendarName.map { "日历「\($0)」" } ?? "默认日历"))
        }
        print("已导入：" + parts.joined(separator: "；"))
        if content.skippedOverrides > 0 {
            print("已跳过 \(content.skippedOverrides) 个对重复条目单次的修改（暂不支持）")
        }
        if content.skippedCancelled > 0 {
            print("已跳过 \(content.skippedCancelled) 个已取消的条目")
        }

    case "export":
        let scope = args.count >= 2 ? args[1] : "all"
        let kind: ExportTarget.Kind
        switch scope {
        case "today":     kind = .today
        case "scheduled": kind = .scheduled
        case "completed": kind = .completed
        case "all":       kind = .all
        default: fail("未知范围：\(scope)（可选 all/today/scheduled/completed）")
        }
        let items = try await EventKitRemindersService().fetchReminders(for: kind)
        let ics = ICSExporter().export(items)
        if args.count >= 3 {
            try ics.write(toFile: args[2], atomically: true, encoding: .utf8)
            print("已导出 \(items.count) 条到 \(args[2])")
        } else {
            print(ics)
        }

    case "export-events":
        guard args.count >= 2 else { usage(); exit(1) }
        let calendarArg = args[1]
        let days = args.count >= 4 ? (Int(args[3]) ?? 365) : 365
        let service = EventKitCalendarService()

        var calendarID: String?
        if calendarArg != "all" {
            guard let match = try await service.fetchCalendars().first(where: { $0.title == calendarArg }) else {
                fail("找不到日历「\(calendarArg)」")
            }
            calendarID = match.id
        }
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: max(1, days), to: start) ?? start
        let events = try await service.fetchEvents(in: calendarID, from: start, to: end)
        let ics = ICSExporter().export(events: events)
        if args.count >= 3 {
            try ics.write(toFile: args[2], atomically: true, encoding: .utf8)
            print("已导出 \(events.count) 个事件到 \(args[2])")
        } else {
            print(ics)
        }

    default:
        usage(); exit(1)
    }
} catch {
    fail(error.localizedDescription)
}
