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

            let expectedErrorDescription = "Command: <redacted>\nExitCode: 1\nError Output:\n"

            switch runnerError {
            case let .commandFailed(command, exitCode, output):
                XCTAssertTrue(!command.isEmpty || exitCode != 0 || !output.isEmpty)
                XCTAssertEqual(runnerError.errorDescription, expectedErrorDescription)
            default:
                XCTFail("Unexpected error type: \(runnerError)")
            }
        }
    }

    func testCommandFailedErrorPrintsOutputNotCommand() {
        XCTAssertThrowsError(try Shell.command("which unexisted", options: [.printOutput]).run()) { error in
            guard let runnerError = error as? ShellRunner.Error else {
                XCTFail("Expected ShellRunner.Error, got \(error)")
                return
            }

            let expectedErrorDescription = "Command: <redacted>\nExitCode: 1\nError Output:\n\nunexisted not found"

            switch runnerError {
            case let .commandFailed(command, exitCode, output):
                XCTAssertTrue(!command.isEmpty || exitCode != 0 || !output.isEmpty)
                XCTAssertEqual(runnerError.errorDescription, expectedErrorDescription)
            default:
                XCTFail("Unexpected error type: \(runnerError)")
            }
        }
    }

    func testCommandFailedErrorPrintsCommand() {
        XCTAssertThrowsError(try Shell.command("which unexisted", options: [.printCommand, .printOutput]).run()) { error in
            guard let runnerError = error as? ShellRunner.Error else {
                XCTFail("Expected ShellRunner.Error, got \(error)")
                return
            }

            let expectedErrorDescription = "Command: which unexisted \nExitCode: 1\nError Output:\n\nunexisted not found"

            switch runnerError {
            case let .commandFailed(command, exitCode, output):
                XCTAssertTrue(!command.isEmpty || exitCode != 0 || !output.isEmpty)
                XCTAssertEqual(runnerError.errorDescription, expectedErrorDescription)
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

    func testArgumentsPassSpecialCharactersVerbatim() throws {
        let output = try Shell.arguments(["echo", "{brace,glob}*?~$HOME"]).run()
        XCTAssertEqual(output, "{brace,glob}*?~$HOME")
    }

    func testArgumentsInFolderSetsWorkingDirectory() throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).resolvingSymlinksInPath()
        let output = try Shell.arguments(["pwd"], in: folder).run()
        XCTAssertEqual(URL(fileURLWithPath: output).resolvingSymlinksInPath().path, folder.path)
    }

    func testArgumentsEnvironmentIsPassed() throws {
        let output = try Shell.arguments(
            ["printenv", "CORREDOR_TEST_VAR"],
            environment: ["CORREDOR_TEST_VAR": "va{l}ue*?"]
        ).run()
        XCTAssertEqual(output, "va{l}ue*?")
    }

    func testArgumentsFailureKeepsCommandRedacted() {
        XCTAssertThrowsError(try Shell.arguments(["false"]).run()) { error in
            XCTAssertTrue(error.localizedDescription.contains("<redacted>"))
        }
    }
}
