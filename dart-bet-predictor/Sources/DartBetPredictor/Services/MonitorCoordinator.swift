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

    // Диагностика
    @Published var lastOCRTexts: [String] = []
    @Published var lastSectorCount: Int = 0
    @Published var visualChangeScore: Double = 0
    @Published var captureSuccessCount: Int = 0
    @Published var captureFailureCount: Int = 0
    @Published var playerCaptureSuccessCount: Int = 0
    @Published var captureMethod = "—"
    @Published var seriesPreview: NSImage?
    @Published var playerPreview: NSImage?
    @Published var sessionRecordingPath: String?

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
    private var previewCounter = 0
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

        if !ScreenCapturePermission.hasPermission() {
            requestScreenPermission()
            statusMessage = "Разрешите запись экрана → Системные настройки → Конфиденциальность → Запись экрана"
            return
        }

        isRunning = true
        phase = .waitingForThrow
        pipelineStep = .watchingOutcome
        statusMessage = "Запуск захвата экрана…"
        frameCount = 0
        fpsTimer = Date()
        captureSuccessCount = 0
        captureFailureCount = 0
        playerCaptureSuccessCount = 0
        behaviorAccumulator.removeAll()
        SeriesFrameDiff.shared.reset()
        CaptureSessionRecorder.shared.startSession()

        LaunchLogger.log("Monitor starting poll=\(pollIntervalMs)ms")

        NotificationCenter.default.post(name: .openPredictionOverlay, object: nil)

        // Проверка захвата — не блокируем, только диагностика
        Task {
            let probeOK = await ScreenCapturePermission.probeCapture(region: series)
            await MainActor.run {
                if probeOK {
                    self.statusMessage = "Захват работает — мониторинг активен"
                    self.captureMethod = ScreenCaptureService.shared.lastCaptureMethod
                } else {
                    self.statusMessage = "Захват не работает — перезапустите приложение после разрешения"
                    LaunchLogger.log("Probe capture failed — continuing anyway")
                }
            }
        }

        timer?.invalidate()
        let interval = pollIntervalMs / 1000.0
        let newTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let coordinator = self else { return }
            Task { @MainActor in
                await coordinator.pollOnce(seriesRegion: series)
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer

        Task { await pollOnce(seriesRegion: series) }
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
        CaptureSessionRecorder.shared.stopSession()
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

    private func pollOnce(seriesRegion: ScreenCaptureRegion) async {
        await captureFrame(seriesRegion: seriesRegion)
        if let playerRegion {
            await capturePlayerFrame(region: playerRegion)
        }
    }

    private func captureFrame(seriesRegion: ScreenCaptureRegion) async {
        guard !isProcessingSeries else { return }
        isProcessingSeries = true

        let image = await ScreenCaptureService.shared.captureAsync(region: seriesRegion)
        captureMethod = ScreenCaptureService.shared.lastCaptureMethod

        guard let image else {
            isProcessingSeries = false
            captureFailureCount += 1
            if captureFailureCount % 5 == 1 {
                statusMessage = "Захват СЕРИЯ не работает (\(captureFailureCount)) — проверьте разрешение и перезапуск"
                LaunchLogger.log("Series capture failed #\(captureFailureCount)")
            }
            return
        }

        captureSuccessCount += 1
        pipelineStep = .watchingOutcome
        frameCount += 1
        updateFPS()
        updatePreview(image: image, isPlayer: false)
        CaptureSessionRecorder.shared.saveFrame(image, label: "series")

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
                        "Throw: \(newThrow.sector) OCR=[\(result.rawTexts.joined(separator: ","))]"
                    )
                    self.onNewThrowDetected(newThrow)
                } else if result.sectors.isEmpty && result.visualChangeScore > 0.15 {
                    self.statusMessage = "Экран меняется, но OCR не читает числа — расширьте СЕРИЯ"
                } else {
                    self.bootstrapRecommendationIfNeeded()
                    if self.isRunning && self.phase == .waitingForThrow {
                        self.statusMessage = "Захват ✓ · \(result.sectors.count) секторов · OCR \(Int(result.parseDurationMs))мс"
                    }
                }
            }
        }
    }

    private func capturePlayerFrame(region: ScreenCaptureRegion) async {
        playerFrameCounter += 1
        let stride = HardwareProfile.playerAnalysisStride
        guard playerFrameCounter % stride == 0 else { return }
        guard !isProcessingPlayer else { return }

        isProcessingPlayer = true
        let image = await ScreenCaptureService.shared.captureAsync(region: region)

        guard let image else {
            isProcessingPlayer = false
            LaunchLogger.log("Player capture failed")
            return
        }

        playerCaptureSuccessCount += 1
        pipelineStep = .analyzingBehavior
        updatePreview(image: image, isPlayer: true)
        CaptureSessionRecorder.shared.saveFrame(image, label: "player")

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

    private func updatePreview(image: CGImage, isPlayer: Bool) {
        previewCounter += 1
        guard previewCounter % 8 == 0 else { return }
        let thumb = image.thumbnail(maxWidth: 160)
        if isPlayer {
            playerPreview = thumb.toNSImage()
        } else {
            seriesPreview = thumb.toNSImage()
        }
        if let path = CaptureSessionRecorder.shared.sessionPath {
            sessionRecordingPath = path
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
        LaunchLogger.log("Bootstrap prediction: \(recommendation.displayBet)")
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

extension CGImage {
    func thumbnail(maxWidth: Int) -> CGImage {
        guard width > maxWidth else { return self }
        let scale = Double(maxWidth) / Double(width)
        let newHeight = Int(Double(height) * scale)
        guard let context = CGContext(
            data: nil,
            width: maxWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return self }
        context.interpolationQuality = .medium
        context.draw(self, in: CGRect(x: 0, y: 0, width: maxWidth, height: newHeight))
        return context.makeImage() ?? self
    }
}
