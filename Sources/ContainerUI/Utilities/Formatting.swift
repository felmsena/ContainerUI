import Foundation

func formatCount(_ n: Int) -> String {
    if n >= 1_000_000_000 { return String(format: "%.1fB", Double(n) / 1_000_000_000) }
    if n >= 1_000_000     { return String(format: "%.0fM", Double(n) / 1_000_000) }
    if n >= 1_000         { return "\(n / 1_000)K" }
    return "\(n)"
}
