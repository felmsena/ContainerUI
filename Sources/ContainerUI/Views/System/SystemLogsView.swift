import SwiftUI

struct SystemLogsView: View {
    @EnvironmentObject var service: ContainerService
    @State private var logs = ""
    @State private var isLoading = false
    @State private var filterText = ""

    private var displayedLogs: String {
        guard !filterText.isEmpty else { return logs }
        let lines = logs.components(separatedBy: "\n")
        return lines.filter { $0.localizedCaseInsensitiveContains(filterText) }.joined(separator: "\n")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundStyle(Theme.text3)
                    .font(.system(size: 13))
                TextField("Filter logs…", text: $filterText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                if !filterText.isEmpty {
                    Button { filterText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.text3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear filter")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 9))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.bg)

            Divider()

            if isLoading && logs.isEmpty {
                ProgressView("Loading system logs…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if displayedLogs.isEmpty {
                EmptyStateView(
                    icon: "terminal",
                    title: filterText.isEmpty ? "No logs" : "No results for \"\(filterText)\""
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(displayedLogs)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.text2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(12)
                            .id("sysLogBottom")
                    }
                    .background(Theme.surface)
                    .onChange(of: logs) { _, _ in
                        proxy.scrollTo("sysLogBottom", anchor: .bottom)
                    }
                }
            }
        }
        .navigationTitle("System logs")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Group {
                    if isLoading {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Button {
                            Task { await load() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .help("Refresh logs")
                        .accessibilityLabel("Refresh logs")
                    }
                }
            }
        }
        .task { await load() }
    }

    func load() async {
        isLoading = true
        logs = await service.fetchSystemLogs()
        isLoading = false
    }
}
