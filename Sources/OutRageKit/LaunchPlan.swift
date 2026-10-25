import Foundation

public struct LaunchPlan: Equatable, Sendable, CustomStringConvertible {
    public let profileID: String
    public let displayName: String
    public let executableURL: URL
    public let workingDirectoryURL: URL
    public let runtime: RuntimeKind
    public let launcher: LauncherMode
    public let cpu: CPUBackend
    public let graphics: GraphicsBackend
    public let arguments: [String]
    public let environment: [String: String]

    public var description: String {
        [
            "profile=\(profileID)",
            "target=\(executableURL.path)",
            "cpu=\(cpu.rawValue)",
            "graphics=\(graphics.rawValue)",
            "runtime=\(runtime.rawValue)",
            "launcher=\(launcher.rawValue)"
        ].joined(separator: "\n")
    }
}

public enum LaunchPlanner {
    public static func makePlan(
        profile: RuntimeProfile,
        targetRoot: URL,
        prefixRoot: URL? = nil,
        host: HostCapabilities = .current()
    ) throws -> LaunchPlan {
        try profile.validate()

        let executableRoot: URL
        switch profile.resolvedExecutableScope {
        case .target:
            executableRoot = targetRoot
        case .prefix:
            guard let prefixRoot else {
                throw LaunchPlannerError.prefixRootRequired
            }
            executableRoot = prefixRoot
        }

        let executableURL = executableRoot.appendingPathComponent(profile.executable)
        let workingDirectoryURL: URL
        if let relative = profile.workingDirectory {
            workingDirectoryURL = executableRoot.appendingPathComponent(relative, isDirectory: true)
        } else {
            workingDirectoryURL = executableURL.deletingLastPathComponent()
        }

        return LaunchPlan(
            profileID: profile.id,
            displayName: profile.displayName,
            executableURL: executableURL,
            workingDirectoryURL: workingDirectoryURL,
            runtime: profile.runtime,
            launcher: profile.launcher,
            cpu: profile.cpu == .auto ? host.recommendedCPUBackend : profile.cpu,
            graphics: profile.graphics,
            arguments: profile.arguments,
            environment: profile.environment
        )
    }
}

public enum LaunchPlannerError: Error, Equatable, CustomStringConvertible {
    case prefixRootRequired

    public var description: String {
        switch self {
        case .prefixRootRequired:
            return "Prefix root is required for a prefix-scoped executable"
        }
    }
}
