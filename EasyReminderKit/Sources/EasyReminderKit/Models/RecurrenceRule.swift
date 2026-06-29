import Foundation

/// 重复规则（RRULE 的常用子集）。
public struct RecurrenceRule {
    public enum Frequency: String {
        case daily = "DAILY"
        case weekly = "WEEKLY"
        case monthly = "MONTHLY"
        case yearly = "YEARLY"
    }
    public var frequency: Frequency
    public var interval: Int = 1     // 每几个周期
    public var count: Int?           // 共重复几次
    public var until: Date?          // 重复到某日期为止

    public init(frequency: Frequency, interval: Int = 1, count: Int? = nil, until: Date? = nil) {
        self.frequency = frequency
        self.interval = interval
        self.count = count
        self.until = until
    }
}
