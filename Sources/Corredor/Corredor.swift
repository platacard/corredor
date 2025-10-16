import Foundation

// For serious usage
public typealias Shell = Corredor

// By design
public struct Corredor: Sendable {

    public static func script(_ script: String, in folder: URL) -> ShellRunner {
        ShellRunner(command: "cd \(folder.path()); chmod +x \(script); ./\(script)")
    }

    public static func command(
        _ command: String,
        arguments: [BashArgument] = [],
        environment: [String: String] = [:],
        in folder: URL,
        options: [ShellOption] = []
    ) -> ShellRunner {
        ShellRunner(
            command: "cd \(folder.path()); " + command + " " + arguments.map(\.bashArgument).joined(separator: " "),
            environment: environment,
            options: options
        )
    }

    public static func arguments(
        _ arguments: [String],
        environment: [String: String] = [:],
        in folder: URL,
        options: [ShellOption] = []
    ) -> ShellRunner {
        ShellRunner(
            command: "cd \(folder.path()); \(arguments.joined(separator: " "))",
            environment: environment,
            options: options
        )
    }

    public static func arguments(
        _ arguments: [String],
        environment: [String: String] = [:],
        options: [ShellOption] = []
    ) -> ShellRunner {
        ShellRunner(
            command: arguments.joined(separator: " "),
            environment: environment,
            options: options
        )
    }

    public static func command(
        _ command: String,
        arguments: [BashArgument] = [],
        environment: [String: String] = [:],
        options: [ShellOption] = []
    ) -> ShellRunner {
        ShellRunner(
            command: command + " " + arguments.map(\.bashArgument).joined(separator: " "),
            environment: environment,
            options: options
        )
    }
}
