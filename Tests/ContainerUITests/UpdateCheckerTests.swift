import XCTest
@testable import ContainerUI

final class UpdateCheckerTests: XCTestCase {

    // MARK: – Semver comparison

    func testIsNewer_higherPatchWins() {
        XCTAssertTrue(UpdateChecker.isNewer("0.2.0", than: "0.1.0"))
        XCTAssertFalse(UpdateChecker.isNewer("0.1.0", than: "0.2.0"))
    }

    func testIsNewer_equalVersionsAreNotNewer() {
        XCTAssertFalse(UpdateChecker.isNewer("0.1.0", than: "0.1.0"))
    }

    func testIsNewer_numericNotLexicographic() {
        XCTAssertTrue(UpdateChecker.isNewer("1.10.0", than: "1.9.0"))
        XCTAssertFalse(UpdateChecker.isNewer("1.9.0", than: "1.10.0"))
    }

    func testIsNewer_leadingVIsIgnoredOnBothSides() {
        XCTAssertTrue(UpdateChecker.isNewer("v0.2.0", than: "0.1.0"))
        XCTAssertTrue(UpdateChecker.isNewer("0.2.0", than: "v0.1.0"))
    }

    func testIsNewer_missingComponentsCompareAsZero() {
        XCTAssertFalse(UpdateChecker.isNewer("1.2", than: "1.2.0"))
        XCTAssertTrue(UpdateChecker.isNewer("1.2.1", than: "1.2"))
    }

    func testIsNewer_prereleaseAndBuildSuffixesAreStripped() {
        XCTAssertFalse(UpdateChecker.isNewer("0.2.0-beta.1", than: "0.2.0"))
        XCTAssertFalse(UpdateChecker.isNewer("0.2.0+build5", than: "0.2.0"))
        XCTAssertTrue(UpdateChecker.isNewer("0.3.0-beta.1", than: "0.2.0"))
    }

    // MARK: – GitHubReleaseInfo decode

    func testDecodesRealReleaseAPIShape() throws {
        // Trimmed fixture matching the actual shape of
        // GET /repos/{owner}/{repo}/releases/latest.
        let json = """
        {
          "tag_name": "v0.1.0",
          "html_url": "https://github.com/felmsena/ContainerUI/releases/tag/v0.1.0",
          "draft": false,
          "prerelease": false,
          "name": "ContainerUI v0.1.0",
          "id": 123456
        }
        """.data(using: .utf8)!

        let release = try JSONDecoder().decode(GitHubReleaseInfo.self, from: json)
        XCTAssertEqual(release.tagName, "v0.1.0")
        XCTAssertEqual(release.htmlUrl, "https://github.com/felmsena/ContainerUI/releases/tag/v0.1.0")
        XCTAssertFalse(release.draft)
        XCTAssertFalse(release.prerelease)
    }
}
