import SwiftUI

struct SettingsView: View {
    @AppStorage("refreshInterval") private var refreshInterval = 5
    @AppStorage("defaultBrowserPort") private var defaultPort = "9000"
    @EnvironmentObject var service: ContainerService

    @State private var registryLogins: [RegistryLogin] = []
    @State private var showAddRegistrySheet = false
    @State private var registryError: String?
    @State private var loggingOutHostname: String?

    private let intervals = [3, 5, 10, 30, 60]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                SectionCard(title: "Binary") {
                    KeyValueRow(key: String(localized: "Path"), value: containerBin)

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

                SectionCard(title: "DNS") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Set up a local DNS domain so containers are accessible by name (e.g. sonarqube.local).")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            Button("Create .local domain") {
                                Task {
                                    _ = try? await service.shell([
                                        "/usr/bin/osascript", "-e",
                                        "do shell script \"\(containerBin) system dns create local\" with administrator privileges"
                                    ])
                                }
                            }
                            .buttonStyle(.bordered)

                            Button("Remove .local domain") {
                                Task {
                                    _ = try? await service.shell([
                                        "/usr/bin/osascript", "-e",
                                        "do shell script \"\(containerBin) system dns delete local\" with administrator privileges"
                                    ])
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
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
                                .buttonStyle(.bordered)
                                .controlSize(.small)
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
        }
        .sheet(isPresented: $showAddRegistrySheet) {
            RegistryLoginSheet {
                Task { await loadRegistryLogins() }
            }
            .environmentObject(service)
        }
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
