import AppKit
import CoreGraphics
import Foundation
import Combine
import ImageIO
#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
#endif

/// Захват выбранных областей. OCR — только result-region; player — downscaled.
@MainActor
final class ScreenCaptureManager: ObservableObject {
    @Published private(set) var lastError: String?
    @Published private(set) var isRunning = false

    private var resultTimer: Timer?
    private var playerTimer: Timer?
    private var resultRegion: ScreenCaptureRegion?
    private var playerRegion: ScreenCaptureRegion?

    var onResultFrame: ((CGImage) -> Void)?
    var onPlayerFrame: ((CGImage) -> Void)?

    func updateRegions(result: ScreenCaptureRegion?, player: ScreenCaptureRegion?) {
        resultRegion = result
        playerRegion = player
    }

    func start() {
        stop()
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            lastError = "Нет разрешения на запись экрана"
            DebugLog.error(lastError!)
            return
        }
        isRunning = true
        lastError = nil

        resultTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / Double(HardwareProfile.resultCaptureFPS), repeats: true) { [weak self] _ in
            Task { @MainActor in self?.captureResult() }
        }
        playerTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / Double(HardwareProfile.playerCaptureFPS), repeats: true) { [weak self] _ in
            Task { @MainActor in self?.capturePlayer() }
        }
        // Не блокируем runloop — timers на common mode.
        if let t = resultTimer { RunLoop.main.add(t, forMode: .common) }
        if let t = playerTimer { RunLoop.main.add(t, forMode: .common) }
        DebugLog.info("ScreenCapture started")
    }

    func stop() {
        resultTimer?.invalidate()
        playerTimer?.invalidate()
        resultTimer = nil
        playerTimer = nil
        isRunning = false
    }

    private func captureResult() {
        guard let region = resultRegion else { return }
        guard let image = captureCGImage(region: region, maxWidth: nil) else { return }
        onResultFrame?(image)
    }

    private func capturePlayer() {
        guard let region = playerRegion else { return }
        guard let image = captureCGImage(region: region, maxWidth: HardwareProfile.playerMaxWidth) else { return }
        onPlayerFrame?(image)
    }

    /// CGDisplay crop — стабильно на Intel / macOS 15, без тяжёлого SCK pipeline.
    private func captureCGImage(region: ScreenCaptureRegion, maxWidth: CGFloat?) -> CGImage? {
        let rect = region.cgRect
        guard rect.width > 2, rect.height > 2 else { return nil }

        guard let displayImage = CGDisplayCreateImage(region.displayID) else {
            lastError = "Не удалось захватить дисплей"
            DebugLog.warn("CGDisplayCreateImage failed")
            return nil
        }
        let local = displayLocalRect(region)
        let scaleX = CGFloat(displayImage.width) / CGDisplayPixelsWide(region.displayID).cgFloatSafe
        let scaleY = CGFloat(displayImage.height) / CGDisplayPixelsHigh(region.displayID).cgFloatSafe
        var crop = CGRect(
            x: local.origin.x * scaleX,
            y: local.origin.y * scaleY,
            width: local.width * scaleX,
            height: local.height * scaleY
        )
        let bounds = CGRect(x: 0, y: 0, width: CGFloat(displayImage.width), height: CGFloat(displayImage.height))
        crop = crop.integral.intersection(bounds)
        guard crop.width > 1, crop.height > 1, let cropped = displayImage.cropping(to: crop) else { return nil }
        return downscaleIfNeeded(cropped, maxWidth: maxWidth)
    }

    private func displayLocalRect(_ region: ScreenCaptureRegion) -> CGRect {
        let bounds = CGDisplayBounds(region.displayID)
        return CGRect(
            x: region.cgRect.origin.x - bounds.origin.x,
            y: region.cgRect.origin.y - bounds.origin.y,
            width: region.cgRect.width,
            height: region.cgRect.height
        )
    }

    private func downscaleIfNeeded(_ image: CGImage, maxWidth: CGFloat?) -> CGImage {
        guard let maxWidth, CGFloat(image.width) > maxWidth else { return image }
        let scale = maxWidth / CGFloat(image.width)
        let h = CGFloat(image.height) * scale
        let w = maxWidth
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: Int(w),
            height: Int(h),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        ctx.interpolationQuality = .low
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage() ?? image
    }
}

private extension Int {
    var cgFloatSafe: CGFloat { CGFloat(self == 0 ? 1 : self) }
}
