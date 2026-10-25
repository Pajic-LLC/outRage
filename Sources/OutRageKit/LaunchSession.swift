import Foundation

public struct LaunchSession: Equatable, Sendable {
    public let profile: RuntimeProfile
    public let plan: LaunchPlan
    public let command: LaunchCommand
    public let runtimeIdentifier: String?

    public init(
        profile: RuntimeProfile,
        plan: LaunchPlan,
        command: LaunchCommand,
        runtimeIdentifier: String?
    ) {
        self.profile = profile
        self.plan = plan
        self.command = command
        self.runtimeIdentifier = runtimeIdentifier
    }
}

public enum LaunchSessionBuilder {
    public static func prepare(
        profile: RuntimeProfile,
        paths: RuntimePaths = RuntimePaths(),
        host: HostCapabilities = .current(),
        fileManager: FileManager = .default
    ) throws -> LaunchSession {
        try profile.validate()
        try paths.ensureDirectories(fileManager: fileManager)
        try paths.ensureTargetDirectories(for: profile.id, fileManager: fileManager)

        let targetRoot = paths.targetURL(for: profile.id)
        let plan = try LaunchPlanner.makePlan(
            profile: profile,
            targetRoot: targetRoot,
            host: host
        )

        guard fileManager.fileExists(atPath: plan.executableURL.path) else {
            throw LaunchSessionError.targetExecutableMissing(plan.executableURL.path)
        }

        if profile.runtime == .native {
            let command = try LaunchCommandBuilder.make(plan: plan)
            return LaunchSession(
                profile: profile,
                plan: plan,
                command: command,
                runtimeIdentifier: nil
            )
        }

        let catalog = RuntimeCatalog(runtimesURL: paths.runtimesURL)
        let installed = try catalog.resolve(
            identifier: profile.runtimeIdentifier,
            fileManager: fileManager
        )

        let runtimeExecutable = installed.rootURL.appendingPathComponent(installed.descriptor.executable)
        guard fileManager.isExecutableFile(atPath: runtimeExecutable.path) else {
            throw LaunchSessionError.runtimeExecutableMissing(runtimeExecutable.path)
        }

        let context = RuntimeLaunchContext(
            runtimeRoot: installed.rootURL,
            targetRoot: targetRoot,
            prefixRoot: paths.prefixURL(for: profile.id),
            cacheRoot: paths.cacheURL(for: profile.id)
        )

        let command = try LaunchCommandBuilder.make(
            plan: plan,
            runtime: installed.descriptor,
            runtimeRoot: installed.rootURL,
            context: context
        )

        return LaunchSession(
            profile: profile,
            plan: plan,
            command: command,
            runtimeIdentifier: installed.descriptor.id
        )
    }
}

public enum LaunchSessionError: Error, Equatable, CustomStringConvertible {
    case targetExecutableMissing(String)
    case runtimeExecutableMissing(String)

    public var description: String {
        switch self {
        case .targetExecutableMissing(let path):
            return "Target executable is missing: \(path)"
        case .runtimeExecutableMissing(let path):
            return "Runtime executable is missing or not executable: \(path)"
        }
    }
}
