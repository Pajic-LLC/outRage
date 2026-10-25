import Foundation

public enum ManagedLauncherBootstrap {
    public static func installedLauncherURL(
        profile: RuntimeProfile,
        paths: RuntimePaths = RuntimePaths()
    ) throws -> URL? {
        let action = try AcquisitionPlanner.makePlan(profile: profile, paths: paths)
        guard case let .managedLauncher(_, _, _, _, installedLauncherURL, _, _) = action else {
            throw ManagedLauncherBootstrapError.wrongAcquisitionKind
        }
        return installedLauncherURL
    }

    public static func targetBootstrapURL(
        profile: RuntimeProfile,
        paths: RuntimePaths = RuntimePaths()
    ) throws -> URL? {
        guard let acquisition = profile.acquisition,
              acquisition.kind == .managedLauncher else {
            throw ManagedLauncherBootstrapError.wrongAcquisitionKind
        }
        try acquisition.validate()
        return acquisition.targetBootstrapExecutable.map {
            paths.targetURL(for: profile.id).appendingPathComponent($0)
        }
    }

    public static func prepareInstaller(
        profile: RuntimeProfile,
        paths: RuntimePaths = RuntimePaths(),
        fileManager: FileManager = .default
    ) async throws -> URL {
        try paths.ensureDirectories(fileManager: fileManager)
        try paths.ensureTargetDirectories(for: profile.id, fileManager: fileManager)

        let action = try AcquisitionPlanner.makePlan(profile: profile, paths: paths)
        guard case let .managedLauncher(
            sourceURL,
            expectedSHA256,
            installerDestinationURL,
            _,
            _,
            _,
            _
        ) = action else {
            throw ManagedLauncherBootstrapError.wrongAcquisitionKind
        }

        if fileManager.fileExists(atPath: installerDestinationURL.path) {
            if let expectedSHA256 {
                if try FileDigest.verifySHA256(expectedSHA256, of: installerDestinationURL) {
                    return installerDestinationURL
                }
                try fileManager.removeItem(at: installerDestinationURL)
            } else {
                return installerDestinationURL
            }
        }

        return try await ArtifactDownloader.download(
            from: sourceURL,
            to: installerDestinationURL,
            expectedSHA256: expectedSHA256,
            fileManager: fileManager
        )
    }

    public static func makeInstallerCommand(
        profile: RuntimeProfile,
        installerURL: URL,
        paths: RuntimePaths = RuntimePaths(),
        host: HostCapabilities = .current(),
        fileManager: FileManager = .default
    ) throws -> LaunchCommand {
        let action = try AcquisitionPlanner.makePlan(profile: profile, paths: paths)
        guard case let .managedLauncher(_, _, _, installerArguments, _, _, _) = action else {
            throw ManagedLauncherBootstrapError.wrongAcquisitionKind
        }

        let prepared = try RuntimeEnvironmentPreparer.prepare(
            profile: profile,
            executableForProbe: installerURL,
            paths: paths,
            host: host,
            fileManager: fileManager
        )

        return try makeCommand(
            profile: profile,
            executableURL: installerURL,
            arguments: installerArguments,
            suffix: ".bootstrap",
            prepared: prepared
        )
    }

    public static func makeTargetBootstrapCommand(
        profile: RuntimeProfile,
        paths: RuntimePaths = RuntimePaths(),
        host: HostCapabilities = .current(),
        fileManager: FileManager = .default
    ) throws -> LaunchCommand {
        guard let acquisition = profile.acquisition,
              acquisition.kind == .managedLauncher else {
            throw ManagedLauncherBootstrapError.wrongAcquisitionKind
        }
        try acquisition.validate()
        guard let relativeExecutable = acquisition.targetBootstrapExecutable else {
            throw ManagedLauncherBootstrapError.targetBootstrapExecutableNotConfigured
        }

        let executableURL = paths.targetURL(for: profile.id)
            .appendingPathComponent(relativeExecutable)
        guard fileManager.fileExists(atPath: executableURL.path) else {
            throw ManagedLauncherBootstrapError.targetBootstrapNotInstalled(executableURL.path)
        }

        let targetURL = paths.executableURL(for: profile)
        let prepared = try RuntimeEnvironmentPreparer.prepare(
            profile: profile,
            executableForProbe: fileManager.fileExists(atPath: targetURL.path) ? targetURL : executableURL,
            paths: paths,
            host: host,
            fileManager: fileManager
        )
        var command = try makeCommand(
            profile: profile,
            executableURL: executableURL,
            arguments: acquisition.targetBootstrapArguments ?? [],
            suffix: ".target-bootstrap",
            prepared: prepared
        )
        command = try tuneForInstalledTarget(
            command,
            profile: profile,
            prepared: prepared,
            paths: paths,
            fileManager: fileManager
        )
        return command
    }

    public static func makeInstalledLauncherCommand(
        profile: RuntimeProfile,
        paths: RuntimePaths = RuntimePaths(),
        host: HostCapabilities = .current(),
        fileManager: FileManager = .default
    ) throws -> LaunchCommand {
        let action = try AcquisitionPlanner.makePlan(profile: profile, paths: paths)
        guard case let .managedLauncher(_, _, _, _, launcherURL, launcherArguments, _) = action else {
            throw ManagedLauncherBootstrapError.wrongAcquisitionKind
        }
        guard let launcherURL else {
            throw ManagedLauncherBootstrapError.launcherExecutableNotConfigured
        }
        guard fileManager.fileExists(atPath: launcherURL.path) else {
            throw ManagedLauncherBootstrapError.launcherNotInstalled(launcherURL.path)
        }

        let targetURL = paths.executableURL(for: profile)
        let prepared = try RuntimeEnvironmentPreparer.prepare(
            profile: profile,
            executableForProbe: fileManager.fileExists(atPath: targetURL.path) ? targetURL : launcherURL,
            paths: paths,
            host: host,
            fileManager: fileManager
        )
        var command = try makeCommand(
            profile: profile,
            executableURL: launcherURL,
            arguments: launcherArguments,
            suffix: ".launcher",
            prepared: prepared
        )
        command = try tuneForInstalledTarget(
            command,
            profile: profile,
            prepared: prepared,
            paths: paths,
            fileManager: fileManager
        )
        return command
    }

    private static func tuneForInstalledTarget(
        _ command: LaunchCommand,
        profile: RuntimeProfile,
        prepared: PreparedCompatibilityRuntime,
        paths: RuntimePaths,
        fileManager: FileManager
    ) throws -> LaunchCommand {
        let targetURL = paths.executableURL(for: profile)
        guard fileManager.fileExists(atPath: targetURL.path),
              let targetFingerprint = try? TargetBuildFingerprint.inspect(
                  executableURL: targetURL,
                  fileManager: fileManager
              ) else {
            return command
        }

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
        return PerformanceLaunchTuner.tune(command, cache: cache)
    }

    private static func makeCommand(
        profile: RuntimeProfile,
        executableURL: URL,
        arguments: [String],
        suffix: String,
        prepared: PreparedCompatibilityRuntime
    ) throws -> LaunchCommand {
        let plan = LaunchPlan(
            profileID: profile.id + suffix,
            displayName: profile.displayName,
            executableURL: executableURL,
            workingDirectoryURL: executableURL.deletingLastPathComponent(),
            runtime: .compatibility,
            launcher: .managed,
            cpu: prepared.cpu,
            graphics: prepared.graphics,
            arguments: arguments,
            environment: profile.environment
        )

        return try LaunchCommandBuilder.make(
            plan: plan,
            runtime: prepared.installedRuntime.descriptor,
            runtimeRoot: prepared.installedRuntime.rootURL,
            context: prepared.context
        )
    }
}

public enum ManagedLauncherBootstrapError: Error, Equatable, CustomStringConvertible {
    case wrongAcquisitionKind
    case compatibilityRuntimeRequired
    case launcherExecutableNotConfigured
    case launcherNotInstalled(String)
    case targetBootstrapExecutableNotConfigured
    case targetBootstrapNotInstalled(String)

    public var description: String {
        switch self {
        case .wrongAcquisitionKind: return "Profile does not use managed launcher acquisition"
        case .compatibilityRuntimeRequired: return "Managed launcher bootstrap requires a compatibility runtime"
        case .launcherExecutableNotConfigured: return "Managed launcher executable is not configured"
        case .launcherNotInstalled(let path): return "Managed launcher is not installed: \(path)"
        case .targetBootstrapExecutableNotConfigured: return "Managed title bootstrap executable is not configured"
        case .targetBootstrapNotInstalled(let path): return "Managed title bootstrap executable is not installed: \(path)"
        }
    }
}
