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
                                .fill(status.isRunning ? Color.green : Color.secondary)
                                .frame(width: 10, height: 10)
                            Text(status.isRunning ? "Running" : "Stopped")
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            if status.isRunning {
                                Button("Stop service") {
                                    Task { await service.stopService() }
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            } else {
                                Button("Start service") {
                                    Task { await service.startService() }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                            }
                        }

                        Divider()

                        KeyValueRow(key: "App root",     value: status.appRoot)
                        KeyValueRow(key: "Install root", value: status.installRoot)
                        KeyValueRow(key: "API version",  value: status.apiserverVersion)
                    }
                } else {
                    SectionCard(title: "Service") {
                        HStack {
                            Circle()
                                .fill(Color.secondary)
                                .frame(width: 10, height: 10)
                            Text("Unknown — service may not be running")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
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
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 6)

                            Divider()

                            ForEach(service.systemDf) { row in
                                HStack {
                                    HStack(spacing: 6) {
                                        Image(systemName: dfIcon(for: row.type))
                                            .foregroundStyle(.secondary)
                                            .font(.system(size: 12))
                                        Text(row.type)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(row.total).frame(width: 50, alignment: .trailing)
                                    Text(row.active).frame(width: 50, alignment: .trailing)
                                    Text(row.size)
                                        .font(.system(size: 12, design: .monospaced))
                                        .frame(width: 80, alignment: .trailing)
                                    Text(row.reclaimable)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(.secondary)
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

