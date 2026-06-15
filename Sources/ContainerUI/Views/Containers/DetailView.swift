import SwiftUI

enum DetailTab: String, CaseIterable {
    case info  = "Info"
    case logs  = "Logs"
    case stats = "Stats"
}

struct DetailView: View {
    let container: ContainerInfo
    @State private var tab: DetailTab = .info

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(DetailTab.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
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
            }
        }
        .navigationTitle(container.id)
    }
}
