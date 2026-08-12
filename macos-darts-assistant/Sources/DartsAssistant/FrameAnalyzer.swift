import CoreVideo
import Foundation
import ImageIO
import Vision

final class FrameAnalyzer {
    private let queue = DispatchQueue(label: "darts.vision", qos: .userInteractive)
    private let lock = NSLock()
    private var processing = false

    func analyze(
        pixelBuffer: CVPixelBuffer,
        region: CaptureRegion,
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

            do {
                try VNImageRequestHandler(
                    cvPixelBuffer: pixelBuffer,
                    orientation: .up,
                    options: [:]
                ).perform([request])

                let observations = (request.results ?? []).sorted { lhs, rhs in
                    let verticalDifference = lhs.boundingBox.midY - rhs.boundingBox.midY
                    if abs(verticalDifference) > 0.025 {
                        return verticalDifference > 0
                    }
                    return lhs.boundingBox.minX < rhs.boundingBox.minX
                }
                let strings = observations.compactMap { $0.topCandidates(1).first?.string }
                let elapsed = started.duration(to: .now)
                let milliseconds = Int(
                    elapsed.components.seconds * 1_000
                        + elapsed.components.attoseconds / 1_000_000_000_000_000
                )
                completion(
                    OCRSnapshot(
                        values: self.extractValues(from: strings),
                        rawText: strings.joined(separator: " · "),
                        latencyMilliseconds: milliseconds
                    )
                )
            } catch {
                completion(
                    OCRSnapshot(
                        values: [],
                        rawText: "Ошибка Vision: \(error.localizedDescription)",
                        latencyMilliseconds: 0
                    )
                )
            }

            self.lock.lock()
            self.processing = false
            self.lock.unlock()
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
}
