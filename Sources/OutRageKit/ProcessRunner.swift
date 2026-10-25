import Foundation

public final class RunningProcess {
    public let process: Process

    init(process: Process) {
        self.process = process
    }

    public var processIdentifier: Int32 { process.processIdentifier }
    public var isRunning: Bool { process.isRunning }
    public var terminationStatus: Int32 { process.terminationStatus }

    public func terminate() {
        process.terminate()
    }

    public func interrupt() {
        process.interrupt()
    }

    public func waitUntilExit() {
        process.waitUntilExit()
    }
}

public enum ProcessRunner {
    @discardableResult
    public static func start(
        _ command: LaunchCommand,
        inheritEnvironment: Bool = true,
        fileManager: FileManager = .default
    ) throws -> RunningProcess {
        guard fileManager.isExecutableFile(atPath: command.executableURL.path) else {
            throw ProcessRunnerError.executableNotFound(command.executableURL.path)
        }
        guard fileManager.fileExists(atPath: command.workingDirectoryURL.path) else {
            throw ProcessRunnerError.workingDirectoryNotFound(command.workingDirectoryURL.path)
        }

        let process = Process()
        process.executableURL = command.executableURL
        process.arguments = command.arguments
        process.currentDirectoryURL = command.workingDirectoryURL

        var environment = inheritEnvironment ? ProcessInfo.processInfo.environment : [:]
        command.environment.forEach { environment[$0.key] = $0.value }
        process.environment = environment

        try process.run()
        return RunningProcess(process: process)
    }
}

public enum ProcessRunnerError: Error, Equatable, CustomStringConvertible {
    case executableNotFound(String)
    case workingDirectoryNotFound(String)

    public var description: String {
        switch self {
        case .executableNotFound(let path):
            return "Launch executable is missing or not executable: \(path)"
        case .workingDirectoryNotFound(let path):
            return "Launch working directory does not exist: \(path)"
        }
    }
}
