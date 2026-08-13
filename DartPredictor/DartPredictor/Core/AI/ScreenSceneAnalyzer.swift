import Foundation
import Vision
import CoreGraphics

/// Анализирует единую область экрана: кто бросает, как бросает, результаты
final class ScreenSceneAnalyzer {
    static let shared = ScreenSceneAnalyzer()

    private let aiAnalyzer = AIActionAnalyzer.shared
    private let throwTracker = ThrowSequenceTracker()
    private let processingQueue = DispatchQueue(label: "com.dartpredictor.scene", qos: .userInteractive)
    private var isProcessing = false

    func analyzeFrame(_ image: CGImage, completion: @escaping (SceneAnalysisResult) -> Void) {
        guard !isProcessing else { return }
        isProcessing = true
        let start = CFAbsoluteTimeGetCurrent()

        // OCR на увеличенной копии для лучшего распознавания
        let ocrImage = scaleForOCR(image)

        aiAnalyzer.analyzeFrame(image) { [weak self] insight, features in
            guard let self else { return }
            self.processingQueue.async {
                let numbers = self.detectNumbersInScene(ocrImage)
                let confirmed = self.throwTracker.process(detectedNumbers: numbers)

                let result = SceneAnalysisResult(
                    timestamp: Date(),
                    sceneState: insight.sceneState,
                    aiInsight: insight,
                    playerFeatures: features,
                    detectedNumbers: numbers,
                    confirmedNewThrow: confirmed,
                    processingTimeMs: (CFAbsoluteTimeGetCurrent() - start) * 1000
                )

                self.isProcessing = false
                DispatchQueue.main.async {
                    completion(result)
                }
            }
        }
    }

    func reset() {
        throwTracker.reset()
        aiAnalyzer.reset()
        isProcessing = false
    }

    private func scaleForOCR(_ image: CGImage) -> CGImage {
        let minWidth: CGFloat = 400
        if CGFloat(image.width) >= minWidth { return image }

        let scale = minWidth / CGFloat(image.width)
        let newW = Int(CGFloat(image.width) * scale)
        let newH = Int(CGFloat(image.height) * scale)
        guard newW > 0, newH > 0,
              let ctx = CGContext(
                  data: nil, width: newW, height: newH,
                  bitsPerComponent: 8, bytesPerRow: newW * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return image }

        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: newW, height: newH))
        return ctx.makeImage() ?? image
    }

    private func detectNumbersInScene(_ image: CGImage) -> [DetectedNumber] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        request.minimumTextHeight = 0.008

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do { try handler.perform([request]) } catch {
            DebugLogger.shared.logOCRError(error.localizedDescription)
            return []
        }

        guard let observations = request.results else { return [] }

        var detected: [DetectedNumber] = []
        var seen = Set<Int>()

        for obs in observations {
            guard let candidate = obs.topCandidates(1).first else { continue }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)

            let values: [Int]
            if let v = Int(text), DartConstants.validNumbers.contains(v) {
                values = [v]
            } else {
                values = extractAllNumbers(from: text)
            }

            for value in values where !seen.contains(value) {
                seen.insert(value)
                detected.append(DetectedNumber(
                    value: value,
                    boundingBox: obs.boundingBox,
                    confidence: candidate.confidence
                ))
            }
        }
        return detected
    }

    private func extractAllNumbers(from text: String) -> [Int] {
        let pattern = #"\b(\d{1,2})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        return matches.compactMap { match -> Int? in
            guard let r = Range(match.range(at: 1), in: text) else { return nil }
            let value = Int(text[r])
            guard let value, DartConstants.validNumbers.contains(value) else { return nil }
            return value
        }
    }
}
