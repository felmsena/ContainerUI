import SwiftUI

/// Dismissible banner used consistently wherever `serviceError` or a local
/// error/info message needs to be surfaced instead of failing silently.
struct ErrorBanner: View {
    enum Style {
        case warning
        case info

        var tint: Color { self == .warning ? .orange : .blue }
        var icon: String { self == .warning ? "exclamationmark.triangle.fill" : "arrow.down.circle.fill" }
    }

    let message: String
    var style: Style = .warning
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: style.icon)
                .font(.system(size: 12))
                .foregroundStyle(style.tint)
                .padding(.top, 1)

            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            if let actionLabel, let action {
                Button(actionLabel, action: action)
                    .font(.system(size: 12, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(style.tint.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style.tint.opacity(0.3), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
