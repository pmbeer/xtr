import CoreGraphics
import Foundation
import Vision

/// Анализ поведения игрока: поза тела, движение, фаза броска.
final class PlayerBehaviorAnalyzer {
    static let shared = PlayerBehaviorAnalyzer()

    private let queue = DispatchQueue(label: "dartbet.behavior", qos: .userInitiated)
    private var previousFrame: [UInt8]?
    private var motionHistory: [Double] = []
    private var lastThrowTime: Date?

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
            if self.motionHistory.count > HardwareProfile.isIntelMac ? 8 : 12 {
                self.motionHistory.removeFirst()
            }

            // Детекция человека: прямоугольники (работает на дальних/частичных фигурах)
            let humanRect = self.detectHumanRectangle(in: image)

            // Поза — пробуем обе руки
            if let pose = self.detectPose(in: image) {
                snapshot.bodyDetected = true
                snapshot.armRaise = pose.armRaise
                snapshot.lateralLean = pose.lateralLean
                snapshot.shoulderAngle = pose.shoulderAngle
            } else if humanRect {
                snapshot.bodyDetected = true
                snapshot.armRaise = min(1.0, snapshot.motionIntensity * 2.5)
                snapshot.lateralLean = 0
            } else if snapshot.motionIntensity > 0.015 {
                // Видео живое, движение есть — игрок на экране, поза не распознана
                snapshot.bodyDetected = true
                snapshot.armRaise = min(1.0, snapshot.motionIntensity * 3)
            }

            snapshot.phase = self.inferPhase(
                motion: snapshot.motionIntensity,
                armRaise: snapshot.armRaise,
                history: self.motionHistory
            )

            DispatchQueue.main.async {
                completion(snapshot)
            }
        }
    }

    // MARK: - Motion

    private func computeMotionIntensity(image: CGImage) -> Double {
        let width = min(image.width, HardwareProfile.motionFrameWidth)
        let height = min(image.height, HardwareProfile.motionFrameHeight)
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

    // MARK: - Human detection

    private func detectHumanRectangle(in image: CGImage) -> Bool {
        let request = VNDetectHumanRectanglesRequest()
        request.upperBodyOnly = false
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return false
        }
        return (request.results?.isEmpty == false)
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

        let wristJoints: [VNHumanBodyPoseObservation.JointName] = [
            .rightWrist, .leftWrist, .rightElbow, .leftElbow
        ]
        let shoulderJoints: [VNHumanBodyPoseObservation.JointName] = [
            .rightShoulder, .leftShoulder
        ]

        var bestWrist: VNRecognizedPoint?
        var bestShoulder: VNRecognizedPoint?
        var leftShoulder: VNRecognizedPoint?
        var rightShoulder: VNRecognizedPoint?

        for joint in wristJoints {
            if let point = try? observation.recognizedPoint(joint), point.confidence > 0.12 {
                if bestWrist == nil || point.confidence > bestWrist!.confidence {
                    bestWrist = point
                }
            }
        }

        for joint in shoulderJoints {
            if let point = try? observation.recognizedPoint(joint), point.confidence > 0.12 {
                if joint == .rightShoulder { rightShoulder = point }
                if joint == .leftShoulder { leftShoulder = point }
                if bestShoulder == nil || point.confidence > bestShoulder!.confidence {
                    bestShoulder = point
                }
            }
        }

        guard let wrist = bestWrist, let shoulder = bestShoulder else { return nil }

        let armRaise = max(0, min(1, (shoulder.location.y - wrist.location.y) * 2.5))

        var lateralLean = 0.0
        if let rs = rightShoulder, let ls = leftShoulder {
            let shoulderWidth = abs(rs.location.x - ls.location.x)
            let centerX = (rs.location.x + ls.location.x) / 2
            lateralLean = shoulderWidth > 0.01
                ? max(-1, min(1, (wrist.location.x - centerX) / shoulderWidth * 2))
                : 0
        }

        let dy = (rightShoulder?.location.y ?? shoulder.location.y) - (leftShoulder?.location.y ?? shoulder.location.y)
        let dx = (rightShoulder?.location.x ?? shoulder.location.x) - (leftShoulder?.location.x ?? shoulder.location.x)
        let angle = atan2(dy, dx) * 180 / .pi

        return PoseMetrics(armRaise: armRaise, lateralLean: lateralLean, shoulderAngle: angle)
    }

    // MARK: - Phase inference

    private func inferPhase(motion: Double, armRaise: Double, history: [Double]) -> PlayerPhase {
        let avgMotion = history.isEmpty ? motion : history.reduce(0, +) / Double(history.count)
        let peakMotion = history.max() ?? motion

        if peakMotion > 0.08 && motion > avgMotion * 0.8 {
            return .release
        }
        if armRaise > 0.45 && motion > 0.03 {
            return .windup
        }
        if armRaise > 0.2 || (motion > 0.015 && motion < 0.1) {
            return .aiming
        }
        if motion > 0.01 {
            return .aiming
        }
        return .idle
    }

    func reset() {
        previousFrame = nil
        motionHistory.removeAll()
        lastThrowTime = nil
    }
}
