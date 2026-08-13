import Foundation
import ScreenCaptureKit
import CoreImage
import CoreGraphics
import Combine

final class ScreenCaptureManager: NSObject, ObservableObject {
    static let shared = ScreenCaptureManager()

    @Published var isCapturing = false
    @Published var lastError: String?

    private var stream: SCStream?
    private let captureQueue = DispatchQueue(label: "com.dartpredictor.capture", qos: .userInteractive)
    private var frameHandler: ((CGImage) -> Void)?
    private var monitorRect: CGRect?
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    func configureMonitorRegion(_ rect: CGRect) {
        monitorRect = rect
    }

    func configure(regions: [CaptureRegion]) {
        if let game = regions.first(where: { $0.type == .gameScreen }) {
            monitorRect = game.rect
            return
        }
        // Legacy: объединить result + player в одну область
        let legacy = regions.filter { $0.type == .result || $0.type == .player }
        if !legacy.isEmpty {
            monitorRect = legacy.map(\.rect).reduce(legacy[0].rect) { $0.union($1) }
        }
    }

    func startCapture(handler: @escaping (CGImage) -> Void) async throws {
        guard !isCapturing else { return }
        guard monitorRect != nil else {
            throw CaptureError.noRegion
        }

        frameHandler = handler

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw CaptureError.noDisplay
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(display.width)
        config.height = Int(display.height)
        let frameRate = await MainActor.run { SettingsManager.shared.settings.captureFrameRate }
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        config.queueDepth = 3
        config.showsCursor = false
        config.pixelFormat = kCVPixelFormatType_32BGRA

        let streamOutput = StreamOutputHandler(manager: self)
        let newStream = SCStream(filter: filter, configuration: config, delegate: nil)
        try newStream.addStreamOutput(streamOutput, type: .screen, sampleHandlerQueue: captureQueue)
        try await newStream.startCapture()

        stream = newStream
        await MainActor.run { isCapturing = true }
        DebugLogger.shared.log("Screen capture started (unified monitor)", category: "capture")
    }

    func stopCapture() async {
        guard let stream else { return }
        try? await stream.stopCapture()
        self.stream = nil
        frameHandler = nil
        await MainActor.run { isCapturing = false }
        DebugLogger.shared.log("Screen capture stopped", category: "capture")
    }

    fileprivate func processFrame(_ pixelBuffer: CVPixelBuffer) {
        guard let handler = frameHandler, let rect = monitorRect else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let cropped = ciImage.cropped(to: rect)
        guard let cgImage = ciContext.createCGImage(cropped, from: cropped.extent) else { return }
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
