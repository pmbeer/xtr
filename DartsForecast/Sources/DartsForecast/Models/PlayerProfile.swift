import Foundation

struct PlayerProfile: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var displayName: String
    var createdAt: Date
    var throwCount: Int
    var accuracy: AccuracySnapshot
    var modelWeights: [String: Double]
    var characteristicSequences: [[Int]]
    var timingMean: Double
    var timingStd: Double
    var behaviorKeys: [String: Int]

    static let unknownID = "unknown"

    static func makeUnknown() -> PlayerProfile {
        PlayerProfile(
            id: unknownID,
            displayName: "Unknown Player",
            createdAt: Date(),
            throwCount: 0,
            accuracy: AccuracySnapshot(),
            modelWeights: Dictionary(uniqueKeysWithValues: ModelKind.allCases.map { ($0.rawValue, $0.defaultWeight) }),
            characteristicSequences: [],
            timingMean: 8.0,
            timingStd: 3.0,
            behaviorKeys: [:]
        )
    }

    static func make(id: String, name: String) -> PlayerProfile {
        var p = makeUnknown()
        p.id = id
        p.displayName = name
        return p
    }
}
