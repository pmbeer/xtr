import Foundation

/// Модель D — связь визуальных признаков с результатом.
public final class PlayerBehaviorModel: PredictionModel {
    let kind: ModelKind = .playerBehavior

    private struct State: Codable {
        var keyToOutcome: [String: [Int: Int]] = [:]
        var phaseToOutcome: [Int: [Int: Int]] = [:]
        var leanBucketToOutcome: [Int: [Int: Int]] = [:]
    }

    private var state = State()

    func score(history: [Int], features: PlayerFeatures) -> [Int: Double] {
        var scores = Dictionary(uniqueKeysWithValues: DartNumber.scoringValues.map { ($0, 0.05) })

        if let row = state.keyToOutcome[features.behaviorKey] {
            let total = Double(row.values.reduce(0, +))
            if total > 0 {
                for (num, c) in row {
                    scores[num, default: 0] += Double(c) / total * 3.0
                }
            }
        }

        if let row = state.phaseToOutcome[features.throwPhase] {
            let total = Double(row.values.reduce(0, +))
            if total > 0 {
                for (num, c) in row {
                    scores[num, default: 0] += Double(c) / total * 0.8
                }
            }
        }

        let leanBucket = Int((features.torsoLean * 3).rounded())
        if let row = state.leanBucketToOutcome[leanBucket] {
            let total = Double(row.values.reduce(0, +))
            if total > 0 {
                for (num, c) in row {
                    scores[num, default: 0] += Double(c) / total * 0.6
                }
            }
        }

        // Если тела нет — модель почти нейтральна.
        if !features.bodyDetected {
            return scores.mapValues { $0 * 0.3 + 0.05 }
        }
        return scores
    }

    func learn(previous: [Int], actual: Int, features: PlayerFeatures, wasInTop4: Bool) {
        var f = features
        if f.behaviorKey.isEmpty || f.behaviorKey == "unknown" {
            f.recomputeKey()
        }
        state.keyToOutcome[f.behaviorKey, default: [:]][actual, default: 0] += 1
        state.phaseToOutcome[f.throwPhase, default: [:]][actual, default: 0] += 1
        let leanBucket = Int((f.torsoLean * 3).rounded())
        state.leanBucketToOutcome[leanBucket, default: [:]][actual, default: 0] += 1

        if state.keyToOutcome.count > 4000 {
            let drop = Array(state.keyToOutcome.keys.prefix(500))
            for k in drop { state.keyToOutcome.removeValue(forKey: k) }
        }
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
