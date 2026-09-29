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

@MainActor
final class VolumeUsageTests: XCTestCase {
    func testContainersUsingVolume_matchesByNameOrBackingImage() async {
        let json = """
        [{"configuration":{"image":{"reference":"alpine"},"platform":{"architecture":"arm64","os":"linux"},
          "resources":{"cpus":1,"memoryInBytes":268435456},
          "mounts":[{"destination":"/data","source":"/vols/db/volume.img","type":{"volume":{"name":"db","format":"ext4"}}}]},
          "id":"c1","status":{"networks":[],"state":"running"}},
         {"configuration":{"image":{"reference":"alpine"},"platform":{"architecture":"arm64","os":"linux"},
          "resources":{"cpus":1,"memoryInBytes":268435456},"mounts":[]},
          "id":"c2","status":{"networks":[],"state":"running"}}]
        """
        let service = ContainerService(runner: FakeRunner { _ in FakeRunner.ok(json) }, binary: "/x", startBackgroundWork: false)
        await service.fetchContainers()
        let db = VolumeInfo(name: "db", type: "named", driver: "local", options: "", source: "/vols/db/volume.img")
        let other = VolumeInfo(name: "other", type: "named", driver: "local", options: "")
        XCTAssertEqual(service.containers(using: db).map(\.id), ["c1"])
        XCTAssertTrue(service.containers(using: other).isEmpty)
    }
}

final class NetworkParsingTests: XCTestCase {
    func testParseNetworkListJSON() {
        let json = """
        [{"configuration":{"creationDate":"2026-09-27T15:35:54Z","labels":{"com.apple.container.resource.role":"builtin"},
          "mode":"nat","name":"default","options":{},"plugin":"container-network-vmnet"},"id":"default",
          "status":{"ipv4Gateway":"192.168.64.1","ipv4Subnet":"192.168.64.0/24","ipv6Subnet":"fdc8::/64"}},
         {"configuration":{"labels":{},"mode":"nat","name":"backend"},"id":"backend","status":{"ipv4Subnet":"192.168.65.0/24"}}]
        """
        let networks = ContainerService.parseNetworkListJSON(Data(json.utf8)) ?? []
        XCTAssertEqual(networks.map(\.name), ["default", "backend"])
        XCTAssertTrue(networks[0].isBuiltin)
        XCTAssertEqual(networks[0].gateway, "192.168.64.1")
        XCTAssertEqual(networks[0].mode, "nat")
        XCTAssertFalse(networks[1].isBuiltin)
    }

    func testParseNetworkListText() {
        let output = """
        NETWORK  SUBNET
        default  192.168.64.0/24
        """
        XCTAssertEqual(ContainerService.parseNetworkList(output), [NetworkInfo(name: "default", subnet: "192.168.64.0/24")])
    }
}

final class InspectRunSpecTests: XCTestCase {
    func testParseContainerDetail_reconstructsRunSpec() {
        let json = """
        [{"configuration":{"id":"web","image":{"reference":"docker.io/library/nginx:alpine"},
          "initProcess":{"arguments":["-g","daemon off;"],"environment":["PATH=/usr/bin","MODE=prod"],
            "executable":"/docker-entrypoint.sh","user":{"id":{"gid":0,"uid":0}},"workingDirectory":"/srv"},
          "labels":{"team":"core"},
          "mounts":[{"destination":"/data","source":"/vols/db/volume.img","type":{"volume":{"name":"db"}}},
                    {"destination":"/run","source":"","type":{"tmpfs":{}}},
                    {"destination":"/src","source":"/Users/me/src","type":{"virtiofs":{}}}],
          "networks":[{"network":"backend"}],"platform":{"architecture":"amd64","os":"linux"},
          "publishedPorts":[{"containerPort":80,"hostAddress":"0.0.0.0","hostPort":8080,"proto":"tcp"}],
          "readOnly":true,"resources":{"cpus":2,"memoryInBytes":1073741824},"rosetta":true,"ssh":false,"useInit":true}}]
        """
        guard let spec = ContainerService.parseContainerDetail(Data(json.utf8))?.runSpec else { return XCTFail() }
        XCTAssertEqual(spec.image, "docker.io/library/nginx:alpine")
        XCTAssertEqual(spec.memory, "1G")
        XCTAssertEqual(spec.cpus, 2)
        XCTAssertEqual(spec.ports, ["8080:80"])
        XCTAssertEqual(spec.volumes, ["db:/data", "/Users/me/src:/src"])
        XCTAssertEqual(spec.env, ["MODE=prod"])
        XCTAssertEqual(spec.network, "backend")
        XCTAssertEqual(spec.platform, "linux/amd64")
        XCTAssertTrue(spec.rosetta && spec.readOnly && spec.useInit)
        XCTAssertEqual(spec.labels, ["team=core"])
        XCTAssertEqual(spec.entrypoint, "/docker-entrypoint.sh")
        XCTAssertEqual(ContainerService.tokenizeCommand(spec.command), ["-g", "daemon off;"])
        XCTAssertEqual(spec.workdir, "/srv")
        XCTAssertEqual(spec.user, "")
    }

    func testMemorySpec() {
        XCTAssertEqual(ContainerService.memorySpec(268_435_456), "256M")
        XCTAssertEqual(ContainerService.memorySpec(2_147_483_648), "2G")
    }
}

final class AllStatsParsingTests: XCTestCase {
    func testParseAllRawStats_keysSamplesById() {
        let json = """
        [{"blockReadBytes":1679360,"blockWriteBytes":0,"cpuUsageUsec":7006,"id":"cui-test","memoryLimitBytes":268435456,
          "memoryUsageBytes":2502656,"networkRxBytes":22734,"networkTxBytes":602,"numProcesses":2}]
        """
        let samples = ContainerService.parseAllRawStats(Data(json.utf8)) ?? []
        XCTAssertEqual(samples.map(\.id), ["cui-test"])
        XCTAssertEqual(samples.first?.raw.memoryUsageBytes, 2_502_656)
    }
}
