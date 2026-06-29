import Foundation

/// 从 ICS(VTODO) 解析出的一条待办，也是导出时的中间表示。
/// 只含 EventKit 可写入的字段。
public struct ReminderItem: Identifiable {
    public let id = UUID()
    public var title: String
    public var notes: String?
    public var dueDate: Date?
    public var startDate: Date?
    public var priority: Int            // 0 无 / 1-4 高 / 5 中 / 6-9 低
    public var isCompleted: Bool
    public var url: URL?
    public var uid: String?
    public var alarms: [ReminderAlarm]
    public var recurrence: RecurrenceRule?

    public init(title: String,
                notes: String? = nil,
                dueDate: Date? = nil,
                startDate: Date? = nil,
                priority: Int = 0,
                isCompleted: Bool = false,
                url: URL? = nil,
                uid: String? = nil,
                alarms: [ReminderAlarm] = [],
                recurrence: RecurrenceRule? = nil) {
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.startDate = startDate
        self.priority = priority
        self.isCompleted = isCompleted
        self.url = url
        self.uid = uid
        self.alarms = alarms
        self.recurrence = recurrence
    }
}
