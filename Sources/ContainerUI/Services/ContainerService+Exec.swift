import Foundation

extension ContainerService {

    /// Runs `container exec <id> <args...>` and returns whatever the process
    /// produced regardless of exit code — unlike `shell()`, this never
    /// discards stdout on a non-zero exit, since a terminal-like UI needs to
    /// show output either way. Cancelling the calling task kills the command.
    func exec(_ id: String, args: [String]) async -> ProcessOutput {
        switch await runner.run([bin, "exec", id] + args, stdin: nil, timeout: nil) {
        case .success(let output): return output
        case .failure(let error): return ProcessOutput(stdout: "", stderr: error.localizedDescription, exitCode: -1)
        }
    }

    /// Splits a typed command line into argv tokens for `container exec`,
    /// which takes arguments directly (no shell involved) — so a command
    /// like `sh -c "echo hello world"` needs its quoted segment kept as one
    /// argument. Supports single/double quotes (an empty `""` is kept as an
    /// empty argument); no other shell features (no `$()`, `;`, pipes,
    /// globbing) — that's intentional, not a gap.
    nonisolated static func tokenizeCommand(_ input: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var quoteChar: Character?
        var hasToken = false

        for char in input {
            if let q = quoteChar {
                if char == q { quoteChar = nil } else { current.append(char) }
            } else if char == "\"" || char == "'" {
                quoteChar = char
                hasToken = true
            } else if char.isWhitespace {
                if hasToken { tokens.append(current); current = ""; hasToken = false }
            } else {
                current.append(char)
                hasToken = true
            }
        }
        if hasToken { tokens.append(current) }
        return tokens
    }
}
