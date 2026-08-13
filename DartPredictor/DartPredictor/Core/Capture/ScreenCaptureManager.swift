import Foundation
import ScreenCaptureKit
import CoreImage
import CoreGraphics
import CoreMedia
import Combine

final class ScreenCaptureManager: NSObject, ObservableObject {
    static let shared = ScreenCaptureManager()

    @Published var isCapturing = false
    @Published var lastError: String?
    @Published var framesCaptured: Int = 0
    @Published var lastCropSize: CGSize = .zero

    private var stream: SCStream?
    private let captureQueue = DispatchQueue(label: "com.dartpredictor.capture", qos: .userInteractive)
    private var frameHandler: ((CGImage) -> Void)?
    private var monitorRect: CGRect?
    private var captureDisplay: SCDisplay?
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    func configureMonitorRegion(_ rect: CGRect) {
        monitorRect = rect
        DebugLogger.shared.log(
            "Monitor region: x=\(Int(rect.origin.x)) y=\(Int(rect.origin.y)) w=\(Int(rect.width)) h=\(Int(rect.height))",
            category: "capture"
        )
    }

    func configure(regions: [CaptureRegion]) {
        if let game = regions.first(where: { $0.type == .gameScreen }) {
            monitorRect = game.rect
            return
        }
        let legacy = regions.filter { $0.type == .result || $0.type == .player }
        if !legacy.isEmpty {
            monitorRect = legacy.map(\.rect).reduce(legacy[0].rect) { $0.union($1) }
        }
    }

    func startCapture(handler: @escaping (CGImage) -> Void) async throws {
        guard !isCapturing else { return }
        guard let rect = monitorRect else {
            throw CaptureError.noRegion
        }

        frameHandler = handler
        framesCaptured = 0

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = CaptureGeometry.displayContaining(rect: rect, displays: content.displays) else {
            throw CaptureError.noDisplay
        }
        captureDisplay = display

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        // Нативное разрешение дисплея для чёткого OCR
        config.width = display.width
        config.height = display.height
        let frameRate = await MainActor.run { SettingsManager.shared.settings.captureFrameRate }
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        config.queueDepth = 3
        config.showsCursor = false
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.captureResolution = .best

        let streamOutput = StreamOutputHandler(manager: self)
        let newStream = SCStream(filter: filter, configuration: config, delegate: nil)
        try newStream.addStreamOutput(streamOutput, type: .screen, sampleHandlerQueue: captureQueue)
        try await newStream.startCapture()

        stream = newStream
        await MainActor.run { isCapturing = true }
        DebugLogger.shared.log(
            "Capture started display \(display.width)x\(display.height)",
            category: "capture"
        )
    }

    func stopCapture() async {
        guard let stream else { return }
        try? await stream.stopCapture()
        self.stream = nil
        frameHandler = nil
        captureDisplay = nil
        await MainActor.run { isCapturing = false }
        DebugLogger.shared.log("Screen capture stopped", category: "capture")
    }

    fileprivate func processFrame(_ pixelBuffer: CVPixelBuffer) {
        guard let handler = frameHandler,
              let screenRect = monitorRect,
              let display = captureDisplay else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let extent = ciImage.extent

        let cropRect = CaptureGeometry.cropRect(
            screenRect: screenRect,
            display: display,
            imageExtent: extent
        )

        guard CaptureGeometry.isValidCrop(cropRect) else {
            DebugLogger.shared.logCaptureError("Invalid crop rect: \(cropRect)")
            return
        }

        let cropped = ciImage.cropped(to: cropRect)
        let outputRect = cropped.extent
        guard let cgImage = ciContext.createCGImage(cropped, from: outputRect) else {
            DebugLogger.shared.logCaptureError("Failed to create CGImage from crop")
            return
        }

        framesCaptured += 1
        lastCropSize = CGSize(width: cgImage.width, height: cgImage.height)

        handler(cgImage)
    }

    enum CaptureError: LocalizedError {
        case noDisplay
        case noRegion
        case streamFailed

        var errorDescription: String? {
            switch self {
            case .noDisplay: return "Не найден дисплей для захвата"
            case .noRegion: return "Не выбрана область экрана для мониторинга"
            case .streamFailed: return "Ошибка запуска потока захвата"
            }
        }
    }

    private final class StreamOutputHandler: NSObject, SCStreamOutput {
        weak var manager: ScreenCaptureManager?

        init(manager: ScreenCaptureManager) {
            self.manager = manager
        }

        func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
            guard outputType == .screen,
                  let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            manager?.processFrame(pixelBuffer)
        }
    }
}
