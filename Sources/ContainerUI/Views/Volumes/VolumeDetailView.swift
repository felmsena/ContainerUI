import SwiftUI

struct VolumeDetailView: View {
    let volume: VolumeInfo
    @EnvironmentObject var service: ContainerService
    @State private var showDeleteAlert = false
    @State private var copied = false

    private var usingContainers: [ContainerInfo] {
        // Best-effort: match containers whose image name contains the volume name
        // (not 100% accurate without container inspect, but useful as a hint)
        service.containers.filter {
            $0.id.localizedCaseInsensitiveContains(volume.name) ||
            $0.image.localizedCaseInsensitiveContains(volume.name)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Hero header
                VStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 72, height: 72)
                        Image(systemName: "externaldrive.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.blue)
                    }

                    VStack(spacing: 6) {
                        Text(volume.name)
                            .font(.system(size: 18, weight: .bold))
                            .multilineTextAlignment(.center)

                        HStack(spacing: 8) {
                            if !volume.type.isEmpty {
                                badge(volume.type, color: .blue)
                            }
                            if !volume.driver.isEmpty {
                                badge(volume.driver, color: .purple)
                            }
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

                    infoRow(label: "Name", value: volume.name, copyable: true)
                    if !volume.type.isEmpty   { infoRow(label: "Type",    value: volume.type) }
                    if !volume.driver.isEmpty { infoRow(label: "Driver",  value: volume.driver) }
                    if !volume.options.isEmpty { infoRow(label: "Options", value: volume.options, monospaced: true) }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider()

                // Usage hint
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader("Mount in a container")

                    Text("Use this volume when running a container by adding a mount:")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        Text("-v \(volume.name):/your/path")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                            .textSelection(.enabled)

                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("-v \(volume.name):/your/path", forType: .string)
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 12))
                                .foregroundStyle(copied ? Color.green : Color(nsColor: .tertiaryLabelColor))
                        }
                        .buttonStyle(.plain)
                        .help("Copy mount flag")
                        .accessibilityLabel(copied ? "Copied" : "Copy mount flag")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider()

                // Actions
                VStack(spacing: 8) {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete volume", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .controlSize(.large)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(volume.name)
        .alert("Delete volume \"\(volume.name)\"?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task { await service.deleteVolume(volume.name) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All data stored in this volume will be permanently lost.")
        }
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
    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func infoRow(label: String, value: String, monospaced: Bool = false, copyable: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(monospaced ? .system(size: 12, design: .monospaced) : .system(size: 12))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
            Spacer()
        }
    }
}
