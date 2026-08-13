import XCTest
@testable import DartsForecast

final class ThrowDetectorTests: XCTestCase {
    func testRequiresStableFrames() async {
        let detector = ThrowDetector(requiredStable: 3, minGap: 0)
        let n = DartNumber.n17
        let r = OCRReading(number: n, rawText: "17", confidence: 0.9)

        let e1 = await detector.ingest(r)
        let e2 = await detector.ingest(r)
        XCTAssertNil(e1)
        XCTAssertNil(e2)
        let e3 = await detector.ingest(r)
        XCTAssertEqual(e3?.number, 17)
    }

    func testIgnoresSameConfirmedNumber() async {
        let detector = ThrowDetector(requiredStable: 2, minGap: 0)
        let r = OCRReading(number: .n7, rawText: "7", confidence: 0.9)
        _ = await detector.ingest(r)
        let confirmed = await detector.ingest(r)
        XCTAssertEqual(confirmed?.number, 7)

        let again1 = await detector.ingest(r)
        let again2 = await detector.ingest(r)
        XCTAssertNil(again1)
        XCTAssertNil(again2)
    }

    func testRejectsInvalidOCR() async {
        let detector = ThrowDetector(requiredStable: 2, minGap: 0)
        let bad = OCRReading(number: nil, rawText: "abc", confidence: 0.1)
        XCTAssertNil(await detector.ingest(bad))
        XCTAssertNil(await detector.ingest(bad))
    }

    func testParseOCRFilters() {
        XCTAssertEqual(DartNumber.parseOCR("17"), .n17)
        XCTAssertEqual(DartNumber.parseOCR("BULL"), .bull)
        XCTAssertEqual(DartNumber.parseOCR("O1"), .n1)
        XCTAssertNil(DartNumber.parseOCR("99"))
        XCTAssertNil(DartNumber.parseOCR(""))
    }
}
