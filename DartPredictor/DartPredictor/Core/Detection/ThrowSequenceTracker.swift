import Foundation
import CoreGraphics

/// Отслеживает появление нового результата из OCR-потока и движения игрока
final class ThrowSequenceTracker {
    private var pendingValue: Int?
    private var confirmationCount = 0
    private var lastConfirmed: Int?
    private var lastConfirmedTime: Date?
    private let minConfirmFrames = 2
    private let minIntervalBetweenThrows: TimeInterval = 1.2

    func reset() {
        pendingValue = nil
        confirmationCount = 0
        lastConfirmed = nil
        lastConfirmedTime = nil
    }

    /// Возвращает новый подтверждённый результат, если число стабильно распознано
    func process(detectedNumbers: [DetectedNumber], motionReleased: Bool = false) -> Int? {
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

        if candidate.value == lastConfirmed {
            return nil
        }

        if let lastTime = lastConfirmedTime,
           Date().timeIntervalSince(lastTime) < minIntervalBetweenThrows {
            return nil
        }

        lastConfirmed = candidate.value
        lastConfirmedTime = Date()
        pendingValue = nil
        confirmationCount = 0

        return candidate.value
    }

  /// Выбор числа: приоритет — крайнее левое (обычно последний результат), затем крупный текст
    private func selectBestCandidate(from numbers: [DetectedNumber]) -> DetectedNumber? {
        guard !numbers.isEmpty else { return nil }

        let byLeft = numbers.sorted { $0.boundingBox.origin.x < $1.boundingBox.origin.x }
        if let left = byLeft.first, left.confidence > 0.15 {
            return left
        }

        return numbers.max { a, b in
            let areaA = a.boundingBox.width * a.boundingBox.height
            let areaB = b.boundingBox.width * b.boundingBox.height
            if areaA != areaB { return areaA < areaB }
            return a.confidence < b.confidence
        }
    }
}
