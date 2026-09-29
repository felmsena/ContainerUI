import Foundation

/// A long-running job (build, pull, compose up/down) owned by the service
/// rather than a view, so it survives navigation, reports progress in the
/// Activity popover, and can be cancelled from anywhere.
@MainActor
@Observable
final class BackgroundJob: Identifiable {
    enum Kind { case build, pull, compose }

    enum Status: Equatable {
        case running, succeeded, cancelled
        case failed(String)
    }

    let id = UUID()
    let kind: Kind
    let title: String
    /// What the job is about: the image tag, image ref or group name.
    let subject: String
    let startedAt = Date()
    var status: Status = .running
    var finishedAt: Date?
    /// Most recent output line, shown as the one-line progress detail.
    var detail = ""
    /// 0…1 when the CLI reports a percentage.
    var progress: Double?
    private(set) var log = ""

    @ObservationIgnored fileprivate var stream: ProcessStream?
    @ObservationIgnored fileprivate var task: Task<Void, Never>?

    init(kind: Kind, title: String, subject: String) {
        self.kind = kind
        self.title = title
        self.subject = subject
    }

    var isRunning: Bool { status == .running }

    func cancel() {
        guard isRunning else { return }
        stream?.cancel()
        task?.cancel()
    }

    /// Waits for the job to finish (whatever the outcome).
    func wait() async { await task?.value }

    fileprivate func append(_ line: String) {
        log += line + "\n"
        let cleaned = Self.cleanProgressLine(line)
        if !cleaned.isEmpty { detail = cleaned }
        if let pct = Self.percentage(in: line) { progress = pct }
    }

    fileprivate func finish(_ status: Status) {
        self.status = status
        finishedAt = Date()
        if status == .succeeded { progress = 1 }
    }

    /// "[4/6] Fetching init image 45% (3 of 4 blobs, 30,0/65,9 MB) [4s]" →
    /// "Fetching init image 45% (3 of 4 blobs, 30,0/65,9 MB)".
    nonisolated static func cleanProgressLine(_ line: String) -> String {
        var s = line.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("["), let close = s.firstIndex(of: "]") {
            s = String(s[s.index(after: close)...]).trimmingCharacters(in: .whitespaces)
        }
        if s.hasSuffix("]"), let open = s.lastIndex(of: "[") {
            s = String(s[..<open]).trimmingCharacters(in: .whitespaces)
        }
        return s
    }

    /// Overall progress from a `--progress plain` line: the step counter
    /// ("[4/6]") combined with the step's own percentage, when present.
    nonisolated static func percentage(in line: String) -> Double? {
        let ns = line as NSString
        var stepFraction: (done: Double, total: Double)?
        if let m = try? NSRegularExpression(pattern: #"^\s*\[(\d+)/(\d+)\]"#).firstMatch(in: line, range: NSRange(location: 0, length: ns.length)),
           let done = Double(ns.substring(with: m.range(at: 1))), let total = Double(ns.substring(with: m.range(at: 2))), total > 0 {
            stepFraction = (done, total)
        }
        var pct: Double?
        if let m = try? NSRegularExpression(pattern: #"(\d{1,3})%"#).firstMatch(in: line, range: NSRange(location: 0, length: ns.length)),
           let value = Double(ns.substring(with: m.range(at: 1))) {
            pct = min(value, 100) / 100
        }
        if let step = stepFraction {
            // Step n of m is in progress: completed steps + this step's share.
            let base = max(step.done - 1, 0) / step.total
            return min(base + (pct ?? 0) / step.total, 1)
        }
        return pct
    }
}

extension ContainerService {

    var runningJobs: [BackgroundJob] { jobs.filter(\.isRunning) }

    /// The most recent job of `kind` about `subject`, if any.
    func latestJob(_ kind: BackgroundJob.Kind, subject: String? = nil) -> BackgroundJob? {
        jobs.first { $0.kind == kind && (subject == nil || $0.subject == subject) }
    }

    func isPulling(_ ref: String) -> Bool {
        jobs.contains { $0.kind == .pull && $0.subject == ref && $0.isRunning }
    }

    func clearFinishedJobs() {
        jobs.removeAll { !$0.isRunning }
    }

    // MARK: Builds

    @discardableResult
    func startBuild(tag: String, contextDir: String, buildArgs: [String] = []) -> BackgroundJob {
        let job = BackgroundJob(kind: .build, title: String(localized: "Build \(tag)"), subject: tag)
        runStreaming(job, args: [bin] + CLI.build(tag: tag, contextDir: contextDir, buildArgs: buildArgs)) { [weak self] succeeded in
            self?.notifyBuildFinished(tag: tag, success: succeeded)
            await self?.fetchImages()
        }
        return job
    }

    // MARK: Pulls

    /// Starts pulling `ref` (or returns the pull already in progress).
    @discardableResult
    func startPull(_ ref: String) -> BackgroundJob {
        if let existing = jobs.first(where: { $0.kind == .pull && $0.subject == ref && $0.isRunning }) {
            return existing
        }
        let job = BackgroundJob(kind: .pull, title: String(localized: "Pull \(ref)"), subject: ref)
        runStreaming(job, args: [bin] + CLI.imagePull(ref)) { [weak self] succeeded in
            self?.notifyPullFinished(ref: ref, success: succeeded)
            if succeeded { await self?.fetchImages() }
        }
        return job
    }

    /// Pulls `ref` and waits, throwing if the pull failed.
    func pullImage(_ ref: String) async throws {
        let job = startPull(ref)
        await job.wait()
        switch job.status {
        case .failed(let message): throw CLIError.failed(message, code: 1)
        case .cancelled: throw CLIError.cancelled
        default: break
        }
    }

    // MARK: Compose

    /// Runs `work` as a tracked compose job (status only, no streamed log).
    @discardableResult
    func trackCompose(_ title: String, group: String, _ work: @escaping () async -> String?) -> BackgroundJob {
        let job = BackgroundJob(kind: .compose, title: title, subject: group)
        jobs.insert(job, at: 0)
        job.task = Task { [weak job] in
            let failure = await work()
            guard let job else { return }
            if Task.isCancelled { job.finish(.cancelled) }
            else if let failure { job.finish(.failed(failure)) }
            else { job.finish(.succeeded) }
        }
        return job
    }

    // MARK: Plumbing

    private func runStreaming(_ job: BackgroundJob, args: [String], onFinish: @escaping (Bool) async -> Void) {
        jobs.insert(job, at: 0)
        let stream = ProcessRunner.stream(args)
        job.stream = stream
        job.task = Task { [weak job] in
            var outcome: BackgroundJob.Status = .succeeded
            do {
                for try await line in stream.lines {
                    job?.append(line)
                }
            } catch CLIError.cancelled {
                outcome = .cancelled
            } catch {
                outcome = .failed(error.localizedDescription)
            }
            if Task.isCancelled { outcome = .cancelled }
            job?.finish(outcome)
            await onFinish(outcome == .succeeded)
        }
    }
}
