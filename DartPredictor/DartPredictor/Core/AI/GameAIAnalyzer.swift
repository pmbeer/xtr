import Foundation
import CoreGraphics

/// ИИ-анализатор: только результаты + поведение игрока (overlay/таймеры игнорируются)
final class GameAIAnalyzer {
    static let shared = GameAIAnalyzer()

    private let aiAction = AIActionAnalyzer.shared
    private let throwTracker = ThrowSequenceTracker()
    private let processingQueue = DispatchQueue(label: "com.dartpredictor.gameai", qos: .userInteractive)
    private var throwMotionDetected = false
    private var motionReleased = false
    private var prevPlayerBytes: [UInt8]?
    private var poseFrameCounter = 0

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
        aiAction.reset()
        throwMotionDetected = false
        motionReleased = false
        prevPlayerBytes = nil
        poseFrameCounter = 0
    }

    private func buildSnapshot(image: CGImage, zones: GameWindowZones, includePose: Bool) -> GameSnapshot {
        let start = CFAbsoluteTimeGetCurrent()
        let scaled = scaleForAnalysis(image)
        let ignored = zones.ignoredZones

        let resultsCrop = WindowZoneCropper.crop(image: scaled, zone: zones.resultsZone)
        let playerAnalysisCrop = WindowZoneCropper.cropMaskingIgnored(
            image: scaled,
            zone: zones.playerAnalysisZone(),
            ignoredZones: ignored
        )
        let bettingCrop = WindowZoneCropper.crop(image: scaled, zone: zones.bettingZone)

        let resultHistory = ResultsHistoryScanner.extract(from: resultsCrop)
        let resultNumbers = ResultsHistoryScanner.toDetectedNumbers(resultHistory)

        let bettingTexts = scanCrop(bettingCrop, accurate: false)
        let forecastsAccepted = detectForecastsAccepted(from: bettingTexts)

        // Таймеры на overlay не читаем — пользователь выделил их как игнорируемые
        let bettingSeconds: Double? = nil

        let playerMotion = WindowZoneCropper.computeMotion(
            image: playerAnalysisCrop,
            previousBytes: &prevPlayerBytes
        )

        if playerMotion > 0.14 {
            throwMotionDetected = true
        } else if playerMotion < 0.05 && throwMotionDetected {
            motionReleased = true
            throwMotionDetected = false
        }

        let confirmed = throwTracker.process(
            detectedNumbers: resultNumbers,
            motionReleased: motionReleased || playerMotion > 0.20
        )
        if confirmed != nil {
            motionReleased = false
        }

        var playerInsight = AIActionInsight.empty
        var playerFeatures = PlayerFeatures.zero

        if includePose, let playerAnalysisCrop {
            let semaphore = DispatchSemaphore(value: 0)
            aiAction.analyzeFrame(playerAnalysisCrop) { insight, features in
                playerInsight = insight
                playerFeatures = features
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + 1.2)
        } else if let playerAnalysisCrop {
            playerInsight.aiDescription = "Игрок: движение \(Int(playerMotion * 100))%"
            playerInsight.motionIntensity = playerMotion
        } else {
            playerInsight.aiDescription = "Зона игрока не видна"
        }

        let throwInProgress = playerInsight.detectedAction == .throwMotion
            || playerInsight.detectedAction == .release
            || throwMotionDetected
            || playerMotion > 0.18

        var enrichedInsight = playerInsight
        enrichedInsight.motionIntensity = playerMotion
        enrichedInsight.aiDescription = buildZoneDescription(
            playerInsight: enrichedInsight,
            playerMotion: playerMotion,
            forecastsAccepted: forecastsAccepted,
            resultHistory: resultHistory
        )

        let phase = classifyPhase(
            insight: enrichedInsight,
            resultHistory: resultHistory,
            forecastsAccepted: forecastsAccepted,
            throwMotion: throwMotionDetected,
            playerMotion: playerMotion,
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
            dartboardMotion: 0,
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

    private func buildZoneDescription(
        playerInsight: AIActionInsight,
        playerMotion: Double,
        forecastsAccepted: Bool,
        resultHistory: [Int]
    ) -> String {
        var parts: [String] = []
        parts.append("Игрок: \(playerInsight.detectedAction.rawValue)")
        parts.append(motionLabel(playerMotion))
        if forecastsAccepted { parts.append("ставки закрыты") }
        if !resultHistory.isEmpty {
            parts.append("попадания: \(resultHistory.map(String.init).joined(separator: "→"))")
        }
        parts.append("прогноз на следующую ставку")
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
        forecastsAccepted: Bool,
        throwMotion: Bool,
        playerMotion: Double,
        confirmedResult: Int?
    ) -> GamePhase {
        if throwMotion || playerMotion > 0.18
            || insight.detectedAction == .throwMotion
            || insight.detectedAction == .windup {
            return .throwing
        }
        if confirmedResult != nil { return .resultShown }
        if forecastsAccepted { return .watchingResults }
        if insight.playerDetected
            && (insight.detectedAction == .aim || insight.detectedAction == .stance)
            && !resultHistory.isEmpty {
            return .bettingWindow
        }
        if !resultHistory.isEmpty && !forecastsAccepted { return .bettingWindow }
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
