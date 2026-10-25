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

        let prepared = try prepareRuntime(
            profile: profile,
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

        let prepared = try prepareRuntime(
            profile: profile,
            paths: paths,
            host: host,
            fileManager: fileManager
        )
        return try makeCommand(
            profile: profile,
            executableURL: launcherURL,
            arguments: launcherArguments,
            suffix: ".launcher",
            prepared: prepared
        )
    }

    private struct PreparedRuntime {
        let installed: InstalledRuntime
        let cpu: CPUBackend
        let graphics: GraphicsBackend
        let context: RuntimeLaunchContext
    }

    private static func prepareRuntime(
        profile: RuntimeProfile,
        paths: RuntimePaths,
        host: HostCapabilities,
        fileManager: FileManager
    ) throws -> PreparedRuntime {
        guard profile.runtime == .compatibility else {
            throw ManagedLauncherBootstrapError.compatibilityRuntimeRequired
        }
        try profile.validate()
        try paths.ensureDirectories(fileManager: fileManager)
        try paths.ensureTargetDirectories(for: profile.id, fileManager: fileManager)

        let installed = try RuntimeCatalog(runtimesURL: paths.runtimesURL).resolve(
            identifier: profile.runtimeIdentifier,
            fileManager: fileManager
        )
        let runtimeExecutable = installed.rootURL.appendingPathComponent(installed.descriptor.executable)
        guard fileManager.isExecutableFile(atPath: runtimeExecutable.path) else {
            throw LaunchSessionError.runtimeExecutableMissing(runtimeExecutable.path)
        }

        let cpu = try BackendResolver.resolveCPU(
            requested: profile.cpu,
            runtime: installed.descriptor,
            host: host
        )
        let graphics = try BackendResolver.resolveGraphics(
            requested: profile.graphics,
            runtime: installed.descriptor
        )
        let context = RuntimeLaunchContext(
            runtimeRoot: installed.rootURL,
            targetRoot: paths.targetURL(for: profile.id),
            prefixRoot: paths.prefixURL(for: profile.id),
            cacheRoot: paths.cacheURL(for: profile.id)
        )

        try PrefixManager.ensureInitialized(
            runtime: installed.descriptor,
            runtimeRoot: installed.rootURL,
            cpu: cpu,
            graphics: graphics,
            context: context,
            logURL: paths.logURL(for: profile.id),
            fileManager: fileManager
        )
        try RuntimePathMapper.apply(
            installed.descriptor.pathMappings ?? [],
            context: context,
            fileManager: fileManager
        )
        try RuntimeOverlayInstaller.apply(
            runtime: installed.descriptor,
            cpu: cpu,
            graphics: graphics,
            context: context,
            fileManager: fileManager
        )

        return PreparedRuntime(
            installed: installed,
            cpu: cpu,
            graphics: graphics,
            context: context
        )
    }

    private static func makeCommand(
        profile: RuntimeProfile,
        executableURL: URL,
        arguments: [String],
        suffix: String,
        prepared: PreparedRuntime
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
            runtime: prepared.installed.descriptor,
            runtimeRoot: prepared.installed.rootURL,
            context: prepared.context
        )
    }
}

public enum ManagedLauncherBootstrapError: Error, Equatable, CustomStringConvertible {
    case wrongAcquisitionKind
    case compatibilityRuntimeRequired
    case launcherExecutableNotConfigured
    case launcherNotInstalled(String)

    public var description: String {
        switch self {
        case .wrongAcquisitionKind: return "Profile does not use managed launcher acquisition"
        case .compatibilityRuntimeRequired: return "Managed launcher bootstrap requires a compatibility runtime"
        case .launcherExecutableNotConfigured: return "Managed launcher executable is not configured"
        case .launcherNotInstalled(let path): return "Managed launcher is not installed: \(path)"
        }
    }
}
