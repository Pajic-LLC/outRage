import Foundation

public enum RuntimeInstaller {
    @discardableResult
    public static func install(
        archiveURL: URL,
        manifest: RuntimePackageManifest,
        paths: RuntimePaths = RuntimePaths(),
        fileManager: FileManager = .default
    ) throws -> InstalledRuntime {
        try manifest.validate()
        try paths.ensureDirectories(fileManager: fileManager)

        guard try FileDigest.verifySHA256(manifest.archiveSHA256, of: archiveURL) else {
            throw RuntimePackageError.checksumMismatch
        }

        let staging = paths.runtimesURL.appendingPathComponent(
            ".staging-" + UUID().uuidString,
            isDirectory: true
        )
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }

        try extractZip(archiveURL: archiveURL, destination: staging)

        let packageRoot: URL
        if let rootSubdirectory = manifest.rootSubdirectory {
            packageRoot = staging.appendingPathComponent(rootSubdirectory, isDirectory: true)
        } else {
            packageRoot = staging
        }

        let descriptorURL = packageRoot.appendingPathComponent("runtime.json")
        guard fileManager.fileExists(atPath: descriptorURL.path) else {
            throw RuntimePackageError.descriptorMissing
        }

        let descriptor = try RuntimeDescriptorLoader.load(from: descriptorURL)
        guard descriptor.id == manifest.runtimeIdentifier else {
            throw RuntimePackageError.descriptorIdentifierMismatch(
                expected: manifest.runtimeIdentifier,
                actual: descriptor.id
            )
        }

        let runtimeExecutable = packageRoot.appendingPathComponent(descriptor.executable)
        guard fileManager.fileExists(atPath: runtimeExecutable.path) else {
            throw LaunchSessionError.runtimeExecutableMissing(runtimeExecutable.path)
        }

        let destination = paths.runtimesURL.appendingPathComponent(descriptor.id, isDirectory: true)
        let backup = paths.runtimesURL.appendingPathComponent(
            ".backup-" + descriptor.id + "-" + UUID().uuidString,
            isDirectory: true
        )
        let hadExisting = fileManager.fileExists(atPath: destination.path)

        if hadExisting {
            try fileManager.moveItem(at: destination, to: backup)
        }

        do {
            try fileManager.moveItem(at: packageRoot, to: destination)
            if hadExisting {
                try? fileManager.removeItem(at: backup)
            }
        } catch {
            if hadExisting, fileManager.fileExists(atPath: backup.path) {
                try? fileManager.moveItem(at: backup, to: destination)
            }
            throw error
        }

        return InstalledRuntime(descriptor: descriptor, rootURL: destination)
    }

    private static func extractZip(archiveURL: URL, destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archiveURL.path, destination.path]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw RuntimePackageError.extractionFailed(process.terminationStatus)
        }
    }
}
