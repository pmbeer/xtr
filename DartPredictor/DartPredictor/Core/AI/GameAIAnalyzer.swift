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
    private var latestImage: CGImage?
    private var pendingCompletion: ((GameSnapshot) -> Void)?
    private var throwMotionDetected = false
    private var motionReleased = false

    func analyze(image: CGImage, completion: @escaping (GameSnapshot) -> Void) {
        latestImage = image
        pendingCompletion = completion
        guard !isProcessing else { return }
        drainQueue()
    }

    func reset() {
        throwTracker.reset()
        timerRecognizer.reset()
        aiAction.reset()
        throwMotionDetected = false
        motionReleased = false
        isProcessing = false
        latestImage = nil
        pendingCompletion = nil
    }

    private func drainQueue() {
        guard let image = latestImage, let completion = pendingCompletion else { return }
        latestImage = nil
        isProcessing = true
        let start = CFAbsoluteTimeGetCurrent()
        let ocrImage = scaleForAnalysis(image)

        aiAction.analyzeFrame(image) { [weak self] insight, features in
            guard let self else { return }
            self.processingQueue.async {
                let fastTexts = VisionTextScanner.scan(image: ocrImage, fast: true)
                let accurateTexts = VisionTextScanner.scan(image: ocrImage, fast: false)
                let mergedTexts = VisionTextScanner.merge(fastTexts, accurateTexts)
                let numbers = VisionTextScanner.extractDartNumbers(from: mergedTexts)
                let bettingSeconds = self.timerRecognizer.recognize(from: ocrImage)

                let motion = insight.motionIntensity
                if motion > 0.18 {
                    self.throwMotionDetected = true
                } else if motion < 0.06 && self.throwMotionDetected {
                    self.motionReleased = true
                    self.throwMotionDetected = false
                }

                let confirmed = self.throwTracker.process(
                    detectedNumbers: numbers,
                    motionReleased: self.motionReleased
                )
                if confirmed != nil {
                    self.motionReleased = false
                }

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
                    if self.latestImage != nil {
                        self.drainQueue()
                    }
                }
            }
        }
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
        if insight.playerDetected && (insight.detectedAction == .aim || insight.detectedAction == .stance) {
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
        let minWidth: CGFloat = 640
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
