import AVFoundation
import CoreVideo
import Foundation
import ScreenCaptureKit
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var windows: [SCWindow] = []
    @Published var selectedWindowID: CGWindowID?
    @Published var region = CaptureRegion()
    @Published var behaviorRegion = CaptureRegion(
        x: 0.50,
        y: 0.10,
        width: 0.25,
        height: 0.55
    )
    @Published var newestFirst = true
    @Published var voiceEnabled = true
    @Published var isCapturing = false
    @Published var isTransitioning = false
    @Published var status = "Выберите окно с игрой."
    @Published var rawOCR = "—"
    @Published var recognizedValues: [Int] = []
    @Published var latestThrow: Int?
    @Published var sampleCount = 0
    @Published var latencyMilliseconds = 0
    @Published var recommendation = Recommendation.collecting
    @Published var learningMetrics = LearningMetrics()

    private let capture = ScreenCaptureService()
    private let analyzer = FrameAnalyzer()
    private let speech = AVSpeechSynthesizer()
    private var detector = ThrowDetector()
    private var predictor = ThrowPredictor()
    private var onlineLearner: OnlineLearningPredictor
    private var activeSessionID: UUID?
    private var analysisEpoch = 0

    init() {
        onlineLearner = OnlineLearningPredictor.load(from: Self.modelURL)
            ?? OnlineLearningPredictor()
        onlineLearner.beginSession()
        learningMetrics = onlineLearner.metrics

        capture.onFrame = { [weak self] pixelBuffer, sessionID in
            Task { @MainActor [weak self] in
                guard let self, self.activeSessionID == sessionID else { return }
                self.process(
                    pixelBuffer,
                    sessionID: sessionID,
                    epoch: self.analysisEpoch
                )
            }
        }
        capture.onError = { [weak self] sessionID, message in
            Task { @MainActor [weak self] in
                guard let self, self.activeSessionID == sessionID else { return }
                self.activeSessionID = nil
                self.analysisEpoch += 1
                self.isCapturing = false
                self.status = "Захват остановлен: \(message)"
            }
        }
    }

    func refreshWindows() async {
        do {
            windows = try await capture.availableWindows()
            if selectedWindowID == nil || !windows.contains(where: {
                $0.windowID == selectedWindowID
            }) {
                selectedWindowID = windows.first?.windowID
            }
            status = windows.isEmpty
                ? "Подходящие окна не найдены."
                : "Окна обновлены. Настройте область истории бросков."
        } catch {
            status = "Нет доступа к экрану: \(error.localizedDescription)"
        }
    }

    func toggleCapture() async {
        guard !isTransitioning else { return }
        isTransitioning = true
        defer { isTransitioning = false }

        if isCapturing {
            await stopCapture()
            return
        }

        guard let window = windows.first(where: { $0.windowID == selectedWindowID }) else {
            status = "Сначала выберите окно."
            return
        }

        detector.reset()
        predictor.reset()
        onlineLearner.beginSession()
        learningMetrics = onlineLearner.metrics
        analyzer.resetBehavior()
        analysisEpoch += 1
        recommendation = Recommendation.collecting
        sampleCount = 0
        latestThrow = nil

        let sessionID = UUID()
        activeSessionID = sessionID
        do {
            try await capture.start(window: window, sessionID: sessionID)
            guard activeSessionID == sessionID else {
                try? await capture.stop()
                return
            }
            isCapturing = true
            status = "Захват активен. OCR обрабатывает до 12 кадров/с."
        } catch {
            if activeSessionID == sessionID {
                activeSessionID = nil
                analysisEpoch += 1
                status = "Не удалось запустить захват: \(error.localizedDescription)"
            }
        }
    }

    private func stopCapture() async {
        activeSessionID = nil
        analysisEpoch += 1
        isCapturing = false
        do {
            try await capture.stop()
        } catch {
            status = "Ошибка остановки: \(error.localizedDescription)"
        }
        if !status.hasPrefix("Ошибка") {
            status = "Захват остановлен."
        }
    }

    func resetStatistics() {
        analysisEpoch += 1
        detector.reset()
        predictor.reset()
        onlineLearner.beginSession()
        learningMetrics = onlineLearner.metrics
        analyzer.resetBehavior()
        recognizedValues = []
        latestThrow = nil
        sampleCount = 0
        recommendation = Recommendation.collecting
        status = "Статистика сброшена."
    }

    func eraseLearning() {
        onlineLearner.eraseLearning()
        learningMetrics = onlineLearner.metrics
        try? FileManager.default.removeItem(at: Self.modelURL)
        status = "Накопленное обучение удалено."
    }

    func windowLabel(_ window: SCWindow) -> String {
        let app = window.owningApplication?.applicationName ?? "Приложение"
        let title = window.title?.isEmpty == false ? window.title! : "без названия"
        return "\(app) — \(title)"
    }

    private func process(_ pixelBuffer: CVPixelBuffer, sessionID: UUID, epoch: Int) {
        let currentRegion = region
        let currentBehaviorRegion = behaviorRegion
        analyzer.analyze(
            pixelBuffer: pixelBuffer,
            region: currentRegion,
            behaviorRegion: currentBehaviorRegion
        ) { [weak self] snapshot in
            Task { @MainActor [weak self] in
                guard let self,
                      self.activeSessionID == sessionID,
                      self.analysisEpoch == epoch,
                      self.isCapturing else {
                    return
                }
                self.accept(snapshot)
            }
        }
    }

    private func accept(_ snapshot: OCRSnapshot) {
        rawOCR = snapshot.rawText.isEmpty ? "—" : snapshot.rawText
        recognizedValues = snapshot.values
        latencyMilliseconds = snapshot.latencyMilliseconds
        detector.newestFirst = newestFirst

        switch detector.ingest(snapshot.values) {
        case .none:
            break
        case .seed(let values):
            values.forEach { predictor.observe($0) }
            let chronologicalValues = newestFirst ? Array(values.reversed()) : values
            learningMetrics = onlineLearner.seed(
                chronologicalValues,
                behaviorFeatures: snapshot.behaviorFeatures,
                behaviorConfidence: snapshot.behaviorConfidence
            )
            sampleCount = predictor.history.count
            recommendation = predictor.recommendation()
            status = "История распознана: \(values.count) значений."
        case .newThrow(let value):
            latestThrow = value
            predictor.observe(value)
            learningMetrics = onlineLearner.observe(
                outcome: value,
                behaviorFeatures: snapshot.behaviorFeatures,
                behaviorConfidence: snapshot.behaviorConfidence
            )
            try? onlineLearner.save(to: Self.modelURL)
            sampleCount = predictor.history.count
            recommendation = predictor.recommendation()
            status = "Новый бросок: \(value). Подсказка обновлена."
            speak(recommendation.title)
        }
    }

    private func speak(_ text: String) {
        guard voiceEnabled else { return }
        speech.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text == "ПРОПУСТИТЬ"
            ? "Ставку пропустить"
            : "Следующая ставка: \(text)")
        utterance.voice = AVSpeechSynthesisVoice(language: "ru-RU")
        utterance.rate = 0.55
        speech.speak(utterance)
    }

    private static var modelURL: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        return base
            .appendingPathComponent("DartsAssistant", isDirectory: true)
            .appendingPathComponent("online-model.json")
    }
}
