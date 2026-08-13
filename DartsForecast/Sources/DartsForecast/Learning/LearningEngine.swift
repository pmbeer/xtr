import Foundation
import Combine

/// Цикл: факт → проверка прогноза → обучение → новый ТОП-4.
@MainActor
final class LearningEngine: ObservableObject {
    let ensemble = EnsemblePredictor()
    let accuracy = AccuracyManager()
    let profiles = PlayerProfileManager()

    @Published private(set) var lastPrediction: Top4Prediction = .empty
    @Published private(set) var lastOutcomeSuccess: Bool?
    @Published private(set) var phase: LearningPhase = .dataCollection
    @Published private(set) var trainingSamples: Int = 0
    @Published private(set) var lastMessage: String = "Ожидание данных"

    private var pendingPrediction: Top4Prediction?
    private var pendingHistory: [Int] = []
    private var pendingFeatures: PlayerFeatures = .empty

    func bootstrap(from store: PersistedState) {
        ensemble.importSnapshot(store.ensemble)
        accuracy.load(store.accuracy)
        profiles.load(store.profiles, active: store.activeProfileID)
        trainingSamples = store.accuracy.totalPredictions
        phase = LearningPhase.resolve(samples: trainingSamples, top4Accuracy: store.accuracy.top4Accuracy)
        if let last = store.history.last, !last.predictedNumbers.isEmpty {
            let items = zip(last.predictedNumbers, last.predictedProbabilities).map {
                Top4Prediction.Item(number: $0.0, probability: $0.1)
            }
            lastPrediction = Top4Prediction(
                items: items,
                confidence: last.confidenceLevel,
                confidenceScore: last.predictedProbabilities.first ?? 0,
                createdAt: last.timestamp,
                modelWeights: last.modelWeightsSnapshot
            )
            pendingPrediction = lastPrediction
        }
    }

    /// Вызывается после подтверждённого нового результата.
    func onNewResult(
        historyIncludingNew: [Int],
        features: PlayerFeatures
    ) -> (verified: Bool?, prediction: Top4Prediction) {
        guard let actual = historyIncludingNew.last else {
            return (nil, .empty)
        }
        let previous = Array(historyIncludingNew.dropLast())

        var verified: Bool?
        if let pending = pendingPrediction, !pending.numbers.isEmpty {
            let success = pending.numbers.contains(actual)
            verified = success
            lastOutcomeSuccess = success
            accuracy.record(actual: actual, predicted: pending.numbers)

            ensemble.learn(
                previous: pendingHistory.isEmpty ? previous : pendingHistory,
                actual: actual,
                features: pendingFeatures,
                previousTop4: pending.numbers
            )

            lastMessage = success
                ? "SUCCESS: \(actual) в ТОП-4"
                : "MISS: \(actual) вне ТОП-4"

            DebugLog.info("Learn: actual=\(actual) top4=\(pending.numbers) success=\(success)")
            trainingSamples = accuracy.snapshot.totalPredictions
        } else {
            lastMessage = "Первый результат — накопление"
            DebugLog.info("First result \(actual), no prior prediction")
        }

        profiles.maybeDetectPlayerChange(features: features)

        let prediction = ensemble.predict(history: historyIncludingNew, features: features)
        lastPrediction = prediction
        pendingPrediction = prediction
        pendingHistory = historyIncludingNew
        pendingFeatures = features

        profiles.updateAfterThrow(
            features: features,
            accuracy: accuracy.snapshot,
            weights: ensemble.weightDictionary
        )

        phase = LearningPhase.resolve(
            samples: trainingSamples,
            top4Accuracy: accuracy.snapshot.top4Accuracy
        )

        return (verified, prediction)
    }

    func currentWeights() -> [String: Double] {
        ensemble.weightDictionary
    }
}
