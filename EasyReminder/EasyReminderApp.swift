import SwiftUI
import EasyReminderKit
#if canImport(Sparkle)
import Sparkle
#endif

@main
struct EasyReminderApp: App {
    private let remindersService: RemindersService = EventKitRemindersService()
    private let calendarService: CalendarService = EventKitCalendarService()
    #if canImport(Sparkle)
    private let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    #endif

    var body: some Scene {
        WindowGroup {
            #if canImport(Sparkle)
            RootView(importVM: ImportViewModel(service: remindersService, calendarService: calendarService),
                     exportVM: ExportViewModel(service: remindersService),
                     updater: updaterController.updater)
            #else
            RootView(importVM: ImportViewModel(service: remindersService, calendarService: calendarService),
                     exportVM: ExportViewModel(service: remindersService))
            #endif
        }
        #if canImport(Sparkle)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }
        #endif
    }
}
