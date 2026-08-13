import Foundation
import Combine

/// Detects confirmed new throws from OCR stream
final class ThrowDetector: ObservableObject {
    @Published var lastConfirmedThrow: Int?
    @Published var throwSequence: [Int] = []

    private var lastThrowTimestamp: Date?
    private let minIntervalBetweenThrows: TimeInterval = 2.0

    func processOCRResult(_ number: Int?) {
        guard let number else { return }

        let now = Date()
        if let last = lastThrowTimestamp,
           now.timeIntervalSince(last) < minIntervalBetweenThrows {
            return
        }

        if throwSequence.last == number { return }

        lastThrowTimestamp = now
        throwSequence.append(number)
        lastConfirmedThrow = number

        if throwSequence.count > 5000 {
            throwSequence.removeFirst(throwSequence.count - 5000)
        }

        DebugLogger.shared.logThrowDetected(number: number, timeMs: 0)
    }

    func reset() {
        throwSequence = []
        lastConfirmedThrow = nil
        lastThrowTimestamp = nil
    }
}
