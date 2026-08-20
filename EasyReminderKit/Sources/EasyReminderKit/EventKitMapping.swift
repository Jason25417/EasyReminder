import Foundation
import EventKit
import CoreLocation

/// ReminderAlarm / RecurrenceRule ↔ EventKit 对象的公共映射，
/// 供提醒（EKReminder）与日历事件（EKEvent）两个服务共用。
enum EventKitMapping {

    // MARK: - 模型 → EventKit

    static func alarm(_ alarm: ReminderAlarm) -> EKAlarm {
        switch alarm {
        case .relative(let offset):
            return EKAlarm(relativeOffset: offset)
        case .absolute(let date):
            return EKAlarm(absoluteDate: date)
        case .location(let loc):
            let a = EKAlarm()
            let structured = EKStructuredLocation(title: loc.title)
            structured.geoLocation = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
            structured.radius = loc.radius
            a.structuredLocation = structured
            a.proximity = loc.onArrival ? .enter : .leave
            return a
        }
    }

    static func recurrence(_ rule: RecurrenceRule) -> EKRecurrenceRule {
        let freq: EKRecurrenceFrequency
        switch rule.frequency {
        case .daily:   freq = .daily
        case .weekly:  freq = .weekly
        case .monthly: freq = .monthly
        case .yearly:  freq = .yearly
        }
        var end: EKRecurrenceEnd?
        if let c = rule.count { end = EKRecurrenceEnd(occurrenceCount: max(1, c)) }
        else if let u = rule.until { end = EKRecurrenceEnd(end: u) }

        let hasByParts = !rule.daysOfWeek.isEmpty || !rule.daysOfMonth.isEmpty
            || !rule.monthsOfYear.isEmpty || !rule.setPositions.isEmpty
        guard hasByParts else {
            return EKRecurrenceRule(recurrenceWith: freq, interval: max(1, rule.interval), end: end)
        }

        let days: [EKRecurrenceDayOfWeek]? = rule.daysOfWeek.isEmpty ? nil
            : rule.daysOfWeek.compactMap {
                guard let wd = EKWeekday(rawValue: $0.weekday) else { return nil }
                // EKRecurrenceDayOfWeek.h：weekly 规则的 weekNumber 必须为 0
                let n = (freq == .weekly) ? 0 : $0.weekNumber
                return EKRecurrenceDayOfWeek(wd, weekNumber: n)
            }
        return EKRecurrenceRule(
            recurrenceWith: freq, interval: max(1, rule.interval),
            daysOfTheWeek: days,
            daysOfTheMonth: rule.daysOfMonth.isEmpty ? nil : rule.daysOfMonth.map { NSNumber(value: $0) },
            monthsOfTheYear: rule.monthsOfYear.isEmpty ? nil : rule.monthsOfYear.map { NSNumber(value: $0) },
            weeksOfTheYear: nil, daysOfTheYear: nil,
            setPositions: rule.setPositions.isEmpty ? nil : rule.setPositions.map { NSNumber(value: $0) },
            end: end)
    }

    // MARK: - 起止时间归一化

    /// 把 EventItem 的起止时间归一化成 EKEvent 可写的 (start, end)。
    /// 全天：ICS 的 DTEND 是「互斥」日（次日零点），EK 的 endDate 要落在最后一天当天；
    /// 必须用日历天运算而非固定 86400 秒——跨夏令时切换的那天不是 24 小时。
    /// 定时：无结束按 1 小时兜底；end < start 钳到 start。
    static func dateRange(start: Date?, end: Date?, isAllDay: Bool,
                          calendar: Calendar = .current, now: Date = Date()) -> (start: Date, end: Date) {
        let s = start ?? now
        if isAllDay {
            guard let e = end else { return (s, s) }
            let days = calendar.dateComponents([.day],
                                               from: calendar.startOfDay(for: s),
                                               to: calendar.startOfDay(for: e)).day ?? 0
            if days > 1, let adjusted = calendar.date(byAdding: .day, value: -1, to: e) {
                return (s, adjusted)
            }
            return (s, s)
        }
        let e = end ?? s.addingTimeInterval(3600)
        return (s, max(e, s))
    }

    // MARK: - EventKit → 模型（导出侧）

    static func alarmModel(_ a: EKAlarm) -> ReminderAlarm {
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

    static func recurrenceModel(_ r: EKRecurrenceRule) -> RecurrenceRule {
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
        if let days = r.daysOfTheWeek {
            rule.daysOfWeek = days.map { .init(weekday: $0.dayOfTheWeek.rawValue, weekNumber: $0.weekNumber) }
        }
        if let v = r.daysOfTheMonth   { rule.daysOfMonth = v.map(\.intValue) }
        if let v = r.monthsOfTheYear  { rule.monthsOfYear = v.map(\.intValue) }
        if let v = r.setPositions     { rule.setPositions = v.map(\.intValue) }
        return rule
    }
}
