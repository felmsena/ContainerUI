import Foundation

func formatCount(_ n: Int) -> String {
    if n >= 1_000_000_000 { return String(format: "%.1fB", Double(n) / 1_000_000_000) }
    if n >= 1_000_000     { return String(format: "%.0fM", Double(n) / 1_000_000) }
    if n >= 1_000         { return "\(n / 1_000)K" }
    return "\(n)"
}

func formatBytes(_ bytes: Int) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .memory
    formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
    return formatter.string(fromByteCount: Int64(bytes))
}
