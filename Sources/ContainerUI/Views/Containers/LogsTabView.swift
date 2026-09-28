import SwiftUI

struct LogsTabView: View {
    let containerId: String
    @Environment(ContainerService.self) private var service

    /// 0 means "all lines".
    @State private var lineCount = 100
    @State private var follow = false
    @State private var boot = false
    @State private var filter = ""
    @State private var buffer = LogBuffer()
    @State private var isLoading = false
    @State private var error: String?
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            if let error {
                ErrorBanner(message: error) { self.error = nil }
                    .padding(10)
            }
            let text = buffer.text(filter: filter)
            if text.isEmpty && !isLoading {
                EmptyStateView(
                    icon: "text.alignleft",
                    title: filter.isEmpty ? (follow ? "Waiting for output…" : "No logs available") : "No results for \"\(filter)\""
                )
                .background(Theme.surface)
            } else {
                LogTextView(text: text)
                    .background(Theme.surface)
            }
        }
        .onAppear(perform: reload)
        .onDisappear { loadTask?.cancel() }
        .onChange(of: lineCount) { _, _ in reload() }
        .onChange(of: follow) { _, _ in reload() }
        .onChange(of: boot) { _, _ in reload() }
    }

    /// One row when the column is wide enough, two when it isn't — nothing
    /// gets clipped or wrapped mid-word.
    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                lineTabs
                filterField
                Spacer(minLength: 4)
                options
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    lineTabs
                    filterField
                }
                HStack(spacing: 8) {
                    options
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var lineTabs: some View {
        BrandTabs(
            items: [(50, "50", true), (100, "100", true), (500, "500", true), (0, "All", true)],
            selection: $lineCount
        )
        .help("Lines to load")
    }

    private var filterField: some View {
        SearchField(text: $filter, prompt: "Filter…")
            .frame(minWidth: 120, maxWidth: 200)
    }

    @ViewBuilder
    private var options: some View {
        Toggle("Boot log", isOn: $boot)
            .toggleStyle(.checkbox)
            .font(.system(size: 12))
            .fixedSize()
            .help("Show the VM boot log instead of the container's output")

        Toggle(isOn: $follow) {
            Label("Follow", systemImage: follow ? "dot.radiowaves.left.and.right" : "pause.circle")
        }
        .toggleStyle(.button)
        .tint(Theme.accent)
        .fixedSize()
        .help("Stream new lines as they're written")

        if isLoading {
            ProgressView().controlSize(.small)
        } else if !follow {
            Button {
                reload()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .help("Refresh logs")
            .accessibilityLabel("Refresh logs")
        }
    }

    private func reload() {
        loadTask?.cancel()
        error = nil
        let lines: Int? = lineCount == 0 ? nil : lineCount
        loadTask = Task {
            if follow {
                buffer = LogBuffer()
                isLoading = false
                let stream = service.followLogs(for: containerId, lines: lines, boot: boot)
                do {
                    for try await line in stream.lines {
                        buffer.append(line)
                    }
                } catch CLIError.cancelled {
                } catch {
                    if !Task.isCancelled { self.error = error.localizedDescription }
                }
                if Task.isCancelled { stream.cancel() }
            } else {
                isLoading = true
                do {
                    let text = try await service.fetchLogs(for: containerId, lines: lines, boot: boot)
                    if !Task.isCancelled { buffer = LogBuffer(text: text) }
                } catch {
                    if !Task.isCancelled {
                        buffer = LogBuffer()
                        self.error = error.localizedDescription
                    }
                }
                isLoading = false
            }
        }
    }
}
