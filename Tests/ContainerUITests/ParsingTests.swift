import XCTest
@testable import ContainerUI

final class ParsingTests: XCTestCase {

    // MARK: – columnOffset / field helpers

    func testColumnOffset_found() {
        let header = "ID     IMAGE   OS"
        XCTAssertEqual(ContainerService.columnOffset("ID",    in: header), 0)
        XCTAssertEqual(ContainerService.columnOffset("IMAGE", in: header), 7)
        XCTAssertEqual(ContainerService.columnOffset("OS",    in: header), 15)
    }

    func testColumnOffset_missing() {
        XCTAssertNil(ContainerService.columnOffset("MISSING", in: "ID IMAGE OS"))
    }

    func testField_basic() {
        let chars = Array("hello world")
        XCTAssertEqual(ContainerService.field(chars, from: 0,  to: 5),  "hello")
        XCTAssertEqual(ContainerService.field(chars, from: 6,  to: nil), "world")
    }

    func testField_trims_whitespace() {
        let chars = Array("  nginx   alpine  ")
        XCTAssertEqual(ContainerService.field(chars, from: 0, to: 9),  "nginx")
        XCTAssertEqual(ContainerService.field(chars, from: 9, to: nil), "alpine")
    }

    func testField_outOfBounds_returnsEmpty() {
        let chars = Array("ab")
        XCTAssertEqual(ContainerService.field(chars, from: 5, to: 10), "")
    }

    // MARK: – parseContainerList
    //
    // Column positions in the header below (verified by character count):
    //   ID=0  IMAGE=7  OS=15  ARCH=21  STATE=28  IP=36  CPUS=47  MEMORY=53  STARTED=61

    private let containerHeader = "ID     IMAGE   OS    ARCH   STATE   IP         CPUS  MEMORY  STARTED"
    private let containerRow    = "abc123 nginx   linux arm64  running 10.0.0.1/8 1     256M    2024-01-01T00:00:00Z"

    func testParseContainerList_empty() {
        XCTAssertTrue(ContainerService.parseContainerList("").isEmpty)
        XCTAssertTrue(ContainerService.parseContainerList(containerHeader).isEmpty)
    }

    func testParseContainerList_single() {
        let output = containerHeader + "\n" + containerRow
        let result = ContainerService.parseContainerList(output)

        XCTAssertEqual(result.count, 1)
        let c = result[0]
        XCTAssertEqual(c.id,     "abc123")
        XCTAssertEqual(c.image,  "nginx")
        XCTAssertEqual(c.os,     "linux")
        XCTAssertEqual(c.arch,   "arm64")
        XCTAssertEqual(c.state,  .running)
        XCTAssertEqual(c.ip,     "10.0.0.1/8")
        XCTAssertEqual(c.cpus,   1)
        XCTAssertEqual(c.memory, "256M")
        XCTAssertEqual(c.started, "2024-01-01T00:00:00Z")
    }

    func testParseContainerList_multiple() {
        let row2 = "web    postgres linux arm64  stopped 10.0.0.2/8 2     512M    2024-06-01T00:00:00Z"
        let output = containerHeader + "\n" + containerRow + "\n" + row2
        let result = ContainerService.parseContainerList(output)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[1].id,    "web")
        XCTAssertEqual(result[1].state, .stopped)
        XCTAssertEqual(result[1].cpus,  2)
    }

    func testParseContainerList_skips_empty_id() {
        let blankRow = "       nginx   linux arm64  running 10.0.0.1/8 1     256M    "
        let output = containerHeader + "\n" + blankRow
        XCTAssertTrue(ContainerService.parseContainerList(output).isEmpty)
    }

    // MARK: – parseImageList
    //
    // Column positions: NAME=0  TAG=13  DIGEST=22

    private let imageHeader = "NAME         TAG      DIGEST"
    private let imageRow    = "nginx        alpine   sha256:abcdef123456"

    func testParseImageList_empty() {
        XCTAssertTrue(ContainerService.parseImageList("").isEmpty)
        XCTAssertTrue(ContainerService.parseImageList(imageHeader).isEmpty)
    }

    func testParseImageList_single() {
        let output = imageHeader + "\n" + imageRow
        let result = ContainerService.parseImageList(output)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name,   "nginx")
        XCTAssertEqual(result[0].tag,    "alpine")
        XCTAssertEqual(result[0].digest, "sha256:abcdef123456")
    }

    func testParseImageList_multiple() {
        let row2 = "postgres     16       sha256:deadbeef0000"
        let output = imageHeader + "\n" + imageRow + "\n" + row2
        let result = ContainerService.parseImageList(output)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[1].name, "postgres")
        XCTAssertEqual(result[1].tag,  "16")
    }

    // MARK: – parseVolumeList
    //
    // Column positions: NAME=0  TYPE=9  DRIVER=16  OPTIONS=25

    private let volumeHeader = "NAME     TYPE   DRIVER   OPTIONS"
    private let volumeRow    = "my-vol   local  local    size=1GB"

    func testParseVolumeList_empty() {
        XCTAssertTrue(ContainerService.parseVolumeList("").isEmpty)
        XCTAssertTrue(ContainerService.parseVolumeList(volumeHeader).isEmpty)
    }

    func testParseVolumeList_single() {
        let output = volumeHeader + "\n" + volumeRow
        let result = ContainerService.parseVolumeList(output)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name,    "my-vol")
        XCTAssertEqual(result[0].type,    "local")
        XCTAssertEqual(result[0].driver,  "local")
        XCTAssertEqual(result[0].options, "size=1GB")
    }

    // MARK: – parseSystemStatus

    func testParseSystemStatus_running() {
        let output = """
        STATUS    VALUE
        status    running
        appRoot   /var/lib/container
        installRoot  /usr/local
        apiserver.version  1.2.3
        """
        let result = ContainerService.parseSystemStatus(output)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.status,           "running")
        XCTAssertEqual(result?.appRoot,          "/var/lib/container")
        XCTAssertEqual(result?.installRoot,      "/usr/local")
        XCTAssertEqual(result?.apiserverVersion, "1.2.3")
        XCTAssertTrue(result?.isRunning == true)
    }

    func testParseSystemStatus_stopped() {
        let output = "HEADER\nstatus  stopped\n"
        let result = ContainerService.parseSystemStatus(output)
        XCTAssertEqual(result?.status, "stopped")
        XCTAssertFalse(result?.isRunning == true)
    }

    func testParseSystemStatus_missingStatusKey_returnsNil() {
        let output = "HEADER\nappRoot  /var/lib\n"
        XCTAssertNil(ContainerService.parseSystemStatus(output))
    }

    // MARK: – parseSystemDf
    //
    // Column positions: TYPE=0  TOTAL=11  ACTIVE=19  SIZE=27  RECLAIMABLE=35

    private let dfHeader = "TYPE       TOTAL   ACTIVE  SIZE    RECLAIMABLE"
    private let dfRow    = "Images     5       3       1GB     800MB"

    func testParseSystemDf_empty() {
        XCTAssertTrue(ContainerService.parseSystemDf("").isEmpty)
        XCTAssertTrue(ContainerService.parseSystemDf(dfHeader).isEmpty)
    }

    func testParseSystemDf_single() {
        let output = dfHeader + "\n" + dfRow
        let result = ContainerService.parseSystemDf(output)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].type,        "Images")
        XCTAssertEqual(result[0].total,       "5")
        XCTAssertEqual(result[0].active,      "3")
        XCTAssertEqual(result[0].size,        "1GB")
        XCTAssertEqual(result[0].reclaimable, "800MB")
    }

    // MARK: – parseVersionRows
    //
    // Column positions: COMPONENT=0  VERSION=12  BUILD=22

    private let versionHeader = "COMPONENT   VERSION   BUILD"
    private let versionRow    = "container   1.0.0     abc123"

    func testParseVersionRows_empty() {
        XCTAssertTrue(ContainerService.parseVersionRows("").isEmpty)
        XCTAssertTrue(ContainerService.parseVersionRows(versionHeader).isEmpty)
    }

    func testParseVersionRows_single() {
        let output = versionHeader + "\n" + versionRow
        let result = ContainerService.parseVersionRows(output)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].component, "container")
        XCTAssertEqual(result[0].version,   "1.0.0")
        XCTAssertEqual(result[0].build,     "abc123")
    }

    func testParseVersionRows_multiple() {
        let row2   = "apiserver   2.1.0     def456"
        let output = versionHeader + "\n" + versionRow + "\n" + row2
        let result = ContainerService.parseVersionRows(output)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[1].component, "apiserver")
        XCTAssertEqual(result[1].version,   "2.1.0")
        XCTAssertEqual(result[1].build,     "def456")
    }
}
