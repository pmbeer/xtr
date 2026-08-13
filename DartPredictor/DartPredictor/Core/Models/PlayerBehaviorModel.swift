import Foundation

/// Model D — player behavior correlation
final class PlayerBehaviorModel: PredictionModel {
    let type: PredictionModelType = .playerBehavior
    private var featureResultMap: [[Double]: [Int: Int]] = [:]
    private let bucketSize = 0.15

    func predict(history: [Int], features: PlayerFeatures) -> [Int: Double] {
        let bucket = bucketize(features.vector)
        let counts = featureResultMap[bucket] ?? [:]

        if counts.isEmpty {
            return behaviorHeuristic(features)
        }

        let total = counts.values.reduce(0, +)
        var scores: [Int: Double] = [:]
        for (num, count) in counts {
            scores[num] = Double(count) / Double(total)
        }
        return normalize(scores)
    }

    func update(actual: Int, history: [Int], features: PlayerFeatures, wasCorrect: Bool) {
        let bucket = bucketize(features.vector)
        if featureResultMap[bucket] == nil { featureResultMap[bucket] = [:] }
        featureResultMap[bucket]![actual, default: 0] += 1
    }

    private func bucketize(_ vector: [Double]) -> [Double] {
        vector.map { round($0 / bucketSize) * bucketSize }
    }

    private func behaviorHeuristic(_ features: PlayerFeatures) -> [Int: Double] {
        var scores = DartConstants.validNumbers.reduce(into: [Int: Double]()) { $0[$1] = 1.0 / 20.0 }

        let speedFactor = min(features.swingSpeed * 2, 1.0)
        let heightFactor = features.armHeight

        for num in DartConstants.validNumbers {
            let numFactor = Double(num) / 20.0
            let alignment = abs(numFactor - heightFactor) + abs(numFactor - speedFactor) * 0.5
            scores[num] = max(0.01, 1.0 - alignment)
        }

        return normalize(scores)
    }

    private func normalize(_ scores: [Int: Double]) -> [Int: Double] {
        let total = scores.values.reduce(0, +)
        guard total > 0 else { return scores }
        return scores.mapValues { $0 / total }
    }
}
