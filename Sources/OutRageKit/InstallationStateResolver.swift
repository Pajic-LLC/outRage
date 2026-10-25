import Foundation

public enum InstallationState: Equatable, Sendable {
    case ready
    case runtimeRequired
    case managedLauncherInstallerRequired
    case managedLauncherReady(URL)
    case existingFilesRequired
    case steamAuthenticationRequired(appID: Int)
}

public enum InstallationStateResolver {
    public static func resolve(
        profile: RuntimeProfile,
        paths: RuntimePaths = RuntimePaths(),
        fileManager: FileManager = .default
    ) throws -> InstallationState {
        try profile.validate()

        if profile.runtime == .compatibility {
            let catalog = RuntimeCatalog(runtimesURL: paths.runtimesURL)
            guard (try? catalog.resolve(
                identifier: profile.runtimeIdentifier,
                fileManager: fileManager
            )) != nil else {
                return .runtimeRequired
            }
        }

        if fileManager.fileExists(atPath: paths.executableURL(for: profile).path) {
            return .ready
        }

        guard let acquisition = profile.acquisition else {
            return .existingFilesRequired
        }
        try acquisition.validate()

        switch acquisition.kind {
        case .managedLauncher:
            let action = try AcquisitionPlanner.makePlan(profile: profile, paths: paths)
            guard case let .managedLauncher(_, _, _, _, launcherURL, _, _) = action else {
                return .managedLauncherInstallerRequired
            }
            if let launcherURL,
               fileManager.fileExists(atPath: launcherURL.path) {
                return .managedLauncherReady(launcherURL)
            }
            return .managedLauncherInstallerRequired

        case .importExisting:
            return .existingFilesRequired

        case .steam:
            guard let appID = acquisition.steamAppID else {
                throw AcquisitionError.steamAppIDRequired
            }
            return .steamAuthenticationRequired(appID: appID)
        }
    }
}
