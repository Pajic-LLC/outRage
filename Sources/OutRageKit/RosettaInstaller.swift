import Foundation

public struct RosettaInstallCommand: Equatable, Sendable {
    public let executableURL: URL
    public let arguments: [String]

    public init(executableURL: URL, arguments: [String]) {
        self.executableURL = executableURL
        self.arguments = arguments
    }
}

public enum RosettaInstaller {
    public static var command: RosettaInstallCommand {
        RosettaInstallCommand(
            executableURL: URL(fileURLWithPath: "/usr/sbin/softwareupdate"),
            arguments: ["--install-rosetta", "--agree-to-license"]
        )
    }

    public static func install() async throws {
        #if os(macOS)
        let command = Self.command
        let process = Process()
        process.executableURL = command.executableURL
        process.arguments = command.arguments

        let output = Pipe()
        process.standardOutput = output
        process.standardError = output

        try process.run()
        let status = await wait(for: process)
        guard status == 0 else {
            let data = output.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw RosettaInstallError.failed(status: status, message: message)
        }
        #else
        throw RosettaInstallError.unsupportedPlatform
        #endif
    }

    private static func wait(for process: Process) async -> Int32 {
        await withCheckedContinuation { continuation in
            process.terminationHandler = { terminated in
                continuation.resume(returning: terminated.terminationStatus)
            }
        }
    }
}

public enum RosettaInstallError: Error, Equatable, CustomStringConvertible {
    case unsupportedPlatform
    case failed(status: Int32, message: String?)

    public var description: String {
        switch self {
        case .unsupportedPlatform:
            return "Rosetta installation is only available on macOS"
        case .failed(let status, let message):
            if let message, !message.isEmpty {
                return "Rosetta installation failed (\(status)): \(message)"
            }
            return "Rosetta installation failed with status \(status)"
        }
    }
}
