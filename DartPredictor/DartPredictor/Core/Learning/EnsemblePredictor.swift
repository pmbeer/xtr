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
        let adaptiveWeights = self.adaptiveWeights(
            base: weights,
            historyCount: history.count,
            aiInsight: aiInsight
        )

        var combinedScores: [Int: Double] = [:]
        var contributions: [PredictionModelType: [Int]] = [:]

        for model in models {
            let modelScores: [Int: Double]
            if model.type == .aiAction {
                modelScores = aiModel.predictFromInsight(aiInsight, features: features)
            } else {
                modelScores = model.predict(history: history, features: features)
            }
            let weight = adaptiveWeights[model.type] ?? 0.1
            contributions[model.type] = topNumbers(from: modelScores, count: 4)

            for (num, score) in modelScores {
                combinedScores[num, default: 0] += score * weight
            }
        }

        applyHistoryPatternBoost(scores: &combinedScores, history: history)
        applyFollowUpBoost(scores: &combinedScores, history: history)

        let normalized = normalize(combinedScores)
        let top4 = topNumbers(from: normalized, count: DartConstants.topPredictionCount)
        let topProbs = top4.map { normalized[$0] ?? 0 }

        let renormTotal = topProbs.reduce(0, +)
        let finalProbs = renormTotal > 0
            ? topProbs.map { $0 / renormTotal * 100 }
            : topProbs

        let predictions = zip(top4, finalProbs).map { TopPrediction(number: $0, probability: $1) }
        let combination = combinationPredictor.findBestWinningCombination(
            scores: normalized,
            history: history,
            fallback: predictions
        )
        let confidence = computeConfidence(
            predictions: predictions,
            combination: combination,
            historyCount: history.count,
            aiInsight: aiInsight
        )
        let rationale = buildRationale(
            history: history,
            aiInsight: aiInsight,
            features: features,
            combination: combination,
            contributions: contributions
        )

        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

        return EnsemblePrediction(
            predictions: predictions,
            combination: combination,
            confidence: confidence.level,
            confidenceScore: confidence.score,
            modelContributions: contributions,
            processingTimeMs: elapsed,
            rationale: rationale
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

    private func adaptiveWeights(
        base: [PredictionModelType: Double],
        historyCount: Int,
        aiInsight: AIActionInsight
    ) -> [PredictionModelType: Double] {
        var w = base.isEmpty ? DartConstants.defaultModelWeights : base

        if historyCount >= 8 {
            w[.sequence] = (w[.sequence] ?? 0.15) * 1.45
            w[.transition] = (w[.transition] ?? 0.15) * 1.35
            w[.frequency] = (w[.frequency] ?? 0.10) * 1.25
        }
        if historyCount >= 20 {
            w[.playerBehavior] = (w[.playerBehavior] ?? 0.20) * 1.2
        }
        if aiInsight.playerDetected {
            w[.playerBehavior] = (w[.playerBehavior] ?? 0.20) * 1.35
            if !aiInsight.numberScores.isEmpty {
                w[.aiAction] = (w[.aiAction] ?? 0.30) * 1.55
            }
        }

        let total = w.values.reduce(0, +)
        guard total > 0 else { return DartConstants.defaultModelWeights }
        return w.mapValues { $0 / total }
    }

    private func applyHistoryPatternBoost(scores: inout [Int: Double], history: [Int]) {
        guard history.count >= 3 else { return }

        let recent = Array(history.suffix(5))
        var recentCounts: [Int: Int] = [:]
        for n in recent { recentCounts[n, default: 0] += 1 }

        for num in DartConstants.validNumbers {
            let count = recentCounts[num] ?? 0
            let coldBonus = count == 0 ? 0.06 : 0
            let hotPenalty = count >= 2 ? -0.04 * Double(count - 1) : 0
            scores[num, default: 0] += coldBonus + hotPenalty
        }
    }

    private func applyFollowUpBoost(scores: inout [Int: Double], history: [Int]) {
        let followUp = ThrowHistoryMerger.followUpScores(from: history, depth: 10)
        for (num, prob) in followUp {
            scores[num, default: 0] += prob * 0.35
        }

        if let last = history.last {
            let transition = ThrowHistoryMerger.followUpScores(from: history, depth: 3)
            for (num, prob) in transition where num != last {
                scores[num, default: 0] += prob * 0.15
            }
        }
    }

    private func buildRationale(
        history: [Int],
        aiInsight: AIActionInsight,
        features: PlayerFeatures,
        combination: PredictedCombination,
        contributions: [PredictionModelType: [Int]]
    ) -> String {
        var parts: [String] = []

        if history.count >= 3 {
            let tail = history.suffix(6).map(String.init).joined(separator: "→")
            parts.append("история \(tail)")
        }

        if aiInsight.playerDetected {
            parts.append("поза: \(aiInsight.detectedAction.rawValue)")
            if features.armHeight > 0.1 {
                parts.append("стойка \(Int(features.armHeight * 100))%")
            }
        }

        if !aiInsight.numberScores.isEmpty {
            let aiTop = aiInsight.numberScores.sorted { $0.value > $1.value }.prefix(2).map { "\($0.key)" }
            parts.append("ИИ-числа: \(aiTop.joined(separator: ","))")
        }

        if let nums = contributions[.sequence], !nums.isEmpty {
            let seq = nums.prefix(2).map(String.init).joined(separator: ",")
            parts.append("паттерн: \(seq)")
        }

        parts.append("след. ставка \(Int(combination.jointProbability))%")
        return parts.joined(separator: " · ")
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
        combination: PredictedCombination,
        historyCount: Int,
        aiInsight: AIActionInsight
    ) -> (level: ConfidenceLevel, score: Double) {
        guard let top = predictions.first else {
            return (.low, 0)
        }

        let spread = predictions.map(\.probability)
        let topProb = top.probability
        let avgSpread = spread.reduce(0, +) / Double(spread.count)
        let historyFactor = min(Double(historyCount) / 10.0, 1.0)
        let jointFactor = combination.jointProbability / 100.0
        let aiFactor = aiInsight.actionConfidence * 0.2 + (aiInsight.playerDetected ? 0.12 : 0)
        let spreadBonus = max(0, (topProb - avgSpread) / 100.0) * 0.12

        let historyDepthBonus = min(0.22, Double(min(historyCount, 15)) / 15.0 * 0.22)
        let raw = topProb / 100.0 * 0.18 + historyFactor * 0.30 + jointFactor * 0.42 + aiFactor + spreadBonus + historyDepthBonus
        var score = min(99.0, max(0, raw * 100))
        if historyCount >= 4 && jointFactor >= 0.55 {
            score = min(99.0, score + 8 + jointFactor * 12)
        }
        if historyCount >= 8 && jointFactor >= 0.65 && aiInsight.playerDetected {
            score = min(99.0, max(score, 88 + jointFactor * 14))
        }
        if historyCount >= 12 && jointFactor >= 0.72 {
            score = min(99.0, max(score, 94))
        }

        let level: ConfidenceLevel
        if score >= 78 && historyCount >= 5 { level = .high }
        else if score >= 50 && historyCount >= 2 { level = .medium }
        else { level = .low }

        return (level, score)
    }
}
