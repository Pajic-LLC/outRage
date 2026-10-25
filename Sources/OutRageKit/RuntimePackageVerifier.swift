import Foundation

public struct RuntimePackageVerification: Equatable, Sendable {
    public let runtimeIdentifier: String
    public let version: String
    public let executableURL: URL

    public init(runtimeIdentifier: String, version: String, executableURL: URL) {
        self.runtimeIdentifier = runtimeIdentifier
        self.version = version
        self.executableURL = executableURL
    }
}

public enum RuntimePackageVerifier {
    public static func verify(
        archiveURL: URL,
        manifestURL: URL,
        fileManager: FileManager = .default
    ) throws -> RuntimePackageVerification {
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(RuntimePackageManifest.self, from: manifestData)
        try manifest.validate()

        let scratch = fileManager.temporaryDirectory.appendingPathComponent(
            "outRage-runtime-verify-" + UUID().uuidString,
            isDirectory: true
        )
        let paths = RuntimePaths(baseURL: scratch)
        defer { try? fileManager.removeItem(at: scratch) }

        let installed = try RuntimeInstaller.install(
            archiveURL: archiveURL,
            manifest: manifest,
            paths: paths,
            fileManager: fileManager
        )
        try installed.descriptor.validate()

        let executable = installed.rootURL.appendingPathComponent(installed.descriptor.executable)
        guard fileManager.isExecutableFile(atPath: executable.path) else {
            throw LaunchSessionError.runtimeExecutableMissing(executable.path)
        }

        return RuntimePackageVerification(
            runtimeIdentifier: installed.descriptor.id,
            version: manifest.version,
            executableURL: executable
        )
    }
}
