import Foundation
import EventKit
import CoreLocation

/// ReminderAlarm / RecurrenceRule → EventKit 对象的公共映射，
/// 供提醒（EKReminder）与日历事件（EKEvent）两个服务共用。
enum EventKitMapping {

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
        if let c = rule.count { end = EKRecurrenceEnd(occurrenceCount: c) }
        else if let u = rule.until { end = EKRecurrenceEnd(end: u) }
        return EKRecurrenceRule(recurrenceWith: freq, interval: max(1, rule.interval), end: end)
    }
}
