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
