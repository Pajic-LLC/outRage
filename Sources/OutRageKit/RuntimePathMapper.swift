import Foundation

public enum RuntimePathMapper {
    public static func apply(
        _ mappings: [RuntimePathMapping],
        context: RuntimeLaunchContext,
        fileManager: FileManager = .default
    ) throws {
        for mapping in mappings {
            try mapping.validate()

            let sourceRoot = root(for: mapping.sourceScope, context: context)
            let destinationRoot = root(for: mapping.destinationScope, context: context)
            let sourceURL = sourceRoot.appendingPathComponent(mapping.source).standardizedFileURL
            let destinationURL = destinationRoot.appendingPathComponent(mapping.destination).standardizedFileURL

            try validateContained(sourceURL, root: sourceRoot, error: .sourceEscapesManagedRoot(sourceURL.path))
            try validateContained(destinationURL, root: destinationRoot, error: .destinationEscapesManagedRoot(destinationURL.path))

            guard fileManager.fileExists(atPath: sourceURL.path) else {
                throw RuntimePathMapperError.sourceMissing(sourceURL.path)
            }

            try fileManager.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            if fileManager.fileExists(atPath: destinationURL.path) ||
                (try? destinationURL.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
                let values = try destinationURL.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
                if values.isSymbolicLink == true {
                    try fileManager.removeItem(at: destinationURL)
                } else if values.isDirectory == true,
                          try fileManager.contentsOfDirectory(atPath: destinationURL.path).isEmpty {
                    // Launchers commonly create their configured install directory before
                    // writing any files. An empty directory is safe to adopt into our
                    // managed-storage mapping; anything non-empty remains protected.
                    try fileManager.removeItem(at: destinationURL)
                } else {
                    throw RuntimePathMapperError.destinationOccupied(destinationURL.path)
                }
            }

            try fileManager.createSymbolicLink(
                at: destinationURL,
                withDestinationURL: sourceURL.resolvingSymlinksInPath()
            )
        }
    }

    private static func root(for scope: RuntimeFileScope, context: RuntimeLaunchContext) -> URL {
        switch scope {
        case .target: context.targetRoot
        case .prefix: context.prefixRoot
        case .cache: context.cacheRoot
        }
    }

    private static func validateContained(
        _ url: URL,
        root: URL,
        error: RuntimePathMapperError
    ) throws {
        let canonicalRoot = root.standardizedFileURL.path
        let canonicalPath = url.standardizedFileURL.path
        guard canonicalPath == canonicalRoot || canonicalPath.hasPrefix(canonicalRoot + "/") else {
            throw error
        }
    }
}

public enum RuntimePathMapperError: Error, Equatable, CustomStringConvertible {
    case sourceMissing(String)
    case sourceEscapesManagedRoot(String)
    case destinationEscapesManagedRoot(String)
    case destinationOccupied(String)

    public var description: String {
        switch self {
        case .sourceMissing(let path): return "Runtime path mapping source does not exist: \(path)"
        case .sourceEscapesManagedRoot(let path): return "Runtime path mapping source is outside its managed root: \(path)"
        case .destinationEscapesManagedRoot(let path): return "Runtime path mapping destination is outside its managed root: \(path)"
        case .destinationOccupied(let path): return "Runtime path mapping destination is already occupied: \(path)"
        }
    }
}
