import SwiftUI

struct RegistryLoginSheet: View {
    @EnvironmentObject var service: ContainerService
    @Environment(\.dismiss) private var dismiss

    @State private var server = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isLoggingIn = false
    @State private var error: String?

    let onSuccess: () -> Void

    private var canSubmit: Bool {
        !server.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Registry Login")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Server").font(.caption).foregroundStyle(.secondary)
                TextField("ghcr.io", text: $server)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                    .disabled(isLoggingIn)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Username").font(.caption).foregroundStyle(.secondary)
                TextField("your-username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isLoggingIn)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Password / Token").font(.caption).foregroundStyle(.secondary)
                SecureField("personal access token", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isLoggingIn)
                    .onSubmit { Task { await login() } }
            }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(3)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                    .disabled(isLoggingIn)
                Button {
                    Task { await login() }
                } label: {
                    HStack(spacing: 6) {
                        if isLoggingIn { ProgressView().scaleEffect(0.7).frame(width: 14, height: 14) }
                        Text(isLoggingIn ? "Logging in…" : "Log In")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit || isLoggingIn)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func login() async {
        guard canSubmit else { return }
        isLoggingIn = true
        error = nil
        do {
            try await service.registryLogin(
                server: server.trimmingCharacters(in: .whitespaces),
                username: username.trimmingCharacters(in: .whitespaces),
                password: password
            )
            onSuccess()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isLoggingIn = false
    }
}
