import SwiftUI
import EasyReminderKit
import Sparkle

@main
struct EasyReminderApp: App {
    private let remindersService: RemindersService = EventKitRemindersService()
    private let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    var body: some Scene {
        WindowGroup {
            RootView(importVM: ImportViewModel(service: remindersService),
                     exportVM: ExportViewModel(service: remindersService),
                     updater: updaterController.updater)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }
    }
}
