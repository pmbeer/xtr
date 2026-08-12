import CoreMedia
import CoreVideo
import Foundation
import ScreenCaptureKit

final class ScreenCaptureService: NSObject, SCStreamOutput, SCStreamDelegate {
    var onFrame: ((CVPixelBuffer, UUID) -> Void)?
    var onError: ((UUID, String) -> Void)?

    private let captureQueue = DispatchQueue(label: "darts.capture", qos: .userInteractive)
    private let stateLock = NSLock()
    private var stream: SCStream?
    private var sessionID: UUID?

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

    func start(window: SCWindow, sessionID: UUID) async throws {
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
        activate(newStream, sessionID: sessionID)
        do {
            try await newStream.startCapture()
        } catch {
            deactivate(newStream)
            throw error
        }
    }

    func stop() async throws {
        guard let stream = takeActiveStream() else { return }
        try await stream.stopCapture()
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard let sessionID = activeSession(for: stream),
              type == .screen,
              sampleBuffer.isValid,
              isCompleteFrame(sampleBuffer),
              let pixelBuffer = sampleBuffer.imageBuffer else {
            return
        }
        onFrame?(pixelBuffer, sessionID)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        guard let sessionID = activeSession(for: stream) else { return }
        onError?(sessionID, error.localizedDescription)
    }

    private func windowLabel(_ window: SCWindow) -> String {
        let app = window.owningApplication?.applicationName ?? "Приложение"
        let title = window.title?.isEmpty == false ? window.title! : "без названия"
        return "\(app) — \(title)"
    }

    private func isCompleteFrame(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let attachmentArray = CMSampleBufferGetSampleAttachmentsArray(
            sampleBuffer,
            createIfNecessary: false
        ) as? [[SCStreamFrameInfo: Any]],
        let attachment = attachmentArray.first,
        let rawStatus = attachment[.status] as? Int,
        let status = SCFrameStatus(rawValue: rawStatus) else {
            return false
        }
        return status == .complete
    }

    private func activeSession(for candidate: SCStream) -> UUID? {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard let stream, stream === candidate else { return nil }
        return sessionID
    }

    private func activate(_ newStream: SCStream, sessionID: UUID) {
        stateLock.lock()
        defer { stateLock.unlock() }
        stream = newStream
        self.sessionID = sessionID
    }

    private func takeActiveStream() -> SCStream? {
        stateLock.lock()
        defer { stateLock.unlock() }
        let activeStream = stream
        stream = nil
        sessionID = nil
        return activeStream
    }

    private func deactivate(_ candidate: SCStream) {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard let stream, stream === candidate else { return }
        self.stream = nil
        sessionID = nil
    }
}
