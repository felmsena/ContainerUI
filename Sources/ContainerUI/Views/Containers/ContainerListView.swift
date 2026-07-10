import SwiftUI

struct ContainerListView: View {
    @EnvironmentObject var service: ContainerService
    @Binding var selected: ContainerInfo?
    @State private var searchText = ""
    @State private var showRunSheet = false
    @State private var showPruneAlert = false

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
                            .onTapGesture { selected = container }
                        }
                    }
                    .padding(12)
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
                .help("Prune \(stoppedCount) stopped container\(stoppedCount == 1 ? "" : "s")")
                .foregroundStyle(stoppedCount > 0 ? .orange : .secondary)
                .disabled(stoppedCount == 0)

                Button { showRunSheet = true } label: {
                    Image(systemName: "plus")
                }
                .help("Run new container")
                .disabled(service.daemonState != .running)
            }
        }
        .alert("Remove \(stoppedCount) stopped container\(stoppedCount == 1 ? "" : "s")?", isPresented: $showPruneAlert) {
            Button("Remove", role: .destructive) {
                Task { await service.pruneContainers() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(isPresented: $showRunSheet) {
            RunContainerSheet(imageRef: "", defaultPorts: [], defaultMemory: "512M", defaultEnv: [])
                .environmentObject(service)
        }
    }

    // MARK: – Empty states

    private var emptySearch: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36)).foregroundStyle(.quaternary)
            Text("No results for \"\(searchText)\"")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            StateView(
                icon: "poweroff",
                iconColor: .orange,
                title: "Service is not running",
                subtitle: "The Apple Container daemon needs to be started before you can manage containers.",
                detail: nil
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
            StateView(
                icon: "cube.box",
                iconColor: nil,
                title: "No containers",
                subtitle: "Run your first container to get started.",
                detail: nil
            ) {
                Button { showRunSheet = true } label: {
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
    let title: String
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

// MARK: – Reusable state view

private struct StateView<Actions: View>: View {
    let icon: String
    let iconColor: Color?
    let title: String
    let subtitle: String
    let detail: String?
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(iconColor.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.quaternary))

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
            }

            if let detail {
                Text(detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .textSelection(.enabled)
            }

            actions()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
