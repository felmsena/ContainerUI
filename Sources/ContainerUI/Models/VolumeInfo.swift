import Foundation

struct VolumeInfo: Identifiable, Hashable {
    let name: String
    let type: String
    let driver: String
    let options: String

    var id: String { name }
}
