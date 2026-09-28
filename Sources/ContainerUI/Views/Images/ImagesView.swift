import SwiftUI

struct ImagesView: View {
    @Environment(ContainerService.self) private var service
    @Environment(AppState.self) private var app
    @Binding var selected: ImageInfo?
    @State private var searchText = ""
    @State private var showPruneAlert = false

    private var filtered: [ImageInfo] {
        guard !searchText.isEmpty else { return service.images }
        return service.images.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.tag.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var unusedImages: [ImageInfo] {
        service.images.filter { img in
            !img.isSystem && !service.containers.contains { imageMatches(containerImage: $0.image, image: img) }
        }
    }

    private var unusedCount: Int { unusedImages.count }

    /// Split into two fully-formed literals (rather than interpolating an
    /// English "s" suffix) so each pluralization gets its own, grammatically
    /// correct translation.
    private var pruneImagesLabel: LocalizedStringKey {
        unusedCount == 1 ? "Prune 1 unused image" : "Prune \(unusedCount) unused images"
    }

    private var removeImagesAlertTitle: LocalizedStringKey {
        unusedCount == 1 ? "Remove 1 unused image?" : "Remove \(unusedCount) unused images?"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.text3)
                    .font(.system(size: 13))
                TextField("Search images…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.text3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 9))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.bg)

            if filtered.isEmpty {
                if searchText.isEmpty {
                    EmptyStateView(icon: "photo.stack", title: "No images") {
                        Button("Pull an image") { app.showPullSheet = true }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.accent)
                    }
                } else {
                    EmptyStateView(icon: "magnifyingglass", title: "No results for \"\(searchText)\"")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filtered) { image in
                            ImageRowView(image: image, isSelected: selected?.id == image.id)
                                .contentShape(Rectangle())
                                .onTapGesture { selected = image }
                        }
                    }
                    .padding(12)
                }
                .background(Theme.bg)
                .listKeyboardNavigation(items: filtered, selection: $selected)
            }
        }
        .navigationTitle("Images")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await service.fetchImages() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
                .accessibilityLabel("Refresh images")

                Button {
                    showPruneAlert = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash.slash")
                        if unusedCount > 0 {
                            Text("\(unusedCount) unused")
                                .font(.system(size: 11))
                        }
                    }
                }
                .help(pruneImagesLabel)
                .foregroundStyle(unusedCount > 0 ? .orange : .secondary)
                .disabled(unusedCount == 0)
                .accessibilityLabel(pruneImagesLabel)

                Button {
                    app.showPullSheet = true
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .help("Pull image")
                .accessibilityLabel("Pull image")
            }
        }
        .task { await service.fetchImages() }
        .alert(removeImagesAlertTitle, isPresented: $showPruneAlert) {
            Button("Remove", role: .destructive) {
                let refs = unusedImages.map(\.ref)
                Task { await service.removeImages(refs) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(unusedImages.map(\.ref).joined(separator: "\n"))
        }
    }
}

struct ImageRowView: View {
    let image: ImageInfo
    var isSelected: Bool = false
    @Environment(ContainerService.self) private var service
    @Environment(AppState.self) private var app
    @State private var showDeleteAlert = false

    private var iconInfo: (symbol: String, color: Color) {
        imageIcon(for: image.name)
    }

    private enum UsageState { case running, stopped, unused }

    private var usageState: UsageState {
        let matching = service.containers.filter { imageMatches(containerImage: $0.image, image: image) }
        if matching.isEmpty { return .unused }
        return matching.contains { $0.state.isRunning } ? .running : .stopped
    }

    private var usageDotColor: Color {
        switch usageState {
        case .running: return Theme.accent
        case .stopped: return Theme.warn
        case .unused:  return Theme.text3
        }
    }

    private var usageTooltip: String {
        switch usageState {
        case .running: return String(localized: "In use — container running")
        case .stopped: return String(localized: "In use — container stopped")
        case .unused:  return String(localized: "Not in use")
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconInfo.color.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: iconInfo.symbol)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(iconInfo.color)
                }
                Circle()
                    .fill(usageDotColor)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Theme.surface, lineWidth: 1.5))
                    .offset(x: 2, y: 2)
            }
            .frame(width: 32)
            .help(usageTooltip)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(image.shortName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.text)
                    if image.tag == "latest" {
                        Text(image.tag)
                            .font(.system(size: 11))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(Theme.text3)
                    } else {
                        Text(image.tag)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(iconInfo.color.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(iconInfo.color)
                    }
                }
                Text(image.shortDigest)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.text3)
            }

            Spacer()

            Button {
                app.runContainer(RunSpec(image: image.ref))
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
            .help("Run container from this image")
            .accessibilityLabel("Run container from \(image.shortName)")

            Button {
                showDeleteAlert = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.danger)
            }
            .buttonStyle(.plain)
            .disabled(usageState != .unused)
            .opacity(usageState != .unused ? 0.35 : 1)
            .help(usageState != .unused ? "In use by a container" : "Delete image")
            .accessibilityLabel("Delete \(image.shortName)")
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
        .alert("Delete \"\(image.ref)\"?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task { await service.deleteImage(image.ref) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the image from local storage.")
        }
    }
}

struct PullImageSheet: View {
    @Binding var isPresented: Bool
    @Environment(ContainerService.self) private var service
    @State private var ref = ""

    private var trimmed: String { ref.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pull image")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Image reference")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. nginx:latest, postgres:16", text: $ref)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                    .onSubmit(pull)
                Text("The pull continues in the background — follow it from Activity in the toolbar.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.text3)
            }

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.escape)
                    .buttonStyle(BrandButtonStyle(kind: .secondary))
                Button("Pull", action: pull)
                    .buttonStyle(BrandButtonStyle(kind: .primary))
                    .disabled(trimmed.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
        .background(Theme.bg)
    }

    private func pull() {
        guard !trimmed.isEmpty else { return }
        service.startPull(trimmed)
        isPresented = false
    }
}
