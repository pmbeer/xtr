import Foundation

public protocol PredictionModel: AnyObject {
    var kind: ModelKind { get }
    /// Возвращает score для каждого числа 1…20,25. Не обязан быть нормализован.
    func score(history: [Int], features: PlayerFeatures) -> [Int: Double]
    func learn(previous: [Int], actual: Int, features: PlayerFeatures, wasInTop4: Bool)
    func exportState() -> Data
    func importState(_ data: Data)
}

public enum ScoreNormalizer {
    /// Нормализует scores → вероятности, сумма = 1.
    static func probabilities(from scores: [Int: Double]) -> [Int: Double] {
        var clipped: [Int: Double] = [:]
        for (k, v) in scores where DartNumber.parse(k) != nil {
            clipped[k] = max(0, v)
        }
        let sum = clipped.values.reduce(0, +)
        guard sum > 1e-12 else {
            let uniform = 1.0 / Double(DartNumber.scoringValues.count)
            return Dictionary(uniqueKeysWithValues: DartNumber.scoringValues.map { ($0, uniform) })
        }
        return clipped.mapValues { $0 / sum }
    }

    /// ТОП-N с нормализацией только среди top (сумма 100%).
    static func topN(_ probs: [Int: Double], n: Int) -> [(Int, Double)] {
        let sorted = probs.sorted { $0.value > $1.value }
        let top = Array(sorted.prefix(n))
        let sum = top.map(\.value).reduce(0, +)
        guard sum > 1e-12 else {
            return top.map { ($0.key, 1.0 / Double(max(1, top.count))) }
        }
        return top.map { ($0.key, $0.value / sum) }
    }
}
