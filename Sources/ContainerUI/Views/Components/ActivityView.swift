import SwiftUI

/// One-line status + progress bar for a running job.
struct JobProgressView: View {
    let job: BackgroundJob

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let progress = job.progress {
                ProgressView(value: progress)
                    .tint(Theme.accent)
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(Theme.accent)
            }
            Text(job.detail.isEmpty ? String(localized: "Starting…") : job.detail)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.text2)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

/// Toolbar item listing builds, pulls and group runs, with progress and a
/// cancel button — the place to follow work started from anywhere.
struct ActivityToolbarButton: View {
    @Environment(ContainerService.self) private var service
    @Environment(AppState.self) private var app
    @State private var isShowing = false

    var body: some View {
        let running = service.runningJobs.count
        Button {
            isShowing.toggle()
        } label: {
            HStack(spacing: 4) {
                if running > 0 {
                    ProgressView().controlSize(.small)
                    Text("\(running)").font(.system(size: 11, weight: .semibold, design: .monospaced))
                } else {
                    Image(systemName: "list.bullet.rectangle")
                }
            }
        }
        .help("Activity")
        .accessibilityLabel(running > 0 ? "Activity, \(running) running" : "Activity")
        .popover(isPresented: $isShowing, arrowEdge: .bottom) {
            ActivityPopover()
                .environment(service)
                .environment(app)
        }
    }
}

private struct ActivityPopover: View {
    @Environment(ContainerService.self) private var service
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Activity").font(.system(size: 13, weight: .semibold))
                Spacer()
                if service.jobs.contains(where: { !$0.isRunning }) {
                    Button("Clear finished") { service.clearFinishedJobs() }
                        .buttonStyle(BrandButtonStyle(kind: .secondary, compact: true))
                }
            }
            .padding(12)

            Divider()

            if service.jobs.isEmpty {
                Text("No builds, pulls or group runs yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.text2)
                    .frame(maxWidth: .infinity)
                    .padding(24)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(service.jobs) { job in
                            JobRow(job: job)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 360)
            }
        }
        .frame(width: 380)
        .background(Theme.bg)
    }
}

private struct JobRow: View {
    let job: BackgroundJob
    @Environment(AppState.self) private var app

    private var icon: String {
        switch job.kind {
        case .build: return "hammer"
        case .pull: return "arrow.down.circle"
        case .compose: return "rectangle.3.group"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(Theme.text2)
                    .frame(width: 16)
                Text(job.title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                statusBadge
            }
            if job.isRunning {
                JobProgressView(job: job)
                HStack {
                    if job.kind == .build {
                        Button("Show log") { app.sidebarItem = .build }
                            .buttonStyle(BrandButtonStyle(kind: .secondary, compact: true))
                    }
                    Spacer()
                    Button("Cancel", role: .destructive) { job.cancel() }
                        .buttonStyle(BrandButtonStyle(kind: .destructive, compact: true))
                }
            } else if case .failed(let message) = job.status {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.danger)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch job.status {
        case .running:
            EmptyView()
        case .succeeded:
            Label("Done", systemImage: "checkmark.circle.fill").labelStyle(.iconOnly).foregroundStyle(Theme.accent)
        case .cancelled:
            Text("Cancelled").font(.system(size: 11)).foregroundStyle(Theme.text3)
        case .failed:
            Label("Failed", systemImage: "xmark.octagon.fill").labelStyle(.iconOnly).foregroundStyle(Theme.danger)
        }
    }
}
