import Foundation
import EventKit
import CoreLocation

public final class EventKitRemindersService: RemindersService {
    private let store = EKEventStore()

    public init() {}

    public func requestAccess() async throws -> Bool {
        try await store.requestFullAccessToReminders()
    }

    public func addTestReminder(title: String) async throws {
        // 1. 申请完全访问权限
        let granted = try await store.requestFullAccessToReminders()
        guard granted else { throw RemindersError.accessDenied }

        // 2. 找一个默认列表来放
        guard let calendar = store.defaultCalendarForNewReminders() else {
            throw RemindersError.noDefaultList
        }

        // 3. 建一条提醒并保存
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = calendar
        try store.save(reminder, commit: true)
    }

    public func importReminders(_ items: [ReminderItem], intoListNamed listName: String?) async throws -> Int {
        let granted = try await store.requestFullAccessToReminders()
        guard granted else { throw RemindersError.accessDenied }

        let calendar = try resolveCalendar(named: listName)

        var count = 0
        for item in items {
            let reminder = EKReminder(eventStore: store)
            reminder.title = item.title
            reminder.notes = item.notes
            reminder.calendar = calendar
            reminder.priority = item.priority
            reminder.isCompleted = item.isCompleted
            reminder.url = item.url
            if let due = item.dueDate { reminder.dueDateComponents = components(from: due) }
            if let start = item.startDate { reminder.startDateComponents = components(from: start) }
            for alarm in item.alarms { reminder.addAlarm(EventKitMapping.alarm(alarm)) }
            if let rule = item.recurrence { reminder.addRecurrenceRule(EventKitMapping.recurrence(rule)) }
            try store.save(reminder, commit: false)
            count += 1
        }
        try store.commit()
        return count
    }

    // 指定列表名就找/建该列表，否则用默认列表
    private func resolveCalendar(named name: String?) throws -> EKCalendar {
        if let name, !name.isEmpty {
            if let existing = store.calendars(for: .reminder).first(where: { $0.title == name }) {
                return existing
            }
            let cal = EKCalendar(for: .reminder, eventStore: store)
            cal.title = name
            cal.source = store.defaultCalendarForNewReminders()?.source
                ?? store.sources.first(where: { $0.sourceType == .local })
                ?? store.sources.first
            guard cal.source != nil else { throw RemindersError.noDefaultList }
            try store.saveCalendar(cal, commit: true)
            return cal
        }
        guard let def = store.defaultCalendarForNewReminders() else {
            throw RemindersError.noDefaultList
        }
        return def
    }

    private func components(from date: Date) -> DateComponents {
        Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    }

    // MARK: - 导出：读取

    public func fetchLists() async throws -> [ExportTarget] {
        let granted = try await store.requestFullAccessToReminders()
        guard granted else { throw RemindersError.accessDenied }
        return store.calendars(for: .reminder).map {
            ExportTarget(id: $0.calendarIdentifier, title: $0.title,
                         kind: .list(calendarID: $0.calendarIdentifier))
        }
    }

    public func fetchReminders(for kind: ExportTarget.Kind) async throws -> [ReminderItem] {
        let granted = try await store.requestFullAccessToReminders()
        guard granted else { throw RemindersError.accessDenied }

        let calendars: [EKCalendar]
        if case .list(let id) = kind {
            calendars = store.calendars(for: .reminder).filter { $0.calendarIdentifier == id }
        } else {
            calendars = store.calendars(for: .reminder)
        }

        let predicate = store.predicateForReminders(in: calendars.isEmpty ? nil : calendars)
        let mapped = await rawReminders(matching: predicate).map(map)

        switch kind {
        case .today:
            let cal = Calendar.current
            return mapped.filter { !$0.isCompleted && ($0.dueDate.map { cal.isDateInToday($0) } ?? false) }
        case .scheduled:
            return mapped.filter { !$0.isCompleted && $0.dueDate != nil }
        case .completed:
            return mapped.filter { $0.isCompleted }
        case .all, .list:
            return mapped
        }
    }

    private func rawReminders(matching predicate: NSPredicate) async -> [EKReminder] {
        await withCheckedContinuation { cont in
            store.fetchReminders(matching: predicate) { cont.resume(returning: $0 ?? []) }
        }
    }

    private func map(_ r: EKReminder) -> ReminderItem {
        let due = r.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
        let start = r.startDateComponents.flatMap { Calendar.current.date(from: $0) }
        let alarms = (r.alarms ?? []).map(mapAlarm)
        let recurrence = r.recurrenceRules?.first.map(mapRecurrence)
        return ReminderItem(
            title: r.title ?? "(无标题)",
            notes: r.notes,
            dueDate: due,
            startDate: start,
            priority: r.priority,
            isCompleted: r.isCompleted,
            url: r.url,
            uid: r.calendarItemExternalIdentifier,
            alarms: alarms,
            recurrence: recurrence
        )
    }

    private func mapAlarm(_ a: EKAlarm) -> ReminderAlarm {
        if let loc = a.structuredLocation, let geo = loc.geoLocation {
            return .location(LocationTrigger(
                title: loc.title ?? "位置",
                latitude: geo.coordinate.latitude,
                longitude: geo.coordinate.longitude,
                radius: loc.radius,
                onArrival: a.proximity != .leave))
        }
        if let date = a.absoluteDate { return .absolute(date) }
        return .relative(a.relativeOffset)
    }

    private func mapRecurrence(_ r: EKRecurrenceRule) -> RecurrenceRule {
        let freq: RecurrenceRule.Frequency
        switch r.frequency {
        case .daily:   freq = .daily
        case .weekly:  freq = .weekly
        case .monthly: freq = .monthly
        case .yearly:  freq = .yearly
        @unknown default: freq = .daily
        }
        var rule = RecurrenceRule(frequency: freq, interval: r.interval)
        if let end = r.recurrenceEnd {
            if end.occurrenceCount > 0 { rule.count = end.occurrenceCount }
            else { rule.until = end.endDate }
        }
        return rule
    }
}
