import SwiftUI
import AppKit

@main
struct DartsForecastApp: App {
    @StateObject private var pipeline = PipelineCoordinator()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Darts Forecast") {
            RootView(pipeline: pipeline)
                .onAppear {
                    appDelegate.pipeline = pipeline
                    FloatingOverlayController.setVisible(
                        pipeline.settings.floatingOverlayVisible && pipeline.settings.onboardingDone,
                        pipeline: pipeline
                    )
                }
                .onChange(of: pipeline.settings.floatingOverlayVisible) { visible in
                    FloatingOverlayController.setVisible(visible && pipeline.settings.onboardingDone, pipeline: pipeline)
                }
                .onChange(of: pipeline.settings.onboardingDone) { done in
                    FloatingOverlayController.setVisible(done && pipeline.settings.floatingOverlayVisible, pipeline: pipeline)
                }
        }
        .defaultSize(width: 820, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Захват") {
                Button("Область результата") { pipeline.selectResultRegion() }
                Button("Область игрока") { pipeline.selectPlayerRegion() }
                Divider()
                Button(pipeline.isRunning ? "Стоп" : "Старт") {
                    pipeline.isRunning ? pipeline.stop() : pipeline.start()
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}

struct RootView: View {
    @ObservedObject var pipeline: PipelineCoordinator

    var body: some View {
        Group {
            if pipeline.settings.onboardingDone {
                MainWindowView(pipeline: pipeline)
            } else {
                OnboardingView(pipeline: pipeline)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var pipeline: PipelineCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DebugLog.info("DartsForecast launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        pipeline?.persist()
        pipeline?.stop()
        DebugLog.info("DartsForecast terminated — state saved")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
