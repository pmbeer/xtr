import Foundation

/// Прогноз 4 секторов — цель: 99% что один из них выпадет.
@MainActor
enum MultiPickPredictor {
    static let pickCount = 4

    static func recommend(
        history: [DartSector],
        behavior: PlayerBehaviorSnapshot,
        strategy: PredictionStrategy = .adaptiveLearning
    ) -> BetRecommendation {
        guard history.count >= 2 else {
            return BetRecommendation(
                betType: .number,
                number: history.first?.rawValue,
                predictedNumbers: fallbackNumbers(from: history),
                confidence: 0.35,
                reason: "Мало данных — 4 сектора по истории",
                strategy: strategy.displayName
            )
        }

        switch strategy {
        case .adaptiveLearning:
            return LearningEngine.shared.adaptiveRecommendMultiPick(
                history: history,
                behavior: behavior,
                baseCandidates: PredictionEngine.shared.allBaseCandidates(history: history)
            )
        default:
            let single = PredictionEngine.shared.recommend(
                history: history,
                behavior: behavior,
                strategy: strategy
            )
            return expandToMultiPick(single, history: history, behavior: behavior)
        }
    }

    private static func expandToMultiPick(
        _ primary: BetRecommendation,
        history: [DartSector],
        behavior: PlayerBehaviorSnapshot
    ) -> BetRecommendation {
        let features = PredictionFeatures.build(
            history: history,
            behavior: behavior,
            strategyVotes: [:]
        )
        let probs = SectorProbabilityModel.shared.probabilities(
            contextKey: features.contextKey,
            behaviorKey: features.behaviorKey
        )

        var scores: [Int: Double] = [:]
        for n in 1...20 {
            scores[n] = probs[n] ?? 0.05
        }
        if let n = primary.number {
            scores[n, default: 0] += primary.confidence * 2
        }

        let picks = topNumbers(from: scores, count: pickCount)
        let confidence = setConfidence(numbers: picks, scores: scores)

        return BetRecommendation(
            betType: .number,
            number: picks.first,
            predictedNumbers: picks,
            confidence: confidence,
            reason: "4 сектора: \(picks.map(String.init).joined(separator: ", "))",
            strategy: primary.strategy
        )
    }

    static func topNumbers(from scores: [Int: Double], count: Int) -> [Int] {
        let sorted = scores
            .filter { (1...20).contains($0.key) }
            .sorted { $0.value > $1.value }

        var picks: [Int] = []
        for (num, _) in sorted {
            if picks.contains(num) { continue }
            picks.append(num)
            if picks.count >= count { break }
        }

        while picks.count < count {
            let filler = (1...20).first { !picks.contains($0) } ?? 1
            picks.append(filler)
        }
        return picks
    }

    static func setConfidence(numbers: [Int], scores: [Int: Double]) -> Double {
        guard !numbers.isEmpty else { return 0.35 }
        let missProb = numbers.reduce(1.0) { acc, n in
            let p = min(0.45, max(0.04, scores[n] ?? 0.05))
            return acc * (1.0 - p)
        }
        return min(0.96, max(0.35, 1.0 - missProb))
    }

    private static func fallbackNumbers(from history: [DartSector]) -> [Int] {
        var nums: [Int] = []
        for s in history where s != .bullseye {
            if !nums.contains(s.rawValue) { nums.append(s.rawValue) }
            if nums.count >= pickCount { break }
        }
        while nums.count < pickCount {
            let n = (1...20).first { !nums.contains($0) } ?? 7
            nums.append(n)
        }
        return nums
    }
}
