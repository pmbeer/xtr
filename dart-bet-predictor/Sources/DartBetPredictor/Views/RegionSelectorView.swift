import AppKit
import SwiftUI

// MARK: - Нативный селектор области (NSView — надёжные mouse events)

/// Поле, которое не перехватывает клики — drag проходит на родителя.
private final class PassthroughLabel: NSTextField {
    override func hitTest(_ point: CGPoint) -> NSView? { nil }
}

/// NSView с координатами origin сверху-слева (как SwiftUI).
final class NativeRegionSelectorView: NSView {
    var title: String = "Выделите область"
    var onConfirm: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var isDragging = false

    private let headerHeight: CGFloat = 88
    private let buttonBarHeight: CGFloat = 96
    private var confirmButton: NSButton?
    private var cancelButton: NSButton?
    fileprivate var titleLabel: NSTextField?
    private var hintLabel: NSTextField?

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.45).cgColor

        titleLabel = PassthroughLabel(labelWithString: title)
        titleLabel?.font = .boldSystemFont(ofSize: 20)
        titleLabel?.alignment = .center
        titleLabel?.textColor = .white
        titleLabel?.backgroundColor = .clear
        titleLabel?.isBezeled = false
        titleLabel?.isEditable = false
        if let label = titleLabel { addSubview(label) }

        hintLabel = PassthroughLabel(
            labelWithString: "Зажмите ЛКМ и протяните мышь для выделения (не в зоне кнопок)"
        )
        hintLabel?.font = .systemFont(ofSize: 14)
        hintLabel?.alignment = .center
        hintLabel?.textColor = NSColor.white.withAlphaComponent(0.85)
        hintLabel?.backgroundColor = .clear
        hintLabel?.isBezeled = false
        hintLabel?.isEditable = false
        if let label = hintLabel { addSubview(label) }

        cancelButton = NSButton(title: "Отмена", target: self, action: #selector(cancelTapped))
        cancelButton?.bezelStyle = .rounded
        if let btn = cancelButton { addSubview(btn) }

        confirmButton = NSButton(title: "Подтвердить", target: self, action: #selector(confirmTapped))
        confirmButton?.bezelStyle = .rounded
        confirmButton?.keyEquivalent = "\r"
        if let btn = confirmButton { addSubview(btn) }

        updateButtonState()
    }

    override func layout() {
        super.layout()
        let w = bounds.width
        let h = bounds.height

        titleLabel?.frame = CGRect(x: 20, y: 24, width: w - 40, height: 30)
        hintLabel?.frame = CGRect(x: 20, y: 52, width: w - 40, height: 22)

        let btnW: CGFloat = 140
        let btnH: CGFloat = 36
        let btnY = h - buttonBarHeight + 28
        cancelButton?.frame = CGRect(x: w / 2 - btnW - 12, y: btnY, width: btnW, height: btnH)
        confirmButton?.frame = CGRect(x: w / 2 + 12, y: btnY, width: btnW, height: btnH)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let rect = selectionRect else { return }

        NSColor.orange.withAlphaComponent(0.25).setFill()
        rect.fill()

        let path = NSBezierPath(rect: rect)
        path.lineWidth = 3
        NSColor.orange.setStroke()
        path.stroke()

        let sizeText = String(format: "%.0f × %.0f", rect.width, rect.height)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 13),
            .foregroundColor: NSColor.white
        ]
        let textSize = (sizeText as NSString).size(withAttributes: attrs)
        let textOrigin = CGPoint(
            x: rect.midX - textSize.width / 2,
            y: rect.midY - textSize.height / 2
        )
        (sizeText as NSString).draw(at: textOrigin, withAttributes: attrs)
    }

    // MARK: - Hit testing (прозрачные borderless окна не должны «пробивать» клики)

    override func hitTest(_ point: CGPoint) -> NSView? {
        guard bounds.contains(point) else { return nil }

        for subview in subviews.reversed() {
            let local = convert(point, to: subview)
            if let hit = subview.hitTest(local) {
                return hit
            }
        }

        if isInDragExclusionZone(point) { return nil }
        return self
    }

    // MARK: - Mouse

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard isInDragZone(point) else { return }

        startPoint = point
        currentPoint = point
        isDragging = true
        needsDisplay = true

        // trackEvents — надёжнее mouseDragged на полноэкранных overlay
        window?.trackEvents(
            matching: [.leftMouseDragged, .leftMouseUp],
            timeout: .greatestFiniteMagnitude,
            mode: .eventTracking
        ) { event, stop in
            guard let event else { return }
            switch event.type {
            case .leftMouseDragged:
                self.currentPoint = self.convert(event.locationInWindow, from: nil)
                self.needsDisplay = true
                self.updateButtonState()
            case .leftMouseUp:
                self.currentPoint = self.convert(event.locationInWindow, from: nil)
                self.isDragging = false
                self.needsDisplay = true
                self.updateButtonState()
                stop.pointee = true
            default:
                break
            }
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            cancelTapped()
            return
        }
        super.keyDown(with: event)
    }

    override var acceptsFirstResponder: Bool { true }

    // MARK: - Actions

    @objc private func confirmTapped() {
        guard let rect = selectionRect else { return }
        onConfirm?(rect)
    }

    @objc private func cancelTapped() {
        onCancel?()
    }

    private func updateButtonState() {
        confirmButton?.isEnabled = selectionRect != nil
    }

    private func isInDragZone(_ point: CGPoint) -> Bool {
        point.y >= headerHeight && point.y <= bounds.height - buttonBarHeight
    }

    private func isInDragExclusionZone(_ point: CGPoint) -> Bool {
        !isInDragZone(point)
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

// MARK: - NSPanel

private final class RegionSelectorPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Window controller

final class RegionSelectorWindowController: NSWindowController, NSWindowDelegate {
    private static var active: RegionSelectorWindowController?

    private var onSelectCallback: ((ScreenCaptureRegion) -> Void)?
    private var selectorView: NativeRegionSelectorView?
    private var targetScreen: NSScreen?
    private var isClosing = false

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

        let screenSize = screen.frame.size
        let selectorView = NativeRegionSelectorView(frame: CGRect(origin: .zero, size: screenSize))
        selectorView.title = title
        selectorView.titleLabel?.stringValue = title
        selectorView.onConfirm = { rect in controller.confirmSelection(rect) }
        selectorView.onCancel = { controller.cancelSelection() }
        controller.selectorView = selectorView

        let panel = RegionSelectorPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentView = selectorView
        panel.isOpaque = true
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.45)
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.delegate = controller
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true

        controller.window = panel

        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        selectorView.window?.makeFirstResponder(selectorView)

        LaunchLogger.log("RegionSelector (native) opened: \(screen.localizedName)")
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
        LaunchLogger.log("RegionSelector confirmed: \(localRect)")

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
        window?.contentView = nil
        selectorView = nil
        window = nil
        targetScreen = nil

        if RegionSelectorWindowController.active === self {
            RegionSelectorWindowController.active = nil
        }
    }

    func windowWillClose(_ notification: Notification) {
        if !isClosing { dismissPanel() }
    }
}
