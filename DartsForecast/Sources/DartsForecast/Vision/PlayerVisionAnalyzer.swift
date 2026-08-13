import Foundation
import Vision
import CoreGraphics

/// Анализ последовательности кадров игрока (уменьшенное разрешение).
public actor PlayerVisionAnalyzer {
    private var samples: [PlayerFrameSample] = []
    private var lastThrowTime: Date?
    private var prepStart: Date?
    private var lastFeatures = PlayerFeatures.empty
    private var processing = false

    func noteThrow(at date: Date) {
        lastThrowTime = date
        prepStart = nil
    }

    func currentFeatures() -> PlayerFeatures {
        lastFeatures
    }

    func ingest(image: CGImage) async -> PlayerFeatures {
        if processing { return lastFeatures }
        processing = true
        defer { processing = false }

        let motion = await motionEnergy(image)
        let pose = await detectPose(image)
        let sample = PlayerFrameSample(
            timestamp: Date(),
            motionEnergy: motion,
            centroidY: pose.centroidY,
            centroidX: pose.centroidX,
            bodyDetected: pose.bodyDetected
        )
        samples.append(sample)
        if samples.count > 45 { samples.removeFirst(samples.count - 45) }

        var features = PlayerFeatures()
        features.bodyDetected = pose.bodyDetected
        features.torsoLean = pose.lean
        features.shoulderAngle = pose.shoulder
        features.armRaise = pose.armRaise
        features.armDirection = pose.armDirection

        if samples.count >= 3 {
            let recent = samples.suffix(8)
            let energies = recent.map(\.motionEnergy)
            let maxE = energies.max() ?? 0
            let meanE = energies.reduce(0, +) / Double(energies.count)
            features.motionSpeed = min(1, meanE * 4)
            features.swingAmplitude = min(1, maxE * 3)

            let xs = recent.map(\.centroidX)
            if let first = xs.first, let last = xs.last {
                features.armDirection = max(-1, min(1, (last - first) * 4))
            }
        }

        // Фаза броска по энергии движения
        if features.motionSpeed < 0.12 {
            features.throwPhase = 0
            if prepStart == nil { prepStart = Date() }
        } else if features.armRaise > 0.55 && features.motionSpeed < 0.35 {
            features.throwPhase = 1
        } else if features.swingAmplitude > 0.4 && features.motionSpeed > 0.35 {
            features.throwPhase = 2
        } else if features.motionSpeed > 0.55 {
            features.throwPhase = 3
        }

        if let last = lastThrowTime {
            features.intervalSeconds = Date().timeIntervalSince(last)
        }
        if let prep = prepStart {
            features.prepDuration = Date().timeIntervalSince(prep)
        }

        features.recomputeKey()
        lastFeatures = features
        return features
    }

    private struct PoseLite {
        var bodyDetected: Bool
        var lean: Double
        var shoulder: Double
        var armRaise: Double
        var armDirection: Double
        var centroidX: Double
        var centroidY: Double
    }

    private func detectPose(_ image: CGImage) async -> PoseLite {
        // VNDetectHumanBodyPoseRequest — доступен на Intel без GPU-моделей.
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            DebugLog.warn("Vision pose error: \(error)")
            return PoseLite(bodyDetected: false, lean: 0, shoulder: 0, armRaise: 0, armDirection: 0, centroidX: 0.5, centroidY: 0.5)
        }

        guard let obs = request.results?.first else {
            return PoseLite(bodyDetected: false, lean: 0, shoulder: 0, armRaise: 0, armDirection: 0, centroidX: 0.5, centroidY: 0.5)
        }

        func pt(_ joint: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
            guard let p = try? obs.recognizedPoint(joint), p.confidence > 0.2 else { return nil }
            return p.location
        }

        let ls = pt(.leftShoulder)
        let rs = pt(.rightShoulder)
        let lh = pt(.leftHip)
        let rh = pt(.rightHip)
        let lw = pt(.leftWrist)
        let rw = pt(.rightWrist)

        var lean: Double = 0
        if let ls, let rs, let lh, let rh {
            let shoulderMidX = (ls.x + rs.x) / 2
            let hipMidX = (lh.x + rh.x) / 2
            lean = Double(shoulderMidX - hipMidX) * 4
        }

        var shoulder: Double = 0
        if let ls, let rs {
            shoulder = Double(rs.y - ls.y) * 4
        }

        var armRaise: Double = 0
        if let ls, let lw {
            armRaise = max(armRaise, Double(lw.y - ls.y) + 0.5)
        }
        if let rs, let rw {
            armRaise = max(armRaise, Double(rw.y - rs.y) + 0.5)
        }
        armRaise = max(0, min(1, armRaise))

        let cx = Double((ls?.x ?? rs?.x ?? 0.5))
        let cy = Double((ls?.y ?? rs?.y ?? 0.5))

        return PoseLite(
            bodyDetected: true,
            lean: max(-1, min(1, lean)),
            shoulder: max(-1, min(1, shoulder)),
            armRaise: armRaise,
            armDirection: 0,
            centroidX: cx,
            centroidY: cy
        )
    }

    private func motionEnergy(_ image: CGImage) async -> Double {
        // Простая энергия: среднее абсолютное отклонение grayscale luma (через downsample).
        let w = min(64, image.width)
        let h = max(1, Int(Double(image.height) * Double(w) / Double(image.width)))
        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return 0 }
        ctx.interpolationQuality = .low
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data else { return 0 }
        let buf = data.bindMemory(to: UInt8.self, capacity: w * h)
        var sum: Double = 0
        let count = w * h
        var i = 0
        while i < count {
            sum += Double(buf[i])
            i += 1
        }
        let mean = sum / Double(count)
        var varSum: Double = 0
        i = 0
        while i < count {
            let d = Double(buf[i]) - mean
            varSum += abs(d)
            i += 4 // subsample
        }
        return min(1.0, (varSum / Double(max(1, count / 4))) / 80.0)
    }
}
