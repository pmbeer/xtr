import Foundation

struct ThrowPredictor {
    private(set) var history: [Int] = []
    let minimumSamples = 30
    let minimumEdge = 0.03
    let priorStrength = 20.0
    let simultaneousZScore = 2.92

    mutating func observe(_ value: Int) {
        guard (1...20).contains(value) else { return }
        history.append(value)
        if history.count > 500 {
            history.removeFirst(history.count - 500)
        }
    }

    mutating func reset() {
        history.removeAll(keepingCapacity: true)
    }

    func recommendation() -> Recommendation {
        guard history.count >= minimumSamples else {
            return .collecting
        }

        let candidates = makeCandidates()
        guard let best = candidates.max(by: candidateIsWorse) else {
            return noBet("Не удалось построить варианты.")
        }

        let requiredProbability = best.fairProbability + minimumEdge
        guard best.lowerConfidenceBound > requiredProbability else {
            return noBet(
                "Статистического преимущества нет. Лучший вариант: "
                    + "\(best.label), оценка \(percent(best.posteriorProbability))."
            )
        }

        return Recommendation(
            title: best.label,
            detail: "Оценка \(percent(best.posteriorProbability)); "
                + "нижняя граница \(percent(best.lowerConfidenceBound)); "
                + "база \(percent(best.fairProbability)). Проверьте коэффициент.",
            candidate: best
        )
    }

    private func makeCandidates() -> [BetCandidate] {
        var definitions: [(String, Double, (Int) -> Bool)] = []

        for number in 1...20 {
            definitions.append(("\(number)", 1.0 / 20.0, { $0 == number }))
        }

        definitions += [
            ("НЕЧЁТ", 0.5, { $0.isMultiple(of: 2) == false }),
            ("ЧЁТ", 0.5, { $0.isMultiple(of: 2) }),
            ("1–10", 0.5, { (1...10).contains($0) }),
            ("11–20", 0.5, { (11...20).contains($0) }),
            ("НЕЧЁТ + 1–10", 0.25, { $0 <= 10 && !$0.isMultiple(of: 2) }),
            ("ЧЁТ + 1–10", 0.25, { $0 <= 10 && $0.isMultiple(of: 2) }),
            ("НЕЧЁТ + 11–20", 0.25, { $0 >= 11 && !$0.isMultiple(of: 2) }),
            ("ЧЁТ + 11–20", 0.25, { $0 >= 11 && $0.isMultiple(of: 2) })
        ]

        return definitions.map { label, fairProbability, matches in
            candidate(label, fairProbability: fairProbability, matches: matches)
        }
    }

    private func candidate(
        _ label: String,
        fairProbability: Double,
        matches: (Int) -> Bool
    ) -> BetCandidate {
        let hits = history.lazy.filter(matches).count
        let alpha = Double(hits) + fairProbability * priorStrength
        let beta = Double(history.count - hits) + (1 - fairProbability) * priorStrength
        let posterior = alpha / (alpha + beta)
        let variance = alpha * beta
            / (pow(alpha + beta, 2) * (alpha + beta + 1))
        // Bonferroni-adjusted one-sided normal approximation for 28 candidates.
        let lowerBound = max(0, posterior - simultaneousZScore * sqrt(variance))

        return BetCandidate(
            label: label,
            hits: hits,
            fairProbability: fairProbability,
            posteriorProbability: posterior,
            lowerConfidenceBound: lowerBound
        )
    }

    private func candidateIsWorse(_ lhs: BetCandidate, _ rhs: BetCandidate) -> Bool {
        let lhsEdge = lhs.lowerConfidenceBound - lhs.fairProbability
        let rhsEdge = rhs.lowerConfidenceBound - rhs.fairProbability
        return lhsEdge < rhsEdge
    }

    private func noBet(_ detail: String) -> Recommendation {
        Recommendation(title: "ПРОПУСТИТЬ", detail: detail, candidate: nil)
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(1)))
    }
}
