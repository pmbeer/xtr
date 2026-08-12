import AppKit
import SwiftUI

/// Полноэкранный оверлей для выбора области захвата (без @Environment dismiss).
struct RegionSelectorView: View {
    var title: String = "Выделите область"
    let onConfirm: (CGRect) -> Void
    let onCancel: () -> Void

    @State private var startPoint: CGPoint?
    @State private var currentPoint: CGPoint?

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            if let rect = selectionRect {
                Rectangle()
                    .path(in: rect)
                    .stroke(Color.orange, lineWidth: 2)

                Rectangle()
                    .path(in: rect)
                    .fill(Color.orange.opacity(0.15))
            }

            VStack {
                Text(title)
                    .font(.headline)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 40)

                Text("Зажмите и протяните мышь, затем «Подтвердить»")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 16) {
                    Button("Отмена") {
                        onCancel()
                    }
                    .keyboardShortcut(.cancelAction)

                    Button("Подтвердить") {
                        if let rect = selectionRect {
                            onConfirm(rect)
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectionRect == nil)
                }
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 2, coordinateSpace: .local)
                .onChanged { value in
                    if startPoint == nil {
                        startPoint = value.startLocation
                    }
                    currentPoint = value.location
                }
                .onEnded { value in
                    currentPoint = value.location
                }
        )
    }

    private var selectionRect: CGRect? {
        guard let start = startPoint, let current = currentPoint else { return nil }
        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let w = abs(current.x - start.x)
        let h = abs(current.y - start.y)
        guard w > 20, h > 10 else { return nil }
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

/// Безопасный контроллер окна — удерживает сильную ссылку до полного закрытия.
final class RegionSelectorWindowController: NSWindowController, NSWindowDelegate {
    private static var active: RegionSelectorWindowController?

    private var onSelectCallback: ((CGRect) -> Void)?
    private var hostingController: NSHostingController<RegionSelectorView>?

    static func present(
        title: String = "Выделите область",
        onSelect: @escaping (CGRect) -> Void
    ) {
        // Закрыть предыдущий селектор, если открыт
        active?.closeSelector()

        guard let screen = NSScreen.main else { return }

        let controller = RegionSelectorWindowController()
        RegionSelectorWindowController.active = controller
        controller.onSelectCallback = onSelect

        let contentView = RegionSelectorView(
            title: title,
            onConfirm: { rect in
                controller.confirmSelection(rect)
            },
            onCancel: {
                controller.cancelSelection()
            }
        )

        let hosting = NSHostingController(rootView: contentView)
        controller.hostingController = hosting

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hosting
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = NSColor.black.withAlphaComponent(0.01)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.delegate = controller

        controller.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        LaunchLogger.log("RegionSelector opened: \(title)")
    }

    private func confirmSelection(_ rect: CGRect) {
        LaunchLogger.log("RegionSelector confirmed: \(rect)")
        let callback = onSelectCallback
        onSelectCallback = nil
        closeSelector()

        // Callback после закрытия окна — избегаем краша при dealloc NSHostingView
        DispatchQueue.main.async {
            callback?(rect)
        }
    }

    private func cancelSelection() {
        LaunchLogger.log("RegionSelector cancelled")
        onSelectCallback = nil
        closeSelector()
    }

    private func closeSelector() {
        window?.orderOut(nil)
        window?.contentViewController = nil
        hostingController = nil
        window = nil

        if RegionSelectorWindowController.active === self {
            RegionSelectorWindowController.active = nil
        }
    }

    func windowWillClose(_ notification: Notification) {
        closeSelector()
    }
}
