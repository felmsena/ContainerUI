import Foundation
import SwiftUI

struct ContainerInfo: Identifiable, Hashable {
    let id: String
    let image: String
    let os: String
    let arch: String
    let state: ContainerState
    let ip: String
    let cpus: Int
    let memory: String
    let started: String
    var labels: [String: String] = [:]
    /// Names of the networks the container is attached to.
    var networks: [String] = []
    /// Host-side sources of the container's mounts (for named volumes, the
    /// volume's image file — see `VolumeInfo.source`).
    var mountSources: [String] = []
    /// Named volumes mounted into the container.
    var volumeNames: [String] = []

    /// The BuildKit container Apple Container runs behind `container build`.
    /// It's infrastructure, not a user container, so it's listed separately.
    var isBuilder: Bool {
        labels["com.apple.container.resource.role"] == "builder"
            || (id == "buildkit" && image.contains("container-builder-shim"))
    }

    var shortImage: String {
        image
            .components(separatedBy: "/").last?
            .components(separatedBy: ":").first ?? image
    }

    var imageTag: String {
        image.components(separatedBy: ":").last ?? "latest"
    }

    var ipWithoutMask: String {
        ip.components(separatedBy: "/").first ?? ip
    }

    private static let isoFormatter = ISO8601DateFormatter()

    var uptimeDisplay: String { uptimeDisplay(at: Date()) }

    /// Uptime relative to `now` — views re-evaluate it from a `TimelineView`,
    /// since the model itself doesn't change while a container runs.
    func uptimeDisplay(at now: Date) -> String {
        guard !started.isEmpty else { return "—" }
        guard let date = Self.isoFormatter.date(from: started) else { return started }
        let elapsed = now.timeIntervalSince(date)
        if elapsed < 0 { return "—" }
        if elapsed < 60 { return "\(Int(elapsed))s" }
        if elapsed < 3600 { return "\(Int(elapsed / 60))m \(Int(elapsed.truncatingRemainder(dividingBy: 60)))s" }
        let h = Int(elapsed / 3600)
        let m = Int((elapsed.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(h)h \(m)m"
    }
}

enum ContainerState: String, Hashable {
    case running
    case stopped
    case paused
    case unknown

    init(raw: String) {
        self = ContainerState(rawValue: raw.lowercased()) ?? .unknown
    }

    var isRunning: Bool { self == .running }

    var color: Color {
        switch self {
        case .running: return .green
        case .stopped: return Color(nsColor: .tertiaryLabelColor)
        case .paused: return .orange
        case .unknown: return Color(nsColor: .tertiaryLabelColor)
        }
    }

    var label: String {
        switch self {
        case .running: return String(localized: "Running")
        case .stopped: return String(localized: "Stopped")
        case .paused:  return String(localized: "Paused")
        case .unknown: return String(localized: "Unknown")
        }
    }
}
