import Foundation
import Vision
import CoreGraphics
import Accelerate

/// ИИ-анализатор действий на экране: поза, движение, фазы броска, embedding игрока
final class AIActionAnalyzer {
    static let shared = AIActionAnalyzer()

    private let processingQueue = DispatchQueue(label: "com.dartpredictor.ai", qos: .userInteractive)
    private let neuralClassifier = NeuralActionClassifier.shared

    private var frameBuffer: [[Double]] = []
    private let maxFrames = 15
    private var previousFrameBytes: [UInt8]?
    private var previousPose: [Double] = []
    private var motionHistory: [Double] = []
    private var currentAction: PlayerActionType = .none
    private var actionStartTime: Date?
    private var lastThrowTime: Date?
    private var sceneState: GameSceneState = .idle

    func analyzeFrame(_ image: CGImage, completion: @escaping (AIActionInsight, PlayerFeatures) -> Void) {
        processingQueue.async { [weak self] in
            guard let self else { return }
            let scaled = self.scaleImage(image, scale: DartConstants.playerAnalysisScale)
            let motion = self.computeMotion(scaled)
            let pose = self.detectPose(scaled)
            let features = self.buildFeatures(pose: pose, motion: motion)

            self.frameBuffer.append(features.vector)
            if self.frameBuffer.count > self.maxFrames {
                self.frameBuffer.removeFirst()
            }

            let action = self.classifyAction(motion: motion, pose: pose, features: features)
            self.currentAction = action
            self.sceneState = self.deriveSceneState(action: action, motion: motion, pose: pose)

            let sequence = self.frameBuffer.flatMap { $0 }
            let numberScores = self.neuralClassifier.predictNumber(from: sequence)

            let embedding = self.buildPlayerEmbedding(pose: pose)
            let progress = self.computeThrowProgress(action: action, motion: motion)

            var insight = AIActionInsight(
                sceneState: self.sceneState,
                detectedAction: action,
                actionConfidence: self.computeActionConfidence(pose: pose, motion: motion),
                playerDetected: pose.confidence > 0.25,
                playerEmbedding: embedding,
                motionIntensity: motion,
                throwPhaseProgress: progress,
                aiDescription: self.describeScene(action: action, pose: pose, motion: motion),
                numberScores: numberScores
            )

            DispatchQueue.main.async {
                completion(insight, features)
            }
        }
    }

    func trainOnResult(_ number: Int, featureSequence: [Double]) {
        processingQueue.async {
            self.neuralClassifier.train(actual: number, featureSequence: featureSequence)
        }
    }

    func reset() {
        frameBuffer = []
        previousFrameBytes = nil
        previousPose = []
        motionHistory = []
        currentAction = .none
        sceneState = .idle
        actionStartTime = nil
    }

    private struct PoseData {
        var bodyTilt: Double = 0
        var shoulderAngle: Double = 0
        var armHeight: Double = 0
        var armExtension: Double = 0
        var wristY: Double = 0
        var confidence: Double = 0
    }

    private func scaleImage(_ image: CGImage, scale: CGFloat) -> CGImage {
        let w = max(1, Int(CGFloat(image.width) * scale))
        let h = max(1, Int(CGFloat(image.height) * scale))
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        ctx.interpolationQuality = .low
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage() ?? image
    }

    private func computeMotion(_ image: CGImage) -> Double {
        guard let data = image.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return 0 }
        let count = CFDataGetLength(data)
        var current = Array(UnsafeBufferPointer(start: bytes, count: count))

        guard let prev = previousFrameBytes, prev.count == current.count else {
            previousFrameBytes = current
            return 0
        }

        var diff: Double = 0
        let step = 20
        var samples = 0
        for i in Swift.stride(from: 0, to: current.count, by: step) {
            diff += Double(abs(Int(current[i]) - Int(prev[i])))
            samples += 1
        }
        previousFrameBytes = current
        let motion = samples > 0 ? diff / Double(samples) / 255.0 : 0
        motionHistory.append(motion)
        if motionHistory.count > 30 { motionHistory.removeFirst() }
        return motion
    }

    private func detectPose(_ image: CGImage) -> PoseData {
        var pose = PoseData()
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do { try handler.perform([request]) } catch { return pose }

        guard let obs = request.results?.first else { return pose }

        do {
            let neck = try obs.recognizedPoint(.neck)
            let root = try obs.recognizedPoint(.root)
            let ls = try obs.recognizedPoint(.leftShoulder)
            let rs = try obs.recognizedPoint(.rightShoulder)
            let lw = try obs.recognizedPoint(.leftWrist)
            let rw = try obs.recognizedPoint(.rightWrist)

            pose.confidence = Double(max(neck.confidence, root.confidence, ls.confidence))

            if neck.confidence > 0.2 && root.confidence > 0.2 {
                pose.bodyTilt = Double(neck.location.x - root.location.x)
            }
            if ls.confidence > 0.2 && rs.confidence > 0.2 {
                pose.shoulderAngle = atan2(
                    rs.location.y - ls.location.y,
                    rs.location.x - ls.location.x
                )
            }
            let wrist = lw.confidence > rw.confidence ? lw : rw
            if wrist.confidence > 0.2 {
                pose.armHeight = Double(wrist.location.y)
                pose.armExtension = Double(wrist.location.x)
                pose.wristY = Double(wrist.location.y)
            }
        } catch {}

        return pose
    }

    private func buildFeatures(pose: PoseData, motion: Double) -> PlayerFeatures {
        let now = Date()
        var f = PlayerFeatures()
        f.bodyTilt = pose.bodyTilt
        f.shoulderAngle = pose.shoulderAngle
        f.armHeight = pose.armHeight
        f.armExtension = pose.armExtension
        f.swingSpeed = motionHistory.count >= 2
            ? motionHistory[motionHistory.count - 1] - motionHistory[motionHistory.count - 2]
            : 0
        f.swingAmplitude = (motionHistory.max() ?? 0) - (motionHistory.min() ?? 0)
        f.movementDirection = f.swingSpeed
        f.bodyMovementBeforeThrow = motionHistory.suffix(5).reduce(0, +) / Double(min(5, motionHistory.count))
        f.motionVariance = variance(motionHistory)
        f.frameCount = frameBuffer.count
        if let last = lastThrowTime {
            f.intervalSinceLastThrow = now.timeIntervalSince(last)
        }
        if actionStartTime != nil {
            f.preparationDuration = now.timeIntervalSince(actionStartTime!)
        }
        return f
    }

    private func classifyAction(motion: Double, pose: PoseData, features: PlayerFeatures) -> PlayerActionType {
        guard pose.confidence > 0.2 else { return .none }

        let armHigh = pose.armHeight > 0.55
        let fastMotion = motion > 0.12
        let veryFast = motion > 0.22
        let slowMotion = motion < 0.04

        if veryFast && armHigh { return .release }
        if fastMotion && armHigh { return .throwMotion }
        if motion > 0.08 && pose.armExtension > 0.3 { return .windup }
        if slowMotion && armHigh { return .aim }
        if pose.confidence > 0.3 && motion < 0.06 { return .stance }
        if fastMotion && !armHigh { return .recovery }
        return .stance
    }

    private func deriveSceneState(action: PlayerActionType, motion: Double, pose: PoseData) -> GameSceneState {
        switch action {
        case .none:
            return motion > 0.05 ? .idle : .idle
        case .stance, .aim:
            return pose.confidence > 0.25 ? .preparing : .playerVisible
        case .windup:
            return .preparing
        case .throwMotion:
            return .throwing
        case .release:
            lastThrowTime = Date()
            return .release
        case .recovery:
            return motion < 0.05 ? .resultPending : .throwing
        }
    }

    private func buildPlayerEmbedding(pose: PoseData) -> [Double] {
        [pose.bodyTilt, pose.shoulderAngle, pose.armHeight, pose.armExtension, pose.wristY, pose.confidence]
    }

    private func computeThrowProgress(action: PlayerActionType, motion: Double) -> Double {
        switch action {
        case .none: return 0
        case .stance: return 0.1
        case .aim: return 0.25
        case .windup: return 0.45
        case .throwMotion: return 0.7
        case .release: return 0.9
        case .recovery: return 1.0
        }
    }

    private func computeActionConfidence(pose: PoseData, motion: Double) -> Double {
        min(1.0, pose.confidence * 0.6 + min(motion * 2, 0.4))
    }

    private func describeScene(action: PlayerActionType, pose: PoseData, motion: Double) -> String {
        if pose.confidence < 0.2 {
            return "ИИ: игрок не виден на экране"
        }
        let motionDesc = motion > 0.15 ? "активное движение" : motion > 0.05 ? "лёгкое движение" : "статичен"
        return "ИИ: \(action.rawValue), \(motionDesc), уверенность \(Int(pose.confidence * 100))%"
    }

    private func variance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        return values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)
    }
}
