import Foundation

/// Подтверждение нового броска: изменение → стабильность N кадров → событие.
public actor ThrowDetector {
    private var lastConfirmed: Int?
    private var candidate: Int?
    private var stableCount = 0
    private var lastConfirmTime: Date = .distantPast
    private let requiredStable: Int
    private let minGap: TimeInterval

    init(
        requiredStable: Int = HardwareProfile.ocrConfirmFrames,
        minGap: TimeInterval = HardwareProfile.minThrowGap
    ) {
        self.requiredStable = requiredStable
        self.minGap = minGap
    }

    struct Event: Sendable {
        let number: Int
        let confirmedAt: Date
    }

    /// Возвращает Event только при подтверждённом новом броске.
    func ingest(_ reading: OCRReading) -> Event? {
        guard let num = reading.number?.rawValue else {
            // Шум OCR — не сбрасываем кандидата сразу.
            return nil
        }

        // Фильтр: допустимое число уже проверено DartNumber.parse.
        if num == lastConfirmed {
            candidate = nil
            stableCount = 0
            return nil
        }

        if candidate == num {
            stableCount += 1
        } else {
            candidate = num
            stableCount = 1
        }

        guard stableCount >= requiredStable else { return nil }
        let now = Date()
        guard now.timeIntervalSince(lastConfirmTime) >= minGap else { return nil }

        lastConfirmed = num
        lastConfirmTime = now
        candidate = nil
        stableCount = 0
        return Event(number: num, confirmedAt: now)
    }

    func reset() {
        lastConfirmed = nil
        candidate = nil
        stableCount = 0
        lastConfirmTime = .distantPast
    }

    func seed(last: Int?) {
        lastConfirmed = last
    }
}
