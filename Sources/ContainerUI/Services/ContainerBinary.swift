import Foundation

/// Locates the `container` CLI. GUI apps don't inherit the shell's PATH, so
/// well-known install locations are probed instead: Homebrew on Apple
/// Silicon, and `/usr/local/bin`, where Apple's signed `.pkg` installer puts
/// it. A path chosen in Settings takes precedence.
enum ContainerBinary {
    static let overrideKey = "containerBinaryPath"
    static let candidates = ["/opt/homebrew/bin/container", "/usr/local/bin/container"]

    /// The first executable among the override (if set) and the candidates,
    /// or `nil` when none exists.
    static func resolve(
        override: String? = UserDefaults.standard.string(forKey: overrideKey),
        isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) -> String? {
        let custom = override?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let paths = (custom.isEmpty ? [] : [custom]) + candidates
        return paths.first(where: isExecutable)
    }
}
