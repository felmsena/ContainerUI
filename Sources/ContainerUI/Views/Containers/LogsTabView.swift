import SwiftUI

struct LogsTabView: View {
    let containerId: String
    @EnvironmentObject var service: ContainerService
    @State private var logs = ""
    @State private var isLoading = false
    @State private var lineCount = 100

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Last")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.text2)
                BrandTabs(
                    items: [(50, "50", true), (100, "100", true), (500, "500", true)],
                    selection: $lineCount
                )
                Text("lines")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.text2)

                Spacer()

                if isLoading {
                    ProgressView().scaleEffect(0.6)
                }

                Button {
                    Task { await load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help("Refresh logs")
                .accessibilityLabel("Refresh logs")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if logs.isEmpty {
                EmptyStateView(icon: "text.alignleft", title: "No logs available")
                    .background(Theme.surface)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(logs)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.text2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(10)
                            .id("logBottom")
                    }
                    .background(Theme.surface)
                    .onChange(of: logs) { _, _ in
                        proxy.scrollTo("logBottom", anchor: .bottom)
                    }
                }
            }
        }
        .task { await load() }
        .onChange(of: lineCount) { _, _ in Task { await load() } }
    }

    func load() async {
        isLoading = true
        logs = await service.fetchLogs(for: containerId, lines: lineCount)
        isLoading = false
    }
}
