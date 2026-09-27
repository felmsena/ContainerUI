import XCTest
@testable import ContainerUI

/// A `CommandRunning` that answers from a closure instead of spawning
/// processes, recording every invocation.
final class FakeRunner: CommandRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls: [[String]] = []
    var handler: ([String]) -> Result<ProcessOutput, CLIError>

    init(_ handler: @escaping ([String]) -> Result<ProcessOutput, CLIError>) { self.handler = handler }

    var calls: [[String]] { lock.lock(); defer { lock.unlock() }; return _calls }

    func run(_ args: [String], stdin: String?, timeout: TimeInterval?) async -> Result<ProcessOutput, CLIError> {
        lock.lock(); _calls.append(args); lock.unlock()
        return handler(args)
    }

    static func ok(_ stdout: String) -> Result<ProcessOutput, CLIError> {
        .success(ProcessOutput(stdout: stdout, stderr: "", exitCode: 0))
    }
    static func fail(_ stderr: String, code: Int32 = 1) -> Result<ProcessOutput, CLIError> {
        .success(ProcessOutput(stdout: "", stderr: stderr, exitCode: code))
    }
}

@MainActor
final class ContainerServiceBehaviorTests: XCTestCase {

    private let bin = "/fake/container"

    private let runningJSON = """
    [{"configuration":{"image":{"reference":"docker.io/library/nginx:alpine"},
      "platform":{"architecture":"arm64","os":"linux"},"resources":{"cpus":1,"memoryInBytes":536870912}},
      "id":"web","status":{"networks":[{"ipv4Address":"192.168.64.3/24","network":"default"}],"state":"running"}}]
    """

    func testFetchContainers_success_setsRunningAndContainers() async {
        let runner = FakeRunner { _ in FakeRunner.ok(self.runningJSON) }
        let service = ContainerService(runner: runner, binary: bin, startBackgroundWork: false)
        await service.fetchContainers()
        XCTAssertEqual(service.daemonState, .running)
        XCTAssertEqual(service.containers.map(\.id), ["web"])
        XCTAssertFalse(service.isLoading)
        XCTAssertEqual(runner.calls.first, [bin, "list", "--all", "--format", "json"])
    }

    func testFetchContainers_serviceDown_setsNotRunning_withoutTextRetry() async {
        let runner = FakeRunner { _ in FakeRunner.fail("Error: interrupted: \"XPC connection error: Connection invalid\"") }
        let service = ContainerService(runner: runner, binary: bin, startBackgroundWork: false)
        await service.fetchContainers()
        XCTAssertEqual(service.daemonState, .notRunning)
        XCTAssertNil(service.serviceError)
        XCTAssertEqual(runner.calls.count, 1, "a service-down error must not trigger the text-format retry")
    }

    func testFetchContainers_otherError_surfacesServiceError() async {
        let runner = FakeRunner { _ in FakeRunner.fail("Error: something odd") }
        let service = ContainerService(runner: runner, binary: bin, startBackgroundWork: false)
        await service.fetchContainers()
        XCTAssertEqual(service.serviceError, "Error: something odd")
    }

    func testFetchJSONOrText_undecodableJSON_fallsBackOnce_thenSkipsJSON() async {
        let table = """
        ID   IMAGE  OS     ARCH   STATE    IP  CPUS  MEMORY  STARTED
        web  nginx  linux  arm64  running      1     512 MB
        """
        let runner = FakeRunner { args in
            args.contains("json") ? FakeRunner.ok("not json") : FakeRunner.ok(table)
        }
        let service = ContainerService(runner: runner, binary: bin, startBackgroundWork: false)
        await service.fetchContainers()
        await service.fetchContainers()
        XCTAssertEqual(service.containers.map(\.id), ["web"])
        XCTAssertEqual(runner.calls.filter { $0.contains("json") }.count, 1)
    }

    func testBuilderContainer_isKeptOutOfContainerList() async {
        let json = """
        [{"configuration":{"image":{"reference":"ghcr.io/apple/container-builder-shim/builder:0.12.0"},
          "labels":{"com.apple.container.resource.role":"builder"},
          "platform":{"architecture":"arm64","os":"linux"},"resources":{"cpus":2,"memoryInBytes":2147483648}},
          "id":"buildkit","status":{"networks":[],"state":"stopped"}}]
        """
        let service = ContainerService(runner: FakeRunner { _ in FakeRunner.ok(json) }, binary: bin, startBackgroundWork: false)
        await service.fetchContainers()
        XCTAssertTrue(service.containers.isEmpty)
        XCTAssertEqual(service.builderContainer?.id, "buildkit")
    }

    // MARK: - Actions & notifications

    func testUnexpectedStops_excludesUserInitiatedStops() {
        let result = ContainerService.unexpectedStops(previous: ["a", "b", "c"], current: ["c"], expected: ["a"])
        XCTAssertEqual(result, ["b"])
    }

    func testFailedAction_isReportedAsToast_andPendingIsCleared() async {
        let runner = FakeRunner { args in
            args.contains("stop") ? FakeRunner.fail("Error: container not found") : FakeRunner.ok(self.runningJSON)
        }
        let service = ContainerService(runner: runner, binary: bin, startBackgroundWork: false)
        await service.stop("web")
        XCTAssertEqual(service.toasts.count, 1)
        XCTAssertEqual(service.toasts.first?.style, .error)
        XCTAssertEqual(service.toasts.first?.message, "Error: container not found")
        XCTAssertTrue(service.pendingContainers.isEmpty)
    }

    func testRemove_isSingleForcedDelete() async {
        let runner = FakeRunner { _ in FakeRunner.ok("[]") }
        let service = ContainerService(runner: runner, binary: bin, startBackgroundWork: false)
        await service.remove("web")
        XCTAssertEqual(runner.calls.first, [bin, "delete", "--force", "web"])
        XCTAssertTrue(service.toasts.isEmpty)
    }
}
