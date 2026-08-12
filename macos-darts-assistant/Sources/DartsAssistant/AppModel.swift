import AVFoundation
import Foundation
import ScreenCaptureKit
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var windows: [SCWindow] = []
    @Published var selectedWindowID: CGWindowID?
    @Published var region = CaptureRegion()
    @Published var newestFirst = true
    @Published var voiceEnabled = true
    @Published var isCapturing = false
    @Published var status = "Выберите окно с игрой."
    @Published var rawOCR = "—"
    @Published var recognizedValues: [Int] = []
    @Published var latestThrow: Int?
    @Published var sampleCount = 0
    @Published var latencyMilliseconds = 0
    @Published var recommendation = Recommendation.collecting

    private let capture = ScreenCaptureService()
    private let analyzer = FrameAnalyzer()
    private let speech = AVSpeechSynthesizer()
    private var detector = ThrowDetector()
    private var predictor = ThrowPredictor()

    init() {
        capture.onFrame = { [weak self] pixelBuffer in
            Task { @MainActor [weak self] in
                self?.process(pixelBuffer)
            }
        }
        capture.onError = { [weak self] message in
            Task { @MainActor [weak self] in
                self?.isCapturing = false
                self?.status = "Захват остановлен: \(message)"
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
        recommendation = .collecting
        sampleCount = 0
        latestThrow = nil

        do {
            try await capture.start(window: window)
            isCapturing = true
            status = "Захват активен. OCR обрабатывает до 12 кадров/с."
        } catch {
            status = "Не удалось запустить захват: \(error.localizedDescription)"
        }
    }

    func stopCapture() async {
        do {
            try await capture.stop()
        } catch {
            status = "Ошибка остановки: \(error.localizedDescription)"
        }
        isCapturing = false
        if !status.hasPrefix("Ошибка") {
            status = "Захват остановлен."
        }
    }

    func resetStatistics() {
        detector.reset()
        predictor.reset()
        recognizedValues = []
        latestThrow = nil
        sampleCount = 0
        recommendation = .collecting
        status = "Статистика сброшена."
    }

    func windowLabel(_ window: SCWindow) -> String {
        let app = window.owningApplication?.applicationName ?? "Приложение"
        let title = window.title?.isEmpty == false ? window.title! : "без названия"
        return "\(app) — \(title)"
    }

    private func process(_ pixelBuffer: CVPixelBuffer) {
        let currentRegion = region
        analyzer.analyze(pixelBuffer: pixelBuffer, region: currentRegion) {
            [weak self] snapshot in
            Task { @MainActor [weak self] in
                self?.accept(snapshot)
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
            sampleCount = predictor.history.count
            recommendation = predictor.recommendation()
            status = "История распознана: \(values.count) значений."
        case .newThrow(let value):
            latestThrow = value
            predictor.observe(value)
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
}
