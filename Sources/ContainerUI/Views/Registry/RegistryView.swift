import SwiftUI

// MARK: - Docker Hub detail (private, only used for Hub API enrichment)

private struct HubRepoDetail: Codable {
    let pullCount: Int
    let starCount: Int
    let description: String
    let isOfficial: Bool?

    enum CodingKeys: String, CodingKey {
        case pullCount = "pull_count"
        case starCount = "star_count"
        case description
        case isOfficial = "is_official"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pullCount   = (try? c.decode(Int.self,    forKey: .pullCount))   ?? 0
        starCount   = (try? c.decode(Int.self,    forKey: .starCount))   ?? 0
        description = (try? c.decode(String.self, forKey: .description)) ?? ""
        isOfficial  = try?  c.decode(Bool.self,   forKey: .isOfficial)
    }
}

// MARK: - Main View

struct RegistryView: View {
    @Binding var selectedEntry: RegistryEntry?
    @Environment(ContainerService.self) private var service
    @Environment(AppState.self) private var app
    @State private var mode: Mode = .browse
    @State private var categories: [RegistryCategory] = curatedCategories
    @State private var isLoadingHub = false
    @State private var hubLoadError: String?
    @State private var searchText = ""
    @State private var searchResults: [HubRepo] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    enum Mode: String, CaseIterable { case browse = "Featured"; case search = "Search" }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BrandTabs(
                    items: Mode.allCases.map { ($0, LocalizedStringKey($0.rawValue), true) },
                    selection: $mode
                )
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            switch mode {
            case .browse: browseTab
            case .search: searchTab
            }
        }
        .navigationTitle("Registry")
        .task { await loadHubData() }
    }

    // MARK: Browse

    private var browseTab: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let error = hubLoadError {
                        ErrorBanner(message: error) { hubLoadError = nil }
                            .padding(.horizontal, 16)
                    }

                    ForEach(categories) { category in
                        VStack(alignment: .leading, spacing: 10) {
                            Label(LocalizedStringKey(category.name), systemImage: category.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.text2)
                                .padding(.horizontal, 16)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210, maximum: 280), spacing: 10)],
                                      spacing: 10) {
                                ForEach(category.entries) { entry in
                                    RegistryCard(entry: entry,
                                                 isLoadingHub: isLoadingHub,
                                                 isSelected: selectedEntry?.id == entry.id) {
                                        selectedEntry = entry
                                    } onPull: {
                                        Task { try? await service.pullImage(entry.fullRef) }
                                    } onRun: {
                                        app.runContainer(entry.runSpec)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 16)
            }

            if isLoadingHub {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.6)
                    Text("Fetching Docker Hub data…")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.regularMaterial)
                .clipShape(Capsule())
                .padding(.top, 8)
            }
        }
    }

    // MARK: Search

    private var searchTab: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.text3).font(.system(size: 13))
                TextField("Search Docker Hub…", text: $searchText)
                    .textFieldStyle(.plain).font(.system(size: 12.5))
                    .onSubmit { triggerSearch() }
                    .onChange(of: searchText) { _, _ in triggerSearch() }
                if isSearching {
                    ProgressView().scaleEffect(0.6)
                } else if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.text3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 9))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.bg)

            Divider()

            if searchText.isEmpty {
                EmptyStateView(icon: "magnifyingglass", title: "Search for images on Docker Hub", subtitle: "nginx, postgres, redis…")
            } else if isSearching && searchResults.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Searching Docker Hub…")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty {
                EmptyStateView(icon: "questionmark.square.dashed", title: "No results for \"\(searchText)\"")
            } else {
                ZStack(alignment: .top) {
                    List(searchResults) { repo in
                        HubRepoRow(repo: repo) {
                            Task { try? await service.pullImage(repo.repoName) }
                        } onRun: {
                            app.runContainer(RunSpec(image: repo.repoName))
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedEntry = hubRepoToEntry(repo) }
                        .listRowBackground(
                            selectedEntry?.image == repo.repoName
                                ? Theme.accentSoft
                                : Color.clear
                        )
                    }
                    .listStyle(.inset)

                    if isSearching {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.6)
                            Text("Updating…").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.regularMaterial)
                        .clipShape(Capsule())
                        .padding(.top, 8)
                    }
                }
            }
        }
    }

    // MARK: Docker Hub fetch

    private func loadHubData() async {
        guard !isLoadingHub else { return }
        isLoadingHub = true
        hubLoadError = nil

        await withTaskGroup(of: (String, HubRepoDetail?).self) { group in
            for category in curatedCategories {
                for entry in category.entries {
                    group.addTask {
                        let detail = await fetchRepoDetail(namespace: entry.namespace, repo: entry.repoName)
                        return (entry.image, detail)
                    }
                }
            }

            var details: [String: HubRepoDetail] = [:]
            for await (image, detail) in group {
                if let d = detail { details[image] = d }
            }

            var updated = curatedCategories
            for ci in updated.indices {
                for ei in updated[ci].entries.indices {
                    let image = updated[ci].entries[ei].image
                    if let d = details[image] {
                        updated[ci].entries[ei].description = d.description
                        updated[ci].entries[ei].pullCount   = d.pullCount
                        updated[ci].entries[ei].starCount   = d.starCount
                        updated[ci].entries[ei].isOfficial  = d.isOfficial ?? updated[ci].entries[ei].isOfficial
                    }
                }
                updated[ci].entries.sort { $0.pullCount > $1.pullCount }
            }
            categories = updated
        }

        isLoadingHub = false
    }

    private func fetchRepoDetail(namespace: String, repo: String) async -> HubRepoDetail? {
        let path = namespace == "library"
            ? "https://hub.docker.com/v2/repositories/library/\(repo)/"
            : "https://hub.docker.com/v2/repositories/\(namespace)/\(repo)/"
        guard let url = URL(string: path) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return try? JSONDecoder().decode(HubRepoDetail.self, from: data)
    }

    private func hubRepoToEntry(_ repo: HubRepo) -> RegistryEntry {
        var entry = RegistryEntry(
            name: repo.repoName.components(separatedBy: "/").last?.capitalized ?? repo.repoName,
            image: repo.repoName,
            tag: "latest",
            category: "Search",
            icon: repo.isOfficial ? "checkmark.seal.fill" : "shippingbox.fill",
            color: .accentColor,
            defaultPorts: [],
            defaultMemory: "512M",
            defaultEnv: []
        )
        entry.description = repo.shortDescription
        entry.pullCount   = repo.pullCount
        entry.starCount   = repo.starCount
        entry.isOfficial  = repo.isOfficial
        return entry
    }

    @MainActor
    private func triggerSearch() {
        searchTask?.cancel()
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        searchTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 400_000_000)
                isSearching = true
                searchResults = try await fetchSearchResults(query: query)
            } catch is CancellationError {
                // new search started
            } catch {
                searchResults = []
            }
            isSearching = false
        }
    }

    private func fetchSearchResults(query: String) async throws -> [HubRepo] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlStr = "https://hub.docker.com/v2/search/repositories/?query=\(encoded)&page_size=25&page=1"
        guard let url = URL(string: urlStr) else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        return (try? JSONDecoder().decode(HubResponse.self, from: data))?.results ?? []
    }
}

// MARK: - Registry Card

struct RegistryCard: View {
    let entry: RegistryEntry
    let isLoadingHub: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onPull: () -> Void
    let onRun: () -> Void
    @Environment(ContainerService.self) private var service

    private var isAlreadyPulled: Bool {
        service.images.contains { $0.name == entry.image }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(entry.color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: entry.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(entry.color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(entry.name).font(.system(size: 13, weight: .semibold))
                        if entry.isOfficial {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 10)).foregroundStyle(Theme.accent)
                        }
                    }
                    Text(entry.fullRef)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.text2)
                }
            }
            .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 6)

            Group {
                if isLoadingHub && entry.description.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        RoundedRectangle(cornerRadius: 4).fill(Theme.border).frame(height: 8)
                        RoundedRectangle(cornerRadius: 4).fill(Theme.border).frame(width: 130, height: 8)
                    }
                } else {
                    Text(entry.description.isEmpty ? entry.fullRef : entry.description)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.text2)
                        .lineLimit(2)
                }
            }
            .frame(height: 28, alignment: .top)
            .padding(.horizontal, 12).padding(.bottom, 8)

            Group {
                if entry.pullCount > 0 {
                    HStack(spacing: 8) {
                        Label(formatCount(entry.pullCount), systemImage: "arrow.down.circle")
                            .font(.system(size: 10)).foregroundStyle(Theme.text3)
                        if entry.starCount > 0 {
                            Label("\(entry.starCount)", systemImage: "star.fill")
                                .font(.system(size: 10)).foregroundStyle(Theme.text3)
                        }
                    }
                } else if isLoadingHub {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.border)
                        .frame(width: 60, height: 8)
                }
            }
            .frame(height: 14, alignment: .leading)
            .padding(.horizontal, 12).padding(.bottom, 8)

            Divider()

            HStack(spacing: 6) {
                Button {
                    onPull()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isAlreadyPulled ? "checkmark" : "arrow.down.circle")
                            .font(.system(size: 10))
                        Text(isAlreadyPulled ? "Pulled" : "Pull")
                    }
                }
                .buttonStyle(BrandButtonStyle(kind: .secondary, fill: true))
                .disabled(isAlreadyPulled)

                Button {
                    onRun()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill").font(.system(size: 10))
                        Text("Run")
                    }
                }
                .buttonStyle(BrandButtonStyle(kind: .primary, fill: true))
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Theme.accentSoft : Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Theme.accent : Theme.border,
                                  lineWidth: isSelected ? 1.5 : 1))
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { onSelect() }
    }
}

// MARK: - Hub Repo Row

struct HubRepoRow: View {
    let repo: HubRepo
    let onPull: () -> Void
    let onRun: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.accentSoft)
                    .frame(width: 36, height: 36)
                Image(systemName: repo.isOfficial ? "checkmark.seal.fill" : "shippingbox.fill")
                    .font(.system(size: 16)).foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(repo.repoName).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.text)
                    if repo.isOfficial {
                        Text("Official")
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Theme.accentSoft).foregroundStyle(Theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                if !repo.shortDescription.isEmpty {
                    Text(repo.shortDescription).font(.system(size: 11)).foregroundStyle(Theme.text2).lineLimit(1)
                }
                HStack(spacing: 10) {
                    Label(formatCount(repo.pullCount), systemImage: "arrow.down.circle")
                        .font(.system(size: 10)).foregroundStyle(Theme.text3)
                    Label("\(repo.starCount)", systemImage: "star.fill")
                        .font(.system(size: 10)).foregroundStyle(Theme.text3)
                }
            }
            Spacer()
            HStack(spacing: 6) {
                Button("Pull", action: onPull).buttonStyle(BrandButtonStyle(kind: .secondary))
                Button { onRun() } label: {
                    Label("Run", systemImage: "play.fill")
                }.buttonStyle(BrandButtonStyle(kind: .primary))
            }
        }
        .padding(.vertical, 4)
    }
}
