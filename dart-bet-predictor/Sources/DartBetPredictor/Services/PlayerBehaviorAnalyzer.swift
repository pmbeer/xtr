import CoreGraphics
import Foundation
import Vision

/// Анализ поведения игрока: поза тела, движение, фаза броска.
final class PlayerBehaviorAnalyzer {
    static let shared = PlayerBehaviorAnalyzer()

    private let queue = DispatchQueue(label: "dartbet.behavior", qos: .userInitiated)
    private var previousFrame: [UInt8]?
    private var previousSnapshot: PlayerBehaviorSnapshot?
    private var motionHistory: [Double] = []
    private var lastThrowTime: Date?
    private let motionHistoryLimit = 12

    private init() {}

    func markThrowDetected() {
        lastThrowTime = Date()
        motionHistory.removeAll()
    }

    func analyze(image: CGImage, completion: @escaping (PlayerBehaviorSnapshot) -> Void) {
        queue.async { [weak self] in
            guard let self else { return }

            var snapshot = PlayerBehaviorSnapshot()
            snapshot.motionIntensity = self.computeMotionIntensity(image: image)
            snapshot.capturedAt = Date()

            self.motionHistory.append(snapshot.motionIntensity)
            if self.motionHistory.count > self.motionHistoryLimit {
                self.motionHistory.removeFirst()
            }

            let pose = self.detectPose(in: image)
            if let pose {
                snapshot.bodyDetected = true
                snapshot.armRaise = pose.armRaise
                snapshot.lateralLean = pose.lateralLean
                snapshot.shoulderAngle = pose.shoulderAngle
            }

            snapshot.phase = self.inferPhase(
                motion: snapshot.motionIntensity,
                armRaise: snapshot.armRaise,
                history: self.motionHistory
            )

            self.previousSnapshot = snapshot

            DispatchQueue.main.async {
                completion(snapshot)
            }
        }
    }

    // MARK: - Motion

    private func computeMotionIntensity(image: CGImage) -> Double {
        let width = min(image.width, 160)
        let height = min(image.height, 120)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return 0 }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return 0 }

        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height)
        var pixels = [UInt8](repeating: 0, count: width * height)
        for i in 0..<(width * height) {
            pixels[i] = buffer[i]
        }

        guard let previous = previousFrame, previous.count == pixels.count else {
            previousFrame = pixels
            return 0
        }

        var diffSum = 0
        for i in 0..<pixels.count {
            diffSum += abs(Int(pixels[i]) - Int(previous[i]))
        }
        previousFrame = pixels

        let maxDiff = pixels.count * 255
        return min(1.0, Double(diffSum) / Double(maxDiff) * 8.0)
    }

    // MARK: - Pose

    private struct PoseMetrics {
        let armRaise: Double
        let lateralLean: Double
        let shoulderAngle: Double
    }

    private func detectPose(in image: CGImage) -> PoseMetrics? {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observation = request.results?.first else { return nil }

        guard let rightWrist = try? observation.recognizedPoint(.rightWrist),
              let rightShoulder = try? observation.recognizedPoint(.rightShoulder),
              let leftShoulder = try? observation.recognizedPoint(.leftShoulder),
              rightWrist.confidence > 0.2,
              rightShoulder.confidence > 0.2 else {
            return nil
        }

        let armRaise = max(0, min(1, (rightShoulder.location.y - rightWrist.location.y) * 2.5))
        let shoulderWidth = abs(rightShoulder.location.x - leftShoulder.location.x)
        let centerX = (rightShoulder.location.x + leftShoulder.location.x) / 2
        let lateralLean = shoulderWidth > 0.01
            ? max(-1, min(1, (rightWrist.location.x - centerX) / shoulderWidth * 2))
            : 0

        let dy = rightShoulder.location.y - leftShoulder.location.y
        let dx = rightShoulder.location.x - leftShoulder.location.x
        let angle = atan2(dy, dx) * 180 / .pi

        return PoseMetrics(armRaise: armRaise, lateralLean: lateralLean, shoulderAngle: angle)
    }

    // MARK: - Phase inference

    private func inferPhase(motion: Double, armRaise: Double, history: [Double]) -> PlayerPhase {
        let avgMotion = history.isEmpty ? motion : history.reduce(0, +) / Double(history.count)
        let peakMotion = history.max() ?? motion

        if peakMotion > 0.12 && motion > avgMotion * 0.85 {
            return .release
        }
        if armRaise > 0.55 && motion > 0.04 {
            return .windup
        }
        if armRaise > 0.3 || (motion > 0.02 && motion < 0.08) {
            return .aiming
        }
        return .idle
    }

    func reset() {
        previousFrame = nil
        previousSnapshot = nil
        motionHistory.removeAll()
        lastThrowTime = nil
    }
}
