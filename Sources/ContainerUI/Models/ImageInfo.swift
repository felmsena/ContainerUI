import Foundation

struct ImageInfo: Identifiable, Hashable {
    let name: String
    let tag: String
    let digest: String

    var id: String { "\(name):\(tag)" }
    var ref: String { "\(name):\(tag)" }
    var shortDigest: String { String(digest.prefix(12)) }

    var shortName: String {
        name.components(separatedBy: "/").last ?? name
    }
}
