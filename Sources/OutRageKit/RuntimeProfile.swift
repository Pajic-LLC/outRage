import Foundation

public enum CPUBackend: String, Codable, Sendable, CaseIterable {
    case auto
    case native
    case rosetta
    case fex
}

public enum GraphicsBackend: String, Codable, Sendable, CaseIterable {
    case auto
    case metal
    case dxmt
    case d3dMetal
}

public enum RuntimeKind: String, Codable, Sendable {
    case native
    case compatibility
}

public enum LauncherMode: String, Codable, Sendable {
    case direct
    case managed
}

public struct RuntimeProfile: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var id: String
    public var displayName: String
    public var bundleIdentifier: String
    public var executable: String
    public var workingDirectory: String?
    public var runtime: RuntimeKind
    public var runtimeIdentifier: String?
    public var launcher: LauncherMode
    public var cpu: CPUBackend
    public var graphics: GraphicsBackend
    public var arguments: [String]
    public var environment: [String: String]
    public var acquisition: AcquisitionDescriptor?

    public init(
        schemaVersion: Int = 1,
        id: String,
        displayName: String,
        bundleIdentifier: String,
        executable: String,
        workingDirectory: String? = nil,
        runtime: RuntimeKind = .compatibility,
        runtimeIdentifier: String? = nil,
        launcher: LauncherMode = .managed,
        cpu: CPUBackend = .auto,
        graphics: GraphicsBackend = .auto,
        arguments: [String] = [],
        environment: [String: String] = [:],
        acquisition: AcquisitionDescriptor? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.executable = executable
        self.workingDirectory = workingDirectory
        self.runtime = runtime
        self.runtimeIdentifier = runtimeIdentifier
        self.launcher = launcher
        self.cpu = cpu
        self.graphics = graphics
        self.arguments = arguments
        self.environment = environment
        self.acquisition = acquisition
    }

    public func validate() throws {
        guard schemaVersion == 1 else {
            throw ProfileValidationError.unsupportedSchema(schemaVersion)
        }
        guard !id.isEmpty, id.range(of: #"^[a-z0-9][a-z0-9._-]*$"#, options: .regularExpression) != nil else {
            throw ProfileValidationError.invalidID(id)
        }
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProfileValidationError.emptyDisplayName
        }
        guard bundleIdentifier.contains("."), !bundleIdentifier.contains(" ") else {
            throw ProfileValidationError.invalidBundleIdentifier(bundleIdentifier)
        }
        guard !executable.isEmpty, !executable.hasPrefix("/") else {
            throw ProfileValidationError.executableMustBeRelative(executable)
        }
        if let workingDirectory, workingDirectory.hasPrefix("/") {
            throw ProfileValidationError.workingDirectoryMustBeRelative(workingDirectory)
        }
        if let runtimeIdentifier {
            guard !runtimeIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !runtimeIdentifier.contains("/") else {
                throw ProfileValidationError.invalidRuntimeIdentifier(runtimeIdentifier)
            }
        }
        try acquisition?.validate()
    }
}

public enum ProfileValidationError: Error, Equatable, CustomStringConvertible {
    case unsupportedSchema(Int)
    case invalidID(String)
    case emptyDisplayName
    case invalidBundleIdentifier(String)
    case executableMustBeRelative(String)
    case workingDirectoryMustBeRelative(String)
    case invalidRuntimeIdentifier(String)

    public var description: String {
        switch self {
        case .unsupportedSchema(let value): return "Unsupported profile schema: \(value)"
        case .invalidID(let value): return "Invalid profile id: \(value)"
        case .emptyDisplayName: return "Profile display name cannot be empty"
        case .invalidBundleIdentifier(let value): return "Invalid bundle identifier: \(value)"
        case .executableMustBeRelative(let value): return "Executable path must be relative: \(value)"
        case .workingDirectoryMustBeRelative(let value): return "Working directory must be relative: \(value)"
        case .invalidRuntimeIdentifier(let value): return "Invalid runtime identifier: \(value)"
        }
    }
}
