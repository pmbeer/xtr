import Foundation

struct PersistedState: Codable {
    var history: [ThrowRecord]
    var resultSequence: [Int]
    var accuracy: AccuracySnapshot
    var ensemble: EnsemblePredictor.Snapshot
    var profiles: [PlayerProfile]
    var activeProfileID: String
    var paperMode: Bool
    var onboardingDone: Bool
}

@MainActor
final class PredictionStore {
    static let shared = PredictionStore()

    private let url: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("DartsForecast", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("state.json")
        encoder.outputFormatting = [.sortedKeys]
    }

    func load() -> PersistedState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try decoder.decode(PersistedState.self, from: data)
        } catch {
            DebugLog.error("Load state failed: \(error)")
            return nil
        }
    }

    func save(_ state: PersistedState) {
        do {
            // Не раздуваем файл: храним последние N записей истории.
            var trimmed = state
            if trimmed.history.count > HardwareProfile.maxHistoryInMemory {
                trimmed.history = Array(trimmed.history.suffix(HardwareProfile.maxHistoryInMemory))
            }
            if trimmed.resultSequence.count > HardwareProfile.maxHistoryInMemory {
                trimmed.resultSequence = Array(trimmed.resultSequence.suffix(HardwareProfile.maxHistoryInMemory))
            }
            let data = try encoder.encode(trimmed)
            try data.write(to: url, options: .atomic)
        } catch {
            DebugLog.error("Save state failed: \(error)")
        }
    }

    func emptyState() -> PersistedState {
        PersistedState(
            history: [],
            resultSequence: [],
            accuracy: AccuracySnapshot(),
            ensemble: EnsemblePredictor().exportSnapshot(),
            profiles: [.makeUnknown()],
            activeProfileID: PlayerProfile.unknownID,
            paperMode: true,
            onboardingDone: false
        )
    }
}
