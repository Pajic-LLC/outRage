import Foundation

public struct RuntimePaths: Sendable {
    public let baseURL: URL

    public init(baseURL: URL = Self.defaultBaseURL()) {
        self.baseURL = baseURL
    }

    public var runtimesURL: URL { baseURL.appendingPathComponent("Runtimes", isDirectory: true) }
    public var profilesURL: URL { baseURL.appendingPathComponent("Profiles", isDirectory: true) }
    public var targetsURL: URL { baseURL.appendingPathComponent("Targets", isDirectory: true) }
    public var cacheURL: URL { baseURL.appendingPathComponent("Cache", isDirectory: true) }
    public var logsURL: URL { baseURL.appendingPathComponent("Logs", isDirectory: true) }

    public func targetURL(for profileID: String) -> URL {
        targetsURL.appendingPathComponent(profileID, isDirectory: true)
    }

    public func ensureDirectories(fileManager: FileManager = .default) throws {
        for url in [baseURL, runtimesURL, profilesURL, targetsURL, cacheURL, logsURL] {
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
