import Foundation

/// Everything a finished process produced, regardless of exit status.
struct ProcessOutput: Sendable, Equatable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

/// Typed failure of a `container` CLI invocation, so callers can react to
/// *why* something failed instead of pattern-matching message text.
enum CLIError: LocalizedError, Equatable {
    /// The binary itself could not be launched (missing, not executable).
    case launchFailed(String)
    /// The apiserver/XPC service isn't reachable — `container system start` needed.
    case daemonNotRunning(String)
    /// The command ran and exited non-zero; carries its trimmed stderr.
    case failed(String, code: Int32)
    case timedOut
    case cancelled

    var errorDescription: String? {
        switch self {
        case .launchFailed(let msg): return msg
        case .daemonNotRunning(let msg): return msg
        case .failed(let msg, let code):
            return msg.isEmpty ? String(localized: "Command failed with exit code \(Int(code))") : msg
        case .timedOut: return String(localized: "The command timed out")
        case .cancelled: return String(localized: "The command was cancelled")
        }
    }

    /// Classifies a non-zero exit. The CLI has no machine-readable error
    /// codes, so "service is down" is recognised from its well-known stderr
    /// phrasing — in exactly one place, instead of at every call site.
    nonisolated static func classify(stderr: String, code: Int32) -> CLIError {
        let msg = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = msg.lowercased()
        let daemonMarkers = [
            "xpc connection error", "connection invalid", "connection refused",
            "container system start", "plugins are unavailable", "apiserver is not running",
        ]
        if daemonMarkers.contains(where: lower.contains) {
            return .daemonNotRunning(msg)
        }
        return .failed(msg, code: code)
    }
}

/// Seam for running CLI commands, so `ContainerService` logic can be unit
/// tested with a fake instead of a real `container` binary.
protocol CommandRunning: Sendable {
    func run(_ args: [String], stdin: String?, timeout: TimeInterval?) async -> Result<ProcessOutput, CLIError>
}

/// Runs processes without the classic `Process` deadlock: stdout and stderr
/// are drained concurrently *while* the child runs (waiting for exit first
/// and reading afterwards blocks forever once a pipe's ~64 KB buffer fills).
/// Supports stdin, a timeout, and Swift task cancellation (which terminates
/// the child rather than just abandoning it).
struct ProcessRunner: CommandRunning {
    static let defaultTimeout: TimeInterval = 120

    func run(_ args: [String], stdin: String? = nil, timeout: TimeInterval? = defaultTimeout) async -> Result<ProcessOutput, CLIError> {
        await Self.run(args, stdin: stdin, timeout: timeout)
    }

    static func run(_ args: [String], stdin: String? = nil, timeout: TimeInterval? = defaultTimeout) async -> Result<ProcessOutput, CLIError> {
        guard let executable = args.first else { return .failure(.launchFailed("Empty command")) }
        let handle = ProcessHandle()

        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Result<ProcessOutput, CLIError>, Never>) in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = Array(args.dropFirst())
                let outPipe = Pipe(), errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe
                let inPipe: Pipe? = stdin == nil ? nil : Pipe()
                if let inPipe { process.standardInput = inPipe }

                let group = DispatchGroup()
                let collected = OutputBuffers()
                for (pipe, isErr) in [(outPipe, false), (errPipe, true)] {
                    group.enter()
                    DispatchQueue.global(qos: .userInitiated).async {
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        collected.set(data, isErr: isErr)
                        group.leave()
                    }
                }
                group.enter()
                process.terminationHandler = { _ in group.leave() }

                do {
                    try process.run()
                } catch {
                    try? outPipe.fileHandleForWriting.close()
                    try? errPipe.fileHandleForWriting.close()
                    continuation.resume(returning: .failure(.launchFailed(error.localizedDescription)))
                    return
                }
                handle.attach(process)

                if let inPipe, let stdin {
                    DispatchQueue.global(qos: .userInitiated).async {
                        inPipe.fileHandleForWriting.write(Data(stdin.utf8))
                        try? inPipe.fileHandleForWriting.close()
                    }
                }
                if let timeout {
                    DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                        handle.terminate(reason: .timedOut)
                    }
                }

                group.notify(queue: .global()) {
                    if let reason = handle.terminationReason {
                        continuation.resume(returning: .failure(reason))
                        return
                    }
                    let (out, err) = collected.strings
                    continuation.resume(returning: .success(ProcessOutput(stdout: out, stderr: err, exitCode: process.terminationStatus)))
                }
            }
        } onCancel: {
            handle.terminate(reason: .cancelled)
        }
    }

    /// Streams a process's combined stdout/stderr line by line. The stream
    /// finishes when the process exits (throwing `CLIError` on a non-zero
    /// status), and cancelling the consuming task — or calling `cancel()` —
    /// terminates the process.
    static func stream(_ args: [String]) -> ProcessStream {
        ProcessStream(args: args)
    }
}

/// A running, line-streamed process. See `ProcessRunner.stream`.
final class ProcessStream: @unchecked Sendable {
    let lines: AsyncThrowingStream<String, Error>
    private let handle = ProcessHandle()

    init(args: [String]) {
        let handle = self.handle
        lines = AsyncThrowingStream { continuation in
            guard let executable = args.first else {
                continuation.finish(throwing: CLIError.launchFailed("Empty command"))
                return
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = Array(args.dropFirst())
            let outPipe = Pipe(), errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            let group = DispatchGroup()
            let stderrTail = StderrTail()
            for (pipe, isErr) in [(outPipe, false), (errPipe, true)] {
                group.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    var splitter = LineSplitter()
                    let reader = pipe.fileHandleForReading
                    while true {
                        let data = reader.availableData
                        if data.isEmpty { break }
                        for line in splitter.feed(data) {
                            if isErr { stderrTail.append(line) }
                            continuation.yield(line)
                        }
                    }
                    if let last = splitter.flush() {
                        if isErr { stderrTail.append(last) }
                        continuation.yield(last)
                    }
                    group.leave()
                }
            }
            group.enter()
            process.terminationHandler = { _ in group.leave() }

            continuation.onTermination = { _ in handle.terminate(reason: .cancelled) }

            do {
                try process.run()
            } catch {
                try? outPipe.fileHandleForWriting.close()
                try? errPipe.fileHandleForWriting.close()
                continuation.finish(throwing: CLIError.launchFailed(error.localizedDescription))
                return
            }
            handle.attach(process)

            group.notify(queue: .global()) {
                if let reason = handle.terminationReason {
                    continuation.finish(throwing: reason)
                } else if process.terminationStatus == 0 {
                    continuation.finish()
                } else {
                    continuation.finish(throwing: CLIError.classify(stderr: stderrTail.text, code: process.terminationStatus))
                }
            }
        }
    }

    func cancel() { handle.terminate(reason: .cancelled) }
}

// MARK: - Internals

/// Thread-safe holder for the child process, so cancellation/timeout from
/// another thread can terminate it and record why.
private final class ProcessHandle: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var reason: CLIError?
    private var pendingReason: CLIError?

    func attach(_ p: Process) {
        lock.lock()
        process = p
        let pending = pendingReason
        lock.unlock()
        if let pending { terminate(reason: pending) }
    }

    func terminate(reason newReason: CLIError) {
        lock.lock()
        guard let process else {
            // Cancelled before launch — apply as soon as it's attached.
            pendingReason = newReason
            lock.unlock()
            return
        }
        let shouldKill = process.isRunning && reason == nil
        if shouldKill { reason = newReason }
        lock.unlock()
        if shouldKill { process.terminate() }
    }

    var terminationReason: CLIError? {
        lock.lock(); defer { lock.unlock() }
        return reason
    }
}

private final class OutputBuffers: @unchecked Sendable {
    private let lock = NSLock()
    private var out = Data()
    private var err = Data()

    func set(_ data: Data, isErr: Bool) {
        lock.lock(); defer { lock.unlock() }
        if isErr { err = data } else { out = data }
    }

    var strings: (String, String) {
        lock.lock(); defer { lock.unlock() }
        return (String(decoding: out, as: UTF8.self), String(decoding: err, as: UTF8.self))
    }
}

/// Keeps the last few stderr lines, to build an error message when a
/// streamed process fails.
private final class StderrTail: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [String] = []

    func append(_ line: String) {
        lock.lock(); defer { lock.unlock() }
        lines.append(line)
        if lines.count > 20 { lines.removeFirst(lines.count - 20) }
    }

    var text: String {
        lock.lock(); defer { lock.unlock() }
        return lines.joined(separator: "\n")
    }
}

/// Splits a byte stream into lines, buffering partial lines (and partial
/// multi-byte UTF-8 sequences) across reads so nothing is dropped or garbled.
struct LineSplitter {
    private var buffer = Data()

    mutating func feed(_ data: Data) -> [String] {
        buffer.append(data)
        var lines: [String] = []
        while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            var lineData = buffer[buffer.startIndex..<newline]
            if lineData.last == UInt8(ascii: "\r") { lineData = lineData.dropLast() }
            lines.append(String(decoding: lineData, as: UTF8.self))
            buffer.removeSubrange(buffer.startIndex...newline)
        }
        return lines
    }

    mutating func flush() -> String? {
        guard !buffer.isEmpty else { return nil }
        defer { buffer.removeAll() }
        return String(decoding: buffer, as: UTF8.self)
    }
}
