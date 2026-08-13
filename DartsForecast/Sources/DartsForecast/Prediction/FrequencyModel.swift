import Foundation

/// Модель B — горячие/холодные числа, частота, recency, conditional после предыдущего.
final class FrequencyModel: PredictionModel {
    let kind: ModelKind = .frequency

    private struct State: Codable {
        var counts: [Int: Int] = [:]
        var lastSeenIndex: [Int: Int] = [:]
        var afterPrev: [Int: [Int: Int]] = [:]
        var total: Int = 0
    }

    private var state = State()

    func score(history: [Int], features: PlayerFeatures) -> [Int: Double] {
        var scores: [Int: Double] = [:]
        let total = max(1, state.total)
        let last = history.last

        for num in DartNumber.scoringValues {
            let freq = Double(state.counts[num, default: 0]) / Double(total)
            let lastIdx = state.lastSeenIndex[num]
            let gap = lastIdx.map { Double(total - $0) } ?? Double(total)
            // «Горячие» — высокая частота; «холодные» — большой gap (лёгкий бонус к возврату).
            let hot = freq * 2.0
            let coldReturn = min(1.5, gap / 40.0) * 0.4
            var s = 0.1 + hot + coldReturn

            if let last, let cond = state.afterPrev[last] {
                let condTotal = Double(cond.values.reduce(0, +))
                if condTotal > 0 {
                    s += (Double(cond[num, default: 0]) / condTotal) * 1.5
                }
            }
            scores[num] = s
        }
        return scores
    }

    func learn(previous: [Int], actual: Int, features: PlayerFeatures, wasInTop4: Bool) {
        state.total += 1
        state.counts[actual, default: 0] += 1
        state.lastSeenIndex[actual] = state.total
        if let prev = previous.last {
            state.afterPrev[prev, default: [:]][actual, default: 0] += 1
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
