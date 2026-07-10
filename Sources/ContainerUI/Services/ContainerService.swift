import Foundation
import SwiftUI
import UserNotifications

let containerBin = "/opt/homebrew/bin/container"

enum DaemonState {
    case unknown
    case notInstalled
    case notRunning
    case starting
    case running
}

@MainActor
final class ContainerService: ObservableObject {
    // Containers
    @Published var containers: [ContainerInfo] = []
    @Published var isLoading = false
    @Published var serviceError: String?
    @Published var daemonState: DaemonState = .unknown

    // Images
    @Published var images: [ImageInfo] = []

    // Volumes
    @Published var volumes: [VolumeInfo] = []

    // System
    @Published var systemStatus: SystemStatusInfo?
    @Published var systemDf: [SystemDfRow] = []
    @Published var versionRows: [VersionRow] = []

    var bin: String { containerBin }

    private var refreshTask: Task<Void, Never>?
    private var previousRunningIds: Set<String> = []
    private var hasInitialFetch = false

    init() {
        requestNotificationPermission()
        startAutoRefresh()
    }
    deinit { refreshTask?.cancel() }

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
        guard FileManager.default.fileExists(atPath: containerBin) else {
            daemonState = .notInstalled
            serviceError = nil
            containers = []
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            let newContainers = try await fetchJSONOrText(
                command: "\(bin) list --all",
                jsonParse: Self.parseContainerListJSON,
                textParse: Self.parseContainerList
            )

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
            let msg = error.localizedDescription.lowercased()
            let isDaemonDown = msg.contains("connection refused")
                            || msg.contains("not running")
                            || msg.contains("failed to connect")
                            || msg.contains("broken pipe")
                            || msg.contains("no such file or directory")
                            || msg.contains("daemon")
                            || msg.contains("socket")
                            || msg.contains("xpc")
            if isDaemonDown {
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
            try await shell("\(bin) system start")
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
            try await shell("\(bin) system stop")
            containers = []
            daemonState = .notRunning
        } catch {
            // If stop fails, re-check actual state
            await fetchContainers()
            serviceError = "Could not stop service: \(error.localizedDescription)"
        }
    }

    func start(_ id: String) async {
        _ = try? await shell("\(bin) start \(id)")
        await fetchContainers()
    }

    func stop(_ id: String) async {
        _ = try? await shell("\(bin) stop \(id)")
        await fetchContainers()
    }

    func restart(_ id: String) async {
        _ = try? await shell("\(bin) stop \(id)")
        _ = try? await shell("\(bin) start \(id)")
        await fetchContainers()
    }

    func remove(_ id: String) async {
        // Stop first if running, then remove
        _ = try? await shell("\(bin) stop \(id)")
        _ = try? await shell("\(bin) rm \(id)")
        await fetchContainers()
    }

    func fetchLogs(for id: String, lines: Int = 200) async -> String {
        (try? await shell("\(bin) logs --tail \(lines) \(id)")) ?? ""
    }

    func openShell(for id: String) {
        let cmd = "\(bin) exec --tty --interactive \(id) sh"
        let script = """
        tell application "Terminal"
            activate
            do script "\(cmd)"
        end tell
        """
        var err: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&err)
    }

    func openInBrowser(ip: String, port: Int) {
        if let url = URL(string: "http://localhost:\(port)") {
            NSWorkspace.shared.open(url)
        }
    }

    func runContainer(image: String, name: String?, ports: [(host: String, container: String)], volumes: [String] = [], memory: String, cpus: Int, env: [String]) async throws {
        var parts = [bin, "run"]
        if let name { parts += ["--name", name] }
        parts += ["-m", memory]
        if cpus > 1 { parts += ["--cpus", "\(cpus)"] }
        for p in ports   { parts += ["-p", "\(p.host):\(p.container)"] }
        for v in volumes { parts += ["-v", v] }
        for e in env     { parts += ["-e", e] }
        parts.append(image)
        try await shell(parts.joined(separator: " "))
        await fetchContainers()
    }

    // MARK: – Notifications

    private var hasBundle: Bool { Bundle.main.bundleIdentifier != nil }

    private func requestNotificationPermission() {
        guard hasBundle else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notifyContainerStopped(_ id: String) {
        guard hasBundle else { return }
        let content = UNMutableNotificationContent()
        content.title = "Container stopped"
        content.body = "\"\(id)\" is no longer running"
        content.sound = .default
        let req = UNNotificationRequest(
            identifier: "stopped-\(id)-\(Int(Date().timeIntervalSince1970))",
            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: – Shell

    @discardableResult
    func shell(_ command: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let outPipe = Pipe()
                let errPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-c", command]
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                process.waitUntilExit()
                let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

                if process.terminationStatus != 0 {
                    let errMsg = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: ContainerError.failed(errMsg.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    continuation.resume(returning: out)
                }
            }
        }
    }

    enum ContainerError: LocalizedError {
        case failed(String)
        var errorDescription: String? {
            if case .failed(let msg) = self { return msg }
            return nil
        }
    }

    /// Runs `command --format json` and decodes it; falls back to the plain
    /// text form (and its fixed-width parser) if the JSON attempt fails to
    /// run or to decode — e.g. an older `container` CLI without `--format`.
    func fetchJSONOrText<T>(
        command: String,
        jsonParse: (Data) -> [T]?,
        textParse: (String) -> [T]
    ) async throws -> [T] {
        if let jsonOutput = try? await shell("\(command) --format json"),
           let data = jsonOutput.data(using: .utf8),
           let parsed = jsonParse(data) {
            return parsed
        }
        let output = try await shell(command)
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
            let image: ImageRef
            let platform: Platform
            let resources: Resources
        }
        struct Status: Decodable {
            struct NetworkStatus: Decodable { let ipv4Address: String? }
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
                started: entry.status.startedDate ?? ""
            )
        }
    }
}
