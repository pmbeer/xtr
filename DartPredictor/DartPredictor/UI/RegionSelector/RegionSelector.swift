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

final class RegionSelectionWindowController: NSWindowController {
    private let regionType: CaptureRegionType
    private let selectionView = RegionSelectionView()
    private var isClosed = false

    var onComplete: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    init(regionType: CaptureRegionType) {
        self.regionType = regionType

        let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let window = NSWindow(
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
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeWindow() {
        guard !isClosed else { return }
        isClosed = true
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
        addSubview(instructionLabel)

        updateInstruction()
    }

    override func layout() {
        super.layout()
        overlayLayer.frame = bounds
        borderLayer.frame = bounds
        instructionLabel.frame = CGRect(x: 20, y: bounds.height - 60, width: bounds.width - 40, height: 40)
        redrawOverlay()
    }

    private func updateInstruction() {
        switch regionType {
        case .result:
            instructionLabel.stringValue = "Выделите область с результатами бросков. Перетащите мышь. Enter — подтвердить, Esc — отмена."
        case .player:
            instructionLabel.stringValue = "Выделите область с игроком. Перетащите мышь. Enter — подтвердить, Esc — отмена."
        }
    }

    override func mouseDown(with event: NSEvent) {
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
        case 36: // Return
            confirmSelection()
        case 53: // Escape
            onCancel?()
        default:
            super.keyDown(with: event)
        }
    }

    override var acceptsFirstResponder: Bool { true }

    private func confirmSelection() {
        guard let rect = currentRect, rect.width > 20, rect.height > 20 else { return }
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let flipped = CGRect(
            x: rect.origin.x,
            y: screenHeight - rect.origin.y - rect.height,
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
                RegionSelectionCoordinator.shared.present(for: regionType) { rect in
                    onSelected(rect)
                }
            }
            .onDisappear {
                RegionSelectionCoordinator.shared.dismiss()
            }
    }
}
