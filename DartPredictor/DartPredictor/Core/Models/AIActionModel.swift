import Foundation

/// Модель G — ИИ-анализ действий (нейросеть + Vision)
final class AIActionModel: PredictionModel {
    let type: PredictionModelType = .aiAction
    private let classifier = NeuralActionClassifier.shared

    func predict(history: [Int], features: PlayerFeatures) -> [Int: Double] {
        let sequence = features.vector + features.vector + features.vector + features.vector + features.vector
        let scores = classifier.predictNumber(from: sequence)
        if scores.isEmpty { return uniform() }
        return normalize(scores)
    }

    func update(actual: Int, history: [Int], features: PlayerFeatures, wasCorrect: Bool) {
        let sequence = features.vector + features.vector + features.vector + features.vector + features.vector
        classifier.train(actual: actual, featureSequence: sequence)
    }

    func predictFromInsight(_ insight: AIActionInsight, features: PlayerFeatures) -> [Int: Double] {
        if !insight.numberScores.isEmpty {
            return normalize(insight.numberScores)
        }
        return predict(history: [], features: features)
    }

    private func uniform() -> [Int: Double] {
        let c = DartConstants.validNumbers.count
        return DartConstants.validNumbers.reduce(into: [:]) { $0[$1] = 1.0 / Double(c) }
    }

    private func normalize(_ scores: [Int: Double]) -> [Int: Double] {
        let total = scores.values.reduce(0, +)
        guard total > 0 else { return scores }
        return scores.mapValues { $0 / total }
    }
}
