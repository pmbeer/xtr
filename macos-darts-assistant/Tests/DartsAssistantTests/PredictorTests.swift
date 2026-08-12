import XCTest
@testable import DartsAssistant

final class PredictorTests: XCTestCase {
    func testCollectsAtLeastThirtyThrows() {
        var predictor = ThrowPredictor()
        (1...29).forEach { predictor.observe(($0 % 20) + 1) }

        XCTAssertEqual(predictor.recommendation(), .collecting)
    }

    func testUniformHistoryRecommendsSkipping() {
        var predictor = ThrowPredictor()
        for _ in 0..<5 {
            (1...20).forEach { predictor.observe($0) }
        }

        XCTAssertEqual(predictor.recommendation().title, "ПРОПУСТИТЬ")
    }

    func testStrongOddBiasIsDetected() {
        var predictor = ThrowPredictor()
        for index in 0..<100 {
            predictor.observe((index % 10) * 2 + 1)
        }

        XCTAssertEqual(predictor.recommendation().title, "НЕЧЁТ")
    }

    func testInvalidValuesAreIgnored() {
        var predictor = ThrowPredictor()
        predictor.observe(0)
        predictor.observe(21)
        predictor.observe(7)

        XCTAssertEqual(predictor.history, [7])
    }
}

final class ThrowDetectorTests: XCTestCase {
    func testSeedsOnlyAfterStableFrames() {
        var detector = ThrowDetector()

        XCTAssertEqual(detector.ingest([3, 7, 10]), .none)
        XCTAssertEqual(detector.ingest([3, 7, 10]), .seed([3, 7, 10]))
    }

    func testFindsNewestValueAfterHistoryShift() {
        var detector = ThrowDetector()
        _ = detector.ingest([3, 7, 10])
        _ = detector.ingest([3, 7, 10])

        XCTAssertEqual(detector.ingest([5, 3, 7]), .none)
        XCTAssertEqual(detector.ingest([5, 3, 7]), .newThrow(5))
    }

    func testDetectsSameNumberTwiceWhenHistoryShifts() {
        var detector = ThrowDetector()
        _ = detector.ingest([5, 3, 7])
        _ = detector.ingest([5, 3, 7])

        XCTAssertEqual(detector.ingest([5, 5, 3]), .none)
        XCTAssertEqual(detector.ingest([5, 5, 3]), .newThrow(5))
    }
}
