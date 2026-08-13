import Foundation
import CoreGraphics

/// Отслеживает новый результат только из красной зоны (история бросков)
final class ThrowSequenceTracker {
    private var pendingValue: Int?
    private var confirmationCount = 0
    private var lastConfirmed: Int?
    private var lastConfirmedTime: Date?
    private var historySignature: [Int] = []
    private let minConfirmFrames = 2
    private let minIntervalBetweenThrows: TimeInterval = 1.0

    func reset() {
        pendingValue = nil
        confirmationCount = 0
        lastConfirmed = nil
        lastConfirmedTime = nil
        historySignature = []
    }

    func process(
        historyStrip: [Int],
        detectedNumbers: [DetectedNumber],
        motionReleased: Bool = false
    ) -> Int? {
        if let newFromHistory = detectNewFromHistory(historyStrip) {
            return registerConfirmed(newFromHistory)
        }

        guard let candidate = selectBestCandidate(from: detectedNumbers) else {
            return nil
        }

        let requiredFrames = motionReleased ? 1 : minConfirmFrames

        if candidate.value == pendingValue {
            confirmationCount += 1
        } else {
            pendingValue = candidate.value
            confirmationCount = 1
        }

        guard confirmationCount >= requiredFrames else { return nil }

        return registerConfirmed(candidate.value)
    }

    private func registerConfirmed(_ value: Int) -> Int? {
        if value == lastConfirmed { return nil }

        if let lastTime = lastConfirmedTime,
           Date().timeIntervalSince(lastTime) < minIntervalBetweenThrows {
            return nil
        }

        lastConfirmed = value
        lastConfirmedTime = Date()
        pendingValue = nil
        confirmationCount = 0
        historySignature.append(value)

        return value
    }

    private func detectNewFromHistory(_ strip: [Int]) -> Int? {
        guard !strip.isEmpty else {
            historySignature = []
            return nil
        }

        if strip == historySignature { return nil }

        var newValue: Int? = nil
        if strip.count > historySignature.count {
            newValue = strip.last
        } else if let last = strip.last, historySignature.last != last {
            newValue = last
        }

        historySignature = strip
        return newValue
    }

    /// В красной зоне — самый правый результат в истории
    private func selectBestCandidate(from numbers: [DetectedNumber]) -> DetectedNumber? {
        guard !numbers.isEmpty else { return nil }
        return numbers
            .filter { $0.confidence > 0.1 }
            .max { a, b in
                if a.boundingBox.origin.x != b.boundingBox.origin.x {
                    return a.boundingBox.origin.x < b.boundingBox.origin.x
                }
                return a.confidence < b.confidence
            }
    }
}
