import Foundation

public struct InstalledRuntime: Equatable, Sendable {
    public let descriptor: RuntimeDescriptor
    public let rootURL: URL

    public init(descriptor: RuntimeDescriptor, rootURL: URL) {
        self.descriptor = descriptor
        self.rootURL = rootURL
    }
}

public struct RuntimeCatalog: Sendable {
    public let runtimesURL: URL

    public init(runtimesURL: URL) {
        self.runtimesURL = runtimesURL
    }

    public func installed(fileManager: FileManager = .default) throws -> [InstalledRuntime] {
        guard fileManager.fileExists(atPath: runtimesURL.path) else { return [] }

        let candidates = try fileManager.contentsOfDirectory(
            at: runtimesURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var result: [InstalledRuntime] = []
        for root in candidates {
            let values = try root.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else { continue }

            let descriptorURL = root.appendingPathComponent("runtime.json")
            guard fileManager.fileExists(atPath: descriptorURL.path) else { continue }
            guard let descriptor = try? RuntimeDescriptorLoader.load(from: descriptorURL) else {
                continue
            }

            let executableURL = root.appendingPathComponent(descriptor.executable)
            guard fileManager.isExecutableFile(atPath: executableURL.path) else {
                continue
            }

            result.append(InstalledRuntime(descriptor: descriptor, rootURL: root))
        }

        return result.sorted { lhs, rhs in
            lhs.descriptor.id.localizedStandardCompare(rhs.descriptor.id) == .orderedAscending
        }
    }

    public func resolve(
        identifier: String?,
        fileManager: FileManager = .default
    ) throws -> InstalledRuntime {
        let installed = try installed(fileManager: fileManager)

        if let identifier, !identifier.isEmpty {
            guard let match = installed.first(where: { $0.descriptor.id == identifier }) else {
                throw RuntimeCatalogError.runtimeNotFound(identifier)
            }
            return match
        }

        switch installed.count {
        case 0:
            throw RuntimeCatalogError.noRuntimesInstalled
        case 1:
            return installed[0]
        default:
            throw RuntimeCatalogError.runtimeSelectionRequired(installed.map(\.descriptor.id))
        }
    }
}

public enum RuntimeCatalogError: Error, Equatable, CustomStringConvertible {
    case noRuntimesInstalled
    case runtimeNotFound(String)
    case runtimeSelectionRequired([String])

    public var description: String {
        switch self {
        case .noRuntimesInstalled:
            return "No runtime is installed"
        case .runtimeNotFound(let identifier):
            return "Runtime is not installed: \(identifier)"
        case .runtimeSelectionRequired(let identifiers):
            return "Multiple runtimes are installed; select one: \(identifiers.joined(separator: ", "))"
        }
    }
}
