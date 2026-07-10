import SwiftUI

struct ContainerListView: View {
    @EnvironmentObject var service: ContainerService
    @Binding var selected: ContainerInfo?
    @State private var searchText = ""
    @State private var showPruneAlert = false
    @FocusState private var isListFocused: Bool

    private var filtered: [ContainerInfo] {
        guard !searchText.isEmpty else { return service.containers }
        return service.containers.filter {
            $0.id.localizedCaseInsensitiveContains(searchText) ||
            $0.image.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var stoppedCount: Int {
        service.containers.filter { !$0.state.isRunning }.count
    }

    /// Split into fully-formed literals so each pluralization/verb combo
    /// gets its own, grammatically correct translation.
    private var pruneContainersLabel: LocalizedStringKey {
        stoppedCount == 1 ? "Prune 1 stopped container" : "Prune \(stoppedCount) stopped containers"
    }
    private var removeContainersAlertTitle: LocalizedStringKey {
        stoppedCount == 1 ? "Remove 1 stopped container?" : "Remove \(stoppedCount) stopped containers?"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 13))
                TextField("Search containers…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if !searchText.isEmpty && filtered.isEmpty {
                emptySearch
            } else if service.containers.isEmpty {
                daemonEmptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filtered) { container in
                            ContainerCardView(
                                container: container,
                                isSelected: selected?.id == container.id
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selected = container
                                isListFocused = true
                            }
                        }
                    }
                    .padding(12)
                }
                .focusable()
                .focused($isListFocused)
                .onKeyPress(.space) {
                    guard let selected else { return .ignored }
                    Task {
                        if selected.state.isRunning {
                            await service.stop(selected.id)
                        } else {
                            await service.start(selected.id)
                        }
                    }
                    return .handled
                }
            }
        }
        .navigationTitle("Containers")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { Task { await service.fetchContainers() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh (⌘R)")
                .accessibilityLabel("Refresh containers")

                Button {
                    showPruneAlert = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash.slash")
                        if stoppedCount > 0 {
                            Text("\(stoppedCount) stopped")
                                .font(.system(size: 11))
                        }
                    }
                }
                .help(pruneContainersLabel)
                .foregroundStyle(stoppedCount > 0 ? .orange : .secondary)
                .disabled(stoppedCount == 0)
                .accessibilityLabel(pruneContainersLabel)

                Button { service.showRunSheet = true } label: {
                    Image(systemName: "plus")
                }
                .help("Run new container")
                .disabled(service.daemonState != .running)
                .accessibilityLabel("Run new container")
            }
        }
        .alert(removeContainersAlertTitle, isPresented: $showPruneAlert) {
            Button("Remove", role: .destructive) {
                Task { await service.pruneContainers() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }

    // MARK: – Empty states

    private var emptySearch: some View {
        EmptyStateView(icon: "magnifyingglass", title: "No results for \"\(searchText)\"")
    }

    @ViewBuilder
    private var daemonEmptyState: some View {
        switch service.daemonState {
        case .notInstalled:
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Image(systemName: "shippingbox.and.arrow.backward")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)
                    Text("Apple Container not installed")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Install Apple Container with Homebrew to manage\nlightweight macOS VMs.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 12) {
                    OnboardingStep(number: 1, title: "Install Homebrew (if needed)",
                                  code: "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"")
                    OnboardingStep(number: 2, title: "Add the Apple Container tap",
                                  code: "brew tap apple/apple")
                    OnboardingStep(number: 3, title: "Install Apple Container",
                                  code: "brew install container")
                    OnboardingStep(number: 4, title: "Start the service",
                                  code: "container system start")
                }
                .frame(maxWidth: 420)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()

        case .notRunning:
            EmptyStateView(
                icon: "poweroff",
                iconColor: .orange,
                title: "Service is not running",
                subtitle: "The Apple Container daemon needs to be started before you can manage containers."
            ) {
                Button {
                    Task { await service.startDaemon() }
                } label: {
                    Label("Start Service", systemImage: "play.fill")
                        .frame(minWidth: 130)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)
            }

        case .starting:
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Starting Apple Container…")
                    .font(.system(size: 14, weight: .medium))
                Text("This may take a few seconds")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .unknown:
            VStack(spacing: 10) {
                ProgressView()
                Text("Connecting…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .running:
            EmptyStateView(
                icon: "cube.box",
                title: "No containers",
                subtitle: "Run your first container to get started."
            ) {
                Button { service.showRunSheet = true } label: {
                    Label("Run Container", systemImage: "play.fill")
                        .frame(minWidth: 130)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)
            }
        }
    }
}

// MARK: – Onboarding step

private struct OnboardingStep: View {
    let number: Int
    let title: LocalizedStringKey
    let code: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.blue))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                HStack(spacing: 6) {
                    Text(code)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                    Spacer(minLength: 0)
                    CopyButton(text: code, help: "Copy command")
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
        }
    }
}
