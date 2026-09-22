import Foundation
import os
import Testing
import Corredor

@Suite
struct ShellRunnerConcurrencyTests {

    @Test
    func concurrentRunsOnCooperativePoolComplete() {
        let callCount = ProcessInfo.processInfo.activeProcessorCount * 2
        let outputs = OSAllocatedUnfairLock(initialState: [String]())
        let failures = OSAllocatedUnfairLock(initialState: [String]())
        let finished = DispatchSemaphore(value: 0)

        for index in 0..<callCount {
            Task.detached {
                defer { finished.signal() }
                do {
                    let output = try Shell.arguments(["echo", "\(index)"]).run()
                    outputs.withLock { $0.append(output) }
                } catch {
                    failures.withLock { $0.append("\(error)") }
                }
            }
        }

        let deadline = DispatchTime.now() + .seconds(30)
        for completed in 0..<callCount {
            guard finished.wait(timeout: deadline) == .success else {
                // Every pool thread is wedged here, so exiting is the only way to fail instead of hanging until the CI timeout.
                Issue.record("\(callCount - completed) of \(callCount) concurrent run() calls hung for 30s: ShellRunner deadlocks on the cooperative pool")
                exit(EXIT_FAILURE)
            }
        }

        #expect(outputs.withLock { $0.sorted() } == (0..<callCount).map(String.init).sorted())
        #expect(failures.withLock { $0 }.isEmpty)
    }
}
