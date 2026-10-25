import Foundation

public enum AcquisitionKind: String, Codable, Sendable {
    case managedLauncher
    case steam
    case importExisting
}

public struct AcquisitionDescriptor: Codable, Equatable, Sendable {
    public var kind: AcquisitionKind
    public var productIdentifier: String?
    public var installerURL: URL?
    public var installerSHA256: String?
    public var installerArguments: [String]?
    public var managedLauncherExecutable: String?
    public var managedLauncherDisplayName: String?
    public var managedLauncherArguments: [String]?
    public var targetBootstrapExecutable: String?
    public var targetBootstrapArguments: [String]?
    public var steamAppID: Int?
    public var steamBranch: String?

    public init(
        kind: AcquisitionKind,
        productIdentifier: String? = nil,
        installerURL: URL? = nil,
        installerSHA256: String? = nil,
        installerArguments: [String]? = nil,
        managedLauncherExecutable: String? = nil,
        managedLauncherDisplayName: String? = nil,
        managedLauncherArguments: [String]? = nil,
        targetBootstrapExecutable: String? = nil,
        targetBootstrapArguments: [String]? = nil,
        steamAppID: Int? = nil,
        steamBranch: String? = nil
    ) {
        self.kind = kind
        self.productIdentifier = productIdentifier
        self.installerURL = installerURL
        self.installerSHA256 = installerSHA256
        self.installerArguments = installerArguments
        self.managedLauncherExecutable = managedLauncherExecutable
        self.managedLauncherDisplayName = managedLauncherDisplayName
        self.managedLauncherArguments = managedLauncherArguments
        self.targetBootstrapExecutable = targetBootstrapExecutable
        self.targetBootstrapArguments = targetBootstrapArguments
        self.steamAppID = steamAppID
        self.steamBranch = steamBranch
    }

    public func validate() throws {
        switch kind {
        case .managedLauncher:
            guard let installerURL else { throw AcquisitionError.installerURLRequired }
            guard installerURL.isFileURL || installerURL.scheme?.lowercased() == "https" else {
                throw AcquisitionError.insecureInstallerURL
            }
            if let installerSHA256,
               installerSHA256.range(of: #"^[a-fA-F0-9]{64}$"#, options: .regularExpression) == nil {
                throw AcquisitionError.invalidInstallerSHA256
            }
            if let managedLauncherExecutable,
               !Self.isManagedRelativePath(managedLauncherExecutable) {
                throw AcquisitionError.invalidManagedLauncherExecutable(managedLauncherExecutable)
            }
            if let targetBootstrapExecutable,
               !Self.isManagedRelativePath(targetBootstrapExecutable) {
                throw AcquisitionError.invalidTargetBootstrapExecutable(targetBootstrapExecutable)
            }
        case .steam:
            guard let steamAppID, steamAppID > 0 else { throw AcquisitionError.steamAppIDRequired }
        case .importExisting:
            break
        }
    }

    private static func isManagedRelativePath(_ value: String) -> Bool {
        !value.isEmpty && !value.hasPrefix("/") && !value.split(separator: "/").contains("..")
    }
}

public enum AcquisitionAction: Equatable, Sendable {
    case managedLauncher(
        sourceURL: URL,
        expectedSHA256: String?,
        installerDestinationURL: URL,
        installerArguments: [String],
        installedLauncherURL: URL?,
        launcherArguments: [String],
        targetRoot: URL
    )
    case steam(appID: Int, branch: String?, targetRoot: URL)
    case importExisting(targetRoot: URL)
}

public enum AcquisitionPlanner {
    public static func makePlan(
        profile: RuntimeProfile,
        paths: RuntimePaths = RuntimePaths()
    ) throws -> AcquisitionAction {
        guard let acquisition = profile.acquisition else {
            throw AcquisitionError.notConfigured
        }
        try acquisition.validate()

        let targetRoot = paths.targetURL(for: profile.id)
        switch acquisition.kind {
        case .managedLauncher:
            guard let sourceURL = acquisition.installerURL else {
                throw AcquisitionError.installerURLRequired
            }
            let installerDestination = paths.cacheURL(for: profile.id)
                .appendingPathComponent("bootstrap-installer.exe")
            let installedLauncherURL = acquisition.managedLauncherExecutable.map {
                paths.prefixURL(for: profile.id).appendingPathComponent($0)
            }
            return .managedLauncher(
                sourceURL: sourceURL,
                expectedSHA256: acquisition.installerSHA256,
                installerDestinationURL: installerDestination,
                installerArguments: acquisition.installerArguments ?? [],
                installedLauncherURL: installedLauncherURL,
                launcherArguments: acquisition.managedLauncherArguments ?? [],
                targetRoot: targetRoot
            )
        case .steam:
            guard let appID = acquisition.steamAppID else {
                throw AcquisitionError.steamAppIDRequired
            }
            return .steam(
                appID: appID,
                branch: acquisition.steamBranch,
                targetRoot: targetRoot
            )
        case .importExisting:
            return .importExisting(targetRoot: targetRoot)
        }
    }
}

public enum AcquisitionError: Error, Equatable, CustomStringConvertible {
    case notConfigured
    case installerURLRequired
    case insecureInstallerURL
    case invalidInstallerSHA256
    case invalidManagedLauncherExecutable(String)
    case invalidTargetBootstrapExecutable(String)
    case steamAppIDRequired

    public var description: String {
        switch self {
        case .notConfigured: return "No acquisition method is configured"
        case .installerURLRequired: return "Managed launcher acquisition requires an installer URL"
        case .insecureInstallerURL: return "Managed launcher installer URL must use HTTPS"
        case .invalidInstallerSHA256: return "Installer SHA-256 must be 64 hexadecimal characters"
        case .invalidManagedLauncherExecutable(let value): return "Managed launcher executable must use a relative prefix path: \(value)"
        case .invalidTargetBootstrapExecutable(let value): return "Target bootstrap executable must use a relative target path: \(value)"
        case .steamAppIDRequired: return "Steam acquisition requires a valid app identifier"
        }
    }
}
