import Foundation

/// A single running (or finished) `container build` invocation. Streams
/// combined stdout/stderr as they're produced (so a log view can update
/// live) and can be cancelled mid-build by terminating the process.
final class BuildTask {
    private let process: Process
    let output: AsyncThrowingStream<String, Error>

    init(bin: String, tag: String, contextDir: String, buildArgs: [String]) {
        var args = [bin, "build", "-t", tag, "--progress", "plain"]
        for arg in buildArgs { args += ["--build-arg", arg] }
        args.append(contextDir)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: args[0])
        process.arguments = Array(args.dropFirst())
        self.process = process

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        output = AsyncThrowingStream { continuation in
            func pump(_ pipe: Pipe) {
                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else { return }
                    if let text = String(data: data, encoding: .utf8) {
                        continuation.yield(text)
                    }
                }
            }
            pump(outPipe)
            pump(errPipe)

            process.terminationHandler = { proc in
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                if proc.terminationStatus == 0 {
                    continuation.finish()
                } else {
                    continuation.finish(throwing: ContainerService.ContainerError.failed("Build exited with status \(proc.terminationStatus)"))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    /// Terminates the build process if it's still running. The output
    /// stream then finishes via the termination handler above.
    func cancel() {
        if process.isRunning { process.terminate() }
    }
}

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

    func startBuild(tag: String, contextDir: String, buildArgs: [String] = []) -> BuildTask {
        BuildTask(bin: bin, tag: tag, contextDir: contextDir, buildArgs: buildArgs)
    }
}
