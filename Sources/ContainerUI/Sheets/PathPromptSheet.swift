import SwiftUI

/// Single-text-field prompt used by the container file actions to collect
/// a path inside the container (remote source when copying out, remote
/// destination when copying in).
struct PathPromptSheet: View {
    let title: String
    let placeholder: String
    let confirmLabel: String
    @State private var path = ""
    @Environment(\.dismiss) private var dismiss
    let onConfirm: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)

            TextField(placeholder, text: $path)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, design: .monospaced))
                .onSubmit(confirm)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Button(confirmLabel, action: confirm)
                    .buttonStyle(.borderedProminent)
                    .disabled(path.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func confirm() {
        let trimmed = path.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        dismiss()
        onConfirm(trimmed)
    }
}
