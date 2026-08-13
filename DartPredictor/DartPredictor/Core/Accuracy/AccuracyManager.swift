import Foundation
import Combine

@MainActor
final class AccuracyManager: ObservableObject {
    static let shared = AccuracyManager()

    @Published var stats: AccuracyStats = AccuracyStats()

    func update(from profile: PlayerProfile) {
        stats = profile.accuracyStats
    }

    func formattedTop1() -> String {
        String(format: "%.1f%%", stats.top1Accuracy)
    }

    func formattedTop4() -> String {
        String(format: "%.1f%%", stats.top4Accuracy)
    }

    func formattedRecent(_ count: Int) -> String {
        String(format: "%.1f%%", stats.accuracyForLast(count))
    }

    func formattedOverall() -> String {
        String(format: "%.1f%%", stats.overallAccuracy)
    }
}
