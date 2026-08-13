import Foundation
import CoreGraphics
import Vision

/// OCR истории попаданий из зоны «СЕРИЯ» (кружки с числами)
enum ResultsHistoryScanner {
    /// Читает последовательность бросков в порядке отображения на экране
    static func extract(from image: CGImage?) -> [Int] {
        guard let image else { return [] }
        let scaled = upscale(image, factor: 2.8) ?? image

        let fast = VisionTextScanner.scan(scaled, fast: true)
        let accurate = VisionTextScanner.scan(scaled, fast: false)
        let items = VisionTextScanner.merge(fast, accurate)

        var cells: [(value: Int, x: Double, y: Double, conf: Float)] = []
        for item in items {
            let values = numbers(from: item.text)
            let cx = Double(item.boundingBox.midX)
            let cy = Double(item.boundingBox.midY)
            for v in values {
                cells.append((v, cx, cy, item.confidence))
            }
        }

        cells = dedupeCells(cells)
        guard !cells.isEmpty else { return [] }

        // Vision: origin снизу — выше на экране = больше y
        cells.sort { a, b in
            if abs(a.y - b.y) > 0.055 {
                return a.y > b.y
            }
            return a.x < b.x
        }

        return cells.map(\.value)
    }

    static func toDetectedNumbers(_ history: [Int]) -> [DetectedNumber] {
        history.enumerated().map { idx, value in
            DetectedNumber(
                value: value,
                boundingBox: CGRect(x: CGFloat(idx) * 0.04, y: 0.5, width: 0.03, height: 0.03),
                confidence: 0.9
            )
        }
    }

    private static func numbers(from text: String) -> [Int] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let v = Int(trimmed), DartConstants.validNumbers.contains(v) {
            return [v]
        }
        guard let regex = try? NSRegularExpression(pattern: #"\b(\d{1,2})\b"#) else { return [] }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        return regex.matches(in: trimmed, range: range).compactMap { match -> Int? in
            guard let r = Range(match.range(at: 1), in: trimmed) else { return nil }
            let v = Int(trimmed[r])
            guard let v, DartConstants.validNumbers.contains(v) else { return nil }
            return v
        }
    }

    private static func dedupeCells(_ cells: [(value: Int, x: Double, y: Double, conf: Float)]) -> [(value: Int, x: Double, y: Double, conf: Float)] {
        var kept: [(value: Int, x: Double, y: Double, conf: Float)] = []
        for cell in cells {
            let duplicate = kept.contains { existing in
                abs(existing.x - cell.x) < 0.045 && abs(existing.y - cell.y) < 0.055
            }
            if !duplicate {
                kept.append(cell)
            }
        }
        return kept
    }

    private static func upscale(_ image: CGImage, factor: CGFloat) -> CGImage? {
        let w = max(1, Int(CGFloat(image.width) * factor))
        let h = max(1, Int(CGFloat(image.height) * factor))
        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()
    }
}
