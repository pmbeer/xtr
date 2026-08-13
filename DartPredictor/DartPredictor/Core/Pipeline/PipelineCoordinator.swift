import Foundation
import Combine
import CoreGraphics

enum CaptureBackend: String {
    case screenCaptureKit = "ScreenCaptureKit"
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

        guard let region = SettingsManager.shared.monitorRegion else {
            processingState = "Сначала выберите область игры"
            return
        }

        guard CaptureGeometry.isValidRegion(region.rect) else {
            processingState = "Область слишком мала — выберите область заново"
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

        let fps = SettingsManager.shared.settings.captureFrameRate
        let normalized = CaptureGeometry.normalizeRegion(region.rect)
        SettingsManager.shared.setMonitorRegion(normalized)

        await stopCaptureInternal()

        let frameHandler: (CGImage) -> Void = { [weak self] image in
            Task { @MainActor in
                self?.handleFrame(image)
            }
        }

        // ScreenCaptureKit — основной путь на macOS 14+
        screenCapture.configureMonitorRegion(normalized)
        do {
            try await screenCapture.startCapture(handler: frameHandler)
            activeBackend = .screenCaptureKit
            captureBackend = .screenCaptureKit
            isRunning = true
            processingState = "ИИ анализирует область игры (SCK)..."
            DebugLogger.shared.log("Capture backend: ScreenCaptureKit", category: "capture")
        } catch {
            DebugLogger.shared.logCaptureError("SCK failed: \(error.localizedDescription), fallback to RegionCapture")
            regionCapture.configure(region: normalized)
            regionCapture.startCapture(fps: fps, handler: frameHandler)
            activeBackend = regionCapture.isCapturing ? .regionFrame : .none
            captureBackend = activeBackend
            isRunning = regionCapture.isCapturing
            if isRunning {
                processingState = "ИИ анализирует область игры..."
            } else {
                captureError = regionCapture.lastError
                processingState = regionCapture.lastError ?? "Не удалось запустить захват"
            }
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

    /// Тестовый снимок после выбора области — показывает, что программа «видит» экран
    func testCapturePreview() async {
        guard let region = SettingsManager.shared.monitorRegion else { return }

        if !regionCapture.checkScreenRecordingPermission() {
            needsScreenPermission = true
            captureError = "Нужно разрешение «Запись экрана»"
            return
        }

        let normalized = CaptureGeometry.normalizeRegion(region.rect)

        if let image = regionCapture.captureSingleFrame(region: normalized) {
            livePreviewImage = image
            lastCropSize = CGSize(width: image.width, height: image.height)
            captureError = nil
            processingState = "Область выбрана — превью обновлено. Нажмите «Запустить»"
            gameAI.analyze(image: image) { [weak self] snapshot in
                Task { @MainActor in
                    self?.applySnapshot(snapshot, analyzeOnly: true)
                }
            }
        } else {
            captureError = "Не удалось снять экран — разрешите «Запись экрана» и попробуйте снова"
            needsScreenPermission = true
        }
    }

    private func stopCaptureInternal() async {
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
        if activeBackend == .screenCaptureKit {
            captureFrames = screenCapture.framesCaptured
            lastCropSize = screenCapture.lastCropSize
        } else {
            captureFrames = regionCapture.framesCaptured
            lastCropSize = CGSize(width: image.width, height: image.height)
        }
        livePreviewImage = image
        captureError = regionCapture.lastError
        needsScreenPermission = !regionCapture.hasScreenPermission

        gameAI.analyze(image: image) { [weak self] snapshot in
            Task { @MainActor in
                self?.applySnapshot(snapshot)
            }
        }
    }

    private func applySnapshot(_ snapshot: GameSnapshot, analyzeOnly: Bool = false) {
        framesProcessed += 1
        gamePhase = snapshot.phase
        sceneState = snapshot.aiInsight.sceneState
        aiInsight = snapshot.aiInsight
        currentAIInsight = snapshot.aiInsight
        lastPlayerFeatures = snapshot.playerFeatures
        currentFeatures = snapshot.playerFeatures
        detectedNumbersOnScreen = snapshot.detectedNumbers.map(\.value)
        bettingSecondsOnScreen = snapshot.bettingSeconds
        throwInProgress = snapshot.throwInProgress

        if let sec = snapshot.bettingSeconds {
            decisionTimerRemaining = sec
        }

        let nums = detectedNumbersOnScreen.map(String.init).joined(separator: ", ")
        var status = "Фаза: \(snapshot.phase.rawValue)"
        if !nums.isEmpty { status += " · Числа: \(nums)" }
        if let sec = snapshot.bettingSeconds {
            status += " · Таймер: \(String(format: "%.1f", sec))с"
        }
        if snapshot.throwInProgress { status += " · БРОСОК" }
        status += " · \(snapshot.aiInsight.detectedAction.rawValue)"
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
