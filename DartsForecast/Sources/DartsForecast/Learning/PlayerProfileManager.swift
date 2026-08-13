import Foundation
import Combine

@MainActor
public final class PlayerProfileManager: ObservableObject {
    @Published private(set) var profiles: [PlayerProfile] = []
    @Published private(set) var activeProfileID: String = PlayerProfile.unknownID

    var activeProfile: PlayerProfile {
        profiles.first(where: { $0.id == activeProfileID }) ?? .makeUnknown()
    }

    init() {
        profiles = [.makeUnknown()]
    }

    func select(_ id: String) {
        if !profiles.contains(where: { $0.id == id }) {
            profiles.append(.make(id: id, name: id == PlayerProfile.unknownID ? "Unknown Player" : id))
        }
        activeProfileID = id
    }

    func markUnknown() {
        select(PlayerProfile.unknownID)
    }

    /// Простая эвристика смены игрока: резкое изменение тайминга/поведения.
    func maybeDetectPlayerChange(features: PlayerFeatures) {
        let profile = activeProfile
        guard profile.throwCount >= 15 else { return }
        let timingZ = abs(features.intervalSeconds - profile.timingMean) / max(0.5, profile.timingStd)
        if timingZ > 3.5 && features.bodyDetected == false {
            // Недостаточно сигнала — unknown
            markUnknown()
            DebugLog.info("PlayerProfile: switched to Unknown (timing anomaly)")
        }
    }

    func updateAfterThrow(features: PlayerFeatures, accuracy: AccuracySnapshot, weights: [String: Double]) {
        guard let idx = profiles.firstIndex(where: { $0.id == activeProfileID }) else { return }
        profiles[idx].throwCount += 1
        profiles[idx].accuracy = accuracy
        profiles[idx].modelWeights = weights
        profiles[idx].behaviorKeys[features.behaviorKey, default: 0] += 1

        // Скользящее среднее тайминга
        let n = Double(profiles[idx].throwCount)
        let oldMean = profiles[idx].timingMean
        let newMean = oldMean + (features.intervalSeconds - oldMean) / n
        let oldVar = profiles[idx].timingStd * profiles[idx].timingStd
        let newVar = oldVar + (features.intervalSeconds - oldMean) * (features.intervalSeconds - newMean)
        profiles[idx].timingMean = newMean
        profiles[idx].timingStd = sqrt(max(0.1, newVar / max(1, n)))
    }

    func load(_ list: [PlayerProfile], active: String) {
        profiles = list.isEmpty ? [.makeUnknown()] : list
        activeProfileID = active
        if !profiles.contains(where: { $0.id == active }) {
            activeProfileID = PlayerProfile.unknownID
        }
    }
}
