import Foundation

public enum AppBundleCodeSigner {
    public static func sign(
        appURL: URL,
        identity: String = "-",
        hardenedRuntime: Bool = false
    ) throws {
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            throw AppBundleCodeSigningError.bundleMissing(appURL.path)
        }

        var arguments = ["--force", "--sign", identity, "--timestamp=none"]
        if hardenedRuntime {
            arguments += ["--options", "runtime"]
        }
        arguments.append(appURL.path)

        try runCodesign(arguments, operation: "sign")
    }

    public static func verify(appURL: URL) throws {
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            throw AppBundleCodeSigningError.bundleMissing(appURL.path)
        }
        try runCodesign(
            ["--verify", "--strict", "--verbose=2", appURL.path],
            operation: "verify"
        )
    }

    private static func runCodesign(_ arguments: [String], operation: String) throws {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw AppBundleCodeSigningError.codesignFailed(
                operation: operation,
                status: process.terminationStatus,
                message: message
            )
        }
    }
}

public enum AppBundleCodeSigningError: Error, Equatable, CustomStringConvertible {
    case bundleMissing(String)
    case codesignFailed(operation: String, status: Int32, message: String)

    public var description: String {
        switch self {
        case .bundleMissing(let path): return "App bundle does not exist: \(path)"
        case .codesignFailed(let operation, let status, let message):
            return "codesign \(operation) failed with status \(status): \(message)"
        }
    }
}
