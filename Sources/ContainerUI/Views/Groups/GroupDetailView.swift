import SwiftUI

struct GroupDetailView: View {
    @EnvironmentObject var service: ContainerService
    let fileURL: URL

    @State private var text: String = ""
    @State private var parseResult: Result<ComposeGroup, ComposeParseError>?
    @State private var isBusy = false
    @State private var didLoad = false

    private var groupName: String { fileURL.deletingPathExtension().lastPathComponent }

    private var validationError: String? {
        guard case .failure(let error) = parseResult else { return nil }
        return error.description
    }

    private var parsedGroup: ComposeGroup? {
        guard case .success(let group) = parseResult, !group.services.isEmpty else { return nil }
        return group
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    formSection("YAML") {
                        TextEditor(text: $text)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(minHeight: 260)
                            .padding(6)
                            .background(Color(nsColor: .textBackgroundColor))
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(nsColor: .separatorColor)))
                            .onChange(of: text) { _, newValue in
                                parseResult = ComposeParser.parse(newValue)
                                try? newValue.write(to: fileURL, atomically: true, encoding: .utf8)
                            }
                    }

                    if let validationError {
                        Label(validationError, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.orange)
                            .textSelection(.enabled)
                    }

                    if let group = parsedGroup {
                        SectionCard(title: "Services") {
                            ForEach(Array(group.services.enumerated()), id: \.element.name) { index, svc in
                                if index > 0 { Divider() }
                                serviceRow(svc)
                            }
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Spacer()
                Button {
                    Task { await bringDown() }
                } label: {
                    Label("Down", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .disabled(isBusy || parsedGroup == nil)

                Button {
                    Task { await bringUp() }
                } label: {
                    HStack(spacing: 6) {
                        if isBusy {
                            ProgressView().scaleEffect(0.7).frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text("Up")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy || parsedGroup == nil)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .navigationTitle(LocalizedStringKey(groupName))
        .task {
            guard !didLoad else { return }
            didLoad = true
            text = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            parseResult = ComposeParser.parse(text)
        }
    }

    @ViewBuilder
    private func formSection<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func serviceRow(_ svc: ComposeService) -> some View {
        let state = status(for: svc)
        return HStack(spacing: 8) {
            Circle()
                .fill(color(state))
                .frame(width: 7, height: 7)
            Text(svc.name)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
            Text(svc.image)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Text(label(state))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }

    private func status(for svc: ComposeService) -> ComposeServiceState {
        let name = ContainerService.composeContainerName(group: groupName, service: svc.name)
        if let live = service.composeState[name] { return live }
        if let container = service.containers.first(where: { $0.id == name }) {
            return container.state.isRunning ? .running : .stopped
        }
        return .pending
    }

    private func color(_ state: ComposeServiceState) -> Color {
        switch state {
        case .pending, .stopped: return .secondary
        case .starting, .stopping: return .orange
        case .running: return .green
        case .failed: return .red
        }
    }

    private func label(_ state: ComposeServiceState) -> String {
        switch state {
        case .pending: return String(localized: "Pending")
        case .starting: return String(localized: "Starting…")
        case .running: return String(localized: "Running")
        case .stopping: return String(localized: "Stopping…")
        case .stopped: return String(localized: "Stopped")
        case .failed(let message): return message
        }
    }

    private func bringUp() async {
        guard let group = parsedGroup else { return }
        isBusy = true
        _ = await service.composeUp(group: groupName, services: group)
        isBusy = false
    }

    private func bringDown() async {
        guard let group = parsedGroup else { return }
        isBusy = true
        await service.composeDown(group: groupName, services: group)
        isBusy = false
    }
}
