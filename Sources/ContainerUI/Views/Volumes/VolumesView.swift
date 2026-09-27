import SwiftUI

struct VolumesView: View {
    @Environment(ContainerService.self) private var service
    @Binding var selected: VolumeInfo?
    @State private var showCreateSheet = false
    @State private var showPruneAlert = false

    var body: some View {
        VStack(spacing: 0) {
            if service.volumes.isEmpty {
                EmptyStateView(icon: "externaldrive", title: "No volumes") {
                    Button("Create volume") { showCreateSheet = true }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(service.volumes) { volume in
                            VolumeRowView(volume: volume, isSelected: selected?.id == volume.id)
                                .contentShape(Rectangle())
                                .onTapGesture { selected = volume }
                        }
                    }
                    .padding(12)
                }
                .background(Theme.bg)
            }
        }
        .navigationTitle("Volumes")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await service.fetchVolumes() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
                .accessibilityLabel("Refresh volumes")

                Button {
                    showPruneAlert = true
                } label: {
                    Image(systemName: "trash.slash")
                }
                .help("Prune unused volumes")
                .accessibilityLabel("Prune unused volumes")

                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Create volume")
                .accessibilityLabel("Create volume")
            }
        }
        .task { await service.fetchVolumes() }
        .alert("Remove all unused volumes?", isPresented: $showPruneAlert) {
            Button("Remove", role: .destructive) {
                Task { await service.pruneVolumes() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every volume not referenced by a container will be deleted, including the data stored in it. This action cannot be undone.")
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateVolumeSheet(isPresented: $showCreateSheet)
        }
    }
}

struct VolumeRowView: View {
    let volume: VolumeInfo
    let isSelected: Bool
    @Environment(ContainerService.self) private var service
    @State private var showDeleteAlert = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "#D97706").opacity(0.14))
                    .frame(width: 32, height: 32)
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "#D97706"))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(volume.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.text)
                HStack(spacing: 6) {
                    if !volume.driver.isEmpty {
                        Text(volume.driver)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.text2)
                    }
                    if !volume.type.isEmpty {
                        Text("·").foregroundStyle(Theme.text3).font(.system(size: 11))
                        Text(volume.type)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.text3)
                    }
                }
            }

            Spacer()

            Button {
                showDeleteAlert = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.danger)
            }
            .buttonStyle(.plain)
            .help("Delete volume")
            .accessibilityLabel("Delete \(volume.name)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Theme.accentSoft : Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isSelected ? Theme.accent : Theme.border, lineWidth: isSelected ? 1.5 : 1)
                )
        )
        .alert("Delete volume \"\(volume.name)\"?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task { await service.deleteVolume(volume.name) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All data stored in this volume will be lost.")
        }
    }
}

struct CreateVolumeSheet: View {
    @Binding var isPresented: Bool
    @Environment(ContainerService.self) private var service
    @State private var name = ""
    @State private var isCreating = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create volume")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Volume name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("my-volume", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await create() } }
            }

            if let error {
                ErrorBanner(message: error) { self.error = nil }
            }

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }.keyboardShortcut(.escape)
                Button("Create") { Task { await create() } }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    func create() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isCreating = true
        do {
            try await service.createVolume(trimmed)
            isPresented = false
        } catch {
            self.error = error.localizedDescription
        }
        isCreating = false
    }
}
