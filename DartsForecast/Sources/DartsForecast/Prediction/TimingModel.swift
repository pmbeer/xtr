import Foundation

/// Модель E — временные паттерны (интервал, подготовка, ритм).
final class TimingModel: PredictionModel {
    let kind: ModelKind = .timing

    private struct State: Codable {
        var intervalBucketToOutcome: [Int: [Int: Int]] = [:]
        var prepBucketToOutcome: [Int: [Int: Int]] = [:]
        var recentIntervals: [Double] = []
    }

    private var state = State()

    func score(history: [Int], features: PlayerFeatures) -> [Int: Double] {
        var scores = Dictionary(uniqueKeysWithValues: DartNumber.scoringValues.map { ($0, 0.05) })

        let intervalBucket = bucket(features.intervalSeconds, step: 1.5, max: 12)
        if let row = state.intervalBucketToOutcome[intervalBucket] {
            let total = Double(row.values.reduce(0, +))
            if total > 0 {
                for (num, c) in row {
                    scores[num, default: 0] += Double(c) / total * 1.5
                }
            }
        }

        let prepBucket = bucket(features.prepDuration, step: 0.5, max: 8)
        if let row = state.prepBucketToOutcome[prepBucket] {
            let total = Double(row.values.reduce(0, +))
            if total > 0 {
                for (num, c) in row {
                    scores[num, default: 0] += Double(c) / total * 1.0
                }
            }
        }

        // Отклонение от среднего ритма
        if state.recentIntervals.count >= 5 {
            let mean = state.recentIntervals.reduce(0, +) / Double(state.recentIntervals.count)
            let delta = abs(features.intervalSeconds - mean)
            if delta > 2.0 {
                // При сбое ритма — слегка усиливаем «горячие» из истории.
                var local: [Int: Int] = [:]
                for n in history.suffix(10) { local[n, default: 0] += 1 }
                let t = Double(local.values.reduce(0, +))
                if t > 0 {
                    for (n, c) in local {
                        scores[n, default: 0] += Double(c) / t * 0.5
                    }
                }
            }
        }
        return scores
    }

    func learn(previous: [Int], actual: Int, features: PlayerFeatures, wasInTop4: Bool) {
        let intervalBucket = bucket(features.intervalSeconds, step: 1.5, max: 12)
        let prepBucket = bucket(features.prepDuration, step: 0.5, max: 8)
        state.intervalBucketToOutcome[intervalBucket, default: [:]][actual, default: 0] += 1
        state.prepBucketToOutcome[prepBucket, default: [:]][actual, default: 0] += 1
        state.recentIntervals.append(features.intervalSeconds)
        if state.recentIntervals.count > 100 {
            state.recentIntervals.removeFirst(state.recentIntervals.count - 100)
        }
    }

    private func bucket(_ value: Double, step: Double, maxBucket: Int) -> Int {
        Swift.min(maxBucket, Swift.max(0, Int(value / step)))
    }

    func exportState() -> Data {
        (try? JSONEncoder().encode(state)) ?? Data()
    }

    func importState(_ data: Data) {
        if let s = try? JSONDecoder().decode(State.self, from: data) {
            state = s
        }
    }
}
