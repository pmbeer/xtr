import Foundation
import Vision
import CoreGraphics

struct VisionTextItem {
    let text: String
    let boundingBox: CGRect
    let confidence: Float
}

/// Общий OCR сканер для Vision
enum VisionTextScanner {
    static func scan(image: CGImage) -> [VisionTextItem] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US", "ru-RU"]
        request.minimumTextHeight = 0.006

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do { try handler.perform([request]) } catch { return [] }

        guard let observations = request.results else { return [] }

        return observations.compactMap { obs -> VisionTextItem? in
            guard let c = obs.topCandidates(1).first else { return nil }
            let text = c.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return VisionTextItem(text: text, boundingBox: obs.boundingBox, confidence: c.confidence)
        }
    }

    static func extractDartNumbers(from items: [VisionTextItem]) -> [DetectedNumber] {
        var detected: [DetectedNumber] = []
        var seen = Set<Int>()

        for item in items {
            let values: [Int]
            if let v = Int(item.text), DartConstants.validNumbers.contains(v) {
                values = [v]
            } else {
                values = extractAllNumbers(from: item.text)
            }
            for value in values where !seen.contains(value) {
                seen.insert(value)
                detected.append(DetectedNumber(
                    value: value,
                    boundingBox: item.boundingBox,
                    confidence: item.confidence
                ))
            }
        }
        return detected
    }

    private static func extractAllNumbers(from text: String) -> [Int] {
        let pattern = #"\b(\d{1,2})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match -> Int? in
            guard let r = Range(match.range(at: 1), in: text) else { return nil }
            let value = Int(text[r])
            guard let value, DartConstants.validNumbers.contains(value) else { return nil }
            return value
        }
    }
}
