import Foundation

struct VolumeInfo: Identifiable, Hashable {
    let name: String
    let type: String
    let driver: String
    let options: String
    /// Backing disk image on the host, and its size — CLI 1.4 JSON only.
    var source: String = ""
    var sizeInBytes: Int?

    var id: String { name }
}
