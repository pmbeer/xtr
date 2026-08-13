import CoreGraphics
import Foundation
import Vision

/// Читает таймер ставки на экране FONBET (~10 сек) и синхронизирует окно прогноза.
final class BettingTimerDetector {
    static let shared = BettingTimerDetector()

    private var readings: [(Date, Double)] = []
    private let queue = DispatchQueue(label: "dartbet.timer", qos: .userInitiated)

    private init() {}

    var latestSeconds: Double? {
        readings.last.map(\.1)
    }

    /// Оценка длительности окна ставки по наблюдениям (обычно ~10 с).
    var estimatedWindowSeconds: Double {
        let values = readings.map(\.1)
        guard !values.isEmpty else { return 10.0 }
        let peak = values.max() ?? 10
        return min(15, max(6, peak))
    }

    func reset() {
        readings.removeAll()
    }

    func observeOCRTexts(_ texts: [String]) {
        for text in texts {
            if let sec = parseTimerValue(text) {
                record(sec)
            }
        }
    }

    func parseTimer(from image: CGImage, completion: @escaping (Double?) -> Void) {
        queue.async {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .fast
            request.usesLanguageCorrection = false
            request.minimumTextHeight = 0.02

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            var best: Double?
            for obs in request.results ?? [] {
                guard let text = obs.topCandidates(1).first?.string else { continue }
                if let v = self.parseTimerValue(text) {
                    best = max(best ?? 0, v)
                }
            }

            DispatchQueue.main.async {
                if let best { self.record(best) }
                completion(best)
            }
        }
    }

    private func record(_ seconds: Double) {
        readings.append((Date(), seconds))
        if readings.count > 30 { readings.removeFirst() }
        LaunchLogger.log("Timer OCR: \(seconds)s")
    }

    private func parseTimerValue(_ text: String) -> Double? {
        let trimmed = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        if trimmed.contains(":") {
            let parts = trimmed.split(separator: ":")
            if parts.count == 2,
               let m = Double(parts[0]),
               let s = Double(parts[1]) {
                let total = m * 60 + s
                if total >= 1 && total <= 15 { return total }
            }
            return nil
        }

        guard trimmed.count <= 5 else { return nil }
        let filtered = trimmed.filter { $0.isNumber || $0 == "." }
        guard let value = Double(filtered), value >= 1, value <= 15 else { return nil }

        // Не путать с секторами дартс (1–20) в панели СЕРИЯ — таймер обычно с десятичной частью или целое ≤15
        if value > 15 { return nil }
        if value > 20 { return nil }
        if trimmed.contains(".") || value <= 15 {
            return value
        }
        return nil
    }
}
