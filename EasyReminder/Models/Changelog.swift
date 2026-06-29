import Foundation

/// App 基本信息（版本号从工程读取）。
enum AppInfo {
    static var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
    static let author = "Jason Tu"
    static let name = "EasyReminder"
    static var copyright: String { "© 2026 \(author) · \(name)" }
}

struct ChangelogEntry: Identifiable {
    let id = UUID()
    let version: String
    let date: String
    let changes: [String]
}

/// 更新日志：以后每发一版，在最前面加一条。
enum Changelog {
    static let entries: [ChangelogEntry] = [
        ChangelogEntry(version: "1.1", date: "2026-06", changes: [
            "批量导入：可一次选多个 .ics 文件，并入同一列表",
            "导入时提示被忽略的私有字段（子任务 / 标签 / 附件）",
            "新增英文、西班牙语界面",
            "应用内「检查更新…」一键自更新",
            "列表为空时显示占位提示",
        ]),
        ChangelogEntry(version: "1.0", date: "2026-06", changes: [
            "首个版本",
            "导入：读取 .ics 在「提醒事项」中创建条目与列表",
            "支持把 App 设为 .ics 的打开方式，打开即导入",
            "导入字段：标题、备注、截止/开始、优先级、完成态、URL、提醒(定时/地点)、重复",
            "导出：从「提醒事项」导出为 .ics，可选保存位置",
        ]),
    ]
}
