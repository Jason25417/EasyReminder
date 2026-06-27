import Foundation
import Observation

@MainActor
@Observable
final class RemindersViewModel {
    var status: String = "未开始"

    private let service: RemindersService

    init(service: RemindersService) {
        self.service = service
    }

    func addTestReminder() async {
        do {
            try await service.addTestReminder(title: "测试提醒 ✅")
            status = "成功：已在提醒事项里建了一条「测试提醒 ✅」"
        } catch RemindersError.accessDenied {
            status = "失败：提醒事项权限被拒绝"
        } catch RemindersError.noDefaultList {
            status = "失败：没有可用的提醒列表（先在提醒事项里建一个列表）"
        } catch {
            status = "失败：\(error.localizedDescription)"
        }
    }
}
