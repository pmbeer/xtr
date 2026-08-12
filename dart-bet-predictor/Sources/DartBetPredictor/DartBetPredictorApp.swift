import SwiftUI

@main
struct DartBetPredictorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var coordinator = MonitorCoordinator()

    var body: some Scene {
        // Главное окно — открывается при запуске (видно в Dock)
        WindowGroup("Dart Bet Predictor") {
            ControlPanelView()
                .environmentObject(coordinator)
                .frame(minWidth: 400, minHeight: 520)
                .onAppear {
                    LaunchLogger.log("ControlPanelView appeared")
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .defaultSize(width: 420, height: 580)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        MenuBarExtra {
            ControlPanelView()
                .environmentObject(coordinator)
                .frame(minWidth: 400, minHeight: 520)
        } label: {
            MenuBarIconView()
        }
        .menuBarExtraStyle(.window)

        Window("Прогноз ставки", id: "prediction-overlay") {
            PredictionOverlayView()
                .environmentObject(coordinator)
                .onAppear { LaunchLogger.log("PredictionOverlay appeared") }
        }
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)
    }
}
