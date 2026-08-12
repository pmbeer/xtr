import AppKit

/// Перевод прямоугольника из координат Cocoa (начало слева внизу основного
/// экрана) в глобальные координаты CG (начало слева вверху) — их ждёт
/// ScreenCaptureKit.
func cocoaRectToCG(_ rect: CGRect) -> CGRect {
    let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
    return CGRect(x: rect.origin.x,
                  y: primaryHeight - rect.maxY,
                  width: rect.width,
                  height: rect.height)
}

private final class SelectionWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

private final class SelectionView: NSView {
    var instruction: String = ""
    var onFinish: ((CGRect?) -> Void)?

    private var startPoint: NSPoint?
    private var currentRect: NSRect = .zero

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentRect = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let point = convert(event.locationInWindow, from: nil)
        currentRect = NSRect(x: min(start.x, point.x),
                             y: min(start.y, point.y),
                             width: abs(point.x - start.x),
                             height: abs(point.y - start.y))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard currentRect.width > 4, currentRect.height > 4, let window else {
            startPoint = nil
            currentRect = .zero
            needsDisplay = true
            return
        }
        let screenRect = window.convertToScreen(currentRect)
        onFinish?(screenRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            onFinish?(nil)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.35).setFill()
        bounds.fill()

        if currentRect.width > 0 {
            NSColor.systemGreen.withAlphaComponent(0.2).setFill()
            currentRect.fill()
            NSColor.systemGreen.setStroke()
            let path = NSBezierPath(rect: currentRect)
            path.lineWidth = 2
            path.stroke()
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let string = NSAttributedString(string: instruction, attributes: attributes)
        let size = string.size()
        string.draw(at: NSPoint(x: (bounds.width - size.width) / 2,
                                y: bounds.height - 140))
    }
}

/// Полноэкранный полупрозрачный слой для выделения области мышью.
@MainActor
final class RegionSelector {
    private var windows: [NSWindow] = []
    private var continuation: CheckedContinuation<CGRect?, Never>?

    /// Возвращает выбранную область в координатах Cocoa или nil при отмене (Esc).
    func select(instruction: String) async -> CGRect? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation

            for screen in NSScreen.screens {
                let window = SelectionWindow(contentRect: screen.frame,
                                             styleMask: .borderless,
                                             backing: .buffered,
                                             defer: false)
                let view = SelectionView(frame: NSRect(origin: .zero, size: screen.frame.size))
                view.instruction = instruction
                view.onFinish = { [weak self] rect in
                    self?.finish(rect)
                }
                window.contentView = view
                window.level = .screenSaver
                window.backgroundColor = .clear
                window.isOpaque = false
                window.setFrame(screen.frame, display: true)
                window.makeKeyAndOrderFront(nil)
                window.makeFirstResponder(view)
                windows.append(window)
            }
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func finish(_ rect: CGRect?) {
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        continuation?.resume(returning: rect)
        continuation = nil
    }
}
