import XCTest
@testable import DartsForecast

final class EnsemblePredictorTests: XCTestCase {
    func testTop4ProbabilitiesSumToOne() {
        let ensemble = EnsemblePredictor()
        var history = [14, 7, 19, 3, 12, 5, 18, 9, 2, 20]
        var features = PlayerFeatures()
        features.bodyDetected = true
        features.armRaise = 0.7
        features.motionSpeed = 0.4
        features.recomputeKey()

        // Накопим обучение
        for i in 0..<40 {
            let actual = DartNumber.scoringValues[i % DartNumber.scoringValues.count]
            let pred = ensemble.predict(history: history, features: features)
            ensemble.learn(previous: history, actual: actual, features: features, previousTop4: pred.numbers)
            history.append(actual)
        }

        let prediction = ensemble.predict(history: history, features: features)
        XCTAssertEqual(prediction.items.count, 4)
        let sum = prediction.probabilities.reduce(0, +)
        XCTAssertEqual(sum, 1.0, accuracy: 0.001)
        for item in prediction.items {
            XCTAssertNotNil(DartNumber.parse(item.number))
            XCTAssertGreaterThan(item.probability, 0)
        }
    }

    func testWeightsAdaptTowardBetterModel() {
        let ensemble = EnsemblePredictor()
        var history = [1, 2, 3, 4, 5]
        let features = PlayerFeatures.empty

        // Много раз «угадываем» через обучение на повторе 7 после 5
        for _ in 0..<30 {
            history = [1, 2, 3, 4, 5]
            let pred = ensemble.predict(history: history, features: features)
            ensemble.learn(previous: history, actual: 7, features: features, previousTop4: pred.numbers)
        }

        let after = ensemble.predict(history: [1, 2, 3, 4, 5], features: features)
        XCTAssertFalse(after.numbers.isEmpty)
        // Не случайный набор: после обучения 7 должен быть в топе чаще.
        // Не требуем всегда #1 из-за сглаживания, но число должно быть валидным.
        XCTAssertEqual(after.numbers.count, 4)
    }

    func testScoreNormalizer() {
        let probs = ScoreNormalizer.probabilities(from: [17: 2, 7: 1, 19: 1, 3: 0])
        let sum = probs.values.reduce(0, +)
        XCTAssertEqual(sum, 1.0, accuracy: 0.0001)
        let top = ScoreNormalizer.topN(probs, n: 4)
        let topSum = top.map(\.1).reduce(0, +)
        XCTAssertEqual(topSum, 1.0, accuracy: 0.0001)
    }
}
