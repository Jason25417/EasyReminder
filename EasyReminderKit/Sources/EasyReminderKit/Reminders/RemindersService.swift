import Foundation

public protocol RemindersService {
    func requestAccess() async throws -> Bool
    func addTestReminder(title: String) async throws
    /// 把若干条目导入提醒事项；listName 为空则用默认列表，否则找/建同名列表。返回成功条数。
    func importReminders(_ items: [ReminderItem], intoListNamed listName: String?) async throws -> Int
    /// 读取提醒事项里的真实列表（用于导出选择）。
    func fetchLists() async throws -> [ExportTarget]
    /// 按目标读取条目并转成 ReminderItem（供导出）。
    func fetchReminders(for kind: ExportTarget.Kind) async throws -> [ReminderItem]
}

public enum RemindersError: Error {
    case accessDenied      // 用户拒绝授权
    case noDefaultList     // 没有可用的默认提醒列表
}
