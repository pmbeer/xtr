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
    @Published var lastLiveUpdate: Date?
    @Published var liveTick: Int = 0
    @Published var bettingSecondsOnScreen: Double?
    @Published var throwInProgress = false
    @Published var framesProcessed: Int = 0
    @Published var captureFrames: Int = 0
    @Published var lastCropSize: CGSize = .zero
    @Published var livePreviewImage: CGImage?
    @Published var captureError: String?
    @Published var needsScreenPermission = false
    @Published var captureBackend: CaptureBackend = .none
    @Published var predictionRationale: String = ""

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
    private var analysisCancellable: AnyCancellable?
    private var heartbeatCancellable: AnyCancellable?
    private var permissionCancellable: AnyCancellable?
    private var lastPendingEntry: PredictionEntry?
    private var currentFeatures: PlayerFeatures = .zero
    private var currentAIInsight: AIActionInsight = .empty
    private var activeBackend: CaptureBackend = .none
    private var latestFrame: CGImage?
    private var lastCaptureCount = 0
    private var staleCaptureSeconds = 0
    private var analysisInFlight = false
    private var lastPredictionHistory: [Int] = []
    private var lastLivePredictionAt: Date = .distantPast
    private var lastPoseSignature: String = ""

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
            staleCaptureSeconds = 0
            lastCaptureCount = 0
            processingState = "LIVE · захват окна «\(window.shortLabel)»..."
            DebugLogger.shared.log("Capture backend: Window SCK \(window.displayTitle)", category: "capture")
        } catch {
            captureError = error.localizedDescription
            processingState = error.localizedDescription
            DebugLogger.shared.logCaptureError("Window capture failed: \(error.localizedDescription)")
        }

        if isRunning {
            startDecisionTimer()
            startLiveAnalysisLoop()
            startHeartbeat()
            publishInitialPrediction()
        }
    }

    func stop() {
        Task { await stopCaptureInternal() }
        gameAI.reset()
        isRunning = false
        processingState = "Остановлен"
        timerCancellable?.cancel()
        analysisCancellable?.cancel()
        heartbeatCancellable?.cancel()
        permissionCancellable?.cancel()
        captureBackend = .none
        activeBackend = .none
        latestFrame = nil
        analysisInFlight = false
        isLiveAnalyzing = false
    }

    func requestPermission() {
        regionCapture.requestScreenRecordingPermission()
        needsScreenPermission = false
        startPermissionPolling()
    }

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

    /// Захват: только обновление превью (без тяжёлого ИИ на каждый кадр)
    private func handleFrame(_ image: CGImage) {
        latestFrame = image
        livePreviewImage = image
        captureFrames = windowCapture.framesCaptured
        lastCropSize = CGSize(width: image.width, height: image.height)
        captureError = windowCapture.lastError
        needsScreenPermission = !regionCapture.hasScreenPermission
        liveTick += 1
    }

    /// ИИ: отдельный таймер 3 Гц — не блокирует поток кадров
    private func startLiveAnalysisLoop() {
        analysisCancellable?.cancel()
        analysisCancellable = Timer.publish(every: 0.33, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.runLiveAnalysis()
            }
    }

    private func runLiveAnalysis() {
        guard isRunning, let frame = latestFrame else { return }
        if analysisInFlight { return }

        analysisInFlight = true
        isLiveAnalyzing = true
        let zones = SettingsManager.shared.settings.gameWindowZones

        gameAI.analyzeLive(image: frame, zones: zones) { [weak self] snapshot in
            Task { @MainActor in
                guard let self else { return }
                self.analysisInFlight = false
                self.isLiveAnalyzing = false
                self.applySnapshot(snapshot)
            }
        }
    }

    /// Пульс UI + перезапуск захвата если кадры остановились
    private func startHeartbeat() {
        heartbeatCancellable?.cancel()
        heartbeatCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.isRunning else { return }

                let count = self.windowCapture.framesCaptured
                if count == self.lastCaptureCount {
                    self.staleCaptureSeconds += 1
                } else {
                    self.staleCaptureSeconds = 0
                    self.lastCaptureCount = count
                }

                if self.staleCaptureSeconds >= 4 {
                    self.staleCaptureSeconds = 0
                    Task { await self.restartCapture() }
                }

                if let last = self.lastLiveUpdate,
                   Date().timeIntervalSince(last) > 2.0,
                   !self.analysisInFlight {
                    self.runLiveAnalysis()
                }
            }
    }

    private func restartCapture() async {
        guard isRunning, let window = SettingsManager.shared.selectedCaptureWindow else { return }
        processingState = "LIVE · переподключение захвата..."
        await windowCapture.stopCapture()
        let handler: (CGImage) -> Void = { [weak self] image in
            Task { @MainActor in
                self?.handleFrame(image)
            }
        }
        do {
            try await windowCapture.startCapture(windowID: window.windowID, handler: handler)
            processingState = "LIVE · захват восстановлен"
        } catch {
            captureError = error.localizedDescription
        }
    }

    private func applySnapshot(_ snapshot: GameSnapshot, analyzeOnly: Bool = false) {
        framesProcessed += 1
        lastLiveUpdate = Date()
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
        var status = "LIVE · кадр \(captureFrames) · анализ #\(framesProcessed)"
        status += " · \(snapshot.phase.rawValue)"
        if !history.isEmpty { status += " · 🔴 \(history)" }
        if let sec = snapshot.bettingSeconds {
            status += " · ⏱ \(String(format: "%.1f", sec))с"
        }
        if snapshot.forecastsAccepted { status += " · ставки закрыты" }
        if snapshot.throwInProgress { status += " · БРОСОК" }
        status += " · 🔵\(Int(snapshot.dartboardMotion * 100))% 🟢\(Int(snapshot.playerMotion * 100))%"
        if !analyzeOnly {
            processingState = status
        }

        if let newThrow = snapshot.confirmedResult {
            Task { await handleConfirmedThrow(newThrow) }
        } else {
            refreshLivePrediction(snapshot: snapshot)
        }
    }

    /// Обновляет TOP-4 в online без ожидания подтверждённого броска
    private func refreshLivePrediction(snapshot: GameSnapshot) {
        let profile = profileManager.activeProfile
        let mergedHistory = ThrowHistoryMerger.merge(
            stored: profile.throwHistory,
            liveOCR: snapshot.resultHistory
        )

        let historyChanged = mergedHistory != lastPredictionHistory
        let interval = Date().timeIntervalSince(lastLivePredictionAt)
        let timerTick = interval >= 0.85
        let bettingActive = snapshot.phase == .bettingWindow || snapshot.bettingSeconds != nil
        let poseSignature = "\(snapshot.aiInsight.detectedAction.rawValue)-\(Int(snapshot.playerFeatures.armHeight * 100))-\(Int(snapshot.playerFeatures.bodyTilt * 100))"
        let poseChanged = snapshot.aiInsight.playerDetected && poseSignature != lastPoseSignature

        guard historyChanged || timerTick || bettingActive || poseChanged else { return }

        lastPredictionHistory = mergedHistory
        lastLivePredictionAt = Date()
        if poseChanged { lastPoseSignature = poseSignature }

        let prediction = learningEngine.makePrediction(
            history: mergedHistory,
            features: currentFeatures,
            profile: profile,
            aiInsight: currentAIInsight
        )
        currentPrediction = prediction
        currentCombination = prediction.combination
        predictionRationale = prediction.rationale
    }

    func onZonesUpdated() {
        gameAI.reset()
        lastPredictionHistory = []
        lastLivePredictionAt = .distantPast
        lastPoseSignature = ""
        if isRunning, latestFrame != nil {
            runLiveAnalysis()
        } else if SettingsManager.shared.selectedCaptureWindow != nil {
            Task { await testCapturePreview() }
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
        predictionRationale = prediction.rationale
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
        predictionRationale = prediction.rationale
        lastPredictionHistory = profile.throwHistory
        lastLivePredictionAt = Date()

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
