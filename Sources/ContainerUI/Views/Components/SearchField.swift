import SwiftUI

/// The rounded search/filter field used at the top of lists and log views.
struct SearchField: View {
    @Binding var text: String
    var prompt: LocalizedStringKey = "Search…"
    var icon = "magnifyingglass"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Theme.text3)
                .font(.system(size: 12))
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.text3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 8))
    }
}
