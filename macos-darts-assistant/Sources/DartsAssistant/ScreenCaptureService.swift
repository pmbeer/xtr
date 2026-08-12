import CoreMedia
import CoreVideo
import Foundation
import ScreenCaptureKit

final class ScreenCaptureService: NSObject, SCStreamOutput, SCStreamDelegate {
    var onFrame: ((CVPixelBuffer) -> Void)?
    var onError: ((String) -> Void)?

    private let captureQueue = DispatchQueue(label: "darts.capture", qos: .userInteractive)
    private var stream: SCStream?

    func availableWindows() async throws -> [SCWindow] {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        return content.windows
            .filter { window in
                window.frame.width >= 400
                    && window.frame.height >= 300
                    && window.owningApplication?.bundleIdentifier
                        != Bundle.main.bundleIdentifier
            }
            .sorted {
                windowLabel($0).localizedCaseInsensitiveCompare(windowLabel($1))
                    == .orderedAscending
            }
    }

    func start(window: SCWindow) async throws {
        try await stop()

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        let scale = min(2.0, 1920.0 / max(window.frame.width, 1))
        configuration.width = Int(window.frame.width * scale)
        configuration.height = Int(window.frame.height * scale)
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 12)
        configuration.queueDepth = 3
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = false
        configuration.capturesAudio = false

        let newStream = SCStream(
            filter: filter,
            configuration: configuration,
            delegate: self
        )
        try newStream.addStreamOutput(
            self,
            type: .screen,
            sampleHandlerQueue: captureQueue
        )
        stream = newStream
        try await newStream.startCapture()
    }

    func stop() async throws {
        guard let stream else { return }
        try await stream.stopCapture()
        self.stream = nil
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen,
              sampleBuffer.isValid,
              let pixelBuffer = sampleBuffer.imageBuffer else {
            return
        }
        onFrame?(pixelBuffer)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        onError?(error.localizedDescription)
    }

    private func windowLabel(_ window: SCWindow) -> String {
        let app = window.owningApplication?.applicationName ?? "Приложение"
        let title = window.title?.isEmpty == false ? window.title! : "без названия"
        return "\(app) — \(title)"
    }
}
