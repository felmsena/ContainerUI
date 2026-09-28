import SwiftUI

enum BrandButtonKind {
    case primary, secondary, destructive
}

/// Themed button style so every screen's primary/secondary/destructive
/// action reads the same, instead of each view mixing `.bordered`,
/// `.borderedProminent`, and ad-hoc `.tint(...)` calls. `compact` is the
/// small variant for toolbars, rows and inline actions.
struct BrandButtonStyle: ButtonStyle {
    let kind: BrandButtonKind
    var fill = false
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        BrandButtonBody(kind: kind, fill: fill, compact: compact, configuration: configuration)
    }
}

private struct BrandButtonBody: View {
    let kind: BrandButtonKind
    let fill: Bool
    let compact: Bool
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(.system(size: compact ? 11.5 : 12.5, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, compact ? 10 : 16)
            .frame(maxWidth: fill ? .infinity : nil)
            .frame(height: compact ? 24 : 32)
            .background(background, in: RoundedRectangle(cornerRadius: compact ? 7 : 9))
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: compact ? 7 : 9))
    }

    private var background: Color {
        switch kind {
        case .primary:     Theme.accent
        case .secondary:   Theme.surface2
        case .destructive: Theme.dangerSoft
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary:     .white
        case .secondary:   Theme.text
        case .destructive: Theme.danger
        }
    }
}

/// Themed replacement for `Picker(.segmented)` — segmented pickers pick up
/// the system accent color that `.tint(Theme.accent)` can't fully override
/// (the selection knob stays system blue on macOS), so tab-style selection
/// uses this instead. Each segment is a real button, so it's reachable with
/// the keyboard and announced by VoiceOver with its selected state.
struct BrandTabs<T: Hashable>: View {
    let items: [(value: T, label: LocalizedStringKey, enabled: Bool)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items.indices, id: \.self) { i in
                let item = items[i]
                let active = item.value == selection
                Button {
                    selection = item.value
                } label: {
                    Text(item.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(active ? Theme.text : Theme.text2)
                        .padding(.horizontal, 14)
                        .frame(height: 26)
                        .background(active ? Theme.surface : .clear,
                                    in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!item.enabled)
                .opacity(item.enabled ? 1 : 0.4)
                .accessibilityAddTraits(active ? [.isSelected] : [])
            }
        }
        .padding(3)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 10))
        // Never squeeze the labels away; neighbours (titles) truncate instead.
        .fixedSize()
        .accessibilityElement(children: .contain)
    }
}
