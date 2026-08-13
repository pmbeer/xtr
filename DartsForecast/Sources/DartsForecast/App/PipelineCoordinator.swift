import Foundation
import Combine
import CoreGraphics

/// Полный pipeline: Capture → OCR → Throw → Vision → Predict → Learn → Persist.
@MainActor
final class PipelineCoordinator: ObservableObject {
    let capture = ScreenCaptureManager()
    let settings = SettingsManager()
    let history = HistoryManager()
    let learning = LearningEngine()
    let store = PredictionStore.shared

    private let ocr = OCRManager()
    private let throwDetector = ThrowDetector()
    private let playerVision = PlayerVisionAnalyzer()

    @Published var isRunning = false
    @Published var lastResult: Int?
    @Published var lastPrediction: Top4Prediction = .empty
    @Published var lastVerified: Bool?
    @Published var decisionDeadline: Date?
    @Published var statusText = "Готово"
    @Published var lastProcessingMs: Int = 0
    @Published var ocrProbeText = ""

    private var ocrTaskRunning = false
    private var playerTaskRunning = false
    private var recordCounter = 0

    init() {
        bootstrap()
        wireCapture()
    }

    private func bootstrap() {
        let state = store.load() ?? store.emptyState()
        history.load(records: state.history, sequence: state.resultSequence)
        learning.bootstrap(from: state)
        settings.paperMode = state.paperMode
        settings.onboardingDone = state.onboardingDone
        lastPrediction = learning.lastPrediction
        lastResult = state.resultSequence.last
        recordCounter = state.history.last?.index ?? 0
        Task {
            await throwDetector.seed(last: state.resultSequence.last)
        }
        statusText = settings.hasRequiredRegions ? "Области заданы" : "Нужно выбрать области"
    }

    private func wireCapture() {
        capture.onResultFrame = { [weak self] image in
            Task { @MainActor in
                await self?.handleResultFrame(image)
            }
        }
        capture.onPlayerFrame = { [weak self] image in
            Task { @MainActor in
                await self?.handlePlayerFrame(image)
            }
        }
    }

    func start() {
        guard settings.hasRequiredRegions else {
            statusText = "Сначала выберите область результата"
            return
        }
        capture.updateRegions(
            result: settings.regions.resultRegion,
            player: settings.regions.playerRegion
        )
        capture.start()
        isRunning = capture.isRunning
        statusText = settings.paperMode ? "Paper Prediction — мониторинг" : "Мониторинг"
        DebugLog.info("Pipeline started paper=\(settings.paperMode)")
    }

    func stop() {
        capture.stop()
        isRunning = false
        statusText = "Остановлено"
        persist()
    }

    func selectResultRegion() {
        RegionSelectorController.present(title: "Область №1 — результат игры") { [weak self] region in
            guard let self else { return }
            self.settings.regions.resultRegion = region
            self.settings.persist()
            self.capture.updateRegions(result: region, player: self.settings.regions.playerRegion)
            self.statusText = "Область результата сохранена"
            DebugLog.info("Result region set \(region.cgRect)")
        }
    }

    func selectPlayerRegion() {
        RegionSelectorController.present(title: "Область №2 — игрок") { [weak self] region in
            guard let self else { return }
            self.settings.regions.playerRegion = region
            self.settings.persist()
            self.capture.updateRegions(result: self.settings.regions.resultRegion, player: region)
            self.statusText = "Область игрока сохранена"
            DebugLog.info("Player region set \(region.cgRect)")
        }
    }

    func probeOCROnce() async {
        guard let region = settings.regions.resultRegion else {
            ocrProbeText = "Сначала выберите область результата"
            return
        }
        capture.updateRegions(result: region, player: settings.regions.playerRegion)
        // Однократный захват через временный start/stop неудобен — используем внутренний путь.
        // Просим пользователя запустить мониторинг; здесь читаем через повторный capture cycle.
        ocrProbeText = "Запустите мониторинг — OCR текст появится в статусе"
    }

    // MARK: - Frames

    private func handleResultFrame(_ image: CGImage) async {
        guard !ocrTaskRunning else { return }
        ocrTaskRunning = true
        defer { ocrTaskRunning = false }

        let t0 = Date()
        let reading = await ocr.recognize(image: image)
        if !reading.rawText.isEmpty {
            ocrProbeText = reading.rawText
        }

        guard let event = await throwDetector.ingest(reading) else { return }

        let features = await playerVision.currentFeatures()
        await playerVision.noteThrow(at: event.confirmedAt)
        await processConfirmedThrow(number: event.number, features: features, startedAt: t0)
    }

    private func handlePlayerFrame(_ image: CGImage) async {
        guard !playerTaskRunning else { return }
        playerTaskRunning = true
        defer { playerTaskRunning = false }
        _ = await playerVision.ingest(image: image)
    }

    private func processConfirmedThrow(number: Int, features: PlayerFeatures, startedAt: Date) async {
        DebugLog.info("Throw confirmed: \(number)")
        statusText = "Новый результат: \(number)"

        // Прогноз, который проверяем — предыдущий ТОП-4 (до обновления).
        let priorPrediction = learning.lastPrediction

        history.appendResult(number)
        lastResult = number

        let sequence = history.sequence
        let (verified, prediction) = learning.onNewResult(
            historyIncludingNew: sequence,
            features: features
        )
        lastVerified = verified
        lastPrediction = prediction
        decisionDeadline = Date().addingTimeInterval(HardwareProfile.decisionWindowSeconds)

        recordCounter += 1
        let elapsed = Int(Date().timeIntervalSince(startedAt) * 1000)
        lastProcessingMs = elapsed

        // Строка истории: факт = текущий результат, прогноз = то, что было ДО него.
        var record = ThrowRecord(
            index: recordCounter,
            previousResults: Array(sequence.dropLast().suffix(20)),
            currentResult: number,
            playerFeatures: features,
            predictedNumbers: priorPrediction.numbers,
            predictedProbabilities: priorPrediction.probabilities,
            confidenceLevel: priorPrediction.confidence,
            modelWeightsSnapshot: priorPrediction.modelWeights,
            playerProfileID: learning.profiles.activeProfileID,
            processingMs: elapsed
        )
        record.actualResult = number
        if !priorPrediction.numbers.isEmpty {
            record.predictionCorrect = priorPrediction.numbers.contains(number)
        }
        history.addRecord(record)

        statusText = settings.paperMode
            ? "Paper: ТОП-4 готов (\(elapsed) мс)"
            : "ТОП-4 готов (\(elapsed) мс)"

        DebugLog.info("Prediction \(prediction.numbers) conf=\(prediction.confidence.rawValue) ms=\(elapsed)")
        if settings.floatingOverlayVisible {
            FloatingOverlayController.refresh(pipeline: self)
        }
        persist()
    }

    func persist() {
        let state = PersistedState(
            history: history.records,
            resultSequence: history.sequence,
            accuracy: learning.accuracy.snapshot,
            ensemble: learning.ensemble.exportSnapshot(),
            profiles: learning.profiles.profiles,
            activeProfileID: learning.profiles.activeProfileID,
            paperMode: settings.paperMode,
            onboardingDone: settings.onboardingDone
        )
        store.save(state)
        settings.persist()
    }

    /// Ручной ввод результата (тест без OCR).
    func injectResultForTesting(_ number: Int) {
        Task {
            let features = await playerVision.currentFeatures()
            await processConfirmedThrow(number: number, features: features, startedAt: Date())
        }
    }
}
