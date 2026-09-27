import XCTest
@testable import ContainerUI

/// Checks every flag the app passes against the *installed* CLI's `--help`,
/// so a renamed or removed flag (like `logs --tail` → `-n` in 1.4) fails
/// here instead of silently in the UI. Skipped when `container` isn't
/// installed; plugin subcommands (image, volume, network, builder, system,
/// registry) are skipped while its services are stopped.
final class CLIContractTests: XCTestCase {

    /// (subcommand path, a sample argument list built by `CLI`/`RunSpec`).
    private var samples: [([String], [String])] {
        var run = RunSpec(image: "img", name: "n", memory: "1G", cpus: 2, ports: ["1:1"], volumes: ["a:/a"], env: ["A=1"],
                          envFile: "f", network: "net", platform: "linux/amd64", rosetta: true, removeOnExit: true,
                          entrypoint: "e", workdir: "/w", user: "u", labels: ["l=1"], readOnly: true, useInit: true, forwardSSH: true)
        run.command = "x"
        return [
            (["run"], run.arguments),
            (["list"], CLI.list()),
            (["delete"], CLI.delete("x")),
            (["logs"], CLI.logs("x", lines: 5, follow: true, boot: true)),
            (["stats"], CLI.stats(["x"])),
            (["exec"], CLI.interactiveShell("x")),
            (["export"], CLI.export("x", to: "/tmp/x.tar")),
            (["build"], CLI.build(tag: "t", contextDir: ".", buildArgs: ["A=1"])),
            (["image", "pull"], CLI.imagePull("x")),
            (["image", "list"], CLI.imageList() + ["--format", "json"]),
            (["image", "delete"], CLI.imageDelete("x")),
            (["volume", "list"], CLI.volumeList() + ["--format", "json"]),
            (["network", "create"], CLI.networkCreate("n", subnet: "10.0.0.0/24", internal: true)),
            (["network", "list"], CLI.networkList() + ["--format", "json"]),
            (["network", "delete"], CLI.networkDelete("n")),
            (["network", "prune"], CLI.networkPrune()),
            (["system", "dns", "list"], CLI.dnsList()),
            (["builder", "start"], CLI.builderStart(cpus: 2, memory: "4G")),
            (["builder", "status"], CLI.builderStatus()),
            (["system", "logs"], CLI.systemLogs(last: "5m", follow: true)),
            (["system", "status"], CLI.systemStatus() + ["--format", "json"]),
            (["registry", "login"], CLI.registryLogin(server: "s", username: "u")),
        ]
    }

    func testEveryFlagExistsInInstalledCLI() async throws {
        guard let bin = ContainerBinary.resolve() else { throw XCTSkip("container CLI not installed") }
        var skipped: [String] = []
        for (path, args) in samples {
            XCTAssertEqual(Array(args.prefix(path.count)), path, "sample for \(path) doesn't start with its path")
            let output = try await ProcessRunner.run([bin] + path + ["--help"], timeout: 20).get()
            let help = output.stdout + output.stderr
            if help.contains("Plugin") && (help.contains("not found") || help.contains("unavailable")) {
                skipped.append(path.joined(separator: " "))
                continue
            }
            for flag in args where flag.hasPrefix("-") && !path.contains(flag) {
                // Command arguments after the image (e.g. "-c") aren't CLI flags.
                if path == ["run"], let imageIndex = args.firstIndex(of: "img"), args.firstIndex(of: flag)! > imageIndex { continue }
                let pattern = "(^|[\\s,])\(NSRegularExpression.escapedPattern(for: flag))([\\s,=<]|$)"
                XCTAssertNotNil(help.range(of: pattern, options: .regularExpression),
                                "`container \(path.joined(separator: " "))` no longer accepts \(flag)")
            }
        }
        if !skipped.isEmpty { print("CLIContractTests: services stopped, skipped \(skipped)") }
    }
}
