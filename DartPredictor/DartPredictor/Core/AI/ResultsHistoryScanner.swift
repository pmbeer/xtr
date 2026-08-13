import Foundation
import CoreGraphics
import Vision

/// OCR истории попаданий из зоны «СЕРИЯ» (кружки с числами)
enum ResultsHistoryScanner {
    struct Cell {
        let value: Int
        let boundingBox: CGRect
        let confidence: Float
    }

    /// Читает последовательность бросков в порядке отображения на экране
    static func extract(from image: CGImage?) -> [Int] {
        extractCells(from: image).map(\.value)
    }

    /// OCR с реальными координатами ячеек (для трекера новых попаданий)
    static func extractCells(from image: CGImage?) -> [Cell] {
        guard let image else { return [] }
        let enhanced = boostContrast(image) ?? image
        let scaled = upscale(enhanced, factor: 3.0) ?? enhanced

        let fast = VisionTextScanner.scan(image: scaled, fast: true)
        let accurate = VisionTextScanner.scan(image: scaled, fast: false)
        let items = VisionTextScanner.merge(fast, accurate)

        var cells: [(value: Int, x: Double, y: Double, conf: Float, box: CGRect)] = []
        for item in items {
            let values = numbers(from: item.text)
            let cx = Double(item.boundingBox.midX)
            let cy = Double(item.boundingBox.midY)
            for v in values {
                cells.append((v, cx, cy, item.confidence, item.boundingBox))
            }
        }

        cells = dedupeCells(cells)
        guard !cells.isEmpty else { return [] }

        // NARDBALL: горизонтальная история сверху — слева направо
        cells.sort { a, b in
            if abs(a.x - b.x) > 0.032 {
                return a.x < b.x
            }
            return a.y > b.y
        }

        return cells.map { cell in
            Cell(value: cell.value, boundingBox: cell.box, confidence: cell.conf)
        }
    }

    static func toDetectedNumbers(_ cells: [Cell]) -> [DetectedNumber] {
        cells.map { cell in
            DetectedNumber(
                value: cell.value,
                boundingBox: cell.boundingBox,
                confidence: cell.confidence
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

    private static func dedupeCells(
        _ cells: [(value: Int, x: Double, y: Double, conf: Float, box: CGRect)]
    ) -> [(value: Int, x: Double, y: Double, conf: Float, box: CGRect)] {
        var kept: [(value: Int, x: Double, y: Double, conf: Float, box: CGRect)] = []
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

    private static func boostContrast(_ image: CGImage) -> CGImage? {
        guard let ctx = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let data = ctx.data else { return nil }
        let pixels = data.bindMemory(to: UInt8.self, capacity: image.width * image.height * 4)
        let count = image.width * image.height
        for i in 0..<count {
            let offset = i * 4
            let r = Double(pixels[offset])
            let g = Double(pixels[offset + 1])
            let b = Double(pixels[offset + 2])
            let gray = 0.299 * r + 0.587 * g + 0.114 * b
            let boosted = min(255, max(0, (gray - 128) * 1.35 + 128))
            let scale = boosted / max(gray, 1)
            pixels[offset] = UInt8(min(255, r * scale))
            pixels[offset + 1] = UInt8(min(255, g * scale))
            pixels[offset + 2] = UInt8(min(255, b * scale))
        }
        return ctx.makeImage()
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
