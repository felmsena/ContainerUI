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

    // MARK: – ImageReference.split

    func testImageReference_split_dockerLibraryPrefix_isStripped() {
        let (name, tag) = ImageReference.split("docker.io/library/postgres:16")
        XCTAssertEqual(name, "postgres")
        XCTAssertEqual(tag,  "16")
    }

    func testImageReference_split_dockerNonLibraryPrefix_keepsNamespace() {
        let (name, tag) = ImageReference.split("docker.io/sonarsource/sonar-scanner-cli:latest")
        XCTAssertEqual(name, "sonarsource/sonar-scanner-cli")
        XCTAssertEqual(tag,  "latest")
    }

    func testImageReference_split_thirdPartyRegistry_isKept() {
        let (name, tag) = ImageReference.split("ghcr.io/apple/containerization/vminit:0.33.3")
        XCTAssertEqual(name, "ghcr.io/apple/containerization/vminit")
        XCTAssertEqual(tag,  "0.33.3")
    }

    func testImageReference_split_noTag_defaultsToLatest() {
        let (name, tag) = ImageReference.split("alpine")
        XCTAssertEqual(name, "alpine")
        XCTAssertEqual(tag,  "latest")
    }

    func testImageReference_split_registryWithPort_notMistakenForTag() {
        let (name, tag) = ImageReference.split("localhost:5000/myapp:v1")
        XCTAssertEqual(name, "localhost:5000/myapp")
        XCTAssertEqual(tag,  "v1")
    }
}
