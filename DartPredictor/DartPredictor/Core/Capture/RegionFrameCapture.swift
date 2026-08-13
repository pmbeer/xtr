import Foundation
import CoreGraphics
import AppKit

/// Захват выбранной области экрана через CGWindowListCreateImage (fallback / тестовый снимок).
final class RegionFrameCapture: ObservableObject {
    static let shared = RegionFrameCapture()

    @Published var framesCaptured: Int = 0
    @Published var lastFrame: CGImage?
    @Published var lastError: String?
    @Published var isCapturing = false
    @Published var hasScreenPermission = true

    private var captureRegion: CGRect?
    private var frameHandler: ((CGImage) -> Void)?
    private var timer: DispatchSourceTimer?
    private let captureQueue = DispatchQueue(label: "com.dartpredictor.regioncapture", qos: .userInteractive)

    func checkScreenRecordingPermission() -> Bool {
        if #available(macOS 10.15, *) {
            let ok = CGPreflightScreenCaptureAccess()
            hasScreenPermission = ok
            return ok
        }
        return true
    }

    func requestScreenRecordingPermission() {
        if #available(macOS 10.15, *) {
            CGRequestScreenCaptureAccess()
        }
    }

    func configure(region: CGRect) {
        let normalized = CaptureGeometry.normalizeRegion(region)
        captureRegion = normalized
        DebugLogger.shared.log(
            "Region capture: x=\(Int(normalized.origin.x)) y=\(Int(normalized.origin.y)) w=\(Int(normalized.width)) h=\(Int(normalized.height))",
            category: "capture"
        )
    }

    /// Одиночный снимок области — для проверки после выбора региона
    func captureSingleFrame(region: CGRect) -> CGImage? {
        guard checkScreenRecordingPermission() else { return nil }
        let normalized = CaptureGeometry.normalizeRegion(region)
        return grabImage(for: normalized)
    }

    func startCapture(fps: Int, handler: @escaping (CGImage) -> Void) {
        guard let region = captureRegion else {
            lastError = "Область не выбрана"
            return
        }

        if !checkScreenRecordingPermission() {
            lastError = "Нет разрешения «Запись экрана»"
            requestScreenRecordingPermission()
            return
        }

        stopCapture()
        frameHandler = handler
        framesCaptured = 0
        isCapturing = true
        lastError = nil

        let interval = 1.0 / Double(max(fps, 5))

        let t = DispatchSource.makeTimerSource(queue: captureQueue)
        t.schedule(deadline: .now() + 0.1, repeating: interval)
        t.setEventHandler { [weak self] in
            self?.grabFrame()
        }
        t.resume()
        timer = t

        DebugLogger.shared.log("Region frame capture started @ \(fps)fps", category: "capture")
    }

    func stopCapture() {
        timer?.cancel()
        timer = nil
        frameHandler = nil
        isCapturing = false
    }

    private func grabFrame() {
        guard let region = captureRegion, let handler = frameHandler else { return }

        guard let image = grabImage(for: region) else {
            DispatchQueue.main.async {
                self.lastError = "Не удалось снять экран — проверьте разрешение «Запись экрана»"
                self.hasScreenPermission = false
            }
            return
        }

        framesCaptured += 1
        DispatchQueue.main.async {
            self.lastFrame = image
            self.lastError = nil
            self.hasScreenPermission = true
        }
        handler(image)
    }

    private func grabImage(for region: CGRect) -> CGImage? {
        CGWindowListCreateImage(
            region,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        )
    }
}
