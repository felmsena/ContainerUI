import Foundation

extension ContainerService {

    func inspectContainer(_ id: String) async -> ContainerDetail? {
        guard let output = try? await shell([bin, "inspect", id]),
              let data = output.data(using: .utf8)
        else { return nil }
        return Self.parseContainerDetail(data)
    }

    // MARK: – JSON parsing

    private struct ContainerInspectEntryJSON: Decodable {
        struct Configuration: Decodable {
            struct InitProcess: Decodable { let environment: [String] }
            struct Mount: Decodable { let source: String; let destination: String }
            struct PublishedPort: Decodable {
                let containerPort: Int
                let hostPort: Int
                let hostAddress: String
                let proto: String
            }
            struct Resources: Decodable { let cpus: Int; let memoryInBytes: Int }
            let initProcess: InitProcess
            let mounts: [Mount]
            let publishedPorts: [PublishedPort]
            let resources: Resources
        }
        let configuration: Configuration
    }

    nonisolated static func parseContainerDetail(_ data: Data) -> ContainerDetail? {
        guard let entries = try? JSONDecoder().decode([ContainerInspectEntryJSON].self, from: data),
              let cfg = entries.first?.configuration
        else { return nil }
        return ContainerDetail(
            environment: cfg.initProcess.environment,
            mounts: cfg.mounts.map { ContainerDetail.Mount(source: $0.source, destination: $0.destination) },
            ports: cfg.publishedPorts.map {
                ContainerDetail.PublishedPort(containerPort: $0.containerPort, hostPort: $0.hostPort,
                                               hostAddress: $0.hostAddress, proto: $0.proto)
            },
            cpus: cfg.resources.cpus,
            memoryInBytes: cfg.resources.memoryInBytes
        )
    }
}
