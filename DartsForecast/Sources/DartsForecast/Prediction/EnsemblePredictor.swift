import Foundation

/// Модель F — адаптивный ансамбль независимых стратегий.
final class EnsemblePredictor: @unchecked Sendable {
    private let models: [PredictionModel]
    private let lock = NSLock()

    private(set) var weights: [ModelKind: Double]
    private var modelHits: [ModelKind: (success: Int, total: Int)] = [:]
    private let smoothing: Double = 0.12

    init(models: [PredictionModel]? = nil) {
        let built: [PredictionModel] = models ?? [
            SequenceModel(),
            FrequencyModel(),
            TransitionModel(),
            PlayerBehaviorModel(),
            TimingModel()
        ]
        self.models = built
        self.weights = Dictionary(uniqueKeysWithValues: ModelKind.allCases.map { ($0, $0.defaultWeight) })
        for k in ModelKind.allCases { modelHits[k] = (0, 0) }
    }

    func predict(history: [Int], features: PlayerFeatures) -> Top4Prediction {
        lock.lock()
        defer { lock.unlock() }

        var blended: [Int: Double] = Dictionary(uniqueKeysWithValues: DartNumber.scoringValues.map { ($0, 0.0) })
        var weightMap: [String: Double] = [:]

        for model in models {
            let w = weights[model.kind] ?? model.kind.defaultWeight
            weightMap[model.kind.rawValue] = w
            let probs = ScoreNormalizer.probabilities(from: model.score(history: history, features: features))
            for (num, p) in probs {
                blended[num, default: 0] += p * w
            }
        }

        let top = ScoreNormalizer.topN(blended, n: 4)
        let items = top.map { Top4Prediction.Item(number: $0.0, probability: $0.1) }

        let confScore = confidenceScore(top: top, blended: blended, historyCount: history.count)
        let level: ConfidenceLevel
        if confScore >= 0.62 && history.count >= 40 { level = .high }
        else if confScore >= 0.45 && history.count >= 15 { level = .medium }
        else { level = .low }

        return Top4Prediction(
            items: items,
            confidence: level,
            confidenceScore: confScore,
            createdAt: Date(),
            modelWeights: weightMap
        )
    }

    /// Онлайн-обучение всех моделей + сглаженное обновление весов.
    func learn(
        previous: [Int],
        actual: Int,
        features: PlayerFeatures,
        previousTop4: [Int]
    ) {
        lock.lock()
        defer { lock.unlock() }

        let hit = previousTop4.contains(actual)

        for model in models {
            let alone = ScoreNormalizer.topN(
                ScoreNormalizer.probabilities(from: model.score(history: previous, features: features)),
                n: 4
            ).map(\.0)
            let modelHit = alone.contains(actual)
            var stats = modelHits[model.kind] ?? (0, 0)
            stats.total += 1
            if modelHit { stats.success += 1 }
            modelHits[model.kind] = stats

            model.learn(previous: previous, actual: actual, features: features, wasInTop4: hit)
        }

        updateWeightsSmoothed()
    }

    private func updateWeightsSmoothed() {
        var raw: [ModelKind: Double] = [:]
        for kind in ModelKind.allCases {
            let s = modelHits[kind] ?? (0, 0)
            // Laplace smoothing + prior
            let rate = (Double(s.success) + 2.0) / (Double(s.total) + 10.0)
            raw[kind] = rate
        }
        let sum = raw.values.reduce(0, +)
        guard sum > 0 else { return }

        for kind in ModelKind.allCases {
            let target = (raw[kind] ?? 0) / sum
            let current = weights[kind] ?? kind.defaultWeight
            weights[kind] = current * (1 - smoothing) + target * smoothing
        }

        // Нормализация + clamp, чтобы ни одна модель не умерла.
        var wsum = weights.values.reduce(0, +)
        if wsum <= 0 { wsum = 1 }
        for kind in ModelKind.allCases {
            var w = (weights[kind] ?? kind.defaultWeight) / wsum
            w = min(0.45, max(0.05, w))
            weights[kind] = w
        }
        let finalSum = weights.values.reduce(0, +)
        for kind in ModelKind.allCases {
            weights[kind] = (weights[kind] ?? 0) / finalSum
        }
    }

    private func confidenceScore(top: [(Int, Double)], blended: [Int: Double], historyCount: Int) -> Double {
        guard let best = top.first?.1 else { return 0 }
        let second = top.dropFirst().first?.1 ?? 0
        let margin = best - second
        let entropyPenalty: Double = {
            let vals = blended.values.filter { $0 > 0 }
            let h = vals.reduce(0.0) { acc, p in
                acc - p * log2(max(p, 1e-12))
            }
            let maxH = log2(Double(max(2, blended.count)))
            return 1.0 - min(1, h / maxH)
        }()
        let dataFactor = min(1.0, Double(historyCount) / 80.0)
        return min(0.95, max(0.05, best * 0.45 + margin * 0.9 + entropyPenalty * 0.25 + dataFactor * 0.15))
    }

    // MARK: - Persistence

    struct Snapshot: Codable {
        var weights: [String: Double]
        var hits: [String: [Int]]
        var modelStates: [String: Data]
    }

    func exportSnapshot() -> Snapshot {
        lock.lock()
        defer { lock.unlock() }
        var hits: [String: [Int]] = [:]
        for (k, v) in modelHits { hits[k.rawValue] = [v.success, v.total] }
        var states: [String: Data] = [:]
        for m in models { states[m.kind.rawValue] = m.exportState() }
        return Snapshot(
            weights: Dictionary(uniqueKeysWithValues: weights.map { ($0.key.rawValue, $0.value) }),
            hits: hits,
            modelStates: states
        )
    }

    func importSnapshot(_ snap: Snapshot) {
        lock.lock()
        defer { lock.unlock() }
        for (k, v) in snap.weights {
            if let kind = ModelKind(rawValue: k) { weights[kind] = v }
        }
        for (k, arr) in snap.hits where arr.count == 2 {
            if let kind = ModelKind(rawValue: k) {
                modelHits[kind] = (arr[0], arr[1])
            }
        }
        for m in models {
            if let data = snap.modelStates[m.kind.rawValue] {
                m.importState(data)
            }
        }
    }

    var weightDictionary: [String: Double] {
        lock.lock(); defer { lock.unlock() }
        return Dictionary(uniqueKeysWithValues: weights.map { ($0.key.rawValue, $0.value) })
    }
}
