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

    /// Обрезка зоны с маскировкой игнорируемых областей (чёрная заливка)
    static func cropMaskingIgnored(
        image: CGImage,
        zone: NormalizedRect,
        ignoredZones: [NormalizedRect]
    ) -> CGImage? {
        let size = CGSize(width: image.width, height: image.height)
        let cropRect = zone.cgRect(for: size)
        guard cropRect.width >= 20, cropRect.height >= 20,
              let cropped = image.cropping(to: cropRect) else { return nil }

        let masks = ignoredZones
            .map { $0.cgRect(for: size).intersection(cropRect) }
            .filter { !$0.isNull && $0.width > 2 && $0.height > 2 }

        guard !masks.isEmpty else { return cropped }

        let w = Int(cropRect.width)
        let h = Int(cropRect.height)
        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return cropped }

        ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: cropRect.width, height: cropRect.height))
        ctx.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
        for mask in masks {
            let local = mask.offsetBy(dx: -cropRect.origin.x, dy: -cropRect.origin.y)
            ctx.fill(local)
        }
        return ctx.makeImage() ?? cropped
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
