import Foundation

extension ContainerService {
    /// Detects `Dockerfile` or `Containerfile` directly under `dir`, for UI
    /// validation before starting a build. `container build` itself already
    /// falls back from Dockerfile to Containerfile with no `-f` flag needed.
    nonisolated static func detectBuildFile(in dir: URL) -> String? {
        let fm = FileManager.default
        for name in ["Dockerfile", "Containerfile"] {
            let candidate = dir.appendingPathComponent(name)
            if fm.fileExists(atPath: candidate.path) { return name }
        }
        return nil
    }
}

extension ContainerService {
    /// (Re)starts BuildKit with the given resources. A builder that already
    /// exists keeps the resources it was created with, so changing them
    /// means deleting it first.
    func startBuilder(cpus: Int, memory: String) async {
        builderBusy = true
        defer { builderBusy = false }
        do {
            if let current = builderContainer,
               current.cpus != cpus || current.memory != formatBytes(Self.bytes(fromMemorySpec: memory) ?? 0) {
                _ = try? await cli(CLI.builderStop())
                try await cli(CLI.builderDelete())
            }
            try await cli(CLI.builderStart(cpus: cpus, memory: memory), timeout: nil)
        } catch {
            report(error, as: String(localized: "Couldn't start the builder"))
        }
        await fetchContainers()
    }

    func stopBuilder() async {
        builderBusy = true
        defer { builderBusy = false }
        do { try await cli(CLI.builderStop()) } catch { report(error, as: String(localized: "Couldn't stop the builder")) }
        await fetchContainers()
    }

    func deleteBuilder() async {
        builderBusy = true
        defer { builderBusy = false }
        _ = try? await cli(CLI.builderStop())
        do { try await cli(CLI.builderDelete()) } catch { report(error, as: String(localized: "Couldn't delete the builder")) }
        await fetchContainers()
    }

    /// "512M" → 536870912, "2G" → 2147483648.
    nonisolated static func bytes(fromMemorySpec spec: String) -> Int? {
        let s = spec.uppercased().trimmingCharacters(in: .whitespaces)
        guard let unit = s.last, let value = Int(s.dropLast()) else { return Int(s) }
        switch unit {
        case "K": return value * 1024
        case "M": return value * 1024 * 1024
        case "G": return value * 1024 * 1024 * 1024
        case "T": return value * 1024 * 1024 * 1024 * 1024
        default: return Int(s)
        }
    }
}
