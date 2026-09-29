import Foundation

struct ImageInfo: Identifiable, Hashable {
    let name: String
    let tag: String
    let digest: String

    var id: String { "\(name):\(tag)" }
    var ref: String { "\(name):\(tag)" }
    var shortDigest: String { String(digest.prefix(12)) }

    /// Images Apple Container itself manages (the VM init image, the
    /// builder shim) — never shown as "unused" or offered for pruning.
    var isSystem: Bool { name.hasPrefix("ghcr.io/apple/") }

    var shortName: String {
        name.components(separatedBy: "/").last ?? name
    }
}
