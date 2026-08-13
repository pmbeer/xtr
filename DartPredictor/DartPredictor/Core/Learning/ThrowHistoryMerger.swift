import Foundation

/// Объединяет сохранённую историю бросков с live OCR с экрана
enum ThrowHistoryMerger {
    static func merge(stored: [Int], liveOCR: [Int]) -> [Int] {
        if liveOCR.isEmpty { return stored }
        if stored.isEmpty { return liveOCR }

        var bestOverlap = 0
        let maxOverlap = min(stored.count, liveOCR.count)
        for overlap in 0...maxOverlap {
            let suffix = stored.suffix(overlap)
            let prefix = liveOCR.prefix(overlap)
            if Array(suffix) == Array(prefix) {
                bestOverlap = overlap
            }
        }

        if bestOverlap > 0 {
            return stored + Array(liveOCR.dropFirst(bestOverlap))
        }

        if liveOCR.count >= 4 {
            let prefix = Array(stored.suffix(min(40, stored.count)))
            return prefix + liveOCR
        }

        return stored + liveOCR
    }

    /// Частоты «что выпадало после» последних N бросков
    static func followUpScores(from history: [Int], depth: Int = 5) -> [Int: Double] {
        guard history.count >= 2 else { return [:] }

        var counts: [Int: Int] = [:]
        let tail = Array(history.suffix(depth))
        for i in 0..<(history.count - 1) {
            let prev = history[i]
            guard tail.contains(prev) || i >= history.count - depth - 1 else { continue }
            let next = history[i + 1]
            counts[next, default: 0] += 1
        }

        let total = counts.values.reduce(0, +)
        guard total > 0 else { return [:] }
        return counts.mapValues { Double($0) / Double(total) }
    }
}
