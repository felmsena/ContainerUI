import Foundation

extension ContainerService {

    func fetchRegistryLogins() async -> [RegistryLogin] {
        let output = (try? await cli(CLI.registryList())) ?? ""
        return Self.parseRegistryList(output)
    }

    /// Logs in via `--password-stdin` so the password is piped to the
    /// process instead of appearing as a `login` argument.
    func registryLogin(server: String, username: String, password: String) async throws {
        try await cli(CLI.registryLogin(server: server, username: username), stdin: password)
    }

    func registryLogout(server: String) async throws {
        try await cli(CLI.registryLogout(server))
    }

    // MARK: – Parsing
    //
    // Column positions in the real `container registry list` header
    // (verified by character count): HOSTNAME=0  USERNAME=10  MODIFIED=20

    nonisolated static func parseRegistryList(_ output: String) -> [RegistryLogin] {
        tableRows(output, columns: ["HOSTNAME", "USERNAME", "MODIFIED"]).map { f in
            RegistryLogin(hostname: f[0], username: f[1])
        }
    }
}
