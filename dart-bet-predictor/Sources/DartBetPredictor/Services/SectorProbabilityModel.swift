import Foundation

/// Онлайн-модель вероятностей секторов: обучается после каждого броска.
final class SectorProbabilityModel {
    static let shared = SectorProbabilityModel()

  /// Все секторы: 1–20 + булл (25).
    static let sectorKeys: [Int] = (1...20).map { $0 } + [25]

    private var contextProbs: [String: [Int: Double]] = [:]
    private var behaviorProbs: [String: [Int: Double]] = [:]
    private var globalProbs: [Int: Double] = [:]
    private var totalSamples = 0

    private let smoothing = 0.08
    private let learningStep = 0.12

    private init() {
        reset()
    }

    func reset() {
        contextProbs.removeAll()
        behaviorProbs.removeAll()
        globalProbs = Self.uniformPrior()
        totalSamples = 0
    }

    /// Обновление после броска: усиливает фактический сектор, ослабляет ошибочный прогноз.
    func learn(
        actual: DartSector,
        contextKey: String,
        behaviorKey: String,
        predictedBet: BetType,
        predictedNumber: Int?
    ) {
        let actualKey = actual.rawValue
        totalSamples += 1

        updateMap(&globalProbs, actualKey: actualKey, weight: 1.0)

        var ctx = contextProbs[contextKey] ?? Self.uniformPrior()
        updateMap(&ctx, actualKey: actualKey, weight: 1.4)
        contextProbs[contextKey] = ctx

        var beh = behaviorProbs[behaviorKey] ?? Self.uniformPrior()
        updateMap(&beh, actualKey: actualKey, weight: 1.6)
        behaviorProbs[behaviorKey] = beh

        // Штраф прогнозу, который не совпал с исходом
        if let wrongKey = wrongSectorKey(bet: predictedBet, number: predictedNumber, actual: actual) {
            if var ctxMap = contextProbs[contextKey] {
                let current = ctxMap[wrongKey] ?? smoothing
                ctxMap[wrongKey] = max(0.001, current - learningStep * 0.5)
                normalize(&ctxMap)
                contextProbs[contextKey] = ctxMap
            }
        }
    }

    /// Вероятности следующего сектора для контекста + поведения.
    func probabilities(contextKey: String, behaviorKey: String) -> [Int: Double] {
        let ctx = contextProbs[contextKey] ?? globalProbs
        let beh = behaviorProbs[behaviorKey] ?? globalProbs

        var merged: [Int: Double] = [:]
        for key in Self.sectorKeys {
            let sampleBoost = min(0.15, Double(totalSamples) / 200.0 * 0.15)
            let g = globalProbs[key] ?? smoothing
            let c = ctx[key] ?? smoothing
            let b = beh[key] ?? smoothing
            merged[key] = g * 0.25 + c * (0.45 + sampleBoost) + b * (0.30 + sampleBoost)
        }
        normalize(&merged)
        return merged
    }

    func topSector(contextKey: String, behaviorKey: String) -> (Int, Double)? {
        let probs = probabilities(contextKey: contextKey, behaviorKey: behaviorKey)
        guard let best = probs.max(by: { $0.value < $1.value }) else { return nil }
        return (best.key, best.value)
    }

    func exportState() -> (context: [String: [Int: Double]], behavior: [String: [Int: Double]], global: [Int: Double], samples: Int) {
        (contextProbs, behaviorProbs, globalProbs, totalSamples)
    }

    func importState(
        context: [String: [Int: Double]],
        behavior: [String: [Int: Double]],
        global: [Int: Double],
        samples: Int
    ) {
        contextProbs = context
        behaviorProbs = behavior
        globalProbs = global.isEmpty ? Self.uniformPrior() : global
        totalSamples = samples
    }

    // MARK: - Helpers

    private static func uniformPrior() -> [Int: Double] {
        let count = Double(sectorKeys.count)
        var map: [Int: Double] = [:]
        for k in sectorKeys { map[k] = 1.0 / count }
        return map
    }

    private func updateMap(_ map: inout [Int: Double], actualKey: Int, weight: Double) {
        for key in Self.sectorKeys {
            let delta = key == actualKey ? learningStep * weight : -learningStep * weight * 0.04
            map[key] = max(0.001, (map[key] ?? smoothing) + delta)
        }
        normalize(&map)
    }

    private func normalize(_ map: inout [Int: Double]) {
        let sum = map.values.reduce(0, +)
        guard sum > 0 else { return }
        for key in map.keys {
            map[key] = (map[key] ?? 0) / sum
        }
    }

    private func wrongSectorKey(bet: BetType, number: Int?, actual: DartSector) -> Int? {
        switch bet {
        case .number:
            guard let number, number != actual.rawValue else { return nil }
            return number
        case .even:
            return actual.isEven && actual != .bullseye ? nil : (actual.isOdd ? actual.rawValue : nil)
        case .odd:
            return actual.isOdd ? nil : actual.rawValue
        case .low:
            return actual.isLow ? nil : actual.rawValue
        case .high:
            return actual.isHigh ? nil : actual.rawValue
        case .bullseye:
            return actual == .bullseye ? nil : actual.rawValue
        }
    }
}
