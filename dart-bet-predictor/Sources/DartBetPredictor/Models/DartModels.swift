import Foundation

/// Результат одного броска (1–20 или булл).
enum DartSector: Int, Codable, CaseIterable, Hashable, CustomStringConvertible {
    case one = 1, two, three, four, five, six, seven, eight, nine, ten
    case eleven, twelve, thirteen, fourteen, fifteen, sixteen, seventeen, eighteen, nineteen, twenty
    case bullseye = 25

    var description: String {
        switch self {
        case .bullseye: return "Булл"
        default: return "\(rawValue)"
        }
    }

    var isEven: Bool { rawValue % 2 == 0 }
    var isOdd: Bool { !isEven }
    var isLow: Bool { rawValue >= 1 && rawValue <= 10 }
    var isHigh: Bool { rawValue >= 11 && rawValue <= 20 }

    static func from(detected value: Int) -> DartSector? {
        if value == 25 || value == 50 { return .bullseye }
        guard (1...20).contains(value) else { return nil }
        return DartSector(rawValue: value)
    }
}

/// Тип ставки на интерфейсе FONBET.
enum BetType: String, CaseIterable, Identifiable, Codable {
    case number
    case even       // ЧЕТ
    case odd        // НЕЧЕТ
    case low        // 1-10
    case high       // 11-20
    case bullseye

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .number: return "Число"
        case .even: return "ЧЕТ"
        case .odd: return "НЕЧЕТ"
        case .low: return "1–10"
        case .high: return "11–20"
        case .bullseye: return "Булл"
        }
    }

    func matches(_ sector: DartSector, number: Int? = nil) -> Bool {
        switch self {
        case .number:
            guard let number else { return false }
            return sector.rawValue == number
        case .even: return sector.isEven && sector != .bullseye
        case .odd: return sector.isOdd
        case .low: return sector.isLow
        case .high: return sector.isHigh
        case .bullseye: return sector == .bullseye
        }
    }
}

/// Рекомендация ставки с уровнем уверенности.
struct BetRecommendation: Identifiable, Equatable {
    let id: UUID
    let betType: BetType
    let number: Int?
    /// До 4 секторов — цель: один из них выпадет (99%).
    let predictedNumbers: [Int]
    let confidence: Double
    let reason: String
    let strategy: String

    init(
        betType: BetType,
        number: Int?,
        predictedNumbers: [Int] = [],
        confidence: Double,
        reason: String,
        strategy: String,
        id: UUID = UUID()
    ) {
        self.id = id
        self.betType = betType
        self.number = number
        self.predictedNumbers = predictedNumbers
        self.confidence = confidence
        self.reason = reason
        self.strategy = strategy
    }

    var displayNumbers: [Int] {
        if !predictedNumbers.isEmpty { return predictedNumbers }
        if let number { return [number] }
        return []
    }

    var displayBet: String {
        let nums = displayNumbers
        if nums.count >= 2 {
            return nums.map(String.init).joined(separator: ", ")
        }
        switch betType {
        case .number:
            if let number { return "\(number)" }
            return "Число"
        default:
            return betType.displayName
        }
    }

    var confidencePercent: Int {
        Int((confidence * 100).rounded())
    }
}

/// Состояние окна ставки (5 секунд после подтверждения результата).
enum BettingPhase: Equatable {
    case idle
    case waitingForThrow
    /// Бросок выполнен — ждём стабильный результат на экране.
    case awaitingResult(pendingSector: DartSector?, stableReads: Int, requiredReads: Int)
    /// Результат подтверждён — 5 сек на ставку на СЛЕДУЮЩИЙ бросок.
    case bettingOpen(
        remainingSeconds: Double,
        recommendation: BetRecommendation,
        confirmedResult: DartSector
    )
}

struct ThrowEvent: Equatable {
    let sector: DartSector
    let detectedAt: Date
    let rawOCR: String
}
