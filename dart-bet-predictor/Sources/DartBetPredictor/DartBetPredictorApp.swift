import SwiftUI

@main
struct DartBetPredictorApp: App {
    @StateObject private var coordinator = MonitorCoordinator()

    var body: some Scene {
        MenuBarExtra("DartBet", systemImage: "target") {
            ControlPanelView()
                .environmentObject(coordinator)
        }
        .menuBarExtraStyle(.window)

        Window("Прогноз ставки", id: "prediction-overlay") {
            PredictionOverlayView()
                .environmentObject(coordinator)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)
    }
}
