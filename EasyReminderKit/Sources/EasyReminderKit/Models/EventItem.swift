import Foundation

/// 从 ICS(VEVENT) 解析出的一条日历事件（导入到「日历」App 的中间表示）。
public struct EventItem: Identifiable {
    public let id = UUID()
    public var title: String
    public var notes: String?
    public var location: String?
    public var startDate: Date?
    public var endDate: Date?       // DTEND（全天事件为 RFC 5545 的“互斥”日，写入时由服务端调整）
    public var isAllDay: Bool
    public var url: URL?
    public var uid: String?
    public var alarms: [ReminderAlarm]
    public var recurrence: RecurrenceRule?
    public var timeZone: TimeZone?  // DTSTART 的 TZID（无或识别不了则为 nil，按设备时区处理）
    public var ignoredFields: [IgnoredField] = []  // 解析到但写不进日历的字段

    public init(title: String,
                notes: String? = nil,
                location: String? = nil,
                startDate: Date? = nil,
                endDate: Date? = nil,
                isAllDay: Bool = false,
                url: URL? = nil,
                uid: String? = nil,
                alarms: [ReminderAlarm] = [],
                recurrence: RecurrenceRule? = nil,
                timeZone: TimeZone? = nil) {
        self.title = title
        self.notes = notes
        self.location = location
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.url = url
        self.uid = uid
        self.alarms = alarms
        self.recurrence = recurrence
        self.timeZone = timeZone
    }
}

/// 一次 ICS 解析的完整结果：待办（VTODO）+ 事件（VEVENT）。
public struct ICSContent {
    public var todos: [ReminderItem]
    public var events: [EventItem]
    /// 带 RECURRENCE-ID 的覆盖块（对重复序列中某一次的修改）：导入会变成独立的重复条目，
    /// 因此整块跳过并计数，由 UI 明确告知，而不是静默生成错误数据。
    public var skippedOverrides: Int
    /// STATUS:CANCELLED 的事件：已取消，跳过并计数。
    public var skippedCancelled: Int

    public init(todos: [ReminderItem] = [], events: [EventItem] = [],
                skippedOverrides: Int = 0, skippedCancelled: Int = 0) {
        self.todos = todos
        self.events = events
        self.skippedOverrides = skippedOverrides
        self.skippedCancelled = skippedCancelled
    }

    public var isEmpty: Bool { todos.isEmpty && events.isEmpty }
}
