import Foundation

public enum RuntimeFileScope: String, Codable, Sendable {
    case target
    case prefix
    case cache
}

public enum RuntimeFileMode: String, Codable, Sendable {
    case copy
    case symlink
}

public struct RuntimeFileMapping: Codable, Equatable, Sendable {
    public var source: String
    public var destinationScope: RuntimeFileScope
    public var destination: String
    public var mode: RuntimeFileMode

    public init(
        source: String,
        destinationScope: RuntimeFileScope,
        destination: String,
        mode: RuntimeFileMode = .symlink
    ) {
        self.source = source
        self.destinationScope = destinationScope
        self.destination = destination
        self.mode = mode
    }

    public func validate() throws {
        guard ManagedRelativePath.isValid(source) else {
            throw RuntimeDescriptorError.invalidFileMapping(source)
        }
        guard ManagedRelativePath.isValid(destination) else {
            throw RuntimeDescriptorError.invalidFileMapping(destination)
        }
    }
}

public struct RuntimePathMapping: Codable, Equatable, Sendable {
    public var sourceScope: RuntimeFileScope
    public var source: String
    public var destinationScope: RuntimeFileScope
    public var destination: String

    public init(
        sourceScope: RuntimeFileScope,
        source: String = ".",
        destinationScope: RuntimeFileScope,
        destination: String
    ) {
        self.sourceScope = sourceScope
        self.source = source
        self.destinationScope = destinationScope
        self.destination = destination
    }

    public func validate() throws {
        guard ManagedRelativePath.isValid(source) else {
            throw RuntimeDescriptorError.invalidPathMapping(source)
        }
        guard ManagedRelativePath.isValid(destination) else {
            throw RuntimeDescriptorError.invalidPathMapping(destination)
        }
    }
}

private enum ManagedRelativePath {
    static func isValid(_ value: String) -> Bool {
        !value.isEmpty && !value.hasPrefix("/") && !value.split(separator: "/").contains("..")
    }
}

public struct RuntimeCommandDescriptor: Codable, Equatable, Sendable {
    public var executable: String
    public var arguments: [String]
    public var environment: [String: String]

    public init(
        executable: String,
        arguments: [String] = [],
        environment: [String: String] = [:]
    ) {
        self.executable = executable
        self.arguments = arguments
        self.environment = environment
    }

    public func validate() throws {
        guard ManagedRelativePath.isValid(executable) else {
            throw RuntimeDescriptorError.invalidRuntimeCommand(executable)
        }
    }
}

public struct RuntimeBackendConfiguration: Codable, Equatable, Sendable {
    public var arguments: [String]?
    public var environment: [String: String]?
    public var fileMappings: [RuntimeFileMapping]?

    public init(
        arguments: [String]? = nil,
        environment: [String: String]? = nil,
        fileMappings: [RuntimeFileMapping]? = nil
    ) {
        self.arguments = arguments
        self.environment = environment
        self.fileMappings = fileMappings
    }

    public func validate() throws {
        try fileMappings?.forEach { try $0.validate() }
    }
}

public struct RuntimeDescriptor: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var id: String
    public var revision: Int?
    public var executable: String
    public var argumentPrefix: [String]
    public var environment: [String: String]
    public var prefixInitializer: RuntimeCommandDescriptor?
    public var pathMappings: [RuntimePathMapping]?
    public var supportedCPUBackends: [CPUBackend]
    public var supportedGraphicsBackends: [GraphicsBackend]
    public var cpuConfigurations: [String: RuntimeBackendConfiguration]?
    public var graphicsConfigurations: [String: RuntimeBackendConfiguration]?

    public init(
        schemaVersion: Int = 1,
        id: String,
        revision: Int? = 1,
        executable: String,
        argumentPrefix: [String] = [],
        environment: [String: String] = [:],
        prefixInitializer: RuntimeCommandDescriptor? = nil,
        pathMappings: [RuntimePathMapping]? = nil,
        supportedCPUBackends: [CPUBackend] = [.native, .rosetta, .fex],
        supportedGraphicsBackends: [GraphicsBackend] = [.metal, .dxmt, .d3dMetal],
        cpuConfigurations: [String: RuntimeBackendConfiguration]? = nil,
        graphicsConfigurations: [String: RuntimeBackendConfiguration]? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.revision = revision
        self.executable = executable
        self.argumentPrefix = argumentPrefix
        self.environment = environment
        self.prefixInitializer = prefixInitializer
        self.pathMappings = pathMappings
        self.supportedCPUBackends = supportedCPUBackends
        self.supportedGraphicsBackends = supportedGraphicsBackends
        self.cpuConfigurations = cpuConfigurations
        self.graphicsConfigurations = graphicsConfigurations
    }

    public func validate() throws {
        guard schemaVersion == 1 else {
            throw RuntimeDescriptorError.unsupportedSchema(schemaVersion)
        }
        guard !id.isEmpty else {
            throw RuntimeDescriptorError.emptyID
        }
        guard ManagedRelativePath.isValid(executable) else {
            throw RuntimeDescriptorError.executableMustBeRelative(executable)
        }
        if let revision, revision < 1 {
            throw RuntimeDescriptorError.invalidRevision(revision)
        }
        try prefixInitializer?.validate()
        try pathMappings?.forEach { try $0.validate() }
        guard !supportedCPUBackends.isEmpty else {
            throw RuntimeDescriptorError.noCPUBackends
        }
        guard !supportedGraphicsBackends.isEmpty else {
            throw RuntimeDescriptorError.noGraphicsBackends
        }

        if let cpuConfigurations {
            for (key, configuration) in cpuConfigurations {
                guard let backend = CPUBackend(rawValue: key), backend != .auto else {
                    throw RuntimeDescriptorError.invalidCPUConfiguration(key)
                }
                try configuration.validate()
            }
        }
        if let graphicsConfigurations {
            for (key, configuration) in graphicsConfigurations {
                guard let backend = GraphicsBackend(rawValue: key), backend != .auto else {
                    throw RuntimeDescriptorError.invalidGraphicsConfiguration(key)
                }
                try configuration.validate()
            }
        }
    }

    public func configuration(for backend: CPUBackend) -> RuntimeBackendConfiguration? {
        cpuConfigurations?[backend.rawValue]
    }

    public func configuration(for backend: GraphicsBackend) -> RuntimeBackendConfiguration? {
        graphicsConfigurations?[backend.rawValue]
    }
}

public enum RuntimeDescriptorError: Error, Equatable, CustomStringConvertible {
    case unsupportedSchema(Int)
    case emptyID
    case invalidRevision(Int)
    case executableMustBeRelative(String)
    case invalidRuntimeCommand(String)
    case noCPUBackends
    case noGraphicsBackends
    case invalidCPUConfiguration(String)
    case invalidGraphicsConfiguration(String)
    case invalidFileMapping(String)
    case invalidPathMapping(String)

    public var description: String {
        switch self {
        case .unsupportedSchema(let value): return "Unsupported runtime schema: \(value)"
        case .emptyID: return "Runtime id cannot be empty"
        case .invalidRevision(let value): return "Runtime revision must be positive: \(value)"
        case .executableMustBeRelative(let value): return "Runtime executable must be relative: \(value)"
        case .invalidRuntimeCommand(let value): return "Runtime command must use a managed relative executable: \(value)"
        case .noCPUBackends: return "Runtime must declare at least one CPU backend"
        case .noGraphicsBackends: return "Runtime must declare at least one graphics backend"
        case .invalidCPUConfiguration(let value): return "Invalid CPU backend configuration: \(value)"
        case .invalidGraphicsConfiguration(let value): return "Invalid graphics backend configuration: \(value)"
        case .invalidFileMapping(let value): return "Runtime file mapping must use a managed relative path: \(value)"
        case .invalidPathMapping(let value): return "Runtime path mapping must use a managed relative path: \(value)"
        }
    }
}

public enum RuntimeDescriptorLoader {
    public static func load(from url: URL) throws -> RuntimeDescriptor {
        let data = try Data(contentsOf: url)
        let descriptor = try JSONDecoder().decode(RuntimeDescriptor.self, from: data)
        try descriptor.validate()
        return descriptor
    }
}
