import Foundation

/// Rich per-container detail from `container inspect`, beyond what the
/// list view's `ContainerInfo` row carries.
struct ContainerDetail {
    struct Mount: Identifiable {
        var id: String { destination }
        let source: String
        let destination: String
    }

    struct PublishedPort: Identifiable {
        var id: String { "\(hostAddress):\(hostPort)-\(containerPort)/\(proto)" }
        let containerPort: Int
        let hostPort: Int
        let hostAddress: String
        let proto: String
    }

    let environment: [String]
    let mounts: [Mount]
    let ports: [PublishedPort]
    let cpus: Int
    let memoryInBytes: Int
}
