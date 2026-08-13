import Foundation
import Combine
import CoreGraphics

enum CaptureBackend: String {
    case windowCapture = "Окно"
    case screenCaptureKit = "Дисплей"
    case regionFrame = "RegionCapture"
    case none = "—"
}

@MainActor
final class PipelineCoordinator: ObservableObject {
    static let shared = PipelineCoordinator()

    @Published var currentPrediction: EnsemblePrediction = .empty
    @Published var lastResult: Int?
    @Published var lastOutcome: PredictionOutcome = .pending
    @Published var isRunning = false
    @Published var decisionTimerRemaining: Double = DartConstants.decisionWindowSeconds
    @Published var processingState: String = "Ожидание"
    @Published var lastPlayerFeatures: PlayerFeatures = .zero
    @Published var sceneState: GameSceneState = .idle
    @Published var gamePhase: GamePhase = .idle
    @Published var aiInsight: AIActionInsight = .empty
    @Published var currentCombination: PredictedCombination = PredictedCombination(
        numbers: [], individualProbabilities: [], jointProbability: 0, combinationScore: 0
    )
    @Published var detectedNumbersOnScreen: [Int] = []
    @Published var resultHistoryNumbers: [Int] = []
    @Published var dartboardMotion: Double = 0
    @Published var playerZoneMotion: Double = 0
    @Published var isLiveAnalyzing = false
    @Published var bettingSecondsOnScreen: Double?
    @Published var throwInProgress = false
    @Published var framesProcessed: Int = 0
    @Published var captureFrames: Int = 0
    @Published var lastCropSize: CGSize = .zero
    @Published var livePreviewImage: CGImage?
    @Published var captureError: String?
    @Published var needsScreenPermission = false
    @Published var captureBackend: CaptureBackend = .none

    private let regionCapture = RegionFrameCapture.shared
    private let windowCapture = WindowCaptureManager.shared
    private let screenCapture = ScreenCaptureManager.shared
    private let gameAI = GameAIAnalyzer.shared
    private let learningEngine = LearningEngine.shared
    private let historyManager = HistoryManager.shared
    private let profileManager = PlayerProfileManager.shared
    private let accuracyManager = AccuracyManager.shared
    private let store = PredictionStore.shared

    private var timerCancellable: AnyCancellable?
    private var permissionCancellable: AnyCancellable?
    private var lastPendingEntry: PredictionEntry?
    private var currentFeatures: PlayerFeatures = .zero
    private var currentAIInsight: AIActionInsight = .empty
    private var activeBackend: CaptureBackend = .none

    func start() async {
        guard !isRunning else { return }

        guard let window = SettingsManager.shared.selectedCaptureWindow else {
            processingState = "Сначала выберите окно с игрой (Safari / fon.bet)"
            return
        }

        if !regionCapture.checkScreenRecordingPermission() {
            needsScreenPermission = true
            processingState = "Нужно разрешение «Запись экрана»"
            regionCapture.requestScreenRecordingPermission()
            startPermissionPolling()
            return
        }

        needsScreenPermission = false
        profileManager.load()
        await stopCaptureInternal()

        let frameHandler: (CGImage) -> Void = { [weak self] image in
            Task { @MainActor in
                self?.handleFrame(image)
            }
        }

        do {
            try await windowCapture.startCapture(windowID: window.windowID, handler: frameHandler)
            activeBackend = .windowCapture
            captureBackend = .windowCapture
            isRunning = true
            processingState = "ИИ анализирует окно «\(window.shortLabel)»..."
            DebugLogger.shared.log("Capture backend: Window SCK \(window.displayTitle)", category: "capture")
        } catch {
            captureError = error.localizedDescription
            processingState = error.localizedDescription
            DebugLogger.shared.logCaptureError("Window capture failed: \(error.localizedDescription)")
        }

        if isRunning {
            startDecisionTimer()
            publishInitialPrediction()
        }
    }

    func stop() {
        Task { await stopCaptureInternal() }
        gameAI.reset()
        isRunning = false
        processingState = "Остановлен"
        timerCancellable?.cancel()
        permissionCancellable?.cancel()
        captureBackend = .none
        activeBackend = .none
    }

    func requestPermission() {
        regionCapture.requestScreenRecordingPermission()
        needsScreenPermission = false
        startPermissionPolling()
    }

    /// Снимок окна после выбора — проверка что программа видит игру
    func testCapturePreview() async {
        guard let window = SettingsManager.shared.selectedCaptureWindow else { return }

        if !regionCapture.checkScreenRecordingPermission() {
            needsScreenPermission = true
            captureError = "Нужно разрешение «Запись экрана»"
            return
        }

        do {
            let image = try await windowCapture.captureSnapshot(windowID: window.windowID)
            livePreviewImage = image
            lastCropSize = CGSize(width: image.width, height: image.height)
            captureError = nil
            captureBackend = .windowCapture
            processingState = "Окно выбрано — превью обновлено. Нажмите «Запустить»"

            gameAI.analyze(image: image, zones: SettingsManager.shared.settings.gameWindowZones) { [weak self] snapshot in
                Task { @MainActor in
                    self?.applySnapshot(snapshot, analyzeOnly: true)
                }
            }
        } catch {
            captureError = error.localizedDescription
            if let wcError = error as? WindowCaptureManager.WindowCaptureError,
               wcError == .windowNotFound {
                processingState = "Окно закрыто — выберите окно снова"
            }
        }
    }

    private func stopCaptureInternal() async {
        if windowCapture.isCapturing {
            await windowCapture.stopCapture()
        }
        if screenCapture.isCapturing {
            await screenCapture.stopCapture()
        }
        regionCapture.stopCapture()
    }

    private func startPermissionPolling() {
        permissionCancellable?.cancel()
        permissionCancellable = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if regionCapture.checkScreenRecordingPermission() {
                    self.needsScreenPermission = false
                    self.permissionCancellable?.cancel()
                    if !self.isRunning {
                        Task { await self.start() }
                    }
                }
            }
    }

    private func handleFrame(_ image: CGImage) {
        captureFrames = windowCapture.framesCaptured
        lastCropSize = windowCapture.lastCropSize
        livePreviewImage = image
        captureError = windowCapture.lastError
        needsScreenPermission = !regionCapture.hasScreenPermission
        isLiveAnalyzing = true

        let zones = SettingsManager.shared.settings.gameWindowZones
        gameAI.analyze(image: image, zones: zones) { [weak self] snapshot in
            Task { @MainActor in
                self?.applySnapshot(snapshot)
            }
        }
    }

    private func applySnapshot(_ snapshot: GameSnapshot, analyzeOnly: Bool = false) {
        framesProcessed += 1
        isLiveAnalyzing = false
        gamePhase = snapshot.phase
        sceneState = snapshot.aiInsight.sceneState
        aiInsight = snapshot.aiInsight
        currentAIInsight = snapshot.aiInsight
        lastPlayerFeatures = snapshot.playerFeatures
        currentFeatures = snapshot.playerFeatures
        resultHistoryNumbers = snapshot.resultHistory
        detectedNumbersOnScreen = snapshot.resultHistory
        dartboardMotion = snapshot.dartboardMotion
        playerZoneMotion = snapshot.playerMotion
        bettingSecondsOnScreen = snapshot.bettingSeconds
        throwInProgress = snapshot.throwInProgress

        if let sec = snapshot.bettingSeconds {
            decisionTimerRemaining = sec
        }

        let history = resultHistoryNumbers.map(String.init).joined(separator: " → ")
        var status = "LIVE · Фаза: \(snapshot.phase.rawValue)"
        if !history.isEmpty { status += " · История: \(history)" }
        if let sec = snapshot.bettingSeconds {
            status += " · Таймер: \(String(format: "%.1f", sec))с"
        }
        if snapshot.forecastsAccepted {
            status += " · Ставки закрыты"
        }
        if snapshot.throwInProgress { status += " · БРОСОК" }
        status += " · Доска \(Int(snapshot.dartboardMotion * 100))%"
        if !analyzeOnly {
            processingState = status
        }

        if let newThrow = snapshot.confirmedResult {
            Task { await handleConfirmedThrow(newThrow) }
        }
    }

    private func publishInitialPrediction() {
        let profile = profileManager.activeProfile
        let prediction = learningEngine.makePrediction(
            history: profile.throwHistory,
            features: .zero,
            profile: profile,
            aiInsight: .empty
        )
        currentPrediction = prediction
        currentCombination = prediction.combination
    }

    private func handleConfirmedThrow(_ number: Int) async {
        let startTime = CFAbsoluteTimeGetCurrent()
        processingState = "✓ Результат \(number) → ИИ обучается..."

        var profile = profileManager.activeProfile
        let history = profile.throwHistory

        if profileManager.detectPlayerChange(features: currentFeatures) {
            let newProfile = profileManager.createNewPlayer(
                name: "Player \(profileManager.profiles.count + 1)",
                features: currentFeatures
            )
            profileManager.setActiveProfile(newProfile)
            profile = newProfile
        }

        profileManager.updateFeatureCluster(for: &profile, features: currentFeatures)

        var outcome: PredictionOutcome = .pending
        if let pending = lastPendingEntry {
            outcome = learningEngine.processNewThrow(
                actual: number,
                history: history,
                features: pending.playerFeatures,
                profile: &profile,
                previousEntry: pending,
                aiInsight: currentAIInsight
            )
            var updated = pending
            updated.actualResult = number
            updated.predictionOutcome = outcome
            historyManager.update(updated)
        }

        store.appendThrow(number, to: profile.id)
        if let updated = store.playerProfiles[profile.id] {
            profile = updated
        }
        profileManager.updateProfile(profile)
        accuracyManager.update(from: profile)

        lastResult = number
        lastOutcome = outcome

        let prediction = learningEngine.makePrediction(
            history: profile.throwHistory,
            features: currentFeatures,
            profile: profile,
            aiInsight: currentAIInsight
        )
        currentPrediction = prediction
        currentCombination = prediction.combination

        let entry = PredictionEntry(
            previousResults: history,
            currentResult: number,
            playerFeatures: currentFeatures,
            predictedNumbers: prediction.predictions.map(\.number),
            predictedProbabilities: prediction.predictions.map(\.probability),
            predictionOutcome: .pending,
            playerProfileId: profile.id,
            processingTimeMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        )
        lastPendingEntry = entry
        historyManager.append(entry)

        processingState = "Прогноз: \(prediction.combination.formatted)"
        DebugLogger.shared.logThrowDetected(number: number, timeMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000)
    }

    private func startDecisionTimer() {
        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.bettingSecondsOnScreen == nil else { return }
                if self.decisionTimerRemaining > 0 {
                    self.decisionTimerRemaining -= 0.1
                }
            }
    }
}
