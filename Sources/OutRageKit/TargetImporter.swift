import Foundation

public enum TargetImporter {
    @discardableResult
    public static func linkExisting(
        sourceDirectory: URL,
        profile: RuntimeProfile,
        paths: RuntimePaths = RuntimePaths(),
        fileManager: FileManager = .default
    ) throws -> URL {
        try profile.validate()

        let sourceExecutable = sourceDirectory.appendingPathComponent(profile.executable)
        guard fileManager.fileExists(atPath: sourceExecutable.path) else {
            throw TargetImportError.executableMissing(sourceExecutable.path)
        }

        try paths.ensureDirectories(fileManager: fileManager)
        let destination = paths.targetURL(for: profile.id)

        if fileManager.fileExists(atPath: destination.path) {
            let values = try destination.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
            if values.isSymbolicLink == true {
                try fileManager.removeItem(at: destination)
            } else if values.isDirectory == true {
                let contents = try fileManager.contentsOfDirectory(atPath: destination.path)
                guard contents.isEmpty else {
                    throw TargetImportError.targetDirectoryNotEmpty(destination.path)
                }
                try fileManager.removeItem(at: destination)
            } else {
                throw TargetImportError.targetPathOccupied(destination.path)
            }
        }

        try fileManager.createSymbolicLink(
            at: destination,
            withDestinationURL: sourceDirectory.resolvingSymlinksInPath()
        )
        return destination
    }
}

public enum TargetImportError: Error, Equatable, CustomStringConvertible {
    case executableMissing(String)
    case targetDirectoryNotEmpty(String)
    case targetPathOccupied(String)

    public var description: String {
        switch self {
        case .executableMissing(let path): return "Selected target does not contain the expected executable: \(path)"
        case .targetDirectoryNotEmpty(let path): return "Target directory already contains files: \(path)"
        case .targetPathOccupied(let path): return "Target path is already occupied: \(path)"
        }
    }
}
