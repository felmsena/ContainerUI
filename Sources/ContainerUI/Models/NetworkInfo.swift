import Foundation

struct NetworkInfo: Identifiable, Hashable {
    let name: String
    var mode = ""
    var subnet = ""
    var gateway = ""
    var ipv6Subnet = ""
    var plugin = ""
    var labels: [String: String] = [:]

    var id: String { name }

    /// Networks Apple Container creates itself (e.g. "default") — can't be deleted.
    var isBuiltin: Bool { labels["com.apple.container.resource.role"] == "builtin" || name == "default" }
}
