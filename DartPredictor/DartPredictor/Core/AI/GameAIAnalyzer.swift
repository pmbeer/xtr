import Foundation
import CoreGraphics

/// ИИ-анализатор с раздельными зонами: результаты / игрок / доска / ставки
final class GameAIAnalyzer {
    static let shared = GameAIAnalyzer()

    private let aiAction = AIActionAnalyzer.shared
    private let timerRecognizer = BettingTimerRecognizer.shared
    private let throwTracker = ThrowSequenceTracker()
    private let processingQueue = DispatchQueue(label: "com.dartpredictor.gameai", qos: .userInteractive)
    private var isProcessing = false
    private var latestImage: CGImage?
    private var latestZones: GameWindowZones = .fonBetDefault
    private var pendingCompletion: ((GameSnapshot) -> Void)?
    private var throwMotionDetected = false
    private var motionReleased = false
    private var prevDartboardBytes: [UInt8]?
    private var prevPlayerBytes: [UInt8]?

    func analyze(image: CGImage, zones: GameWindowZones, completion: @escaping (GameSnapshot) -> Void) {
        latestImage = image
        latestZones = zones
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
        prevDartboardBytes = nil
        prevPlayerBytes = nil
    }

    private func drainQueue() {
        guard let image = latestImage, let completion = pendingCompletion else { return }
        latestImage = nil
        isProcessing = true
        let start = CFAbsoluteTimeGetCurrent()
        let zones = latestZones
        let scaled = scaleForAnalysis(image)

        let resultsCrop = WindowZoneCropper.crop(image: scaled, zone: zones.resultsZone)
        let playerCrop = WindowZoneCropper.crop(image: scaled, zone: zones.playerZone)
        let dartboardCrop = WindowZoneCropper.crop(image: scaled, zone: zones.dartboardZone)
        let bettingCrop = WindowZoneCropper.crop(image: scaled, zone: zones.bettingZone)

        processingQueue.async { [weak self] in
            guard let self else { return }

            let resultTexts = self.scanCrop(resultsCrop)
            let resultNumbers = VisionTextScanner.extractDartNumbers(from: resultTexts)
            let resultHistory = self.extractHistoryStrip(from: resultNumbers)

            let bettingTexts = self.scanCrop(bettingCrop)
            let forecastsAccepted = self.detectForecastsAccepted(from: bettingTexts)

            let playerTimerCrop = playerCrop ?? scaled
            let bettingSeconds = forecastsAccepted ? nil : self.timerRecognizer.recognize(from: playerTimerCrop)

            let dartMotion = WindowZoneCropper.computeMotion(image: dartboardCrop, previousBytes: &self.prevDartboardBytes)
            let playerMotion = WindowZoneCropper.computeMotion(image: playerCrop, previousBytes: &self.prevPlayerBytes)
            let combinedMotion = max(dartMotion * 1.4, playerMotion)

            if combinedMotion > 0.14 {
                self.throwMotionDetected = true
            } else if combinedMotion < 0.05 && self.throwMotionDetected {
                self.motionReleased = true
                self.throwMotionDetected = false
            }

            let confirmed = self.throwTracker.process(
                detectedNumbers: resultNumbers,
                motionReleased: self.motionReleased || dartMotion > 0.18
            )
            if confirmed != nil {
                self.motionReleased = false
            }

            let group = DispatchGroup()
            var playerInsight = AIActionInsight.empty
            var playerFeatures = PlayerFeatures.zero

            if let playerCrop {
                group.enter()
                self.aiAction.analyzeFrame(playerCrop) { insight, features in
                    playerInsight = insight
                    playerFeatures = features
                    group.leave()
                }
            } else {
                playerInsight.aiDescription = "ИИ: зона игрока не видна"
            }

            group.notify(queue: self.processingQueue) {
                let throwInProgress = playerInsight.detectedAction == .throwMotion
                    || playerInsight.detectedAction == .release
                    || self.throwMotionDetected
                    || dartMotion > 0.16

                var enrichedInsight = playerInsight
                enrichedInsight.motionIntensity = max(playerInsight.motionIntensity, combinedMotion)
                enrichedInsight.aiDescription = self.buildZoneDescription(
                    playerInsight: enrichedInsight,
                    dartMotion: dartMotion,
                    playerMotion: playerMotion,
                    forecastsAccepted: forecastsAccepted,
                    resultCount: resultHistory.count
                )

                let phase = self.classifyPhase(
                    insight: enrichedInsight,
                    resultHistory: resultHistory,
                    bettingSeconds: bettingSeconds,
                    forecastsAccepted: forecastsAccepted,
                    throwMotion: self.throwMotionDetected,
                    dartMotion: dartMotion,
                    confirmedResult: confirmed
                )

                let snapshot = GameSnapshot(
                    timestamp: Date(),
                    detectedNumbers: resultNumbers,
                    resultHistory: resultHistory,
                    bettingSeconds: bettingSeconds,
                    phase: phase,
                    aiInsight: enrichedInsight,
                    playerFeatures: playerFeatures,
                    throwInProgress: throwInProgress,
                    throwCompleted: confirmed != nil,
                    confirmedResult: confirmed,
                    forecastsAccepted: forecastsAccepted,
                    dartboardMotion: dartMotion,
                    playerMotion: playerMotion,
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

    private func scanCrop(_ crop: CGImage?) -> [VisionTextItem] {
        guard let crop else { return [] }
        let fast = VisionTextScanner.scan(image: crop, fast: true)
        let accurate = VisionTextScanner.scan(image: crop, fast: false)
        return VisionTextScanner.merge(fast, accurate)
    }

    private func extractHistoryStrip(from numbers: [DetectedNumber]) -> [Int] {
        numbers
            .sorted { $0.boundingBox.origin.x < $1.boundingBox.origin.x }
            .map(\.value)
    }

    private func buildZoneDescription(
        playerInsight: AIActionInsight,
        dartMotion: Double,
        playerMotion: Double,
        forecastsAccepted: Bool,
        resultCount: Int
    ) -> String {
        var parts: [String] = []
        parts.append("Доска: \(motionLabel(dartMotion))")
        parts.append("Игрок: \(playerInsight.detectedAction.rawValue)")
        if forecastsAccepted {
            parts.append("ставки закрыты")
        }
        if resultCount > 0 {
            parts.append("история: \(resultCount) чисел")
        }
        return "ИИ · " + parts.joined(separator: " · ")
    }

    private func motionLabel(_ motion: Double) -> String {
        if motion > 0.18 { return "бросок!" }
        if motion > 0.08 { return "движение" }
        return "стабильна"
    }

    private func detectForecastsAccepted(from texts: [VisionTextItem]) -> Bool {
        for item in texts {
            let upper = item.text.uppercased()
            if upper.contains("ПРОГНОЗЫ ПРИНЯТЫ") || upper.contains("ПРОГНОЗЫПРИНЯТЫ") {
                return true
            }
            if upper.contains("ПРИНЯТЫ") && upper.contains("ПРОГНОЗ") {
                return true
            }
        }
        return false
    }

    private func classifyPhase(
        insight: AIActionInsight,
        resultHistory: [Int],
        bettingSeconds: Double?,
        forecastsAccepted: Bool,
        throwMotion: Bool,
        dartMotion: Double,
        confirmedResult: Int?
    ) -> GamePhase {
        if throwMotion || dartMotion > 0.18 || insight.detectedAction == .throwMotion || insight.detectedAction == .windup {
            return .throwing
        }
        if confirmedResult != nil {
            return .resultShown
        }
        if forecastsAccepted {
            return .watchingResults
        }
        if let sec = bettingSeconds, sec > 0 && sec <= 25 {
            return .bettingWindow
        }
        if insight.playerDetected && (insight.detectedAction == .aim || insight.detectedAction == .stance) {
            return .playerPreparing
        }
        if insight.playerDetected || insight.motionIntensity > 0.08 {
            return .playerVisible
        }
        if !resultHistory.isEmpty {
            return .watchingResults
        }
        return .idle
    }

    private func scaleForAnalysis(_ image: CGImage) -> CGImage {
        let minWidth: CGFloat = 960
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
