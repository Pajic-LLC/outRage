import Foundation

public struct PreparedCompatibilityRuntime: Equatable, Sendable {
    public let installedRuntime: InstalledRuntime
    public let cpu: CPUBackend
    public let graphics: GraphicsBackend
    public let context: RuntimeLaunchContext

    public init(
        installedRuntime: InstalledRuntime,
        cpu: CPUBackend,
        graphics: GraphicsBackend,
        context: RuntimeLaunchContext
    ) {
        self.installedRuntime = installedRuntime
        self.cpu = cpu
        self.graphics = graphics
        self.context = context
    }
}

public enum RuntimeEnvironmentPreparer {
    public static func prepare(
        profile: RuntimeProfile,
        executableForProbe: URL? = nil,
        paths: RuntimePaths = RuntimePaths(),
        host: HostCapabilities = .current(),
        fileManager: FileManager = .default
    ) throws -> PreparedCompatibilityRuntime {
        try profile.validate()
        guard profile.runtime == .compatibility else {
            throw RuntimeEnvironmentPreparationError.compatibilityRuntimeRequired
        }

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

        let hints: [GraphicsAPIHint]
        if profile.graphics == .auto,
           let executableForProbe,
           fileManager.fileExists(atPath: executableForProbe.path),
           let result = try? PEProbe.inspect(executableForProbe, fileManager: fileManager) {
            hints = result.graphicsHints
        } else {
            hints = []
        }

        let cpu = try BackendResolver.resolveCPU(
            requested: profile.cpu,
            runtime: installed.descriptor,
            host: host
        )
        let graphics = try BackendResolver.resolveGraphics(
            requested: profile.graphics,
            runtime: installed.descriptor,
            hints: hints
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
        try RuntimePathMapper.apply(
            profile.pathMappings ?? [],
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

        return PreparedCompatibilityRuntime(
            installedRuntime: installed,
            cpu: cpu,
            graphics: graphics,
            context: context
        )
    }
}

public enum RuntimeEnvironmentPreparationError: Error, Equatable, CustomStringConvertible {
    case compatibilityRuntimeRequired

    public var description: String {
        switch self {
        case .compatibilityRuntimeRequired:
            return "Runtime environment preparation requires a compatibility runtime"
        }
    }
}
