import Foundation

protocol PredictionModel {
    var type: PredictionModelType { get }
    func predict(history: [Int], features: PlayerFeatures) -> [Int: Double]
    func update(actual: Int, history: [Int], features: PlayerFeatures, wasCorrect: Bool)
}

/// Model A — sequence pattern analysis
final class SequenceModel: PredictionModel {
    let type: PredictionModelType = .sequence
    private var patternCounts: [String: [Int: Int]] = [:]

    func predict(history: [Int], features: PlayerFeatures) -> [Int: Double] {
        guard !history.isEmpty else { return uniformDistribution() }

        var scores: [Int: Double] = [:]
        for window in DartConstants.sequenceWindows {
            guard history.count >= window else { continue }
            let pattern = history.suffix(window).map(String.init).joined(separator: ",")
            let counts = patternCounts[pattern] ?? [:]
            let total = counts.values.reduce(0, +)
            guard total > 0 else { continue }

            let weight = Double(window) / 50.0
            for (num, count) in counts {
                scores[num, default: 0] += Double(count) / Double(total) * weight
            }
        }

        if scores.isEmpty { return uniformDistribution() }
        return normalize(scores)
    }

    func update(actual: Int, history: [Int], features: PlayerFeatures, wasCorrect: Bool) {
        for window in DartConstants.sequenceWindows {
            guard history.count >= window else { continue }
            let pattern = history.suffix(window).map(String.init).joined(separator: ",")
            if patternCounts[pattern] == nil { patternCounts[pattern] = [:] }
            patternCounts[pattern]![actual, default: 0] += 1
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
