import Foundation

struct GitHubReleaseInfo: Decodable, Equatable {
    let tagName: String
    let htmlUrl: String
    let draft: Bool
    let prerelease: Bool

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
        case draft
        case prerelease
    }
}

enum UpdateChecker {
    static let releasesURL = URL(string: "https://api.github.com/repos/felmsena/ContainerUI/releases/latest")!

    static func fetchLatestRelease(session: URLSession = .shared) async throws -> GitHubReleaseInfo {
        var request = URLRequest(url: releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(GitHubReleaseInfo.self, from: data)
    }

    /// Compares two version strings ignoring an optional leading "v" and any
    /// "-prerelease"/"+build" suffix. Missing components compare as 0, so
    /// "1.2" == "1.2.0" and "1.10.0" > "1.9.0" (not a lexicographic compare).
    nonisolated static func isNewer(_ remote: String, than local: String) -> Bool {
        let r = components(remote)
        let l = components(local)
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv != lv { return rv > lv }
        }
        return false
    }

    private static func components(_ version: String) -> [Int] {
        var s = Substring(version)
        if s.hasPrefix("v") { s = s.dropFirst() }
        if let cut = s.firstIndex(where: { $0 == "-" || $0 == "+" }) {
            s = s[s.startIndex..<cut]
        }
        return s.split(separator: ".").map { Int($0) ?? 0 }
    }
}
