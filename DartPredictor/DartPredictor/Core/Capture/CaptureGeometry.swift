import Foundation
import CoreGraphics
import ScreenCaptureKit

/// Конвертация координат NSScreen → CIImage (ScreenCaptureKit)
enum CaptureGeometry {
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

        // Локальные координаты внутри дисплея (bottom-left origin)
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
