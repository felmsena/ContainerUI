import Foundation

extension ContainerService {

    struct ExecOutput {
        let stdout: String
        let stderr: String
        let exitCode: Int32
    }

    /// Runs `container exec <id> <args...>` and returns whatever the process
    /// produced regardless of exit code — unlike `shell()`, this never
    /// throws and never discards stdout on a non-zero exit, since a
    /// terminal-like UI needs to show output either way.
    func exec(_ id: String, args: [String]) async -> ExecOutput {
        await Self.runProcess([bin, "exec", id] + args)
    }

    nonisolated static func runProcess(_ args: [String]) async -> ExecOutput {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let outPipe = Pipe()
                let errPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: args[0])
                process.arguments = Array(args.dropFirst())
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: ExecOutput(stdout: "", stderr: error.localizedDescription, exitCode: -1))
                    return
                }

                process.waitUntilExit()
                let stdout = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                continuation.resume(returning: ExecOutput(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus))
            }
        }
    }

    /// Splits a typed command line into argv tokens for `container exec`,
    /// which takes arguments directly (no shell involved) — so a command
    /// like `sh -c "echo hello world"` needs its quoted segment kept as one
    /// argument. Supports single/double quotes; no other shell features
    /// (no `$()`, `;`, pipes, globbing) — that's intentional, not a gap.
    nonisolated static func tokenizeCommand(_ input: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var quoteChar: Character?

        for char in input {
            if let q = quoteChar {
                if char == q { quoteChar = nil } else { current.append(char) }
            } else if char == "\"" || char == "'" {
                quoteChar = char
            } else if char.isWhitespace {
                if !current.isEmpty { tokens.append(current); current = "" }
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }
}
