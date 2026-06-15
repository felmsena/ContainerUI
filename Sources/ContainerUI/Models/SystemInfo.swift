import Foundation

struct SystemStatusInfo {
    let status: String
    let appRoot: String
    let installRoot: String
    let apiserverVersion: String

    var isRunning: Bool { status == "running" }
}

struct SystemDfRow: Identifiable {
    var id: String { type }
    let type: String
    let total: String
    let active: String
    let size: String
    let reclaimable: String
}

struct VersionRow: Identifiable {
    var id: String { component }
    let component: String
    let version: String
    let build: String
}
