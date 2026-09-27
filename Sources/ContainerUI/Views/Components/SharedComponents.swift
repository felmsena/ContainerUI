import SwiftUI

struct SectionCard<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 10.5, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(Theme.text3)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Theme.border, lineWidth: 1)
                    )
            )
        }
    }
}

/// Icon-only button that copies `text` to the pasteboard and shows a
/// checkmark for 1.5s as feedback. Self-contained: each instance tracks
/// its own copied state, so multiple buttons in one view don't need a
/// shared "which one was copied" key.
struct CopyButton: View {
    let text: String
    var size: CGFloat = 11
    var help: LocalizedStringKey = "Copy"
    @State private var copied = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.system(size: size))
                .foregroundStyle(copied ? Theme.accent : Theme.text3)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(copied ? "Copied" : help)
    }
}

struct KeyValueRow: View {
    let key: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(key)
                .font(.system(size: 12))
                .foregroundStyle(Theme.text2)
                .frame(width: 90, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Small caps section title used inside detail panes.
struct SectionHeader: View {
    let title: LocalizedStringKey
    init(_ title: LocalizedStringKey) { self.title = title }

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.text3)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

/// Label + control pair used in sheets and forms.
struct FormSection<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text2)
            content
        }
    }
}

/// Large icon + title header at the top of the image/volume/registry/network
/// detail panes, with optional badges underneath.
struct DetailHero<Badges: View>: View {
    let icon: String
    let color: Color
    let title: String
    @ViewBuilder var badges: Badges

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(color.opacity(0.14))
                    .frame(width: 72, height: 72)
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(color)
            }
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                HStack(spacing: 8) { badges }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
    }
}

struct HeroBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }
}

/// ↑/↓ moves the selection in a card list. The list becomes focusable
/// (click it or Tab to it); instead of AppKit's system-blue focus ring —
/// which ignores the theme — a themed ring shows while it has focus, so
/// keyboard users can still tell where focus is.
struct ListKeyboardNavigation<Item: Identifiable>: ViewModifier {
    let items: [Item]
    @Binding var selection: Item?
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focusable()
            .focusEffectDisabled()
            .focused($isFocused)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Theme.accent.opacity(isFocused ? 0.45 : 0), lineWidth: 2)
                    .padding(2)
                    .allowsHitTesting(false)
            )
            .onKeyPress(.upArrow) { move(by: -1) }
            .onKeyPress(.downArrow) { move(by: 1) }
            .onChange(of: selection?.id) { _, _ in isFocused = true }
    }

    private func move(by delta: Int) -> KeyPress.Result {
        guard !items.isEmpty else { return .ignored }
        let current = selection.flatMap { sel in items.firstIndex { $0.id == sel.id } }
        let next = current.map { min(max($0 + delta, 0), items.count - 1) } ?? (delta > 0 ? 0 : items.count - 1)
        selection = items[next]
        return .handled
    }
}

extension View {
    func listKeyboardNavigation<Item: Identifiable>(items: [Item], selection: Binding<Item?>) -> some View {
        modifier(ListKeyboardNavigation(items: items, selection: selection))
    }
}
