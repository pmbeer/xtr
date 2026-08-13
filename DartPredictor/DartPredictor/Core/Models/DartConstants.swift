import Foundation
import CoreGraphics

enum DartConstants {
  /// NARDBALL: сетка 1–36 (красная × синяя кость)
    static let validNumbers: Set<Int> = Set(1...36)
    static let minHistoryCount = 1000
    static let topPredictionCount = 4
    static let minCombinationVariants = 4
    static let ocrDebounceFrames = 3
    static let maxProcessingTimeMs: Double = 3000
    static let decisionWindowSeconds: Double = 5.0
    static let playerAnalysisScale: CGFloat = 0.35
    static let sequenceWindows = [3, 5, 10, 20, 50]
    static let defaultModelWeights: [PredictionModelType: Double] = [
        .diceMath: 0.28,
        .sequence: 0.12,
        .frequency: 0.10,
        .transition: 0.12,
        .playerBehavior: 0.14,
        .timing: 0.08,
        .aiAction: 0.24
    ]
    static let weightSmoothingAlpha: Double = 0.08
    static let learningPhases: [LearningPhase] = [.dataCollection, .calibration, .adaptiveLearning, .stableModel]
}

enum PredictionModelType: String, Codable, CaseIterable, Identifiable {
    case diceMath = "DiceMathModel"
    case sequence = "SequenceModel"
    case frequency = "FrequencyModel"
    case transition = "TransitionModel"
    case playerBehavior = "PlayerBehaviorModel"
    case timing = "TimingModel"
    case aiAction = "AIActionModel"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .diceMath: return "Математика костей"
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

/// Выбранное окно для мониторинга (Safari, Chrome и т.д.)
struct CaptureWindowInfo: Codable, Equatable, Identifiable {
    var windowID: UInt32
    var title: String
    var appName: String
    var width: Int
    var height: Int

    var id: UInt32 { windowID }

    var displayTitle: String {
        if title.isEmpty {
            return appName
        }
        return "\(appName) — \(title)"
    }

    var shortLabel: String {
        if title.isEmpty { return appName }
        if title.count > 48 { return String(title.prefix(45)) + "…" }
        return title
    }
}

/// Нормализованная зона внутри окна (0…1, origin сверху-слева)
struct NormalizedRect: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    func cgRect(for size: CGSize) -> CGRect {
        let rect = CGRect(
            x: x * size.width,
            y: y * size.height,
            width: width * size.width,
            height: height * size.height
        )
        return rect.intersection(CGRect(origin: .zero, size: size))
    }
}

/// Зоны NARDBALL / fon.bet: история сверху, сетка 1–36, видео
struct GameWindowZones: Codable, Equatable {
    /// История выпадений (верхняя полоса с костями)
    var resultsZone: NormalizedRect
    /// Видео игроков
    var playerZone: NormalizedRect
    /// Сетка ставок 1–36
    var dartboardZone: NormalizedRect
    /// Фишки / кнопки ставок
    var bettingZone: NormalizedRect
    /// Зоны, которые ИИ полностью игнорирует (таймеры, overlay ставок)
    var ignoredZones: [NormalizedRect]

    init(
        resultsZone: NormalizedRect,
        playerZone: NormalizedRect,
        dartboardZone: NormalizedRect,
        bettingZone: NormalizedRect,
        ignoredZones: [NormalizedRect] = []
    ) {
        self.resultsZone = resultsZone
        self.playerZone = playerZone
        self.dartboardZone = dartboardZone
        self.bettingZone = bettingZone
        self.ignoredZones = ignoredZones
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        resultsZone = try c.decode(NormalizedRect.self, forKey: .resultsZone)
        playerZone = try c.decode(NormalizedRect.self, forKey: .playerZone)
        dartboardZone = try c.decode(NormalizedRect.self, forKey: .dartboardZone)
        bettingZone = try c.decode(NormalizedRect.self, forKey: .bettingZone)
        ignoredZones = try c.decodeIfPresent([NormalizedRect].self, forKey: .ignoredZones) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case resultsZone, playerZone, dartboardZone, bettingZone, ignoredZones
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(resultsZone, forKey: .resultsZone)
        try c.encode(playerZone, forKey: .playerZone)
        try c.encode(dartboardZone, forKey: .dartboardZone)
        try c.encode(bettingZone, forKey: .bettingZone)
        try c.encode(ignoredZones, forKey: .ignoredZones)
    }

    /// NARDBALL FORTUNE — история сверху, сетка 1–36, видео по центру
    static let nardballDefault = GameWindowZones(
        // Верхняя полоса истории (числа + красная/синяя кость)
        resultsZone: NormalizedRect(x: 0.02, y: 0.06, width: 0.96, height: 0.11),
        // Центральное видео
        playerZone: NormalizedRect(x: 0.32, y: 0.22, width: 0.36, height: 0.32),
        // Сетка ставок 1–36
        dartboardZone: NormalizedRect(x: 0.08, y: 0.18, width: 0.58, height: 0.58),
        // Фишки и кнопки «Повторить»
        bettingZone: NormalizedRect(x: 0.12, y: 0.76, width: 0.76, height: 0.10),
        ignoredZones: [
            // Баланс / FORTUNE справа
            NormalizedRect(x: 0.78, y: 0.02, width: 0.20, height: 0.12),
            // Таймер до броска (15 сек)
            NormalizedRect(x: 0.18, y: 0.28, width: 0.10, height: 0.14),
            // Статистика / прогнозы снизу
            NormalizedRect(x: 0.78, y: 0.88, width: 0.20, height: 0.10)
        ]
    )

    /// Алиас для совместимости
    static let fonBetDefault = nardballDefault

    /// Верхняя полоса зоны игрока — не анализируется
    static let playerTimerStripFraction: Double = 0.14

    /// Нижняя часть зоны игрока — overlay таймера/ставок
    static let playerOverlayStripFraction: Double = 0.40

    /// Зона анализа поведения игрока (без таймеров и overlay)
    func playerAnalysisZone() -> NormalizedRect {
        let topSkip = playerZone.height * GameWindowZones.playerTimerStripFraction
        let bottomSkip = playerZone.height * GameWindowZones.playerOverlayStripFraction
        return NormalizedRect(
            x: playerZone.x,
            y: playerZone.y + topSkip,
            width: playerZone.width,
            height: max(0.05, playerZone.height - topSkip - bottomSkip)
        )
    }

    func playerBodyZone() -> NormalizedRect {
        playerAnalysisZone()
    }

    func playerTimerStripZone() -> NormalizedRect {
        let strip = playerZone.height * GameWindowZones.playerTimerStripFraction
        return NormalizedRect(
            x: playerZone.x,
            y: playerZone.y,
            width: playerZone.width,
            height: max(0.03, strip)
        )
    }
}

enum EditableZoneKind: String, CaseIterable, Identifiable {
    case results = "История (сверху)"
    case player = "Видео"

    var id: String { rawValue }

    func rect(in zones: GameWindowZones) -> NormalizedRect {
        switch self {
        case .results: return zones.resultsZone
        case .player: return zones.playerZone
        }
    }

    func setRect(_ rect: NormalizedRect, in zones: inout GameWindowZones) {
        switch self {
        case .results: zones.resultsZone = rect
        case .player: zones.playerZone = rect
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
    let alternativeCombinations: [PredictedCombination]
    let confidence: ConfidenceLevel
    let confidenceScore: Double
    let modelContributions: [PredictionModelType: [Int]]
    let processingTimeMs: Double
    let rationale: String

    static let empty = EnsemblePrediction(
        predictions: [],
        combination: PredictedCombination(numbers: [], individualProbabilities: [], jointProbability: 0, combinationScore: 0),
        alternativeCombinations: [],
        confidence: .low,
        confidenceScore: 0,
        modelContributions: [:],
        processingTimeMs: 0,
        rationale: ""
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
    var selectedCaptureWindow: CaptureWindowInfo?
    var gameWindowZones: GameWindowZones = .nardballDefault
    var zoneLayoutVersion: Int = 6
    var isPaperPredictionMode: Bool = true
    var hasCompletedOnboarding: Bool = false
    var showFloatingOverlay: Bool = true
    var captureFrameRate: Int = 15
    var ocrFrameRate: Int = 10
    var activePlayerProfileId: String = PlayerProfile.unknownId
    var debugLoggingEnabled: Bool = true
}
