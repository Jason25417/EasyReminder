import SwiftUI

@main
struct EasyReminderApp: App {
    private let remindersService: RemindersService = EventKitRemindersService()

    var body: some Scene {
        WindowGroup {
            RootView(importVM: ImportViewModel(service: remindersService),
                     exportVM: ExportViewModel(service: remindersService),
                     updateVM: UpdateViewModel(service: GitHubUpdateService()))
        }
    }
}
