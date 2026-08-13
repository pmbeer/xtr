import Foundation
import Vision
import CoreGraphics

/// Анализирует единую область экрана: кто бросает, как бросает, результаты
final class ScreenSceneAnalyzer {
    static let shared = ScreenSceneAnalyzer()

    private let aiAnalyzer = AIActionAnalyzer.shared
    private let processingQueue = DispatchQueue(label: "com.dartpredictor.scene", qos: .userInteractive)

    private var lastConfirmedNumbers: Set<Int> = []
    private var pendingNumber: Int?
    private var confirmationCount = 0
    private var lastResultZone: CGRect?
    private var previousPrimaryResult: Int?

    func analyzeFrame(_ image: CGImage, completion: @escaping (SceneAnalysisResult) -> Void) {
        let start = CFAbsoluteTimeGetCurrent()

        aiAnalyzer.analyzeFrame(image) { [weak self] insight, features in
            guard let self else { return }
            self.processingQueue.async {
                let numbers = self.detectNumbersInScene(image)
                let confirmed = self.confirmNewThrow(
                    numbers: numbers,
                    insight: insight,
                    features: features
                )

                let result = SceneAnalysisResult(
                    timestamp: Date(),
                    sceneState: insight.sceneState,
                    aiInsight: insight,
                    playerFeatures: features,
                    detectedNumbers: numbers,
                    confirmedNewThrow: confirmed,
                    processingTimeMs: (CFAbsoluteTimeGetCurrent() - start) * 1000
                )

                DispatchQueue.main.async {
                    completion(result)
                }
            }
        }
    }

    func reset() {
        lastConfirmedNumbers = []
        pendingNumber = nil
        confirmationCount = 0
        lastResultZone = nil
        previousPrimaryResult = nil
        aiAnalyzer.reset()
    }

    private func detectNumbersInScene(_ image: CGImage) -> [DetectedNumber] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do { try handler.perform([request]) } catch {
            DebugLogger.shared.logOCRError(error.localizedDescription)
            return []
        }

        guard let observations = request.results else { return [] }

        var detected: [DetectedNumber] = []
        for obs in observations {
            guard let candidate = obs.topCandidates(1).first else { continue }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let value = Int(text), DartConstants.validNumbers.contains(value) else {
                // попробовать извлечь число из текста
                if let extracted = extractNumber(from: text) {
                    detected.append(DetectedNumber(
                        value: extracted,
                        boundingBox: obs.boundingBox,
                        confidence: candidate.confidence
                    ))
                }
                continue
            }
            detected.append(DetectedNumber(
                value: value,
                boundingBox: obs.boundingBox,
                confidence: candidate.confidence
            ))
        }
        return detected
    }

    private func extractNumber(from text: String) -> Int? {
        let pattern = #"\b(\d{1,2})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        let value = Int(text[r])
        guard let value, DartConstants.validNumbers.contains(value) else { return nil }
        return value
    }

    private func confirmNewThrow(
        numbers: [DetectedNumber],
        insight: AIActionInsight,
        features: PlayerFeatures
    ) -> Int? {
        guard !numbers.isEmpty else { return nil }

        // Приоритет: число в зоне результата (обычно крупный текст, центр/верх)
        let primary = selectPrimaryResult(from: numbers)
        guard let candidate = primary else { return nil }

        // ИИ подтверждает: результат появился после фазы броска
        let aiConfirms = insight.sceneState == .resultShown
            || insight.sceneState == .resultPending
            || insight.detectedAction == .recovery
            || insight.throwPhaseProgress >= 0.8

        if candidate.value == pendingNumber {
            confirmationCount += 1
        } else {
            pendingNumber = candidate.value
            confirmationCount = 1
        }

        guard confirmationCount >= DartConstants.ocrDebounceFrames else { return nil }

        // Не дублировать тот же результат
        if candidate.value == previousPrimaryResult { return nil }

        // Требуем либо ИИ-подтверждение фазы, либо стабильный OCR
        if !aiConfirms && confirmationCount < DartConstants.ocrDebounceFrames + 1 {
            return nil
        }

        previousPrimaryResult = candidate.value
        pendingNumber = nil
        confirmationCount = 0
        lastResultZone = candidate.boundingBox

        DebugLogger.shared.log(
            "Scene: новый результат \(candidate.value), ИИ: \(insight.detectedAction.rawValue)",
            category: "ai"
        )
        return candidate.value
    }

    private func selectPrimaryResult(from numbers: [DetectedNumber]) -> DetectedNumber? {
        // Эвристика: самое крупное / самое яркое число — bounding box area
        numbers.max { a, b in
            let areaA = a.boundingBox.width * a.boundingBox.height
            let areaB = b.boundingBox.width * b.boundingBox.height
            if areaA != areaB { return areaA < areaB }
            return a.confidence < b.confidence
        }
    }
}
