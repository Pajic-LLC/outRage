import Foundation

public struct LaunchDiagnostics: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let profileID: String
    public let hostArchitecture: String
    public let operatingSystemVersion: String
    public let physicalMemory: UInt64
    public let metalDeviceName: String?
    public let metalRecommendedMaxWorkingSetSize: UInt64?
    public let unifiedMemory: Bool?
    public let targetArchitecture: PEArchitecture?
    public let targetGraphicsHints: [GraphicsAPIHint]
    public let targetFingerprint: TargetBuildFingerprint?
    public let runtimeIdentifier: String?
    public let runtimeRevision: Int?
    public let cpuBackend: CPUBackend
    public let graphicsBackend: GraphicsBackend
    public let cacheKey: String?

    public init(
        timestamp: Date = Date(),
        profileID: String,
        hostArchitecture: String,
        operatingSystemVersion: String,
        physicalMemory: UInt64,
        metalDeviceName: String?,
        metalRecommendedMaxWorkingSetSize: UInt64?,
        unifiedMemory: Bool?,
        targetArchitecture: PEArchitecture?,
        targetGraphicsHints: [GraphicsAPIHint],
        targetFingerprint: TargetBuildFingerprint?,
        runtimeIdentifier: String?,
        runtimeRevision: Int?,
        cpuBackend: CPUBackend,
        graphicsBackend: GraphicsBackend,
        cacheKey: String?
    ) {
        self.timestamp = timestamp
        self.profileID = profileID
        self.hostArchitecture = hostArchitecture
        self.operatingSystemVersion = operatingSystemVersion
        self.physicalMemory = physicalMemory
        self.metalDeviceName = metalDeviceName
        self.metalRecommendedMaxWorkingSetSize = metalRecommendedMaxWorkingSetSize
        self.unifiedMemory = unifiedMemory
        self.targetArchitecture = targetArchitecture
        self.targetGraphicsHints = targetGraphicsHints
        self.targetFingerprint = targetFingerprint
        self.runtimeIdentifier = runtimeIdentifier
        self.runtimeRevision = runtimeRevision
        self.cpuBackend = cpuBackend
        self.graphicsBackend = graphicsBackend
        self.cacheKey = cacheKey
    }
}

public enum LaunchDiagnosticsBuilder {
    public static func make(
        profile: RuntimeProfile,
        executableURL: URL,
        host: HostCapabilities,
        runtime: RuntimeDescriptor?,
        cpu: CPUBackend,
        graphics: GraphicsBackend,
        fileManager: FileManager = .default
    ) -> LaunchDiagnostics {
        let probe = try? PEProbe.inspect(executableURL, fileManager: fileManager)
        let fingerprint = try? TargetBuildFingerprint.inspect(
            executableURL: executableURL,
            fileManager: fileManager
        )

        let cacheFingerprint: RuntimeCacheFingerprint?
        if let fingerprint, let runtime {
            cacheFingerprint = RuntimeCacheFingerprint(
                profileID: profile.id,
                target: fingerprint,
                runtimeIdentifier: runtime.id,
                runtimeRevision: runtime.revision ?? 1,
                graphicsBackend: graphics
            )
        } else {
            cacheFingerprint = nil
        }

        return LaunchDiagnostics(
            profileID: profile.id,
            hostArchitecture: host.architecture,
            operatingSystemVersion: host.operatingSystemVersion,
            physicalMemory: host.physicalMemory,
            metalDeviceName: host.metalDeviceName,
            metalRecommendedMaxWorkingSetSize: host.metalRecommendedMaxWorkingSetSize,
            unifiedMemory: host.hasUnifiedMemory,
            targetArchitecture: probe?.architecture,
            targetGraphicsHints: probe?.graphicsHints ?? [],
            targetFingerprint: fingerprint,
            runtimeIdentifier: runtime?.id,
            runtimeRevision: runtime?.revision,
            cpuBackend: cpu,
            graphicsBackend: graphics,
            cacheKey: cacheFingerprint?.stableKey
        )
    }

    public static func write(
        _ diagnostics: LaunchDiagnostics,
        to url: URL,
        fileManager: FileManager = .default
    ) throws {
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(diagnostics).write(to: url, options: .atomic)
    }
}
