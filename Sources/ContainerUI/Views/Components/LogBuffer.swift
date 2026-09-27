import Foundation

/// Accumulates log lines for the log views: caps memory by dropping the
/// oldest lines in chunks, and applies a case-insensitive line filter.
struct LogBuffer: Equatable {
    static let maxLines = 20_000

    private(set) var lines: [String] = []

    init(text: String = "") { replace(with: text) }

    mutating func replace(with text: String) {
        var parts = text.components(separatedBy: "\n")
        if parts.last == "" { parts.removeLast() }
        lines = parts
        trim()
    }

    mutating func append(_ line: String) {
        lines.append(line)
        trim()
    }

    var isEmpty: Bool { lines.isEmpty }

    func text(filter: String) -> String {
        let needle = filter.trimmingCharacters(in: .whitespaces)
        let shown = needle.isEmpty ? lines : lines.filter { $0.localizedCaseInsensitiveContains(needle) }
        return shown.isEmpty ? "" : shown.joined(separator: "\n") + "\n"
    }

    private mutating func trim() {
        // Drop in chunks so the text view's append-only fast path is only
        // broken occasionally, not on every new line.
        if lines.count > Self.maxLines {
            lines.removeFirst(lines.count - Self.maxLines + Self.maxLines / 10)
        }
    }
}
