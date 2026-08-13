import Foundation

@MainActor
final class LearningEngine: ObservableObject {
    static let shared = LearningEngine()

    @Published var currentPhase: LearningPhase = .dataCollection
    @Published var modelWeights: [PredictionModelType: Double] = DartConstants.defaultModelWeights

    private let ensemble = EnsemblePredictor()
    private var pendingPrediction: EnsemblePrediction?
    private var lastFeatures: PlayerFeatures = .zero
    private var lastAIInsight: AIActionInsight = .empty

    func makePrediction(
        history: [Int],
        features: PlayerFeatures,
        profile: PlayerProfile,
        aiInsight: AIActionInsight = .empty
    ) -> EnsemblePrediction {
        lastFeatures = features
        lastAIInsight = aiInsight
        let weights = profile.modelWeights.reduce(into: [PredictionModelType: Double]()) { result, pair in
            if let type = PredictionModelType.allCases.first(where: { $0.rawValue == pair.key }) {
                result[type] = pair.value
            }
        }
        modelWeights = weights.isEmpty ? DartConstants.defaultModelWeights : weights

        let prediction = ensemble.predict(
            history: history,
            features: features,
            weights: modelWeights,
            aiInsight: aiInsight
        )
        pendingPrediction = prediction

        DebugLogger.shared.logPrediction(
            numbers: prediction.predictions.map(\.number),
            probabilities: prediction.predictions.map(\.probability),
            timeMs: prediction.processingTimeMs
        )

        return prediction
    }

    func processNewThrow(
        actual: Int,
        history: [Int],
        features: PlayerFeatures,
        profile: inout PlayerProfile,
        previousEntry: PredictionEntry?,
        aiInsight: AIActionInsight = .empty
    ) -> PredictionOutcome {
        var outcome: PredictionOutcome = .miss

        if let entry = previousEntry {
            let predicted = entry.predictedNumbers
            let hit = predicted.contains(actual)
            outcome = hit ? .success : .miss

            let modelHits = evaluateModelHits(
                actual: actual,
                history: history,
                features: entry.playerFeatures,
                contributions: pendingPrediction?.modelContributions ?? [:]
            )

            ensemble.updateAll(
                actual: actual,
                history: history,
                features: entry.playerFeatures,
                wasCorrect: hit,
                modelHits: modelHits
            )

            AIActionAnalyzer.shared.trainOnResult(actual, featureSequence: features.vector)

            updateWeights(profile: &profile, modelHits: modelHits)
            updatePhase(profile: &profile)
            updateAccuracy(profile: &profile, hit: hit, predicted: predicted, actual: actual)
        }

        currentPhase = profile.learningPhase
        return outcome
    }

    private func evaluateModelHits(
        actual: Int,
        history: [Int],
        features: PlayerFeatures,
        contributions: [PredictionModelType: [Int]]
    ) -> [PredictionModelType: Bool] {
        var hits: [PredictionModelType: Bool] = [:]
        for (type, numbers) in contributions {
            hits[type] = numbers.contains(actual)
        }
        return hits
    }

    private func updateWeights(profile: inout PlayerProfile, modelHits: [PredictionModelType: Bool]) {
        let alpha = DartConstants.weightSmoothingAlpha

        for type in PredictionModelType.allCases {
            let current = profile.weight(for: type)
            let hit = modelHits[type] ?? false
            let target = hit ? min(current + alpha, 0.5) : max(current - alpha * 0.5, 0.05)
            let smoothed = current + alpha * (target - current)
            profile.setWeight(smoothed, for: type)
        }

        normalizeWeights(profile: &profile)
        modelWeights = PredictionModelType.allCases.reduce(into: [:]) { $0[$1] = profile.weight(for: $1) }

        DebugLogger.shared.logWeightUpdate(weights: profile.modelWeights)
    }

    private func normalizeWeights(profile: inout PlayerProfile) {
        let total = PredictionModelType.allCases.map { profile.weight(for: $0) }.reduce(0, +)
        guard total > 0 else { return }
        for type in PredictionModelType.allCases {
            profile.setWeight(profile.weight(for: type) / total, for: type)
        }
    }

    private func updatePhase(profile: inout PlayerProfile) {
        let count = profile.accuracyStats.totalPredictions
        switch count {
        case 0..<30: profile.learningPhase = .dataCollection
        case 30..<100: profile.learningPhase = .calibration
        case 100..<300: profile.learningPhase = .adaptiveLearning
        default: profile.learningPhase = .stableModel
        }
        currentPhase = profile.learningPhase
    }

    private func updateAccuracy(
        profile: inout PlayerProfile,
        hit: Bool,
        predicted: [Int],
        actual: Int
    ) {
        profile.accuracyStats.totalPredictions += 1
        if hit { profile.accuracyStats.successfulPredictions += 1 }
        else { profile.accuracyStats.failedPredictions += 1 }

        if predicted.first == actual { profile.accuracyStats.top1Hits += 1 }
        if predicted.prefix(2).contains(actual) { profile.accuracyStats.top2Hits += 1 }
        if predicted.contains(actual) { profile.accuracyStats.top4Hits += 1 }

        profile.accuracyStats.recentOutcomes.append(hit)
        if profile.accuracyStats.recentOutcomes.count > 200 {
            profile.accuracyStats.recentOutcomes.removeFirst()
        }
    }
}
