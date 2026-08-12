import Foundation

/// Отслеживает появление нового броска по изменению истории «СЕРИЯ».
final class ThrowTracker: ObservableObject {
    @Published private(set) var history: [DartSector] = []
    @Published private(set) var lastThrow: ThrowEvent?
    @Published private(set) var lastParseMs: Double = 0

    private var previousHead: DartSector?
    private let maxHistory = 200

    func update(with sectors: [DartSector], rawTexts: [String], parseMs: Double) {
        lastParseMs = parseMs
        guard !sectors.isEmpty else { return }

        let newHead = sectors[0]

        if let previousHead, previousHead != newHead {
            let event = ThrowEvent(
                sector: newHead,
                detectedAt: Date(),
                rawOCR: rawTexts.first ?? "\(newHead.rawValue)"
            )
            lastThrow = event
            history.insert(newHead, at: 0)
            if history.count > maxHistory {
                history.removeLast(history.count - maxHistory)
            }
        } else if previousHead == nil {
            history = sectors
        }

        previousHead = newHead
    }

    func reset() {
        history = []
        lastThrow = nil
        previousHead = nil
        lastParseMs = 0
    }
}
