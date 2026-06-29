import Foundation

/// 导入时从 ICS 解析出来、但 EventKit 写不进「提醒事项」的私有字段（属 Apple 私有 ReminderKit）。
/// 解析照常读出，落地时跳过，并在导入结果里告知用户「已忽略」，不静默丢弃。
public enum IgnoredField: Hashable {
    case subtasks(Int)      // RELATED-TO：子任务 / 层级
    case tags(Int)          // CATEGORIES：标签
    case attachments(Int)   // ATTACH：附件

    /// 给用户看的简短描述，如「3 个子任务」。
    public var label: String {
        switch self {
        case .subtasks(let n):    return "\(n) 个子任务"
        case .tags(let n):        return "\(n) 个标签"
        case .attachments(let n): return "\(n) 个附件"
        }
    }
}
