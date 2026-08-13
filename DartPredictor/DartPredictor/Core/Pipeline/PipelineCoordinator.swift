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

    private let captureManager = ScreenCaptureManager.shared
    private let sceneAnalyzer = ScreenSceneAnalyzer.shared
    private let learningEngine = LearningEngine.shared
    private let historyManager = HistoryManager.shared
    private let profileManager = PlayerProfileManager.shared
    private let accuracyManager = AccuracyManager.shared
    private let store = PredictionStore.shared

    private var timerCancellable: AnyCancellable?
    private var lastPendingEntry: PredictionEntry?
    private var currentFeatures: PlayerFeatures = .zero
    private var currentAIInsight: AIActionInsight = .empty
    private var frameCounter = 0
    private let frameSkip = 1

    func start() async {
        guard !isRunning else { return }

        let settings = SettingsManager.shared.settings
        guard let region = settings.monitorRegion else {
            processingState = "Выберите область экрана"
            return
        }

        captureManager.configureMonitorRegion(region.rect)

        do {
            try await captureManager.startCapture { [weak self] image in
                Task { @MainActor in
                    self?.handleMonitorFrame(image)
                }
            }
            isRunning = true
            processingState = "ИИ наблюдает экран"
            startDecisionTimer()
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
    }

    private func handleMonitorFrame(_ image: CGImage) {
        frameCounter += 1
        guard frameCounter % (frameSkip + 1) == 0 else { return }

        sceneAnalyzer.analyzeFrame(image) { [weak self] result in
            Task { @MainActor in
                self?.applySceneResult(result)
            }
        }
    }

    private func applySceneResult(_ result: SceneAnalysisResult) {
        sceneState = result.sceneState
        aiInsight = result.aiInsight
        currentAIInsight = result.aiInsight
        lastPlayerFeatures = result.playerFeatures
        currentFeatures = result.playerFeatures
        detectedNumbersOnScreen = result.detectedNumbers.map(\.value)

        processingState = "\(result.sceneState.rawValue) · \(result.aiInsight.detectedAction.rawValue)"

        if let newThrow = result.confirmedNewThrow {
            Task { await handleConfirmedThrow(newThrow) }
        }
    }

    private func handleConfirmedThrow(_ number: Int) async {
        let startTime = CFAbsoluteTimeGetCurrent()
        processingState = "ИИ: результат \(number), обучение..."

        var profile = profileManager.activeProfile
        let history = profile.throwHistory

        // Определение игрока по ИИ-embedding
        if profileManager.detectPlayerChange(features: currentFeatures) ||
            detectPlayerChangeByAI(insight: currentAIInsight, profile: profile) {
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
        processingState = "Комбинация: \(prediction.combination.formatted)"

        DebugLogger.shared.logThrowDetected(
            number: number,
            timeMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        )
    }

    private func detectPlayerChangeByAI(insight: AIActionInsight, profile: PlayerProfile) -> Bool {
        guard !insight.playerEmbedding.isEmpty, !profile.featureClusters.isEmpty else { return false }
        let minDist = profile.featureClusters.map { dist(insight.playerEmbedding, $0) }.min() ?? 0
        return minDist > 0.4
    }

    private func dist(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 1 }
        let sum = zip(a, b).map { ($0 - $1) * ($0 - $1) }.reduce(0, +)
        return sqrt(sum) / Double(a.count)
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
