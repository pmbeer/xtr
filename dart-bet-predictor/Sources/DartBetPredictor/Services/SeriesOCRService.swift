import CoreGraphics
import CoreImage
import Foundation
import Vision

/// Читает числа из области «СЕРИЯ» (история бросков) с помощью Vision OCR.
final class SeriesOCRService {
    static let shared = SeriesOCRService()

    private let queue = DispatchQueue(label: "dartbet.ocr", qos: .userInitiated)

    private init() {}

    struct ParseResult {
        let sectors: [DartSector]
        let rawTexts: [String]
        let parseDurationMs: Double
        let visualChangeScore: Double
    }

    func parseSeries(from image: CGImage, completion: @escaping (ParseResult?) -> Void) {
        queue.async {
            let start = CFAbsoluteTimeGetCurrent()
            let visualScore = SeriesFrameDiff.shared.changeScore(for: image)

            var bestSectors: [DartSector] = []
            var bestRaw: [String] = []

            // Несколько проходов OCR с разной подготовкой изображения
            let variants: [(CGImage, VNRequestTextRecognitionLevel)] = [
                (image, .accurate),
                (Self.preprocess(image, mode: .contrast) ?? image, .accurate),
                (Self.preprocess(image, mode: .scale2x) ?? image, .fast)
            ]

            for (variant, level) in variants {
                let (sectors, raw) = Self.runOCR(on: variant, level: level)
                if sectors.count > bestSectors.count {
                    bestSectors = sectors
                    bestRaw = raw
                }
                if bestSectors.count >= 3 { break }
            }

            let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
            let result = ParseResult(
                sectors: bestSectors,
                rawTexts: bestRaw,
                parseDurationMs: duration,
                visualChangeScore: visualScore
            )

            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    private static func runOCR(
        on image: CGImage,
        level: VNRequestTextRecognitionLevel
    ) -> ([DartSector], [String]) {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = level
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US", "ru-RU"]
        request.minimumTextHeight = 0.008
        request.customWords = (1...20).map(String.init) + ["25", "50", "BULL", "bull"]

        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return ([], [])
        }

        let observations = request.results ?? []

        // Слева → справа (типичная панель СЕРИЯ FONBET)
        let sorted = observations
            .compactMap { obs -> (CGRect, String)? in
                guard let text = obs.topCandidates(1).first?.string else { return nil }
                return (obs.boundingBox, text)
            }
            .sorted { $0.0.midX < $1.0.midX }

        var sectors: [DartSector] = []
        var rawTexts: [String] = []

        for (_, text) in sorted {
            let cleaned = normalizeText(text)
            if let sector = parseSector(from: cleaned) {
                sectors.append(sector)
                rawTexts.append(cleaned)
            }
        }

        return (sectors, rawTexts)
    }

    private static func normalizeText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "O", with: "0")
            .replacingOccurrences(of: "o", with: "0")
            .replacingOccurrences(of: "l", with: "1")
            .replacingOccurrences(of: "I", with: "1")
            .replacingOccurrences(of: "|", with: "1")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseSector(from text: String) -> DartSector? {
        let lower = text.lowercased()

        if lower.contains("bull") || lower == "25" || lower == "50" || text == "◎" {
            return .bullseye
        }

        let digits = text.filter { $0.isNumber }
        guard !digits.isEmpty, let value = Int(digits) else { return nil }
        return DartSector.from(detected: value)
    }

    private enum PreprocessMode {
        case contrast
        case scale2x
    }

    private static func preprocess(_ image: CGImage, mode: PreprocessMode) -> CGImage? {
        let ciImage = CIImage(cgImage: image)
        let context = CIContext()

        switch mode {
        case .contrast:
            guard let filter = CIFilter(name: "CIColorControls") else { return nil }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(1.4, forKey: kCIInputContrastKey)
            filter.setValue(0.05, forKey: kCIInputBrightnessKey)
            guard let output = filter.outputImage else { return nil }
            return context.createCGImage(output, from: output.extent)

        case .scale2x:
            let scale = 2.0
            let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            return context.createCGImage(scaled, from: scaled.extent)
        }
    }
}

/// Детектор визуальных изменений в области СЕРИЯ (новый кружок появился).
final class SeriesFrameDiff {
    static let shared = SeriesFrameDiff()

    private var lastFingerprint: [UInt8]?
    private let gridSize = 24

    private init() {}

  /// 0.0 = без изменений, 1.0 = сильное изменение.
    func changeScore(for image: CGImage) -> Double {
        let fingerprint = makeFingerprint(image)
        guard let last = lastFingerprint else {
            lastFingerprint = fingerprint
            return 0
        }

        var diff: Int = 0
        for i in 0..<fingerprint.count {
            diff += abs(Int(fingerprint[i]) - Int(last[i]))
        }
        let score = Double(diff) / Double(fingerprint.count * 255)
        lastFingerprint = fingerprint
        return min(1.0, score * 4.0)
    }

    func reset() {
        lastFingerprint = nil
    }

    private func makeFingerprint(_ image: CGImage) -> [UInt8] {
        let width = gridSize
        let height = gridSize
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return pixels }

        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var gray = [UInt8]()
        for i in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let r = Double(pixels[i])
            let g = Double(pixels[i + 1])
            let b = Double(pixels[i + 2])
            gray.append(UInt8((r * 0.3 + g * 0.59 + b * 0.11).rounded()))
        }
        return gray
    }
}
