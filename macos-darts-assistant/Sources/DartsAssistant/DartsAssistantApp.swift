import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApp.windows.forEach { window in
                window.level = .floating
                window.collectionBehavior.insert(.canJoinAllSpaces)
                window.title = "Darts Assistant"
            }
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

@main
struct DartsAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
