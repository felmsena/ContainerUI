import SwiftUI

struct StatsTabView: View {
    let container: ContainerInfo
    @EnvironmentObject var service: ContainerService
    @State private var stats: ContainerStats?
    @State private var isLoading = false
    @State private var refreshTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let stats = stats {
                    LazyVStack(spacing: 12) {
                        StatCard(label: "CPU Usage", value: stats.cpu, icon: "cpu")
                        StatCard(label: "Memory", value: "\(stats.memUsage) / \(stats.memLimit)", icon: "memorychip")
                        StatCard(label: "Net In", value: stats.netIn, icon: "arrow.down.circle")
                        StatCard(label: "Net Out", value: stats.netOut, icon: "arrow.up.circle")
                    }
                } else if isLoading {
                    ProgressView("Loading stats…")
                        .padding(.top, 40)
                } else if !container.state.isRunning {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 36))
                            .foregroundStyle(.quaternary)
                        Text("Container is not running")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 36))
                            .foregroundStyle(.quaternary)
                        Text("Stats unavailable")
                            .foregroundStyle(.secondary)
                        Text("Run `container stats \(container.id)` in Terminal")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }

                Divider().padding(.top, 4)

                // Static info always visible
                VStack(alignment: .leading, spacing: 4) {
                    Text("Allocated Resources")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2)
                    StatCard(label: "Memory limit", value: container.memory, icon: "memorychip")
                    StatCard(label: "CPUs", value: "\(container.cpus)", icon: "cpu")
                    StatCard(label: "Architecture", value: container.arch, icon: "cpu.fill")
                }
            }
            .padding(12)
        }
        .task {
            guard container.state.isRunning else { return }
            await startLiveStats()
        }
        .onDisappear {
            refreshTask?.cancel()
        }
    }

    func startLiveStats() async {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled && container.state.isRunning {
                await loadStats()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    func loadStats() async {
        isLoading = true
        defer { isLoading = false }

        guard let output = try? await service.shell("\(containerBin) stats --no-stream \(container.id)") else { return }
        stats = parseStats(output)
    }

    func parseStats(_ output: String) -> ContainerStats? {
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard lines.count > 1 else { return nil }

        let data = lines[1]
        let parts = data.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard parts.count >= 3 else { return nil }

        return ContainerStats(
            cpu: parts.count > 1 ? parts[1] : "—",
            memUsage: parts.count > 2 ? parts[2] : "—",
            memLimit: parts.count > 4 ? parts[4] : container.memory,
            netIn: parts.count > 5 ? parts[5] : "—",
            netOut: parts.count > 7 ? parts[7] : "—"
        )
    }
}

struct StatCard: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
        )
    }
}
