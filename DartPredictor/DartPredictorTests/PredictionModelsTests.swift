import XCTest
@testable import DartPredictor

final class PredictionModelsTests: XCTestCase {
    func testSequenceModelPredictsFromHistory() {
        let model = SequenceModel()
        let history = [14, 7, 19, 3, 12, 17, 7, 19]
        model.update(actual: 7, history: Array(history.dropLast()), features: .zero, wasCorrect: false)
        model.update(actual: 19, history: history, features: .zero, wasCorrect: false)

        let scores = model.predict(history: history, features: .zero)
        XCTAssertFalse(scores.isEmpty)
        let total = scores.values.reduce(0, +)
        XCTAssertEqual(total, 1.0, accuracy: 0.01)
    }

    func testFrequencyModelNormalization() {
        let model = FrequencyModel()
        var history: [Int] = []
        for i in 1...36 { history.append(i) }
        for num in history {
            model.update(actual: num, history: history, features: .zero, wasCorrect: false)
        }
        let scores = model.predict(history: history, features: .zero)
        let total = scores.values.reduce(0, +)
        XCTAssertEqual(total, 1.0, accuracy: 0.01)
    }

    func testTransitionModelFollowsPrevious() {
        let model = TransitionModel()
        var history = [14]
        for _ in 0..<10 {
            model.update(actual: 7, history: history, features: .zero, wasCorrect: false)
            history.append(7)
        }
        let scores = model.predict(history: [14], features: .zero)
        XCTAssertGreaterThan(scores[7] ?? 0, scores[3] ?? 0)
    }

    func testEnsembleProducesTop4() {
        let ensemble = EnsemblePredictor()
        let history = [14, 7, 19, 3, 12]
        let prediction = ensemble.predict(
            history: history,
            features: .zero,
            weights: DartConstants.defaultModelWeights
        )
        XCTAssertEqual(prediction.predictions.count, 4)
        let probTotal = prediction.predictions.map(\.probability).reduce(0, +)
        XCTAssertEqual(probTotal, 100.0, accuracy: 0.1)
        XCTAssertEqual(prediction.combination.numbers.count, 4)
    }

    func testValidGridNumbers() {
        XCTAssertTrue(DartConstants.validNumbers.contains(36))
        XCTAssertTrue(DartConstants.validNumbers.contains(1))
        XCTAssertFalse(DartConstants.validNumbers.contains(0))
        XCTAssertFalse(DartConstants.validNumbers.contains(37))
    }

    func testDiceMathGridMapping() {
        XCTAssertEqual(DiceMath.gridNumber(red: 5, blue: 5), 29)
        XCTAssertEqual(DiceMath.gridNumber(red: 1, blue: 4), 4)
        XCTAssertEqual(DiceMath.red(from: 29), 5)
        XCTAssertEqual(DiceMath.blue(from: 29), 5)
    }

    func testDiceMathModelPredicts() {
        let model = DiceMathModel()
        let history = [10, 29, 13, 4, 24, 28]
        let scores = model.predict(history: history, features: .zero)
        XCTAssertFalse(scores.isEmpty)
        let total = scores.values.reduce(0, +)
        XCTAssertEqual(total, 1.0, accuracy: 0.02)
    }

    func testEnsembleAlternativeCombinations() {
        let ensemble = EnsemblePredictor()
        let history = [10, 29, 13, 4, 24, 28, 30, 18]
        let prediction = ensemble.predict(
            history: history,
            features: .zero,
            weights: DartConstants.defaultModelWeights
        )
        XCTAssertGreaterThanOrEqual(prediction.alternativeCombinations.count, 1)
    }

    func testOCRDebounce() {
        let ocr = OCRManager.shared
        ocr.reset()
        XCTAssertNil(ocr.processWithDebounce(recognized: 14))
        XCTAssertNil(ocr.processWithDebounce(recognized: 14))
        let confirmed = ocr.processWithDebounce(recognized: 14)
        XCTAssertEqual(confirmed, 14)
    }

    func testAccuracyStats() {
        var stats = AccuracyStats()
        stats.totalPredictions = 10
        stats.top4Hits = 5
        XCTAssertEqual(stats.top4Accuracy, 50.0)
    }

    func testCombinationJointProbability() {
        let preds = [
            TopPrediction(number: 17, probability: 30),
            TopPrediction(number: 7, probability: 25),
            TopPrediction(number: 19, probability: 25),
            TopPrediction(number: 12, probability: 20)
        ]
        let combo = CombinationPredictor.shared.buildCombination(from: preds)
        XCTAssertEqual(combo.numbers.count, 4)
        XCTAssertGreaterThan(combo.jointProbability, 0)
        XCTAssertLessThanOrEqual(combo.jointProbability, 99.9)
    }

    func testAIActionInsightDefaults() {
        let insight = AIActionInsight.empty
        XCTAssertEqual(insight.sceneState, .idle)
        XCTAssertFalse(insight.playerDetected)
    }
}
