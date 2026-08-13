import SwiftUI
import AppKit

struct FloatingOverlayView: View {
    @ObservedObject var pipeline: PipelineCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ТОП-4")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))

            ForEach(pipeline.lastPrediction.items) { item in
                Text("\(item.number)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            if pipeline.lastPrediction.items.isEmpty {
                Text("—")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
            }

            HStack {
                Text("Уверенность:")
                    .foregroundStyle(.white.opacity(0.6))
                Text("\(Int((pipeline.lastPrediction.confidenceScore * 100).rounded()))%")
                    .foregroundStyle(.teal)
                    .font(.body.bold())
            }
            .font(.caption)

            DecisionTimerView(deadline: pipeline.decisionDeadline)
                .font(.caption)
        }
        .padding(14)
        .frame(width: 160)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.teal.opacity(0.45), lineWidth: 1)
                )
        )
    }
}

enum FloatingOverlayController {
    private static var window: NSPanel?
    private static var hosting: NSHostingView<FloatingOverlayView>?

    @MainActor
    static func show(pipeline: PipelineCoordinator) {
        if window != nil {
            window?.orderFrontRegardless()
            return
        }
        let view = FloatingOverlayView(pipeline: pipeline)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 180, height: 260)

        let panel = NSPanel(
            contentRect: NSRect(x: 40, y: 80, width: 180, height: 260),
            styleMask: [.borderless, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.orderFrontRegardless()

        self.window = panel
        self.hosting = hosting
    }

    @MainActor
    static func hide() {
        window?.orderOut(nil)
    }

    @MainActor
    static func setVisible(_ visible: Bool, pipeline: PipelineCoordinator) {
        if visible { show(pipeline: pipeline) } else { hide() }
    }

    /// NSHostingView не всегда подхватывает @Published — обновляем rootView явно.
    @MainActor
    static func refresh(pipeline: PipelineCoordinator) {
        guard window != nil else { return }
        hosting?.rootView = FloatingOverlayView(pipeline: pipeline)
    }
}
