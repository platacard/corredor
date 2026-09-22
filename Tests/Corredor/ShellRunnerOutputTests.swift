import Foundation
import os
import Testing
@testable import Corredor

@Suite
struct ShellRunnerOutputTests {
    private let line = String(repeating: "x", count: 63)
    private let lineCount = 16_384 // 1 MiB per stream, far beyond the 64 KiB pipe buffer

    @Test
    func drainsStdoutAndStderrLargerThanPipeBuffer() {
        let script = "yes \(line) | head -n \(lineCount) | tee /dev/stderr; exit 3"
        do {
            try Shell.arguments(["sh", "-c", script]).run()
            Issue.record("expected exit code 3")
        } catch ShellRunner.Error.commandFailed(_, let exitCode, let output) {
            #expect(exitCode == 3)
            #expect(output.split(separator: "\n").count == lineCount)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test
    func streamsCompleteLinesAcrossChunkBoundaries() throws {
        let streamed = OSAllocatedUnfairLock(initialState: [String]())
        let output = try Shell.arguments(["sh", "-c", "yes \(line) | head -n \(lineCount)"]).run { line in
            streamed.withLock { $0.append(line) }
        }
        #expect(output.split(separator: "\n").count == lineCount)
        let lines = streamed.withLock { $0 }
        #expect(lines.count == lineCount)
        #expect(lines.allSatisfy { $0 == line })
    }

    @Test
    func drainReportsReadFailures() {
        let directory = open("/", O_RDONLY)
        defer { close(directory) }
        let capture = OutputCapture(shouldPrint: false, onLine: nil)
        #expect(OutputCapture.drain([(directory, capture)]) == EISDIR)
        #expect(capture.text.isEmpty)
    }

    @Test
    func onLineReceivesBothStreamsInOrder() throws {
        let streamed = OSAllocatedUnfairLock(initialState: [String]())
        try Shell.arguments(["sh", "-c", "for i in 1 2 3; do echo out$i; echo err$i >&2; done"]).run { line in
            streamed.withLock { $0.append(line) }
        }
        let lines = streamed.withLock { $0 }
        #expect(lines.filter { $0.hasPrefix("out") } == ["out1", "out2", "out3"])
        #expect(lines.filter { $0.hasPrefix("err") } == ["err1", "err2", "err3"])
    }
}
