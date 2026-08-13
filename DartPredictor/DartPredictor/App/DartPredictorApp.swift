import SwiftUI

@main
struct DartPredictorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 800, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        SettingsManager.shared.load()
        PredictionStore.shared
        DebugLogger.shared.configure(enabled: SettingsManager.shared.settings.debugLoggingEnabled)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        PipelineCoordinator.shared.stop()
        return true
    }
}
