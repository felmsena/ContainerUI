import Foundation

/// Argument lists (without the binary path) for every `container`
/// subcommand the app runs — the single place flags are spelled, so a CLI
/// change is fixed once and `CLIContractTests` can check every flag against
/// the installed CLI's `--help`.
enum CLI {
    // MARK: Containers
    static func list() -> [String] { ["list", "--all"] }
    static func start(_ id: String) -> [String] { ["start", id] }
    static func stop(_ id: String) -> [String] { ["stop", id] }
    static func kill(_ id: String) -> [String] { ["kill", id] }
    /// `--force` stops a running container first, in one call.
    static func delete(_ id: String) -> [String] { ["delete", "--force", id] }
    static func prune() -> [String] { ["prune"] }
    static func inspect(_ id: String) -> [String] { ["inspect", id] }
    static func exec(_ id: String, _ args: [String]) -> [String] { ["exec", id] + args }
    static func interactiveShell(_ id: String) -> [String] { ["exec", "--tty", "--interactive", id, "sh"] }
    static func copy(from source: String, to destination: String) -> [String] { ["copy", source, destination] }
    static func export(_ id: String, to path: String) -> [String] { ["export", "--output", path, id] }

    /// `lines: nil` fetches the whole log. `boot` shows the VM boot log
    /// instead of the container's stdio.
    static func logs(_ id: String, lines: Int?, follow: Bool = false, boot: Bool = false) -> [String] {
        var args = ["logs"]
        if let lines { args += ["-n", "\(lines)"] }
        if follow { args.append("--follow") }
        if boot { args.append("--boot") }
        return args + [id]
    }

    /// One JSON sample; with no ids, every running container.
    static func stats(_ ids: [String] = []) -> [String] { ["stats", "--format", "json", "--no-stream"] + ids }

    // MARK: Images
    static func imageList() -> [String] { ["image", "list"] }
    static func imagePull(_ ref: String) -> [String] { ["image", "pull", "--progress", "plain", ref] }
    static func imageDelete(_ ref: String) -> [String] { ["image", "delete", ref] }
    static func build(tag: String, contextDir: String, buildArgs: [String]) -> [String] {
        var args = ["build", "--tag", tag, "--progress", "plain"]
        for arg in buildArgs { args += ["--build-arg", arg] }
        return args + [contextDir]
    }

    // MARK: Volumes
    static func volumeList() -> [String] { ["volume", "list"] }
    static func volumeCreate(_ name: String) -> [String] { ["volume", "create", name] }
    static func volumeDelete(_ name: String) -> [String] { ["volume", "delete", name] }
    static func volumePrune() -> [String] { ["volume", "prune"] }

    // MARK: Networks
    static func networkList() -> [String] { ["network", "list"] }
    static func networkCreate(_ name: String, subnet: String? = nil, internal: Bool = false) -> [String] {
        var args = ["network", "create"]
        if let subnet, !subnet.isEmpty { args += ["--subnet", subnet] }
        if `internal` { args.append("--internal") }
        return args + [name]
    }
    static func networkDelete(_ name: String) -> [String] { ["network", "delete", name] }
    static func networkPrune() -> [String] { ["network", "prune"] }

    // MARK: Builder
    static func builderStatus() -> [String] { ["builder", "status", "--format", "json"] }
    static func builderStart(cpus: Int?, memory: String?) -> [String] {
        var args = ["builder", "start"]
        if let cpus { args += ["--cpus", "\(cpus)"] }
        if let memory { args += ["--memory", memory] }
        return args
    }
    static func builderStop() -> [String] { ["builder", "stop"] }
    static func builderDelete() -> [String] { ["builder", "delete"] }

    // MARK: System
    static func systemStart() -> [String] { ["system", "start"] }
    static func systemStop() -> [String] { ["system", "stop"] }
    static func systemStatus() -> [String] { ["system", "status"] }
    static func systemDf() -> [String] { ["system", "df"] }
    static func systemVersion() -> [String] { ["system", "version"] }
    /// `last` is a CLI duration such as "5m", "1h" or "1d".
    static func systemLogs(last: String?, follow: Bool = false) -> [String] {
        var args = ["system", "logs"]
        if let last { args += ["--last", last] }
        if follow { args.append("--follow") }
        return args
    }
    static func dnsList() -> [String] { ["system", "dns", "list", "--quiet"] }
    static func dnsCreate(_ domain: String) -> [String] { ["system", "dns", "create", domain] }
    static func dnsDelete(_ domain: String) -> [String] { ["system", "dns", "delete", domain] }

    // MARK: Registries
    static func registryList() -> [String] { ["registry", "list"] }
    static func registryLogin(server: String, username: String) -> [String] {
        ["registry", "login", "--username", username, "--password-stdin", server]
    }
    static func registryLogout(_ server: String) -> [String] { ["registry", "logout", server] }
}

/// Everything `container run` can be given from the Run sheet (and from
/// compose-lite groups). `arguments` is what's executed *and* what the
/// sheet's command preview shows, so the two can't drift apart.
struct RunSpec: Equatable {
    var image = ""
    var name = ""
    /// `nil` leaves the CLI default (compose services don't set resources).
    var memory: String? = "512M"
    var cpus: Int? = 1
    var ports: [String] = []      // "host:container[/proto]"
    var volumes: [String] = []    // "source:target"
    var env: [String] = []        // "KEY=VALUE"
    var envFile = ""
    var network = ""
    var platform = ""             // e.g. "linux/amd64"; empty = native
    var rosetta = false
    var removeOnExit = false
    var entrypoint = ""
    var command = ""              // tokenized like the Shell tab
    var workdir = ""
    var user = ""
    var labels: [String] = []     // "key=value"
    var readOnly = false
    var useInit = false
    var forwardSSH = false

    private func trimmed(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }

    var arguments: [String] {
        // --detach: without it `container run` stays attached until the
        // container exits.
        var args = ["run", "--detach"]
        if !trimmed(name).isEmpty { args += ["--name", trimmed(name)] }
        if let memory { args += ["--memory", memory] }
        if let cpus { args += ["--cpus", "\(cpus)"] }
        for p in ports where !trimmed(p).isEmpty { args += ["--publish", trimmed(p)] }
        for v in volumes where !trimmed(v).isEmpty { args += ["--volume", trimmed(v)] }
        for e in env where !trimmed(e).isEmpty { args += ["--env", e] }
        if !trimmed(envFile).isEmpty { args += ["--env-file", trimmed(envFile)] }
        for l in labels where !trimmed(l).isEmpty { args += ["--label", trimmed(l)] }
        if !trimmed(network).isEmpty { args += ["--network", trimmed(network)] }
        if !trimmed(platform).isEmpty { args += ["--platform", trimmed(platform)] }
        if rosetta { args.append("--rosetta") }
        if removeOnExit { args.append("--rm") }
        if !trimmed(entrypoint).isEmpty { args += ["--entrypoint", trimmed(entrypoint)] }
        if !trimmed(workdir).isEmpty { args += ["--workdir", trimmed(workdir)] }
        if !trimmed(user).isEmpty { args += ["--user", trimmed(user)] }
        if readOnly { args.append("--read-only") }
        if useInit { args.append("--init") }
        if forwardSSH { args.append("--ssh") }
        args.append(trimmed(image))
        args += ContainerService.tokenizeCommand(command)
        return args
    }

    /// Shell-quoted, copy-pasteable form of `arguments` for the preview.
    func commandLine(bin: String) -> String {
        ([bin] + arguments).map(Self.quoteIfNeeded).joined(separator: " ")
    }

    private static func quoteIfNeeded(_ arg: String) -> String {
        let safe = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_./:=@,+%"))
        if !arg.isEmpty, arg.unicodeScalars.allSatisfy(safe.contains) { return arg }
        return ContainerService.shellQuote(arg)
    }
}
