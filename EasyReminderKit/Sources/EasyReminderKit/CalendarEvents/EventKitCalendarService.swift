import Foundation
import EventKit

public final class EventKitCalendarService: CalendarService {
    private let store = EKEventStore()

    public init() {}

    public func requestAccess() async throws -> Bool {
        try await store.requestFullAccessToEvents()
    }

    public func importEvents(_ items: [EventItem], into destination: CalendarDestination) async throws -> Int {
        let granted = try await store.requestFullAccessToEvents()
        guard granted else { throw CalendarError.accessDenied }

        let calendar = try resolveCalendar(for: destination)

        var count = 0
        for item in items {
            let event = EKEvent(eventStore: store)
            event.calendar = calendar
            event.title = item.title
            event.notes = item.notes
            event.location = item.location
            event.url = item.url
            event.isAllDay = item.isAllDay
            // TZID 时区：定时事件按源时区落地（重复事件跨夏令时才不会漂移）；全天事件保持浮动
            if !item.isAllDay, let tz = item.timeZone { event.timeZone = tz }

            // 无 DTSTART 的事件极少见：以“现在”兜底，保证可写入。
            let (start, end) = EventKitMapping.dateRange(start: item.startDate,
                                                         end: item.endDate,
                                                         isAllDay: item.isAllDay)
            event.startDate = start
            event.endDate = end

            for alarm in item.alarms { event.addAlarm(EventKitMapping.alarm(alarm)) }
            if let rule = item.recurrence { event.addRecurrenceRule(EventKitMapping.recurrence(rule)) }

            try store.save(event, span: .thisEvent, commit: false)
            count += 1
        }
        try store.commit()
        return count
    }

    public func fetchCalendars() async throws -> [CalendarInfo] {
        let granted = try await store.requestFullAccessToEvents()
        guard granted else { throw CalendarError.accessDenied }
        return store.calendars(for: .event).map {
            CalendarInfo(id: $0.calendarIdentifier,
                         title: $0.title,
                         account: $0.source?.title ?? "",
                         isWritable: $0.allowsContentModifications)
        }
    }

    public func fetchEvents(in calendarID: String?, from: Date, to: Date) async throws -> [EventItem] {
        let granted = try await store.requestFullAccessToEvents()
        guard granted else { throw CalendarError.accessDenied }
        guard from < to else { return [] }

        var calendars: [EKCalendar]?
        if let calendarID {
            let matched = store.calendars(for: .event).filter { $0.calendarIdentifier == calendarID }
            guard !matched.isEmpty else { return [] }
            calendars = matched
        }

        // EventKit 谓词最长 4 年：分窗查询再合并
        var raw: [EKEvent] = []
        var windowStart = from
        let cal = Calendar.current
        while windowStart < to {
            let windowEnd = min(cal.date(byAdding: .year, value: 4, to: windowStart) ?? to, to)
            let predicate = store.predicateForEvents(withStart: windowStart, end: windowEnd, calendars: calendars)
            raw.append(contentsOf: store.events(matching: predicate))
            windowStart = windowEnd
        }

        // 谓词会把重复事件展开成一次次 occurrence：
        // 1) 排除 isDetached（被单次修改过的 occurrence 与主系列同 UID，导出会产生非法的重复 UID）
        // 2) 按条目标识去重
        // 3) 重复系列取回主条目再映射——occurrence 的起始时间配主规则的 COUNT 会多出幻影次数
        var seen = Set<String>()
        return raw
            .filter { !$0.isDetached }
            .sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }
            .filter { seen.insert($0.calendarItemIdentifier).inserted }
            .map { occurrence in
                if occurrence.hasRecurrenceRules,
                   let master = store.calendarItem(withIdentifier: occurrence.calendarItemIdentifier) as? EKEvent {
                    return mapEvent(master)
                }
                return mapEvent(occurrence)
            }
    }

    private func mapEvent(_ e: EKEvent) -> EventItem {
        // 全天：EK 的 endDate 落在最后一天当天；EventItem.endDate 按 RFC 5545 存互斥日（次日零点）
        var end = e.endDate
        if e.isAllDay, let d = end {
            let cal = Calendar.current
            end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: d))
        }
        return EventItem(title: e.title ?? "(无标题)",
                         notes: e.notes,
                         location: e.location,
                         startDate: e.startDate,
                         endDate: end,
                         isAllDay: e.isAllDay,
                         url: e.url,
                         uid: e.calendarItemExternalIdentifier,
                         alarms: (e.alarms ?? []).map(EventKitMapping.alarmModel),
                         recurrence: e.recurrenceRules?.first.map(EventKitMapping.recurrenceModel),
                         timeZone: e.timeZone)
    }

    private func resolveCalendar(for destination: CalendarDestination) throws -> EKCalendar {
        switch destination {
        case .defaultCalendar:
            guard let def = store.defaultCalendarForNewEvents else {
                throw CalendarError.noDefaultCalendar
            }
            return def

        case .existing(let id):
            guard let cal = store.calendars(for: .event)
                .first(where: { $0.calendarIdentifier == id && $0.allowsContentModifications }) else {
                throw CalendarError.calendarNotFound
            }
            return cal

        case .named(let name):
            if let existing = store.calendars(for: .event)
                .first(where: { $0.title == name && $0.allowsContentModifications }) {
                return existing
            }
            return try createCalendar(named: name)
        }
    }

    private func createCalendar(named name: String) throws -> EKCalendar {
        let cal = EKCalendar(for: .event, eventStore: store)
        cal.title = name
        cal.source = store.defaultCalendarForNewEvents?.source
            ?? store.sources.first(where: { $0.sourceType == .local })
            ?? store.sources.first
        guard cal.source != nil else { throw CalendarError.noDefaultCalendar }
        try store.saveCalendar(cal, commit: true)
        return cal
    }
}
