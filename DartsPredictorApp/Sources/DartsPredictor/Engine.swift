import AppKit
import Combine
import CoreGraphics

/// Детектор бросков по счёту. Новое значение принимается только после двух
/// одинаковых чтений подряд, чтобы одиночная ошибка распознавания
/// не превратилась в ложный бросок.
final class ThrowDetector {
    enum Event {
        case initialScore(Int)
        case throwDetected(value: Int, from: Int, to: Int)
        case scoreReset(from: Int, to: Int)
        case anomaly(delta: Int)
    }

    private static let validThrows: Set<Int> = Set(1...20).union([PlayerModel.bull, 50])

    private var candidate: Int?
    private(set) var score: Int?

    func update(_ value: Int?) -> Event? {
        guard let value else {
            candidate = nil
            return nil
        }
        if value == score {
            candidate = nil
            return nil
        }
        guard value == candidate else {
            candidate = value
            return nil
        }
        candidate = nil

        let previous = score
        score = value

        guard let previous else {
            return .initialScore(value)
        }
        let delta = value - previous
        if delta <= 0 {
            return .scoreReset(from: previous, to: value)
        }
        guard Self.validThrows.contains(delta) else {
            return .anomaly(delta: delta)
        }
        return .throwDetected(value: delta, from: previous, to: value)
    }
}

struct PlayerPanelState {
    var name: String
    var score: Int?
    var history: [Int] = []
    var recommendations: [Recommendation] = []
}

@MainActor
final class Engine: ObservableObject {
    @Published var settings = AppSettings.load() {
        didSet { settings.save() }
    }
    @Published var isRunning = false
    @Published var status = "Выберите области счёта и нажмите Старт"
    @Published var leftPlayer = PlayerPanelState(name: "Левый игрок")
    @Published var rightPlayer = PlayerPanelState(name: "Правый игрок")
    @Published var bestRecommendation: Recommendation?
    @Published var lastAnalysisMs: Int = 0
    @Published var logLines: [String] = []

    var regionsConfigured: Bool {
        settings.scoreLeft != nil && settings.scoreRight != nil
    }

    private let grabber = ScreenGrabber()
    private let speech = Speech()
    private var loopTask: Task<Void, Never>?
    private var detectors: [String: ThrowDetector] = [:]
    private var models: [String: PlayerModel] = [:]

    // MARK: - Выбор областей

    func selectRegions() async {
        let wasRunning = isRunning
        stop()

        let selector = RegionSelector()
        guard let left = await selector.select(
            instruction: "Выделите мышью счёт ЛЕВОГО игрока (Esc — отмена)") else {
            status = "Выбор областей отменён"
            return
        }
        guard let right = await selector.select(
            instruction: "Теперь счёт ПРАВОГО игрока (Esc — отмена)") else {
            status = "Выбор областей отменён"
            return
        }
        settings.scoreLeft = CodableRect(cocoaRectToCG(left))
        settings.scoreRight = CodableRect(cocoaRectToCG(right))
        status = "Области счёта сохранены. Нажмите Старт."
        if wasRunning {
            start()
        }
    }

    // MARK: - Запуск/остановка

    func start() {
        guard regionsConfigured else {
            status = "Сначала выберите области счёта"
            return
        }
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            status = "Разрешите запись экрана: Настройки → Конфиденциальность → Запись экрана, затем перезапустите приложение"
            return
        }
        detectors = ["left": ThrowDetector(), "right": ThrowDetector()]
        models = ["left": PlayerModel(), "right": PlayerModel()]
        leftPlayer = PlayerPanelState(name: "Левый игрок")
        rightPlayer = PlayerPanelState(name: "Правый игрок")
        bestRecommendation = nil
        isRunning = true
        loopTask = Task { [weak self] in
            await self?.runLoop()
        }
    }

    func stop() {
        isRunning = false
        loopTask?.cancel()
        loopTask = nil
    }

    // MARK: - Основной цикл

    private func runLoop() async {
        do {
            try await grabber.prepare(name: "left", cgRect: settings.scoreLeft!.cgRect)
            try await grabber.prepare(name: "right", cgRect: settings.scoreRight!.cgRect)
        } catch {
            status = "Ошибка захвата экрана: \(error.localizedDescription)"
            isRunning = false
            return
        }
        status = "Слежу за счётом... Первые броски уйдут на разгон статистики."

        while isRunning && !Task.isCancelled {
            let started = Date()
            await step(side: "left")
            await step(side: "right")

            let elapsed = Date().timeIntervalSince(started)
            let remaining = settings.pollInterval - elapsed
            if remaining > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
        }
    }

    private func step(side: String) async {
        guard let detector = detectors[side], let model = models[side] else { return }

        let image: CGImage
        do {
            image = try await grabber.capture(name: side)
        } catch {
            return
        }

        let started = Date()
        let value = await Task.detached(priority: .userInitiated) {
            DigitOCR.readNumber(from: image)
        }.value

        guard let event = detector.update(value) else { return }
        let playerName = side == "left" ? "Левый игрок" : "Правый игрок"

        switch event {
        case .initialScore(let score):
            updatePanel(side: side) { $0.score = score }
            log("[\(playerName)] стартовый счёт: \(score)")

        case .scoreReset(let from, let to):
            updatePanel(side: side) { $0.score = to }
            log("[\(playerName)] счёт сброшен (\(from) → \(to)), новая серия")

        case .anomaly(let delta):
            updatePanel(side: side) { $0.score = detector.score }
            log("[\(playerName)] +\(delta) не похоже на один бросок (пропущен кадр?), пересинхронизация")

        case .throwDetected(let value, let from, let to):
            let sector = value == 50 ? PlayerModel.bull : value
            model.addThrow(sector)
            let recommendations = recommend(model: model, settings: settings)
            let analysisMs = Int(Date().timeIntervalSince(started) * 1000)

            updatePanel(side: side) {
                $0.score = to
                $0.history = model.history
                $0.recommendations = Array(recommendations.prefix(3))
            }
            bestRecommendation = recommendations.first
            lastAnalysisMs = analysisMs
            log("[\(playerName)] бросок: \(value) (счёт \(from) → \(to), анализ \(analysisMs) мс)")

            if settings.voiceEnabled, let best = recommendations.first {
                speech.speak(best.voiceText)
            }
        }
    }

    private func updatePanel(side: String, _ mutate: (inout PlayerPanelState) -> Void) {
        if side == "left" {
            mutate(&leftPlayer)
        } else {
            mutate(&rightPlayer)
        }
    }

    private func log(_ line: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        logLines.append("\(formatter.string(from: Date()))  \(line)")
        if logLines.count > 200 {
            logLines.removeFirst(logLines.count - 200)
        }
    }
}
