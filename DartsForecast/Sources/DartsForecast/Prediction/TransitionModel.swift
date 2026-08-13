import Foundation

/// Модель C — таблица переходов previous → next.
public final class TransitionModel: PredictionModel {
    let kind: ModelKind = .transition

    private struct State: Codable {
        /// from -> (to -> count)
        var table: [Int: [Int: Int]] = [:]
        /// bigrams: "a,b" -> (to -> count)
        var bigrams: [String: [Int: Int]] = [:]
    }

    private var state = State()

    func score(history: [Int], features: PlayerFeatures) -> [Int: Double] {
        var scores = Dictionary(uniqueKeysWithValues: DartNumber.scoringValues.map { ($0, 0.05) })
        guard let prev = history.last else { return scores }

        if let row = state.table[prev] {
            let total = Double(row.values.reduce(0, +))
            if total > 0 {
                for (to, c) in row {
                    scores[to, default: 0] += Double(c) / total * 2.0
                }
            }
        }

        if history.count >= 2 {
            let a = history[history.count - 2]
            let b = history[history.count - 1]
            let key = "\(a),\(b)"
            if let row = state.bigrams[key] {
                let total = Double(row.values.reduce(0, +))
                if total > 0 {
                    for (to, c) in row {
                        scores[to, default: 0] += Double(c) / total * 1.5
                    }
                }
            }
        }
        return scores
    }

    func learn(previous: [Int], actual: Int, features: PlayerFeatures, wasInTop4: Bool) {
        guard let prev = previous.last else { return }
        state.table[prev, default: [:]][actual, default: 0] += 1
        if previous.count >= 2 {
            let a = previous[previous.count - 2]
            let b = previous[previous.count - 1]
            state.bigrams["\(a),\(b)", default: [:]][actual, default: 0] += 1
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
