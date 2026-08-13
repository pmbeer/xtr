import Foundation

/// Онлайн-обучение: после каждого броска проверяет прошлый прогноз и корректирует веса.
@MainActor
final class LearningEngine: ObservableObject {
    static let shared = LearningEngine()

    @Published private(set) var stats = LearningStats()
    @Published private(set) var recentOutcomes: [PredictionOutcome] = []
    @Published private(set) var lastLearningMessage = "Обучение не начато"

    private var contextTransitions: [String: [Int: Int]] = [:]
    private var behaviorOutcomes: [String: [Int: Int]] = [:]
    private var sectorScores: [Int: Double] = [:]
    private var pendingPrediction: PendingPrediction?
    private let sectorModel = SectorProbabilityModel.shared

    private let recentWindowSize = 50
    private var baseLearningRate = 0.15
    private let explorationRate = 0.08
    private let storageURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("DartBetPredictor", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("learning_state.json")
        load()
        initializeStrategyWeights()
    }

    // MARK: - Prediction lifecycle

    func setPending(_ prediction: PendingPrediction) {
        pendingPrediction = prediction
    }

    /// Вызывается при новом броске: проверяет прошлый прогноз и обучается.
    @discardableResult
    func evaluateAndLearn(actual: DartSector, behaviorDuringRound: PlayerBehaviorSnapshot) -> PredictionOutcome? {
        guard let pending = pendingPrediction else { return nil }
        pendingPrediction = nil

        let correct = pending.isCorrect(for: actual)
        let delta = learn(
            pending: pending,
            actual: actual,
            behaviorDuringRound: behaviorDuringRound,
            correct: correct
        )

        let outcome = PredictionOutcome(
            id: pending.id,
            predictedAt: pending.createdAt,
            evaluatedAt: Date(),
            betType: pending.betType,
            predictedNumber: pending.number,
            predictedNumbers: pending.predictedNumbers,
            actualSector: actual.rawValue,
            wasCorrect: correct,
            confidence: pending.confidence,
            behaviorKey: pending.behaviorAtPrediction.behaviorKey,
            learningDelta: delta
        )

        recentOutcomes.insert(outcome, at: 0)
        if recentOutcomes.count > 30 {
            recentOutcomes.removeLast()
        }

        stats.totalPredictions += 1
        if correct { stats.correctPredictions += 1 }

        stats.recentWindow.insert(correct, at: 0)
        if stats.recentWindow.count > recentWindowSize {
            stats.recentWindow.removeLast()
        }

        updateStreak(correct: correct)
        stats.learningIterations += 1
        adaptLearningRate()

        sectorModel.learn(
            actual: actual,
            contextKey: pending.features.contextKey,
            behaviorKey: behaviorDuringRound.behaviorKey,
            predictedBet: pending.betType,
            predictedNumber: pending.number,
            predictedNumbers: pending.predictedNumbers
        )

        lastLearningMessage = correct
            ? "Верно! \(pending.displayBet) → \(actual) · \(stats.recentAccuracyPercent)% → 99%"
            : "Не угадали (\(pending.displayBet) ≠ \(actual)). Учусь… \(stats.recentAccuracyPercent)%"

        save()
        return outcome
    }

    /// Генерирует прогноз с учётом обученных весов и поведения игрока.
    func adaptiveRecommend(
        history: [DartSector],
        behavior: PlayerBehaviorSnapshot,
        baseCandidates: [BetRecommendation]
    ) -> BetRecommendation {
        guard history.count >= 2 else {
            return baseCandidates.first ?? defaultRecommendation()
        }

        let features = PredictionFeatures.build(
            history: history,
            behavior: behavior,
            strategyVotes: strategyVoteMap(from: baseCandidates)
        )

        var scored: [String: (BetRecommendation, Double)] = [:]

        for candidate in baseCandidates {
            let strategyWeight = stats.strategyWeights[candidate.strategy] ?? 1.0
            let key = betKey(candidate)
            let score = candidate.confidence * strategyWeight
            if let existing = scored[key] {
                scored[key] = (existing.0, existing.1 + score)
            } else {
                scored[key] = (candidate, score)
            }
        }

        let contextBonus = contextBonusRecommendation(features: features, history: history)
        if let ctx = contextBonus {
            let key = betKey(ctx)
            let learnedBoost = contextConfidence(for: features.contextKey, bet: ctx)
            if var existing = scored[key] {
                existing.1 += ctx.confidence * learnedBoost * 2.0
                scored[key] = existing
            } else {
                scored[key] = (ctx, ctx.confidence * learnedBoost * 2.0)
            }
        }

        let behaviorBonus = behaviorBonusRecommendation(features: features)
        if let beh = behaviorBonus {
            let key = betKey(beh)
            let learnedBoost = behaviorConfidence(for: features.behaviorKey, bet: beh)
            if var existing = scored[key] {
                existing.1 += beh.confidence * learnedBoost * 1.5
                scored[key] = existing
            } else {
                scored[key] = (beh, beh.confidence * learnedBoost * 1.5)
            }
        }

        let sectorBet = sectorModelRecommendation(features: features, behavior: behavior)
        if let sec = sectorBet {
            let key = betKey(sec)
            if var existing = scored[key] {
                existing.1 += sec.confidence * 2.5
                scored[key] = existing
            } else {
                scored[key] = (sec, sec.confidence * 2.5)
            }
        }

        let legacySector = sectorScoreRecommendation(history: history, behavior: behavior)
        if let sec = legacySector {
            let key = betKey(sec)
            if var existing = scored[key] {
                existing.1 += sec.confidence * 1.2
                scored[key] = existing
            } else {
                scored[key] = (sec, sec.confidence * 1.2)
            }
        }

        guard let best = scored.max(by: { $0.value.1 < $1.value.1 })?.value else {
            return defaultRecommendation()
        }

        let calibratedConfidence = calibrateConfidence(raw: best.1, features: features)

        var reason = best.0.reason
        if behavior.bodyDetected {
            reason += " · \(behavior.phase.displayName)"
        }
        if stats.totalPredictions > 5 {
            reason += " · обучение \(stats.recentAccuracyPercent)%"
        }

        return BetRecommendation(
            betType: best.0.betType,
            number: best.0.number,
            confidence: calibratedConfidence,
            reason: reason,
            strategy: "Адаптивное обучение"
        )
    }

    /// 4 сектора — максимизируем шанс что один выпадет (цель 99%).
    func adaptiveRecommendMultiPick(
        history: [DartSector],
        behavior: PlayerBehaviorSnapshot,
        baseCandidates: [BetRecommendation]
    ) -> BetRecommendation {
        guard history.count >= 2 else {
            return defaultMultiRecommendation()
        }

        let features = PredictionFeatures.build(
            history: history,
            behavior: behavior,
            strategyVotes: strategyVoteMap(from: baseCandidates)
        )

        let probs = sectorModel.probabilities(
            contextKey: features.contextKey,
            behaviorKey: features.behaviorKey
        )

        var scores: [Int: Double] = [:]
        for n in 1...20 {
            scores[n] = probs[n] ?? 0.05
        }

        for candidate in baseCandidates {
            if let n = candidate.number {
                let w = stats.strategyWeights[candidate.strategy] ?? 1.0
                scores[n, default: 0] += candidate.confidence * w
            }
            for n in candidate.predictedNumbers {
                scores[n, default: 0] += candidate.confidence * 0.4
            }
        }

        for (n, s) in sectorScores where (1...20).contains(n) {
            scores[n, default: 0] += s * 0.25
        }

        let picks = MultiPickPredictor.topNumbers(from: scores, count: MultiPickPredictor.pickCount)
        let rawConfidence = MultiPickPredictor.setConfidence(numbers: picks, scores: scores)
        let calibrated = min(0.96, rawConfidence + min(0.12, stats.recentAccuracy * 0.08))

        var reason = "4 прогноза: \(picks.map(String.init).joined(separator: ", "))"
        if behavior.bodyDetected {
            reason += " · \(behavior.phase.displayName)"
        }
        reason += " · шанс набора \(Int(calibrated * 100))%"
        if stats.totalPredictions > 3 {
            reason += " · точность \(stats.recentAccuracyPercent)%"
        }

        return BetRecommendation(
            betType: .number,
            number: picks.first,
            predictedNumbers: picks,
            confidence: calibrated,
            reason: reason,
            strategy: "Адаптивное обучение (4 сектора)"
        )
    }

    private func defaultMultiRecommendation() -> BetRecommendation {
        BetRecommendation(
            betType: .number,
            number: 7,
            predictedNumbers: [7, 11, 14, 3],
            confidence: 0.35,
            reason: "Недостаточно данных",
            strategy: "По умолчанию"
        )
    }

    func resetLearning() {
        stats = LearningStats()
        contextTransitions.removeAll()
        behaviorOutcomes.removeAll()
        sectorScores.removeAll()
        sectorModel.reset()
        pendingPrediction = nil
        recentOutcomes.removeAll()
        initializeStrategyWeights()
        lastLearningMessage = "Обучение сброшено"
        save()
    }

    private func updateStreak(correct: Bool) {
        if correct {
            stats.currentStreak += 1
            stats.bestStreak = max(stats.bestStreak, stats.currentStreak)
        } else {
            stats.currentStreak = 0
        }
    }

    private func adaptLearningRate() {
        let accuracy = stats.recentAccuracy
        let gap = stats.targetAccuracy - accuracy
        if gap > 0.5 {
            stats.adaptiveLearningRate = min(0.25, baseLearningRate * 1.3)
        } else if gap > 0.2 {
            stats.adaptiveLearningRate = baseLearningRate
        } else if accuracy > 0.9 {
            stats.adaptiveLearningRate = max(0.05, baseLearningRate * 0.6)
        } else {
            stats.adaptiveLearningRate = max(0.08, baseLearningRate * 0.85)
        }
    }

    private var learningRate: Double { stats.adaptiveLearningRate }

    private func sectorModelRecommendation(
        features: PredictionFeatures,
        behavior: PlayerBehaviorSnapshot
    ) -> BetRecommendation? {
        guard let (sectorKey, prob) = sectorModel.topSector(
            contextKey: features.contextKey,
            behaviorKey: features.behaviorKey
        ), prob >= 0.12 else { return nil }

        guard let sector = DartSector.from(detected: sectorKey) else { return nil }

        if sectorKey == 25 {
            return BetRecommendation(
                betType: .bullseye, number: nil, confidence: prob,
                reason: "Модель: булл \(Int(prob * 100))%",
                strategy: "Нейромодель"
            )
        }

        if prob >= 0.18 {
            return BetRecommendation(
                betType: .number, number: sectorKey, confidence: prob,
                reason: "Модель: сектор \(sectorKey) (\(Int(prob * 100))%)",
                strategy: "Нейромодель"
            )
        }

        return groupRecommendation(for: sector, confidence: prob, prefix: "Модель")
    }

    // MARK: - Learning core

    @discardableResult
    private func learn(
        pending: PendingPrediction,
        actual: DartSector,
        behaviorDuringRound: PlayerBehaviorSnapshot,
        correct: Bool
    ) -> Double {
        let reward: Double = correct ? 1.0 : -0.7
        var totalDelta = 0.0

        let strategyName = pending.strategy
        let currentWeight = stats.strategyWeights[strategyName] ?? 1.0
        let newWeight = max(0.1, currentWeight + learningRate * reward)
        stats.strategyWeights[strategyName] = newWeight
        totalDelta += abs(newWeight - currentWeight)

        let ctxKey = pending.features.contextKey
        var ctxMap = contextTransitions[ctxKey, default: [:]]
        ctxMap[actual.rawValue, default: 0] += 1
        contextTransitions[ctxKey] = ctxMap

        let behKey = behaviorDuringRound.behaviorKey
        var behMap = behaviorOutcomes[behKey, default: [:]]
        behMap[actual.rawValue, default: 0] += 1
        behaviorOutcomes[behKey] = behMap

        sectorScores[actual.rawValue, default: 0] += correct ? 0.1 : -0.05

        if !correct {
            boostAlternativesThatWouldWin(actual: actual, pending: pending)
        }

        adjustExploration(correct: correct)
        return totalDelta
    }

    private func boostAlternativesThatWouldWin(actual: DartSector, pending: PendingPrediction) {
        let winningKey: String
        if actual == .bullseye {
            winningKey = "bullseye--1"
        } else {
            winningKey = "number-\(actual.rawValue)"
        }

        for (name, weight) in stats.strategyWeights {
            if name.contains("Марков") && actual.rawValue <= 20 {
                stats.strategyWeights[name] = weight + learningRate * 0.5
            }
        }

        let ctxKey = pending.features.contextKey
        var ctxMap = contextTransitions[ctxKey, default: [:]]
        ctxMap[actual.rawValue, default: 0] += 2
        contextTransitions[ctxKey] = ctxMap

        _ = winningKey
    }

    private func adjustExploration(correct: Bool) {
        if stats.recentAccuracy < 0.4 && stats.totalPredictions > 10 {
            for key in stats.strategyWeights.keys {
                stats.strategyWeights[key] = (stats.strategyWeights[key] ?? 1) * 0.95 + 0.05
            }
        }
        if correct && stats.recentAccuracy > 0.7 {
            _ = explorationRate
        }
    }

    // MARK: - Recommendation helpers

    private func contextBonusRecommendation(features: PredictionFeatures, history: [DartSector]) -> BetRecommendation? {
        guard let map = contextTransitions[features.contextKey], !map.isEmpty else { return nil }
        let total = Double(map.values.reduce(0, +))
        guard let best = map.max(by: { $0.value < $1.value }),
              let sector = DartSector.from(detected: best.key) else { return nil }

        let confidence = Double(best.value) / total
        guard confidence >= 0.2 else { return nil }

        if best.key == 25 {
            return BetRecommendation(betType: .bullseye, number: nil, confidence: confidence,
                                     reason: "Контекст: после \(history.first?.description ?? "?") → булл",
                                     strategy: "Контекст")
        }

        if confidence >= 0.35 {
            return BetRecommendation(betType: .number, number: best.key, confidence: confidence,
                                     reason: "Контекст: сектор \(best.key) (\(Int(confidence * 100))%)",
                                     strategy: "Контекст")
        }

        return groupRecommendation(for: sector, confidence: confidence, prefix: "Контекст")
    }

    private func behaviorBonusRecommendation(features: PredictionFeatures) -> BetRecommendation? {
        guard let map = behaviorOutcomes[features.behaviorKey], !map.isEmpty else { return nil }
        let total = Double(map.values.reduce(0, +))
        guard total >= 2,
              let best = map.max(by: { $0.value < $1.value }),
              let sector = DartSector.from(detected: best.key) else { return nil }

        let confidence = Double(best.value) / total
        guard confidence >= 0.25 else { return nil }

        if best.key == 25 {
            return BetRecommendation(betType: .bullseye, number: nil, confidence: confidence,
                                     reason: "Поведение игрока → булл",
                                     strategy: "Поведение")
        }

        if confidence >= 0.3 {
            return BetRecommendation(betType: .number, number: best.key, confidence: confidence,
                                     reason: "Поведение игрока → \(best.key)",
                                     strategy: "Поведение")
        }

        return groupRecommendation(for: sector, confidence: confidence, prefix: "Поведение")
    }

    private func sectorScoreRecommendation(history: [DartSector], behavior: PlayerBehaviorSnapshot) -> BetRecommendation? {
        guard !sectorScores.isEmpty else { return nil }

        let sorted = sectorScores.sorted { $0.value > $1.value }
        guard let best = sorted.first, best.value > 0.1,
              let sector = DartSector.from(detected: best.key) else { return nil }

        let confidence = min(0.7, 0.3 + best.value)
        if behavior.phase == .windup || behavior.phase == .release {
            return BetRecommendation(
                betType: .number, number: best.key, confidence: confidence,
                reason: "Обученный приоритет сектора \(best.key)",
                strategy: "Секторные веса"
            )
        }

        return groupRecommendation(for: sector, confidence: confidence, prefix: "Веса")
    }

    private func groupRecommendation(for sector: DartSector, confidence: Double, prefix: String) -> BetRecommendation {
        let bet: BetType
        if sector == .bullseye { bet = .bullseye }
        else if sector.isEven { bet = .even }
        else { bet = .odd }

        return BetRecommendation(
            betType: bet, number: nil, confidence: confidence,
            reason: "\(prefix) → \(bet.displayName)",
            strategy: prefix
        )
    }

    private func calibrateConfidence(raw: Double, features: PredictionFeatures) -> Double {
        let base = min(0.95, raw / 3.0 + 0.2)
        let accuracyBoost = stats.recentAccuracy * 0.3
        let samplePenalty = stats.totalPredictions < 10 ? 0.15 : 0

        let calibrated = base + accuracyBoost - samplePenalty
        return max(0.25, min(0.99, calibrated))
    }

    private func contextConfidence(for contextKey: String, bet: BetRecommendation) -> Double {
        guard let map = contextTransitions[contextKey] else { return 0.5 }
        let total = Double(map.values.reduce(0, +))
        guard total > 0 else { return 0.5 }

        let matching = map.filter { key, _ in
            guard let sector = DartSector.from(detected: key) else { return false }
            return bet.betType.matches(sector, number: bet.number)
        }.values.reduce(0, +)

        return max(0.3, Double(matching) / total)
    }

    private func behaviorConfidence(for behaviorKey: String, bet: BetRecommendation) -> Double {
        guard let map = behaviorOutcomes[behaviorKey] else { return 0.5 }
        let total = Double(map.values.reduce(0, +))
        guard total > 0 else { return 0.5 }

        let matching = map.filter { key, _ in
            guard let sector = DartSector.from(detected: key) else { return false }
            return bet.betType.matches(sector, number: bet.number)
        }.values.reduce(0, +)

        return max(0.3, Double(matching) / total)
    }

    private func strategyVoteMap(from candidates: [BetRecommendation]) -> [String: Double] {
        var map: [String: Double] = [:]
        for c in candidates {
            map[c.strategy, default: 0] += c.confidence
        }
        return map
    }

    private func betKey(_ rec: BetRecommendation) -> String {
        "\(rec.betType.rawValue)-\(rec.number ?? -1)"
    }

    private func defaultRecommendation() -> BetRecommendation {
        BetRecommendation(betType: .odd, number: nil, confidence: 0.35,
                          reason: "Недостаточно данных", strategy: "По умолчанию")
    }

    private func initializeStrategyWeights() {
        let strategies = [
            "Ансамбль", "Ансамбль (рекомендуется)", "Марковская цепь", "Контртренд",
            "Горячие/холодные", "Чёт/нечёт", "Адаптивное обучение",
            "Контекст", "Поведение", "Секторные веса", "Нейромодель"
        ]
        for s in strategies {
            if stats.strategyWeights[s] == nil {
                stats.strategyWeights[s] = 1.0
            }
        }
    }

    // MARK: - Persistence

    private struct PersistedState: Codable {
        var stats: LearningStats
        var contextTransitions: [String: [Int: Int]]
        var behaviorOutcomes: [String: [Int: Int]]
        var sectorScores: [Int: Double]
        var sectorContextProbs: [String: [Int: Double]]?
        var sectorBehaviorProbs: [String: [Int: Double]]?
        var sectorGlobalProbs: [Int: Double]?
        var sectorSamples: Int?
    }

    private func save() {
        let exported = sectorModel.exportState()
        let state = PersistedState(
            stats: stats,
            contextTransitions: contextTransitions,
            behaviorOutcomes: behaviorOutcomes,
            sectorScores: sectorScores,
            sectorContextProbs: exported.context,
            sectorBehaviorProbs: exported.behavior,
            sectorGlobalProbs: exported.global,
            sectorSamples: exported.samples
        )
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: storageURL)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data) else { return }
        stats = state.stats
        contextTransitions = state.contextTransitions
        behaviorOutcomes = state.behaviorOutcomes
        sectorScores = state.sectorScores
        if let ctx = state.sectorContextProbs,
           let beh = state.sectorBehaviorProbs,
           let glob = state.sectorGlobalProbs {
            sectorModel.importState(
                context: ctx,
                behavior: beh,
                global: glob,
                samples: state.sectorSamples ?? 0
            )
        }
        lastLearningMessage = "Загружено: \(stats.totalPredictions) прогнозов, точность \(stats.overallAccuracyPercent)%"
    }
}
