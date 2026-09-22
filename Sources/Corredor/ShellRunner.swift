import Foundation

public protocol BashArgument {
    var bashArgument: String { get }
}

public enum ShellOption: Sendable {
    case printCommand
    case printOutput
}

public struct ShellRunner: Sendable {
    // Argv invocations execute the binary directly: arguments are passed
    // verbatim, so secrets with shell-special characters survive and are
    // never echoed back by shell errors.
    private enum Invocation: Sendable {
        case shell(String)
        case argv([String], currentDirectory: URL?)
    }

    private let invocation: Invocation
    private let environment: [String: String]
    private let options: [ShellOption]

    private let shell = "/bin/zsh"
    private let env = ProcessInfo.processInfo.environment

    init(
        command: String,
        environment: [String: String] = [:],
        options: [ShellOption] = []
    ) {
        self.invocation = .shell(command)
        self.environment = environment
        self.options = options
    }

    init(
        argv: [String],
        currentDirectory: URL? = nil,
        environment: [String: String] = [:],
        options: [ShellOption] = []
    ) {
        self.invocation = .argv(argv, currentDirectory: currentDirectory)
        self.environment = environment
        self.options = options
    }

    private var command: String {
        switch invocation {
        case .shell(let command): command
        case .argv(let argv, _): argv.joined(separator: " ")
        }
    }

    private func configure(_ process: Process) {
        process.environment = env.merging(environment, uniquingKeysWith: { _, new in new })

        switch invocation {
        case .shell(let command):
            process.executableURL = URL(fileURLWithPath: shell)
            process.arguments = ["--login", "-c", command]
        case .argv(let argv, let currentDirectory):
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = argv
            if let currentDirectory {
                process.currentDirectoryURL = currentDirectory
            }
        }
    }

    /// Executes a shell command
    /// - Parameters:
    ///   - command: Shell command to run
    ///   - environment: Environment variables (default: empty dictionary)
    ///   - options: Options to work with command output (default: empty array)
    /// - Returns: Output string
    /// - Throws: An error if the command execution fails
    @discardableResult
    public func run() throws(Error) -> String {
        try run(onLine: nil)
    }

    /// Executes a shell command, streaming each complete non-empty output
    /// line (stdout and stderr) to the callback as it arrives, in addition to
    /// the regular capture behavior. The callback is invoked on the calling
    /// thread.
    @discardableResult
    public func run(onLine: @escaping @Sendable (String) -> Void) throws(Error) -> String {
        try run(onLine: Optional(onLine))
    }

    private func run(onLine: (@Sendable (String) -> Void)?) throws(Error) -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        if options.contains(.printCommand) {
            print("Underlying command:")
            print(command)
        }

        configure(process)

        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw .runFailed(error)
        }

        let shouldPrint = options.contains(.printOutput)
        let standardOutput = OutputCapture(shouldPrint: shouldPrint, onLine: onLine)
        let standardError = OutputCapture(shouldPrint: shouldPrint, onLine: onLine)
        let readFailure = OutputCapture.drain([
            (outputPipe.fileHandleForReading.fileDescriptor, standardOutput),
            (errorPipe.fileHandleForReading.fileDescriptor, standardError),
        ])
        try? outputPipe.fileHandleForReading.close()
        try? errorPipe.fileHandleForReading.close()

        if readFailure != nil {
            process.terminate()
        }
        process.waitUntilExit()

        if let readFailure {
            throw .runFailed(NSError(domain: NSPOSIXErrorDomain, code: Int(readFailure)))
        }

        if process.terminationStatus == 0 {
            return standardOutput.text.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            let command = options.contains(.printCommand) ? command : "<redacted>"
            var totalOutput = standardError.text.trimmingCharacters(in: .whitespacesAndNewlines)

            if shouldPrint {
                totalOutput += "\n" + standardOutput.text.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            throw Error.commandFailed(
                command: command,
                exitCode: process.terminationStatus,
                output: totalOutput
            )
        }
    }

    /// Runs shell command in background, returns PID immediately
    /// - Parameters:
    ///   - command: Shell command to execute
    ///   - environment: Environment variables (default: empty)
    ///   - options: Command execution options (default: empty)
    /// - Returns: Process ID string
    /// - Throws: If command fails to start
    @discardableResult
    public func runBackgroundTask() throws(Error) -> String {
        let process = Process()

        if options.contains(.printCommand) {
            print("Underlying background command:")
            print(command)
        }

        configure(process)

        // For background tasks, we typically don't need to capture output
        // but we can redirect to /dev/null to prevent blocking
        if !options.contains(.printOutput) {
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
        }

        do {
            try process.run()
        } catch {
            throw .runFailed(error)
        }

        if options.contains(.printOutput) {
            print("Background task started with PID: \(process.processIdentifier)")
        }

        // Return the process ID as a string for tracking
        return String(process.processIdentifier)
    }

    private func getTrimmedStringOrNil(from data: Data) -> String? {
        let string = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if string?.isEmpty == true {
            return nil
        }

        return string
    }

    public enum Error: LocalizedError {
        case commandFailed(command: String, exitCode: Int32, output: String)
        case runFailed(Swift.Error)

        public var errorDescription: String? {
            switch self {
            case let .commandFailed(command, exitCode, output):
                """
                Command: \(command)
                ExitCode: \(exitCode)
                Error Output:
                \(output)
                """

            case let .runFailed(nestedError):
                "Command execution failed with error: \(nestedError.localizedDescription)"
            }
        }
    }
}
