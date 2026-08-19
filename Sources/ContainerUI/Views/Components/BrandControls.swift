import SwiftUI

enum BrandButtonKind {
    case primary, secondary, destructive
}

/// Themed button style so every screen's primary/secondary/destructive
/// action reads the same, instead of each view mixing `.bordered`,
/// `.borderedProminent`, and ad-hoc `.tint(...)` calls.
struct BrandButtonStyle: ButtonStyle {
    let kind: BrandButtonKind
    var fill = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 16)
            .frame(maxWidth: fill ? .infinity : nil)
            .frame(height: 32)
            .background(background, in: RoundedRectangle(cornerRadius: 9))
            .opacity(configuration.isPressed ? 0.75 : 1)
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
/// uses this instead.
struct BrandTabs<T: Hashable>: View {
    let items: [(value: T, label: LocalizedStringKey, enabled: Bool)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items.indices, id: \.self) { i in
                let item = items[i]
                let active = item.value == selection
                Text(item.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(active ? Theme.text : Theme.text2)
                    .padding(.horizontal, 14)
                    .frame(height: 26)
                    .background(active ? Theme.surface : .clear,
                                in: RoundedRectangle(cornerRadius: 8))
                    .opacity(item.enabled ? 1 : 0.4)
                    .contentShape(Rectangle())
                    .onTapGesture { if item.enabled { selection = item.value } }
            }
        }
        .padding(3)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 10))
    }
}
