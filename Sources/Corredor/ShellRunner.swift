import Foundation

public protocol BashArgument {
    var bashArgument: String { get }
}

public enum ShellOption: Sendable {
    case printCommand
    case printOutput
}

public struct ShellRunner: Sendable {
    private let command: String
    private let environment: [String: String]
    private let options: [ShellOption]

    private let shell = "/bin/zsh"
    private let env = ProcessInfo.processInfo.environment

    init(
        command: String,
        environment: [String: String] = [:],
        options: [ShellOption] = []
    ) {
        self.command = command
        self.environment = environment
        self.options = options
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
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        if options.contains(.printCommand) {
            print("Underlying command:")
            print(command)
        }

        process.environment = env.merging(environment, uniquingKeysWith: { _, new in new })
        process.executableURL = URL(fileURLWithPath: shell)

        process.arguments = ["--login", "-c", command]

        process.standardOutput = outputPipe
        process.standardError = errorPipe

        final class Output {
            var value: String = ""
        }

        var readSources: [DispatchSourceRead] = []

        func handleOutput(for pipe: Pipe, shouldPrint: Bool, output: Output, group: DispatchGroup) {
            let outputHandle = pipe.fileHandleForReading
            let outputFD = outputHandle.fileDescriptor

            let outputSource = DispatchSource.makeReadSource(fileDescriptor: outputFD, queue: DispatchQueue.global())
            group.enter()
            outputSource.setEventHandler { [weak outputSource] in
                let data = outputHandle.availableData
                guard !data.isEmpty else {
                    outputSource?.cancel()
                    return
                }
                if let str = String(data: data, encoding: .utf8) {
                    output.value += str
                    if shouldPrint {
                        print(str, terminator: "")
                    }
                }
            }

            outputSource.setCancelHandler {
                try? outputHandle.close()
                group.leave()
            }

            outputSource.resume()
            readSources.append(outputSource)
        }

        let readGroup = DispatchGroup()

        let accumulatedOutput = Output()
        handleOutput(for: outputPipe, shouldPrint: options.contains(.printOutput), output: accumulatedOutput, group: readGroup)

        let accumulatedError = Output()
        handleOutput(for: errorPipe, shouldPrint: options.contains(.printOutput), output: accumulatedError, group: readGroup)

        do {
            try process.run()
        } catch {
            throw .runFailed(error)
        }

        process.waitUntilExit()
        readGroup.wait()

        if process.terminationStatus == 0 {
            return accumulatedOutput.value.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            throw Error.commandFailed(
                command: command,
                exitCode: process.terminationStatus,
                output: accumulatedError.value.trimmingCharacters(in: .whitespacesAndNewlines)
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

        process.environment = env.merging(environment, uniquingKeysWith: { _, new in new })
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["--login", "-c", command]

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
