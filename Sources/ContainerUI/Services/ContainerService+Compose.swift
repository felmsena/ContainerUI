import Foundation

enum ComposeServiceState: Equatable {
    case pending
    case starting
    case running
    case stopping
    case stopped
    case failed(String)
}

extension ContainerService {
    /// The `container network` name used for every service in a group, so
    /// services can reach each other by container name.
    nonisolated static func composeNetworkName(group: String) -> String { "compose-\(group)" }

    /// The actual `container run --name` used for one service, namespaced
    /// by group so the same service name in two groups can't collide.
    nonisolated static func composeContainerName(group: String, service: String) -> String { "\(group)-\(service)" }

    /// Brings a compose-lite group up: creates the group's network if
    /// needed, then runs each service in dependency order (so a service
    /// only starts once everything it `depends_on` is already running).
    /// Publishes per-container state to `composeState` as it progresses;
    /// a malformed group (bad YAML or a dependency cycle) fails before
    /// anything is started.
    func composeUp(group: String, services: ComposeGroup) async -> Result<Void, ComposeParseError> {
        let ordered: [ComposeService]
        switch ComposeParser.topologicalOrder(services) {
        case .success(let o): ordered = o
        case .failure(let e): return .failure(e)
        }

        let network = Self.composeNetworkName(group: group)
        _ = try? await shell([bin, "network", "create", network])

        for service in ordered {
            let name = Self.composeContainerName(group: group, service: service.name)
            composeState[name] = .starting

            var args = [bin, "run", "-d", "--name", name, "--network", network]
            for port in service.ports { args += ["-p", port] }
            for env in service.env { args += ["-e", env] }
            for volume in service.volumes { args += ["-v", volume] }
            args.append(service.image)

            do {
                try await shell(args)
                composeState[name] = .running
            } catch {
                composeState[name] = .failed(error.localizedDescription)
            }
        }

        await fetchContainers()
        return .success(())
    }

    /// Brings a group down: stops and removes each service's container in
    /// reverse dependency order (dependents before what they depend on),
    /// so e.g. a web frontend stops before its database. Best-effort on
    /// each container — one failing to stop/remove doesn't block the rest.
    func composeDown(group: String, services: ComposeGroup) async {
        let ordered: [ComposeService]
        switch ComposeParser.topologicalOrder(services) {
        case .success(let o): ordered = o.reversed()
        case .failure: ordered = services.services.reversed()
        }

        for service in ordered {
            let name = Self.composeContainerName(group: group, service: service.name)
            composeState[name] = .stopping
            _ = try? await shell([bin, "stop", name])
            _ = try? await shell([bin, "rm", name])
            composeState[name] = .stopped
        }

        await fetchContainers()
    }
}
