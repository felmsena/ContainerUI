import SwiftUI
import UniformTypeIdentifiers

struct RunContainerSheet: View {
    @Environment(ContainerService.self) private var service
    @Environment(\.dismiss) private var dismiss

    /// Everything except the list-valued fields, which are edited as pairs.
    @State private var spec: RunSpec
    @State private var ports: [EditablePair]
    @State private var envVars: [EditablePair]
    @State private var mounts: [EditablePair]
    @State private var labels: [EditablePair]
    @State private var showAdvanced: Bool
    @State private var isRunning = false
    @State private var error: String?

    private let memoryOptions = ["256M", "512M", "1G", "2G", "4G", "8G", "16G"]
    private let cpuOptions = Array(1...8)

    init(spec: RunSpec) {
        var base = spec
        if base.memory == nil { base.memory = "512M" }
        if base.cpus == nil { base.cpus = 1 }
        _spec = State(initialValue: base)
        _ports = State(initialValue: spec.ports.map { raw in
            // "host:container[/proto]" or "ip:host:container": the container
            // side is after the last colon.
            guard let colon = raw.lastIndex(of: ":") else { return EditablePair(left: raw) }
            return EditablePair(left: String(raw[..<colon]), right: String(raw[raw.index(after: colon)...]))
        })
        _envVars = State(initialValue: spec.env.map { EditablePair(splitting: $0, separator: "=") })
        _mounts = State(initialValue: spec.volumes.map { EditablePair(splitting: $0, separator: ":") })
        _labels = State(initialValue: spec.labels.map { EditablePair(splitting: $0, separator: "=") })
        _showAdvanced = State(initialValue: Self.hasAdvancedOptions(spec))
    }

    private static func hasAdvancedOptions(_ s: RunSpec) -> Bool {
        !s.command.isEmpty || !s.entrypoint.isEmpty || !s.workdir.isEmpty || !s.user.isEmpty
            || !s.platform.isEmpty || s.rosetta || s.removeOnExit || s.readOnly || s.useInit
            || s.forwardSSH || !s.labels.isEmpty || !s.envFile.isEmpty
    }

    /// The spec with the pair editors folded back in — what runs, and what
    /// the preview shows.
    private var fullSpec: RunSpec {
        var s = spec
        s.ports = ports.filter { !$0.left.isEmpty && !$0.right.isEmpty }.map { $0.joined(":") }
        s.env = envVars.filter { !$0.left.isEmpty }.map { $0.joined("=") }
        s.volumes = mounts.filter { !$0.left.isEmpty && !$0.right.isEmpty }.map { $0.joined(":") }
        s.labels = labels.filter { !$0.left.isEmpty }.map { $0.joined("=") }
        return s
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    basics
                    FormSection("Port Mappings") {
                        PairListEditor(pairs: $ports, leftPlaceholder: "Host", rightPlaceholder: "Container",
                                       separator: "→", addLabel: "Add port", removeLabel: "Remove port mapping")
                    }
                    FormSection("Environment Variables") {
                        PairListEditor(pairs: $envVars, leftPlaceholder: "KEY", rightPlaceholder: "value",
                                       separator: "=", addLabel: "Add variable", removeLabel: "Remove environment variable") {
                            Button {
                                chooseEnvFile()
                            } label: {
                                Label(spec.envFile.isEmpty ? "Load .env file…" : (spec.envFile as NSString).lastPathComponent,
                                      systemImage: "doc.text")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.borderless)
                            .help(spec.envFile.isEmpty ? "Pass a KEY=value file with --env-file" : spec.envFile)
                            if !spec.envFile.isEmpty {
                                Button { spec.envFile = "" } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.text3)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove env file")
                            }
                        }
                    }
                    FormSection("Volume Mounts") {
                        PairListEditor(pairs: $mounts, leftPlaceholder: "volume-name or /host/path", rightPlaceholder: "/data",
                                       separator: ":", addLabel: "Add mount", removeLabel: "Remove volume mount") {
                            if !service.volumes.isEmpty {
                                Menu {
                                    ForEach(service.volumes) { vol in
                                        Button(vol.name) { mounts.append(EditablePair(left: vol.name, right: "")) }
                                    }
                                } label: {
                                    Label("From existing volume", systemImage: "externaldrive")
                                        .font(.system(size: 12))
                                }
                                .menuStyle(.borderlessButton)
                                .fixedSize()
                            }
                        }
                    }
                    advanced
                    preview
                    if let error {
                        ErrorBanner(message: error) { self.error = nil }
                    }
                }
                .padding(20)
            }
            Divider()
            footer
        }
        .frame(minWidth: 560, maxWidth: 680, minHeight: 640, maxHeight: 900)
        .background(Theme.bg)
        .task {
            if service.networks.isEmpty { await service.fetchNetworks() }
            if service.volumes.isEmpty { await service.fetchVolumes() }
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Theme.accent)
            Text("Run Container")
                .font(.headline)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.text3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var basics: some View {
        VStack(alignment: .leading, spacing: 20) {
            FormSection("Image") {
                TextField("e.g. nginx:alpine, postgres:16", text: $spec.image)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
            }
            FormSection("Name (optional)") {
                TextField("Leave empty for auto-generated name", text: $spec.name)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
            }
            HStack(alignment: .top, spacing: 16) {
                FormSection("Memory") {
                    Picker("", selection: Binding(get: { spec.memory ?? "512M" }, set: { spec.memory = $0 })) {
                        ForEach(memoryOptions + (memoryOptions.contains(spec.memory ?? "") ? [] : [spec.memory ?? "512M"]), id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                FormSection("CPUs") {
                    Picker("", selection: Binding(get: { spec.cpus ?? 1 }, set: { spec.cpus = $0 })) {
                        ForEach(cpuOptions + (cpuOptions.contains(spec.cpus ?? 1) ? [] : [spec.cpus ?? 1]), id: \.self) {
                            Text("\($0)").tag($0)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                FormSection("Network") {
                    Picker("", selection: $spec.network) {
                        Text("default").tag("")
                        ForEach(service.networks.filter { $0.name != "default" }) { net in
                            Text(net.name).tag(net.name)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }
        }
    }

    private var advanced: some View {
        DisclosureGroup(isExpanded: $showAdvanced) {
            VStack(alignment: .leading, spacing: 16) {
                FormSection("Command (overrides the image's CMD)") {
                    TextField("e.g. npm run dev", text: $spec.command)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                }
                HStack(spacing: 12) {
                    FormSection("Entrypoint") {
                        TextField("image default", text: $spec.entrypoint)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                    }
                    FormSection("Working directory") {
                        TextField("/app", text: $spec.workdir)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                    }
                    FormSection("User") {
                        TextField("uid[:gid] or name", text: $spec.user)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                    }
                }
                FormSection("Platform") {
                    Picker("", selection: $spec.platform) {
                        Text("Native (linux/arm64)").tag("")
                        Text("linux/amd64 (x86, via Rosetta)").tag("linux/amd64")
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                    .onChange(of: spec.platform) { _, platform in
                        if platform == "linux/amd64" { spec.rosetta = true }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Remove the container when it stops (--rm)", isOn: $spec.removeOnExit)
                    Toggle("Read-only root filesystem", isOn: $spec.readOnly)
                    Toggle("Run an init process (reaps zombies, forwards signals)", isOn: $spec.useInit)
                    Toggle("Forward the SSH agent", isOn: $spec.forwardSSH)
                    Toggle("Enable Rosetta", isOn: $spec.rosetta)
                }
                .toggleStyle(.checkbox)
                .font(.system(size: 12.5))
                FormSection("Labels") {
                    PairListEditor(pairs: $labels, leftPlaceholder: "key", rightPlaceholder: "value",
                                   separator: "=", addLabel: "Add label", removeLabel: "Remove label")
                }
            }
            .padding(.top, 12)
        } label: {
            Text("Advanced")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.text)
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Command preview")
                .font(.caption)
                .foregroundStyle(Theme.text2)
            HStack(alignment: .top, spacing: 6) {
                Text(fullSpec.commandLine(bin: service.bin))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.text2)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                CopyButton(text: fullSpec.commandLine(bin: service.bin), help: "Copy command")
            }
            .padding(10)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.escape)
                .buttonStyle(BrandButtonStyle(kind: .secondary))

            Button {
                Task { await run() }
            } label: {
                HStack(spacing: 6) {
                    Group {
                        if isRunning {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "play.fill")
                        }
                    }
                    .frame(width: 14, height: 14)
                    Text(isRunning ? "Running…" : "Run")
                }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(BrandButtonStyle(kind: .primary))
            .disabled(spec.image.trimmingCharacters(in: .whitespaces).isEmpty || isRunning)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: Actions

    private func chooseEnvFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        spec.envFile = url.path
        showAdvanced = true
    }

    private func run() async {
        isRunning = true
        error = nil
        do {
            try await service.runContainer(fullSpec)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isRunning = false
    }
}
