import Foundation

extension ContainerService {

    /// `container copy` requires the container to be running (it copies via
    /// the live filesystem), the mirror image of `exportContainer` below.
    func copyFromContainer(_ id: String, remotePath: String, to localPath: String) async throws {
        try await shell([bin, "copy", "\(id):\(remotePath)", localPath])
    }

    func copyToContainer(_ id: String, localPath: String, to remotePath: String) async throws {
        try await shell([bin, "copy", localPath, "\(id):\(remotePath)"])
    }

    /// `container export` requires the container to be stopped (it snapshots
    /// the filesystem layer, which isn't well-defined for a running
    /// container) — the CLI itself rejects this with "container is not
    /// stopped" otherwise.
    func exportContainer(_ id: String, to localPath: String) async throws {
        try await shell([bin, "export", "-o", localPath, id])
    }
}
