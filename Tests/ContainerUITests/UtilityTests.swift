import XCTest
@testable import ContainerUI

final class UtilityTests: XCTestCase {

    // MARK: – formatCount

    func testFormatCount_small() {
        XCTAssertEqual(formatCount(0),   "0")
        XCTAssertEqual(formatCount(42),  "42")
        XCTAssertEqual(formatCount(999), "999")
    }

    func testFormatCount_thousands() {
        XCTAssertEqual(formatCount(1_000),   "1K")
        XCTAssertEqual(formatCount(5_500),   "5K")
        XCTAssertEqual(formatCount(999_999), "999K")
    }

    func testFormatCount_millions() {
        XCTAssertEqual(formatCount(1_000_000),   "1M")
        XCTAssertEqual(formatCount(50_000_000),  "50M")
        XCTAssertEqual(formatCount(999_000_000), "999M")
    }

    func testFormatCount_billions() {
        XCTAssertEqual(formatCount(1_000_000_000), "1.0B")
        XCTAssertEqual(formatCount(2_500_000_000), "2.5B")
    }
}
