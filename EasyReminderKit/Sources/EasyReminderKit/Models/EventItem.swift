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

    public init(title: String,
                notes: String? = nil,
                location: String? = nil,
                startDate: Date? = nil,
                endDate: Date? = nil,
                isAllDay: Bool = false,
                url: URL? = nil,
                uid: String? = nil,
                alarms: [ReminderAlarm] = [],
                recurrence: RecurrenceRule? = nil) {
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
    }
}

/// 一次 ICS 解析的完整结果：待办（VTODO）+ 事件（VEVENT）。
public struct ICSContent {
    public var todos: [ReminderItem]
    public var events: [EventItem]

    public init(todos: [ReminderItem] = [], events: [EventItem] = []) {
        self.todos = todos
        self.events = events
    }

    public var isEmpty: Bool { todos.isEmpty && events.isEmpty }
}
