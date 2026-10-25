import Foundation

public enum ManagedLauncherBootstrap {
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
        guard profile.runtime == .compatibility else {
            throw ManagedLauncherBootstrapError.compatibilityRuntimeRequired
        }
        try profile.validate()
        try paths.ensureDirectories(fileManager: fileManager)
        try paths.ensureTargetDirectories(for: profile.id, fileManager: fileManager)

        let action = try AcquisitionPlanner.makePlan(profile: profile, paths: paths)
        guard case let .managedLauncher(_, _, _, installerArguments, _) = action else {
            throw ManagedLauncherBootstrapError.wrongAcquisitionKind
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

        let cpu = profile.cpu == .auto ? host.recommendedCPUBackend : profile.cpu
        let plan = LaunchPlan(
            profileID: profile.id + ".bootstrap",
            displayName: profile.displayName,
            executableURL: installerURL,
            workingDirectoryURL: installerURL.deletingLastPathComponent(),
            runtime: .compatibility,
            launcher: .managed,
            cpu: cpu,
            graphics: profile.graphics,
            arguments: installerArguments,
            environment: profile.environment
        )
        let context = RuntimeLaunchContext(
            runtimeRoot: installed.rootURL,
            targetRoot: paths.targetURL(for: profile.id),
            prefixRoot: paths.prefixURL(for: profile.id),
            cacheRoot: paths.cacheURL(for: profile.id)
        )

        return try LaunchCommandBuilder.make(
            plan: plan,
            runtime: installed.descriptor,
            runtimeRoot: installed.rootURL,
            context: context
        )
    }
}

public enum ManagedLauncherBootstrapError: Error, Equatable, CustomStringConvertible {
    case wrongAcquisitionKind
    case compatibilityRuntimeRequired

    public var description: String {
        switch self {
        case .wrongAcquisitionKind: return "Profile does not use managed launcher acquisition"
        case .compatibilityRuntimeRequired: return "Managed launcher bootstrap requires a compatibility runtime"
        }
    }
}
