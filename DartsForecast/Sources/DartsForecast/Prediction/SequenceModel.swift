import Foundation

/// Модель A — повторяющиеся последовательности (окна 3/5/10/20/50).
public final class SequenceModel: PredictionModel {
    let kind: ModelKind = .sequence

    private struct State: Codable {
        var ngramNext: [String: [Int: Int]] = [:]
    }

    private var state = State()
    private let windows = [3, 5, 10, 20, 50]

    func score(history: [Int], features: PlayerFeatures) -> [Int: Double] {
        var scores = Dictionary(uniqueKeysWithValues: DartNumber.scoringValues.map { ($0, 0.05) })
        for w in windows {
            guard history.count >= w else { continue }
            let key = history.suffix(w).map(String.init).joined(separator: ",")
            if let counts = state.ngramNext[key] {
                let total = Double(counts.values.reduce(0, +))
                let weight = Double(w) / 10.0
                for (num, c) in counts {
                    scores[num, default: 0] += (Double(c) / max(1, total)) * weight
                }
            }
            // Частичное совпадение: суффикс короче
            if w >= 5 {
                let shortKey = history.suffix(max(2, w / 2)).map(String.init).joined(separator: ",")
                if let counts = state.ngramNext[shortKey] {
                    let total = Double(counts.values.reduce(0, +))
                    for (num, c) in counts {
                        scores[num, default: 0] += (Double(c) / max(1, total)) * 0.3
                    }
                }
            }
        }
        return scores
    }

    func learn(previous: [Int], actual: Int, features: PlayerFeatures, wasInTop4: Bool) {
        for w in windows {
            guard previous.count >= w else { continue }
            let key = previous.suffix(w).map(String.init).joined(separator: ",")
            state.ngramNext[key, default: [:]][actual, default: 0] += 1
        }
        // Лимит памяти n-грамм
        if state.ngramNext.count > 8000 {
            let keys = Array(state.ngramNext.keys.prefix(2000))
            for k in keys { state.ngramNext.removeValue(forKey: k) }
        }
    }

    func exportState() -> Data {
        (try? JSONEncoder().encode(state)) ?? Data()
    }

    func importState(_ data: Data) {
        if let s = try? JSONDecoder().decode(State.self, from: data) {
            state = s
        }
    }
}
