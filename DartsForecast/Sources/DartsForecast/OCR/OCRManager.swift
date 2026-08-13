import Foundation
import Vision
import CoreGraphics

struct OCRReading: Sendable {
    let number: DartNumber?
    let rawText: String
    let confidence: Float
}

/// OCR только области результата. Лёгкий, без GPU-моделей.
actor OCRManager {
    private var busy = false

    func recognize(image: CGImage) async -> OCRReading {
        if busy {
            return OCRReading(number: nil, rawText: "", confidence: 0)
        }
        busy = true
        defer { busy = false }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        // Только цифры ускоряют и снижают ошибки.
        if #available(macOS 13.0, *) {
            request.customWords = (1...20).map(String.init) + ["25", "BULL"]
        }

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            DebugLog.error("OCR Vision error: \(error)")
            return OCRReading(number: nil, rawText: "", confidence: 0)
        }

        let observations = request.results ?? []
        var bestNumber: DartNumber?
        var bestConf: Float = 0
        var rawParts: [String] = []

        for obs in observations {
            guard let candidate = obs.topCandidates(1).first else { continue }
            rawParts.append(candidate.string)
            if let num = DartNumber.parseOCR(candidate.string), candidate.confidence >= bestConf {
                bestNumber = num
                bestConf = candidate.confidence
            }
        }

        // Если Vision дал несколько чисел — берём самое правое/последнее (часто «серия»).
        if bestNumber == nil {
            for part in rawParts.reversed() {
                let tokens = part.split(whereSeparator: { !$0.isNumber && $0 != "B" && $0 != "U" && $0 != "L" })
                for token in tokens.reversed() {
                    if let n = DartNumber.parseOCR(String(token)) {
                        bestNumber = n
                        bestConf = 0.4
                        break
                    }
                }
                if bestNumber != nil { break }
            }
        }

        return OCRReading(number: bestNumber, rawText: rawParts.joined(separator: " "), confidence: bestConf)
    }
}
