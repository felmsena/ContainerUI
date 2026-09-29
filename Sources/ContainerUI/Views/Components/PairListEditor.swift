import SwiftUI

/// One editable left/right pair (port mapping, env var, mount, label…).
struct EditablePair: Identifiable, Equatable {
    let id = UUID()
    var left: String
    var right: String

    /// Splits "a<sep>b" at the first separator ("KEY=a=b" → "KEY", "a=b").
    init(splitting raw: String, separator: Character) {
        let parts = raw.split(separator: separator, maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        left = parts.first ?? ""
        right = parts.count > 1 ? parts[1] : ""
    }

    init(left: String = "", right: String = "") {
        self.left = left
        self.right = right
    }

    func joined(_ separator: String) -> String { "\(left)\(separator)\(right)" }
}

/// Editor for a list of pairs — the repeated ports/env/volumes/build-args
/// UI from the Run sheet and Build view, in one component.
struct PairListEditor<Extra: View>: View {
    @Binding var pairs: [EditablePair]
    let leftPlaceholder: LocalizedStringKey
    let rightPlaceholder: LocalizedStringKey
    let separator: String
    let addLabel: LocalizedStringKey
    var removeLabel: LocalizedStringKey = "Remove"
    @ViewBuilder var extra: Extra

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach($pairs) { $pair in
                HStack(spacing: 8) {
                    TextField(leftPlaceholder, text: $pair.left)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                    Text(separator)
                        .foregroundStyle(Theme.text3)
                        .font(.system(size: 13, design: .monospaced))
                    TextField(rightPlaceholder, text: $pair.right)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                    Button {
                        pairs.removeAll { $0.id == pair.id }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(Theme.danger)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(removeLabel)
                }
            }
            HStack(spacing: 12) {
                Button {
                    pairs.append(EditablePair())
                } label: {
                    Label(addLabel, systemImage: "plus.circle")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                extra
            }
        }
    }
}

extension PairListEditor where Extra == EmptyView {
    init(pairs: Binding<[EditablePair]>, leftPlaceholder: LocalizedStringKey, rightPlaceholder: LocalizedStringKey,
         separator: String, addLabel: LocalizedStringKey, removeLabel: LocalizedStringKey = "Remove") {
        self._pairs = pairs
        self.leftPlaceholder = leftPlaceholder
        self.rightPlaceholder = rightPlaceholder
        self.separator = separator
        self.addLabel = addLabel
        self.removeLabel = removeLabel
        self.extra = EmptyView()
    }
}
