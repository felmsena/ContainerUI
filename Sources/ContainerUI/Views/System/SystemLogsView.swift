import SwiftUI

struct SystemLogsView: View {
    @Environment(ContainerService.self) private var service
    @State private var buffer = LogBuffer()
    @State private var isLoading = false
    @State private var filterText = ""
    @State private var period = "5m"
    @State private var follow = false
    @State private var error: String?
    @State private var loadTask: Task<Void, Never>?

    private let periods: [(value: String, label: LocalizedStringKey, enabled: Bool)] = [
        ("5m", "5 min", true), ("1h", "1 h", true), ("1d", "1 day", true),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                SearchField(text: $filterText, prompt: "Filter logs…", icon: "line.3.horizontal.decrease.circle")
                BrandTabs(items: periods, selection: $period)
                    .help("How far back to fetch")
                Toggle(isOn: $follow) {
                    Label("Follow", systemImage: follow ? "dot.radiowaves.left.and.right" : "pause.circle")
                }
                .toggleStyle(.button)
                .help("Stream new lines as they're written")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.bg)

            Divider()

            if let error {
                ErrorBanner(message: error) { self.error = nil }
                    .padding(10)
            }

            let text = buffer.text(filter: filterText)
            if isLoading && buffer.isEmpty {
                ProgressView("Loading system logs…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if text.isEmpty {
                EmptyStateView(
                    icon: "terminal",
                    title: filterText.isEmpty ? "No logs" : "No results for \"\(filterText)\""
                )
            } else {
                LogTextView(text: text)
                    .background(Theme.surface)
            }
        }
        .navigationTitle("System logs")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Group {
                    if isLoading {
                        ProgressView().scaleEffect(0.7)
                    } else if !follow {
                        Button(action: reload) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .help("Refresh logs")
                        .accessibilityLabel("Refresh logs")
                    }
                }
            }
        }
        .onAppear(perform: reload)
        .onDisappear { loadTask?.cancel() }
        .onChange(of: period) { _, _ in reload() }
        .onChange(of: follow) { _, _ in reload() }
    }

    private func reload() {
        loadTask?.cancel()
        error = nil
        loadTask = Task {
            if follow {
                buffer = LogBuffer()
                let stream = service.followSystemLogs(last: period)
                do {
                    for try await line in stream.lines { buffer.append(line) }
                } catch CLIError.cancelled {
                } catch {
                    if !Task.isCancelled { self.error = error.localizedDescription }
                }
            } else {
                isLoading = true
                do {
                    let text = try await service.fetchSystemLogs(last: period)
                    if !Task.isCancelled { buffer = LogBuffer(text: text) }
                } catch {
                    if !Task.isCancelled { self.error = error.localizedDescription }
                }
                isLoading = false
            }
        }
    }
}
