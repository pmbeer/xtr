import AppKit
import Combine
import Foundation

/// Главный координатор: захват → OCR → поведение игрока → обучение → прогноз → таймер 5 сек.
@MainActor
final class MonitorCoordinator: ObservableObject {
    @Published var isRunning = false
    @Published var seriesRegion: CGRect?
    @Published var playerRegion: CGRect?
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

    func requestScreenPermission() {
        _ = ScreenCapturePermission.requestPermission()
    }

    func setSeriesRegion(_ rect: CGRect) {
        seriesRegion = rect
        updateRegionStatus()
    }

    func setPlayerRegion(_ rect: CGRect) {
        playerRegion = rect
        updateRegionStatus()
    }

    private func updateRegionStatus() {
        let series = seriesRegion != nil ? "СЕРИЯ ✓" : "СЕРИЯ ✗"
        let player = playerRegion != nil ? "Игрок ✓" : "Игрок ✗"
        statusMessage = "\(series), \(player)"
    }

    func start() {
        guard let series = seriesRegion else {
            statusMessage = "Выберите область «СЕРИЯ»"
            return
        }

        if !ScreenCapturePermission.hasPermission() {
            requestScreenPermission()
            statusMessage = "Разрешите запись экрана в Настройках → Конфиденциальность"
            return
        }

        isRunning = true
        phase = .waitingForThrow
        pipelineStep = .watchingOutcome
        statusMessage = "Мониторинг запущен — обучение активно"
        frameCount = 0
        fpsTimer = Date()
        behaviorAccumulator.removeAll()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: pollIntervalMs / 1000.0, repeats: true) { [weak self] _ in
            guard let coordinator = self else { return }
            Task { @MainActor in
                coordinator.captureFrame(seriesRegion: series)
                if let playerRegion = coordinator.playerRegion {
                    coordinator.capturePlayerFrame(region: playerRegion)
                }
            }
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
    }

    func resetHistory() {
        throwTracker.reset()
        PlayerBehaviorAnalyzer.shared.reset()
        currentRecommendation = nil
        lastDetectedThrow = nil
        lastOutcome = nil
        behaviorAccumulator.removeAll()
        phase = isRunning ? .waitingForThrow : .idle
        statusMessage = "История сброшена"
    }

    func resetLearning() {
        learningEngine.resetLearning()
        statusMessage = "Обучение сброшено"
    }

    private func captureFrame(seriesRegion: CGRect) {
        guard !isProcessingSeries else { return }
        guard let screen = NSScreen.main else { return }

        let cgRegion = ScreenCaptureService.cgRect(
            from: seriesRegion,
            screenHeight: screen.frame.height
        )

        guard let image = ScreenCaptureService.shared.capture(region: cgRegion) else {
            statusMessage = "Ошибка захвата «СЕРИЯ»"
            return
        }

        isProcessingSeries = true
        pipelineStep = .watchingOutcome
        frameCount += 1
        updateFPS()

        SeriesOCRService.shared.parseSeries(from: image) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isProcessingSeries = false
                guard let result else { return }

                self.parseLatencyMs = result.parseDurationMs

                let previousThrow = self.throwTracker.lastThrow
                self.throwTracker.update(
                    with: result.sectors,
                    rawTexts: result.rawTexts,
                    parseMs: result.parseDurationMs
                )

                if let newThrow = self.throwTracker.lastThrow,
                   newThrow != previousThrow {
                    self.onNewThrowDetected(newThrow)
                }
            }
        }
    }

    private func capturePlayerFrame(region: CGRect) {
        playerFrameCounter += 1
        let stride = HardwareProfile.playerAnalysisStride
        guard playerFrameCounter % stride == 0 else { return }
        guard !isProcessingPlayer else { return }
        guard let screen = NSScreen.main else { return }

        let cgRegion = ScreenCaptureService.cgRect(
            from: region,
            screenHeight: screen.frame.height
        )

        guard let image = ScreenCaptureService.shared.capture(region: cgRegion) else { return }

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
            }
        }
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

        bettingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let coordinator = self else { return }
            Task { @MainActor in
                coordinator.tickBettingWindow()
            }
        }
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
