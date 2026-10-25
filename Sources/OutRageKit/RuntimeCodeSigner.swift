import Foundation

public enum RuntimeCodeSigner {
    @discardableResult
    public static func signAdHoc(
        root: URL,
        fileManager: FileManager = .default
    ) throws -> Int {
        guard fileManager.fileExists(atPath: root.path) else {
            throw RuntimeCodeSigningError.rootMissing(root.path)
        }

        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey]
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        ) else {
            throw RuntimeCodeSigningError.enumerationFailed(root.path)
        }

        var signedCount = 0
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(resourceKeys))
            guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }
            guard MachOInspector.isMachO(url) else { continue }

            try signAdHoc(file: url)
            signedCount += 1
        }
        return signedCount
    }

    private static func signAdHoc(file: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = [
            "--force",
            "--sign", "-",
            "--timestamp=none",
            file.path
        ]
        process.standardOutput = FileHandle.nullDevice
        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(decoding: errorData, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw RuntimeCodeSigningError.codesignFailed(
                path: file.path,
                status: process.terminationStatus,
                message: message
            )
        }
    }
}

public enum RuntimeCodeSigningError: Error, Equatable, CustomStringConvertible {
    case rootMissing(String)
    case enumerationFailed(String)
    case codesignFailed(path: String, status: Int32, message: String)

    public var description: String {
        switch self {
        case .rootMissing(let path):
            return "Runtime signing root does not exist: \(path)"
        case .enumerationFailed(let path):
            return "Unable to enumerate runtime for signing: \(path)"
        case .codesignFailed(let path, let status, let message):
            return "codesign failed for \(path) with status \(status): \(message)"
        }
    }
}
