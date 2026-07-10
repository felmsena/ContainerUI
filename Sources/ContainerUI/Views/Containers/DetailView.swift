import SwiftUI

enum DetailTab: String, CaseIterable {
    case info  = "Info"
    case logs  = "Logs"
    case stats = "Stats"
    case shell = "Shell"
}

struct DetailView: View {
    let container: ContainerInfo
    @State private var tab: DetailTab = .info

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(DetailTab.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                        .disabled(t == .shell && !container.state.isRunning)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(10)

            Divider()

            switch tab {
            case .info:  InfoTabView(container: container)
            case .logs:  LogsTabView(containerId: container.id)
            case .stats: StatsTabView(container: container)
            case .shell: ExecTabView(container: container)
            }
        }
        .navigationTitle(container.id)
        .onChange(of: container.state.isRunning) { _, isRunning in
            if tab == .shell && !isRunning { tab = .info }
        }
    }
}
