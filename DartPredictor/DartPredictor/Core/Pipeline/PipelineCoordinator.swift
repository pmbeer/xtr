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

    private let captureManager = ScreenCaptureManager.shared
    private let ocrManager = OCRManager.shared
    private let throwDetector = ThrowDetector()
    private let visionAnalyzer = PlayerVisionAnalyzer.shared
    private let learningEngine = LearningEngine.shared
    private let historyManager = HistoryManager.shared
    private let profileManager = PlayerProfileManager.shared
    private let accuracyManager = AccuracyManager.shared

    private var timerCancellable: AnyCancellable?
    private var lastPendingEntry: PredictionEntry?
    private var currentFeatures: PlayerFeatures = .zero
    private var ocrFrameCounter = 0
    private let ocrFrameSkip = 2

    func start() async {
        guard !isRunning else { return }

        let settings = SettingsManager.shared.settings
        captureManager.configure(regions: settings.regions)

        do {
            try await captureManager.startCapture { [weak self] image, type in
                Task { @MainActor in
                    self?.handleFrame(image: image, type: type)
                }
            }
            isRunning = true
            processingState = "Активен"
            startDecisionTimer()
        } catch {
            processingState = "Ошибка: \(error.localizedDescription)"
            DebugLogger.shared.logCaptureError(error.localizedDescription)
        }
    }

    func stop() async {
        await captureManager.stopCapture()
        isRunning = false
        processingState = "Остановлен"
        timerCancellable?.cancel()
    }

    private func handleFrame(image: CGImage, type: CaptureRegionType) {
        switch type {
        case .result:
            ocrFrameCounter += 1
            guard ocrFrameCounter % (ocrFrameSkip + 1) == 0 else { return }
            processResultFrame(image)
        case .player:
            processPlayerFrame(image)
        }
    }

    private func processResultFrame(_ image: CGImage) {
        ocrManager.recognizeNumber(from: image) { [weak self] number in
            Task { @MainActor in
                guard let self else { return }
                if let confirmed = self.ocrManager.processWithDebounce(recognized: number) {
                    await self.handleConfirmedThrow(confirmed)
                }
            }
        }
    }

    private func processPlayerFrame(_ image: CGImage) {
        visionAnalyzer.analyzeFrame(image) { [weak self] features in
            Task { @MainActor in
                self?.currentFeatures = features
                self?.lastPlayerFeatures = features
            }
        }
    }

    private func handleConfirmedThrow(_ number: Int) async {
        let startTime = CFAbsoluteTimeGetCurrent()
        processingState = "Обработка броска \(number)..."

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
                previousEntry: pending
            )

            var updated = pending
            updated.actualResult = number
            updated.predictionOutcome = outcome
            historyManager.update(updated)
        }

        store.appendThrow(number, to: profile.id)
        profileManager.updateProfile(profile)
        accuracyManager.update(from: profile)

        lastResult = number
        lastOutcome = outcome
        throwDetector.processOCRResult(number)

        let prediction = learningEngine.makePrediction(
            history: profile.throwHistory,
            features: currentFeatures,
            profile: profile
        )
        currentPrediction = prediction

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
        processingState = "Прогноз готов"

        DebugLogger.shared.logThrowDetected(
            number: number,
            timeMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        )
    }

    private let store = PredictionStore.shared

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
