import AppKit
import SwiftUI

/// Делает окно поверх всех приложений (удобно при ставках).
struct FloatingWindowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(FloatingWindowAccessor())
    }
}

private struct FloatingWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.level = .floating
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                window.isMovableByWindowBackground = true
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.level = .floating
        }
    }
}

extension View {
    func floatingWindow() -> some View {
        modifier(FloatingWindowModifier())
    }
}
