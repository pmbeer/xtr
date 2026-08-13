import Foundation
import ScreenCaptureKit
import CoreImage
import CoreGraphics
import CoreMedia
import Combine

/// Захват конкретного окна (Safari с fon.bet и др.) через ScreenCaptureKit
final class WindowCaptureManager: NSObject, ObservableObject {
    static let shared = WindowCaptureManager()

    @Published var isCapturing = false
    @Published var framesCaptured: Int = 0
    @Published var lastCropSize: CGSize = .zero
    @Published var lastError: String?

    private var stream: SCStream?
    private let captureQueue = DispatchQueue(label: "com.dartpredictor.windowcapture", qos: .userInteractive)
    private var frameHandler: ((CGImage) -> Void)?
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private var targetWindowID: UInt32?

    enum WindowCaptureError: LocalizedError {
        case windowNotFound
        case permissionDenied
        case snapshotFailed

        var errorDescription: String? {
            switch self {
            case .windowNotFound:
                return "Окно не найдено — откройте игру и выберите окно снова"
            case .permissionDenied:
                return "Нужно разрешение «Запись экрана»"
            case .snapshotFailed:
                return "Не удалось снять снимок окна"
            }
        }
    }

    func listWindows() async throws -> [CaptureWindowInfo] {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        let ownBundle = Bundle.main.bundleIdentifier ?? ""

        let items = content.windows.compactMap { window -> CaptureWindowInfo? in
            guard window.isOnScreen else { return nil }
            let app = window.owningApplication
            if app?.bundleIdentifier == ownBundle { return nil }
            guard window.frame.width >= 400, window.frame.height >= 300 else { return nil }

            let title = window.title ?? ""
            let appName = app?.applicationName ?? "Приложение"

            return CaptureWindowInfo(
                windowID: window.windowID,
                title: title,
                appName: appName,
                width: Int(window.frame.width),
                height: Int(window.frame.height)
            )
        }

        return items.sorted { lhs, rhs in
            let lhsScore = windowSortScore(lhs)
            let rhsScore = windowSortScore(rhs)
            if lhsScore != rhsScore { return lhsScore > rhsScore }
            return lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle) == .orderedAscending
        }
    }

    private func windowSortScore(_ info: CaptureWindowInfo) -> Int {
        var score = 0
        let title = info.title.lowercased()
        let app = info.appName.lowercased()
        if title.contains("fon") || title.contains("dart") || title.contains("игр") { score += 10 }
        if app.contains("safari") || app.contains("chrome") || app.contains("firefox") { score += 5 }
        if info.width >= 900 && info.height >= 600 { score += 2 }
        return score
    }

    func captureSnapshot(windowID: UInt32) async throws -> CGImage {
        let window = try await findWindow(id: windowID)
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = makeConfiguration(for: window)
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    func startCapture(windowID: UInt32, handler: @escaping (CGImage) -> Void) async throws {
        guard !isCapturing else { return }

        let window = try await findWindow(id: windowID)
        targetWindowID = windowID
        frameHandler = handler
        framesCaptured = 0
        lastError = nil

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = makeConfiguration(for: window)
        let frameRate = await MainActor.run { SettingsManager.shared.settings.captureFrameRate }
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(max(frameRate, 5)))
        config.queueDepth = 4
        config.showsCursor = false
        config.pixelFormat = kCVPixelFormatType_32BGRA

        let output = StreamOutputHandler(manager: self)
        let newStream = SCStream(filter: filter, configuration: config, delegate: nil)
        try newStream.addStreamOutput(output, type: .screen, sampleHandlerQueue: captureQueue)
        try await newStream.startCapture()

        stream = newStream
        await MainActor.run { isCapturing = true }

        DebugLogger.shared.log(
            "Window capture started: \(window.title ?? "?") \(Int(window.frame.width))×\(Int(window.frame.height))",
            category: "capture"
        )
    }

    func stopCapture() async {
        guard let stream else { return }
        try? await stream.stopCapture()
        self.stream = nil
        frameHandler = nil
        targetWindowID = nil
        await MainActor.run { isCapturing = false }
        DebugLogger.shared.log("Window capture stopped", category: "capture")
    }

    private func findWindow(id: UInt32) async throws -> SCWindow {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        guard let window = content.windows.first(where: { $0.windowID == id }) else {
            throw WindowCaptureError.windowNotFound
        }
        return window
    }

    private func makeConfiguration(for window: SCWindow) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.width = max(Int(window.frame.width), 640)
        config.height = max(Int(window.frame.height), 480)
        config.captureResolution = .best
        return config
    }

    fileprivate func processFrame(_ pixelBuffer: CVPixelBuffer) {
        guard let handler = frameHandler else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let extent = ciImage.extent
        guard let cgImage = ciContext.createCGImage(ciImage, from: extent) else {
            DebugLogger.shared.logCaptureError("Window capture: failed to create CGImage")
            return
        }

        framesCaptured += 1
        lastCropSize = CGSize(width: cgImage.width, height: cgImage.height)
        handler(cgImage)
    }

    private final class StreamOutputHandler: NSObject, SCStreamOutput {
        weak var manager: WindowCaptureManager?

        init(manager: WindowCaptureManager) {
            self.manager = manager
        }

        func stream(
            _ stream: SCStream,
            didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
            of outputType: SCStreamOutputType
        ) {
            guard outputType == .screen,
                  let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            manager?.processFrame(pixelBuffer)
        }
    }
}
