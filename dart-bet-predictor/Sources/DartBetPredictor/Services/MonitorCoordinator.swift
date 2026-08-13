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
    @Published var bettingWindowSeconds: Double = 10.0
    @Published var detectedTimerSeconds: Double?
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
    private var lastPlayerPhase: PlayerPhase = .idle
    private var bettingWindowStart: Date?

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
        lastPlayerPhase = .idle
        throwTracker.engine.clearAwaiting()
        CaptureSessionRecorder.shared.startSession()
        BettingTimerDetector.shared.reset()

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
        lastPlayerPhase = .idle
        throwTracker.engine.clearAwaiting()
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
                BettingTimerDetector.shared.observeOCRTexts(result.rawTexts)

                if case .bettingOpen = self.phase {
                    BettingTimerDetector.shared.parseTimer(from: image) { detected in
                        Task { @MainActor in
                            if let detected {
                                self.detectedTimerSeconds = detected
                                self.bettingDeadline = Date().addingTimeInterval(detected)
                            }
                        }
                    }
                }

                let engine = self.throwTracker.engine
                let newThrow = self.throwTracker.update(
                    with: result.sectors,
                    rawTexts: result.rawTexts,
                    parseMs: result.parseDurationMs
                )

                self.updateAwaitingPhaseUI()

                if let newThrow {
                    LaunchLogger.log(
                        "Result confirmed: \(newThrow.sector) OCR=[\(result.rawTexts.joined(separator: ","))]"
                    )
                    self.onResultConfirmed(newThrow)
                } else if engine.isAwaitingResult {
                    // ждём стабильный результат
                } else if result.sectors.isEmpty && result.visualChangeScore > 0.15 {
                    self.statusMessage = "Экран меняется, но OCR не читает числа — расширьте СЕРИЯ"
                } else if self.phase == .waitingForThrow {
                    self.statusMessage = "Слежение · \(result.sectors.count) секторов · ждём бросок игрока"
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

                self.handlePlayerMotion(snapshot)

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

    private func handlePlayerMotion(_ snapshot: PlayerBehaviorSnapshot) {
        let engine = throwTracker.engine

        // Бросок: фаза release или резкий скачок движения после замаха
        let throwDetected = snapshot.phase == .release && lastPlayerPhase != .release
        let motionThrow = snapshot.motionIntensity > 0.1
            && snapshot.phase == .release
            && lastPlayerPhase == .windup

        if (throwDetected || motionThrow) && !engine.isAwaitingResult {
            if case .bettingOpen = phase { return } // не прерываем окно ставки

            engine.markAwaitingResult(reason: "player_\(snapshot.phase.displayName)")
            PlayerBehaviorAnalyzer.shared.markThrowDetected()
            pipelineStep = .awaitingResult
            statusMessage = "Бросок! Ждём результат на экране…"
            updateAwaitingPhaseUI()
            LaunchLogger.log("Player throw motion → awaiting result")
        }

        lastPlayerPhase = snapshot.phase
    }

    private func updateAwaitingPhaseUI() {
        let engine = throwTracker.engine
        guard engine.isAwaitingResult else { return }

        pipelineStep = .awaitingResult
        phase = .awaitingResult(
            pendingSector: engine.pendingSector,
            stableReads: engine.stableReadCount,
            requiredReads: 3
        )

        if let pending = engine.pendingSector {
            statusMessage = "Результат: \(pending) — подтверждение \(engine.stableReadCount)/3"
        } else {
            statusMessage = "Ждём появления результата…"
        }
    }

    private func onResultConfirmed(_ event: ThrowEvent) {
        let behaviorDuringRound = averagedBehavior()

        pipelineStep = .evaluatingPrediction
        if let outcome = learningEngine.evaluateAndLearn(
            actual: event.sector,
            behaviorDuringRound: behaviorDuringRound
        ) {
            lastOutcome = outcome
            statusMessage = "\(outcome.displayResult): выпало \(event.sector)"
        }

        lastDetectedThrow = event
        behaviorAccumulator.removeAll()
        lastPlayerPhase = .idle

        pipelineStep = .generatingForecast
        let recommendation = MultiPickPredictor.recommend(
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
        learningEngine.setPending(
            PendingPrediction(from: recommendation, features: features, behavior: currentPlayerBehavior)
        )

        let windowSec = BettingTimerDetector.shared.estimatedWindowSeconds
        bettingWindowSeconds = windowSec

        // 5–10 сек на ставку на СЛЕДУЮЩИЙ бросок — после подтверждённого результата
        startBettingWindow(
            recommendation: recommendation,
            confirmedResult: event.sector,
            duration: windowSec
        )
        playAlertSound()

        if lastOutcome == nil {
            statusMessage = "Выпало \(event.sector) → прогноз на следующий: \(recommendation.displayBet)"
        }

        LaunchLogger.log("Next throw prediction: \(recommendation.displayBet) after confirmed \(event.sector)")
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

    private func startBettingWindow(
        recommendation: BetRecommendation,
        confirmedResult: DartSector,
        duration: Double
    ) {
        bettingTimer?.invalidate()
        bettingWindowStart = Date()
        bettingWindowSeconds = duration
        bettingDeadline = Date().addingTimeInterval(duration)
        phase = .bettingOpen(
            remainingSeconds: duration,
            recommendation: recommendation,
            confirmedResult: confirmedResult
        )

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
        guard let deadline = bettingDeadline else {
            phase = .waitingForThrow
            return
        }

        let remaining = deadline.timeIntervalSinceNow
        if remaining <= 0 {
            bettingTimer?.invalidate()
            bettingTimer = nil
            bettingWindowStart = nil
            phase = .waitingForThrow
            statusMessage = "Ожидание броска игрока…"
            return
        }

        if case .bettingOpen(_, let rec, let confirmed) = phase {
            phase = .bettingOpen(
                remainingSeconds: remaining,
                recommendation: rec,
                confirmedResult: confirmed
            )
        }
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
