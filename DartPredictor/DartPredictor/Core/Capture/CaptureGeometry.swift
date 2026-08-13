import Foundation
import CoreGraphics
import ScreenCaptureKit
import AppKit

/// Конвертация координат NSScreen → CIImage (ScreenCaptureKit) и валидация областей
enum CaptureGeometry {
    /// Объединённый frame всех мониторов (глобальные координаты, origin снизу-слева)
    static func unionOfAllScreens() -> CGRect {
        let screens = NSScreen.screens
        guard let first = screens.first else {
            return CGRect(x: 0, y: 0, width: 1920, height: 1080)
        }
        return screens.dropFirst().reduce(first.frame) { $0.union($1.frame) }
    }

    /// Монитор, содержащий центр области
    static func screenContaining(rect: CGRect) -> NSScreen? {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return NSScreen.screens.first { $0.frame.contains(center) }
    }

    /// Ограничить область внутри видимых экранов
    static func normalizeRegion(_ rect: CGRect) -> CGRect {
        let union = unionOfAllScreens()
        let clamped = rect.intersection(union)
        guard clamped.width >= 20, clamped.height >= 20 else { return rect }
        return clamped
    }

    static func isValidRegion(_ rect: CGRect) -> Bool {
        rect.width >= 20 && rect.height >= 20 && unionOfAllScreens().intersects(rect)
    }

    /// Найти дисплей, на котором находится область
    static func displayContaining(rect: CGRect, displays: [SCDisplay]) -> SCDisplay? {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        if let match = displays.first(where: { $0.frame.contains(center) }) {
            return match
        }
        return displays.first
    }

    /// Преобразовать глобальные screen-координаты в crop rect для CIImage
    static func cropRect(
        screenRect: CGRect,
        display: SCDisplay,
        imageExtent: CGRect
    ) -> CGRect {
        let displayFrame = display.frame

        let localX = screenRect.origin.x - displayFrame.origin.x
        let localY = screenRect.origin.y - displayFrame.origin.y

        let scaleX = imageExtent.width / displayFrame.width
        let scaleY = imageExtent.height / displayFrame.height

        let crop = CGRect(
            x: localX * scaleX,
            y: localY * scaleY,
            width: screenRect.width * scaleX,
            height: screenRect.height * scaleY
        )

        return crop.intersection(imageExtent)
    }

    static func isValidCrop(_ rect: CGRect) -> Bool {
        rect.width >= 10 && rect.height >= 10
    }
}
