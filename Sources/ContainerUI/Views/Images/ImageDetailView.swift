import SwiftUI

struct ImageDetailView: View {
    let image: ImageInfo
    @EnvironmentObject var service: ContainerService
    @State private var showRunSheet = false
    @State private var showDeleteAlert = false
    @State private var copiedKey: String?

    private var iconInfo: (symbol: String, color: Color) { imageIcon(for: image.name) }

    private var registry: String {
        let parts = image.name.components(separatedBy: "/")
        guard parts.count > 1 else { return "docker.io" }
        let first = parts[0]
        return first.contains(".") || first.contains(":") ? first : "docker.io"
    }

    private var usingContainers: [ContainerInfo] {
        service.containers.filter { imageMatches(containerImage: $0.image, image: image) }
    }

    private var runningContainers: [ContainerInfo] { usingContainers.filter { $0.state.isRunning } }
    private var stoppedContainers: [ContainerInfo] { usingContainers.filter { !$0.state.isRunning } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Hero header
                VStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(iconInfo.color.opacity(0.15))
                            .frame(width: 72, height: 72)
                        Image(systemName: iconInfo.symbol)
                            .font(.system(size: 32))
                            .foregroundStyle(iconInfo.color)
                    }

                    VStack(spacing: 6) {
                        Text(image.shortName)
                            .font(.system(size: 20, weight: .bold))
                            .multilineTextAlignment(.center)

                        HStack(spacing: 6) {
                            if image.tag == "latest" {
                                tagBadge(image.tag, color: .secondary)
                            } else {
                                tagBadge(image.tag, color: iconInfo.color)
                            }
                            usageStatusBadge
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 20)

                Divider()

                // Details
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Details")

                    infoRow(label: "Full name", value: image.name)
                    infoRow(label: "Tag",       value: image.tag)
                    infoRow(label: "Registry",  value: registry)
                    copyableRow(label: "Ref",    value: image.ref,    key: "ref")
                    copyableRow(label: "Digest", value: image.digest, key: "digest")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider()

                // Container usage
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Used by")

                    if usingContainers.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "circle")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                            Text("Not used by any container")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        VStack(spacing: 6) {
                            ForEach(usingContainers) { container in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(container.state.color)
                                        .frame(width: 7, height: 7)
                                    Text(container.id)
                                        .font(.system(size: 12, weight: .medium))
                                    Spacer()
                                    Text(container.state.label)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider()

                // Pull command
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader("Pull command")

                    copyableCode("container image pull \(image.ref)", key: "pull")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider()

                // Actions
                HStack(spacing: 10) {
                    Button {
                        showRunSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text("Run container")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(iconInfo.color)

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("Delete")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(!usingContainers.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .controlSize(.large)

                if !usingContainers.isEmpty {
                    Text("Stop all containers using this image before deleting.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(image.shortName)
        .alert("Delete \"\(image.ref)\"?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task { await service.deleteImage(image.ref) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the image from local storage.")
        }
        .sheet(isPresented: $showRunSheet) {
            RunContainerSheet(imageRef: image.ref, defaultPorts: [], defaultMemory: "512M", defaultEnv: [])
                .environmentObject(service)
        }
    }

    // MARK: – Helpers

    @ViewBuilder
    private var usageStatusBadge: some View {
        if runningContainers.count > 0 {
            Label("\(runningContainers.count) running", systemImage: "circle.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.green)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.green.opacity(0.1))
                .clipShape(Capsule())
        } else if stoppedContainers.count > 0 {
            Label("\(stoppedContainers.count) stopped", systemImage: "circle.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.orange)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.orange.opacity(0.1))
                .clipShape(Capsule())
        } else {
            Label("Unused", systemImage: "circle")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private func tagBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(color == .secondary ? Color.secondary : color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background((color == .secondary ? Color(nsColor: .controlBackgroundColor) : color.opacity(0.12)))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func copyableRow(label: String, value: String, key: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
                copiedKey = key
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copiedKey = nil }
            } label: {
                Image(systemName: copiedKey == key ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11))
                    .foregroundStyle(copiedKey == key ? Color.green : Color(nsColor: .tertiaryLabelColor))
            }
            .buttonStyle(.plain)
            .help("Copy \(label)")
        }
    }

    @ViewBuilder
    private func copyableCode(_ code: String, key: String) -> some View {
        HStack(spacing: 6) {
            Text(code)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .textSelection(.enabled)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(code, forType: .string)
                copiedKey = key
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copiedKey = nil }
            } label: {
                Image(systemName: copiedKey == key ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundStyle(copiedKey == key ? Color.green : Color(nsColor: .tertiaryLabelColor))
            }
            .buttonStyle(.plain)
            .help("Copy command")
        }
    }
}
