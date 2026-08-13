import Foundation
import CoreGraphics

enum DartConstants {
    static let validNumbers: Set<Int> = Set(1...20)
    static let minHistoryCount = 1000
    static let topPredictionCount = 4
    static let ocrDebounceFrames = 3
    static let maxProcessingTimeMs: Double = 3000
    static let decisionWindowSeconds: Double = 5.0
    static let playerAnalysisScale: CGFloat = 0.35
    static let sequenceWindows = [3, 5, 10, 20, 50]
    static let defaultModelWeights: [PredictionModelType: Double] = [
        .sequence: 0.15,
        .frequency: 0.10,
        .transition: 0.15,
        .playerBehavior: 0.20,
        .timing: 0.10,
        .aiAction: 0.30
    ]
    static let weightSmoothingAlpha: Double = 0.08
    static let learningPhases: [LearningPhase] = [.dataCollection, .calibration, .adaptiveLearning, .stableModel]
}

enum PredictionModelType: String, Codable, CaseIterable, Identifiable {
    case sequence = "SequenceModel"
    case frequency = "FrequencyModel"
    case transition = "TransitionModel"
    case playerBehavior = "PlayerBehaviorModel"
    case timing = "TimingModel"
    case aiAction = "AIActionModel"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sequence: return "Последовательности"
        case .frequency: return "Частотность"
        case .transition: return "Переходы"
        case .playerBehavior: return "Поведение игрока"
        case .timing: return "Временные паттерны"
        case .aiAction: return "ИИ-анализ действий"
        }
    }
}

enum LearningPhase: String, Codable, CaseIterable {
    case dataCollection = "СБОР ДАННЫХ"
    case calibration = "КАЛИБРАВКА"
    case adaptiveLearning = "АДАПТИВНОЕ ОБУЧЕНИЕ"
    case stableModel = "СТАБИЛЬНАЯ МОДЕЛЬ"
}

enum ConfidenceLevel: String, Codable {
    case high = "HIGH"
    case medium = "MEDIUM"
    case low = "LOW"

    var localizedName: String {
        switch self {
        case .high: return "HIGH"
        case .medium: return "MEDIUM"
        case .low: return "LOW"
        }
    }
}

enum PredictionOutcome: String, Codable {
    case success = "SUCCESS"
    case miss = "MISS"
    case pending = "PENDING"
}

enum CaptureRegionType: String, Codable, CaseIterable {
    case gameScreen = "game_screen"
    case result = "result"
    case player = "player"

    var displayName: String {
        switch self {
        case .gameScreen: return "Игровой экран"
        case .result: return "Результаты (legacy)"
        case .player: return "Игрок (legacy)"
        }
    }
}

struct CaptureRegion: Codable, Equatable {
    let type: CaptureRegionType
    var rect: CGRect

    enum CodingKeys: String, CodingKey {
        case type, x, y, width, height
    }

    init(type: CaptureRegionType, rect: CGRect) {
        self.type = type
        self.rect = rect
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(CaptureRegionType.self, forKey: .type)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        let width = try container.decode(CGFloat.self, forKey: .width)
        let height = try container.decode(CGFloat.self, forKey: .height)
        rect = CGRect(x: x, y: y, width: width, height: height)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(rect.origin.x, forKey: .x)
        try container.encode(rect.origin.y, forKey: .y)
        try container.encode(rect.size.width, forKey: .width)
        try container.encode(rect.size.height, forKey: .height)
    }
}

struct PlayerFeatures: Codable, Equatable {
    var bodyTilt: Double = 0
    var shoulderAngle: Double = 0
    var armHeight: Double = 0
    var armExtension: Double = 0
    var swingAmplitude: Double = 0
    var swingSpeed: Double = 0
    var movementDirection: Double = 0
    var throwStartTimestamp: Double = 0
    var releaseTimestamp: Double = 0
    var preparationDuration: Double = 0
    var bodyMovementBeforeThrow: Double = 0
    var motionVariance: Double = 0
    var intervalSinceLastThrow: Double = 0
    var frameCount: Int = 0

    static let zero = PlayerFeatures()

    var vector: [Double] {
        [
            bodyTilt, shoulderAngle, armHeight, armExtension,
            swingAmplitude, swingSpeed, movementDirection,
            preparationDuration, bodyMovementBeforeThrow,
            motionVariance, intervalSinceLastThrow
        ]
    }
}

struct PredictionEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let previousResults: [Int]
    let currentResult: Int
    let playerFeatures: PlayerFeatures
    let predictedNumbers: [Int]
    let predictedProbabilities: [Double]
    var actualResult: Int?
    var predictionOutcome: PredictionOutcome
    let playerProfileId: String
    let processingTimeMs: Double

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        previousResults: [Int],
        currentResult: Int,
        playerFeatures: PlayerFeatures,
        predictedNumbers: [Int],
        predictedProbabilities: [Double],
        actualResult: Int? = nil,
        predictionOutcome: PredictionOutcome = .pending,
        playerProfileId: String,
        processingTimeMs: Double = 0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.previousResults = previousResults
        self.currentResult = currentResult
        self.playerFeatures = playerFeatures
        self.predictedNumbers = predictedNumbers
        self.predictedProbabilities = predictedProbabilities
        self.actualResult = actualResult
        self.predictionOutcome = predictionOutcome
        self.playerProfileId = playerProfileId
        self.processingTimeMs = processingTimeMs
    }
}

struct TopPrediction: Identifiable, Equatable {
    let id = UUID()
    let number: Int
    let probability: Double
}

struct EnsemblePrediction: Equatable {
    let predictions: [TopPrediction]
    let combination: PredictedCombination
    let confidence: ConfidenceLevel
    let confidenceScore: Double
    let modelContributions: [PredictionModelType: [Int]]
    let processingTimeMs: Double

    static let empty = EnsemblePrediction(
        predictions: [],
        combination: PredictedCombination(numbers: [], individualProbabilities: [], jointProbability: 0, combinationScore: 0),
        confidence: .low,
        confidenceScore: 0,
        modelContributions: [:],
        processingTimeMs: 0
    )
}

struct AccuracyStats: Codable, Equatable {
    var totalPredictions: Int = 0
    var successfulPredictions: Int = 0
    var failedPredictions: Int = 0
    var top1Hits: Int = 0
    var top2Hits: Int = 0
    var top4Hits: Int = 0
    var recentOutcomes: [Bool] = []

    var top1Accuracy: Double {
        guard totalPredictions > 0 else { return 0 }
        return Double(top1Hits) / Double(totalPredictions) * 100
    }

    var top2Accuracy: Double {
        guard totalPredictions > 0 else { return 0 }
        return Double(top2Hits) / Double(totalPredictions) * 100
    }

    var top4Accuracy: Double {
        guard totalPredictions > 0 else { return 0 }
        return Double(top4Hits) / Double(totalPredictions) * 100
    }

    var overallAccuracy: Double { top4Accuracy }

    func accuracyForLast(_ count: Int) -> Double {
        let slice = recentOutcomes.suffix(count)
        guard !slice.isEmpty else { return 0 }
        let hits = slice.filter { $0 }.count
        return Double(hits) / Double(slice.count) * 100
    }
}

struct PlayerProfile: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var throwHistory: [Int] = []
    var modelWeights: [String: Double] = [:]
    var accuracyStats: AccuracyStats = AccuracyStats()
    var learningPhase: LearningPhase = .dataCollection
    var featureClusters: [[Double]] = []
    var createdAt: Date = Date()
    var lastActiveAt: Date = Date()

    static let unknownId = "unknown_player"
    static let unknown = PlayerProfile(id: unknownId, name: "Unknown Player")

    init(id: String, name: String) {
        self.id = id
        self.name = name
        self.modelWeights = PredictionModelType.allCases.reduce(into: [:]) { result, type in
            result[type.rawValue] = DartConstants.defaultModelWeights[type]
        }
    }

    func weight(for type: PredictionModelType) -> Double {
        modelWeights[type.rawValue] ?? DartConstants.defaultModelWeights[type] ?? 0.1
    }

    mutating func setWeight(_ value: Double, for type: PredictionModelType) {
        modelWeights[type.rawValue] = value
    }
}

struct AppSettings: Codable, Equatable {
    var regions: [CaptureRegion] = []
    var isPaperPredictionMode: Bool = true
    var hasCompletedOnboarding: Bool = false
    var showFloatingOverlay: Bool = true
    var captureFrameRate: Int = 15
    var ocrFrameRate: Int = 10
    var activePlayerProfileId: String = PlayerProfile.unknownId
    var debugLoggingEnabled: Bool = false
}
