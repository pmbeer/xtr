import AppKit
import CoreGraphics
import Foundation

/// Захват выбранной области экрана.
final class ScreenCaptureService {
    static let shared = ScreenCaptureService()

    private init() {}

    func capture(region: ScreenCaptureRegion) -> CGImage? {
        let cgRect = region.cgCaptureRect()
        guard cgRect.width > 1, cgRect.height > 1 else { return nil }

        if let image = captureWindowList(rect: cgRect) {
            return image
        }

        if let displayID = region.displayIDForCapture,
           let image = captureDisplay(displayID: displayID, cropRect: cgRect) {
            return image
        }

        return captureWindowList(rect: cgRect, onScreenBelow: true)
    }

  /// Legacy API — CGRect в глобальных координатах.
    func capture(region: CGRect) -> CGImage? {
        guard region.width > 1, region.height > 1 else { return nil }
        if let image = captureWindowList(rect: region) { return image }
        return captureWindowList(rect: region, onScreenBelow: true)
    }

    private func captureWindowList(rect: CGRect, onScreenBelow: Bool = false) -> CGImage? {
        let option: CGWindowListOption = onScreenBelow ? .optionOnScreenBelowWindow : .optionOnScreenOnly
        return CGWindowListCreateImage(
            rect,
            option,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        )
    }

    /// Fallback: снимок дисплея и обрезка по глобальным координатам.
    private func captureDisplay(displayID: CGDirectDisplayID, cropRect: CGRect) -> CGImage? {
        guard let fullImage = CGDisplayCreateImage(displayID) else { return nil }

        let displayBounds = CGDisplayBounds(displayID)
        let localX = cropRect.origin.x - displayBounds.origin.x
        let localY = cropRect.origin.y - displayBounds.origin.y

        let crop = CGRect(
            x: localX,
            y: localY,
            width: cropRect.width,
            height: cropRect.height
        )

        guard crop.width > 1, crop.height > 1,
              let cropped = fullImage.cropping(to: crop) else { return nil }
        return cropped
    }

    /// Конвертирует координаты SwiftUI (origin top-left) в CG (origin bottom-left).
    static func cgRect(from swiftUIRect: CGRect, screenHeight: CGFloat) -> CGRect {
        CGRect(
            x: swiftUIRect.origin.x,
            y: screenHeight - swiftUIRect.origin.y - swiftUIRect.height,
            width: swiftUIRect.width,
            height: swiftUIRect.height
        )
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

    /// Пробный захват — иногда preflight ложноположительный до первого реального снимка.
    static func verifyWithProbe() -> Bool {
        guard hasPermission() else { return false }
        let probe = CGRect(x: 0, y: 0, width: 4, height: 4)
        return CGWindowListCreateImage(probe, .optionOnScreenOnly, kCGNullWindowID, []) != nil
    }
}
