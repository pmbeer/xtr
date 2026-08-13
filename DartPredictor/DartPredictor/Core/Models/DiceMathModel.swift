import Foundation

/// Математическая модель NARDBALL: красная и синяя кость + переходы по сетке 1–36
final class DiceMathModel: PredictionModel {
    let type: PredictionModelType = .diceMath

    private var redTransitions: [Int: [Int: Int]] = [:]
    private var blueTransitions: [Int: [Int: Int]] = [:]
    private var gridTransitions: [Int: [Int: Int]] = [:]

    func predict(history: [Int], features: PlayerFeatures) -> [Int: Double] {
        guard !history.isEmpty else {
            return uniformScores()
        }

        let (reds, blues) = DiceMath.decomposeHistory(history)
        let redScores = markovScores(sequence: reds, table: redTransitions)
        let blueScores = markovScores(sequence: blues, table: blueTransitions)

        var scores: [Int: Double] = [:]
        for num in DartConstants.validNumbers {
            let r = DiceMath.red(from: num)
            let b = DiceMath.blue(from: num)
            scores[num] = (redScores[r] ?? 1.0 / 6.0) * (blueScores[b] ?? 1.0 / 6.0)
        }

        if let last = history.last {
            let gridFollow = markovScores(sequence: history, table: gridTransitions, lastOnly: last)
            for (num, prob) in gridFollow {
                scores[num, default: 0] += prob * 0.42
            }
        }

        applyDieFrequencyBoost(scores: &scores, reds: reds, blues: blues)
        return normalize(scores)
    }

    func update(actual: Int, history: [Int], features: PlayerFeatures, wasCorrect: Bool) {
        let r = DiceMath.red(from: actual)
        let b = DiceMath.blue(from: actual)

        if let prevR = history.last.map({ DiceMath.red(from: $0) }) {
            redTransitions[prevR, default: [:]][r, default: 0] += 1
        }
        if let prevB = history.last.map({ DiceMath.blue(from: $0) }) {
            blueTransitions[prevB, default: [:]][b, default: 0] += 1
        }
        if let last = history.last {
            gridTransitions[last, default: [:]][actual, default: 0] += 1
        }
    }

    private func markovScores(
        sequence: [Int],
        table: [Int: [Int: Int]],
        lastOnly: Int? = nil
    ) -> [Int: Double] {
        let anchor = lastOnly ?? sequence.last
        guard let anchor else {
            return frequencyScores(sequence: sequence, domain: Set(1...6))
        }

        let transitions = table[anchor] ?? [:]
        if !transitions.isEmpty {
            let total = transitions.values.reduce(0, +)
            var scores: [Int: Double] = [:]
            for (value, count) in transitions {
                scores[value] = Double(count) / Double(total)
            }
            return scores
        }

        return frequencyScores(sequence: sequence, domain: Set(1...6))
    }

    private func frequencyScores(sequence: [Int], domain: Set<Int>) -> [Int: Double] {
        var counts: [Int: Int] = [:]
        for v in sequence { counts[v, default: 0] += 1 }
        let total = counts.values.reduce(0, +)
        guard total > 0 else {
            return domain.reduce(into: [:]) { $0[$1] = 1.0 / Double(domain.count) }
        }
        var scores: [Int: Double] = [:]
        for face in domain {
            scores[face] = Double(counts[face] ?? 0) / Double(total)
        }
        return scores
    }

    private func applyDieFrequencyBoost(
        scores: inout [Int: Double],
        reds: [Int],
        blues: [Int]
    ) {
        let recentR = Array(reds.suffix(8))
        let recentB = Array(blues.suffix(8))
        var coldR: Set<Int> = Set(1...6)
        var coldB: Set<Int> = Set(1...6)
        for r in recentR { coldR.remove(r) }
        for b in recentB { coldB.remove(b) }

        for num in DartConstants.validNumbers {
            let r = DiceMath.red(from: num)
            let b = DiceMath.blue(from: num)
            if coldR.contains(r) { scores[num, default: 0] += 0.04 }
            if coldB.contains(b) { scores[num, default: 0] += 0.04 }
        }
    }

    private func uniformScores() -> [Int: Double] {
        let count = Double(DartConstants.validNumbers.count)
        return DartConstants.validNumbers.reduce(into: [:]) { $0[$1] = 1.0 / count }
    }

    private func normalize(_ scores: [Int: Double]) -> [Int: Double] {
        let total = scores.values.reduce(0, +)
        guard total > 0 else { return scores }
        return scores.mapValues { $0 / total }
    }
}
