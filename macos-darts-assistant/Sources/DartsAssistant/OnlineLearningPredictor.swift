import Foundation

struct OnlineLearningPredictor: Codable {
    private struct PendingPrediction: Codable {
        let features: [Double]
        let predictedNumber: Int
        let confidence: Double
    }

    private static let outcomeCount = 20
    private static let historyDepth = 5
    private static let behaviorFeatureCount = 40
    private static let featureCount =
        1 + historyDepth * outcomeCount + behaviorFeatureCount

    private var weights: [[Double]]
    private var history: [Int] = []
    private var pendingPrediction: PendingPrediction?
    private var rollingResults: [Bool] = []
    private var trainingExamples = 0
    private(set) var metrics = LearningMetrics()

    init() {
        weights = Array(
            repeating: Array(repeating: 0, count: Self.featureCount),
            count: Self.outcomeCount
        )
    }

    mutating func beginSession() {
        history.removeAll(keepingCapacity: true)
        pendingPrediction = nil
        metrics.predictedNumber = nil
        metrics.confidence = 0
        metrics.lastPredictionWasCorrect = nil
        metrics.behaviorConfidence = 0
    }

    mutating func seed(
        _ chronologicalValues: [Int],
        behaviorFeatures: [Double],
        behaviorConfidence: Double
    ) -> LearningMetrics {
        history = Array(
            chronologicalValues
                .filter { (1...Self.outcomeCount).contains($0) }
                .suffix(50)
        )
        createPendingPrediction(
            behaviorFeatures: behaviorFeatures,
            behaviorConfidence: behaviorConfidence
        )
        return metrics
    }

    mutating func observe(
        outcome: Int,
        behaviorFeatures: [Double],
        behaviorConfidence: Double
    ) -> LearningMetrics {
        guard (1...Self.outcomeCount).contains(outcome) else { return metrics }

        if let pendingPrediction {
            let wasCorrect = pendingPrediction.predictedNumber == outcome
            metrics.evaluatedCount += 1
            metrics.correctCount += wasCorrect ? 1 : 0
            metrics.lastPredictionWasCorrect = wasCorrect
            rollingResults.append(wasCorrect)
            if rollingResults.count > 100 {
                rollingResults.removeFirst(rollingResults.count - 100)
            }
            train(features: pendingPrediction.features, outcome: outcome)
        }

        history.append(outcome)
        if history.count > 50 {
            history.removeFirst(history.count - 50)
        }
        createPendingPrediction(
            behaviorFeatures: behaviorFeatures,
            behaviorConfidence: behaviorConfidence
        )
        return metrics
    }

    mutating func eraseLearning() {
        self = OnlineLearningPredictor()
    }

    func save(to url: URL) throws {
        let data = try JSONEncoder().encode(self)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    static func load(from url: URL) -> OnlineLearningPredictor? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let model = try? JSONDecoder().decode(Self.self, from: data),
              model.weights.count == Self.outcomeCount,
              model.weights.allSatisfy({ $0.count == Self.featureCount }) else {
            return nil
        }
        return model
    }

    private mutating func createPendingPrediction(
        behaviorFeatures: [Double],
        behaviorConfidence: Double
    ) {
        let features = makeFeatures(behaviorFeatures: behaviorFeatures)
        let probabilities = predict(features: features)
        guard let bestIndex = probabilities.indices.max(by: {
            probabilities[$0] < probabilities[$1]
        }) else {
            return
        }

        let predictedNumber = bestIndex + 1
        let confidence = probabilities[bestIndex]
        pendingPrediction = PendingPrediction(
            features: features,
            predictedNumber: predictedNumber,
            confidence: confidence
        )
        metrics.predictedNumber = predictedNumber
        metrics.confidence = confidence
        metrics.behaviorConfidence = behaviorConfidence
        metrics.rollingAccuracy = rollingResults.isEmpty
            ? nil
            : Double(rollingResults.filter { $0 }.count) / Double(rollingResults.count)
    }

    private func makeFeatures(behaviorFeatures: [Double]) -> [Double] {
        var features = [1.0]
        let recentHistory = Array(history.suffix(Self.historyDepth).reversed())

        for lag in 0..<Self.historyDepth {
            var oneHot = Array(repeating: 0.0, count: Self.outcomeCount)
            if lag < recentHistory.count {
                oneHot[recentHistory[lag] - 1] = 1
            }
            features.append(contentsOf: oneHot)
        }

        let behavior = Array(behaviorFeatures.prefix(Self.behaviorFeatureCount))
        features.append(contentsOf: behavior)
        if behavior.count < Self.behaviorFeatureCount {
            features.append(
                contentsOf: repeatElement(
                    0,
                    count: Self.behaviorFeatureCount - behavior.count
                )
            )
        }
        return features
    }

    private func predict(features: [Double]) -> [Double] {
        let logits = weights.map { row in
            zip(row, features).reduce(0) { $0 + $1.0 * $1.1 }
        }
        let maximum = logits.max() ?? 0
        let exponentials = logits.map { exp(($0 - maximum) / 1.5) }
        let total = exponentials.reduce(0, +)
        guard total.isFinite, total > 0 else {
            return Array(repeating: 1.0 / Double(Self.outcomeCount), count: Self.outcomeCount)
        }
        return exponentials.map { $0 / total }
    }

    private mutating func train(features: [Double], outcome: Int) {
        let probabilities = predict(features: features)
        let learningRate = 0.08 / sqrt(1 + Double(trainingExamples) / 50)
        let regularization = 0.0005

        for classIndex in 0..<Self.outcomeCount {
            let target = classIndex == outcome - 1 ? 1.0 : 0.0
            let error = target - probabilities[classIndex]
            for featureIndex in features.indices {
                weights[classIndex][featureIndex] += learningRate * (
                    error * features[featureIndex]
                        - regularization * weights[classIndex][featureIndex]
                )
            }
        }
        trainingExamples += 1
    }
}
