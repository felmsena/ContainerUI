import XCTest
@testable import ContainerUI

final class CLICommandsTests: XCTestCase {

    func testLogs_usesDashN_notTail() {
        XCTAssertEqual(CLI.logs("web", lines: 100), ["logs", "-n", "100", "web"])
        XCTAssertEqual(CLI.logs("web", lines: nil, follow: true, boot: true), ["logs", "--follow", "--boot", "web"])
    }

    func testDelete_forcesSoRunningContainersNeedNoSeparateStop() {
        XCTAssertEqual(CLI.delete("web"), ["delete", "--force", "web"])
    }

    func testImagePull_requestsPlainProgress() {
        XCTAssertEqual(CLI.imagePull("nginx:alpine"), ["image", "pull", "--progress", "plain", "nginx:alpine"])
    }

    func testBuild() {
        XCTAssertEqual(CLI.build(tag: "app:1", contextDir: "/src", buildArgs: ["A=1"]),
                       ["build", "--tag", "app:1", "--progress", "plain", "--build-arg", "A=1", "/src"])
    }

    func testNetworkCreate_optionalFlags() {
        XCTAssertEqual(CLI.networkCreate("n"), ["network", "create", "n"])
        XCTAssertEqual(CLI.networkCreate("n", subnet: "10.0.0.0/24", internal: true),
                       ["network", "create", "--subnet", "10.0.0.0/24", "--internal", "n"])
    }

    func testSystemLogs() {
        XCTAssertEqual(CLI.systemLogs(last: "1h", follow: true), ["system", "logs", "--last", "1h", "--follow"])
    }

    // MARK: - RunSpec

    func testRunSpec_minimal_alwaysDetachesAndSetsResources() {
        let spec = RunSpec(image: "nginx:alpine")
        XCTAssertEqual(spec.arguments, ["run", "--detach", "--memory", "512M", "--cpus", "1", "nginx:alpine"])
    }

    func testRunSpec_nilResources_areOmitted() {
        let spec = RunSpec(image: "redis", memory: nil, cpus: nil)
        XCTAssertEqual(spec.arguments, ["run", "--detach", "redis"])
    }

    func testRunSpec_full() {
        var spec = RunSpec(image: " app:1 ", name: " web ", memory: "1G", cpus: 2)
        spec.ports = ["8080:80", " "]
        spec.volumes = ["data:/data"]
        spec.env = ["A=b c"]
        spec.envFile = "/tmp/.env"
        spec.labels = ["team=core"]
        spec.network = "backend"
        spec.platform = "linux/amd64"
        spec.rosetta = true
        spec.removeOnExit = true
        spec.entrypoint = "/bin/sh"
        spec.workdir = "/app"
        spec.user = "1000"
        spec.readOnly = true
        spec.useInit = true
        spec.forwardSSH = true
        spec.command = "-c \"echo hi\""
        XCTAssertEqual(spec.arguments, [
            "run", "--detach", "--name", "web", "--memory", "1G", "--cpus", "2",
            "--publish", "8080:80", "--volume", "data:/data", "--env", "A=b c",
            "--env-file", "/tmp/.env", "--label", "team=core", "--network", "backend",
            "--platform", "linux/amd64", "--rosetta", "--rm", "--entrypoint", "/bin/sh",
            "--workdir", "/app", "--user", "1000", "--read-only", "--init", "--ssh",
            "app:1", "-c", "echo hi",
        ])
    }

    func testRunSpec_commandLine_quotesOnlyWhatNeedsIt() {
        var spec = RunSpec(image: "alpine", memory: nil, cpus: nil)
        spec.env = ["GREETING=hello world"]
        XCTAssertEqual(spec.commandLine(bin: "/opt/homebrew/bin/container"),
                       "/opt/homebrew/bin/container run --detach --env 'GREETING=hello world' alpine")
    }
}
