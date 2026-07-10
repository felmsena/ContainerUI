import SwiftUI

struct ImagesView: View {
    @EnvironmentObject var service: ContainerService
    @Binding var selected: ImageInfo?
    @State private var searchText = ""
    @State private var showPullSheet = false
    @State private var pullRef = ""
    @State private var isPulling = false
    @State private var pullError: String?

    private var filtered: [ImageInfo] {
        guard !searchText.isEmpty else { return service.images }
        return service.images.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.tag.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var unusedCount: Int {
        service.images.filter { img in
            !service.containers.contains { imageMatches(containerImage: $0.image, image: img) }
        }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 13))
                TextField("Search images…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if filtered.isEmpty {
                if searchText.isEmpty {
                    EmptyStateView(icon: "photo.stack", title: "No images") {
                        Button("Pull an image") { showPullSheet = true }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                    }
                } else {
                    EmptyStateView(icon: "magnifyingglass", title: "No results for \"\(searchText)\"")
                }
            } else {
                List(filtered, selection: $selected) { image in
                    ImageRowView(image: image, isSelected: selected?.id == image.id)
                        .tag(image)
                }
                .listStyle(.inset)
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
                    Task { await service.pruneImages() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash.slash")
                        if unusedCount > 0 {
                            Text("\(unusedCount) unused")
                                .font(.system(size: 11))
                        }
                    }
                }
                .help("Prune \(unusedCount) unused image\(unusedCount == 1 ? "" : "s")")
                .foregroundStyle(unusedCount > 0 ? .orange : .secondary)
                .accessibilityLabel("Prune \(unusedCount) unused image\(unusedCount == 1 ? "" : "s")")

                Button {
                    pullRef = ""
                    pullError = nil
                    showPullSheet = true
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .help("Pull image")
                .accessibilityLabel("Pull image")
            }
        }
        .task { await service.fetchImages() }
        .sheet(isPresented: $showPullSheet) {
            PullImageSheet(isPresented: $showPullSheet)
        }
    }
}

func imageIcon(for name: String) -> (symbol: String, color: Color) {
    let base = name.split(separator: "/").last.map(String.init) ?? name
    let lower = base.lowercased()
    switch true {
    case lower.contains("postgres") || lower.contains("pgvector"):
        return ("cylinder.split.1x2.fill", .blue)
    case lower.contains("mysql") || lower.contains("mariadb"):
        return ("cylinder.split.1x2.fill", .orange)
    case lower.contains("mongo"):
        return ("cylinder.split.1x2.fill", .green)
    case lower.contains("redis"):
        return ("bolt.fill", .red)
    case lower.contains("nginx") || lower.contains("caddy") || lower.contains("traefik") || lower.contains("haproxy"):
        return ("network", .blue)
    case lower.contains("node") || lower.contains("deno") || lower.contains("bun"):
        return ("chevron.left.forwardslash.chevron.right", Color(red: 0.3, green: 0.7, blue: 0.3))
    case lower.contains("python"):
        return ("chevron.left.forwardslash.chevron.right", .yellow)
    case lower.contains("ruby") || lower.contains("rails"):
        return ("chevron.left.forwardslash.chevron.right", .red)
    case lower.contains("golang") || lower.contains("/go"):
        return ("chevron.left.forwardslash.chevron.right", .cyan)
    case lower.contains("rust"):
        return ("chevron.left.forwardslash.chevron.right", .orange)
    case lower.contains("java") || lower.contains("gradle") || lower.contains("maven"):
        return ("chevron.left.forwardslash.chevron.right", .red)
    case lower.contains("ubuntu") || lower.contains("debian") || lower.contains("centos") || lower.contains("fedora"):
        return ("terminal.fill", .purple)
    case lower.contains("alpine"):
        return ("mountain.2.fill", .gray)
    case lower.contains("kafka") || lower.contains("rabbit") || lower.contains("nats"):
        return ("arrow.left.arrow.right.circle.fill", .orange)
    case lower.contains("elastic") || lower.contains("opensearch") || lower.contains("kibana"):
        return ("magnifyingglass.circle.fill", Color(red: 1.0, green: 0.6, blue: 0.1))
    case lower.contains("grafana") || lower.contains("prometheus"):
        return ("chart.xyaxis.line", .orange)
    case lower.contains("jenkins") || lower.contains("gitlab") || lower.contains("drone"):
        return ("gearshape.2.fill", .indigo)
    case lower.contains("wordpress") || lower.contains("ghost") || lower.contains("drupal"):
        return ("globe", .blue)
    case lower.contains("minio") || lower.contains("s3"):
        return ("externaldrive.fill", .yellow)
    case lower.contains("sonar"):
        return ("doc.text.magnifyingglass", Color(red: 0.2, green: 0.55, blue: 0.85))
    case lower.contains("scanner") || lower.contains("cli"):
        return ("terminal.fill", .indigo)
    default:
        return ("shippingbox.fill", .secondary)
    }
}

struct ImageRowView: View {
    let image: ImageInfo
    var isSelected: Bool = false
    @EnvironmentObject var service: ContainerService
    @State private var showDeleteAlert = false
    @State private var showRunSheet = false

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
        case .running: return .green
        case .stopped: return .orange
        case .unused:  return Color(nsColor: .tertiaryLabelColor)
        }
    }

    private var usageTooltip: String {
        switch usageState {
        case .running: return "In use — container running"
        case .stopped: return "In use — container stopped"
        case .unused:  return "Not in use"
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
                    .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
                    .offset(x: 2, y: 2)
            }
            .frame(width: 32)
            .help(usageTooltip)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(image.shortName)
                        .font(.system(size: 13, weight: .medium))
                    if image.tag == "latest" {
                        Text(image.tag)
                            .font(.system(size: 11))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(.tertiary)
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
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                showRunSheet = true
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .help("Run container from this image")
            .accessibilityLabel("Run container from \(image.shortName)")

            Button {
                showDeleteAlert = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("Delete image")
            .accessibilityLabel("Delete \(image.shortName)")
        }
        .padding(.vertical, 4)
        .alert("Delete \"\(image.ref)\"?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task { await service.deleteImage(image.ref) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the image from local storage.")
        }
        .sheet(isPresented: $showRunSheet) {
            RunContainerSheet(imageRef: image.ref,
                              defaultPorts: [],
                              defaultMemory: "512M",
                              defaultEnv: [])
                .environmentObject(service)
        }
    }
}

struct PullImageSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var service: ContainerService
    @State private var ref = ""
    @State private var isPulling = false
    @State private var error: String?

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
                    .onSubmit { Task { await pull() } }
            }

            if let error {
                ErrorBanner(message: error) { self.error = nil }
            }

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.escape)
                Button("Pull") {
                    Task { await pull() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(ref.trimmingCharacters(in: .whitespaces).isEmpty || isPulling)
            }

            if isPulling {
                ProgressView("Pulling \(ref)…")
                    .progressViewStyle(.linear)
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    func pull() async {
        let trimmed = ref.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isPulling = true
        error = nil
        do {
            try await service.pullImage(trimmed)
            isPresented = false
        } catch {
            self.error = error.localizedDescription
        }
        isPulling = false
    }
}
