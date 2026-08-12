import AppKit
import SwiftUI

/// Полноэкранный оверлей для выбора области захвата (панель «СЕРИЯ»).
struct RegionSelectorView: View {
    let onSelect: (CGRect) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var startPoint: CGPoint?
    @State private var currentPoint: CGPoint?
    @State private var screenFrame: CGRect = .zero

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
                Text("Выделите область «СЕРИЯ» с номерами бросков")
                    .font(.headline)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 40)

                Spacer()

                HStack(spacing: 16) {
                    Button("Отмена") { dismiss() }
                        .keyboardShortcut(.cancelAction)

                    Button("Подтвердить") {
                        if let rect = selectionRect {
                            onSelect(rect)
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectionRect == nil)
                }
                .padding(.bottom, 40)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 2)
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
        .onAppear {
            if let screen = NSScreen.main {
                screenFrame = screen.frame
            }
        }
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

/// NSWindow wrapper для полноэкранного выбора области поверх всех окон.
final class RegionSelectorWindowController {
    static func present(onSelect: @escaping (CGRect) -> Void) {
        guard let screen = NSScreen.main else { return }

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hosting = NSHostingView(
            rootView: RegionSelectorView { rect in
                window.close()
                onSelect(rect)
            }
        )
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
    }
}
