import Foundation
import CoreGraphics

/// Состояние игровой сцены на экране
enum GameSceneState: String, Codable, CaseIterable {
    case idle = "Ожидание"
    case playerVisible = "Игрок на экране"
    case preparing = "Подготовка"
    case throwing = "Замах / бросок"
    case release = "Выпуск дротика"
    case resultPending = "Ожидание результата"
    case resultShown = "Результат на экране"

    var icon: String {
        switch self {
        case .idle: return "moon.zzz"
        case .playerVisible: return "person.fill"
        case .preparing: return "figure.stand"
        case .throwing: return "figure.handball"
        case .release: return "arrow.up.forward"
        case .resultPending: return "hourglass"
        case .resultShown: return "number.circle.fill"
        }
    }
}

/// Фаза игры (ИИ)
enum GamePhase: String, Codable {
    case idle = "Ожидание"
    case playerVisible = "Игрок на экране"
    case playerPreparing = "Игрок готовится"
    case throwing = "Бросок!"
    case resultShown = "Результат"
    case bettingWindow = "Время на ставку"
    case watchingResults = "Смотрим результаты"

    var icon: String {
        switch self {
        case .idle: return "moon.zzz"
        case .playerVisible: return "person.fill"
        case .playerPreparing: return "figure.stand"
        case .throwing: return "figure.handball"
        case .resultShown: return "number.circle.fill"
        case .bettingWindow: return "timer"
        case .watchingResults: return "eye"
        }
    }
}

/// Распознанное действие игрока (ИИ)
enum PlayerActionType: String, Codable, CaseIterable {
    case none = "Нет действия"
    case stance = "Позиция"
    case aim = "Прицеливание"
    case windup = "Замах"
    case throwMotion = "Бросок"
    case release = "Выпуск"
    case recovery = "Восстановление"

    var id: Int {
        switch self {
        case .none: return 0
        case .stance: return 1
        case .aim: return 2
        case .windup: return 3
        case .throwMotion: return 4
        case .release: return 5
        case .recovery: return 6
        }
    }
}

/// Инсайт ИИ-анализа текущего кадра
struct AIActionInsight: Codable, Equatable {
    var sceneState: GameSceneState = .idle
    var detectedAction: PlayerActionType = .none
    var actionConfidence: Double = 0
    var playerDetected: Bool = false
    var playerEmbedding: [Double] = []
    var motionIntensity: Double = 0
    var throwPhaseProgress: Double = 0
    var aiDescription: String = ""
    var numberScores: [Int: Double] = [:]

    static let empty = AIActionInsight()
}

/// Полный снимок игровой сцены (ИИ)
struct GameSnapshot: Equatable {
    let timestamp: Date
    let detectedNumbers: [DetectedNumber]
    let bettingSeconds: Double?
    let phase: GamePhase
    let aiInsight: AIActionInsight
    let playerFeatures: PlayerFeatures
    let throwInProgress: Bool
    let throwCompleted: Bool
    let confirmedResult: Int?
    let forecastsAccepted: Bool
    let processingTimeMs: Double
}

/// Прогнозируемая комбинация 4 чисел
struct PredictedCombination: Codable, Equatable, Identifiable {
    let id: UUID
    let numbers: [Int]
    let individualProbabilities: [Double]
    let jointProbability: Double
    let combinationScore: Double

    init(
        id: UUID = UUID(),
        numbers: [Int],
        individualProbabilities: [Double],
        jointProbability: Double,
        combinationScore: Double
    ) {
        self.id = id
        self.numbers = numbers
        self.individualProbabilities = individualProbabilities
        self.jointProbability = jointProbability
        self.combinationScore = combinationScore
    }

    var formatted: String {
        numbers.map(String.init).joined(separator: " · ")
    }
}

/// Результат анализа одного кадра сцены (legacy)
struct SceneAnalysisResult: Equatable {
    let timestamp: Date
    let sceneState: GameSceneState
    let aiInsight: AIActionInsight
    let playerFeatures: PlayerFeatures
    let detectedNumbers: [DetectedNumber]
    let confirmedNewThrow: Int?
    let processingTimeMs: Double
}

struct DetectedNumber: Equatable {
    let value: Int
    let boundingBox: CGRect
    let confidence: Float
}
