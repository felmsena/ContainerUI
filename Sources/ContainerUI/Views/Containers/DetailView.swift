import SwiftUI
import AppKit

enum DetailTab: String, CaseIterable {
    case info  = "Info"
    case logs  = "Logs"
    case stats = "Stats"
    case shell = "Shell"
}

struct DetailView: View {
    let container: ContainerInfo
    @EnvironmentObject var service: ContainerService
    @State private var tab: DetailTab = .info

    @State private var showCopyFromSheet = false
    @State private var showCopyToSheet = false
    @State private var pendingUploadSource: URL?
    @State private var isPerformingFileAction = false
    @State private var fileActionError: String?

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(DetailTab.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                        .disabled(t == .shell && !container.state.isRunning)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(10)

            Divider()

            if let fileActionError {
                ErrorBanner(message: fileActionError) { self.fileActionError = nil }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }

            switch tab {
            case .info:  InfoTabView(container: container)
            case .logs:  LogsTabView(containerId: container.id)
            case .stats: StatsTabView(container: container)
            case .shell: ExecTabView(container: container)
            }
        }
        .navigationTitle(container.id)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showCopyFromSheet = true
                    } label: {
                        Label("Copy file from container…", systemImage: "square.and.arrow.down")
                    }
                    .disabled(!container.state.isRunning || isPerformingFileAction)

                    Button {
                        chooseUploadSource()
                    } label: {
                        Label("Copy file to container…", systemImage: "square.and.arrow.up")
                    }
                    .disabled(!container.state.isRunning || isPerformingFileAction)

                    Divider()

                    Button {
                        exportFilesystem()
                    } label: {
                        Label("Export filesystem…", systemImage: "archivebox")
                    }
                    .disabled(container.state.isRunning || isPerformingFileAction)
                } label: {
                    if isPerformingFileAction {
                        ProgressView().scaleEffect(0.6)
                    } else {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                .help("File actions")
                .accessibilityLabel("File actions")
            }
        }
        .onChange(of: container.state.isRunning) { _, isRunning in
            if tab == .shell && !isRunning { tab = .info }
        }
        .sheet(isPresented: $showCopyFromSheet) {
            PathPromptSheet(
                title: "Copy file from container",
                placeholder: "/path/inside/container",
                confirmLabel: "Choose destination…"
            ) { remotePath in
                copyFromContainer(remotePath: remotePath)
            }
        }
        .sheet(isPresented: $showCopyToSheet) {
            PathPromptSheet(
                title: "Copy \"\(pendingUploadSource?.lastPathComponent ?? "")\" to container",
                placeholder: "/path/inside/container",
                confirmLabel: "Copy"
            ) { remotePath in
                copyToContainer(remotePath: remotePath)
            }
        }
    }

    private func copyFromContainer(remotePath: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = (remotePath as NSString).lastPathComponent
        guard panel.runModal() == .OK, let destURL = panel.url else { return }
        Task {
            isPerformingFileAction = true
            do {
                try await service.copyFromContainer(container.id, remotePath: remotePath, to: destURL.path)
            } catch {
                fileActionError = error.localizedDescription
            }
            isPerformingFileAction = false
        }
    }

    private func chooseUploadSource() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        pendingUploadSource = url
        showCopyToSheet = true
    }

    private func copyToContainer(remotePath: String) {
        guard let source = pendingUploadSource else { return }
        Task {
            isPerformingFileAction = true
            do {
                try await service.copyToContainer(container.id, localPath: source.path, to: remotePath)
            } catch {
                fileActionError = error.localizedDescription
            }
            isPerformingFileAction = false
        }
    }

    private func exportFilesystem() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(container.id).tar"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            isPerformingFileAction = true
            do {
                try await service.exportContainer(container.id, to: url.path)
            } catch {
                fileActionError = error.localizedDescription
            }
            isPerformingFileAction = false
        }
    }
}
