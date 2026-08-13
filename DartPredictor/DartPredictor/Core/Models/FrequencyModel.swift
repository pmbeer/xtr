import Foundation

/// Model B — frequency analysis (hot/cold numbers)
final class FrequencyModel: PredictionModel {
    let type: PredictionModelType = .frequency
    private var numberCounts: [Int: Int] = [:]
    private var lastAppearance: [Int: Int] = [:]
    private var afterPrevious: [Int: [Int: Int]] = [:]

    func predict(history: [Int], features: PlayerFeatures) -> [Int: Double] {
        guard !history.isEmpty else { return uniformDistribution() }

        let total = history.count
        var scores: [Int: Double] = [:]
        let currentIndex = history.count

        for num in DartConstants.validNumbers {
            let count = numberCounts[num] ?? 0
            let freq = Double(count) / Double(total)

            let sinceLast = currentIndex - (lastAppearance[num] ?? 0)
            let recencyBonus = min(Double(sinceLast) / Double(total), 1.0) * 0.3

            var transitionBonus = 0.0
            if let last = history.last,
               let transitions = afterPrevious[last],
               let nextCount = transitions[num] {
                let transTotal = transitions.values.reduce(0, +)
                transitionBonus = Double(nextCount) / Double(transTotal) * 0.4
            }

            scores[num] = freq * 0.6 + recencyBonus + transitionBonus
        }

        return normalize(scores)
    }

    func update(actual: Int, history: [Int], features: PlayerFeatures, wasCorrect: Bool) {
        numberCounts[actual, default: 0] += 1
        lastAppearance[actual] = history.count

        if let prev = history.last {
            if afterPrevious[prev] == nil { afterPrevious[prev] = [:] }
            afterPrevious[prev]![actual, default: 0] += 1
        }
    }

    private func uniformDistribution() -> [Int: Double] {
        let count = DartConstants.validNumbers.count
        return DartConstants.validNumbers.reduce(into: [:]) { $0[$1] = 1.0 / Double(count) }
    }

    private func normalize(_ scores: [Int: Double]) -> [Int: Double] {
        let total = scores.values.reduce(0, +)
        guard total > 0 else { return scores }
        return scores.mapValues { $0 / total }
    }
}
