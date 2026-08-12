import AppKit
import Combine
import Foundation

/// Главный координатор: захват → OCR → детекция → прогноз → таймер 5 сек.
@MainActor
final class MonitorCoordinator: ObservableObject {
    @Published var isRunning = false
    @Published var captureRegion: CGRect?
    @Published var phase: BettingPhase = .idle
    @Published var currentRecommendation: BetRecommendation?
    @Published var lastDetectedThrow: ThrowEvent?
    @Published var parseLatencyMs: Double = 0
    @Published var fps: Double = 0
    @Published var strategy: PredictionStrategy = .ensemble
    @Published var bettingWindowSeconds: Double = 5.0
    @Published var pollIntervalMs: Double = 150
    @Published var statusMessage = "Выберите область «СЕРИЯ» и нажмите Старт"

    let throwTracker = ThrowTracker()

    private var timer: Timer?
    private var bettingTimer: Timer?
    private var bettingDeadline: Date?
    private var frameCount = 0
    private var fpsTimer: Date?
    private var isProcessingFrame = false
    private var soundEnabled = true

    func requestScreenPermission() {
        _ = ScreenCapturePermission.requestPermission()
    }

    func setCaptureRegion(_ rect: CGRect) {
        captureRegion = rect
        statusMessage = String(
            format: "Область: %.0f×%.0f — готово к запуску",
            rect.width,
            rect.height
        )
    }

    func start() {
        guard let region = captureRegion else {
            statusMessage = "Сначала выберите область экрана"
            return
        }

        if !ScreenCapturePermission.hasPermission() {
            requestScreenPermission()
            statusMessage = "Разрешите запись экрана в Настройках → Конфиденциальность"
            return
        }

        isRunning = true
        phase = .waitingForThrow
        statusMessage = "Мониторинг запущен"
        frameCount = 0
        fpsTimer = Date()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: pollIntervalMs / 1000.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.captureFrame(region: region)
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
        statusMessage = "Остановлено"
    }

    func resetHistory() {
        throwTracker.reset()
        currentRecommendation = nil
        lastDetectedThrow = nil
        phase = isRunning ? .waitingForThrow : .idle
    }

    private func captureFrame(region: CGRect) {
        guard !isProcessingFrame else { return }

        guard let screen = NSScreen.main else { return }
        let cgRegion = ScreenCaptureService.cgRect(
            from: region,
            screenHeight: screen.frame.height
        )

        guard let image = ScreenCaptureService.shared.capture(region: cgRegion) else {
            statusMessage = "Ошибка захвата экрана"
            return
        }

        isProcessingFrame = true
        frameCount += 1
        updateFPS()

        SeriesOCRService.shared.parseSeries(from: image) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isProcessingFrame = false

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

    private func onNewThrowDetected(_ event: ThrowEvent) {
        lastDetectedThrow = event

        let recommendation = PredictionEngine.shared.recommend(
            history: throwTracker.history,
            strategy: strategy
        )
        currentRecommendation = recommendation

        startBettingWindow(recommendation: recommendation)
        playAlertSound()

        statusMessage = "Бросок: \(event.sector) → ставка: \(recommendation.displayBet)"
    }

    private func startBettingWindow(recommendation: BetRecommendation) {
        bettingTimer?.invalidate()
        bettingDeadline = Date().addingTimeInterval(bettingWindowSeconds)
        phase = .bettingOpen(remainingSeconds: bettingWindowSeconds, recommendation: recommendation)

        bettingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickBettingWindow()
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

extension ThrowEvent: Equatable {
    static func == (lhs: ThrowEvent, rhs: ThrowEvent) -> Bool {
        lhs.sector == rhs.sector && lhs.detectedAt == rhs.detectedAt
    }
}
