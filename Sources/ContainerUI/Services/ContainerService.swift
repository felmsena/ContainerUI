import Foundation
import SwiftUI
import UserNotifications

enum DaemonState {
    case unknown
    case notInstalled
    case notRunning
    case starting
    case running
}

/// Owns all data read from the `container` CLI. `@Observable` (rather than
/// `ObservableObject`) so a view only re-renders when a property it
/// actually reads changes — with `ObservableObject` every poll re-rendered
/// the whole window. Setters below also skip no-op assignments, since
/// Observation notifies even when a value is set to itself.
@MainActor
@Observable
final class ContainerService {
    // Containers (user containers only — see `builderContainer`)
    var containers: [ContainerInfo] = []
    var builderContainer: ContainerInfo?
    /// True only until the first container list arrives; background polls
    /// don't flip it, so nothing flickers every refresh.
    var isLoading = true
    var serviceError: String?
    var daemonState: DaemonState = .unknown

    // Images
    var images: [ImageInfo] = []

    // Volumes & networks
    var volumes: [VolumeInfo] = []
    var networks: [NetworkInfo] = []

    // System
    var systemStatus: SystemStatusInfo?
    var systemDf: [SystemDfRow] = []
    var versionRows: [VersionRow] = []

    // Stats (per-container id)
    var latestStats: [String: ContainerStats] = [:]
    var statsHistory: [String: [ContainerStatsSample]] = [:]
    @ObservationIgnored var lastRawStats: [String: RawStatsSample] = [:]

    /// Builds, pulls and compose runs, newest first (see `BackgroundJob`).
    var jobs: [BackgroundJob] = []

    // Feedback
    var toasts: [Toast] = []
    /// Containers with an action in flight (start/stop/restart/remove/kill).
    var pendingContainers: Set<String> = []
    /// Containers the user just stopped from the app — no "stopped" alert.
    @ObservationIgnored private var expectedStops: Set<String> = []

    // Updates
    var availableUpdate: GitHubReleaseInfo?

    // Compose-lite (per compose-container-name, e.g. "<group>-<service>")
    var composeState: [String: ComposeServiceState] = [:]

    /// Path of the `container` CLI in use (see `ContainerBinary`). When it
    /// isn't installed this is the first default location, for display.
    private(set) var bin: String = ContainerBinary.candidates[0]
    private(set) var isBinaryInstalled = false

    @ObservationIgnored let runner: CommandRunning
    /// `fetchJSONOrText` command keys whose `--format json` output failed to
    /// decode, so later polls go straight to the text form.
    @ObservationIgnored var jsonUnsupported: Set<String> = []

    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var updateCheckTask: Task<Void, Never>?
    @ObservationIgnored private var previousRunningIds: Set<String> = []
    @ObservationIgnored private var hasInitialFetch = false

    @ObservationIgnored private let fixedBinary: String?

    /// `binary` pins the CLI path (tests use it with a fake `runner`);
    /// otherwise it's resolved via `ContainerBinary`.
    init(runner: CommandRunning = ProcessRunner(), binary: String? = nil, startBackgroundWork: Bool = true) {
        self.runner = runner
        self.fixedBinary = binary
        reloadBinaryPath()
        guard startBackgroundWork else { return }
        requestNotificationPermission()
        startAutoRefresh()
        startUpdateCheckLoop()
    }
    /// Assigns only when the value actually changed, so observers of an
    /// unchanged property aren't invalidated on every poll.
    func update<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<ContainerService, T>, _ value: T) {
        if self[keyPath: keyPath] != value { self[keyPath: keyPath] = value }
    }

    /// Re-resolves the CLI location, e.g. after the user picks a custom path.
    func reloadBinaryPath() {
        let resolved = fixedBinary ?? ContainerBinary.resolve()
        update(\.bin, resolved ?? ContainerBinary.candidates[0])
        update(\.isBinaryInstalled, resolved != nil)
        jsonUnsupported = []
    }

    func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.fetchContainers()
                let delay = Self.pollInterval(
                    base: UserDefaults.standard.object(forKey: "refreshInterval") as? Int ?? 5,
                    appIsActive: NSApp?.isActive ?? true,
                    daemonState: self.daemonState
                )
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    /// Seconds until the next container poll: the user's "Refresh every"
    /// setting while the app is in front, three times slower in the
    /// background (the menu bar still needs fresh data, just not as often),
    /// and at least 15 s while the service is down or not installed.
    nonisolated static func pollInterval(base: Int, appIsActive: Bool, daemonState: DaemonState) -> TimeInterval {
        var seconds = TimeInterval(max(base, 1))
        if !appIsActive { seconds *= 3 }
        if daemonState == .notRunning || daemonState == .notInstalled { seconds = max(seconds, 15) }
        return seconds
    }

    // MARK: – Containers

    func fetchContainers() async {
        if !isBinaryInstalled { reloadBinaryPath() }  // picks up a fresh install
        guard isBinaryInstalled else {
            update(\.daemonState, .notInstalled)
            update(\.serviceError, nil)
            update(\.containers, [])
            update(\.isLoading, false)
            return
        }

        defer { update(\.isLoading, false) }
        do {
            let listed = try await fetchJSONOrText(
                args: [bin] + CLI.list(),
                jsonParse: Self.parseContainerListJSON,
                textParse: Self.parseContainerList
            )
            let newContainers = listed.filter { !$0.isBuilder }
            let builder = listed.first(where: \.isBuilder)
            update(\.builderContainer, builder)

            let newRunning = Set(newContainers.filter { $0.state.isRunning }.map { $0.id })
            if hasInitialFetch {
                for id in Self.unexpectedStops(previous: previousRunningIds, current: newRunning, expected: expectedStops) {
                    notifyContainerStopped(id)
                }
            }
            // Expectations are consumed once the container is seen stopped.
            expectedStops.formIntersection(newRunning)
            previousRunningIds = newRunning
            hasInitialFetch = true
            update(\.containers, newContainers)
            update(\.serviceError, nil)
            update(\.daemonState, .running)
        } catch {
            if case CLIError.daemonNotRunning = error {
                // Start over once the service returns, rather than notifying
                // for every container that was running before it went down.
                hasInitialFetch = false
                previousRunningIds = []
                update(\.daemonState, .notRunning)
                update(\.serviceError, nil)
                update(\.containers, [])
                update(\.builderContainer, nil)
            } else {
                update(\.serviceError, error.localizedDescription)
            }
        }
    }

    func startDaemon() async {
        daemonState = .starting
        serviceError = nil
        do {
            try await cli(CLI.systemStart(), timeout: nil)
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await fetchContainers()
        } catch {
            daemonState = .notRunning
            serviceError = String(localized: "Could not start service: \(error.localizedDescription)")
        }
    }

    func stopDaemon() async {
        daemonState = .starting  // reuse "transitioning" state for the spinner
        serviceError = nil
        do {
            try await cli(CLI.systemStop())
            containers = []
            daemonState = .notRunning
        } catch {
            // If stop fails, re-check actual state
            await fetchContainers()
            serviceError = String(localized: "Could not stop service: \(error.localizedDescription)")
        }
    }

    // MARK: – Container actions
    //
    // Each action marks the container as pending (the card shows a spinner
    // and disables its buttons), reports failures as a toast instead of
    // swallowing them, and refreshes the list afterwards.

    func start(_ id: String) async {
        await performContainerAction(id, failure: String(localized: "Couldn't start \(id)")) {
            try await self.cli(CLI.start(id))
        }
    }

    func stop(_ id: String) async {
        expectedStops.insert(id)
        await performContainerAction(id, failure: String(localized: "Couldn't stop \(id)")) {
            try await self.cli(CLI.stop(id))
        }
    }

    private func performContainerAction(_ id: String, failure: String, _ action: @escaping () async throws -> Void) async {
        pendingContainers.insert(id)
        defer { pendingContainers.remove(id) }
        do {
            try await action()
        } catch {
            expectedStops.remove(id)
            report(error, as: failure)
        }
        await fetchContainers()
    }

    /// Ids that were running, aren't any more, and weren't stopped by the
    /// user from this app — the ones worth a "Container stopped" alert.
    nonisolated static func unexpectedStops(previous: Set<String>, current: Set<String>, expected: Set<String>) -> Set<String> {
        previous.subtracting(current).subtracting(expected)
    }

    /// Refreshes the given sidebar section (⌘R refreshes the visible one).
    func refresh(_ section: SidebarItem) async {
        switch section {
        case .containers: await fetchContainers()
        case .images:     await fetchImages()
        case .volumes:    await fetchVolumes()
        case .networks:   await fetchNetworks(); await fetchContainers()
        case .stats, .logs: await fetchSystemInfo()
        case .registry, .build, .groups, .settings: await fetchContainers()
        }
    }

    func restart(_ id: String) async {
        expectedStops.insert(id)
        await performContainerAction(id, failure: String(localized: "Couldn't restart \(id)")) {
            try await self.cli(CLI.stop(id))
            try await self.cli(CLI.start(id))
        }
    }

    func remove(_ id: String) async {
        expectedStops.insert(id)
        await performContainerAction(id, failure: String(localized: "Couldn't remove \(id)")) {
            try await self.cli(CLI.delete(id))
        }
    }

    func kill(_ id: String) async {
        expectedStops.insert(id)
        await performContainerAction(id, failure: String(localized: "Couldn't kill \(id)")) {
            try await self.cli(CLI.kill(id))
        }
    }

    func pruneContainers() async {
        do { try await cli(CLI.prune()) } catch { report(error, as: String(localized: "Couldn't prune containers")) }
        await fetchContainers()
    }

    // MARK: – Toasts

    /// Shows `error` as a dismissible toast, prefixed with what failed.
    func report(_ error: Error, as title: String) {
        if case CLIError.cancelled = error { return }
        showToast(Toast(title: title, message: error.localizedDescription, style: .error))
    }

    func showToast(_ toast: Toast) {
        toasts.append(toast)
        if toasts.count > 4 { toasts.removeFirst(toasts.count - 4) }
        let id = toast.id
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: toast.style == .error ? 8_000_000_000 : 4_000_000_000)
            self?.dismissToast(id)
        }
    }

    func dismissToast(_ id: UUID) {
        toasts.removeAll { $0.id == id }
    }

    /// `lines: nil` fetches the whole log; `boot` the VM boot log.
    func fetchLogs(for id: String, lines: Int?, boot: Bool = false) async throws -> String {
        try await cli(CLI.logs(id, lines: lines, boot: boot))
    }

    /// Follows a container's log (`logs --follow`) line by line.
    func followLogs(for id: String, lines: Int?, boot: Bool = false) -> ProcessStream {
        ProcessRunner.stream([bin] + CLI.logs(id, lines: lines, follow: true, boot: boot))
    }

    /// Single-quotes `s` for safe use as one shell argument, escaping any
    /// embedded single quotes (`'` → `'\''`).
    nonisolated static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Escapes backslashes and double quotes so `s` can be safely interpolated
    /// inside an AppleScript double-quoted string literal.
    nonisolated static func appleScriptEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// Builds the `tell application "Terminal"` source for `openShell(for:)`.
    /// `id` is shell-quoted (so it can't break out into a second shell
    /// command) and the resulting command is AppleScript-escaped (so it
    /// can't break out of the `do script` string literal) before either is
    /// interpolated — a container `--name` can contain arbitrary characters.
    nonisolated static func openShellScript(bin: String, id: String) -> String {
        let cmd = "\(bin) exec --tty --interactive \(shellQuote(id)) sh"
        return """
        tell application "Terminal"
            activate
            do script "\(appleScriptEscape(cmd))"
        end tell
        """
    }

    func openShell(for id: String) {
        let script = Self.openShellScript(bin: bin, id: id)
        var err: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&err)
    }

    /// Where a browser should go to reach `containerPort`: through its
    /// published host mapping when there is one, otherwise straight to the
    /// container's own IP (Apple Container gives every container an address
    /// reachable from the host). `localhost:<containerPort>` — the old
    /// behaviour — only worked when the same port happened to be published.
    nonisolated static func browserURL(containerPort: Int, ip: String, published: [ContainerDetail.PublishedPort]) -> URL? {
        if let mapping = published.first(where: { $0.containerPort == containerPort }) {
            let host = mapping.hostAddress.isEmpty || mapping.hostAddress == "0.0.0.0" ? "localhost" : mapping.hostAddress
            return URL(string: "http://\(host):\(mapping.hostPort)")
        }
        guard !ip.isEmpty else { return nil }
        return URL(string: "http://\(ip):\(containerPort)")
    }

    func runContainer(_ spec: RunSpec) async throws {
        try await cli(spec.arguments, timeout: nil)  // may pull the image first
        await fetchContainers()
    }

    // MARK: – Updates

    private static let updateCheckInterval: UInt64 = 24 * 60 * 60 * 1_000_000_000

    private func startUpdateCheckLoop() {
        updateCheckTask?.cancel()
        updateCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkForUpdates()
                try? await Task.sleep(nanoseconds: Self.updateCheckInterval)
            }
        }
    }

    /// Checks the latest GitHub release against the running app's version.
    /// `force: true` (the Settings "Check Now" button) bypasses the
    /// "check automatically" preference; the background loop does not.
    func checkForUpdates(force: Bool = false) async {
        guard force || UserDefaults.standard.object(forKey: "autoCheckForUpdates") as? Bool ?? true else { return }
        guard let local = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              !local.hasSuffix("-dev") || force  // local builds aren't "out of date"
        else { return }
        guard let release = try? await UpdateChecker.fetchLatestRelease(),
              !release.draft, !release.prerelease,
              UpdateChecker.isNewer(release.tagName, than: local)
        else { return }
        availableUpdate = release
    }

    // MARK: – Notifications

    private var hasBundle: Bool { Bundle.main.bundleIdentifier != nil }

    private let notificationClickHandler = NotificationClickHandler()

    private func requestNotificationPermission() {
        guard hasBundle else { return }
        UNUserNotificationCenter.current().delegate = notificationClickHandler
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notifyContainerStopped(_ id: String) {
        guard hasBundle, UserDefaults.standard.object(forKey: "notifyContainerStopped") as? Bool ?? true else { return }
        send(title: String(localized: "Container stopped"), body: String(localized: "\"\(id)\" is no longer running"), identifier: "stopped-\(id)")
    }

    func notifyBuildFinished(tag: String, success: Bool) {
        guard hasBundle, UserDefaults.standard.object(forKey: "notifyBuildFinished") as? Bool ?? true else { return }
        let title = success ? String(localized: "Build finished") : String(localized: "Build failed")
        send(title: title, body: tag, identifier: "build-\(tag)")
    }

    func notifyPullFinished(ref: String, success: Bool) {
        guard hasBundle, UserDefaults.standard.object(forKey: "notifyPullFinished") as? Bool ?? false else { return }
        let title = success ? String(localized: "Pull finished") : String(localized: "Pull failed")
        send(title: title, body: ref, identifier: "pull-\(ref)")
    }

    private func send(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let req = UNNotificationRequest(
            identifier: "\(identifier)-\(Int(Date().timeIntervalSince1970))",
            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: – Shell

    /// Runs `args[0]` with `args.dropFirst()` as arguments directly — no
    /// `/bin/sh -c`, so metacharacters in any argument (spaces, `;`,
    /// `$(...)`, …) are inert rather than shell-interpreted. Throws
    /// `CLIError` on a non-zero exit, timeout or cancellation (cancelling the
    /// calling task terminates the process). Pass `timeout: nil` for
    /// commands that legitimately run long (pulls, `run` that pulls first).
    /// `shell` with the resolved `container` binary prepended.
    @discardableResult
    func cli(_ args: [String], stdin: String? = nil, timeout: TimeInterval? = ProcessRunner.defaultTimeout) async throws -> String {
        try await shell([bin] + args, stdin: stdin, timeout: timeout)
    }

    @discardableResult
    func shell(_ args: [String], stdin: String? = nil, timeout: TimeInterval? = ProcessRunner.defaultTimeout) async throws -> String {
        let output = try await runner.run(args, stdin: stdin, timeout: timeout).get()
        guard output.exitCode == 0 else {
            throw CLIError.classify(stderr: output.stderr, code: output.exitCode)
        }
        return output.stdout
    }

    /// Runs `args + ["--format", "json"]` and decodes it; falls back to the
    /// plain-args form (and its fixed-width parser) if the JSON output can't
    /// be decoded — e.g. an older `container` CLI without `--format`. Once a
    /// command's JSON has failed to decode it isn't retried, so each poll
    /// costs one process, not two. A service-down error is rethrown
    /// immediately rather than retried in text form.
    func fetchJSONOrText<T>(
        args: [String],
        jsonParse: (Data) -> [T]?,
        textParse: (String) -> [T]
    ) async throws -> [T] {
        let key = args.dropFirst().joined(separator: " ")
        if !jsonUnsupported.contains(key) {
            let jsonOutput = try await shell(args + ["--format", "json"])
            if let parsed = jsonParse(Data(jsonOutput.utf8)) { return parsed }
            jsonUnsupported.insert(key)
        }
        let output = try await shell(args)
        return textParse(output)
    }

    // MARK: – Shared parse helpers (used by extensions)

    nonisolated static func columnOffset(_ name: String, in header: String) -> Int? {
        guard let range = header.range(of: name) else { return nil }
        return header.distance(from: header.startIndex, to: range.lowerBound)
    }

    nonisolated static func field(_ chars: [Character], from: Int, to: Int?) -> String {
        let start = min(from, chars.count)
        let end   = to.map { min($0, chars.count) } ?? chars.count
        guard start < end else { return "" }
        return String(chars[start..<end]).trimmingCharacters(in: .whitespaces)
    }

    // MARK: – Container parsing

    nonisolated static func parseContainerList(_ output: String) -> [ContainerInfo] {
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard lines.count > 1 else { return [] }

        let header = lines[0]
        guard
            let idOff      = columnOffset("ID",      in: header),
            let imageOff   = columnOffset("IMAGE",   in: header),
            let osOff      = columnOffset("OS",      in: header),
            let archOff    = columnOffset("ARCH",    in: header),
            let stateOff   = columnOffset("STATE",   in: header),
            let ipOff      = columnOffset("IP",      in: header),
            let cpusOff    = columnOffset("CPUS",    in: header),
            let memOff     = columnOffset("MEMORY",  in: header),
            let startedOff = columnOffset("STARTED", in: header)
        else { return [] }

        return lines.dropFirst().compactMap { line in
            let chars = Array(line)
            guard chars.count > idOff else { return nil }
            let id      = field(chars, from: idOff,      to: imageOff)
            let image   = field(chars, from: imageOff,   to: osOff)
            let os      = field(chars, from: osOff,      to: archOff)
            let arch    = field(chars, from: archOff,    to: stateOff)
            let state   = field(chars, from: stateOff,   to: ipOff)
            let ip      = field(chars, from: ipOff,      to: cpusOff)
            let cpus    = field(chars, from: cpusOff,    to: memOff)
            let memory  = field(chars, from: memOff,     to: startedOff)
            let started = field(chars, from: startedOff, to: nil)
            guard !id.isEmpty else { return nil }
            return ContainerInfo(
                id: id, image: image, os: os, arch: arch,
                state: ContainerState(raw: state),
                ip: ip, cpus: Int(cpus) ?? 0, memory: memory, started: started
            )
        }
    }

    // MARK: – Container parsing (JSON)

    private struct ContainerListEntryJSON: Decodable {
        struct Configuration: Decodable {
            struct ImageRef: Decodable { let reference: String }
            struct Platform: Decodable { let os: String; let architecture: String }
            struct Resources: Decodable { let cpus: Int; let memoryInBytes: Int }
            struct Mount: Decodable {
                struct Kind: Decodable {
                    struct Volume: Decodable { let name: String }
                    let volume: Volume?
                }
                let source: String
                let type: Kind?
            }
            let image: ImageRef
            let platform: Platform
            let resources: Resources
            let labels: [String: String]?
            let mounts: [Mount]?
        }
        struct Status: Decodable {
            struct NetworkStatus: Decodable { let ipv4Address: String?; let network: String? }
            let networks: [NetworkStatus]
            let state: String
            let startedDate: String?
        }
        let id: String
        let configuration: Configuration
        let status: Status
    }

    nonisolated static func parseContainerListJSON(_ data: Data) -> [ContainerInfo]? {
        guard let entries = try? JSONDecoder().decode([ContainerListEntryJSON].self, from: data) else { return nil }
        return entries.map { entry in
            ContainerInfo(
                id: entry.id,
                image: entry.configuration.image.reference,
                os: entry.configuration.platform.os,
                arch: entry.configuration.platform.architecture,
                state: ContainerState(raw: entry.status.state),
                ip: entry.status.networks.first?.ipv4Address ?? "",
                cpus: entry.configuration.resources.cpus,
                memory: formatBytes(entry.configuration.resources.memoryInBytes),
                started: entry.status.startedDate ?? "",
                labels: entry.configuration.labels ?? [:],
                networks: entry.status.networks.compactMap(\.network),
                mountSources: (entry.configuration.mounts ?? []).map(\.source).filter { !$0.isEmpty },
                volumeNames: (entry.configuration.mounts ?? []).compactMap { $0.type?.volume?.name }
            )
        }
    }
}

/// `UNUserNotificationCenterDelegate` requires `NSObject` conformance,
/// which `ContainerService` (an `ObservableObject`) deliberately doesn't
/// have — kept as its own tiny object instead of widening
/// `ContainerService`'s class hierarchy for one callback.
final class NotificationClickHandler: NSObject, UNUserNotificationCenterDelegate {
    /// Clicking any notification (stopped, build finished, pull finished)
    /// brings the app to the front instead of just dismissing it.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            NSApp.activate(ignoringOtherApps: true)
        }
        completionHandler()
    }
}
