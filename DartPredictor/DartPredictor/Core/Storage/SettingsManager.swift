import Foundation
import Combine

@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var settings: AppSettings = AppSettings()

    private let storageURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("DartPredictor", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("settings.json")
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? decoder.decode(AppSettings.self, from: data) else { return }
        settings = decoded
        migrateLegacyRegions()
        migrateZoneLayout()
        DebugLogger.shared.configure(enabled: settings.debugLoggingEnabled)
    }

    private func migrateZoneLayout() {
        if settings.zoneLayoutVersion < 4 {
            settings.gameWindowZones = .fonBetDefault
            settings.zoneLayoutVersion = 4
            save()
        }
    }

    func setGameWindowZones(_ zones: GameWindowZones) {
        settings.gameWindowZones = zones
        settings.zoneLayoutVersion = 4
        save()
    }

    func resetGameWindowZonesToDefault() {
        settings.gameWindowZones = .fonBetDefault
        settings.zoneLayoutVersion = 4
        save()
    }

    var monitorRegion: CaptureRegion? {
        if let game = region(for: .gameScreen) { return game }
        if let result = region(for: .result) {
            return CaptureRegion(type: .gameScreen, rect: result.rect)
        }
        return nil
    }

    var selectedCaptureWindow: CaptureWindowInfo? {
        settings.selectedCaptureWindow
    }

    var hasCaptureTarget: Bool {
        selectedCaptureWindow != nil || monitorRegion != nil
    }

    func setSelectedCaptureWindow(_ window: CaptureWindowInfo) {
        settings.selectedCaptureWindow = window
        save()
    }

    func setMonitorRegion(_ rect: CGRect) {
        setRegion(CaptureRegion(type: .gameScreen, rect: CaptureGeometry.normalizeRegion(rect)))
    }

    private func migrateLegacyRegions() {
        guard region(for: .gameScreen) == nil else { return }
        let legacy = settings.regions.filter { $0.type == .result || $0.type == .player }
        guard !legacy.isEmpty else { return }
        let united = legacy.map(\.rect).reduce(legacy[0].rect) { $0.union($1) }
        setRegion(CaptureRegion(type: .gameScreen, rect: united))
    }

    func save() {
        guard let data = try? encoder.encode(settings) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    func region(for type: CaptureRegionType) -> CaptureRegion? {
        settings.regions.first { $0.type == type }
    }

    func setRegion(_ region: CaptureRegion) {
        settings.regions.removeAll { $0.type == region.type }
        settings.regions.append(region)
        save()
    }

    func completeOnboarding() {
        settings.hasCompletedOnboarding = true
        save()
    }

    func setPaperPredictionMode(_ enabled: Bool) {
        settings.isPaperPredictionMode = enabled
        save()
    }
}
