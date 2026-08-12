import AppKit
import CoreGraphics
import CoreVideo
import Foundation
import ScreenCaptureKit

/// Захват выбранной области экрана (ScreenCaptureKit на macOS 14+, legacy fallback).
final class ScreenCaptureService {
    static let shared = ScreenCaptureService()

    private var lastMethod = "none"

    private init() {}

    var lastCaptureMethod: String { lastMethod }

    /// Асинхронный захват — предпочтительный путь.
    func captureAsync(region: ScreenCaptureRegion) async -> CGImage? {
        let cgRect = region.cgCaptureRect()
        guard cgRect.width > 1, cgRect.height > 1 else { return nil }

        if #available(macOS 14.0, *) {
            if let image = await captureWithDisplayFilter(region: region) {
                lastMethod = "SCK-display"
                return image
            }
        }

        if let image = captureLegacyWindowList(rect: cgRect) {
            lastMethod = "CGWindowList"
            return image
        }

        if let displayID = region.displayIDForCapture,
           let image = captureLegacyDisplay(displayID: displayID, cropRect: cgRect) {
            lastMethod = "CGDisplay"
            return image
        }

        if let image = captureLegacyWindowList(rect: cgRect, onScreenBelow: true) {
            lastMethod = "CGWindowList-below"
            return image
        }

        lastMethod = "failed"
        LaunchLogger.log("All capture methods failed rect=\(cgRect)")
        return nil
    }

    @available(macOS 14.0, *)
    private func captureWithDisplayFilter(region: ScreenCaptureRegion) async -> CGImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            let display: SCDisplay?
            if let id = region.displayIDForCapture {
                display = content.displays.first { $0.displayID == id }
            } else {
                display = content.displays.first
            }

            guard let display else {
                LaunchLogger.log("SCK: display not found id=\(region.displayID ?? 0)")
                return nil
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            let local = region.localRect
            config.sourceRect = local
            config.width = max(1, Int(local.width))
            config.height = max(1, Int(local.height))
            config.showsCursor = false
            config.pixelFormat = kCVPixelFormatType_32BGRA

            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } catch {
            LaunchLogger.log("SCK capture error: \(error.localizedDescription)")
            return nil
        }
    }

    private func captureLegacyWindowList(rect: CGRect, onScreenBelow: Bool = false) -> CGImage? {
        let option: CGWindowListOption = onScreenBelow ? .optionOnScreenBelowWindow : .optionOnScreenOnly
        return CGWindowListCreateImage(
            rect,
            option,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        )
    }

    private func captureLegacyDisplay(displayID: CGDirectDisplayID, cropRect: CGRect) -> CGImage? {
        guard let fullImage = CGDisplayCreateImage(displayID) else { return nil }
        let displayBounds = CGDisplayBounds(displayID)
        let crop = CGRect(
            x: cropRect.origin.x - displayBounds.origin.x,
            y: cropRect.origin.y - displayBounds.origin.y,
            width: cropRect.width,
            height: cropRect.height
        )
        guard crop.width > 1, crop.height > 1,
              let cropped = fullImage.cropping(to: crop) else { return nil }
        return cropped
    }
}

/// Проверка разрешения на запись экрана.
enum ScreenCapturePermission {
    static func hasPermission() -> Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightScreenCaptureAccess()
        }
        return true
    }

    static func requestPermission() -> Bool {
        if #available(macOS 10.15, *) {
            return CGRequestScreenCaptureAccess()
        }
        return true
    }

    static func probeCapture(region: ScreenCaptureRegion?) async -> Bool {
        guard hasPermission() else { return false }
        if let region {
            return await ScreenCaptureService.shared.captureAsync(region: region) != nil
        }
        let probe = CGRect(x: 0, y: 0, width: 8, height: 8)
        return CGWindowListCreateImage(probe, .optionOnScreenOnly, kCGNullWindowID, []) != nil
    }
}

/// Сохраняет кадры для диагностики «записи экрана».
final class CaptureSessionRecorder {
    static let shared = CaptureSessionRecorder()

    private var sessionDir: URL?
    private var frameIndex = 0
    private let fm = FileManager.default

    private init() {}

    func startSession() {
        guard let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let dir = base.appendingPathComponent("DartBetPredictor/sessions/\(stamp)", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        sessionDir = dir
        frameIndex = 0
        LaunchLogger.log("Session recording started: \(dir.path)")
    }

    func saveFrame(_ image: CGImage, label: String) {
        guard let dir = sessionDir else { return }
        frameIndex += 1
        if frameIndex % 5 != 0 && label == "series" { return }

        let file = dir.appendingPathComponent("\(label)_\(frameIndex).png")
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: file)
    }

    func stopSession() {
        sessionDir = nil
        frameIndex = 0
    }

    var sessionPath: String? {
        sessionDir?.path
    }
}

extension CGImage {
    func toNSImage() -> NSImage {
        NSImage(cgImage: self, size: NSSize(width: width, height: height))
    }
}
