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
        let prefixRoot = paths.prefixURL(for: profile.id)

        if profile.runtime == .native {
            let executableURL = paths.executableURL(for: profile)
            guard fileManager.fileExists(atPath: executableURL.path) else {
                throw LaunchSessionError.targetExecutableMissing(executableURL.path)
            }

            let plan = try LaunchPlanner.makePlan(
                profile: profile,
                targetRoot: targetRoot,
                prefixRoot: prefixRoot,
                host: host
            )
            let command = try LaunchCommandBuilder.make(plan: plan)
            return LaunchSession(
                profile: profile,
                plan: plan,
                command: command,
                runtimeIdentifier: nil
            )
        }

        let executableURL = paths.executableURL(for: profile)
        let prepared = try RuntimeEnvironmentPreparer.prepare(
            profile: profile,
            executableForProbe: fileManager.fileExists(atPath: executableURL.path) ? executableURL : nil,
            paths: paths,
            host: host,
            fileManager: fileManager
        )

        guard fileManager.fileExists(atPath: executableURL.path) else {
            throw LaunchSessionError.targetExecutableMissing(executableURL.path)
        }

        var resolvedProfile = profile
        resolvedProfile.cpu = prepared.cpu
        resolvedProfile.graphics = prepared.graphics

        let plan = try LaunchPlanner.makePlan(
            profile: resolvedProfile,
            targetRoot: targetRoot,
            prefixRoot: prefixRoot,
            host: host
        )
        var command = try LaunchCommandBuilder.make(
            plan: plan,
            runtime: prepared.installedRuntime.descriptor,
            runtimeRoot: prepared.installedRuntime.rootURL,
            context: prepared.context
        )

        if let targetFingerprint = try? TargetBuildFingerprint.inspect(
            executableURL: executableURL,
            fileManager: fileManager
        ) {
            let cacheFingerprint = RuntimeCacheFingerprint(
                profileID: profile.id,
                target: targetFingerprint,
                runtimeIdentifier: prepared.installedRuntime.descriptor.id,
                runtimeRevision: prepared.installedRuntime.descriptor.revision ?? 1,
                graphicsBackend: prepared.graphics
            )
            let cache = try RuntimeCacheManager.prepare(
                fingerprint: cacheFingerprint,
                paths: paths,
                fileManager: fileManager
            )
            command = PerformanceLaunchTuner.tune(
                command,
                cache: cache,
                policy: profile.performance,
                explicitEnvironment: profile.environment
            )
        }

        let diagnostics = LaunchDiagnosticsBuilder.make(
            profile: profile,
            executableURL: executableURL,
            host: host,
            runtime: prepared.installedRuntime.descriptor,
            cpu: prepared.cpu,
            graphics: prepared.graphics,
            fileManager: fileManager
        )
        try? LaunchDiagnosticsBuilder.write(
            diagnostics,
            to: paths.diagnosticsURL(for: profile.id),
            fileManager: fileManager
        )

        return LaunchSession(
            profile: profile,
            plan: plan,
            command: command,
            runtimeIdentifier: prepared.installedRuntime.descriptor.id
        )
    }
}

public enum LaunchSessionError: Error, Equatable, CustomStringConvertible {
    case targetExecutableMissing(String)
    case runtimeExecutableMissing(String)

    public var description: String {
        switch self {
        case .targetExecutableMissing(let path):
            return "Configured executable is missing: \(path)"
        case .runtimeExecutableMissing(let path):
            return "Runtime executable is missing or not executable: \(path)"
        }
    }
}
