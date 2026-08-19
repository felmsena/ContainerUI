import SwiftUI

struct SystemStatsView: View {
    @EnvironmentObject var service: ContainerService
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Status card
                if let status = service.systemStatus {
                    SectionCard(title: "Service") {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(status.isRunning ? Theme.accent : Theme.text3)
                                .frame(width: 10, height: 10)
                            Text(status.isRunning ? "Running" : "Stopped")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.text)
                            Spacer()
                            if status.isRunning {
                                Button("Stop service") {
                                    Task { await service.stopService() }
                                }
                                .buttonStyle(.bordered)
                                .tint(Theme.danger)
                            } else {
                                Button("Start service") {
                                    Task { await service.startService() }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Theme.accent)
                            }
                        }

                        Divider()

                        KeyValueRow(key: String(localized: "App root"),     value: status.appRoot)
                        KeyValueRow(key: String(localized: "Install root"), value: status.installRoot)
                        KeyValueRow(key: String(localized: "API version"),  value: status.apiserverVersion)
                    }
                } else {
                    SectionCard(title: "Service") {
                        HStack {
                            Circle()
                                .fill(Theme.text3)
                                .frame(width: 10, height: 10)
                            Text("Unknown — service may not be running")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.text2)
                            Spacer()
                            Button("Start service") {
                                Task { await service.startService() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }
                    }
                }

                // Disk usage
                if !service.systemDf.isEmpty {
                    SectionCard(title: "Disk usage") {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Type").frame(maxWidth: .infinity, alignment: .leading)
                                Text("Total").frame(width: 50, alignment: .trailing)
                                Text("Active").frame(width: 50, alignment: .trailing)
                                Text("Size").frame(width: 80, alignment: .trailing)
                                Text("Reclaimable").frame(width: 110, alignment: .trailing)
                            }
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.text3)
                            .padding(.bottom, 6)

                            Divider()

                            ForEach(service.systemDf) { row in
                                HStack {
                                    HStack(spacing: 6) {
                                        Image(systemName: dfIcon(for: row.type))
                                            .foregroundStyle(Theme.text2)
                                            .font(.system(size: 12))
                                        Text(row.type)
                                            .foregroundStyle(Theme.text)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(row.total).foregroundStyle(Theme.text).frame(width: 50, alignment: .trailing)
                                    Text(row.active).foregroundStyle(Theme.text).frame(width: 50, alignment: .trailing)
                                    Text(row.size)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(Theme.text)
                                        .frame(width: 80, alignment: .trailing)
                                    Text(row.reclaimable)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(Theme.text2)
                                        .frame(width: 110, alignment: .trailing)
                                }
                                .font(.system(size: 13))
                                .padding(.vertical, 6)
                                Divider()
                            }
                        }
                    }
                }

                // Version
                if !service.versionRows.isEmpty {
                    SectionCard(title: "Version") {
                        ForEach(service.versionRows) { row in
                            KeyValueRow(key: row.component, value: "\(row.version) (\(row.build))")
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("System")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Group {
                    if isLoading {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Button {
                            Task { await load() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .help("Refresh system info")
                        .accessibilityLabel("Refresh system info")
                    }
                }
            }
        }
        .task { await load() }
    }

    func load() async {
        isLoading = true
        await service.fetchSystemInfo()
        isLoading = false
    }

    func dfIcon(for type: String) -> String {
        switch type.lowercased() {
        case let t where t.contains("image"):    return "photo.stack"
        case let t where t.contains("container"): return "square.stack.3d.up"
        case let t where t.contains("volume"):  return "externaldrive"
        default: return "cube"
        }
    }
}

