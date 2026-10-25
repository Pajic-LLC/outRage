import Foundation

public struct RuntimePackageVerification: Equatable, Sendable {
    public let runtimeIdentifier: String
    public let version: String
    public let executable: String

    public init(runtimeIdentifier: String, version: String, executable: String) {
        self.runtimeIdentifier = runtimeIdentifier
        self.version = version
        self.executable = executable
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

        let executableURL = installed.rootURL.appendingPathComponent(installed.descriptor.executable)
        guard fileManager.isExecutableFile(atPath: executableURL.path) else {
            throw LaunchSessionError.runtimeExecutableMissing(executableURL.path)
        }

        return RuntimePackageVerification(
            runtimeIdentifier: installed.descriptor.id,
            version: manifest.version,
            executable: installed.descriptor.executable
        )
    }
}
