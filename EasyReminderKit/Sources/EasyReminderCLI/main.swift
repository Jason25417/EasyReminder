import Foundation
import EasyReminderKit

// EasyReminder 命令行工具：复用 EasyReminderKit 做 .ics ↔ 提醒事项桥接。
//   easyreminder import <file.ics> [列表名]
//   easyreminder export [all|today|scheduled|completed] [输出.ics]
// 注意：访问「提醒事项」需在首次运行时授予权限（TCC）。

func usage() {
    FileHandle.standardError.write(Data("""
    用法:
      easyreminder import <file.ics> [列表名]
      easyreminder export [all|today|scheduled|completed] [输出.ics]

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
        let text = try String(contentsOfFile: path, encoding: .utf8)
        let items = ICSParser().parse(text)
        guard !items.isEmpty else { fail("没解析到任何 VTODO 条目：\(path)") }
        let count = try await EventKitRemindersService().importReminders(items, intoListNamed: listName)
        print("已导入 \(count) 条" + (listName.map { "到列表「\($0)」" } ?? "到默认列表"))

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

    default:
        usage(); exit(1)
    }
} catch {
    fail(error.localizedDescription)
}
