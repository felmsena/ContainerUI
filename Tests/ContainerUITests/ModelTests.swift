import XCTest
@testable import ContainerUI

final class ModelTests: XCTestCase {

    // MARK: – ContainerState

    func testContainerState_parsing() {
        XCTAssertEqual(ContainerState(raw: "running"), .running)
        XCTAssertEqual(ContainerState(raw: "stopped"), .stopped)
        XCTAssertEqual(ContainerState(raw: "paused"),  .paused)
        XCTAssertEqual(ContainerState(raw: "RUNNING"), .running)
        XCTAssertEqual(ContainerState(raw: "bogus"),   .unknown)
        XCTAssertEqual(ContainerState(raw: ""),        .unknown)
    }

    func testContainerState_isRunning() {
        XCTAssertTrue(ContainerState.running.isRunning)
        XCTAssertFalse(ContainerState.stopped.isRunning)
        XCTAssertFalse(ContainerState.paused.isRunning)
        XCTAssertFalse(ContainerState.unknown.isRunning)
    }

    func testContainerState_label() {
        XCTAssertEqual(ContainerState.running.label, "Running")
        XCTAssertEqual(ContainerState.stopped.label, "Stopped")
        XCTAssertEqual(ContainerState.paused.label,  "Paused")
        XCTAssertEqual(ContainerState.unknown.label, "Unknown")
    }

    // MARK: – ContainerInfo computed properties

    private func makeContainer(image: String = "nginx:alpine", ip: String = "192.168.64.2/24") -> ContainerInfo {
        ContainerInfo(id: "test", image: image, os: "linux", arch: "arm64",
                      state: .running, ip: ip, cpus: 1, memory: "512M", started: "")
    }

    func testContainerInfo_shortImage() {
        XCTAssertEqual(makeContainer(image: "nginx:alpine").shortImage,         "nginx")
        XCTAssertEqual(makeContainer(image: "postgres:16").shortImage,          "postgres")
        XCTAssertEqual(makeContainer(image: "ghcr.io/user/myapp:v1").shortImage, "myapp")
    }

    func testContainerInfo_imageTag() {
        XCTAssertEqual(makeContainer(image: "nginx:alpine").imageTag,  "alpine")
        XCTAssertEqual(makeContainer(image: "postgres:16").imageTag,   "16")
        XCTAssertEqual(makeContainer(image: "ubuntu").imageTag,        "ubuntu")
    }

    func testContainerInfo_ipWithoutMask() {
        XCTAssertEqual(makeContainer(ip: "192.168.64.2/24").ipWithoutMask, "192.168.64.2")
        XCTAssertEqual(makeContainer(ip: "10.0.0.1/8").ipWithoutMask,     "10.0.0.1")
        XCTAssertEqual(makeContainer(ip: "").ipWithoutMask,               "")
    }

    func testContainerInfo_uptimeDisplay_empty() {
        XCTAssertEqual(makeContainer().uptimeDisplay, "—")
    }

    func testContainerInfo_uptimeDisplay_invalidDate() {
        let c = ContainerInfo(id: "x", image: "nginx", os: "linux", arch: "arm64",
                              state: .running, ip: "", cpus: 1, memory: "", started: "not-a-date")
        XCTAssertEqual(c.uptimeDisplay, "not-a-date")
    }

    // MARK: – ImageInfo computed properties

    func testImageInfo_id() {
        let img = ImageInfo(name: "nginx", tag: "alpine", digest: "sha256:abc")
        XCTAssertEqual(img.id,  "nginx:alpine")
        XCTAssertEqual(img.ref, "nginx:alpine")
    }

    func testImageInfo_shortDigest() {
        let img = ImageInfo(name: "nginx", tag: "latest", digest: "sha256:abcdef123456789")
        XCTAssertEqual(img.shortDigest, "sha256:abcde") // prefix(12): s,h,a,2,5,6,:,a,b,c,d,e
    }

    func testImageInfo_shortName_simple() {
        let img = ImageInfo(name: "nginx", tag: "latest", digest: "")
        XCTAssertEqual(img.shortName, "nginx")
    }

    func testImageInfo_shortName_registry() {
        let img = ImageInfo(name: "ghcr.io/org/myapp", tag: "v2", digest: "")
        XCTAssertEqual(img.shortName, "myapp")
    }
}
