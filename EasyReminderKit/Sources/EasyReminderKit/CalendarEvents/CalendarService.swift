import Foundation

/// 一个事件日历的标识信息（按 id 精确选择，同名日历用 account 区分）。
public struct CalendarInfo: Identifiable, Hashable {
    public let id: String        // calendarIdentifier
    public let title: String
    public let account: String   // 所属账户（EKSource 名，如 iCloud / 本机）
    public let isWritable: Bool

    public init(id: String, title: String, account: String, isWritable: Bool) {
        self.id = id
        self.title = title
        self.account = account
        self.isWritable = isWritable
    }
}

/// 导入事件的目的地。
public enum CalendarDestination: Hashable {
    case defaultCalendar        // 系统默认日历
    case existing(id: String)   // GUI：按标识精确选择（同名日历不混淆）
    case named(String)          // 按名找可写日历，找不到就新建（GUI 新建 / 快捷指令 / CLI 共用，幂等）
}

/// 日历事件服务（VEVENT ↔ 「日历」App）。
public protocol CalendarService {
    func requestAccess() async throws -> Bool
    /// 把事件写入日历。返回成功条数。
    func importEvents(_ items: [EventItem], into destination: CalendarDestination) async throws -> Int
    /// 全部事件日历（含只读——导出场景只读日历完全合法；导入侧自行过滤 isWritable）。
    func fetchCalendars() async throws -> [CalendarInfo]
    /// 读取事件供导出：calendarID 为 nil = 所有日历。重复事件只回主条目（带规则），不展开。
    func fetchEvents(in calendarID: String?, from: Date, to: Date) async throws -> [EventItem]
}

extension CalendarService {
    /// 便捷入口（快捷指令/CLI）：名字为空 = 默认日历，否则按名找/建。
    public func importEvents(_ items: [EventItem], intoCalendarNamed name: String?) async throws -> Int {
        let trimmed = name?.trimmingCharacters(in: .whitespaces)
        if let trimmed, !trimmed.isEmpty {
            return try await importEvents(items, into: .named(trimmed))
        }
        return try await importEvents(items, into: .defaultCalendar)
    }
}

public enum CalendarError: Error {
    case accessDenied         // 用户拒绝日历授权
    case noDefaultCalendar    // 没有可用的默认日历
    case calendarNotFound     // 按 id 指定的日历不存在或不可写
}

extension CalendarError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return String(localized: "日历权限被拒绝", bundle: .module)
        case .noDefaultCalendar:
            return String(localized: "没有可用的日历", bundle: .module)
        case .calendarNotFound:
            return String(localized: "找不到所选日历（可能已被删除）", bundle: .module)
        }
    }
}
