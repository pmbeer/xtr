import Foundation

/// Стратегия прогнозирования следующего броска.
enum PredictionStrategy: String, CaseIterable, Identifiable, Codable {
    case adaptiveLearning
    case ensemble
    case markov
    case contrarian
    case hotCold
    case parityBias

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .adaptiveLearning: return "Адаптивное обучение (99% цель)"
        case .ensemble: return "Ансамбль"
        case .markov: return "Марковская цепь"
        case .contrarian: return "Контртренд"
        case .hotCold: return "Горячие/холодные"
        case .parityBias: return "Чёт/нечёт"
        }
    }
}

/// Движок прогнозов на основе истории бросков.
@MainActor
final class PredictionEngine {
    static let shared = PredictionEngine()

    private init() {}

    func recommend(
        history: [DartSector],
        behavior: PlayerBehaviorSnapshot = PlayerBehaviorSnapshot(),
        strategy: PredictionStrategy = .adaptiveLearning
    ) -> BetRecommendation {
        guard history.count >= 3 else {
            return BetRecommendation(
                betType: .odd,
                number: nil,
                confidence: 0.35,
                reason: "Мало данных — ставка по умолчанию",
                strategy: strategy.displayName
            )
        }

        let baseCandidates = allBaseCandidates(history: history)

        switch strategy {
        case .adaptiveLearning:
            return LearningEngine.shared.adaptiveRecommend(
                history: history,
                behavior: behavior,
                baseCandidates: baseCandidates
            )
        case .ensemble:
            return ensembleRecommendation(history: history)
        case .markov:
            return markovRecommendation(history: history)
        case .contrarian:
            return contrarianRecommendation(history: history)
        case .hotCold:
            return hotColdRecommendation(history: history)
        case .parityBias:
            return parityBiasRecommendation(history: history)
        }
    }

    func allBaseCandidates(history: [DartSector]) -> [BetRecommendation] {
        [
            markovRecommendation(history: history),
            contrarianRecommendation(history: history),
            hotColdRecommendation(history: history),
            parityBiasRecommendation(history: history),
            ensembleRecommendation(history: history)
        ]
    }

    // MARK: - Ensemble

    private func ensembleRecommendation(history: [DartSector]) -> BetRecommendation {
        let candidates = [
            markovRecommendation(history: history),
            contrarianRecommendation(history: history),
            hotColdRecommendation(history: history),
            parityBiasRecommendation(history: history)
        ]

        var scores: [String: (BetRecommendation, Double)] = [:]

        for rec in candidates {
            let key = "\(rec.betType.rawValue)-\(rec.number ?? -1)"
            if var existing = scores[key] {
                existing.1 += rec.confidence
                scores[key] = existing
            } else {
                scores[key] = (rec, rec.confidence)
            }
        }

        guard let best = scores.max(by: { $0.value.1 < $1.value.1 })?.value else {
            return parityBiasRecommendation(history: history)
        }

        let totalVotes = Double(candidates.count)
        let normalizedConfidence = min(0.92, best.1 / totalVotes + 0.15)

        return BetRecommendation(
            betType: best.0.betType,
            number: best.0.number,
            confidence: normalizedConfidence,
            reason: "Согласованный прогноз: \(best.0.reason)",
            strategy: PredictionStrategy.ensemble.displayName
        )
    }

    // MARK: - Markov

    private func markovRecommendation(history: [DartSector]) -> BetRecommendation {
        let order = min(2, history.count - 1)
        let context = Array(history.prefix(order))
        var transitions: [DartSector: Int] = [:]

        for i in 0..<(history.count - order) {
            let slice = Array(history[i..<(i + order)])
            if slice == context {
                let next = history[i + order]
                transitions[next, default: 0] += 1
            }
        }

        if transitions.isEmpty {
            return hotColdRecommendation(history: history)
        }

        let total = Double(transitions.values.reduce(0, +))
        guard let best = transitions.max(by: { $0.value < $1.value }) else {
            return hotColdRecommendation(history: history)
        }

        let confidence = Double(best.value) / total
        let sector = best.key

        if confidence >= 0.25, sector != .bullseye {
            return BetRecommendation(
                betType: .number,
                number: sector.rawValue,
                confidence: min(0.75, confidence + 0.1),
                reason: "После \(contextDescription(context)) чаще выпадало \(sector)",
                strategy: PredictionStrategy.markov.displayName
            )
        }

        return sectorGroupRecommendation(for: sector, confidence: confidence, reasonPrefix: "Марковский переход")
    }

    // MARK: - Contrarian

    private func contrarianRecommendation(history: [DartSector]) -> BetRecommendation {
        let recent = Array(history.prefix(5))
        var counts: [DartSector: Int] = [:]
        for s in recent { counts[s, default: 0] += 1 }

        guard let hot = counts.max(by: { $0.value < $1.value })?.key else {
            return parityBiasRecommendation(history: history)
        }

        let coldNumbers = DartSector.allCases.filter { counts[$0, default: 0] == 0 && $0 != .bullseye }
        if let cold = coldNumbers.randomElement() {
            return BetRecommendation(
                betType: .number,
                number: cold.rawValue,
                confidence: 0.55,
                reason: "\(hot) выпадало \(counts[hot]!)× подряд — ставим на холодное \(cold)",
                strategy: PredictionStrategy.contrarian.displayName
            )
        }

        let oppositeParity: BetType = hot.isEven ? .odd : .even
        return BetRecommendation(
            betType: oppositeParity,
            number: nil,
            confidence: 0.5,
            reason: "Серия \(hot.isEven ? "чётных" : "нечётных") — контрставка",
            strategy: PredictionStrategy.contrarian.displayName
        )
    }

    // MARK: - Hot/Cold

    private func hotColdRecommendation(history: [DartSector]) -> BetRecommendation {
        let window = Array(history.prefix(30))
        var counts: [Int: Int] = [:]
        for s in window where s != .bullseye {
            counts[s.rawValue, default: 0] += 1
        }

        let expected = Double(window.filter { $0 != .bullseye }.count) / 20.0
        let cold = counts
            .filter { Double($0.value) < expected * 0.6 }
            .map(\.key)
            .sorted()

        if let number = cold.first {
            return BetRecommendation(
                betType: .number,
                number: number,
                confidence: 0.58,
                reason: "Число \(number) редко в последних \(window.count) бросках",
                strategy: PredictionStrategy.hotCold.displayName
            )
        }

        return parityBiasRecommendation(history: history)
    }

    // MARK: - Parity bias

    private func parityBiasRecommendation(history: [DartSector]) -> BetRecommendation {
        let recent = Array(history.prefix(12)).filter { $0 != .bullseye }
        let evenCount = recent.filter(\.isEven).count
        let oddCount = recent.count - evenCount

        if evenCount >= oddCount + 3 {
            return BetRecommendation(
                betType: .odd,
                number: nil,
                confidence: 0.52,
                reason: "Перекос в чётные (\(evenCount)/\(recent.count))",
                strategy: PredictionStrategy.parityBias.displayName
            )
        }

        if oddCount >= evenCount + 3 {
            return BetRecommendation(
                betType: .even,
                number: nil,
                confidence: 0.52,
                reason: "Перекос в нечётные (\(oddCount)/\(recent.count))",
                strategy: PredictionStrategy.parityBias.displayName
            )
        }

        let lowCount = recent.filter(\.isLow).count
        let highCount = recent.filter(\.isHigh).count

        if lowCount >= highCount + 3 {
            return BetRecommendation(
                betType: .high,
                number: nil,
                confidence: 0.51,
                reason: "Перекос в 1–10 (\(lowCount)/\(recent.count))",
                strategy: PredictionStrategy.parityBias.displayName
            )
        }

        if highCount >= lowCount + 3 {
            return BetRecommendation(
                betType: .low,
                number: nil,
                confidence: 0.51,
                reason: "Перекос в 11–20 (\(highCount)/\(recent.count))",
                strategy: PredictionStrategy.parityBias.displayName
            )
        }

        return BetRecommendation(
            betType: .odd,
            number: nil,
            confidence: 0.4,
            reason: "Равномерное распределение — нейтральная ставка",
            strategy: PredictionStrategy.parityBias.displayName
        )
    }

    // MARK: - Helpers

    private func sectorGroupRecommendation(
        for sector: DartSector,
        confidence: Double,
        reasonPrefix: String
    ) -> BetRecommendation {
        if sector == .bullseye {
            return BetRecommendation(
                betType: .bullseye,
                number: nil,
                confidence: min(0.6, confidence),
                reason: "\(reasonPrefix) → булл",
                strategy: PredictionStrategy.markov.displayName
            )
        }

        let bet: BetType
        if sector.isEven { bet = .even }
        else if sector.isOdd { bet = .odd }
        else if sector.isLow { bet = .low }
        else { bet = .high }

        return BetRecommendation(
            betType: bet,
            number: nil,
            confidence: min(0.65, confidence + 0.05),
            reason: "\(reasonPrefix) → \(bet.displayName)",
            strategy: PredictionStrategy.markov.displayName
        )
    }

    private func contextDescription(_ context: [DartSector]) -> String {
        context.map(\.description).joined(separator: ", ")
    }
}
