import Foundation

public enum RuntimeOverlayInstaller {
    public static func apply(
        runtime: RuntimeDescriptor,
        cpu: CPUBackend,
        graphics: GraphicsBackend,
        context: RuntimeLaunchContext,
        fileManager: FileManager = .default
    ) throws {
        var mappings: [RuntimeFileMapping] = []
        mappings += runtime.configuration(for: cpu)?.fileMappings ?? []
        mappings += runtime.configuration(for: graphics)?.fileMappings ?? []

        for mapping in mappings {
            try mapping.validate()
            let sourceURL = context.runtimeRoot.appendingPathComponent(mapping.source)
            guard fileManager.fileExists(atPath: sourceURL.path) else {
                throw RuntimeOverlayError.sourceMissing(sourceURL.path)
            }

            let scopeRoot: URL
            switch mapping.destinationScope {
            case .target: scopeRoot = context.targetRoot
            case .prefix: scopeRoot = context.prefixRoot
            case .cache: scopeRoot = context.cacheRoot
            }

            let destinationURL = scopeRoot.appendingPathComponent(mapping.destination)
            let canonicalRoot = scopeRoot.standardizedFileURL
            let canonicalDestination = destinationURL.standardizedFileURL
            guard canonicalDestination.path == canonicalRoot.path ||
                    canonicalDestination.path.hasPrefix(canonicalRoot.path + "/") else {
                throw RuntimeOverlayError.destinationEscapesManagedRoot(destinationURL.path)
            }

            try fileManager.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            if fileManager.fileExists(atPath: destinationURL.path) ||
                (try? destinationURL.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
                try fileManager.removeItem(at: destinationURL)
            }

            switch mapping.mode {
            case .copy:
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
            case .symlink:
                try fileManager.createSymbolicLink(
                    at: destinationURL,
                    withDestinationURL: sourceURL.resolvingSymlinksInPath()
                )
            }
        }
    }
}

public enum RuntimeOverlayError: Error, Equatable, CustomStringConvertible {
    case sourceMissing(String)
    case destinationEscapesManagedRoot(String)

    public var description: String {
        switch self {
        case .sourceMissing(let path): return "Runtime overlay source does not exist: \(path)"
        case .destinationEscapesManagedRoot(let path): return "Runtime overlay destination is outside its managed root: \(path)"
        }
    }
}
