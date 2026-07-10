import SwiftUI

struct VolumesView: View {
    @EnvironmentObject var service: ContainerService
    @Binding var selected: VolumeInfo?
    @State private var showCreateSheet = false

    var body: some View {
        VStack(spacing: 0) {
            if service.volumes.isEmpty {
                EmptyStateView(icon: "externaldrive", title: "No volumes") {
                    Button("Create volume") { showCreateSheet = true }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                }
            } else {
                List(service.volumes, selection: $selected) { volume in
                    VolumeRowView(volume: volume, isSelected: selected?.id == volume.id)
                        .tag(volume)
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Volumes")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await service.fetchVolumes() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }.help("Refresh")

                Button {
                    Task { await service.pruneVolumes() }
                } label: {
                    Image(systemName: "trash.slash")
                }.help("Prune unused volumes")

                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }.help("Create volume")
            }
        }
        .task { await service.fetchVolumes() }
        .sheet(isPresented: $showCreateSheet) {
            CreateVolumeSheet(isPresented: $showCreateSheet)
        }
    }
}

struct VolumeRowView: View {
    let volume: VolumeInfo
    let isSelected: Bool
    @EnvironmentObject var service: ContainerService
    @State private var showDeleteAlert = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(volume.name)
                    .font(.system(size: 13, weight: .medium))
                HStack(spacing: 6) {
                    if !volume.driver.isEmpty {
                        Text(volume.driver)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    if !volume.type.isEmpty {
                        Text("·").foregroundStyle(.tertiary).font(.system(size: 11))
                        Text(volume.type)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            Button {
                showDeleteAlert = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("Delete volume")
        }
        .padding(.vertical, 4)
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
    @EnvironmentObject var service: ContainerService
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
                    .tint(.green)
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
