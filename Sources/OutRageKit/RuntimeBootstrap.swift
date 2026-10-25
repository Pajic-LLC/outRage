import Foundation

public enum RuntimeBootstrap {
    @discardableResult
    public static func ensureInstalled(
        for profile: RuntimeProfile,
        paths: RuntimePaths = RuntimePaths(),
        fileManager: FileManager = .default
    ) async throws -> InstalledRuntime? {
        try profile.validate()
        guard profile.runtime == .compatibility else { return nil }

        try paths.ensureDirectories(fileManager: fileManager)
        let catalog = RuntimeCatalog(runtimesURL: paths.runtimesURL)

        if let existing = try? catalog.resolve(
            identifier: profile.runtimeIdentifier,
            fileManager: fileManager
        ) {
            return existing
        }

        guard let source = profile.runtimePackageSource else {
            throw RuntimeBootstrapError.packageSourceMissing
        }
        try source.validate()

        if let expectedIdentifier = profile.runtimeIdentifier,
           expectedIdentifier != source.manifest.runtimeIdentifier {
            throw RuntimeBootstrapError.identifierMismatch(
                expected: expectedIdentifier,
                actual: source.manifest.runtimeIdentifier
            )
        }

        let archiveURL = paths.runtimePackageArchiveURL(
            identifier: source.manifest.runtimeIdentifier,
            version: source.manifest.version
        )

        let usableCachedArchive: Bool
        if fileManager.fileExists(atPath: archiveURL.path) {
            usableCachedArchive = try FileDigest.verifySHA256(
                source.manifest.archiveSHA256,
                of: archiveURL
            )
            if !usableCachedArchive {
                try fileManager.removeItem(at: archiveURL)
            }
        } else {
            usableCachedArchive = false
        }

        if !usableCachedArchive {
            _ = try await ArtifactDownloader.download(
                from: source.archiveURL,
                to: archiveURL,
                expectedSHA256: source.manifest.archiveSHA256,
                fileManager: fileManager
            )
        }

        return try RuntimeInstaller.install(
            archiveURL: archiveURL,
            manifest: source.manifest,
            paths: paths,
            fileManager: fileManager
        )
    }
}

public enum RuntimeBootstrapError: Error, Equatable, CustomStringConvertible {
    case packageSourceMissing
    case identifierMismatch(expected: String, actual: String)

    public var description: String {
        switch self {
        case .packageSourceMissing:
            return "Runtime is not installed and no package source is configured"
        case .identifierMismatch(let expected, let actual):
            return "Runtime package identifier mismatch: expected \(expected), found \(actual)"
        }
    }
}
