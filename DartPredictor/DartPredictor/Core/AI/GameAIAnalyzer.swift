import Foundation
import CoreGraphics

/// ИИ-анализатор игровой сцены: результаты, таймер, бросок, игрок
final class GameAIAnalyzer {
    static let shared = GameAIAnalyzer()

    private let aiAction = AIActionAnalyzer.shared
    private let timerRecognizer = BettingTimerRecognizer.shared
    private let throwTracker = ThrowSequenceTracker()
    private let processingQueue = DispatchQueue(label: "com.dartpredictor.gameai", qos: .userInteractive)
    private var isProcessing = false
    private var lastMotionPeak = 0.0
    private var throwMotionDetected = false

    func analyze(image: CGImage, completion: @escaping (GameSnapshot) -> Void) {
        guard !isProcessing else { return }
        isProcessing = true
        let start = CFAbsoluteTimeGetCurrent()
        let ocrImage = scaleForAnalysis(image)

        aiAction.analyzeFrame(image) { [weak self] insight, features in
            guard let self else { return }
            self.processingQueue.async {
                let textItems = VisionTextScanner.scan(image: ocrImage)
                let numbers = VisionTextScanner.extractDartNumbers(from: textItems)
                let bettingSeconds = self.timerRecognizer.recognize(from: ocrImage)

                let motion = insight.motionIntensity
                if motion > 0.18 {
                    self.throwMotionDetected = true
                    self.lastMotionPeak = motion
                } else if motion < 0.06 && self.throwMotionDetected {
                    self.throwMotionDetected = false
                }

                let confirmed = self.throwTracker.process(detectedNumbers: numbers)
                let phase = self.classifyPhase(
                    insight: insight,
                    numbers: numbers,
                    bettingSeconds: bettingSeconds,
                    throwMotion: self.throwMotionDetected,
                    confirmedResult: confirmed
                )

                let snapshot = GameSnapshot(
                    timestamp: Date(),
                    detectedNumbers: numbers,
                    bettingSeconds: bettingSeconds,
                    phase: phase,
                    aiInsight: insight,
                    playerFeatures: features,
                    throwInProgress: insight.detectedAction == .throwMotion || insight.detectedAction == .release || self.throwMotionDetected,
                    throwCompleted: confirmed != nil,
                    confirmedResult: confirmed,
                    processingTimeMs: (CFAbsoluteTimeGetCurrent() - start) * 1000
                )

                self.isProcessing = false
                DispatchQueue.main.async {
                    completion(snapshot)
                }
            }
        }
    }

    func reset() {
        throwTracker.reset()
        timerRecognizer.reset()
        aiAction.reset()
        throwMotionDetected = false
        isProcessing = false
    }

    private func classifyPhase(
        insight: AIActionInsight,
        numbers: [DetectedNumber],
        bettingSeconds: Double?,
        throwMotion: Bool,
        confirmedResult: Int?
    ) -> GamePhase {
        if throwMotion || insight.detectedAction == .throwMotion || insight.detectedAction == .windup {
            return .throwing
        }
        if confirmedResult != nil {
            return .resultShown
        }
        if let sec = bettingSeconds, sec > 0 && sec <= 20 {
            return .bettingWindow
        }
        if insight.playerDetected && insight.detectedAction == .aim || insight.detectedAction == .stance {
            return .playerPreparing
        }
        if insight.playerDetected {
            return .playerVisible
        }
        if !numbers.isEmpty {
            return .watchingResults
        }
        return .idle
    }

    private func scaleForAnalysis(_ image: CGImage) -> CGImage {
        let minWidth: CGFloat = 480
        if CGFloat(image.width) >= minWidth { return image }
        let scale = minWidth / CGFloat(image.width)
        let w = Int(CGFloat(image.width) * scale)
        let h = Int(CGFloat(image.height) * scale)
        guard w > 0, h > 0,
              let ctx = CGContext(
                  data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return image }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage() ?? image
    }
}
