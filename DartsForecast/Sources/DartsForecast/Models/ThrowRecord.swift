import Foundation

/// Запись одного броска + прогноз + факт.
struct ThrowRecord: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var index: Int
    var timestamp: Date
    var previousResults: [Int]
    var currentResult: Int
    var playerFeatures: PlayerFeatures
    var predictedNumbers: [Int]
    var predictedProbabilities: [Double]
    var actualResult: Int?
    var predictionCorrect: Bool?
    var confidenceLevel: ConfidenceLevel
    var modelWeightsSnapshot: [String: Double]
    var playerProfileID: String
    var processingMs: Int

    init(
        index: Int,
        previousResults: [Int],
        currentResult: Int,
        playerFeatures: PlayerFeatures,
        predictedNumbers: [Int],
        predictedProbabilities: [Double],
        confidenceLevel: ConfidenceLevel,
        modelWeightsSnapshot: [String: Double],
        playerProfileID: String,
        processingMs: Int = 0
    ) {
        self.id = UUID()
        self.index = index
        self.timestamp = Date()
        self.previousResults = previousResults
        self.currentResult = currentResult
        self.playerFeatures = playerFeatures
        self.predictedNumbers = predictedNumbers
        self.predictedProbabilities = predictedProbabilities
        self.actualResult = nil
        self.predictionCorrect = nil
        self.confidenceLevel = confidenceLevel
        self.modelWeightsSnapshot = modelWeightsSnapshot
        self.playerProfileID = playerProfileID
        self.processingMs = processingMs
    }
}

/// Текущий ТОП-4 прогноз.
struct Top4Prediction: Equatable, Sendable {
    struct Item: Equatable, Identifiable, Sendable {
        var id: Int { number }
        let number: Int
        let probability: Double

        var percentText: String {
            String(format: "%.1f%%", probability * 100)
        }
    }

    let items: [Item]
    let confidence: ConfidenceLevel
    let confidenceScore: Double
    let createdAt: Date
    let modelWeights: [String: Double]

    static let empty = Top4Prediction(
        items: [],
        confidence: .low,
        confidenceScore: 0,
        createdAt: .distantPast,
        modelWeights: [:]
    )

    var numbers: [Int] { items.map(\.number) }
    var probabilities: [Double] { items.map(\.probability) }
}

struct AccuracySnapshot: Codable, Equatable, Sendable {
    var totalPredictions: Int = 0
    var successes: Int = 0
    var misses: Int = 0
    var top1Hits: Int = 0
    var top2Hits: Int = 0
    var top4Hits: Int = 0
    var recent10: [Bool] = []
    var recent50: [Bool] = []
    var recent100: [Bool] = []

    var top1Accuracy: Double {
        guard totalPredictions > 0 else { return 0 }
        return Double(top1Hits) / Double(totalPredictions)
    }

    var top2Accuracy: Double {
        guard totalPredictions > 0 else { return 0 }
        return Double(top2Hits) / Double(totalPredictions)
    }

    var top4Accuracy: Double {
        guard totalPredictions > 0 else { return 0 }
        return Double(top4Hits) / Double(totalPredictions)
    }

    var overallAccuracy: Double { top4Accuracy }

    func windowAccuracy(_ window: [Bool]) -> Double {
        guard !window.isEmpty else { return 0 }
        let hits = window.filter { $0 }.count
        return Double(hits) / Double(window.count)
    }

    mutating func record(actual: Int, predicted: [Int]) {
        totalPredictions += 1
        let top1 = predicted.first == actual
        let top2 = predicted.prefix(2).contains(actual)
        let top4 = predicted.prefix(4).contains(actual)
        if top1 { top1Hits += 1 }
        if top2 { top2Hits += 1 }
        if top4 { top4Hits += 1; successes += 1 } else { misses += 1 }

        func push(_ value: Bool, into arr: inout [Bool], limit: Int) {
            arr.insert(value, at: 0)
            if arr.count > limit { arr.removeLast() }
        }
        push(top4, into: &recent10, limit: 10)
        push(top4, into: &recent50, limit: 50)
        push(top4, into: &recent100, limit: 100)
    }
}
