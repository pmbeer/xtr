import Foundation
import CoreGraphics

/// ИИ-анализатор с раздельными зонами: результаты / игрок / доска / ставки
final class GameAIAnalyzer {
    static let shared = GameAIAnalyzer()

    private let aiAction = AIActionAnalyzer.shared
    private let timerRecognizer = BettingTimerRecognizer.shared
    private let throwTracker = ThrowSequenceTracker()
    private let processingQueue = DispatchQueue(label: "com.dartpredictor.gameai", qos: .userInteractive)
    private var throwMotionDetected = false
    private var motionReleased = false
    private var prevDartboardBytes: [UInt8]?
    private var prevPlayerBytes: [UInt8]?
    private var poseFrameCounter = 0

    /// Быстрый live-анализ (~3 раза/сек) — не блокирует захват окна
    func analyzeLive(image: CGImage, zones: GameWindowZones, completion: @escaping (GameSnapshot) -> Void) {
        processingQueue.async { [weak self] in
            guard let self else { return }
            let snapshot = self.buildSnapshot(image: image, zones: zones, includePose: self.poseFrameCounter % 2 == 0)
            self.poseFrameCounter += 1
            DispatchQueue.main.async {
                completion(snapshot)
            }
        }
    }

    func analyze(image: CGImage, zones: GameWindowZones, completion: @escaping (GameSnapshot) -> Void) {
        processingQueue.async { [weak self] in
            guard let self else { return }
            let snapshot = self.buildSnapshot(image: image, zones: zones, includePose: true)
            DispatchQueue.main.async {
                completion(snapshot)
            }
        }
    }

    func reset() {
        throwTracker.reset()
        timerRecognizer.reset()
        aiAction.reset()
        throwMotionDetected = false
        motionReleased = false
        prevDartboardBytes = nil
        prevPlayerBytes = nil
        poseFrameCounter = 0
    }

    private func buildSnapshot(image: CGImage, zones: GameWindowZones, includePose: Bool) -> GameSnapshot {
        let start = CFAbsoluteTimeGetCurrent()
        let scaled = scaleForAnalysis(image)

        let resultsCrop = WindowZoneCropper.crop(image: scaled, zone: zones.resultsZone)
        let playerCrop = WindowZoneCropper.crop(image: scaled, zone: zones.playerZone)
        let dartboardCrop = WindowZoneCropper.crop(image: scaled, zone: zones.dartboardZone)
        let bettingCrop = WindowZoneCropper.crop(image: scaled, zone: zones.bettingZone)

        // Live: только fast OCR в зонах результатов и ставок
        let resultTexts = scanCrop(resultsCrop, accurate: false)
        let resultNumbers = VisionTextScanner.extractDartNumbers(from: resultTexts)
        let resultHistory = extractHistoryStrip(from: resultNumbers)

        let bettingTexts = scanCrop(bettingCrop, accurate: false)
        let forecastsAccepted = detectForecastsAccepted(from: bettingTexts)

        let playerTimerCrop = playerCrop ?? scaled
        let bettingSeconds = forecastsAccepted ? nil : self.timerRecognizer.recognize(from: playerTimerCrop)

        let dartMotion = WindowZoneCropper.computeMotion(image: dartboardCrop, previousBytes: &prevDartboardBytes)
        let playerMotion = WindowZoneCropper.computeMotion(image: playerCrop, previousBytes: &prevPlayerBytes)
        let combinedMotion = max(dartMotion * 1.4, playerMotion)

        if combinedMotion > 0.14 {
            throwMotionDetected = true
        } else if combinedMotion < 0.05 && throwMotionDetected {
            motionReleased = true
            throwMotionDetected = false
        }

        let confirmed = throwTracker.process(
            detectedNumbers: resultNumbers,
            motionReleased: motionReleased || dartMotion > 0.18
        )
        if confirmed != nil {
            motionReleased = false
        }

        var playerInsight = AIActionInsight.empty
        var playerFeatures = PlayerFeatures.zero

        if includePose, let playerCrop {
            let semaphore = DispatchSemaphore(value: 0)
            aiAction.analyzeFrame(playerCrop) { insight, features in
                playerInsight = insight
                playerFeatures = features
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + 1.2)
        } else if let playerCrop {
            playerInsight.aiDescription = "Игрок: движение \(Int(playerMotion * 100))%"
            playerInsight.motionIntensity = playerMotion
        } else {
            playerInsight.aiDescription = "Зона игрока не видна"
        }

        let throwInProgress = playerInsight.detectedAction == .throwMotion
            || playerInsight.detectedAction == .release
            || throwMotionDetected
            || dartMotion > 0.16

        var enrichedInsight = playerInsight
        enrichedInsight.motionIntensity = max(playerInsight.motionIntensity, combinedMotion)
        enrichedInsight.aiDescription = buildZoneDescription(
            playerInsight: enrichedInsight,
            dartMotion: dartMotion,
            playerMotion: playerMotion,
            forecastsAccepted: forecastsAccepted,
            resultHistory: resultHistory
        )

        let phase = classifyPhase(
            insight: enrichedInsight,
            resultHistory: resultHistory,
            bettingSeconds: bettingSeconds,
            forecastsAccepted: forecastsAccepted,
            throwMotion: throwMotionDetected,
            dartMotion: dartMotion,
            confirmedResult: confirmed
        )

        return GameSnapshot(
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
    }

    private func scanCrop(_ crop: CGImage?, accurate: Bool) -> [VisionTextItem] {
        guard let crop else { return [] }
        let fast = VisionTextScanner.scan(image: crop, fast: true)
        if !accurate { return fast }
        let merged = VisionTextScanner.scan(image: crop, fast: false)
        return VisionTextScanner.merge(fast, merged)
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
        resultHistory: [Int]
    ) -> String {
        var parts: [String] = []
        parts.append("Доска: \(motionLabel(dartMotion))")
        parts.append("Игрок: \(playerInsight.detectedAction.rawValue)")
        if forecastsAccepted { parts.append("ставки закрыты") }
        if !resultHistory.isEmpty {
            parts.append("история: \(resultHistory.map(String.init).joined(separator: "→"))")
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
            if upper.contains("ПРОГНОЗЫ ПРИНЯТЫ") || upper.contains("ПРОГНОЗЫПРИНЯТЫ") { return true }
            if upper.contains("ПРИНЯТЫ") && upper.contains("ПРОГНОЗ") { return true }
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
        if confirmedResult != nil { return .resultShown }
        if forecastsAccepted { return .watchingResults }
        if let sec = bettingSeconds, sec > 0 && sec <= 25 { return .bettingWindow }
        if insight.playerDetected && (insight.detectedAction == .aim || insight.detectedAction == .stance) {
            return .playerPreparing
        }
        if insight.playerDetected || insight.motionIntensity > 0.08 { return .playerVisible }
        if !resultHistory.isEmpty { return .watchingResults }
        return .idle
    }

    private func scaleForAnalysis(_ image: CGImage) -> CGImage {
        let targetWidth: CGFloat = 720
        if CGFloat(image.width) <= targetWidth { return image }
        let scale = targetWidth / CGFloat(image.width)
        let w = Int(CGFloat(image.width) * scale)
        let h = Int(CGFloat(image.height) * scale)
        guard w > 0, h > 0,
              let ctx = CGContext(
                  data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return image }
        ctx.interpolationQuality = .medium
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage() ?? image
    }
}
