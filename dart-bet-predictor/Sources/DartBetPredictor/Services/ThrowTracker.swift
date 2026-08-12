import Foundation

/// Отслеживает появление нового броска по изменению истории «СЕРИЯ».
final class ThrowTracker: ObservableObject {
    @Published private(set) var history: [DartSector] = []
    @Published private(set) var lastThrow: ThrowEvent?
    @Published private(set) var lastParseMs: Double = 0

    private var previousSnapshot: [DartSector] = []
    private let maxHistory = 200

    /// Обновляет историю и возвращает событие, если обнаружен новый бросок.
    func update(with sectors: [DartSector], rawTexts: [String], parseMs: Double) -> ThrowEvent? {
        lastParseMs = parseMs
        guard !sectors.isEmpty else { return nil }

        var newEvent: ThrowEvent?

        if previousSnapshot.isEmpty {
            history = Array(sectors.prefix(maxHistory))
            previousSnapshot = sectors
            return nil
        }

        let newHead = sectors[0]

        // Новый элемент в начале списка (история выросла)
        if sectors.count > previousSnapshot.count {
            newEvent = makeEvent(sector: newHead, rawTexts: rawTexts)
        } else if newHead != previousSnapshot[0] {
            // Голова изменилась (тот же размер или перестроение)
            newEvent = makeEvent(sector: newHead, rawTexts: rawTexts)
        } else if sectors.count == previousSnapshot.count {
            // Тот же размер, но содержимое сдвинулось (дубликаты секторов)
            for index in 0..<sectors.count {
                if sectors[index] != previousSnapshot[index] {
                    newEvent = makeEvent(sector: newHead, rawTexts: rawTexts)
                    break
                }
            }
        }

        if let newEvent {
            lastThrow = newEvent
            history.insert(newHead, at: 0)
            if history.count > maxHistory {
                history.removeLast(history.count - maxHistory)
            }
        }

        previousSnapshot = sectors
        return newEvent
    }

    private func makeEvent(sector: DartSector, rawTexts: [String]) -> ThrowEvent {
        ThrowEvent(
            sector: sector,
            detectedAt: Date(),
            rawOCR: rawTexts.first ?? "\(sector.rawValue)"
        )
    }

    func reset() {
        history = []
        lastThrow = nil
        previousSnapshot = []
        lastParseMs = 0
    }
}
