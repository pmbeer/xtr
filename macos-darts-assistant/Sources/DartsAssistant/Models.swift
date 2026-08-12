import CoreGraphics
import Foundation

struct CaptureRegion: Equatable {
    var x: Double = 0.68
    var y: Double = 0.68
    var width: Double = 0.30
    var height: Double = 0.30

    var visionRegion: CGRect {
        let minimumSize = 0.01
        let clampedX = max(0, min(1 - minimumSize, x))
        let topY = max(0, min(1 - minimumSize, y))
        let clampedWidth = max(minimumSize, min(1 - clampedX, width))
        let clampedHeight = max(minimumSize, min(1 - topY, height))

        return CGRect(
            x: clampedX,
            y: 1 - topY - clampedHeight,
            width: clampedWidth,
            height: clampedHeight
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
