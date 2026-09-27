import XCTest
@testable import ContainerUI

/// Fixtures captured from `container` CLI 1.4.1.
final class CLI14ParsingTests: XCTestCase {

    func testParseSystemStatusJSON_groupedShape() {
        let json = """
        {"client":{"appName":"container","build":"release","commit":"unspecified","version":"1.4.1"},
         "host":{"architecture":"arm64","cpus":10,"operatingSystem":"Version 27.0 (Build 26A428)"},
         "paths":{"appRoot":"/Users/me/Library/Application Support/com.apple.container/","installRoot":"/opt/homebrew/Cellar/container/1.4.1/"},
         "resources":{"containersRunning":0,"containersTotal":1,"images":6},
         "server":{"appName":"container-apiserver","build":"release","commit":"unspecified","version":"1.4.1"},
         "status":"running"}
        """
        let status = ContainerService.parseSystemStatusJSON(Data(json.utf8))
        XCTAssertEqual(status?.status, "running")
        XCTAssertEqual(status?.appRoot, "/Users/me/Library/Application Support/com.apple.container/")
        XCTAssertEqual(status?.installRoot, "/opt/homebrew/Cellar/container/1.4.1/")
        XCTAssertEqual(status?.apiserverVersion, "1.4.1")
        XCTAssertEqual(status?.hostCPUs, 10)
        XCTAssertEqual(status?.containersTotal, 1)
        XCTAssertEqual(status?.imageCount, 6)
    }

    func testParseSystemStatus_textWithGroupedKeys() {
        let output = """
        FIELD               VALUE
        status              running
        server.version      1.4.1
        host.cpus           10
        paths.appRoot       /Users/me/Library/Application Support/com.apple.container/
        paths.installRoot   /opt/homebrew/Cellar/container/1.4.1/
        containers.running  0
        """
        let status = ContainerService.parseSystemStatus(output)
        XCTAssertEqual(status?.apiserverVersion, "1.4.1")
        XCTAssertEqual(status?.appRoot, "/Users/me/Library/Application Support/com.apple.container/")
        XCTAssertEqual(status?.installRoot, "/opt/homebrew/Cellar/container/1.4.1/")
        XCTAssertEqual(status?.hostCPUs, 10)
        XCTAssertEqual(status?.containersRunning, 0)
    }

    func testParseContainerListJSON_readsLabelsNetworksAndMounts_andFlagsBuilder() {
        let json = """
        [{"configuration":{"id":"buildkit","image":{"reference":"ghcr.io/apple/container-builder-shim/builder:0.12.0"},
          "labels":{"com.apple.container.plugin":"builder","com.apple.container.resource.role":"builder"},
          "mounts":[{"destination":"/run","source":""},{"destination":"/exports","source":"/Users/me/builder"}],
          "platform":{"architecture":"arm64","os":"linux"},"resources":{"cpus":2,"memoryInBytes":2147483648}},
          "id":"buildkit","status":{"networks":[],"state":"stopped"}},
         {"configuration":{"image":{"reference":"docker.io/library/alpine:latest"},"labels":{},
          "platform":{"architecture":"arm64","os":"linux"},"resources":{"cpus":1,"memoryInBytes":268435456}},
          "id":"web","status":{"networks":[{"ipv4Address":"192.168.64.2/24","network":"default"}],
          "startedDate":"2026-09-27T15:41:37Z","state":"running"}}]
        """
        let containers = ContainerService.parseContainerListJSON(Data(json.utf8)) ?? []
        XCTAssertEqual(containers.count, 2)
        XCTAssertTrue(containers[0].isBuilder)
        XCTAssertEqual(containers[0].mountSources, ["/Users/me/builder"])
        XCTAssertFalse(containers[1].isBuilder)
        XCTAssertEqual(containers[1].networks, ["default"])
        XCTAssertEqual(containers[1].ip, "192.168.64.2/24")
    }

    func testIsBuilder_textFallbackHeuristic() {
        let c = ContainerInfo(id: "buildkit", image: "ghcr.io/apple/container-builder-shim/builder:0.12.0",
                              os: "linux", arch: "arm64", state: .stopped, ip: "", cpus: 2, memory: "2048 MB", started: "")
        XCTAssertTrue(c.isBuilder)
    }

    func testImageInfo_isSystem() {
        XCTAssertTrue(ImageInfo(name: "ghcr.io/apple/containerization/vminit", tag: "0.35.0", digest: "").isSystem)
        XCTAssertFalse(ImageInfo(name: "alpine", tag: "latest", digest: "").isSystem)
    }
}
