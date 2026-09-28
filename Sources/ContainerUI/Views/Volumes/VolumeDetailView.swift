import SwiftUI

struct VolumeDetailView: View {
    let volume: VolumeInfo
    @Environment(ContainerService.self) private var service
    @State private var showDeleteAlert = false
    @State private var copied = false

    @Environment(AppState.self) private var app

    private var usingContainers: [ContainerInfo] { service.containers(using: volume) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                DetailHero(icon: "externaldrive.fill", color: Theme.Hue.volumes, title: volume.name) {
                    if !volume.type.isEmpty { HeroBadge(text: volume.type, color: Theme.Hue.blue) }
                    if !volume.driver.isEmpty { HeroBadge(text: volume.driver, color: Theme.Hue.violet) }
                }

                Divider()

                // Details
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("Details")

                    infoRow(label: "Name", value: volume.name, copyable: true)
                    if !volume.type.isEmpty   { infoRow(label: "Type",    value: volume.type) }
                    if !volume.driver.isEmpty { infoRow(label: "Driver",  value: volume.driver) }
                    if !volume.options.isEmpty { infoRow(label: "Options", value: volume.options, monospaced: true) }
                    if let size = volume.sizeInBytes { infoRow(label: "Max size", value: formatBytes(size)) }
                    if !volume.source.isEmpty { infoRow(label: "Disk image", value: volume.source, monospaced: true) }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider()

                // Usage
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader("Used by")
                    if usingContainers.isEmpty {
                        Text("Not mounted by any container")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.text2)
                    } else {
                        ForEach(usingContainers) { container in
                            Button {
                                app.selectedContainer = container
                                app.sidebarItem = .containers
                            } label: {
                                HStack(spacing: 8) {
                                    Circle().fill(container.state.isRunning ? Theme.accent : Theme.text3).frame(width: 7, height: 7)
                                    Text(container.id).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.text)
                                    Spacer()
                                    Text(container.state.label).font(.system(size: 11)).foregroundStyle(Theme.text2)
                                    Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(Theme.text3)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 7))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider()

                // Usage hint
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader("Mount in a container")

                    Text("Use this volume when running a container by adding a mount:")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.text2)

                    HStack(spacing: 6) {
                        Text("-v \(volume.name):/your/path")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Theme.text)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.surface2)
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
                                .foregroundStyle(copied ? Theme.accent : Theme.text3)
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
                    }
                    .buttonStyle(BrandButtonStyle(kind: .destructive, fill: true))
                    .disabled(!usingContainers.isEmpty)
                    if !usingContainers.isEmpty {
                        Text("Remove the containers that mount this volume before deleting it.")
                            .font(.caption)
                            .foregroundStyle(Theme.text2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
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
    private func infoRow(label: LocalizedStringKey, value: String, monospaced: Bool = false, copyable: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.text2)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(monospaced ? .system(size: 12, design: .monospaced) : .system(size: 12))
                .foregroundStyle(Theme.text)
                .textSelection(.enabled)
            Spacer()
        }
    }
}
