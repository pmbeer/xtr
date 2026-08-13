import SwiftUI
import AppKit

/// Floating overlay window showing TOP-4 predictions
final class PredictionOverlayController {
    static let shared = PredictionOverlayController()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<OverlayContentView>?

    func show() {
        guard panel == nil else { return }

        let content = OverlayContentView()
        let hosting = NSHostingView(rootView: content)
        hostingView = hosting

        let panel = NSPanel(
            contentRect: NSRect(x: 100, y: 100, width: 180, height: 200),
            styleMask: [.nonactivatingPanel, .titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "DartPredictor"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.contentView = hosting
        panel.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.92)

        self.panel = panel
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
        panel?.contentView = nil
        panel = nil
        hostingView = nil
    }

    func toggle() {
        if panel != nil { hide() } else { show() }
    }
}

struct OverlayContentView: View {
    @ObservedObject var pipeline = PipelineCoordinator.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ТОП-4")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            ForEach(pipeline.currentPrediction.predictions) { pred in
                Text("\(pred.number)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
            }

            Divider()

            Text("Уверенность: \(Int(pipeline.currentPrediction.confidenceScore))%")
                .font(.caption2)

            Text("Таймер: \(String(format: "%.1f", pipeline.decisionTimerRemaining)) сек")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 160)
    }
}

struct PredictionOverlay: View {
    var body: some View {
        EmptyView()
            .onAppear {
                if SettingsManager.shared.settings.showFloatingOverlay {
                    PredictionOverlayController.shared.show()
                }
            }
    }
}
