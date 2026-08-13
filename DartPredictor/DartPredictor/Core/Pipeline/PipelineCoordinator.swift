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
    @Published var aiInsight: AIActionInsight = .empty
    @Published var currentCombination: PredictedCombination = PredictedCombination(
        numbers: [], individualProbabilities: [], jointProbability: 0, combinationScore: 0
    )
    @Published var detectedNumbersOnScreen: [Int] = []
    @Published var framesProcessed: Int = 0
    @Published var captureFrames: Int = 0
    @Published var lastCropSize: CGSize = .zero

    private let captureManager = ScreenCaptureManager.shared
    private let sceneAnalyzer = ScreenSceneAnalyzer.shared
    private let learningEngine = LearningEngine.shared
    private let historyManager = HistoryManager.shared
    private let profileManager = PlayerProfileManager.shared
    private let accuracyManager = AccuracyManager.shared
    private let store = PredictionStore.shared

    private var timerCancellable: AnyCancellable?
    private var statusTimer: AnyCancellable?
    private var lastPendingEntry: PredictionEntry?
    private var currentFeatures: PlayerFeatures = .zero
    private var currentAIInsight: AIActionInsight = .empty
    private var frameCounter = 0
    private let frameSkip = 0

    func start() async {
        guard !isRunning else { return }

        guard let region = SettingsManager.shared.monitorRegion else {
            processingState = "Выберите область экрана"
            return
        }

        captureManager.configureMonitorRegion(region.rect)
        profileManager.load()

        do {
            try await captureManager.startCapture { [weak self] image in
                Task { @MainActor in
                    self?.handleMonitorFrame(image)
                }
            }
            isRunning = true
            processingState = "ИИ наблюдает экран..."
            startDecisionTimer()
            startStatusRefresh()
            publishInitialPrediction()
        } catch {
            processingState = "Ошибка: \(error.localizedDescription)"
            DebugLogger.shared.logCaptureError(error.localizedDescription)
        }
    }

    func stop() async {
        await captureManager.stopCapture()
        sceneAnalyzer.reset()
        isRunning = false
        processingState = "Остановлен"
        timerCancellable?.cancel()
        statusTimer?.cancel()
    }

    private func handleMonitorFrame(_ image: CGImage) {
        frameCounter += 1
        guard frameCounter % (frameSkip + 1) == 0 else { return }

        captureFrames = captureManager.framesCaptured
        lastCropSize = captureManager.lastCropSize

        sceneAnalyzer.analyzeFrame(image) { [weak self] result in
            Task { @MainActor in
                self?.applySceneResult(result)
            }
        }
    }

    private func applySceneResult(_ result: SceneAnalysisResult) {
        framesProcessed += 1
        sceneState = result.sceneState
        aiInsight = result.aiInsight
        currentAIInsight = result.aiInsight
        lastPlayerFeatures = result.playerFeatures
        currentFeatures = result.playerFeatures
        detectedNumbersOnScreen = result.detectedNumbers.map(\.value)

        let nums = detectedNumbersOnScreen.map(String.init).joined(separator: ", ")
        if detectedNumbersOnScreen.isEmpty {
            processingState = "Кадр \(framesProcessed) · OCR: нет чисел · \(result.sceneState.rawValue)"
        } else {
            processingState = "Кадр \(framesProcessed) · Числа: \(nums) · \(result.aiInsight.detectedAction.rawValue)"
        }

        if let newThrow = result.confirmedNewThrow {
            Task { await handleConfirmedThrow(newThrow) }
        }
    }

    private func publishInitialPrediction() {
        var profile = profileManager.activeProfile
        let prediction = learningEngine.makePrediction(
            history: profile.throwHistory,
            features: .zero,
            profile: profile,
            aiInsight: .empty
        )
        currentPrediction = prediction
        currentCombination = prediction.combination
        processingState = "Прогноз готов · ожидание результатов на экране"
    }

    private func handleConfirmedThrow(_ number: Int) async {
        let startTime = CFAbsoluteTimeGetCurrent()
        processingState = "Результат \(number) → обучение..."

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

        decisionTimerRemaining = DartConstants.decisionWindowSeconds
        processingState = "✓ \(number) → комбинация: \(prediction.combination.formatted)"

        DebugLogger.shared.logThrowDetected(
            number: number,
            timeMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        )
    }

    private func startStatusRefresh() {
        statusTimer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.isRunning else { return }
                self.captureFrames = self.captureManager.framesCaptured
                self.lastCropSize = self.captureManager.lastCropSize
                if self.captureManager.framesCaptured == 0 {
                    self.processingState = "⚠ Нет кадров — проверьте разрешение «Запись экрана»"
                }
            }
    }

    private func startDecisionTimer() {
        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.decisionTimerRemaining > 0 {
                    self.decisionTimerRemaining -= 0.1
                }
            }
    }
}
