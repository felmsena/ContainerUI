import SwiftUI

struct RegistryDetailView: View {
    let entry: RegistryEntry
    @EnvironmentObject var service: ContainerService
    @State private var showRunSheet = false
    @State private var isPulling = false
    @State private var pullError: String?
    @State private var pullTask: Task<Void, Never>?

    private var isAlreadyPulled: Bool {
        service.images.contains { $0.name == entry.image }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero header
                VStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(entry.color.opacity(0.15))
                            .frame(width: 72, height: 72)
                        Image(systemName: entry.icon)
                            .font(.system(size: 34))
                            .foregroundStyle(entry.color)
                    }

                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Text(entry.name)
                                .font(.system(size: 20, weight: .bold))
                            if entry.isOfficial {
                                Label("Official", systemImage: "checkmark.seal.fill")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.blue)
                                    .padding(.horizontal, 7).padding(.vertical, 3)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }

                        Text(entry.fullRef)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    // Stats row
                    if entry.pullCount > 0 || entry.starCount > 0 {
                        HStack(spacing: 20) {
                            if entry.pullCount > 0 {
                                statPill(icon: "arrow.down.circle.fill",
                                         value: formatCount(entry.pullCount),
                                         label: "pulls")
                            }
                            if entry.starCount > 0 {
                                statPill(icon: "star.fill",
                                         value: "\(entry.starCount)",
                                         label: "stars")
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 20)

                Divider()

                // Description
                if !entry.description.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        sectionHeader("About")
                        Text(entry.description)
                            .font(.system(size: 13))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)

                    Divider()
                }

                // Default configuration
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Default Configuration")

                    configRow(label: "Image", value: entry.fullRef, monospaced: true)
                    configRow(label: "Memory", value: entry.defaultMemory, monospaced: true)

                    if !entry.defaultPorts.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ports")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.tertiary)
                                .textCase(.uppercase)
                            VStack(spacing: 4) {
                                ForEach(entry.defaultPorts, id: \.0) { host, container in
                                    HStack(spacing: 8) {
                                        Text(host)
                                            .font(.system(size: 12, design: .monospaced))
                                            .padding(.horizontal, 8).padding(.vertical, 3)
                                            .background(Color(nsColor: .controlBackgroundColor))
                                            .clipShape(RoundedRectangle(cornerRadius: 5))
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.tertiary)
                                        Text(container)
                                            .font(.system(size: 12, design: .monospaced))
                                            .padding(.horizontal, 8).padding(.vertical, 3)
                                            .background(Color(nsColor: .controlBackgroundColor))
                                            .clipShape(RoundedRectangle(cornerRadius: 5))
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }

                    if !entry.defaultEnv.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Environment Variables")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.tertiary)
                                .textCase(.uppercase)
                            VStack(alignment: .leading, spacing: 3) {
                                ForEach(entry.defaultEnv, id: \.self) { env in
                                    Text(env)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(nsColor: .controlBackgroundColor))
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider()

                // Error
                if let err = pullError {
                    ErrorBanner(message: err) { pullError = nil }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                }

                // Action buttons
                HStack(spacing: 10) {
                    Button {
                        if isPulling {
                            pullTask?.cancel()
                            isPulling = false
                        } else {
                            pullTask = Task { await pull() }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Group {
                                if isPulling {
                                    ProgressView().scaleEffect(0.7)
                                } else {
                                    Image(systemName: isAlreadyPulled ? "checkmark.circle.fill" : "arrow.down.circle")
                                }
                            }
                            .frame(width: 14, height: 14)
                            Text(isPulling ? "Cancel" : isAlreadyPulled ? "Already pulled" : "Pull image")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(isPulling ? .red : nil)
                    .disabled(isAlreadyPulled && !isPulling)

                    Button {
                        showRunSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text("Run")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(entry.color)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .controlSize(.large)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(entry.name)
        .task { await service.fetchImages() }
        .sheet(isPresented: $showRunSheet) {
            RunContainerSheet(
                imageRef: entry.fullRef,
                defaultPorts: entry.defaultPorts,
                defaultMemory: entry.defaultMemory,
                defaultEnv: entry.defaultEnv
            )
            .environmentObject(service)
        }
    }

    // MARK: – Helpers

    @ViewBuilder
    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    @ViewBuilder
    private func configRow(label: LocalizedStringKey, value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(monospaced ? .system(size: 12, design: .monospaced) : .system(size: 12))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
            Spacer()
        }
    }

    @ViewBuilder
    private func statPill(icon: String, value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(entry.color)
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    private func pull() async {
        isPulling = true
        pullError = nil
        do {
            try await service.pullImage(entry.fullRef)
        } catch {
            pullError = error.localizedDescription
        }
        isPulling = false
    }

}
