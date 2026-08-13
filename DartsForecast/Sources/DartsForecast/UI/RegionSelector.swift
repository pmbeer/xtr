import AppKit
import Foundation

// Crash-safe native region selector (pure AppKit, no SwiftUI representable).
// Fixes EXC_BAD_ACCESS seen when selecting the player region on Intel macOS 15.

private final class PassthroughLabel: NSTextField {
    override func hitTest(_ point: CGPoint) -> NSView? { nil }
}

final class NativeRegionSelectorView: NSView {
    var titleText: String = "Выделите область" {
        didSet { titleLabel?.stringValue = titleText }
    }
    var onConfirm: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var isTracking = false

    private let headerHeight: CGFloat = 88
    private let buttonBarHeight: CGFloat = 96
    private var confirmButton: NSButton?
    private var cancelButton: NSButton?
    private var titleLabel: NSTextField?
    private var hintLabel: NSTextField?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    deinit {
        onConfirm = nil
        onCancel = nil
    }

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.42).cgColor

        let title = PassthroughLabel(labelWithString: titleText)
        title.font = .boldSystemFont(ofSize: 20)
        title.alignment = .center
        title.textColor = .white
        title.backgroundColor = .clear
        title.isBezeled = false
        title.isEditable = false
        addSubview(title)
        titleLabel = title

        let hint = PassthroughLabel(labelWithString: "Зажмите ЛКМ и выделите область. Esc — отмена.")
        hint.font = .systemFont(ofSize: 14)
        hint.alignment = .center
        hint.textColor = NSColor.white.withAlphaComponent(0.85)
        hint.backgroundColor = .clear
        hint.isBezeled = false
        hint.isEditable = false
        addSubview(hint)
        hintLabel = hint

        let cancel = NSButton(title: "Отмена", target: self, action: #selector(cancelTapped))
        cancel.bezelStyle = .rounded
        addSubview(cancel)
        cancelButton = cancel

        let confirm = NSButton(title: "Подтвердить", target: self, action: #selector(confirmTapped))
        confirm.bezelStyle = .rounded
        confirm.keyEquivalent = "\r"
        addSubview(confirm)
        confirmButton = confirm
        updateButtonState()
    }

    override func layout() {
        super.layout()
        let w = bounds.width
        let h = bounds.height
        titleLabel?.frame = CGRect(x: 20, y: 24, width: w - 40, height: 30)
        hintLabel?.frame = CGRect(x: 20, y: 54, width: w - 40, height: 22)
        let btnW: CGFloat = 140
        let btnH: CGFloat = 36
        let btnY = h - buttonBarHeight + 28
        cancelButton?.frame = CGRect(x: w / 2 - btnW - 12, y: btnY, width: btnW, height: btnH)
        confirmButton?.frame = CGRect(x: w / 2 + 12, y: btnY, width: btnW, height: btnH)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let rect = selectionRect else { return }
        NSColor.systemTeal.withAlphaComponent(0.28).setFill()
        rect.fill()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 3
        NSColor.systemTeal.setStroke()
        path.stroke()

        let sizeText = String(format: "%.0f × %.0f", rect.width, rect.height)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 13),
            .foregroundColor: NSColor.white
        ]
        let textSize = (sizeText as NSString).size(withAttributes: attrs)
        (sizeText as NSString).draw(
            at: CGPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2),
            withAttributes: attrs
        )
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard !isTracking else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard isInDragZone(point) else { return }

        startPoint = point
        currentPoint = point
        isTracking = true
        needsDisplay = true

        weak var weakSelf = self
        window?.trackEvents(
            matching: [.leftMouseDragged, .leftMouseUp],
            timeout: .greatestFiniteMagnitude,
            mode: .eventTracking
        ) { event, stop in
            guard let self = weakSelf, let event else {
                stop.pointee = true
                return
            }
            switch event.type {
            case .leftMouseDragged:
                self.currentPoint = self.convert(event.locationInWindow, from: nil)
                self.needsDisplay = true
                self.updateButtonState()
            case .leftMouseUp:
                self.currentPoint = self.convert(event.locationInWindow, from: nil)
                self.isTracking = false
                self.needsDisplay = true
                self.updateButtonState()
                stop.pointee = true
            default:
                break
            }
        }
        isTracking = false
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            cancelTapped()
            return
        }
        super.keyDown(with: event)
    }

    @objc private func confirmTapped() {
        guard !isTracking, let rect = selectionRect else { return }
        let cb = onConfirm
        onConfirm = nil
        onCancel = nil
        cb?(rect)
    }

    @objc private func cancelTapped() {
        guard !isTracking else { return }
        let cb = onCancel
        onConfirm = nil
        onCancel = nil
        cb?()
    }

    private func updateButtonState() {
        confirmButton?.isEnabled = selectionRect != nil && !isTracking
    }

    private func isInDragZone(_ point: CGPoint) -> Bool {
        point.y >= headerHeight && point.y <= bounds.height - buttonBarHeight
    }

    private var selectionRect: CGRect? {
        guard let start = startPoint, let current = currentPoint else { return nil }
        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let w = abs(current.x - start.x)
        let h = abs(current.y - start.y)
        guard w > 10, h > 8 else { return nil }
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

private final class RegionSelectorPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class RegionSelectorController: NSObject, NSWindowDelegate {
    private static var active: RegionSelectorController?

    private var panel: RegionSelectorPanel?
    private var selectorView: NativeRegionSelectorView?
    private var targetScreen: NSScreen?
    private var onSelect: ((ScreenCaptureRegion) -> Void)?
    private var isClosing = false
    private var selfRetain: RegionSelectorController?

    static func present(title: String, onSelect: @escaping (ScreenCaptureRegion) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            presentNow(title: title, onSelect: onSelect)
        }
    }

    private static func presentNow(title: String, onSelect: @escaping (ScreenCaptureRegion) -> Void) {
        if let existing = active {
            existing.finish(cancel: true)
        }

        guard let screen = screenUnderMouse() else {
            DebugLog.error("RegionSelector: no screen")
            return
        }

        let controller = RegionSelectorController()
        controller.selfRetain = controller
        RegionSelectorController.active = controller
        controller.onSelect = onSelect
        controller.targetScreen = screen
        controller.isClosing = false

        let view = NativeRegionSelectorView(frame: CGRect(origin: .zero, size: screen.frame.size))
        view.titleText = title
        weak var weakController = controller
        view.onConfirm = { rect in weakController?.confirm(rect) }
        view.onCancel = { weakController?.finish(cancel: true) }
        controller.selectorView = view

        let panel = RegionSelectorPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentView = view
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.delegate = controller
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        controller.panel = panel

        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeFirstResponder(view)
        DebugLog.info("RegionSelector opened on \(screen.localizedName)")
    }

    private static func screenUnderMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouse) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    private func confirm(_ localRect: CGRect) {
        guard !isClosing, let screen = targetScreen else { return }
        let region = ScreenCaptureRegion.from(localRect: localRect, screen: screen)
        let callback = onSelect
        onSelect = nil
        finish(cancel: false)
        DispatchQueue.main.async {
            callback?(region)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func finish(cancel: Bool) {
        guard !isClosing else { return }
        isClosing = true
        if cancel { onSelect = nil }

        selectorView?.onConfirm = nil
        selectorView?.onCancel = nil

        if let panel {
            panel.delegate = nil
            panel.orderOut(nil)
            DispatchQueue.main.async { [weak panel] in
                panel?.contentView = nil
            }
        }

        panel = nil
        selectorView = nil
        targetScreen = nil

        if RegionSelectorController.active === self {
            RegionSelectorController.active = nil
        }
        DispatchQueue.main.async { [weak self] in
            self?.selfRetain = nil
        }
        DebugLog.info("RegionSelector closed cancel=\(cancel)")
    }

    func windowWillClose(_ notification: Notification) {
        if !isClosing { finish(cancel: true) }
    }
}
