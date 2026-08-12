import AppKit
import SwiftUI

/// Полноэкранный оверлей для выбора области захвата.
struct RegionSelectorView: View {
    var title: String
    let onConfirm: (CGRect) -> Void
    let onCancel: () -> Void

    @State private var startPoint: CGPoint?
    @State private var currentPoint: CGPoint?

    var body: some View {
        ZStack {
            // Затемнение — явно видимое
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            if let rect = selectionRect {
                Rectangle()
                    .path(in: rect)
                    .stroke(Color.orange, lineWidth: 3)

                Rectangle()
                    .path(in: rect)
                    .fill(Color.orange.opacity(0.2))
            }

            VStack(spacing: 12) {
                Text(title)
                    .font(.title3.bold())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThickMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 48)

                Text("Зажмите левую кнопку мыши и выделите область")
                    .font(.subheadline)
                    .foregroundStyle(.white)

                Spacer()

                HStack(spacing: 20) {
                    Button("Отмена") {
                        onCancel()
                    }
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.large)

                    Button("Подтвердить") {
                        if let rect = selectionRect {
                            onConfirm(rect)
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(selectionRect == nil)
                }
                .padding(.bottom, 48)
            }
            .allowsHitTesting(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            // Отдельный слой для drag — не перекрывается кнопками
            Color.clear
                .contentShape(Rectangle())
                .gesture(dragGesture)
        )
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .local)
            .onChanged { value in
                if startPoint == nil {
                    startPoint = value.startLocation
                }
                currentPoint = value.location
            }
            .onEnded { value in
                currentPoint = value.location
            }
    }

    private var selectionRect: CGRect? {
        guard let start = startPoint, let current = currentPoint else { return nil }
        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let w = abs(current.x - start.x)
        let h = abs(current.y - start.y)
        guard w > 15, h > 10 else { return nil }
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

/// NSPanel — может стать key window и получать клики.
private final class RegionSelectorPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Полноэкранный селектор области на экране под курсором.
final class RegionSelectorWindowController: NSWindowController, NSWindowDelegate {
    private static var active: RegionSelectorWindowController?

    private var onSelectCallback: ((ScreenCaptureRegion) -> Void)?
    private var hostingController: NSHostingController<RegionSelectorView>?
    private var targetScreen: NSScreen?
    private var isClosing = false

    /// Открыть селектор (с небольшой задержкой — после закрытия menu bar).
    static func present(
        title: String = "Выделите область",
        onSelect: @escaping (ScreenCaptureRegion) -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            presentImmediately(title: title, onSelect: onSelect)
        }
    }

    private static func presentImmediately(
        title: String,
        onSelect: @escaping (ScreenCaptureRegion) -> Void
    ) {
        if let existing = active {
            existing.cancelSelection()
        }

        guard let screen = screenUnderMouse() else {
            LaunchLogger.log("RegionSelector: no screen found")
            return
        }

        let controller = RegionSelectorWindowController()
        RegionSelectorWindowController.active = controller
        controller.onSelectCallback = onSelect
        controller.targetScreen = screen
        controller.isClosing = false

        let selectorView = RegionSelectorView(
            title: title,
            onConfirm: { rect in controller.confirmSelection(rect) },
            onCancel: { controller.cancelSelection() }
        )

        let hosting = NSHostingController(rootView: selectorView)
        hosting.view.frame = CGRect(origin: .zero, size: screen.frame.size)
        hosting.view.autoresizingMask = [.width, .height]
        controller.hostingController = hosting

        let panel = RegionSelectorPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hosting
        panel.isOpaque = false
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.01)
        panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.delegate = controller
        panel.ignoresMouseEvents = false

        controller.window = panel

        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        LaunchLogger.log("RegionSelector opened on screen \(screen.localizedName): \(screen.frame)")
    }

    private static func screenUnderMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        if let hit = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) {
            return hit
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    private func confirmSelection(_ localRect: CGRect) {
        guard !isClosing, let screen = targetScreen else { return }
        LaunchLogger.log("RegionSelector confirmed: \(localRect) on \(screen.localizedName)")

        let region = ScreenCaptureRegion.from(localRect: localRect, screen: screen)
        let callback = onSelectCallback
        onSelectCallback = nil
        dismissPanel()

        DispatchQueue.main.async {
            callback?(region)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func cancelSelection() {
        LaunchLogger.log("RegionSelector cancelled")
        onSelectCallback = nil
        dismissPanel()
    }

    private func dismissPanel() {
        guard !isClosing else { return }
        isClosing = true

        window?.orderOut(nil)
        window?.contentViewController = nil
        hostingController = nil
        window = nil
        targetScreen = nil

        if RegionSelectorWindowController.active === self {
            RegionSelectorWindowController.active = nil
        }
    }

    func windowWillClose(_ notification: Notification) {
        if !isClosing {
            dismissPanel()
        }
    }
}
