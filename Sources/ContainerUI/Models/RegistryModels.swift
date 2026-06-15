import SwiftUI

struct RegistryEntry: Identifiable {
    let id = UUID()
    let name: String
    let image: String
    let tag: String
    let category: String
    let icon: String
    let color: Color
    let defaultPorts: [(String, String)]
    let defaultMemory: String
    let defaultEnv: [String]
    var description: String = ""
    var pullCount: Int = 0
    var starCount: Int = 0
    var isOfficial: Bool = false

    var fullRef: String { "\(image):\(tag)" }
    var namespace: String { image.contains("/") ? String(image.split(separator: "/").first!) : "library" }
    var repoName: String { image.contains("/") ? String(image.split(separator: "/").dropFirst().joined(separator: "/")) : image }
}

struct RegistryCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    var entries: [RegistryEntry]
}

struct HubRepo: Codable, Identifiable {
    var id: String { repoName }
    let repoName: String
    let shortDescription: String
    let starCount: Int
    let pullCount: Int
    let isOfficial: Bool

    enum CodingKeys: String, CodingKey {
        case repoName = "repo_name"
        case shortDescription = "short_description"
        case starCount = "star_count"
        case pullCount = "pull_count"
        case isOfficial = "is_official"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        repoName         = try  c.decode(String.self, forKey: .repoName)
        shortDescription = (try? c.decode(String.self, forKey: .shortDescription)) ?? ""
        starCount        = (try? c.decode(Int.self,    forKey: .starCount))         ?? 0
        pullCount        = (try? c.decode(Int.self,    forKey: .pullCount))         ?? 0
        isOfficial       = (try? c.decode(Bool.self,   forKey: .isOfficial))        ?? false
    }
}

struct HubResponse: Codable { let results: [HubRepo] }
