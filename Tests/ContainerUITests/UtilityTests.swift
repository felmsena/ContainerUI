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

    // MARK: – imageMatches

    func testImageMatches_exactRefMatch() {
        let image = ImageInfo(name: "postgres", tag: "latest", digest: "")
        XCTAssertTrue(imageMatches(containerImage: "docker.io/library/postgres:latest", image: image))
    }

    func testImageMatches_implicitLatestTag() {
        let image = ImageInfo(name: "postgres", tag: "latest", digest: "")
        XCTAssertTrue(imageMatches(containerImage: "docker.io/library/postgres", image: image))
    }

    func testImageMatches_falsePrefix_doesNotMatch() {
        let image = ImageInfo(name: "postgres", tag: "latest", digest: "")
        XCTAssertFalse(imageMatches(containerImage: "docker.io/library/postgres-custom:1.0", image: image))
    }

    func testImageMatches_differentTag_doesNotMatch() {
        let image = ImageInfo(name: "postgres", tag: "16", digest: "")
        XCTAssertFalse(imageMatches(containerImage: "docker.io/library/postgres:latest", image: image))
    }

    func testImageMatches_thirdPartyRegistry() {
        let image = ImageInfo(name: "ghcr.io/apple/containerization/vminit", tag: "0.33.3", digest: "")
        XCTAssertTrue(imageMatches(containerImage: "ghcr.io/apple/containerization/vminit:0.33.3", image: image))
    }

    // MARK: – ContainerService.tokenizeCommand

    func testTokenizeCommand_simple() {
        XCTAssertEqual(ContainerService.tokenizeCommand("ls -la /"), ["ls", "-la", "/"])
    }

    func testTokenizeCommand_collapsesExtraWhitespace() {
        XCTAssertEqual(ContainerService.tokenizeCommand("  ls    -la   /tmp  "), ["ls", "-la", "/tmp"])
    }

    func testTokenizeCommand_doubleQuotedArgumentKeepsSpaces() {
        XCTAssertEqual(ContainerService.tokenizeCommand(#"sh -c "echo hello world""#), ["sh", "-c", "echo hello world"])
    }

    func testTokenizeCommand_singleQuotedArgumentKeepsSpaces() {
        XCTAssertEqual(ContainerService.tokenizeCommand("sh -c 'echo hi there'"), ["sh", "-c", "echo hi there"])
    }

    func testTokenizeCommand_empty_returnsEmptyArray() {
        XCTAssertEqual(ContainerService.tokenizeCommand(""), [])
        XCTAssertEqual(ContainerService.tokenizeCommand("   "), [])
    }

    func testTokenizeCommand_unmatchedQuote_doesNotCrash() {
        XCTAssertEqual(ContainerService.tokenizeCommand(#"echo "unterminated"#), ["echo", "unterminated"])
    }

    // MARK: – ContainerService.detectBuildFile

    private func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func testDetectBuildFile_prefersDockerfile() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try! "FROM alpine".write(to: dir.appendingPathComponent("Dockerfile"), atomically: true, encoding: .utf8)
        try! "FROM alpine".write(to: dir.appendingPathComponent("Containerfile"), atomically: true, encoding: .utf8)
        XCTAssertEqual(ContainerService.detectBuildFile(in: dir), "Dockerfile")
    }

    func testDetectBuildFile_fallsBackToContainerfile() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try! "FROM alpine".write(to: dir.appendingPathComponent("Containerfile"), atomically: true, encoding: .utf8)
        XCTAssertEqual(ContainerService.detectBuildFile(in: dir), "Containerfile")
    }

    func testDetectBuildFile_neitherPresent_returnsNil() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        XCTAssertNil(ContainerService.detectBuildFile(in: dir))
    }
}
