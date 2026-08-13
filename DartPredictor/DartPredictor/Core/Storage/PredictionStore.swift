import Foundation
import Combine

@MainActor
final class PredictionStore: ObservableObject {
    static let shared = PredictionStore()

    @Published private(set) var entries: [PredictionEntry] = []
    @Published private(set) var playerProfiles: [String: PlayerProfile] = [:]

    private let storageDir: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("DartPredictor", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageDir = dir
        loadAll()
        if playerProfiles.isEmpty {
            playerProfiles[PlayerProfile.unknownId] = PlayerProfile.unknown
        }
    }

    var activeProfile: PlayerProfile {
        let id = SettingsManager.shared.settings.activePlayerProfileId
        return playerProfiles[id] ?? PlayerProfile.unknown
    }

    func updateActiveProfile(_ profile: PlayerProfile) {
        playerProfiles[profile.id] = profile
        saveProfiles()
    }

    func appendEntry(_ entry: PredictionEntry) {
        entries.append(entry)
        if entries.count > 10000 {
            entries.removeFirst(entries.count - 10000)
        }
        saveEntries()
    }

    func updateEntry(_ entry: PredictionEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
            saveEntries()
        }
    }

    func throwHistory(for profileId: String) -> [Int] {
        playerProfiles[profileId]?.throwHistory ?? []
    }

    func appendThrow(_ number: Int, to profileId: String) {
        guard var profile = playerProfiles[profileId] else { return }
        profile.throwHistory.append(number)
        if profile.throwHistory.count > 5000 {
            profile.throwHistory.removeFirst(profile.throwHistory.count - 5000)
        }
        profile.lastActiveAt = Date()
        playerProfiles[profileId] = profile
        saveProfiles()
    }

    private func loadAll() {
        loadEntries()
        loadProfiles()
    }

    private func loadEntries() {
        let url = storageDir.appendingPathComponent("predictions.json")
        guard let data = try? Data(contentsOf: url),
              let decoded = try? decoder.decode([PredictionEntry].self, from: data) else { return }
        entries = decoded
    }

    private func loadProfiles() {
        let url = storageDir.appendingPathComponent("profiles.json")
        guard let data = try? Data(contentsOf: url),
              let decoded = try? decoder.decode([PlayerProfile].self, from: data) else { return }
        playerProfiles = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
    }

    private func saveEntries() {
        let url = storageDir.appendingPathComponent("predictions.json")
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func saveProfiles() {
        let url = storageDir.appendingPathComponent("profiles.json")
        let profiles = Array(playerProfiles.values)
        guard let data = try? encoder.encode(profiles) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
