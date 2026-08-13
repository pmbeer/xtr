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
