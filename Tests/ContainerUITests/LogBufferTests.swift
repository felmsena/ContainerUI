import XCTest
@testable import ContainerUI

final class LogBufferTests: XCTestCase {

    func testReplace_splitsLinesAndDropsTrailingEmpty() {
        let buffer = LogBuffer(text: "a\nb\n")
        XCTAssertEqual(buffer.lines, ["a", "b"])
        XCTAssertEqual(buffer.text(filter: ""), "a\nb\n")
    }

    func testFilter_isCaseInsensitive() {
        let buffer = LogBuffer(text: "GET /health\nPOST /login\nget /index")
        XCTAssertEqual(buffer.text(filter: "get"), "GET /health\nget /index\n")
        XCTAssertEqual(buffer.text(filter: "nope"), "")
    }

    func testAppend_capsLineCount() {
        var buffer = LogBuffer()
        for i in 0..<(LogBuffer.maxLines + 5) { buffer.append("line \(i)") }
        XCTAssertLessThanOrEqual(buffer.lines.count, LogBuffer.maxLines)
        XCTAssertEqual(buffer.lines.last, "line \(LogBuffer.maxLines + 4)")
    }
}
