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
        for i in 1...20 { history.append(i) }
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
    }

    func testValidDartNumbers() {
        XCTAssertTrue(DartConstants.validNumbers.contains(20))
        XCTAssertFalse(DartConstants.validNumbers.contains(0))
        XCTAssertFalse(DartConstants.validNumbers.contains(21))
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

    func testPlayerProfileWeights() {
        let profile = PlayerProfile(id: "test", name: "Test")
        let total = PredictionModelType.allCases.map { profile.weight(for: $0) }.reduce(0, +)
        XCTAssertGreaterThan(total, 0.9)
    }
}
