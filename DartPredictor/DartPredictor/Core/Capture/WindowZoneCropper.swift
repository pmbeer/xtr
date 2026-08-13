import Foundation
import CoreGraphics

/// Обрезка зон внутри захваченного окна
enum WindowZoneCropper {
    static func crop(image: CGImage, zone: NormalizedRect) -> CGImage? {
        let size = CGSize(width: image.width, height: image.height)
        let rect = zone.cgRect(for: size)
        guard rect.width >= 20, rect.height >= 20 else { return nil }
        return image.cropping(to: rect)
    }

    static func computeMotion(image: CGImage?, previousBytes: inout [UInt8]?) -> Double {
        guard let image,
              let data = image.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return 0 }

        let count = CFDataGetLength(data)
        let current = Array(UnsafeBufferPointer(start: bytes, count: count))

        guard let prev = previousBytes, prev.count == current.count else {
            previousBytes = current
            return 0
        }

        var diff: Double = 0
        let step = 24
        var samples = 0
        for i in Swift.stride(from: 0, to: current.count, by: step) {
            diff += Double(abs(Int(current[i]) - Int(prev[i])))
            samples += 1
        }
        previousBytes = current
        return samples > 0 ? diff / Double(samples) / 255.0 : 0
    }
}
