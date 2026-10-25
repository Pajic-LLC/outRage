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
    case mullion
    case d3dMetal
    case dxvk
    case vkd3d
}

public enum RuntimeKind: String, Codable, Sendable {
    case native
    case compatibility
}

public enum LauncherMode: String, Codable, Sendable {
    case direct
    case managed
}

public enum ExecutableScope: String, Codable, Sendable {
    case target
    case prefix
}

public struct RuntimeProfile: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var id: String
    public var displayName: String
    public var bundleIdentifier: String
    public var executable: String
    public var executableScope: ExecutableScope?
    public var workingDirectory: String?
    public var runtime: RuntimeKind
    public var runtimeIdentifier: String?
    public var runtimePackageSource: RuntimePackageSource?
    public var launcher: LauncherMode
    public var cpu: CPUBackend
    public var graphics: GraphicsBackend
    public var arguments: [String]
    public var environment: [String: String]
    public var pathMappings: [RuntimePathMapping]?
    public var processMatch: String?
    public var performance: PerformancePolicy?
    public var acquisition: AcquisitionDescriptor?

    public init(
        schemaVersion: Int = 1,
        id: String,
        displayName: String,
        bundleIdentifier: String,
        executable: String,
        executableScope: ExecutableScope? = .target,
        workingDirectory: String? = nil,
        runtime: RuntimeKind = .compatibility,
        runtimeIdentifier: String? = nil,
        runtimePackageSource: RuntimePackageSource? = nil,
        launcher: LauncherMode = .managed,
        cpu: CPUBackend = .auto,
        graphics: GraphicsBackend = .auto,
        arguments: [String] = [],
        environment: [String: String] = [:],
        pathMappings: [RuntimePathMapping]? = nil,
        processMatch: String? = nil,
        performance: PerformancePolicy? = nil,
        acquisition: AcquisitionDescriptor? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.executable = executable
        self.executableScope = executableScope
        self.workingDirectory = workingDirectory
        self.runtime = runtime
        self.runtimeIdentifier = runtimeIdentifier
        self.runtimePackageSource = runtimePackageSource
        self.launcher = launcher
        self.cpu = cpu
        self.graphics = graphics
        self.arguments = arguments
        self.environment = environment
        self.pathMappings = pathMappings
        self.processMatch = processMatch
        self.performance = performance
        self.acquisition = acquisition
    }

    public var resolvedExecutableScope: ExecutableScope {
        executableScope ?? .target
    }

    public var resolvedProcessMatch: String {
        if let processMatch,
           !processMatch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return processMatch
        }
        return URL(fileURLWithPath: executable).lastPathComponent
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
        guard !executable.isEmpty,
              !executable.hasPrefix("/"),
              !executable.split(separator: "/").contains("..") else {
            throw ProfileValidationError.executableMustBeRelative(executable)
        }
        if let workingDirectory,
           workingDirectory.hasPrefix("/") || workingDirectory.split(separator: "/").contains("..") {
            throw ProfileValidationError.workingDirectoryMustBeRelative(workingDirectory)
        }
        if resolvedExecutableScope == .prefix, runtime == .native {
            throw ProfileValidationError.prefixExecutableRequiresCompatibilityRuntime
        }
        if let runtimeIdentifier {
            guard !runtimeIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !runtimeIdentifier.contains("/") else {
                throw ProfileValidationError.invalidRuntimeIdentifier(runtimeIdentifier)
            }
        }
        if let processMatch {
            let trimmed = processMatch.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  !processMatch.contains("\n"),
                  !processMatch.contains("\r") else {
                throw ProfileValidationError.invalidProcessMatch(processMatch)
            }
        }
        if let runtimePackageSource {
            try runtimePackageSource.validate()
            if let runtimeIdentifier,
               runtimeIdentifier != runtimePackageSource.manifest.runtimeIdentifier {
                throw ProfileValidationError.runtimePackageIdentifierMismatch(
                    expected: runtimeIdentifier,
                    actual: runtimePackageSource.manifest.runtimeIdentifier
                )
            }
        }
        try pathMappings?.forEach { try $0.validate() }
        try performance?.validate()
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
    case prefixExecutableRequiresCompatibilityRuntime
    case invalidRuntimeIdentifier(String)
    case invalidProcessMatch(String)
    case runtimePackageIdentifierMismatch(expected: String, actual: String)

    public var description: String {
        switch self {
        case .unsupportedSchema(let value): return "Unsupported profile schema: \(value)"
        case .invalidID(let value): return "Invalid profile id: \(value)"
        case .emptyDisplayName: return "Profile display name cannot be empty"
        case .invalidBundleIdentifier(let value): return "Invalid bundle identifier: \(value)"
        case .executableMustBeRelative(let value): return "Executable path must be relative: \(value)"
        case .workingDirectoryMustBeRelative(let value): return "Working directory must be relative: \(value)"
        case .prefixExecutableRequiresCompatibilityRuntime: return "Prefix executables require a compatibility runtime"
        case .invalidRuntimeIdentifier(let value): return "Invalid runtime identifier: \(value)"
        case .invalidProcessMatch(let value): return "Invalid process match value: \(value)"
        case .runtimePackageIdentifierMismatch(let expected, let actual):
            return "Runtime package identifier mismatch: expected \(expected), found \(actual)"
        }
    }
}
