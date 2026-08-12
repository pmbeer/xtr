import AppKit
import Combine
import Foundation

extension Notification.Name {
    static let openPredictionOverlay = Notification.Name("DartBetPredictor.openPredictionOverlay")
}

/// Главный координатор: захват → OCR → поведение игрока → обучение → прогноз → таймер 5 сек.
@MainActor
final class MonitorCoordinator: ObservableObject {
    @Published var isRunning = false
    @Published var seriesRegion: ScreenCaptureRegion?
    @Published var playerRegion: ScreenCaptureRegion?
    @Published var phase: BettingPhase = .idle
    @Published var currentRecommendation: BetRecommendation?
    @Published var lastDetectedThrow: ThrowEvent?
    @Published var lastOutcome: PredictionOutcome?
    @Published var currentPlayerBehavior = PlayerBehaviorSnapshot()
    @Published var parseLatencyMs: Double = 0
    @Published var behaviorLatencyMs: Double = 0
    @Published var fps: Double = 0
    @Published var strategy: PredictionStrategy = .adaptiveLearning
    @Published var bettingWindowSeconds: Double = 5.0
    @Published var pollIntervalMs: Double = HardwareProfile.recommendedPollIntervalMs
    @Published var pipelineStep: AnalysisPipelineStep = .idle
    @Published var statusMessage = "Выберите области «СЕРИЯ» и «Игрок», затем Старт"

    // Диагностика — видно, что пайплайн работает
    @Published var lastOCRTexts: [String] = []
    @Published var lastSectorCount: Int = 0
    @Published var visualChangeScore: Double = 0
    @Published var captureSuccessCount: Int = 0
    @Published var captureFailureCount: Int = 0

    let throwTracker = ThrowTracker()
    let learningEngine = LearningEngine.shared

    private var timer: Timer?
    private var bettingTimer: Timer?
    private var bettingDeadline: Date?
    private var frameCount = 0
    private var fpsTimer: Date?
    private var isProcessingSeries = false
    private var isProcessingPlayer = false
    private var soundEnabled = true
    private var behaviorAccumulator: [PlayerBehaviorSnapshot] = []
    private var playerFrameCounter = 0
    private var cancellables = Set<AnyCancellable>()

    init() {
        throwTracker.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        learningEngine.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func requestScreenPermission() {
        _ = ScreenCapturePermission.requestPermission()
    }

    func setSeriesRegion(_ region: ScreenCaptureRegion) {
        seriesRegion = region
        SeriesFrameDiff.shared.reset()
        updateRegionStatus()
        LaunchLogger.log("Series region set: \(region.localRect) display=\(region.displayID ?? 0)")
    }

    func setPlayerRegion(_ region: ScreenCaptureRegion) {
        playerRegion = region
        updateRegionStatus()
        LaunchLogger.log("Player region set: \(region.localRect) display=\(region.displayID ?? 0)")
    }

    private func updateRegionStatus() {
        let series = seriesRegion != nil ? "СЕРИЯ ✓" : "СЕРИЯ ✗"
        let player = playerRegion != nil ? "Игрок ✓" : "Игрок ✗"
        statusMessage = "\(series), \(player) — нажмите Старт"
    }

    func start() {
        guard let series = seriesRegion else {
            statusMessage = "Выберите область «СЕРИЯ»"
            return
        }

        guard playerRegion != nil else {
            statusMessage = "Выберите область «Игрок» для анализа поведения"
            return
        }

        if !ScreenCapturePermission.hasPermission() {
            requestScreenPermission()
            statusMessage = "Разрешите запись экрана → Настройки → Конфиденциальность"
            return
        }

        if !ScreenCapturePermission.verifyWithProbe() {
            statusMessage = "Запись экрана не работает — перезапустите после разрешения"
            LaunchLogger.log("Screen capture probe failed")
            return
        }

        isRunning = true
        phase = .waitingForThrow
        pipelineStep = .watchingOutcome
        statusMessage = "Мониторинг запущен — анализ и прогнозы активны"
        frameCount = 0
        fpsTimer = Date()
        captureSuccessCount = 0
        captureFailureCount = 0
        behaviorAccumulator.removeAll()
        SeriesFrameDiff.shared.reset()

        LaunchLogger.log("Monitor started poll=\(pollIntervalMs)ms")

        NotificationCenter.default.post(name: .openPredictionOverlay, object: nil)

        timer?.invalidate()
        let interval = pollIntervalMs / 1000.0
        let newTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let coordinator = self else { return }
            Task { @MainActor in
                coordinator.captureFrame(seriesRegion: series)
                if let playerRegion = coordinator.playerRegion {
                    coordinator.capturePlayerFrame(region: playerRegion)
                }
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer

        // Первый кадр сразу
        captureFrame(seriesRegion: series)
        if let playerRegion {
            capturePlayerFrame(region: playerRegion)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        bettingTimer?.invalidate()
        bettingTimer = nil
        isRunning = false
        phase = .idle
        pipelineStep = .idle
        statusMessage = "Остановлено"
        LaunchLogger.log("Monitor stopped")
    }

    func resetHistory() {
        throwTracker.reset()
        PlayerBehaviorAnalyzer.shared.reset()
        SeriesFrameDiff.shared.reset()
        currentRecommendation = nil
        lastDetectedThrow = nil
        lastOutcome = nil
        lastOCRTexts = []
        lastSectorCount = 0
        behaviorAccumulator.removeAll()
        phase = isRunning ? .waitingForThrow : .idle
        statusMessage = "История сброшена"
    }

    func resetLearning() {
        learningEngine.resetLearning()
        statusMessage = "Обучение сброшено"
    }

    private func captureFrame(seriesRegion: ScreenCaptureRegion) {
        guard !isProcessingSeries else { return }

        guard let image = ScreenCaptureService.shared.capture(region: seriesRegion) else {
            captureFailureCount += 1
            if captureFailureCount % 10 == 1 {
                statusMessage = "Ошибка захвата «СЕРИЯ» (\(captureFailureCount)) — проверьте разрешения"
                LaunchLogger.log("Series capture failed #\(captureFailureCount) rect=\(seriesRegion.cgCaptureRect())")
            }
            return
        }

        captureSuccessCount += 1
        isProcessingSeries = true
        pipelineStep = .watchingOutcome
        frameCount += 1
        updateFPS()

        SeriesOCRService.shared.parseSeries(from: image) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isProcessingSeries = false
                guard let result else {
                    LaunchLogger.log("OCR returned nil")
                    return
                }

                self.parseLatencyMs = result.parseDurationMs
                self.lastOCRTexts = result.rawTexts
                self.lastSectorCount = result.sectors.count
                self.visualChangeScore = result.visualChangeScore

                let newThrow = self.throwTracker.update(
                    with: result.sectors,
                    rawTexts: result.rawTexts,
                    parseMs: result.parseDurationMs
                )

                if let newThrow {
                    LaunchLogger.log(
                        "Throw detected: \(newThrow.sector) OCR=[\(result.rawTexts.joined(separator: ","))]"
                    )
                    self.onNewThrowDetected(newThrow)
                } else if result.sectors.isEmpty && result.visualChangeScore > 0.2 {
                    self.statusMessage = "Визуальное изменение, но OCR не прочитал числа — увеличьте область СЕРИЯ"
                } else {
                    self.bootstrapRecommendationIfNeeded()
                    if self.isRunning && self.phase == .waitingForThrow {
                        self.statusMessage = "Слежение: \(result.sectors.count) секторов, OCR \(Int(result.parseDurationMs))мс"
                    }
                }
            }
        }
    }

    private func capturePlayerFrame(region: ScreenCaptureRegion) {
        playerFrameCounter += 1
        let stride = HardwareProfile.playerAnalysisStride
        guard playerFrameCounter % stride == 0 else { return }
        guard !isProcessingPlayer else { return }

        guard let image = ScreenCaptureService.shared.capture(region: region) else {
            if captureFailureCount % 15 == 0 {
                LaunchLogger.log("Player capture failed")
            }
            return
        }

        isProcessingPlayer = true
        pipelineStep = .analyzingBehavior
        let start = CFAbsoluteTimeGetCurrent()

        PlayerBehaviorAnalyzer.shared.analyze(image: image) { [weak self] snapshot in
            Task { @MainActor in
                guard let self else { return }
                self.isProcessingPlayer = false
                self.behaviorLatencyMs = (CFAbsoluteTimeGetCurrent() - start) * 1000
                self.currentPlayerBehavior = snapshot
                self.behaviorAccumulator.append(snapshot)
                if self.behaviorAccumulator.count > 40 {
                    self.behaviorAccumulator.removeFirst()
                }
                if self.isRunning && self.phase == .waitingForThrow {
                    self.pipelineStep = .watchingOutcome
                }
            }
        }
    }

    private func bootstrapRecommendationIfNeeded() {
        guard currentRecommendation == nil, throwTracker.history.count >= 1 else { return }

        let recommendation = PredictionEngine.shared.recommend(
            history: throwTracker.history,
            behavior: currentPlayerBehavior,
            strategy: strategy
        )
        currentRecommendation = recommendation
        statusMessage = "Прогноз: \(recommendation.displayBet) (\(recommendation.confidencePercent)%)"
        LaunchLogger.log("Bootstrap recommendation: \(recommendation.displayBet)")
    }

    private func onNewThrowDetected(_ event: ThrowEvent) {
        PlayerBehaviorAnalyzer.shared.markThrowDetected()

        let behaviorDuringRound = averagedBehavior()

        pipelineStep = .evaluatingPrediction
        if let outcome = learningEngine.evaluateAndLearn(
            actual: event.sector,
            behaviorDuringRound: behaviorDuringRound
        ) {
            lastOutcome = outcome
            statusMessage = "\(outcome.displayResult): выпало \(event.sector), ставили \(outcomeDisplay(outcome))"
        }

        lastDetectedThrow = event
        behaviorAccumulator.removeAll()

        pipelineStep = .learning
        pipelineStep = .generatingForecast
        let recommendation = PredictionEngine.shared.recommend(
            history: throwTracker.history,
            behavior: currentPlayerBehavior,
            strategy: strategy
        )
        currentRecommendation = recommendation

        let features = PredictionFeatures.build(
            history: throwTracker.history,
            behavior: currentPlayerBehavior,
            strategyVotes: [:]
        )
        let pending = PendingPrediction(
            from: recommendation,
            features: features,
            behavior: currentPlayerBehavior
        )
        learningEngine.setPending(pending)

        startBettingWindow(recommendation: recommendation)
        playAlertSound()

        if lastOutcome == nil {
            statusMessage = "Бросок: \(event.sector) → ставка: \(recommendation.displayBet)"
        }

        LaunchLogger.log("Prediction: \(recommendation.displayBet) conf=\(recommendation.confidencePercent)%")
        pipelineStep = .watchingOutcome
    }

    private func averagedBehavior() -> PlayerBehaviorSnapshot {
        guard !behaviorAccumulator.isEmpty else { return currentPlayerBehavior }

        var avg = PlayerBehaviorSnapshot()
        let count = Double(behaviorAccumulator.count)
        for snap in behaviorAccumulator {
            avg.armRaise += snap.armRaise
            avg.lateralLean += snap.lateralLean
            avg.motionIntensity += snap.motionIntensity
            avg.shoulderAngle += snap.shoulderAngle
            avg.bodyDetected = avg.bodyDetected || snap.bodyDetected
        }
        avg.armRaise /= count
        avg.lateralLean /= count
        avg.motionIntensity /= count
        avg.shoulderAngle /= count
        avg.phase = behaviorAccumulator.last?.phase ?? .idle
        return avg
    }

    private func outcomeDisplay(_ outcome: PredictionOutcome) -> String {
        switch outcome.betType {
        case .number: return outcome.predictedNumber.map(String.init) ?? "?"
        default: return outcome.betType.displayName
        }
    }

    private func startBettingWindow(recommendation: BetRecommendation) {
        bettingTimer?.invalidate()
        bettingDeadline = Date().addingTimeInterval(bettingWindowSeconds)
        phase = .bettingOpen(remainingSeconds: bettingWindowSeconds, recommendation: recommendation)

        let newTimer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let coordinator = self else { return }
            Task { @MainActor in
                coordinator.tickBettingWindow()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        bettingTimer = newTimer
    }

    private func tickBettingWindow() {
        guard let deadline = bettingDeadline,
              let recommendation = currentRecommendation else {
            phase = .waitingForThrow
            return
        }

        let remaining = deadline.timeIntervalSinceNow
        if remaining <= 0 {
            bettingTimer?.invalidate()
            bettingTimer = nil
            phase = .waitingForThrow
            statusMessage = "Ожидание следующего броска…"
            return
        }

        phase = .bettingOpen(remainingSeconds: remaining, recommendation: recommendation)
    }

    private func updateFPS() {
        guard let start = fpsTimer else { return }
        let elapsed = Date().timeIntervalSince(start)
        if elapsed >= 1.0 {
            fps = Double(frameCount) / elapsed
            frameCount = 0
            fpsTimer = Date()
        }
    }

    private func playAlertSound() {
        guard soundEnabled else { return }
        NSSound.beep()
    }
}
