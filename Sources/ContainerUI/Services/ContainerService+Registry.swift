import Foundation

extension ContainerService {

    func fetchRegistryLogins() async -> [RegistryLogin] {
        let output = (try? await shell([bin, "registry", "list"])) ?? ""
        return Self.parseRegistryList(output)
    }

    /// Logs in via `--password-stdin` so the password is piped to the
    /// process instead of appearing as a `login` argument.
    func registryLogin(server: String, username: String, password: String) async throws {
        try await shellWithStdin(
            [bin, "registry", "login", "--username", username, "--password-stdin", server],
            stdin: password
        )
    }

    func registryLogout(server: String) async throws {
        try await shell([bin, "registry", "logout", server])
    }

    // MARK: – Parsing
    //
    // Column positions in the real `container registry list` header
    // (verified by character count): HOSTNAME=0  USERNAME=10  MODIFIED=20

    nonisolated static func parseRegistryList(_ output: String) -> [RegistryLogin] {
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard lines.count > 1 else { return [] }

        let header = lines[0]
        guard
            let hostOff = columnOffset("HOSTNAME", in: header),
            let userOff = columnOffset("USERNAME", in: header),
            let modOff  = columnOffset("MODIFIED", in: header)
        else { return [] }

        return lines.dropFirst().compactMap { line in
            let chars = Array(line)
            guard chars.count > hostOff else { return nil }
            let hostname = field(chars, from: hostOff, to: userOff)
            let username = field(chars, from: userOff, to: modOff)
            guard !hostname.isEmpty else { return nil }
            return RegistryLogin(hostname: hostname, username: username)
        }
    }
}
