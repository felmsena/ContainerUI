import Foundation

enum ComposeServiceState: Equatable {
    case pending
    case starting
    case running
    case stopping
    case stopped
    case failed(String)
}

/// What `composeUp` does for one service, given its container's state.
enum ComposeAction: Equatable {
    case run      // no container yet: `container run`
    case start    // exists but stopped: `container start`
    case keep     // already running: nothing to do
}

extension ContainerService {
    /// Group names come from file names, which may contain spaces, capitals
    /// or punctuation that aren't valid in container/network names. Keeps
    /// lowercase letters, digits, '_' and '.', turning anything else into '-'.
    nonisolated static func sanitizedGroupName(_ group: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789_.")
        let mapped = group.lowercased().map { allowed.contains($0) ? $0 : "-" }
        var name = String(mapped)
        while name.contains("--") { name = name.replacingOccurrences(of: "--", with: "-") }
        name = name.trimmingCharacters(in: CharacterSet(charactersIn: "-_."))
        return name.isEmpty ? "group" : name
    }

    /// The `container network` name used for every service in a group, so
    /// services can reach each other by container name.
    nonisolated static func composeNetworkName(group: String) -> String { "compose-\(sanitizedGroupName(group))" }

    /// The actual `container run --name` used for one service, namespaced
    /// by group so the same service name in two groups can't collide.
    nonisolated static func composeContainerName(group: String, service: String) -> String {
        "\(sanitizedGroupName(group))-\(service)"
    }

    nonisolated static func composeAction(existing: ContainerState?) -> ComposeAction {
        switch existing {
        case nil: return .run
        case .running?: return .keep
        default: return .start
        }
    }

    /// Brings a compose-lite group up: creates the group's network if
    /// needed, then handles each service in dependency order — creating its
    /// container, starting it if it already exists stopped, or leaving it if
    /// it's running — so "Up" can be pressed again safely. A service whose
    /// dependency failed is skipped rather than started against a missing
    /// dependency. A malformed group (bad YAML or a dependency cycle) fails
    /// before anything is started.
    func composeUp(group: String, services: ComposeGroup) async -> Result<Void, ComposeParseError> {
        let ordered: [ComposeService]
        switch ComposeParser.topologicalOrder(services) {
        case .success(let o): ordered = o
        case .failure(let e): return .failure(e)
        }

        await fetchContainers()
        let network = Self.composeNetworkName(group: group)
        _ = try? await cli(CLI.networkCreate(network))

        var failed: Set<String> = []
        for service in ordered {
            let name = Self.composeContainerName(group: group, service: service.name)
            if let blocker = service.dependsOn.first(where: failed.contains) {
                composeState[name] = .failed(String(localized: "Skipped: \(blocker) failed to start"))
                failed.insert(service.name)
                continue
            }
            composeState[name] = .starting
            let existing = containers.first { $0.id == name }?.state
            do {
                switch Self.composeAction(existing: existing) {
                case .keep:
                    break
                case .start:
                    try await cli(CLI.start(name))
                case .run:
                    let spec = RunSpec(image: service.image, name: name, memory: nil, cpus: nil,
                                       ports: service.ports, volumes: service.volumes, env: service.env,
                                       network: network)
                    try await cli(spec.arguments, timeout: nil)
                }
                composeState[name] = .running
            } catch {
                composeState[name] = .failed(error.localizedDescription)
                failed.insert(service.name)
            }
        }

        await fetchContainers()
        return .success(())
    }

    /// Brings a group down: removes each service's container in reverse
    /// dependency order (dependents before what they depend on), then the
    /// group's network. Best-effort on each container — one failing doesn't
    /// block the rest.
    func composeDown(group: String, services: ComposeGroup) async {
        let ordered: [ComposeService]
        switch ComposeParser.topologicalOrder(services) {
        case .success(let o): ordered = o.reversed()
        case .failure: ordered = services.services.reversed()
        }

        for service in ordered {
            let name = Self.composeContainerName(group: group, service: service.name)
            composeState[name] = .stopping
            _ = try? await cli(CLI.delete(name))
            composeState[name] = .stopped
        }
        _ = try? await cli(CLI.networkDelete(Self.composeNetworkName(group: group)))

        await fetchContainers()
    }
}
