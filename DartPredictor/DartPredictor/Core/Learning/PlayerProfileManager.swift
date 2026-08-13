import Foundation
import Combine

@MainActor
final class PlayerProfileManager: ObservableObject {
    static let shared = PlayerProfileManager()

    @Published var activeProfile: PlayerProfile = .unknown
    @Published var profiles: [PlayerProfile] = []

    private let store = PredictionStore.shared
    private let similarityThreshold = 0.35

    func load() {
        profiles = Array(store.playerProfiles.values)
        activeProfile = store.activeProfile
    }

    func setActiveProfile(_ profile: PlayerProfile) {
        activeProfile = profile
        SettingsManager.shared.settings.activePlayerProfileId = profile.id
        SettingsManager.shared.save()
        store.updateActiveProfile(profile)
    }

    func updateProfile(_ profile: PlayerProfile) {
        store.updateActiveProfile(profile)
        profiles = Array(store.playerProfiles.values)
        if profile.id == activeProfile.id {
            activeProfile = profile
        }
    }

    func detectPlayerChange(features: PlayerFeatures) -> Bool {
        guard activeProfile.id != PlayerProfile.unknownId,
              !activeProfile.featureClusters.isEmpty else { return false }

        let vector = features.vector
        let minDistance = activeProfile.featureClusters.map { euclideanDistance(vector, $0) }.min() ?? 0
        return minDistance > similarityThreshold
    }

    func createNewPlayer(name: String, features: PlayerFeatures) -> PlayerProfile {
        let id = UUID().uuidString
        var profile = PlayerProfile(id: id, name: name)
        profile.featureClusters.append(features.vector)
        store.updateActiveProfile(profile)
        profiles = Array(store.playerProfiles.values)
        return profile
    }

    func updateFeatureCluster(for profile: inout PlayerProfile, features: PlayerFeatures) {
        profile.featureClusters.append(features.vector)
        if profile.featureClusters.count > 100 {
            profile.featureClusters.removeFirst()
        }
    }

    private func euclideanDistance(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 1.0 }
        let sum = zip(a, b).map { ($0 - $1) * ($0 - $1) }.reduce(0, +)
        return sqrt(sum) / Double(a.count)
    }
}
