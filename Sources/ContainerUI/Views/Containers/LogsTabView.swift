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
                    .foregroundStyle(.secondary)
                Picker("", selection: $lineCount) {
                    Text("50").tag(50)
                    Text("100").tag(100)
                    Text("500").tag(500)
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 60)
                Text("lines")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

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

            ScrollViewReader { proxy in
                ScrollView {
                    Text(logs.isEmpty ? "No logs available" : logs)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(logs.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(10)
                        .id("logBottom")
                }
                .background(Color(nsColor: .textBackgroundColor).opacity(0.4))
                .onChange(of: logs) { _, _ in
                    proxy.scrollTo("logBottom", anchor: .bottom)
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
