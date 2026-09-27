import SwiftUI
import AppKit

struct BuildView: View {
    @Environment(ContainerService.self) private var service
    @Environment(AppState.self) private var app

    @AppStorage("lastBuildContext") private var contextPath = ""
    @AppStorage("lastBuildTag") private var tag = ""
    @State private var detectedFile: String?
    @State private var buildArgs: [EnvVar] = []
    /// The build started from this form. Held by the service, so it keeps
    /// running (and stays cancellable) if you navigate away and back.
    @State private var jobID: UUID?

    private var contextDir: URL? { contextPath.isEmpty ? nil : URL(fileURLWithPath: contextPath) }

    private var job: BackgroundJob? {
        if let jobID, let job = service.jobs.first(where: { $0.id == jobID }) { return job }
        return service.latestJob(.build)
    }

    private var isBuilding: Bool { job?.isRunning == true }

    private var error: String? {
        if case .failed(let message) = job?.status { return message }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    formSection("Build context") {
                        HStack(spacing: 8) {
                            Text(contextDir?.path ?? String(localized: "No folder selected"))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(contextDir == nil ? Theme.text2 : Theme.text)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button("Choose…", action: chooseFolder)
                                .buttonStyle(BrandButtonStyle(kind: .secondary, compact: true))
                        }

                        if let contextDir {
                            if let detectedFile {
                                Label("Found \(detectedFile)", systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.accent)
                            } else {
                                Label("No Dockerfile or Containerfile in \(contextDir.lastPathComponent)", systemImage: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.warn)
                            }
                        }
                    }

                    formSection("Tag") {
                        TextField("name:tag, e.g. myapp:latest", text: $tag)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13, design: .monospaced))
                            .disabled(isBuilding)
                    }

                    formSection("Build Args (optional)") {
                        VStack(spacing: 6) {
                            ForEach($buildArgs) { $arg in
                                HStack(spacing: 8) {
                                    TextField("KEY", text: $arg.key)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 12, design: .monospaced))
                                        .frame(maxWidth: .infinity)
                                    Text("=")
                                        .foregroundStyle(Theme.text2)
                                        .font(.system(size: 13, design: .monospaced))
                                    TextField("value", text: $arg.value)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 12, design: .monospaced))
                                        .frame(maxWidth: .infinity)
                                    Button {
                                        buildArgs.removeAll { $0.id == arg.id }
                                    } label: {
                                        Image(systemName: "minus.circle.fill").foregroundStyle(Theme.danger)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Remove build argument")
                                }
                            }
                            .disabled(isBuilding)
                            Button {
                                buildArgs.append(EnvVar(key: "", value: ""))
                            } label: {
                                Label("Add build arg", systemImage: "plus.circle")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.borderless)
                            .disabled(isBuilding)
                        }
                    }

                    if let error {
                        ErrorBanner(message: error) { jobID = nil; service.clearFinishedJobs() }
                    }

                    if let job {
                        formSection(job.isRunning ? "Build log — \(job.subject)" : "Last build — \(job.subject)") {
                            LogTextView(text: job.log)
                                .frame(height: 300)
                                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.border))
                            if job.status == .succeeded, let built = builtImage(for: job) {
                                Button {
                                    app.selectedImage = built
                                    app.sidebarItem = .images
                                } label: {
                                    Label("Show \(built.ref) in Images", systemImage: "arrow.right.circle")
                                }
                                .buttonStyle(BrandButtonStyle(kind: .secondary, compact: true))
                            }
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Spacer()
                if isBuilding {
                    Button("Cancel", role: .destructive) {
                        job?.cancel()
                    }
                    .buttonStyle(BrandButtonStyle(kind: .destructive))
                }
                Button {
                    Task { await startBuild() }
                } label: {
                    HStack(spacing: 6) {
                        if isBuilding {
                            ProgressView().scaleEffect(0.7).frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "hammer.fill")
                        }
                        Text(isBuilding ? "Building…" : "Build")
                    }
                }
                .buttonStyle(BrandButtonStyle(kind: .primary))
                .disabled(isBuilding || contextDir == nil || detectedFile == nil || tag.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .navigationTitle("Build Image")
        .onAppear {
            if let contextDir { detectedFile = ContainerService.detectBuildFile(in: contextDir) }
        }
    }

    @ViewBuilder
    private func formSection<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text2)
            content()
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        contextPath = url.path
        detectedFile = ContainerService.detectBuildFile(in: url)
    }

    private func builtImage(for job: BackgroundJob) -> ImageInfo? {
        service.images.first { imageMatches(containerImage: job.subject, image: $0) }
    }

    private func startBuild() async {
        guard let contextDir else { return }
        let trimmedTag = tag.trimmingCharacters(in: .whitespaces)
        guard !trimmedTag.isEmpty else { return }
        let args = buildArgs.filter { !$0.key.isEmpty }.map { "\($0.key)=\($0.value)" }
        jobID = service.startBuild(tag: trimmedTag, contextDir: contextDir.path, buildArgs: args).id
    }
}
