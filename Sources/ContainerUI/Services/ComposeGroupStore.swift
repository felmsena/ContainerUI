import Foundation

/// Persists the list of compose-lite group YAML files the user has
/// created or opened, so they reappear in the Groups sidebar across
/// launches. The app isn't sandboxed, so a plain absolute path is enough —
/// no security-scoped bookmark needed. Files that have since been moved or
/// deleted are dropped silently on load rather than shown as broken rows.
enum ComposeGroupStore {
    private static let key = "composeGroupPaths"
    private static let defaults = UserDefaults.standard

    static func load() -> [URL] {
        let paths = defaults.array(forKey: key) as? [String] ?? []
        return paths
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    static func add(_ url: URL) {
        var paths = defaults.array(forKey: key) as? [String] ?? []
        paths.removeAll { $0 == url.path }
        paths.insert(url.path, at: 0)
        defaults.set(paths, forKey: key)
    }

    static func remove(_ url: URL) {
        var paths = defaults.array(forKey: key) as? [String] ?? []
        paths.removeAll { $0 == url.path }
        defaults.set(paths, forKey: key)
    }
}
