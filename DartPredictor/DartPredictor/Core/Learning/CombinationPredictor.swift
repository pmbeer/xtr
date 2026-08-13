import Foundation

/// Формирует оптимальную комбинацию 4 чисел с совместной вероятностью
final class CombinationPredictor {
    static let shared = CombinationPredictor()

    func buildCombination(from predictions: [TopPrediction]) -> PredictedCombination {
        let numbers = predictions.map(\.number)
        let probs = predictions.map(\.probability)

        guard !numbers.isEmpty else {
            return PredictedCombination(
                numbers: [], individualProbabilities: [],
                jointProbability: 0, combinationScore: 0
            )
        }

        // Совместная вероятность: хотя бы одно число из комбинации выпадет
        // P(at least one) = 1 - Π(1 - p_i/100) для независимых событий
        let missProbs = probs.map { 1.0 - ($0 / 100.0) }
        let jointMiss = missProbs.reduce(1.0, *)
        let jointHit = (1.0 - jointMiss) * 100.0

        let score = probs.enumerated().reduce(0.0) { acc, pair in
            let rankWeight = 1.0 - Double(pair.offset) * 0.15
            return acc + pair.element * rankWeight
        }

        return PredictedCombination(
            numbers: numbers,
            individualProbabilities: probs,
            jointProbability: min(jointHit, 99.9),
            combinationScore: score
        )
    }

    /// Ищет комбинацию 4 чисел с максимальной совместной вероятностью и синергией с историей
    func findBestWinningCombination(
        scores: [Int: Double],
        history: [Int],
        fallback: [TopPrediction]
    ) -> PredictedCombination {
        let ranked = scores.sorted { $0.value > $1.value }.map(\.key)
        guard ranked.count >= 4 else {
            return buildCombination(from: fallback)
        }

        let pool = Array(ranked.prefix(14))
        var best: PredictedCombination?
        var bestScore = -1.0

        let combos = combinations(of: pool, size: 4)
        for combo in combos {
            let comboScores = combo.map { scores[$0] ?? 0 }
            let total = comboScores.reduce(0, +)
            let probs = total > 0 ? comboScores.map { $0 / total * 100 } : comboScores
            let preds = zip(combo, probs).map { TopPrediction(number: $0, probability: $1) }
            let built = buildCombination(from: preds)
            let synergy = historySynergy(numbers: combo, history: history)
            let score = built.combinationScore + synergy * 12 + built.jointProbability * 0.15
            if score > bestScore {
                bestScore = score
                best = built
            }
        }

        return best ?? buildCombination(from: fallback)
    }

    private func historySynergy(numbers: [Int], history: [Int]) -> Double {
        guard history.count >= 2 else { return 0 }
        let followUp = ThrowHistoryMerger.followUpScores(from: history, depth: 8)
        let synergy = numbers.reduce(0.0) { $0 + (followUp[$1] ?? 0) }
        return synergy / Double(numbers.count)
    }

    private func combinations(of items: [Int], size: Int) -> [[Int]] {
        guard size > 0, items.count >= size else { return [] }
        if size == 1 { return items.map { [$0] } }

        var result: [[Int]] = []
        for i in 0...(items.count - size) {
            let head = items[i]
            let tailCombos = combinations(of: Array(items[(i + 1)...]), size: size - 1)
            for tail in tailCombos {
                result.append([head] + tail)
            }
        }
        return result
    }

    func buildAlternativeCombinations(
        scores: [Int: Double],
        count: Int = 3
    ) -> [PredictedCombination] {
        let sorted = scores.sorted { $0.value > $1.value }.map(\.key)
        guard sorted.count >= 4 else { return [] }

        var combinations: [PredictedCombination] = []
        let top = Array(sorted.prefix(8))

        for i in 0..<min(count, top.count - 3) {
            let quad = Array(top[i..<i+4])
            let quadScores = quad.map { scores[$0] ?? 0 }
            let total = quadScores.reduce(0, +)
            let probs = total > 0 ? quadScores.map { $0 / total * 100 } : quadScores
            let preds = zip(quad, probs).map { TopPrediction(number: $0, probability: $1) }
            combinations.append(buildCombination(from: preds))
        }
        return combinations
    }
}
