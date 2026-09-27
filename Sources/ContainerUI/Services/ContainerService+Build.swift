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

    /// Starts `container build`, streaming its combined output line by line.
    func startBuild(tag: String, contextDir: String, buildArgs: [String] = []) -> ProcessStream {
        ProcessRunner.stream([bin] + CLI.build(tag: tag, contextDir: contextDir, buildArgs: buildArgs))
    }
}
