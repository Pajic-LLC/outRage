import Foundation

public final class RunningProcess {
    public let process: Process
    private let outputHandle: FileHandle?

    init(process: Process, outputHandle: FileHandle? = nil) {
        self.process = process
        self.outputHandle = outputHandle
    }

    deinit {
        try? outputHandle?.close()
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
        try? outputHandle?.synchronize()
    }
}

public enum ProcessRunner {
    @discardableResult
    public static func start(
        _ command: LaunchCommand,
        inheritEnvironment: Bool = true,
        outputURL: URL? = nil,
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

        let outputHandle: FileHandle?
        if let outputURL {
            try fileManager.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if !fileManager.fileExists(atPath: outputURL.path) {
                guard fileManager.createFile(atPath: outputURL.path, contents: nil) else {
                    throw ProcessRunnerError.logUnavailable(outputURL.path)
                }
            }

            let handle = try FileHandle(forWritingTo: outputURL)
            try handle.seekToEnd()
            let timestamp = ISO8601DateFormatter().string(from: Date())
            try handle.write(contentsOf: Data("\n--- outRage session \(timestamp) ---\n".utf8))
            process.standardOutput = handle
            process.standardError = handle
            outputHandle = handle
        } else {
            outputHandle = nil
        }

        do {
            try process.run()
        } catch {
            try? outputHandle?.close()
            throw error
        }
        return RunningProcess(process: process, outputHandle: outputHandle)
    }
}

public enum ProcessRunnerError: Error, Equatable, CustomStringConvertible {
    case executableNotFound(String)
    case workingDirectoryNotFound(String)
    case logUnavailable(String)

    public var description: String {
        switch self {
        case .executableNotFound(let path):
            return "Launch executable is missing or not executable: \(path)"
        case .workingDirectoryNotFound(let path):
            return "Launch working directory does not exist: \(path)"
        case .logUnavailable(let path):
            return "Unable to create launch log: \(path)"
        }
    }
}
