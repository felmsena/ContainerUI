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

    var uptimeDisplay: String {
        guard !started.isEmpty else { return "—" }
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: started) else { return started }
        let elapsed = Date().timeIntervalSince(date)
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

    var label: String { rawValue.capitalized }
}
