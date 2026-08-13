import Foundation
import Combine

@MainActor
final class HistoryManager: ObservableObject {
    static let shared = HistoryManager()

    @Published var entries: [PredictionEntry] = []

    private let store = PredictionStore.shared

    func load() {
        entries = store.entries
    }

    func append(_ entry: PredictionEntry) {
        store.appendEntry(entry)
        entries = store.entries
    }

    func update(_ entry: PredictionEntry) {
        store.updateEntry(entry)
        entries = store.entries
    }

    var displayEntries: [PredictionEntry] {
        entries.sorted { $0.timestamp > $1.timestamp }
    }
}
