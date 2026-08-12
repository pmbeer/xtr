import CoreGraphics
import Foundation

struct CaptureRegion: Equatable {
    var x: Double = 0.68
    var y: Double = 0.48
    var width: Double = 0.30
    var height: Double = 0.45

    var visionRegion: CGRect {
        CGRect(
            x: max(0, min(1, x)),
            y: max(0, min(1, 1 - y - height)),
            width: max(0.01, min(1 - x, width)),
            height: max(0.01, min(1 - y, height))
        )
    }
}

struct OCRSnapshot: Equatable {
    let values: [Int]
    let rawText: String
    let latencyMilliseconds: Int
}

struct BetCandidate: Equatable {
    let label: String
    let hits: Int
    let fairProbability: Double
    let posteriorProbability: Double
    let lowerConfidenceBound: Double
}

struct Recommendation: Equatable {
    let title: String
    let detail: String
    let candidate: BetCandidate?

    static let collecting = Recommendation(
        title: "Собираю историю",
        detail: "Нужно не менее 30 распознанных бросков.",
        candidate: nil
    )
}
