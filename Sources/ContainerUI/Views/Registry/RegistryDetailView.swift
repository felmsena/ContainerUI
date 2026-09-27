import SwiftUI

struct RegistryDetailView: View {
    let entry: RegistryEntry
    @Environment(ContainerService.self) private var service
    @Environment(AppState.self) private var app
    private var pullJob: BackgroundJob? { service.latestJob(.pull, subject: entry.fullRef) }
    private var isPulling: Bool { pullJob?.isRunning == true }
    private var pullError: String? {
        if case .failed(let message) = pullJob?.status { return message }
        return nil
    }

    /// Name *and* tag must match — a local `postgres:15` doesn't mean the
    /// catalog's `postgres:16` is already pulled.
    private var isAlreadyPulled: Bool {
        service.images.contains { imageMatches(containerImage: entry.fullRef, image: $0) }
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
                                    .foregroundStyle(Theme.accent)
                                    .padding(.horizontal, 7).padding(.vertical, 3)
                                    .background(Theme.accentSoft)
                                    .clipShape(Capsule())
                            }
                        }

                        Text(entry.fullRef)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Theme.text2)
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
                            .foregroundStyle(Theme.text)
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
                                .foregroundStyle(Theme.text3)
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
                                .foregroundStyle(Theme.text3)
                                .textCase(.uppercase)
                            VStack(alignment: .leading, spacing: 3) {
                                ForEach(entry.defaultEnv, id: \.self) { env in
                                    Text(env)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(Theme.text2)
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Theme.surface2)
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
                    ErrorBanner(message: err) { service.clearFinishedJobs() }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                }

                // Action buttons
                HStack(spacing: 10) {
                    Button {
                        if isPulling {
                            pullJob?.cancel()
                        } else {
                            service.startPull(entry.fullRef)
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
                    }
                    .buttonStyle(BrandButtonStyle(kind: isPulling ? .destructive : .secondary, fill: true))
                    .disabled(isAlreadyPulled && !isPulling)

                    Button {
                        app.runContainer(entry.runSpec)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text("Run")
                        }
                    }
                    .buttonStyle(BrandButtonStyle(kind: .primary, fill: true))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                if let pullJob, pullJob.isRunning {
                    JobProgressView(job: pullJob)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(entry.name)
        .task { await service.fetchImages() }
    }

    // MARK: – Helpers

    @ViewBuilder
    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.text3)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    @ViewBuilder
    private func configRow(label: LocalizedStringKey, value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.text2)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(monospaced ? .system(size: 12, design: .monospaced) : .system(size: 12))
                .foregroundStyle(Theme.text)
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
                .foregroundStyle(Theme.text3)
        }
    }


}
