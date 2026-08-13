import Foundation

/// Model F — adaptive ensemble combining all models including AI
final class EnsemblePredictor {
    private let models: [PredictionModel] = [
        SequenceModel(),
        FrequencyModel(),
        TransitionModel(),
        PlayerBehaviorModel(),
        TimingModel(),
        AIActionModel()
    ]
    private let aiModel = AIActionModel()
    private let combinationPredictor = CombinationPredictor.shared

    func predict(
        history: [Int],
        features: PlayerFeatures,
        weights: [PredictionModelType: Double],
        aiInsight: AIActionInsight = .empty
    ) -> EnsemblePrediction {
        let start = CFAbsoluteTimeGetCurrent()

        var combinedScores: [Int: Double] = [:]
        var contributions: [PredictionModelType: [Int]] = [:]

        for model in models {
            let modelScores: [Int: Double]
            if model.type == .aiAction {
                modelScores = aiModel.predictFromInsight(aiInsight, features: features)
            } else {
                modelScores = model.predict(history: history, features: features)
            }
            let weight = weights[model.type] ?? 0.1
            contributions[model.type] = topNumbers(from: modelScores, count: 4)

            for (num, score) in modelScores {
                combinedScores[num, default: 0] += score * weight
            }
        }

        let normalized = normalize(combinedScores)
        let top4 = topNumbers(from: normalized, count: DartConstants.topPredictionCount)
        let topProbs = top4.map { normalized[$0] ?? 0 }

        let renormTotal = topProbs.reduce(0, +)
        let finalProbs = renormTotal > 0
            ? topProbs.map { $0 / renormTotal * 100 }
            : topProbs

        let predictions = zip(top4, finalProbs).map { TopPrediction(number: $0, probability: $1) }
        let combination = combinationPredictor.buildCombination(from: predictions)
        let confidence = computeConfidence(predictions: predictions, historyCount: history.count, aiInsight: aiInsight)

        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

        return EnsemblePrediction(
            predictions: predictions,
            combination: combination,
            confidence: confidence.level,
            confidenceScore: confidence.score,
            modelContributions: contributions,
            processingTimeMs: elapsed
        )
    }

    func updateAll(
        actual: Int,
        history: [Int],
        features: PlayerFeatures,
        wasCorrect: Bool,
        modelHits: [PredictionModelType: Bool]
    ) {
        for model in models {
            let hit = modelHits[model.type] ?? false
            model.update(actual: actual, history: history, features: features, wasCorrect: hit)
        }
    }

    private func topNumbers(from scores: [Int: Double], count: Int) -> [Int] {
        scores.sorted { $0.value > $1.value }
            .prefix(count)
            .map { $0.key }
    }

    private func normalize(_ scores: [Int: Double]) -> [Int: Double] {
        let total = scores.values.reduce(0, +)
        guard total > 0 else { return scores }
        return scores.mapValues { $0 / total }
    }

    private func computeConfidence(
        predictions: [TopPrediction],
        historyCount: Int,
        aiInsight: AIActionInsight
    ) -> (level: ConfidenceLevel, score: Double) {
        guard let top = predictions.first else {
            return (.low, 0)
        }

        let spread = predictions.map(\.probability)
        let topProb = top.probability
        let avgSpread = spread.reduce(0, +) / Double(spread.count)
        let dataFactor = min(Double(historyCount) / 100.0, 1.0)
        let aiFactor = aiInsight.actionConfidence * 0.2

        let score = (topProb / 100.0 * 0.4 + dataFactor * 0.25 + (topProb - avgSpread) / 100.0 * 0.15 + aiFactor) * 100
        let clamped = min(max(score, 0), 100)

        let level: ConfidenceLevel
        if clamped >= 60 && historyCount >= 50 { level = .high }
        else if clamped >= 35 && historyCount >= 20 { level = .medium }
        else { level = .low }

        return (level, clamped)
    }
}
