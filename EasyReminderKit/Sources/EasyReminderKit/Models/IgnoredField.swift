import Foundation

/// 导入时从 ICS 解析出来、但 EventKit 写不进「提醒事项 / 日历」的字段。
/// 解析照常读出，落地时跳过，并在导入结果里告知用户「已忽略」，不静默丢弃。
public enum IgnoredField: Hashable {
    case subtasks(Int)              // RELATED-TO：子任务 / 层级（提醒私有字段）
    case tags(Int)                  // CATEGORIES：标签
    case attachments(Int)           // ATTACH：附件
    case attendees(Int)             // ATTENDEE/ORGANIZER：参与者（本 App 不写入邀请）
    case exceptionDates(Int)        // EXDATE：重复例外日（暂不支持，会多出这些天的重复）
    case unresolvedTimeZone(String) // 认不出的 TZID（如 Windows 时区名），已按设备时区处理

    /// 给用户看的简短描述，如「3 个子任务」。
    public var label: String {
        switch self {
        case .subtasks(let n):            return "\(n) 个子任务"
        case .tags(let n):                return "\(n) 个标签"
        case .attachments(let n):         return "\(n) 个附件"
        case .attendees(let n):           return "\(n) 个参与者"
        case .exceptionDates(let n):      return "\(n) 个例外日期"
        case .unresolvedTimeZone(let tz): return "无法识别的时区「\(tz)」"
        }
    }
}
