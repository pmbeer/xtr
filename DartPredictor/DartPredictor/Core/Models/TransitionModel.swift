import Foundation

/// Model C — transition table (previous → next)
final class TransitionModel: PredictionModel {
    let type: PredictionModelType = .transition
    private var transitions: [Int: [Int: Int]] = [:]

    func predict(history: [Int], features: PlayerFeatures) -> [Int: Double] {
        guard let last = history.last else { return uniformDistribution() }

        let nextCounts = transitions[last] ?? [:]
        guard !nextCounts.isEmpty else { return uniformDistribution() }

        let total = nextCounts.values.reduce(0, +)
        var scores: [Int: Double] = [:]
        for (num, count) in nextCounts {
            scores[num] = Double(count) / Double(total)
        }

        for num in DartConstants.validNumbers where scores[num] == nil {
            scores[num] = 0.01 / Double(DartConstants.validNumbers.count)
        }

        return normalize(scores)
    }

    func update(actual: Int, history: [Int], features: PlayerFeatures, wasCorrect: Bool) {
        guard let prev = history.last else { return }
        if transitions[prev] == nil { transitions[prev] = [:] }
        transitions[prev]![actual, default: 0] += 1
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
