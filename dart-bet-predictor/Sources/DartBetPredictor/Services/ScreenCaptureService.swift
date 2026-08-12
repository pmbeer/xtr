import AppKit
import CoreGraphics
import Foundation

/// Захват выбранной области экрана через CGWindowListCreateImage.
final class ScreenCaptureService {
    static let shared = ScreenCaptureService()

    private init() {}

    func capture(region: CGRect) -> CGImage? {
        guard region.width > 1, region.height > 1 else { return nil }

        let displayID = CGMainDisplayID()
        guard let image = CGWindowListCreateImage(
            region,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            return nil
        }

        _ = displayID
        return image
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
}
