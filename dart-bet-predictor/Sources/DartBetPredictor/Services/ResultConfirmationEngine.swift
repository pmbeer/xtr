import Foundation

/// Подтверждение результата броска: ждём стабильный OCR после движения игрока.
final class ResultConfirmationEngine: ObservableObject {
    @Published private(set) var history: [DartSector] = []
    @Published private(set) var lastConfirmedThrow: ThrowEvent?
    @Published private(set) var isAwaitingResult = false
    @Published private(set) var pendingSector: DartSector?
    @Published private(set) var stableReadCount: Int = 0

    private var confirmedSnapshot: [DartSector] = []
    private var pendingRawText: String?
    private var awaitingSince: Date?
    private var lastConfirmedAt: Date?
    private let maxHistory = 200

    /// Стабильных чтений OCR для подтверждения.
    private let requiredStableReads = 3
    /// После броска — пауза до появления числа на экране.
    private let minDelayAfterThrowSec: TimeInterval = 0.9
    /// Таймаут ожидания результата.
    private let awaitingTimeoutSec: TimeInterval = 20
    /// Пауза после подтверждения — не реагировать на шум OCR.
    private let cooldownAfterConfirmSec: TimeInterval = 2.5

    func reset() {
        history = []
        lastConfirmedThrow = nil
        confirmedSnapshot = []
        clearAwaiting()
    }

    func markAwaitingResult(reason: String = "throw") {
        guard !isAwaitingResult else { return }
        isAwaitingResult = true
        awaitingSince = Date()
        pendingSector = nil
        pendingRawText = nil
        stableReadCount = 0
        LaunchLogger.log("Awaiting result (\(reason))")
    }

    func clearAwaiting() {
        isAwaitingResult = false
        awaitingSince = nil
        pendingSector = nil
        pendingRawText = nil
        stableReadCount = 0
    }

    /// Обрабатывает OCR. Возвращает событие только при подтверждённом результате.
    func processOCR(sectors: [DartSector], rawTexts: [String]) -> ThrowEvent? {
        guard !sectors.isEmpty else { return nil }

        if confirmedSnapshot.isEmpty {
            confirmedSnapshot = sectors
            history = Array(sectors.prefix(maxHistory))
            return nil
        }

        if let lastConfirmedAt, Date().timeIntervalSince(lastConfirmedAt) < cooldownAfterConfirmSec {
            // В cooldown только обновляем baseline если списки совпали
            if sectors == confirmedSnapshot { return nil }
            return nil
        }

        if isAwaitingResult {
            return processWhileAwaiting(sectors: sectors, rawTexts: rawTexts)
        }

        // Без явного броска — не подтверждаем (избегаем ложных OCR)
        return nil
    }

    private func processWhileAwaiting(sectors: [DartSector], rawTexts: [String]) -> ThrowEvent? {
        if let since = awaitingSince {
            if Date().timeIntervalSince(since) > awaitingTimeoutSec {
                LaunchLogger.log("Awaiting result timeout")
                clearAwaiting()
                return nil
            }
            if Date().timeIntervalSince(since) < minDelayAfterThrowSec {
                return nil
            }
        }

        guard let candidate = detectNewSector(previous: confirmedSnapshot, current: sectors) else {
            return nil
        }

        let raw = rawTextFor(sector: candidate, in: sectors, rawTexts: rawTexts)

        if pendingSector == candidate {
            stableReadCount += 1
        } else {
            pendingSector = candidate
            pendingRawText = raw
            stableReadCount = 1
        }

        if stableReadCount >= requiredStableReads {
            return confirmResult(sector: candidate, raw: raw ?? "\(candidate.rawValue)", sectors: sectors)
        }

        return nil
    }

    private func confirmResult(sector: DartSector, raw: String, sectors: [DartSector]) -> ThrowEvent {
        let event = ThrowEvent(sector: sector, detectedAt: Date(), rawOCR: raw)
        lastConfirmedThrow = event
        lastConfirmedAt = Date()

        if !history.isEmpty && history[0] != sector {
            history.insert(sector, at: 0)
        } else if history.isEmpty {
            history = [sector]
        }
        if history.count > maxHistory {
            history.removeLast(history.count - maxHistory)
        }

        confirmedSnapshot = sectors
        clearAwaiting()

        LaunchLogger.log("Result confirmed: \(sector) stable=\(requiredStableReads) OCR=\(raw)")
        return event
    }

    /// Находит новый результат сравнением списков (не предполагает позицию «нового» кружка).
    static func detectNewSector(previous: [DartSector], current: [DartSector]) -> DartSector? {
        guard !previous.isEmpty, !current.isEmpty else { return nil }

        if current == previous { return nil }

        // Список вырос — новый элемент обычно справа (конец панели СЕРИЯ)
        if current.count > previous.count {
            if current.last != previous.last { return current.last }
            if current[0] != previous[0] { return current[0] }
            // Вставка в середину
            for i in 0..<previous.count {
                if current[i] != previous[i] { return current[i] }
            }
            return current.last
        }

        // Та же длина — одна или несколько позиций изменились
        var changes: [(Int, DartSector)] = []
        for i in 0..<min(current.count, previous.count) {
            if current[i] != previous[i] {
                changes.append((i, current[i]))
            }
        }

        if changes.count == 1 {
            return changes[0].1
        }

        // Несколько изменений — берём правый (новый бросок обычно справа в СЕРИЯ)
        if let rightmost = changes.max(by: { $0.0 < $1.0 }) {
            return rightmost.1
        }

        // Длина уменьшилась — редкий случай, голова изменилась
        if current[0] != previous[0] {
            return current[0]
        }

        return nil
    }

    private func rawTextFor(sector: DartSector, in sectors: [DartSector], rawTexts: [String]) -> String? {
        for (i, s) in sectors.enumerated() where s == sector && i < rawTexts.count {
            return rawTexts[i]
        }
        return rawTexts.first
    }
}
