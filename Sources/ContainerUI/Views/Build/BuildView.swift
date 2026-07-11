import SwiftUI
import AppKit

struct BuildView: View {
    @Binding var sidebarItem: SidebarItem
    @Binding var selectedImage: ImageInfo?
    @EnvironmentObject var service: ContainerService

    @State private var contextDir: URL?
    @State private var detectedFile: String?
    @State private var tag = ""
    @State private var buildArgs: [EnvVar] = []
    @State private var logText = ""
    @State private var isBuilding = false
    @State private var buildTask: BuildTask?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    formSection("Build context") {
                        HStack(spacing: 8) {
                            Text(contextDir?.path ?? String(localized: "No folder selected"))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(contextDir == nil ? .secondary : .primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button("Choose…", action: chooseFolder)
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }

                        if let contextDir {
                            if let detectedFile {
                                Label("Found \(detectedFile)", systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.green)
                            } else {
                                Label("No Dockerfile or Containerfile in \(contextDir.lastPathComponent)", systemImage: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.orange)
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
                                        .foregroundStyle(.secondary)
                                        .font(.system(size: 13, design: .monospaced))
                                    TextField("value", text: $arg.value)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 12, design: .monospaced))
                                        .frame(maxWidth: .infinity)
                                    Button {
                                        buildArgs.removeAll { $0.id == arg.id }
                                    } label: {
                                        Image(systemName: "minus.circle.fill").foregroundStyle(.red)
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
                        ErrorBanner(message: error) { self.error = nil }
                    }

                    if isBuilding || !logText.isEmpty {
                        formSection("Build log") {
                            ScrollViewReader { proxy in
                                ScrollView {
                                    Text(logText)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .textSelection(.enabled)
                                        .padding(10)
                                        .id("logBottom")
                                }
                                .frame(height: 280)
                                .background(Color(nsColor: .textBackgroundColor).opacity(0.4))
                                .onChange(of: logText) { _, _ in
                                    proxy.scrollTo("logBottom", anchor: .bottom)
                                }
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
                        buildTask?.cancel()
                    }
                    .buttonStyle(.bordered)
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
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(isBuilding || contextDir == nil || detectedFile == nil || tag.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .navigationTitle("Build Image")
    }

    @ViewBuilder
    private func formSection<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
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
        contextDir = url
        detectedFile = ContainerService.detectBuildFile(in: url)
    }

    private func startBuild() async {
        guard let contextDir else { return }
        let trimmedTag = tag.trimmingCharacters(in: .whitespaces)
        guard !trimmedTag.isEmpty else { return }

        error = nil
        logText = ""
        isBuilding = true

        let args = buildArgs.filter { !$0.key.isEmpty }.map { "\($0.key)=\($0.value)" }
        let task = service.startBuild(tag: trimmedTag, contextDir: contextDir.path, buildArgs: args)
        buildTask = task

        do {
            for try await chunk in task.output {
                logText += chunk
            }
            service.notifyBuildFinished(tag: trimmedTag, success: true)
            await service.fetchImages()
            if let built = service.images.first(where: { imageMatches(containerImage: trimmedTag, image: $0) }) {
                selectedImage = built
                sidebarItem = .images
            }
        } catch {
            self.error = error.localizedDescription
            service.notifyBuildFinished(tag: trimmedTag, success: false)
        }

        isBuilding = false
        buildTask = nil
    }
}
