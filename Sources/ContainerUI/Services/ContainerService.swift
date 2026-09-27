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

@MainActor
final class ContainerService: ObservableObject {
    // Containers (user containers only — see `builderContainer`)
    @Published var containers: [ContainerInfo] = []
    @Published var builderContainer: ContainerInfo?
    @Published var isLoading = false
    @Published var serviceError: String?
    @Published var daemonState: DaemonState = .unknown
    @Published var showCommandPalette = false
    @Published var showRunSheet = false
    @Published var sidebarItem: SidebarItem = .containers

    // Images
    @Published var images: [ImageInfo] = []

    // Volumes
    @Published var volumes: [VolumeInfo] = []

    // System
    @Published var systemStatus: SystemStatusInfo?
    @Published var systemDf: [SystemDfRow] = []
    @Published var versionRows: [VersionRow] = []

    // Stats (per-container id)
    @Published var latestStats: [String: ContainerStats] = [:]
    @Published var statsHistory: [String: [ContainerStatsSample]] = [:]
    var lastRawStats: [String: RawStatsSample] = [:]

    // Updates
    @Published var availableUpdate: GitHubReleaseInfo?

    // Compose-lite (per compose-container-name, e.g. "<group>-<service>")
    @Published var composeState: [String: ComposeServiceState] = [:]

    /// Path of the `container` CLI in use (see `ContainerBinary`). When it
    /// isn't installed this is the first default location, for display.
    @Published private(set) var bin: String = ContainerBinary.candidates[0]
    @Published private(set) var isBinaryInstalled = false

    let runner: CommandRunning
    /// `fetchJSONOrText` command keys whose `--format json` output failed to
    /// decode, so later polls go straight to the text form.
    var jsonUnsupported: Set<String> = []

    private var refreshTask: Task<Void, Never>?
    private var updateCheckTask: Task<Void, Never>?
    private var previousRunningIds: Set<String> = []
    private var hasInitialFetch = false

    init(runner: CommandRunning = ProcessRunner(), startBackgroundWork: Bool = true) {
        self.runner = runner
        reloadBinaryPath()
        guard startBackgroundWork else { return }
        requestNotificationPermission()
        startAutoRefresh()
        startUpdateCheckLoop()
    }
    deinit {
        refreshTask?.cancel()
        updateCheckTask?.cancel()
    }

    /// Re-resolves the CLI location, e.g. after the user picks a custom path.
    func reloadBinaryPath() {
        let resolved = ContainerBinary.resolve()
        bin = resolved ?? ContainerBinary.candidates[0]
        isBinaryInstalled = resolved != nil
        jsonUnsupported = []
    }

    func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.fetchContainers()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    // MARK: – Containers

    func fetchContainers() async {
        if !isBinaryInstalled { reloadBinaryPath() }  // picks up a fresh install
        guard isBinaryInstalled else {
            daemonState = .notInstalled
            serviceError = nil
            containers = []
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            let listed = try await fetchJSONOrText(
                args: [bin] + CLI.list(),
                jsonParse: Self.parseContainerListJSON,
                textParse: Self.parseContainerList
            )
            let newContainers = listed.filter { !$0.isBuilder }
            let builder = listed.first(where: \.isBuilder)
            if builderContainer != builder { builderContainer = builder }

            if hasInitialFetch {
                let newRunning = Set(newContainers.filter { $0.state.isRunning }.map { $0.id })
                let stopped = previousRunningIds.subtracting(newRunning)
                for id in stopped { notifyContainerStopped(id) }
            }

            previousRunningIds = Set(newContainers.filter { $0.state.isRunning }.map { $0.id })
            hasInitialFetch = true
            containers = newContainers
            serviceError = nil
            if daemonState != .running { daemonState = .running }
        } catch {
            if case CLIError.daemonNotRunning = error {
                daemonState = .notRunning
                serviceError = nil
                containers = []
            } else {
                serviceError = error.localizedDescription
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
            serviceError = "Could not start service: \(error.localizedDescription)"
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
            serviceError = "Could not stop service: \(error.localizedDescription)"
        }
    }

    func start(_ id: String) async {
        _ = try? await cli(CLI.start(id))
        await fetchContainers()
    }

    func stop(_ id: String) async {
        _ = try? await cli(CLI.stop(id))
        await fetchContainers()
    }

    /// Refreshes whichever sidebar section is currently on screen (⌘R).
    func refreshCurrentSection() async {
        switch sidebarItem {
        case .containers: await fetchContainers()
        case .images:     await fetchImages()
        case .volumes:    await fetchVolumes()
        case .stats, .logs: await fetchSystemInfo()
        case .registry, .build, .groups, .settings: break
        }
    }

    func restart(_ id: String) async {
        _ = try? await cli(CLI.stop(id))
        _ = try? await cli(CLI.start(id))
        await fetchContainers()
    }

    func remove(_ id: String) async {
        _ = try? await cli(CLI.delete(id))
        await fetchContainers()
    }

    func kill(_ id: String) async {
        _ = try? await cli(CLI.kill(id))
        await fetchContainers()
    }

    func pruneContainers() async {
        _ = try? await cli(CLI.prune())
        await fetchContainers()
    }

    func fetchLogs(for id: String, lines: Int = 200) async -> String {
        (try? await cli(CLI.logs(id, lines: lines))) ?? ""
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

    func openInBrowser(ip: String, port: Int) {
        if let url = URL(string: "http://localhost:\(port)") {
            NSWorkspace.shared.open(url)
        }
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
        guard let local = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return }
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
            struct Mount: Decodable { let source: String }
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
                mountSources: (entry.configuration.mounts ?? []).map(\.source).filter { !$0.isEmpty }
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
