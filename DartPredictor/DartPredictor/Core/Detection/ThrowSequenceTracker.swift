import Foundation
import CoreGraphics

/// Отслеживает появление нового результата из OCR-потока и движения игрока
final class ThrowSequenceTracker {
    private var pendingValue: Int?
    private var confirmationCount = 0
    private var lastConfirmed: Int?
    private var lastConfirmedTime: Date?
    private var historySignature: [Int] = []
    private let minConfirmFrames = 2
    private let minIntervalBetweenThrows: TimeInterval = 1.2

    func reset() {
        pendingValue = nil
        confirmationCount = 0
        lastConfirmed = nil
        lastConfirmedTime = nil
        historySignature = []
    }

    /// Возвращает новый подтверждённый результат, если число стабильно распознано
    func process(detectedNumbers: [DetectedNumber], motionReleased: Bool = false) -> Int? {
        let historyNumbers = extractHistoryStrip(from: detectedNumbers)
        if let newFromHistory = detectNewFromHistory(historyNumbers) {
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
        if value == lastConfirmed {
            return nil
        }

        if let lastTime = lastConfirmedTime,
           Date().timeIntervalSince(lastTime) < minIntervalBetweenThrows {
            return nil
        }

        lastConfirmed = value
        lastConfirmedTime = Date()
        pendingValue = nil
        confirmationCount = 0

        return value
    }

    /// История бросков fon.bet — нижняя полоса окна, новый результат справа
    private func extractHistoryStrip(from numbers: [DetectedNumber]) -> [Int] {
        let bottom = numbers.filter { $0.boundingBox.midY < 0.38 }
        let sorted = bottom.sorted { $0.boundingBox.origin.x < $1.boundingBox.origin.x }
        return sorted.map(\.value)
    }

    private func detectNewFromHistory(_ strip: [Int]) -> Int? {
        guard strip.count >= 2 else {
            historySignature = strip
            return nil
        }

        if strip == historySignature {
            return nil
        }

        if strip.count > historySignature.count {
            historySignature = strip
            return strip.last
        }

        if strip.last != historySignature.last {
            historySignature = strip
            return strip.last
        }

        historySignature = strip
        return nil
    }

    private func selectBestCandidate(from numbers: [DetectedNumber]) -> DetectedNumber? {
        guard !numbers.isEmpty else { return nil }

        // Нижняя история (fon.bet) — правый край
        let bottom = numbers.filter { $0.boundingBox.midY < 0.38 }
        if let newest = bottom.max(by: { $0.boundingBox.origin.x < $1.boundingBox.origin.x }),
           newest.confidence > 0.12 {
            return newest
        }

        // Центральная зона — крупный текст
        return numbers.max { a, b in
            let areaA = a.boundingBox.width * a.boundingBox.height
            let areaB = b.boundingBox.width * b.boundingBox.height
            if areaA != areaB { return areaA < areaB }
            return a.confidence < b.confidence
        }
    }
}

private extension CGRect {
    var midY: CGFloat { origin.y + height / 2 }
}
