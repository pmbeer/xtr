import Foundation

/// Model E — timing patterns
final class TimingModel: PredictionModel {
    let type: PredictionModelType = .timing
    private var intervalResultMap: [Double: [Int: Int]] = [:]
    private var prepDurationMap: [Double: [Int: Int]] = [:]
    private let bucketSize = 0.5

    func predict(history: [Int], features: PlayerFeatures) -> [Int: Double] {
        var scores = DartConstants.validNumbers.reduce(into: [Int: Double]()) { $0[$1] = 0 }

        let intervalBucket = round(features.intervalSinceLastThrow / bucketSize) * bucketSize
        if let counts = intervalResultMap[intervalBucket] {
            let total = counts.values.reduce(0, +)
            for (num, count) in counts {
                scores[num, default: 0] += Double(count) / Double(total) * 0.5
            }
        }

        let prepBucket = round(features.preparationDuration / bucketSize) * bucketSize
        if let counts = prepDurationMap[prepBucket] {
            let total = counts.values.reduce(0, +)
            for (num, count) in counts {
                scores[num, default: 0] += Double(count) / Double(total) * 0.5
            }
        }

        let rhythmScore = rhythmBasedScores(history: history, features: features)
        for (num, score) in rhythmScore {
            scores[num, default: 0] += score * 0.3
        }

        let hasScores = scores.values.contains { $0 > 0 }
        if !hasScores { return uniformDistribution() }
        return normalize(scores)
    }

    func update(actual: Int, history: [Int], features: PlayerFeatures, wasCorrect: Bool) {
        let intervalBucket = round(features.intervalSinceLastThrow / bucketSize) * bucketSize
        if intervalResultMap[intervalBucket] == nil { intervalResultMap[intervalBucket] = [:] }
        intervalResultMap[intervalBucket]![actual, default: 0] += 1

        let prepBucket = round(features.preparationDuration / bucketSize) * bucketSize
        if prepDurationMap[prepBucket] == nil { prepDurationMap[prepBucket] = [:] }
        prepDurationMap[prepBucket]![actual, default: 0] += 1
    }

    private func rhythmBasedScores(history: [Int], features: PlayerFeatures) -> [Int: Double] {
        guard history.count >= 5 else { return [:] }

        var scores: [Int: Double] = [:]
        let recent = Array(history.suffix(10))
        for num in DartConstants.validNumbers {
            let appearances = recent.enumerated().filter { $0.element == num }.map { $0.offset }
            if appearances.count >= 2 {
                let intervals = zip(appearances.dropFirst(), appearances).map { $0 - $1 }
                let avgInterval = Double(intervals.reduce(0, +)) / Double(intervals.count)
                let currentGap = Double(recent.count - 1 - (appearances.last ?? 0))
                let proximity = abs(currentGap - avgInterval)
                scores[num] = max(0, 1.0 - proximity / 10.0)
            }
        }
        return scores
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
