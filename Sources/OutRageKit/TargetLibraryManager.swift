import Foundation

public struct TargetLibraryLocation: Equatable, Sendable {
    public let managedURL: URL
    public let storageURL: URL

    public init(managedURL: URL, storageURL: URL) {
        self.managedURL = managedURL
        self.storageURL = storageURL
    }
}

public enum TargetLibraryManager {
    @discardableResult
    public static func placeTarget(
        profileID: String,
        on volumeDirectory: URL,
        paths: RuntimePaths = RuntimePaths(),
        fileManager: FileManager = .default
    ) throws -> TargetLibraryLocation {
        guard !profileID.isEmpty,
              profileID.range(of: #"^[a-z0-9][a-z0-9._-]*$"#, options: .regularExpression) != nil else {
            throw TargetLibraryError.invalidProfileID(profileID)
        }

        try paths.ensureDirectories(fileManager: fileManager)
        let resourceValues = try volumeDirectory.resourceValues(forKeys: [.isDirectoryKey, .volumeIsReadOnlyKey])
        guard resourceValues.isDirectory == true else {
            throw TargetLibraryError.storageRootNotDirectory(volumeDirectory.path)
        }
        guard resourceValues.volumeIsReadOnly != true else {
            throw TargetLibraryError.storageVolumeReadOnly(volumeDirectory.path)
        }

        let libraryRoot = volumeDirectory
            .appendingPathComponent("outRage Games", isDirectory: true)
        let storageURL = libraryRoot.appendingPathComponent(profileID, isDirectory: true)
        try fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)

        let managedURL = paths.targetURL(for: profileID)
        if fileManager.fileExists(atPath: managedURL.path) || isSymbolicLink(managedURL) {
            if isSymbolicLink(managedURL) {
                let destination = try fileManager.destinationOfSymbolicLink(atPath: managedURL.path)
                let resolved = URL(fileURLWithPath: destination, relativeTo: managedURL.deletingLastPathComponent())
                    .standardizedFileURL
                    .resolvingSymlinksInPath()
                if resolved == storageURL.standardizedFileURL.resolvingSymlinksInPath() {
                    return TargetLibraryLocation(managedURL: managedURL, storageURL: storageURL)
                }
                throw TargetLibraryError.managedTargetAlreadyLinked(managedURL.path)
            }

            let contents = try fileManager.contentsOfDirectory(atPath: managedURL.path)
            guard contents.isEmpty else {
                throw TargetLibraryError.managedTargetNotEmpty(managedURL.path)
            }
            try fileManager.removeItem(at: managedURL)
        }

        try fileManager.createSymbolicLink(
            at: managedURL,
            withDestinationURL: storageURL
        )
        return TargetLibraryLocation(managedURL: managedURL, storageURL: storageURL)
    }

    public static func freeCapacity(
        at directory: URL
    ) throws -> Int64? {
        let values = try directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values.volumeAvailableCapacityForImportantUsage
    }

    private static func isSymbolicLink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }
}

public enum TargetLibraryError: Error, Equatable, CustomStringConvertible {
    case invalidProfileID(String)
    case storageRootNotDirectory(String)
    case storageVolumeReadOnly(String)
    case managedTargetAlreadyLinked(String)
    case managedTargetNotEmpty(String)

    public var description: String {
        switch self {
        case .invalidProfileID(let value): return "Invalid target library identifier: \(value)"
        case .storageRootNotDirectory(let path): return "Target storage root is not a directory: \(path)"
        case .storageVolumeReadOnly(let path): return "Target storage volume is read-only: \(path)"
        case .managedTargetAlreadyLinked(let path): return "Managed target is already linked elsewhere: \(path)"
        case .managedTargetNotEmpty(let path): return "Managed target already contains files: \(path)"
        }
    }
}
