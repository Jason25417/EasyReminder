import Foundation

/// 重复规则（RRULE 的常用子集）。
public struct RecurrenceRule {
    public enum Frequency: String {
        case daily = "DAILY"
        case weekly = "WEEKLY"
        case monthly = "MONTHLY"
        case yearly = "YEARLY"
    }

    /// BYDAY 的一项。weekday：1=周日 … 7=周六（与 EKWeekday 一致）；
    /// weekNumber：序号（每月第 2 个周二 = 2，倒数第一个周五 = -1；0 = 无序号）。
    public struct Weekday: Hashable {
        public var weekday: Int
        public var weekNumber: Int

        public init(weekday: Int, weekNumber: Int = 0) {
            self.weekday = weekday
            self.weekNumber = weekNumber
        }
    }

    public var frequency: Frequency
    public var interval: Int = 1     // 每几个周期
    public var count: Int?           // 共重复几次
    public var until: Date?          // 重复到某日期为止
    public var daysOfWeek: [Weekday] = []   // BYDAY（空 = 未指定）
    public var daysOfMonth: [Int] = []      // BYMONTHDAY（可为负：倒数）
    public var monthsOfYear: [Int] = []     // BYMONTH（1-12）
    public var setPositions: [Int] = []     // BYSETPOS（如「最后一个工作日」的 -1）

    public init(frequency: Frequency, interval: Int = 1, count: Int? = nil, until: Date? = nil,
                daysOfWeek: [Weekday] = [], daysOfMonth: [Int] = [],
                monthsOfYear: [Int] = [], setPositions: [Int] = []) {
        self.frequency = frequency
        self.interval = interval
        self.count = count
        self.until = until
        self.daysOfWeek = daysOfWeek
        self.daysOfMonth = daysOfMonth
        self.monthsOfYear = monthsOfYear
        self.setPositions = setPositions
    }
}
