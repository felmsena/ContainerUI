import SwiftUI

struct SettingsView: View {
    @AppStorage("refreshInterval") private var refreshInterval = 5
    @AppStorage("defaultBrowserPort") private var defaultPort = "9000"
    @AppStorage("notifyContainerStopped") private var notifyContainerStopped = true
    @AppStorage("notifyBuildFinished") private var notifyBuildFinished = true
    @AppStorage("notifyPullFinished") private var notifyPullFinished = false
    @AppStorage("autoCheckForUpdates") private var autoCheckForUpdates = true
    @AppStorage("appAppearance") private var appAppearance = AppAppearance.system
    @AppStorage(ContainerBinary.overrideKey) private var customBinaryPath = ""
    @State private var isCheckingForUpdates = false
    @Environment(ContainerService.self) private var service

    @AppStorage("dnsDomain") private var dnsDomain = "test"
    @State private var dnsDomains: [String] = []
    @State private var registryLogins: [RegistryLogin] = []
    @State private var showAddRegistrySheet = false
    @State private var registryError: String?
    @State private var loggingOutHostname: String?

    private let intervals = [3, 5, 10, 30, 60]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                SectionCard(title: "Binary") {
                    HStack(spacing: 8) {
                        Text("Path")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 90, alignment: .leading)
                        Text(service.bin)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(service.isBinaryInstalled ? Theme.text : Theme.danger)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                        if !service.isBinaryInstalled {
                            Text("Not found")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.danger)
                        }
                        Spacer()
                        Button("Choose…", action: chooseBinary)
                            .controlSize(.small)
                        if !customBinaryPath.isEmpty {
                            Button("Use default") {
                                customBinaryPath = ""
                                service.reloadBinaryPath()
                            }
                            .controlSize(.small)
                        }
                    }

                    Divider()

                    HStack {
                        Text("Version")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 90, alignment: .leading)
                        if let row = service.versionRows.first {
                            Text(row.version)
                                .font(.system(size: 12, design: .monospaced))
                        } else {
                            Text("—").foregroundStyle(.tertiary)
                                .font(.system(size: 12))
                        }
                    }
                }

                SectionCard(title: "Preferences") {
                    HStack {
                        Text("Appearance")
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $appAppearance) {
                            ForEach(AppAppearance.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 110)
                    }

                    Divider()

                    HStack {
                        Text("Refresh every")
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $refreshInterval) {
                            ForEach(intervals, id: \.self) { s in
                                Text("\(s)s").tag(s)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 70)
                    }

                    Divider()

                    HStack {
                        Text("Default browser port")
                            .font(.system(size: 13))
                        Spacer()
                        TextField("9000", text: $defaultPort)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                            .font(.system(size: 12, design: .monospaced))
                    }
                }

                SectionCard(title: "Updates") {
                    Toggle("Check for updates automatically", isOn: $autoCheckForUpdates)
                        .font(.system(size: 13))

                    Divider()

                    HStack {
                        if let update = service.availableUpdate {
                            Text("\(update.tagName) available")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("You're up to date")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            Task {
                                isCheckingForUpdates = true
                                await service.checkForUpdates(force: true)
                                isCheckingForUpdates = false
                            }
                        } label: {
                            if isCheckingForUpdates {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Text("Check Now")
                            }
                        }
                        .buttonStyle(BrandButtonStyle(kind: .secondary, compact: true))
                        .disabled(isCheckingForUpdates)
                    }
                }

                SectionCard(title: "Notifications") {
                    Toggle("Container stopped", isOn: $notifyContainerStopped)
                        .font(.system(size: 13))
                    Divider()
                    Toggle("Build finished", isOn: $notifyBuildFinished)
                        .font(.system(size: 13))
                    Divider()
                    Toggle("Image pull finished", isOn: $notifyPullFinished)
                        .font(.system(size: 13))
                }

                SectionCard(title: "DNS") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Create a local DNS domain so containers are reachable by name (e.g. web.\(dnsDomain.isEmpty ? "test" : dnsDomain)). Uses .test by default — .local belongs to Bonjour and can break printer.local-style names on your network.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.text2)
                            .fixedSize(horizontal: false, vertical: true)

                        if !dnsDomains.isEmpty {
                            HStack(spacing: 6) {
                                Text("Configured:").font(.system(size: 12)).foregroundStyle(Theme.text2)
                                ForEach(dnsDomains, id: \.self) { domain in
                                    Text(".\(domain)")
                                        .font(.system(size: 11.5, design: .monospaced))
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 5))
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            Text(".").font(.system(size: 13, design: .monospaced))
                            TextField("test", text: $dnsDomain)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                                .frame(width: 120)
                            Button("Create") { Task { await changeDNS(create: true) } }
                                .buttonStyle(BrandButtonStyle(kind: .secondary, compact: true))
                                .disabled(!ContainerService.isValidDNSDomain(dnsDomain))
                            Button("Remove") { Task { await changeDNS(create: false) } }
                                .buttonStyle(BrandButtonStyle(kind: .destructive, compact: true))
                                .disabled(!ContainerService.isValidDNSDomain(dnsDomain))
                            Spacer()
                        }
                        if !dnsDomain.isEmpty && !ContainerService.isValidDNSDomain(dnsDomain) {
                            Text("Use lowercase letters, digits and hyphens.")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.warn)
                        }
                    }
                }

                SectionCard(title: "Registries") {
                    if registryLogins.isEmpty {
                        Text("No registry logins")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(registryLogins.enumerated()), id: \.element.id) { index, login in
                            if index > 0 { Divider() }
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(login.hostname)
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    Text(login.username)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button {
                                    Task { await logout(login.hostname) }
                                } label: {
                                    if loggingOutHostname == login.hostname {
                                        ProgressView().scaleEffect(0.6)
                                    } else {
                                        Text("Log Out")
                                    }
                                }
                                .buttonStyle(BrandButtonStyle(kind: .secondary, compact: true))
                                .disabled(loggingOutHostname != nil)
                            }
                        }
                    }

                    if let registryError {
                        ErrorBanner(message: registryError) { self.registryError = nil }
                    }

                    Divider()

                    Button {
                        showAddRegistrySheet = true
                    } label: {
                        Label("Add registry login…", systemImage: "plus.circle")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.borderless)
                }

                SectionCard(title: "About") {
                    KeyValueRow(key: String(localized: "App"),     value: "ContainerUI")
                    KeyValueRow(key: String(localized: "Backend"), value: "Apple Container \(service.versionRows.first?.version ?? "")")
                    KeyValueRow(key: String(localized: "Source"),  value: "github.com/apple/container")
                }
            }
            .padding(16)
        }
        .navigationTitle("Settings")
        .task {
            if service.versionRows.isEmpty {
                await service.fetchSystemInfo()
            }
            await loadRegistryLogins()
            dnsDomains = await service.fetchDNSDomains()
        }
        .sheet(isPresented: $showAddRegistrySheet) {
            RegistryLoginSheet {
                Task { await loadRegistryLogins() }
            }
            .environment(service)
        }
    }

    private func chooseBinary() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/usr/local/bin")
        panel.message = String(localized: "Select the container executable")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        customBinaryPath = url.path
        service.reloadBinaryPath()
        Task { await service.fetchContainers() }
    }

    private func changeDNS(create: Bool) async {
        await service.setDNSDomain(dnsDomain, create: create)
        dnsDomains = await service.fetchDNSDomains()
    }

    private func loadRegistryLogins() async {
        registryLogins = await service.fetchRegistryLogins()
    }

    private func logout(_ hostname: String) async {
        loggingOutHostname = hostname
        registryError = nil
        do {
            try await service.registryLogout(server: hostname)
            await loadRegistryLogins()
        } catch {
            registryError = error.localizedDescription
        }
        loggingOutHostname = nil
    }
}
