import Foundation

public struct RuntimeBackendConfiguration: Codable, Equatable, Sendable {
    public var arguments: [String]?
    public var environment: [String: String]?

    public init(
        arguments: [String]? = nil,
        environment: [String: String]? = nil
    ) {
        self.arguments = arguments
        self.environment = environment
    }
}

public struct RuntimeDescriptor: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var id: String
    public var executable: String
    public var argumentPrefix: [String]
    public var environment: [String: String]
    public var supportedCPUBackends: [CPUBackend]
    public var supportedGraphicsBackends: [GraphicsBackend]
    public var cpuConfigurations: [String: RuntimeBackendConfiguration]?
    public var graphicsConfigurations: [String: RuntimeBackendConfiguration]?

    public init(
        schemaVersion: Int = 1,
        id: String,
        executable: String,
        argumentPrefix: [String] = [],
        environment: [String: String] = [:],
        supportedCPUBackends: [CPUBackend] = [.native, .rosetta, .fex],
        supportedGraphicsBackends: [GraphicsBackend] = [.metal, .dxmt, .d3dMetal],
        cpuConfigurations: [String: RuntimeBackendConfiguration]? = nil,
        graphicsConfigurations: [String: RuntimeBackendConfiguration]? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.executable = executable
        self.argumentPrefix = argumentPrefix
        self.environment = environment
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
        guard !executable.isEmpty, !executable.hasPrefix("/") else {
            throw RuntimeDescriptorError.executableMustBeRelative(executable)
        }
        guard !supportedCPUBackends.isEmpty else {
            throw RuntimeDescriptorError.noCPUBackends
        }
        guard !supportedGraphicsBackends.isEmpty else {
            throw RuntimeDescriptorError.noGraphicsBackends
        }

        for key in cpuConfigurations?.keys ?? Dictionary<String, RuntimeBackendConfiguration>().keys {
            guard let backend = CPUBackend(rawValue: key), backend != .auto else {
                throw RuntimeDescriptorError.invalidCPUConfiguration(key)
            }
        }
        for key in graphicsConfigurations?.keys ?? Dictionary<String, RuntimeBackendConfiguration>().keys {
            guard let backend = GraphicsBackend(rawValue: key), backend != .auto else {
                throw RuntimeDescriptorError.invalidGraphicsConfiguration(key)
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
    case executableMustBeRelative(String)
    case noCPUBackends
    case noGraphicsBackends
    case invalidCPUConfiguration(String)
    case invalidGraphicsConfiguration(String)

    public var description: String {
        switch self {
        case .unsupportedSchema(let value): return "Unsupported runtime schema: \(value)"
        case .emptyID: return "Runtime id cannot be empty"
        case .executableMustBeRelative(let value): return "Runtime executable must be relative: \(value)"
        case .noCPUBackends: return "Runtime must declare at least one CPU backend"
        case .noGraphicsBackends: return "Runtime must declare at least one graphics backend"
        case .invalidCPUConfiguration(let value): return "Invalid CPU backend configuration: \(value)"
        case .invalidGraphicsConfiguration(let value): return "Invalid graphics backend configuration: \(value)"
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
