import Foundation

public struct RuntimeDescriptor: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var id: String
    public var executable: String
    public var argumentPrefix: [String]
    public var environment: [String: String]
    public var supportedCPUBackends: [CPUBackend]
    public var supportedGraphicsBackends: [GraphicsBackend]

    public init(
        schemaVersion: Int = 1,
        id: String,
        executable: String,
        argumentPrefix: [String] = [],
        environment: [String: String] = [:],
        supportedCPUBackends: [CPUBackend] = [.native, .rosetta, .fex],
        supportedGraphicsBackends: [GraphicsBackend] = [.metal, .dxmt, .d3dMetal]
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.executable = executable
        self.argumentPrefix = argumentPrefix
        self.environment = environment
        self.supportedCPUBackends = supportedCPUBackends
        self.supportedGraphicsBackends = supportedGraphicsBackends
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
    }
}

public enum RuntimeDescriptorError: Error, Equatable, CustomStringConvertible {
    case unsupportedSchema(Int)
    case emptyID
    case executableMustBeRelative(String)
    case noCPUBackends
    case noGraphicsBackends

    public var description: String {
        switch self {
        case .unsupportedSchema(let value): return "Unsupported runtime schema: \(value)"
        case .emptyID: return "Runtime id cannot be empty"
        case .executableMustBeRelative(let value): return "Runtime executable must be relative: \(value)"
        case .noCPUBackends: return "Runtime must declare at least one CPU backend"
        case .noGraphicsBackends: return "Runtime must declare at least one graphics backend"
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
