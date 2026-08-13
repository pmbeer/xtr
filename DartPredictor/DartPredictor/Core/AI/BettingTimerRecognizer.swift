import Foundation
import CoreGraphics

/// Распознавание таймера ставки на экране (OCR)
final class BettingTimerRecognizer {
    static let shared = BettingTimerRecognizer()

    private var lastSeconds: Double?
    private var stableCount = 0

    func recognize(from image: CGImage) -> Double? {
        let texts = VisionTextScanner.scan(image: image)
        var candidates: [Double] = []

        for item in texts {
            let t = item.text
            // 10.0, 9.5, 10,0
            if let regex = try? NSRegularExpression(pattern: #"(\d{1,2})[.,](\d)"#) {
                let range = NSRange(t.startIndex..., in: t)
                if let m = regex.firstMatch(in: t, range: range),
                   let r1 = Range(m.range(at: 1), in: t),
                   let r2 = Range(m.range(at: 2), in: t) {
                    let whole = Double(t[r1]) ?? 0
                    let frac = Double(t[r2]) ?? 0
                    let sec = whole + frac / 10.0
                    if sec >= 0 && sec <= 60 { candidates.append(sec) }
                }
            }
            // целые секунды 6-15
            if let regex = try? NSRegularExpression(pattern: #"\b(\d{1,2})\b"#) {
                let range = NSRange(t.startIndex..., in: t)
                let matches = regex.matches(in: t, range: range)
                for match in matches {
                    if let r = Range(match.range(at: 1), in: t),
                       let v = Double(t[r]), v >= 3 && v <= 30 {
                        candidates.append(v)
                    }
                }
            }
        }

        guard let best = candidates.min() else {
            stableCount = 0
            return lastSeconds
        }

        if best == lastSeconds {
            stableCount += 1
        } else {
            lastSeconds = best
            stableCount = 1
        }

        return stableCount >= 1 ? best : nil
    }

    func reset() {
        lastSeconds = nil
        stableCount = 0
    }
}
