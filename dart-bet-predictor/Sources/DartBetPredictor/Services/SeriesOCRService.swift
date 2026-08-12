import CoreGraphics
import Foundation
import Vision

/// Читает числа из области «СЕРИЯ» (история бросков) с помощью Vision OCR.
final class SeriesOCRService {
    static let shared = SeriesOCRService()

    private let queue = DispatchQueue(label: "dartbet.ocr", qos: .userInitiated)
    private var lastParseTime: CFAbsoluteTime = 0

    private init() {}

    struct ParseResult {
        let sectors: [DartSector]
        let rawTexts: [String]
        let parseDurationMs: Double
    }

    func parseSeries(from image: CGImage, completion: @escaping (ParseResult?) -> Void) {
        queue.async {
            let start = CFAbsoluteTimeGetCurrent()

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .fast
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-US", "ru-RU"]
            request.minimumTextHeight = 0.02

            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let observations = request.results ?? []
            let sorted = observations
                .compactMap { obs -> (CGRect, String)? in
                    guard let text = obs.topCandidates(1).first?.string else { return nil }
                    return (obs.boundingBox, text)
                }
                .sorted { $0.0.midX > $1.0.midX }

            var sectors: [DartSector] = []
            var rawTexts: [String] = []

            for (_, text) in sorted {
                let cleaned = text
                    .replacingOccurrences(of: "O", with: "0")
                    .replacingOccurrences(of: "o", with: "0")
                    .replacingOccurrences(of: "l", with: "1")
                    .replacingOccurrences(of: "I", with: "1")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if let sector = Self.parseSector(from: cleaned) {
                    sectors.append(sector)
                    rawTexts.append(cleaned)
                }
            }

            let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
            let result = ParseResult(sectors: sectors, rawTexts: rawTexts, parseDurationMs: duration)

            DispatchQueue.main.async {
                completion(result)
            }
        }
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
}
