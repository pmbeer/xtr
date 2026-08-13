import Foundation
import Combine

@MainActor
public final class AccuracyManager: ObservableObject {
    @Published private(set) var snapshot = AccuracySnapshot()

    func record(actual: Int, predicted: [Int]) {
        snapshot.record(actual: actual, predicted: predicted)
    }

    func load(_ snap: AccuracySnapshot) {
        snapshot = snap
    }

    var confidenceLabel: ConfidenceLevel {
        let recent = snapshot.windowAccuracy(snapshot.recent50)
        let n = snapshot.totalPredictions
        if n < 20 { return .low }
        if recent >= 0.55 && n >= 50 { return .high }
        if recent >= 0.40 { return .medium }
        return .low
    }
}
