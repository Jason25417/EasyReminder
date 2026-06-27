import Foundation

/// 重复规则（RRULE 的常用子集）。
struct RecurrenceRule {
    enum Frequency: String {
        case daily = "DAILY"
        case weekly = "WEEKLY"
        case monthly = "MONTHLY"
        case yearly = "YEARLY"
    }
    var frequency: Frequency
    var interval: Int = 1     // 每几个周期
    var count: Int?           // 共重复几次
    var until: Date?          // 重复到某日期为止
}
