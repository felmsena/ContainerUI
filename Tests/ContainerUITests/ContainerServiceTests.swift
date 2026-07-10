import XCTest
@testable import ContainerUI

final class ContainerServiceTests: XCTestCase {

    // MARK: – shellQuote

    func testShellQuote_plainId_isWrappedInSingleQuotes() {
        XCTAssertEqual(ContainerService.shellQuote("my-container"), "'my-container'")
    }

    func testShellQuote_embeddedSingleQuote_isEscaped() {
        XCTAssertEqual(ContainerService.shellQuote("foo'bar"), "'foo'\\''bar'")
    }

    // MARK: – appleScriptEscape

    func testAppleScriptEscape_doubleQuote_isEscaped() {
        XCTAssertEqual(ContainerService.appleScriptEscape("say \"hi\""), "say \\\"hi\\\"")
    }

    func testAppleScriptEscape_backslash_isEscaped() {
        XCTAssertEqual(ContainerService.appleScriptEscape("a\\b"), "a\\\\b")
    }

    // MARK: – openShellScript (regression for AppleScript/shell injection via container id)

    func testOpenShellScript_plainId_buildsExpectedDoScriptLine() {
        let script = ContainerService.openShellScript(bin: "/opt/homebrew/bin/container", id: "my-container")
        XCTAssertTrue(script.contains("do script \"/opt/homebrew/bin/container exec --tty --interactive 'my-container' sh\""))
    }

    func testOpenShellScript_idWithDoubleQuote_cannotEscapeDoScriptString() {
        let malicious = "\" & (do shell script \"touch /tmp/pwned\") & \""
        let script = ContainerService.openShellScript(bin: "/opt/homebrew/bin/container", id: malicious)

        // The do script line must remain a single AppleScript string literal:
        // exactly two unescaped double quotes (the opening and closing of the
        // literal) — any more would mean the id broke out of the string.
        guard let lineRange = script.range(of: "do script \"") else {
            return XCTFail("missing do script line")
        }
        let rest = script[lineRange.upperBound...]
        var unescapedQuotes = 0
        var chars = Array(rest)
        var i = 0
        while i < chars.count {
            if chars[i] == "\\" {
                i += 2
                continue
            }
            if chars[i] == "\"" { unescapedQuotes += 1 }
            i += 1
        }
        XCTAssertEqual(unescapedQuotes, 1, "id must not introduce an unescaped quote that closes the string early")
    }

    func testOpenShellScript_idWithSingleQuote_stillOneShellArgument() {
        let id = "foo'; rm -rf ~; echo '"
        let script = ContainerService.openShellScript(bin: "/opt/homebrew/bin/container", id: id)
        // The shell-quoted id is escaped again for AppleScript before being
        // embedded, so compare against that (not the raw shellQuote output).
        let expected = ContainerService.appleScriptEscape(ContainerService.shellQuote(id))
        XCTAssertTrue(script.contains(expected))
    }
}
