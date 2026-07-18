import Foundation
import EventKit

public final class EventKitCalendarService: CalendarService {
    private let store = EKEventStore()

    public init() {}

    public func requestAccess() async throws -> Bool {
        try await store.requestFullAccessToEvents()
    }

    public func importEvents(_ items: [EventItem], intoCalendarNamed calendarName: String?) async throws -> Int {
        let granted = try await store.requestFullAccessToEvents()
        guard granted else { throw CalendarError.accessDenied }

        let calendar = try resolveCalendar(named: calendarName)

        var count = 0
        for item in items {
            let event = EKEvent(eventStore: store)
            event.calendar = calendar
            event.title = item.title
            event.notes = item.notes
            event.location = item.location
            event.url = item.url
            event.isAllDay = item.isAllDay

            // 无 DTSTART 的事件极少见：以“现在”兜底，保证可写入。
            let start = item.startDate ?? Date()
            event.startDate = start
            if item.isAllDay {
                // RFC 5545 的 DTEND 是“互斥”日（次日零点）；EventKit 全天事件的
                // endDate 落在最后一天当天即可。单日全天 end=start。
                if let end = item.endDate, end.timeIntervalSince(start) > 86400 {
                    event.endDate = end.addingTimeInterval(-86400)
                } else {
                    event.endDate = start
                }
            } else {
                // 无结束时间按 1 小时兜底
                let end = item.endDate ?? start.addingTimeInterval(3600)
                event.endDate = max(end, start)
            }

            for alarm in item.alarms { event.addAlarm(EventKitMapping.alarm(alarm)) }
            if let rule = item.recurrence { event.addRecurrenceRule(EventKitMapping.recurrence(rule)) }

            try store.save(event, span: .thisEvent, commit: false)
            count += 1
        }
        try store.commit()
        return count
    }

    public func fetchCalendars() async throws -> [String] {
        let granted = try await store.requestFullAccessToEvents()
        guard granted else { throw CalendarError.accessDenied }
        var seen = Set<String>()
        return store.calendars(for: .event)
            .filter { $0.allowsContentModifications }
            .map(\.title)
            .filter { seen.insert($0).inserted }
    }

    // 指定日历名就找/建该日历，否则用默认日历
    private func resolveCalendar(named name: String?) throws -> EKCalendar {
        if let name, !name.isEmpty {
            if let existing = store.calendars(for: .event)
                .first(where: { $0.title == name && $0.allowsContentModifications }) {
                return existing
            }
            let cal = EKCalendar(for: .event, eventStore: store)
            cal.title = name
            cal.source = store.defaultCalendarForNewEvents?.source
                ?? store.sources.first(where: { $0.sourceType == .local })
                ?? store.sources.first
            guard cal.source != nil else { throw CalendarError.noDefaultCalendar }
            try store.saveCalendar(cal, commit: true)
            return cal
        }
        guard let def = store.defaultCalendarForNewEvents else {
            throw CalendarError.noDefaultCalendar
        }
        return def
    }
}
