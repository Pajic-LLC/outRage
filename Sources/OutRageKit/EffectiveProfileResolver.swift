import Foundation

public enum EffectiveProfileResolver {
    public static func resolve(
        bundledProfileURL: URL,
        paths: RuntimePaths = RuntimePaths(),
        fileManager: FileManager = .default
    ) throws -> RuntimeProfile {
        let bundled = try ProfileLoader.load(from: bundledProfileURL)
        let overrideURL = paths.profilesURL.appendingPathComponent(bundled.id + ".json")

        guard fileManager.fileExists(atPath: overrideURL.path) else {
            return bundled
        }

        do {
            let override = try ProfileLoader.load(from: overrideURL)
            guard override.id == bundled.id else {
                throw EffectiveProfileError.profileIDMismatch(
                    expected: bundled.id,
                    actual: override.id
                )
            }
            guard override.bundleIdentifier == bundled.bundleIdentifier else {
                throw EffectiveProfileError.bundleIdentifierMismatch(
                    expected: bundled.bundleIdentifier,
                    actual: override.bundleIdentifier
                )
            }
            return override
        } catch {
            // Keep the embedded profile as the last known-good local fallback.
            return bundled
        }
    }
}

public enum EffectiveProfileError: Error, Equatable, CustomStringConvertible {
    case profileIDMismatch(expected: String, actual: String)
    case bundleIdentifierMismatch(expected: String, actual: String)

    public var description: String {
        switch self {
        case .profileIDMismatch(let expected, let actual):
            return "Profile override id mismatch: expected \(expected), found \(actual)"
        case .bundleIdentifierMismatch(let expected, let actual):
            return "Profile override bundle id mismatch: expected \(expected), found \(actual)"
        }
    }
}
