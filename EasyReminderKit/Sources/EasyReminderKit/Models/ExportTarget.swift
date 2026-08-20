import Foundation

/// 导出目标：真实列表，或我们用条件重建的智能筛选。
public struct ExportTarget: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let kind: Kind

    public enum Kind: Hashable {
        case list(calendarID: String)     // 真实提醒列表
        case all                          // 全部（所有列表）
        case today                        // 今天到期且未完成
        case scheduled                    // 有到期日且未完成
        case completed                    // 已完成
        case calendar(calendarID: String) // 事件日历（导出 VEVENT，v1.6）
    }

    public init(id: String, title: String, kind: Kind) {
        self.id = id
        self.title = title
        self.kind = kind
    }
}
