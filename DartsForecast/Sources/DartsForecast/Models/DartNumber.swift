import Foundation

/// Допустимые числа дартса: 1…20 и булл (25).
public enum DartNumber: Int, Codable, CaseIterable, Hashable, CustomStringConvertible, Sendable {
    case n1 = 1, n2, n3, n4, n5, n6, n7, n8, n9, n10
    case n11, n12, n13, n14, n15, n16, n17, n18, n19, n20
    case bull = 25

    var description: String {
        self == .bull ? "25" : "\(rawValue)"
    }

    var displayName: String {
        self == .bull ? "Булл" : "\(rawValue)"
    }

    static let scoringValues: [Int] = Array(1...20) + [25]

    static func parse(_ value: Int) -> DartNumber? {
        if value == 25 || value == 50 { return .bull }
        guard (1...20).contains(value) else { return nil }
        return DartNumber(rawValue: value)
    }

    static func parseOCR(_ text: String) -> DartNumber? {
        let cleaned = text
            .uppercased()
            .replacingOccurrences(of: "O", with: "0")
            .replacingOccurrences(of: "I", with: "1")
            .replacingOccurrences(of: "L", with: "1")
            .replacingOccurrences(of: "BULL", with: "25")
            .replacingOccurrences(of: "БЫЛЛ", with: "25")
            .replacingOccurrences(of: "БУЛЛ", with: "25")
            .filter { $0.isNumber }
        guard let value = Int(cleaned) else { return nil }
        return parse(value)
    }
}

public enum ModelKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case sequence
    case frequency
    case transition
    case playerBehavior
    case timing

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sequence: return "Sequence"
        case .frequency: return "Frequency"
        case .transition: return "Transition"
        case .playerBehavior: return "PlayerBehavior"
        case .timing: return "Timing"
        }
    }

    /// Стартовые веса ансамбля (сумма = 1.0).
    var defaultWeight: Double {
        switch self {
        case .sequence: return 0.20
        case .frequency: return 0.15
        case .transition: return 0.20
        case .playerBehavior: return 0.30
        case .timing: return 0.15
        }
    }
}

public enum ConfidenceLevel: String, Codable, Sendable {
    case high = "HIGH"
    case medium = "MEDIUM"
    case low = "LOW"

    var displayName: String { rawValue }
}

public enum LearningPhase: String, Codable, Sendable {
    case dataCollection = "СБОР ДАННЫХ"
    case calibration = "КАЛИБРОВКА"
    case adaptiveLearning = "АДАПТИВНОЕ ОБУЧЕНИЕ"
    case stableModel = "СТАБИЛЬНАЯ МОДЕЛЬ"

    static func resolve(samples: Int, top4Accuracy: Double) -> LearningPhase {
        if samples < 30 { return .dataCollection }
        if samples < 100 { return .calibration }
        if samples < 300 || top4Accuracy < 0.40 { return .adaptiveLearning }
        return .stableModel
    }
}
