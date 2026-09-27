import SwiftUI

/// Status and resources of the BuildKit container behind `container build`.
/// Large builds often fail for lack of builder memory; this is where to
/// give it more (or reclaim it).
struct BuilderCard: View {
    @Environment(ContainerService.self) private var service
    @AppStorage("builderCPUs") private var cpus = 2
    @AppStorage("builderMemory") private var memory = "2G"

    private let memoryOptions = ["1G", "2G", "4G", "8G", "16G"]
    private let cpuOptions = [1, 2, 4, 6, 8]

    private var builder: ContainerInfo? { service.builderContainer }
    private var isRunning: Bool { builder?.state.isRunning == true }

    var body: some View {
        SectionCard(title: "Builder") {
            HStack(spacing: 10) {
                Circle()
                    .fill(isRunning ? Theme.accent : Theme.text3)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(builder == nil ? "Not created" : (isRunning ? "Running" : "Stopped"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.text)
                    if let builder {
                        Text("\(builder.cpus) CPUs · \(builder.memory)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.text2)
                    } else {
                        Text("Created automatically by the first build.")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.text2)
                    }
                }
                Spacer()
                if service.builderBusy {
                    ProgressView().controlSize(.small)
                }
            }

            Divider()

            HStack(spacing: 10) {
                Text("CPUs").font(.system(size: 12)).foregroundStyle(Theme.text2)
                Picker("", selection: $cpus) {
                    ForEach(cpuOptions, id: \.self) { Text("\($0)").tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                Text("Memory").font(.system(size: 12)).foregroundStyle(Theme.text2)
                Picker("", selection: $memory) {
                    ForEach(memoryOptions, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                Spacer()
                Button(isRunning ? "Apply & restart" : "Start") {
                    Task { await service.startBuilder(cpus: cpus, memory: memory) }
                }
                .buttonStyle(BrandButtonStyle(kind: .primary, compact: true))
                if isRunning {
                    Button("Stop") { Task { await service.stopBuilder() } }
                        .buttonStyle(BrandButtonStyle(kind: .secondary, compact: true))
                }
                if builder != nil {
                    Button("Delete") { Task { await service.deleteBuilder() } }
                        .buttonStyle(BrandButtonStyle(kind: .destructive, compact: true))
                        .help("Delete the builder container (its build cache goes with it)")
                }
            }
            .disabled(service.builderBusy)
        }
    }
}
