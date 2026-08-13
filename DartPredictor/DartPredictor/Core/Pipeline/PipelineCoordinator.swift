import Foundation
import Combine
import CoreGraphics

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

    private let regionCapture = RegionFrameCapture.shared
    private let gameAI = GameAIAnalyzer.shared
    private let learningEngine = LearningEngine.shared
    private let historyManager = HistoryManager.shared
    private let profileManager = PlayerProfileManager.shared
    private let accuracyManager = AccuracyManager.shared
    private let store = PredictionStore.shared

    private var timerCancellable: AnyCancellable?
    private var lastPendingEntry: PredictionEntry?
    private var currentFeatures: PlayerFeatures = .zero
    private var currentAIInsight: AIActionInsight = .empty

    func start() async {
        guard !isRunning else { return }

        guard let region = SettingsManager.shared.monitorRegion else {
            processingState = "Сначала выберите область игры"
            return
        }

        if !regionCapture.checkScreenRecordingPermission() {
            needsScreenPermission = true
            processingState = "Нужно разрешение «Запись экрана»"
            regionCapture.requestScreenRecordingPermission()
            return
        }

        profileManager.load()
        regionCapture.configure(region: region.rect)

        regionCapture.startCapture { [weak self] image in
            Task { @MainActor in
                self?.handleFrame(image)
            }
        }

        isRunning = regionCapture.isCapturing
        if isRunning {
            processingState = "ИИ анализирует область игры..."
            startDecisionTimer()
            publishInitialPrediction()
        } else {
            captureError = regionCapture.lastError
            processingState = regionCapture.lastError ?? "Не удалось запустить захват"
        }
    }

    func stop() {
        regionCapture.stopCapture()
        gameAI.reset()
        isRunning = false
        processingState = "Остановлен"
        timerCancellable?.cancel()
        livePreviewImage = nil
    }

    func requestPermission() {
        regionCapture.requestScreenRecordingPermission()
        needsScreenPermission = false
    }

    private func handleFrame(_ image: CGImage) {
        captureFrames = regionCapture.framesCaptured
        lastCropSize = CGSize(width: image.width, height: image.height)
        livePreviewImage = image
        captureError = regionCapture.lastError
        needsScreenPermission = !regionCapture.hasScreenPermission

        gameAI.analyze(image: image) { [weak self] snapshot in
            Task { @MainActor in
                self?.applySnapshot(snapshot)
            }
        }
    }

    private func applySnapshot(_ snapshot: GameSnapshot) {
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
        processingState = status

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
