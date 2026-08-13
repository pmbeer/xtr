import Foundation
import Combine
import CoreGraphics

struct CaptureRegions: Codable, Equatable {
    var resultRegion: ScreenCaptureRegion?
    var playerRegion: ScreenCaptureRegion?
}

@MainActor
final class SettingsManager: ObservableObject {
    @Published var regions = CaptureRegions()
    @Published var paperMode: Bool = true
    @Published var onboardingDone: Bool = false
    @Published var floatingOverlayVisible: Bool = true
    @Published var showDebugInfo: Bool = false

    private let defaults = UserDefaults.standard
    private let regionsKey = "df.regions"
    private let paperKey = "df.paper"
    private let onboardKey = "df.onboard"
    private let overlayKey = "df.overlay"

    init() {
        paperMode = defaults.object(forKey: paperKey) as? Bool ?? true
        onboardingDone = defaults.bool(forKey: onboardKey)
        floatingOverlayVisible = defaults.object(forKey: overlayKey) as? Bool ?? true
        if let data = defaults.data(forKey: regionsKey),
           let decoded = try? JSONDecoder().decode(CaptureRegions.self, from: data) {
            regions = decoded
        }
    }

    func persist() {
        defaults.set(paperMode, forKey: paperKey)
        defaults.set(onboardingDone, forKey: onboardKey)
        defaults.set(floatingOverlayVisible, forKey: overlayKey)
        if let data = try? JSONEncoder().encode(regions) {
            defaults.set(data, forKey: regionsKey)
        }
    }

    var hasRequiredRegions: Bool {
        regions.resultRegion != nil
    }
}
