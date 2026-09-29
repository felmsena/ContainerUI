import XCTest
@testable import ContainerUI

final class ContainerBinaryTests: XCTestCase {

    func testResolve_prefersHomebrewPath() {
        let path = ContainerBinary.resolve(override: nil, isExecutable: { _ in true })
        XCTAssertEqual(path, "/opt/homebrew/bin/container")
    }

    func testResolve_fallsBackToPkgInstallerLocation() {
        let path = ContainerBinary.resolve(override: nil, isExecutable: { $0 == "/usr/local/bin/container" })
        XCTAssertEqual(path, "/usr/local/bin/container")
    }

    func testResolve_overrideTakesPrecedence() {
        let path = ContainerBinary.resolve(override: " /custom/container ", isExecutable: { _ in true })
        XCTAssertEqual(path, "/custom/container")
    }

    func testResolve_missingOverrideFallsBackToCandidates() {
        let path = ContainerBinary.resolve(override: "/missing", isExecutable: { $0 != "/missing" })
        XCTAssertEqual(path, "/opt/homebrew/bin/container")
    }

    func testResolve_nothingInstalled_returnsNil() {
        XCTAssertNil(ContainerBinary.resolve(override: nil, isExecutable: { _ in false }))
    }
}
