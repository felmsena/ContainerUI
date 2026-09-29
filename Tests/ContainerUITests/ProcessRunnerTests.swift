import XCTest
@testable import ContainerUI

final class ProcessRunnerTests: XCTestCase {

    private func sh(_ script: String) -> [String] { ["/bin/sh", "-c", script] }

    // Regression: output larger than the pipe buffer (~64 KB) used to
    // deadlock because the process was awaited before its pipes were read.
    func testLargeStdoutAndStderr_doNotDeadlock() async throws {
        let script = "head -c 300000 /dev/zero | tr '\\0' a; head -c 300000 /dev/zero | tr '\\0' b 1>&2"
        let output = try await ProcessRunner.run(sh(script), timeout: 20).get()
        XCTAssertEqual(output.stdout.count, 300_000)
        XCTAssertEqual(output.stderr.count, 300_000)
        XCTAssertEqual(output.exitCode, 0)
    }

    func testNonZeroExit_isReportedNotThrown() async throws {
        let output = try await ProcessRunner.run(sh("echo oops 1>&2; exit 3")).get()
        XCTAssertEqual(output.exitCode, 3)
        XCTAssertEqual(output.stderr, "oops\n")
    }

    func testStdin_isPipedToProcess() async throws {
        let output = try await ProcessRunner.run(["/bin/cat"], stdin: "secret").get()
        XCTAssertEqual(output.stdout, "secret")
    }

    func testTimeout_terminatesProcess() async {
        let start = Date()
        let result = await ProcessRunner.run(["/bin/sleep", "10"], timeout: 0.5)
        XCTAssertEqual(result, .failure(.timedOut))
        XCTAssertLessThan(Date().timeIntervalSince(start), 5)
    }

    func testTaskCancellation_terminatesProcess() async {
        let start = Date()
        let task = Task { await ProcessRunner.run(["/bin/sleep", "10"], timeout: nil) }
        try? await Task.sleep(nanoseconds: 300_000_000)
        task.cancel()
        let result = await task.value
        XCTAssertEqual(result, .failure(.cancelled))
        XCTAssertLessThan(Date().timeIntervalSince(start), 5)
    }

    func testMissingExecutable_isLaunchFailure() async {
        let result = await ProcessRunner.run(["/nonexistent/binary"])
        guard case .failure(.launchFailed) = result else { return XCTFail("expected launchFailed, got \(result)") }
    }

    func testStream_yieldsLinesInOrder_andFinishes() async throws {
        let stream = ProcessRunner.stream(sh("printf 'one\\ntwo\\nthree'"))
        var lines: [String] = []
        for try await line in stream.lines { lines.append(line) }
        XCTAssertEqual(lines, ["one", "two", "three"])
    }

    func testStream_nonZeroExit_throwsWithStderr() async {
        let stream = ProcessRunner.stream(sh("echo boom 1>&2; exit 2"))
        do {
            for try await _ in stream.lines {}
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? CLIError, .failed("boom", code: 2))
        }
    }

    func testStream_cancel_terminatesProcess() async {
        let stream = ProcessRunner.stream(["/bin/sleep", "10"])
        let start = Date()
        Task { try? await Task.sleep(nanoseconds: 300_000_000); stream.cancel() }
        do {
            for try await _ in stream.lines {}
        } catch {
            XCTAssertEqual(error as? CLIError, .cancelled)
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 5)
    }

    // MARK: - LineSplitter

    func testLineSplitter_keepsSplitMultibyteCharacterIntact() {
        var splitter = LineSplitter()
        let bytes = Array("ñandú\n".utf8)
        // Split inside the two-byte "ñ" sequence.
        XCTAssertEqual(splitter.feed(Data(bytes[0..<1])), [])
        XCTAssertEqual(splitter.feed(Data(bytes[1...])), ["ñandú"])
        XCTAssertNil(splitter.flush())
    }

    func testLineSplitter_stripsCarriageReturn_andFlushesRemainder() {
        var splitter = LineSplitter()
        XCTAssertEqual(splitter.feed(Data("a\r\nb".utf8)), ["a"])
        XCTAssertEqual(splitter.flush(), "b")
    }

    // MARK: - CLIError.classify

    func testClassify_xpcError_isDaemonNotRunning() {
        let err = CLIError.classify(stderr: "Error: interrupted: \"XPC connection error: Connection invalid\"\n", code: 1)
        guard case .daemonNotRunning = err else { return XCTFail("got \(err)") }
    }

    func testClassify_pluginsUnavailable_isDaemonNotRunning() {
        let err = CLIError.classify(stderr: "Error: Plugins are unavailable. Start the container system services and retry:", code: 1)
        guard case .daemonNotRunning = err else { return XCTFail("got \(err)") }
    }

    func testClassify_otherError_isFailedWithTrimmedMessage() {
        XCTAssertEqual(CLIError.classify(stderr: "  Error: not found \n", code: 1), .failed("Error: not found", code: 1))
    }
}
