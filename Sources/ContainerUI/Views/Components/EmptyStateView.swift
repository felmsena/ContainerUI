import SwiftUI

/// Reusable icon + title (+ optional subtitle/detail/action) placeholder for
/// empty lists, unselected details, and no-results states.
struct EmptyStateView<Actions: View>: View {
    let icon: String
    var iconColor: Color? = nil
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    var detail: String? = nil
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(iconColor.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.quaternary))

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                }
            }

            if let detail {
                Text(detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .textSelection(.enabled)
            }

            actions()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

extension EmptyStateView where Actions == EmptyView {
    init(icon: String, iconColor: Color? = nil, title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, detail: String? = nil) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.actions = { EmptyView() }
    }
}
