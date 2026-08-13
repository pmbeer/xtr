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
    private var resultHandler: ((CGImage, CaptureRegionType) -> Void)?
    private var regions: [CaptureRegionType: CGRect] = [:]
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    func configure(regions: [CaptureRegion]) {
        for region in regions {
            self.regions[region.type] = region.rect
        }
    }

    func startCapture(handler: @escaping (CGImage, CaptureRegionType) -> Void) async throws {
        guard !isCapturing else { return }
        resultHandler = handler

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
        DebugLogger.shared.log("Screen capture started", category: "capture")
    }

    func stopCapture() async {
        guard let stream else { return }
        try? await stream.stopCapture()
        self.stream = nil
        resultHandler = nil
        await MainActor.run { isCapturing = false }
        DebugLogger.shared.log("Screen capture stopped", category: "capture")
    }

    fileprivate func processFrame(_ pixelBuffer: CVPixelBuffer) {
        guard let handler = resultHandler else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        for (type, rect) in regions {
            let cropped = ciImage.cropped(to: rect)
            guard let cgImage = ciContext.createCGImage(cropped, from: cropped.extent) else { continue }
            handler(cgImage, type)
        }
    }

    enum CaptureError: LocalizedError {
        case noDisplay
        case streamFailed

        var errorDescription: String? {
            switch self {
            case .noDisplay: return "Не найден дисплей для захвата"
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
