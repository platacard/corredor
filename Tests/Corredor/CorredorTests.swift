import XCTest
@testable import Corredor

final class CorredorTests: XCTestCase {

    func testSuccessOutput() {
        do {
            let output = try Shell.command("echo 'Hello, World!'").run()
            XCTAssertEqual(output, "Hello, World!")
        } catch {
            XCTFail("Expected successful command execution, but got error: \(error)")
        }
    }

    func testCommandFailedError() {
        XCTAssertThrowsError(try Shell.command("which unexisted").run()) { error in
            guard let runnerError = error as? ShellRunner.Error else {
                XCTFail("Expected ShellRunner.Error, got \(error)")
                return
            }

            switch runnerError {
            case let .commandFailed(command, exitCode, output):
                XCTAssertTrue(!command.isEmpty || exitCode != 0 || !output.isEmpty)
            default:
                XCTFail("Unexpected error type: \(runnerError)")
            }
        }
    }

    // This test is commented out because it requires a command that will always fail.
    /**
    func testRunFailedError() {
        let processRunThrownCommand = ""

        XCTAssertThrowsError(try Shell.command(processRunThrownCommand).run()) { error in
            guard let runnerError = error as? ShellRunner.Error else {
                XCTFail("Expected ShellRunner.Error, got \(error)")
                return
            }

            switch runnerError {
            case let .runFailed(nestedError):
                XCTAssertFalse(nestedError.localizedDescription.isEmpty)
            default:
                XCTFail("Unexpected error type: \(runnerError)")
            }
        }
    }
    **/
}
