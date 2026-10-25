import Foundation

public struct RuntimePaths: Sendable {
    public let baseURL: URL

    public init(baseURL: URL = Self.defaultBaseURL()) {
        self.baseURL = baseURL
    }

    public var runtimesURL: URL { baseURL.appendingPathComponent("Runtimes", isDirectory: true) }
    public var profilesURL: URL { baseURL.appendingPathComponent("Profiles", isDirectory: true) }
    public var targetsURL: URL { baseURL.appendingPathComponent("Targets", isDirectory: true) }
    public var prefixesURL: URL { baseURL.appendingPathComponent("Prefixes", isDirectory: true) }
    public var cacheURL: URL { baseURL.appendingPathComponent("Cache", isDirectory: true) }
    public var runtimePackageCacheURL: URL { cacheURL.appendingPathComponent("RuntimePackages", isDirectory: true) }
    public var logsURL: URL { baseURL.appendingPathComponent("Logs", isDirectory: true) }

    public func targetURL(for profileID: String) -> URL {
        targetsURL.appendingPathComponent(profileID, isDirectory: true)
    }

    public func prefixURL(for profileID: String) -> URL {
        prefixesURL.appendingPathComponent(profileID, isDirectory: true)
    }

    public func executableRootURL(for profile: RuntimeProfile) -> URL {
        switch profile.resolvedExecutableScope {
        case .target: return targetURL(for: profile.id)
        case .prefix: return prefixURL(for: profile.id)
        }
    }

    public func executableURL(for profile: RuntimeProfile) -> URL {
        executableRootURL(for: profile).appendingPathComponent(profile.executable)
    }

    public func cacheURL(for profileID: String) -> URL {
        cacheURL.appendingPathComponent(profileID, isDirectory: true)
    }

    public func runtimePackageArchiveURL(identifier: String, version: String) -> URL {
        let safeVersion = version.replacingOccurrences(of: "/", with: "-")
        return runtimePackageCacheURL.appendingPathComponent("\(identifier)-\(safeVersion).zip")
    }

    public func logURL(for profileID: String) -> URL {
        logsURL.appendingPathComponent(profileID + ".log")
    }

    public func ensureDirectories(fileManager: FileManager = .default) throws {
        for url in [
            baseURL,
            runtimesURL,
            profilesURL,
            targetsURL,
            prefixesURL,
            cacheURL,
            runtimePackageCacheURL,
            logsURL
        ] {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    public func ensureTargetDirectories(for profileID: String, fileManager: FileManager = .default) throws {
        for url in [targetURL(for: profileID), prefixURL(for: profileID), cacheURL(for: profileID)] {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    public static func defaultBaseURL() -> URL {
        #if os(macOS)
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support.appendingPathComponent("outRage", isDirectory: true)
        #else
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".local/share/outRage", isDirectory: true)
        #endif
    }
}
