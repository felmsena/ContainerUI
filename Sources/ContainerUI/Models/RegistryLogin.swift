import Foundation

struct RegistryLogin: Identifiable, Hashable {
    var id: String { hostname }
    let hostname: String
    let username: String
}
