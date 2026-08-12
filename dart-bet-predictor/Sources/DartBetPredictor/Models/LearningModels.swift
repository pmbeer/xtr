import Foundation

/// Снимок поведения игрока в момент анализа кадра.
struct PlayerBehaviorSnapshot: Codable, Equatable {
    var armRaise: Double = 0          // 0..1 — поднятие руки
    var lateralLean: Double = 0       // -1..1 — наклон влево/вправо
    var motionIntensity: Double = 0   // 0..1 — активность движения
    var shoulderAngle: Double = 0     // угол плеч (градусы)
    var phase: PlayerPhase = .idle
    var bodyDetected: Bool = false
    var capturedAt: Date = Date()

    /// Компактный ключ для обучения (дискретизация признаков).
    var behaviorKey: String {
        let arm = Int((armRaise * 4).rounded())
        let lean = Int(((lateralLean + 1) * 2).rounded())
        let motion = Int((motionIntensity * 4).rounded())
        return "p\(phase.rawValue)_a\(arm)_l\(lean)_m\(motion)"
    }

    var summary: String {
        if bodyDetected {
            return "\(phase.displayName) · рука \(Int(armRaise * 100))% · движ. \(Int(motionIntensity * 100))%"
        }
        if motionIntensity > 0.015 {
            return "Видео активно · движ. \(Int(motionIntensity * 100))% · \(phase.displayName)"
        }
        return "Нет сигнала — расширьте область видео игрока"
    }
}

enum PlayerPhase: Int, Codable, CaseIterable {
    case idle = 0
    case aiming = 1
    case windup = 2
    case release = 3

    var displayName: String {
        switch self {
        case .idle: return "Покой"
        case .aiming: return "Прицел"
        case .windup: return "Замах"
        case .release: return "Бросок"
        }
    }
}

/// Признаки для обучения модели.
struct PredictionFeatures: Codable {
    let lastSector: Int?
    let secondLastSector: Int?
    let evenRatio: Double
    let lowRatio: Double
    let hotSector: Int?
    let behaviorKey: String
    let armRaise: Double
    let motionIntensity: Double
    let playerPhase: Int
    let strategyVotes: [String: Double]

    static func build(
        history: [DartSector],
        behavior: PlayerBehaviorSnapshot,
        strategyVotes: [String: Double]
    ) -> PredictionFeatures {
        let recent = Array(history.prefix(10))
        let evenCount = Double(recent.filter { $0.isEven && $0 != .bullseye }.count)
        let lowCount = Double(recent.filter(\.isLow).count)
        let denom = max(1, Double(recent.count))

        var counts: [Int: Int] = [:]
        for s in recent where s != .bullseye {
            counts[s.rawValue, default: 0] += 1
        }
        let hot = counts.max(by: { $0.value < $1.value })?.key

        return PredictionFeatures(
            lastSector: history.first?.rawValue,
            secondLastSector: history.dropFirst().first?.rawValue,
            evenRatio: evenCount / denom,
            lowRatio: lowCount / denom,
            hotSector: hot,
            behaviorKey: behavior.behaviorKey,
            armRaise: behavior.armRaise,
            motionIntensity: behavior.motionIntensity,
            playerPhase: behavior.phase.rawValue,
            strategyVotes: strategyVotes
        )
    }

    var contextKey: String {
        "\(lastSector ?? -1)_\(secondLastSector ?? -1)_\(behaviorKey)"
    }
}

/// Ожидающая проверки ставка (сделана после броска N, проверяется на броске N+1).
struct PendingPrediction: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let betType: BetType
    let number: Int?
    let confidence: Double
    let reason: String
    let strategy: String
    let features: PredictionFeatures
    let behaviorAtPrediction: PlayerBehaviorSnapshot

    init(from recommendation: BetRecommendation, features: PredictionFeatures, behavior: PlayerBehaviorSnapshot) {
        id = recommendation.id
        createdAt = Date()
        betType = recommendation.betType
        number = recommendation.number
        confidence = recommendation.confidence
        reason = recommendation.reason
        strategy = recommendation.strategy
        self.features = features
        behaviorAtPrediction = behavior
    }

    func isCorrect(for sector: DartSector) -> Bool {
        betType.matches(sector, number: number)
    }
}

/// Результат проверки прогноза.
struct PredictionOutcome: Identifiable, Codable {
    let id: UUID
    let predictedAt: Date
    let evaluatedAt: Date
    let betType: BetType
    let predictedNumber: Int?
    let actualSector: Int
    let wasCorrect: Bool
    let confidence: Double
    let behaviorKey: String
    let learningDelta: Double

    var displayResult: String {
        wasCorrect ? "✓ Верно" : "✗ Ошибка"
    }
}

/// Статистика обучения.
struct LearningStats: Codable, Equatable {
    var totalPredictions: Int = 0
    var correctPredictions: Int = 0
    var recentWindow: [Bool] = []
    var strategyWeights: [String: Double] = [:]
    var targetAccuracy: Double = 0.99
    var currentStreak: Int = 0
    var bestStreak: Int = 0
    var learningIterations: Int = 0
    var adaptiveLearningRate: Double = 0.15

    var overallAccuracy: Double {
        guard totalPredictions > 0 else { return 0 }
        return Double(correctPredictions) / Double(totalPredictions)
    }

    var recentAccuracy: Double {
        guard !recentWindow.isEmpty else { return 0 }
        return Double(recentWindow.filter { $0 }.count) / Double(recentWindow.count)
    }

    var progressToTarget: Double {
        min(1.0, recentAccuracy / targetAccuracy)
    }

    var recentAccuracyPercent: Int {
        Int((recentAccuracy * 100).rounded())
    }

    var overallAccuracyPercent: Int {
        Int((overallAccuracy * 100).rounded())
    }

    var streakDisplay: String {
        currentStreak > 0 ? "серия \(currentStreak)✓" : "—"
    }

    /// Фаза обучения для UI.
    var learningPhase: String {
        if totalPredictions < 5 { return "Сбор данных"
        }
        if recentAccuracy >= 0.85 { return "Высокая точность"
        }
        if recentAccuracy >= 0.55 { return "Активное обучение"
        }
        return "Калибровка"
    }
}
