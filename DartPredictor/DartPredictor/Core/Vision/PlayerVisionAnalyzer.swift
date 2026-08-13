import Foundation
import Vision
import CoreGraphics
import Accelerate

final class PlayerVisionAnalyzer {
    static let shared = PlayerVisionAnalyzer()

    private let processingQueue = DispatchQueue(label: "com.dartpredictor.vision", qos: .userInteractive)
    private var previousFrameData: [UInt8]?
    private var frameTimestamps: [Date] = []
    private var motionHistory: [Double] = []
    private var armPositions: [CGPoint] = []
    private var lastThrowTime: Date?
    private var throwStartTime: Date?
    private let maxHistoryFrames = 30

    func analyzeFrame(_ image: CGImage, completion: @escaping (PlayerFeatures) -> Void) {
        processingQueue.async { [weak self] in
            guard let self else { return }
            let features = self.extractFeatures(from: image)
            DispatchQueue.main.async {
                completion(features)
            }
        }
    }

    private func extractFeatures(from image: CGImage) -> PlayerFeatures {
        let scaled = scaleImage(image, scale: DartConstants.playerAnalysisScale)
        var features = PlayerFeatures()

        let now = Date()
        frameTimestamps.append(now)
        if frameTimestamps.count > maxHistoryFrames {
            frameTimestamps.removeFirst()
        }

        let motion = computeMotion(from: scaled)
        motionHistory.append(motion)
        if motionHistory.count > maxHistoryFrames {
            motionHistory.removeFirst()
        }

        let poseFeatures = detectBodyPose(in: scaled)
        features.bodyTilt = poseFeatures.bodyTilt
        features.shoulderAngle = poseFeatures.shoulderAngle
        features.armHeight = poseFeatures.armHeight
        features.armExtension = poseFeatures.armExtension
        features.movementDirection = poseFeatures.movementDirection

        features.swingAmplitude = computeSwingAmplitude()
        features.swingSpeed = computeSwingSpeed()
        features.motionVariance = computeVariance(motionHistory)
        features.frameCount = frameTimestamps.count

        if let last = lastThrowTime {
            features.intervalSinceLastThrow = now.timeIntervalSince(last)
        }

        if motion > 0.15 && throwStartTime == nil {
            throwStartTime = now
            features.throwStartTimestamp = now.timeIntervalSince1970
        }

        if throwStartTime != nil && motion < 0.05 {
            features.releaseTimestamp = now.timeIntervalSince1970
            features.preparationDuration = now.timeIntervalSince(throwStartTime ?? now)
            throwStartTime = nil
            lastThrowTime = now
        }

        features.bodyMovementBeforeThrow = motionHistory.suffix(5).reduce(0, +) / Double(min(5, motionHistory.count))

        armPositions.append(CGPoint(x: poseFeatures.armHeight, y: poseFeatures.armExtension))
        if armPositions.count > maxHistoryFrames {
            armPositions.removeFirst()
        }

        return features
    }

    private func scaleImage(_ image: CGImage, scale: CGFloat) -> CGImage {
        let newWidth = Int(CGFloat(image.width) * scale)
        let newHeight = Int(CGFloat(image.height) * scale)
        guard newWidth > 0, newHeight > 0 else { return image }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: newWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }

        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage() ?? image
    }

    private func computeMotion(from image: CGImage) -> Double {
        guard let data = image.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return 0 }

        let byteCount = CFDataGetLength(data)
        var current = Array(UnsafeBufferPointer(start: bytes, count: byteCount))

        guard let previous = previousFrameData, previous.count == current.count else {
            previousFrameData = current
            return 0
        }

        var diffSum: Double = 0
        let step = 16
        var count = 0
        for i in Swift.stride(from: 0, to: current.count, by: step) {
            diffSum += Double(abs(Int(current[i]) - Int(previous[i])))
            count += 1
        }

        previousFrameData = current
        guard count > 0 else { return 0 }
        return diffSum / Double(count) / 255.0
    }

    private struct PoseResult {
        var bodyTilt: Double = 0
        var shoulderAngle: Double = 0
        var armHeight: Double = 0
        var armExtension: Double = 0
        var movementDirection: Double = 0
    }

    private func detectBodyPose(in image: CGImage) -> PoseResult {
        var result = PoseResult()
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([request])
        } catch {
            DebugLogger.shared.logVisionError(error.localizedDescription)
            return result
        }

        guard let observation = request.results?.first else { return result }

        do {
            let neck = try observation.recognizedPoint(.neck)
            let root = try observation.recognizedPoint(.root)
            let leftShoulder = try observation.recognizedPoint(.leftShoulder)
            let rightShoulder = try observation.recognizedPoint(.rightShoulder)
            let leftWrist = try observation.recognizedPoint(.leftWrist)
            let rightWrist = try observation.recognizedPoint(.rightWrist)

            if neck.confidence > 0.3 && root.confidence > 0.3 {
                result.bodyTilt = Double(neck.location.x - root.location.x)
            }

            if leftShoulder.confidence > 0.3 && rightShoulder.confidence > 0.3 {
                let dx = rightShoulder.location.x - leftShoulder.location.x
                let dy = rightShoulder.location.y - leftShoulder.location.y
                result.shoulderAngle = atan2(dy, dx)
            }

            let wrist = leftWrist.confidence > rightWrist.confidence ? leftWrist : rightWrist
            if wrist.confidence > 0.3 {
                result.armHeight = Double(wrist.location.y)
                result.armExtension = Double(wrist.location.x)
            }

            if armPositions.count >= 2 {
                let last = armPositions[armPositions.count - 1]
                result.movementDirection = atan2(
                    wrist.location.y - last.y,
                    wrist.location.x - last.x
                )
            }
        } catch {
            DebugLogger.shared.logVisionError(error.localizedDescription)
        }

        return result
    }

    private func computeSwingAmplitude() -> Double {
        guard armPositions.count >= 3 else { return 0 }
        let ys = armPositions.map { $0.y }
        let minY = ys.min() ?? 0
        let maxY = ys.max() ?? 0
        return Double(maxY - minY)
    }

    private func computeSwingSpeed() -> Double {
        guard armPositions.count >= 2, frameTimestamps.count >= 2 else { return 0 }
        let last = armPositions[armPositions.count - 1]
        let prev = armPositions[armPositions.count - 2]
        let dt = frameTimestamps[frameTimestamps.count - 1].timeIntervalSince(frameTimestamps[frameTimestamps.count - 2])
        guard dt > 0 else { return 0 }
        let dist = hypot(last.x - prev.x, last.y - prev.y)
        return Double(dist) / dt
    }

    private func computeVariance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { ($0 - mean) * ($0 - mean) }
        return squaredDiffs.reduce(0, +) / Double(values.count)
    }

    func reset() {
        previousFrameData = nil
        frameTimestamps = []
        motionHistory = []
        armPositions = []
        throwStartTime = nil
    }

    func snapshotCurrentFeatures() -> PlayerFeatures {
        PlayerFeatures(
            swingAmplitude: computeSwingAmplitude(),
            swingSpeed: computeSwingSpeed(),
            motionVariance: computeVariance(motionHistory),
            intervalSinceLastThrow: lastThrowTime.map { Date().timeIntervalSince($0) } ?? 0,
            frameCount: frameTimestamps.count
        )
    }
}
