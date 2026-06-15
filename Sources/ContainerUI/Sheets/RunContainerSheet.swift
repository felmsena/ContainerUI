import SwiftUI

struct RunContainerSheet: View {
    @EnvironmentObject var service: ContainerService
    @Environment(\.dismiss) private var dismiss

    @State var imageRef: String
    @State private var name = ""
    @State private var ports: [PortMapping]
    @State private var memory: String
    @State private var cpus = 1
    @State private var envVars: [EnvVar]
    @State private var volumeMounts: [VolumeMount] = []
    @State private var isRunning = false
    @State private var error: String?

    private let memoryOptions = ["256M", "512M", "1G", "2G", "4G", "8G", "16G"]
    private let cpuOptions = Array(1...8)

    init(imageRef: String,
         defaultPorts: [(String, String)],
         defaultMemory: String,
         defaultEnv: [String]) {
        _imageRef = State(initialValue: imageRef)
        _ports = State(initialValue: defaultPorts.map { PortMapping(host: $0.0, container: $0.1) })
        _memory = State(initialValue: defaultMemory)
        _envVars = State(initialValue: defaultEnv.map { raw in
            let parts = raw.components(separatedBy: "=")
            return EnvVar(key: parts.first ?? "", value: parts.dropFirst().joined(separator: "="))
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.green)
                Text("Run Container")
                    .font(.headline)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Image
                    formSection("Image") {
                        TextField("e.g. nginx:alpine, postgres:16", text: $imageRef)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13, design: .monospaced))
                    }

                    // Name
                    formSection("Name (optional)") {
                        TextField("Leave empty for auto-generated name", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                    }

                    // Ports
                    formSection("Port Mappings") {
                        VStack(spacing: 6) {
                            ForEach($ports) { $port in
                                HStack(spacing: 8) {
                                    TextField("Host", text: $port.host)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 12, design: .monospaced))
                                        .frame(maxWidth: .infinity)
                                    Text("→")
                                        .foregroundStyle(.secondary)
                                    TextField("Container", text: $port.container)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 12, design: .monospaced))
                                        .frame(maxWidth: .infinity)
                                    Button {
                                        ports.removeAll { $0.id == port.id }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            Button {
                                ports.append(PortMapping(host: "", container: ""))
                            } label: {
                                Label("Add port", systemImage: "plus.circle")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    // Resources
                    HStack(spacing: 16) {
                        formSection("Memory") {
                            Picker("", selection: $memory) {
                                ForEach(memoryOptions, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }
                        formSection("CPUs") {
                            Picker("", selection: $cpus) {
                                ForEach(cpuOptions, id: \.self) { Text("\($0)").tag($0) }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }
                    }

                    // Env vars
                    formSection("Environment Variables") {
                        VStack(spacing: 6) {
                            ForEach($envVars) { $env in
                                HStack(spacing: 8) {
                                    TextField("KEY", text: $env.key)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 12, design: .monospaced))
                                        .frame(maxWidth: .infinity)
                                    Text("=")
                                        .foregroundStyle(.secondary)
                                        .font(.system(size: 13, design: .monospaced))
                                    TextField("value", text: $env.value)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 12, design: .monospaced))
                                        .frame(maxWidth: .infinity)
                                    Button {
                                        envVars.removeAll { $0.id == env.id }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            Button {
                                envVars.append(EnvVar(key: "", value: ""))
                            } label: {
                                Label("Add variable", systemImage: "plus.circle")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    // Volume Mounts
                    formSection("Volume Mounts") {
                        VStack(spacing: 6) {
                            ForEach($volumeMounts) { $mount in
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Source").font(.system(size: 10)).foregroundStyle(.tertiary)
                                        TextField("volume-name or /host/path", text: $mount.source)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.system(size: 12, design: .monospaced))
                                    }
                                    Text(":").foregroundStyle(.secondary).font(.system(size: 14, design: .monospaced))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Container path").font(.system(size: 10)).foregroundStyle(.tertiary)
                                        TextField("/data", text: $mount.target)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.system(size: 12, design: .monospaced))
                                    }
                                    Button {
                                        volumeMounts.removeAll { $0.id == mount.id }
                                    } label: {
                                        Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.top, 14)
                                }
                            }
                            HStack(spacing: 12) {
                                Button {
                                    volumeMounts.append(VolumeMount(source: "", target: ""))
                                } label: {
                                    Label("Add mount", systemImage: "plus.circle")
                                        .font(.system(size: 12))
                                }
                                .buttonStyle(.borderless)

                                if !service.volumes.isEmpty {
                                    Menu {
                                        ForEach(service.volumes) { vol in
                                            Button(vol.name) {
                                                volumeMounts.append(VolumeMount(source: vol.name, target: ""))
                                            }
                                        }
                                    } label: {
                                        Label("From existing volume", systemImage: "externaldrive")
                                            .font(.system(size: 12))
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }

                    // Command preview
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Command preview")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(commandPreview)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
                            )
                            .textSelection(.enabled)
                    }

                    if let error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)

                Button {
                    Task { await run() }
                } label: {
                    HStack(spacing: 6) {
                        Group {
                            if isRunning {
                                ProgressView().scaleEffect(0.7)
                            } else {
                                Image(systemName: "play.fill")
                            }
                        }
                        .frame(width: 14, height: 14)
                        Text(isRunning ? "Running…" : "Run")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(imageRef.trimmingCharacters(in: .whitespaces).isEmpty || isRunning)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 520, maxWidth: 640, minHeight: 620, maxHeight: 860)
    }

    @ViewBuilder
    private func formSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private var commandPreview: String {
        var parts = ["/opt/homebrew/bin/container", "run"]
        if !name.trimmingCharacters(in: .whitespaces).isEmpty {
            parts += ["--name", name.trimmingCharacters(in: .whitespaces)]
        }
        parts += ["-m", memory]
        if cpus > 1 { parts += ["--cpus", "\(cpus)"] }
        for p in ports where !p.host.isEmpty && !p.container.isEmpty {
            parts += ["-p", "\(p.host):\(p.container)"]
        }
        for v in volumeMounts where !v.source.isEmpty && !v.target.isEmpty {
            parts += ["-v", "\(v.source):\(v.target)"]
        }
        for e in envVars where !e.key.isEmpty {
            parts += ["-e", "\(e.key)=\(e.value)"]
        }
        let ref = imageRef.trimmingCharacters(in: .whitespaces)
        if !ref.isEmpty { parts.append(ref) }
        return parts.joined(separator: " ")
    }

    private func run() async {
        isRunning = true
        error = nil
        do {
            try await service.runContainer(
                image: imageRef.trimmingCharacters(in: .whitespaces),
                name: name.trimmingCharacters(in: .whitespaces).isEmpty ? nil : name.trimmingCharacters(in: .whitespaces),
                ports: ports.filter { !$0.host.isEmpty && !$0.container.isEmpty }.map { (host: $0.host, container: $0.container) },
                volumes: volumeMounts.filter { !$0.source.isEmpty && !$0.target.isEmpty }.map { "\($0.source):\($0.target)" },
                memory: memory,
                cpus: cpus,
                env: envVars.filter { !$0.key.isEmpty }.map { "\($0.key)=\($0.value)" }
            )
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isRunning = false
    }
}
