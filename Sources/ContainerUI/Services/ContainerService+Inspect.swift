import Foundation

extension ContainerService {

    func inspectContainer(_ id: String) async -> ContainerDetail? {
        guard let output = try? await cli(CLI.inspect(id)) else { return nil }
        return Self.parseContainerDetail(Data(output.utf8))
    }

    /// The container's configuration as a Run sheet spec (name cleared, so
    /// the copy gets its own), or `nil` with a toast if it can't be read.
    func duplicateSpec(for id: String) async -> RunSpec? {
        guard let detail = await inspectContainer(id) else {
            showToast(Toast(title: String(localized: "Couldn't read the configuration of \(id)"), style: .error))
            return nil
        }
        var spec = detail.runSpec
        spec.name = ""
        return spec
    }

    // MARK: – JSON parsing

    private struct ContainerInspectEntryJSON: Decodable {
        struct Configuration: Decodable {
            struct ImageRef: Decodable { let reference: String }
            struct InitProcess: Decodable {
                struct User: Decodable {
                    struct ID: Decodable { let uid: Int; let gid: Int }
                    let id: ID?
                    let raw: String?
                }
                let environment: [String]
                let executable: String?
                let arguments: [String]?
                let workingDirectory: String?
                let user: User?
            }
            struct Mount: Decodable {
                struct Kind: Decodable {
                    struct Volume: Decodable { let name: String }
                    let volume: Volume?
                    let tmpfs: [String: String]?
                }
                let source: String
                let destination: String
                let type: Kind?
            }
            struct PublishedPort: Decodable {
                let containerPort: Int
                let hostPort: Int
                let hostAddress: String
                let proto: String
            }
            struct Resources: Decodable { let cpus: Int; let memoryInBytes: Int }
            struct Network: Decodable { let network: String }
            struct Platform: Decodable { let os: String; let architecture: String }
            let image: ImageRef?
            let initProcess: InitProcess
            let mounts: [Mount]
            let publishedPorts: [PublishedPort]
            let resources: Resources
            let labels: [String: String]?
            let networks: [Network]?
            let platform: Platform?
            let readOnly: Bool?
            let rosetta: Bool?
            let ssh: Bool?
            let useInit: Bool?
        }
        let configuration: Configuration
    }

    nonisolated static func parseContainerDetail(_ data: Data) -> ContainerDetail? {
        guard let entries = try? JSONDecoder().decode([ContainerInspectEntryJSON].self, from: data),
              let cfg = entries.first?.configuration
        else { return nil }

        var spec = RunSpec(image: cfg.image?.reference ?? "")
        spec.memory = memorySpec(cfg.resources.memoryInBytes)
        spec.cpus = cfg.resources.cpus
        spec.ports = cfg.publishedPorts.map { p in
            let proto = p.proto.lowercased() == "udp" ? "/udp" : ""
            let host = p.hostAddress.isEmpty || p.hostAddress == "0.0.0.0" ? "" : "\(p.hostAddress):"
            return "\(host)\(p.hostPort):\(p.containerPort)\(proto)"
        }
        spec.volumes = cfg.mounts.compactMap { m in
            if m.type?.tmpfs != nil { return nil }
            if let name = m.type?.volume?.name { return "\(name):\(m.destination)" }
            return m.source.isEmpty ? nil : "\(m.source):\(m.destination)"
        }
        // PATH is baked into every image; repeating it would only add noise.
        spec.env = cfg.initProcess.environment.filter { !$0.hasPrefix("PATH=") }
        if let network = cfg.networks?.first?.network, network != "default" { spec.network = network }
        if cfg.platform?.architecture == "amd64" { spec.platform = "linux/amd64" }
        spec.rosetta = cfg.rosetta ?? false
        spec.readOnly = cfg.readOnly ?? false
        spec.forwardSSH = cfg.ssh ?? false
        spec.useInit = cfg.useInit ?? false
        spec.labels = (cfg.labels ?? [:]).sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }
        // The resolved process (image ENTRYPOINT + CMD, or the overrides it
        // was started with) — reproduced exactly as entrypoint + arguments.
        if let executable = cfg.initProcess.executable, !executable.isEmpty {
            spec.entrypoint = executable
            spec.command = (cfg.initProcess.arguments ?? []).map(Self.commandQuote).joined(separator: " ")
        }
        if let wd = cfg.initProcess.workingDirectory, wd != "/" { spec.workdir = wd }
        if let raw = cfg.initProcess.user?.raw, !raw.isEmpty {
            spec.user = raw
        } else if let id = cfg.initProcess.user?.id, id.uid != 0 || id.gid != 0 {
            spec.user = "\(id.uid):\(id.gid)"
        }

        return ContainerDetail(
            environment: cfg.initProcess.environment,
            mounts: cfg.mounts.map { ContainerDetail.Mount(source: $0.source, destination: $0.destination) },
            ports: cfg.publishedPorts.map {
                ContainerDetail.PublishedPort(containerPort: $0.containerPort, hostPort: $0.hostPort,
                                               hostAddress: $0.hostAddress, proto: $0.proto)
            },
            cpus: cfg.resources.cpus,
            memoryInBytes: cfg.resources.memoryInBytes,
            runSpec: spec
        )
    }

    /// "268435456" → "256M", "2147483648" → "2G" (the `--memory` syntax).
    nonisolated static func memorySpec(_ bytes: Int) -> String {
        let mib = bytes / (1024 * 1024)
        if mib > 0, mib % 1024 == 0 { return "\(mib / 1024)G" }
        return "\(max(mib, 1))M"
    }

    /// Quotes one argument for `RunSpec.command`, which is split back with
    /// `tokenizeCommand` (single/double quotes, no escapes).
    nonisolated static func commandQuote(_ arg: String) -> String {
        if !arg.isEmpty, !arg.contains(where: { $0.isWhitespace || $0 == "\"" || $0 == "'" }) { return arg }
        return arg.contains("\"") ? "'\(arg)'" : "\"\(arg)\""
    }
}
