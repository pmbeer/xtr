import AppKit
import SwiftUI

/// Safe region selector using dedicated NSWindow lifecycle.
/// Avoids EXC_BAD_ACCESS by keeping strong references and proper cleanup.
final class RegionSelectionCoordinator: NSObject {
    static let shared = RegionSelectionCoordinator()

    private var windowController: RegionSelectionWindowController?
    private var completionHandler: ((CGRect?) -> Void)?

    func present(for type: CaptureRegionType, completion: @escaping (CGRect?) -> Void) {
        dismiss()

        completionHandler = completion
        let controller = RegionSelectionWindowController(regionType: type)
        controller.onComplete = { [weak self] rect in
            guard let self else { return }
            let handler = self.completionHandler
            self.cleanup()
            handler?(rect)
        }
        controller.onCancel = { [weak self] in
            guard let self else { return }
            let handler = self.completionHandler
            self.cleanup()
            handler?(nil)
        }

        windowController = controller
        controller.show()
    }

    func dismiss() {
        windowController?.closeWindow()
        cleanup()
    }

    private func cleanup() {
        windowController = nil
        completionHandler = nil
    }
}

/// Borderless overlay must explicitly allow key window status for Enter/Esc.
private final class KeyableOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class RegionSelectionWindowController: NSWindowController {
    private let regionType: CaptureRegionType
    private let selectionView = RegionSelectionView()
    private var isClosed = false
    private var keyEventMonitor: Any?

    var onComplete: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    init(regionType: CaptureRegionType) {
        self.regionType = regionType

        let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let window = KeyableOverlayWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = NSColor.black.withAlphaComponent(0.25)
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false

        super.init(window: window)

        selectionView.regionType = regionType
        selectionView.onConfirm = { [weak self] rect in
            self?.handleConfirm(rect)
        }
        selectionView.onCancel = { [weak self] in
            self?.handleCancel()
        }

        window.contentView = selectionView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    func show() {
        guard !isClosed else { return }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(selectionView)

        installKeyMonitor()
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, !self.isClosed else { return event }

            switch event.keyCode {
            case 36, 76: // Return, keypad Enter
                self.selectionView.tryConfirm()
                return nil
            case 53: // Escape
                self.handleCancel()
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }

    func closeWindow() {
        guard !isClosed else { return }
        isClosed = true
        removeKeyMonitor()
        selectionView.onConfirm = nil
        selectionView.onCancel = nil
        window?.orderOut(nil)
        window?.contentView = nil
        window = nil
    }

    private func handleConfirm(_ rect: CGRect) {
        guard !isClosed else { return }
        let handler = onComplete
        closeWindow()
        handler?(rect)
    }

    private func handleCancel() {
        guard !isClosed else { return }
        let handler = onCancel
        closeWindow()
        handler?()
    }
}

final class RegionSelectionView: NSView {
    var regionType: CaptureRegionType = .result
    var onConfirm: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: CGPoint?
    private var currentRect: CGRect?
    private let overlayLayer = CAShapeLayer()
    private let borderLayer = CAShapeLayer()
    private let instructionLabel = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "")
    private let confirmButton = NSButton(title: "Подтвердить", target: nil, action: nil)
    private let cancelButton = NSButton(title: "Отмена", target: nil, action: nil)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true

        overlayLayer.fillColor = NSColor.black.withAlphaComponent(0.4).cgColor
        overlayLayer.fillRule = .evenOdd
        layer?.addSublayer(overlayLayer)

        borderLayer.fillColor = nil
        borderLayer.strokeColor = NSColor.systemGreen.cgColor
        borderLayer.lineWidth = 2
        layer?.addSublayer(borderLayer)

        instructionLabel.font = .systemFont(ofSize: 18, weight: .medium)
        instructionLabel.textColor = .white
        instructionLabel.alignment = .center
        instructionLabel.isEditable = false
        instructionLabel.isSelectable = false
        instructionLabel.isBezeled = false
        instructionLabel.drawsBackground = false
        addSubview(instructionLabel)

        hintLabel.font = .systemFont(ofSize: 13)
        hintLabel.textColor = NSColor.white.withAlphaComponent(0.85)
        hintLabel.alignment = .center
        hintLabel.isEditable = false
        hintLabel.isSelectable = false
        hintLabel.isBezeled = false
        hintLabel.drawsBackground = false
        hintLabel.stringValue = "Enter или кнопка «Подтвердить» · Esc или «Отмена» · Двойной клик — подтвердить"
        addSubview(hintLabel)

        confirmButton.bezelStyle = .rounded
        confirmButton.target = self
        confirmButton.action = #selector(confirmButtonTapped)
        confirmButton.keyEquivalent = "\r"
        addSubview(confirmButton)

        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelButtonTapped)
        cancelButton.keyEquivalent = "\u{1b}"
        addSubview(cancelButton)

        updateInstruction()
    }

    override func layout() {
        super.layout()
        overlayLayer.frame = bounds
        borderLayer.frame = bounds
        instructionLabel.frame = CGRect(x: 20, y: bounds.height - 72, width: bounds.width - 40, height: 44)
        hintLabel.frame = CGRect(x: 20, y: bounds.height - 100, width: bounds.width - 40, height: 20)

        let buttonWidth: CGFloat = 140
        let buttonHeight: CGFloat = 32
        let spacing: CGFloat = 16
        let totalWidth = buttonWidth * 2 + spacing
        let startX = (bounds.width - totalWidth) / 2
        confirmButton.frame = CGRect(x: startX, y: 40, width: buttonWidth, height: buttonHeight)
        cancelButton.frame = CGRect(x: startX + buttonWidth + spacing, y: 40, width: buttonWidth, height: buttonHeight)

        redrawOverlay()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    private func updateInstruction() {
        switch regionType {
        case .gameScreen:
            instructionLabel.stringValue = "Выделите область экрана с игрой (игрок + результаты)"
        case .result:
            instructionLabel.stringValue = "Выделите область с результатами бросков"
        case .player:
            instructionLabel.stringValue = "Выделите область с игроком"
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if event.clickCount >= 2 {
            tryConfirm()
            return
        }
        startPoint = convert(event.locationInWindow, from: nil)
        currentRect = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)
        currentRect = rectFromPoints(start, current)
        redrawOverlay()
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)
        currentRect = rectFromPoints(start, current)
        redrawOverlay()
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76:
            tryConfirm()
        case 53:
            onCancel?()
        default:
            super.keyDown(with: event)
        }
    }

    override var acceptsFirstResponder: Bool { true }

    func tryConfirm() {
        guard let rect = currentRect, rect.width > 20, rect.height > 20 else {
            hintLabel.stringValue = "Сначала выделите область перетаскиванием мыши"
            hintLabel.textColor = .systemOrange
            return
        }
        confirmSelection(rect: rect)
    }

    @objc private func confirmButtonTapped() {
        tryConfirm()
    }

    @objc private func cancelButtonTapped() {
        onCancel?()
    }

    private func confirmSelection(rect: CGRect) {
        let screenFrame = window?.screen?.frame ?? NSScreen.main?.frame ?? .zero
        let flipped = CGRect(
            x: screenFrame.origin.x + rect.origin.x,
            y: screenFrame.origin.y + screenFrame.height - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
        onConfirm?(flipped)
    }

    private func rectFromPoints(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(b.x - a.x),
            height: abs(b.y - a.y)
        )
    }

    private func redrawOverlay() {
        let path = CGMutablePath()
        path.addRect(bounds)
        if let rect = currentRect {
            path.addRect(rect)
        }
        overlayLayer.path = path

        if let rect = currentRect {
            borderLayer.path = CGPath(rect: rect, transform: nil)
        } else {
            borderLayer.path = nil
        }
    }
}

struct RegionSelectorBridge: View {
    let regionType: CaptureRegionType
    let onSelected: (CGRect?) -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                DispatchQueue.main.async {
                    RegionSelectionCoordinator.shared.present(for: regionType) { rect in
                        onSelected(rect)
                    }
                }
            }
            .onDisappear {
                RegionSelectionCoordinator.shared.dismiss()
            }
    }
}
