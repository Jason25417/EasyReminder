import SwiftUI
import EasyReminderKit
#if canImport(Sparkle)
import Sparkle
#endif
#if os(macOS)
import AppKit

/// 关闭最后一个窗口即退出（工具型 App 不驻留后台）。
final class QuitOnCloseDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
#endif

@main
struct EasyReminderApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(QuitOnCloseDelegate.self) private var quitOnClose
    #endif
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
