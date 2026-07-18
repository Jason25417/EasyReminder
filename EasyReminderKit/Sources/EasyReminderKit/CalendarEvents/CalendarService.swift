import Foundation

/// 日历事件写入服务（VEVENT → 「日历」App）。
public protocol CalendarService {
    func requestAccess() async throws -> Bool
    /// 把事件写入日历；calendarName 为空用默认日历，否则找/建同名日历。返回成功条数。
    func importEvents(_ items: [EventItem], intoCalendarNamed calendarName: String?) async throws -> Int
    /// 现有可写事件日历名（供导入选择）。
    func fetchCalendars() async throws -> [String]
}

public enum CalendarError: Error {
    case accessDenied         // 用户拒绝日历授权
    case noDefaultCalendar    // 没有可用的默认日历
}
