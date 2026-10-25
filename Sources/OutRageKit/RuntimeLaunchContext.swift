import Foundation

public struct RuntimeLaunchContext: Equatable, Sendable {
    public let runtimeRoot: URL
    public let targetRoot: URL
    public let prefixRoot: URL
    public let cacheRoot: URL

    public init(
        runtimeRoot: URL,
        targetRoot: URL,
        prefixRoot: URL,
        cacheRoot: URL
    ) {
        self.runtimeRoot = runtimeRoot
        self.targetRoot = targetRoot
        self.prefixRoot = prefixRoot
        self.cacheRoot = cacheRoot
    }

    public var substitutions: [String: String] {
        [
            "${RUNTIME_ROOT}": runtimeRoot.path,
            "${TARGET_ROOT}": targetRoot.path,
            "${PREFIX_ROOT}": prefixRoot.path,
            "${CACHE_ROOT}": cacheRoot.path
        ]
    }

    public func expanding(_ value: String) -> String {
        substitutions.reduce(value) { partial, pair in
            partial.replacingOccurrences(of: pair.key, with: pair.value)
        }
    }

    public func expanding(_ values: [String]) -> [String] {
        values.map(expanding)
    }

    public func expanding(_ values: [String: String]) -> [String: String] {
        values.mapValues(expanding)
    }
}
