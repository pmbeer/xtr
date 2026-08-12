import CoreVideo
import Foundation
import ImageIO
import Vision

final class FrameAnalyzer {
    private static let trackedJoints: [VNHumanBodyPoseObservation.JointName] = [
        .nose,
        .neck,
        .leftShoulder,
        .rightShoulder,
        .leftElbow,
        .rightElbow,
        .leftWrist,
        .rightWrist
    ]

    private let queue = DispatchQueue(label: "darts.vision", qos: .userInteractive)
    private let lock = NSLock()
    private var processing = false
    private var previousPose: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]

    func analyze(
        pixelBuffer: CVPixelBuffer,
        region: CaptureRegion,
        behaviorRegion: CaptureRegion,
        completion: @escaping (OCRSnapshot) -> Void
    ) {
        lock.lock()
        guard !processing else {
            lock.unlock()
            return
        }
        processing = true
        lock.unlock()

        queue.async { [weak self] in
            guard let self else { return }
            let started = ContinuousClock.now
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .fast
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-US"]
            request.minimumTextHeight = 0.018
            request.regionOfInterest = region.visionRegion
            let poseRequest = VNDetectHumanBodyPoseRequest()
            poseRequest.regionOfInterest = behaviorRegion.visionRegion

            do {
                try VNImageRequestHandler(
                    cvPixelBuffer: pixelBuffer,
                    orientation: .up,
                    options: [:]
                ).perform([request, poseRequest])

                let observations = self.readingOrder(request.results ?? [])
                let strings = observations.compactMap { $0.topCandidates(1).first?.string }
                let behavior = self.behaviorFeatures(from: poseRequest.results?.first)
                let elapsed = started.duration(to: .now)
                let milliseconds = Int(
                    elapsed.components.seconds * 1_000
                        + elapsed.components.attoseconds / 1_000_000_000_000_000
                )
                completion(
                    OCRSnapshot(
                        values: self.extractValues(from: strings),
                        rawText: strings.joined(separator: " · "),
                        latencyMilliseconds: milliseconds,
                        behaviorFeatures: behavior.features,
                        behaviorConfidence: behavior.confidence
                    )
                )
            } catch {
                completion(
                    OCRSnapshot(
                        values: [],
                        rawText: "Ошибка Vision: \(error.localizedDescription)",
                        latencyMilliseconds: 0,
                        behaviorFeatures: Array(repeating: 0, count: 40),
                        behaviorConfidence: 0
                    )
                )
            }

            self.lock.lock()
            self.processing = false
            self.lock.unlock()
        }
    }

    func resetBehavior() {
        queue.async { [weak self] in
            self?.previousPose = [:]
        }
    }

    private func extractValues(from strings: [String]) -> [Int] {
        let pattern = try? NSRegularExpression(pattern: #"(?<!\d)(?:[1-9]|1\d|20)(?!\d)"#)
        guard let pattern else { return [] }

        return strings.flatMap { text -> [Int] in
            let range = NSRange(text.startIndex..., in: text)
            return pattern.matches(in: text, range: range).compactMap { match in
                guard let swiftRange = Range(match.range, in: text) else { return nil }
                return Int(text[swiftRange])
            }
        }
    }

    private func readingOrder(
        _ observations: [VNRecognizedTextObservation]
    ) -> [VNRecognizedTextObservation] {
        let byVerticalPosition = observations.sorted {
            $0.boundingBox.midY > $1.boundingBox.midY
        }
        var rows: [[VNRecognizedTextObservation]] = []

        for observation in byVerticalPosition {
            if let index = rows.firstIndex(where: { row in
                guard let anchor = row.first else { return false }
                return abs(anchor.boundingBox.midY - observation.boundingBox.midY) < 0.025
            }) {
                rows[index].append(observation)
            } else {
                rows.append([observation])
            }
        }

        return rows.flatMap { row in
            row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
        }
    }

    private func behaviorFeatures(
        from observation: VNHumanBodyPoseObservation?
    ) -> (features: [Double], confidence: Double) {
        guard let observation else {
            previousPose = [:]
            return (Array(repeating: 0, count: 40), 0)
        }

        var features: [Double] = []
        var currentPose: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        var confidenceSum = 0.0

        for joint in Self.trackedJoints {
            guard let point = try? observation.recognizedPoint(joint),
                  point.confidence >= 0.2 else {
                features.append(contentsOf: [0, 0, 0, 0, 0])
                continue
            }

            let previous = previousPose[joint] ?? point.location
            features.append(contentsOf: [
                Double(point.location.x),
                Double(point.location.y),
                Double(point.confidence),
                Double(point.location.x - previous.x),
                Double(point.location.y - previous.y)
            ])
            currentPose[joint] = point.location
            confidenceSum += Double(point.confidence)
        }

        previousPose = currentPose
        return (
            features,
            confidenceSum / Double(Self.trackedJoints.count)
        )
    }
}
