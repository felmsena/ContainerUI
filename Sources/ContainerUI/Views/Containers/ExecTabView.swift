import SwiftUI

struct ExecTabView: View {
    let container: ContainerInfo
    @Environment(ContainerService.self) private var service

    @State private var commandText = ""
    @State private var entries: [ExecEntry] = []
    @State private var commandHistory: [String] = []
    @State private var historyCursor = 0
    @State private var isRunning = false

    private struct ExecEntry: Identifiable {
        let id = UUID()
        let command: String
        let output: String
        let exitCode: Int32
    }

    var body: some View {
        VStack(spacing: 0) {
            if container.state.isRunning {
                HStack(spacing: 8) {
                    Text("$")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.accent)
                    TextField("ls -la /", text: $commandText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .disabled(isRunning)
                        .onSubmit { runCommand() }
                        .onKeyPress(.upArrow) { recallPrevious(); return .handled }
                        .onKeyPress(.downArrow) { recallNext(); return .handled }

                    if isRunning {
                        ProgressView().scaleEffect(0.6)
                    }

                    Button("Run", action: runCommand)
                        .buttonStyle(BrandButtonStyle(kind: .secondary, compact: true))
                        .disabled(isRunning || commandText.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button {
                        service.openShell(for: container.id)
                    } label: {
                        Label("Open in Terminal", systemImage: "terminal")
                    }
                    .buttonStyle(BrandButtonStyle(kind: .secondary, compact: true))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            if entries.isEmpty {
                                Text("Run a command to see its output here.")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(Theme.text3)
                            }
                            ForEach(entries) { entry in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(alignment: .top, spacing: 6) {
                                        Text("$")
                                            .foregroundStyle(Theme.accent)
                                            .fontWeight(.bold)
                                        Text(entry.command)
                                            .fontWeight(.medium)
                                            .foregroundStyle(Theme.text)
                                    }
                                    .font(.system(size: 12, design: .monospaced))

                                    if !entry.output.isEmpty {
                                        let color: Color = entry.exitCode == 0 ? Theme.text2 : Theme.danger
                                        Text(entry.output)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundStyle(color)
                                            .textSelection(.enabled)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(entry.id)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Theme.surface)
                    .onChange(of: entries.count) { _, _ in
                        if let last = entries.last?.id {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "terminal")
                        .font(.system(size: 36))
                        .foregroundStyle(.quaternary)
                    Text("Container is not running")
                        .foregroundStyle(Theme.text2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func runCommand() {
        let trimmed = commandText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isRunning else { return }
        let args = ContainerService.tokenizeCommand(trimmed)
        guard !args.isEmpty else { return }

        commandHistory.append(trimmed)
        historyCursor = commandHistory.count
        commandText = ""
        isRunning = true

        Task {
            let result = await service.exec(container.id, args: args)
            let output = [result.stdout, result.stderr]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
                .trimmingCharacters(in: .newlines)
            entries.append(ExecEntry(command: trimmed, output: output, exitCode: result.exitCode))
            isRunning = false
        }
    }

    private func recallPrevious() {
        guard !commandHistory.isEmpty else { return }
        historyCursor = max(0, historyCursor - 1)
        commandText = commandHistory[historyCursor]
    }

    private func recallNext() {
        guard !commandHistory.isEmpty else { return }
        if historyCursor < commandHistory.count - 1 {
            historyCursor += 1
            commandText = commandHistory[historyCursor]
        } else {
            historyCursor = commandHistory.count
            commandText = ""
        }
    }
}
