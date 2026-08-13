import Combine
import Foundation

/// Совместимость: история бросков делегирует ResultConfirmationEngine.
final class ThrowTracker: ObservableObject {
    let engine = ResultConfirmationEngine()
    private var cancellables = Set<AnyCancellable>()

    var history: [DartSector] { engine.history }
    var lastThrow: ThrowEvent? { engine.lastConfirmedThrow }
    var lastParseMs: Double = 0

    init() {
        engine.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func update(with sectors: [DartSector], rawTexts: [String], parseMs: Double) -> ThrowEvent? {
        lastParseMs = parseMs
        return engine.processOCR(sectors: sectors, rawTexts: rawTexts)
    }

    func reset() {
        engine.reset()
        lastParseMs = 0
    }
}
