import Foundation

public struct DXMTRuntimeSmokeResult: Equatable, Sendable {
    public let runtimeIdentifier: String
    public let loadedModules: Set<String>

    public init(runtimeIdentifier: String, loadedModules: Set<String>) {
        self.runtimeIdentifier = runtimeIdentifier
        self.loadedModules = loadedModules
    }
}

public enum DXMTRuntimeSmokeVerifier {
    private static let requiredModules: Set<String> = [
        "d3d11.dll",
        "dxgi.dll",
        "winemetal.dll"
    ]

    public static func probeCommand(
        runtime: RuntimeDescriptor,
        runtimeRoot: URL,
        cpu: CPUBackend,
        context: RuntimeLaunchContext
    ) throws -> LaunchCommand {
        guard runtime.supportedGraphicsBackends.contains(.dxmt) else {
            throw DXMTRuntimeSmokeError.dxmtUnsupported
        }

        return try RuntimeToolCommandBuilder.make(
            runtime: runtime,
            runtimeRoot: runtimeRoot,
            command: RuntimeCommandDescriptor(
                executable: runtime.executable,
                arguments: ["rundll32", "d3d11.dll,NoSuchEntry"],
                environment: [
                    "WINEDEBUG": "+loaddll,+dxmt",
                    "DXMT_LOG_LEVEL": "info"
                ]
            ),
            cpu: cpu,
            graphics: .dxmt,
            context: context
        )
    }

    public static func evaluate(log: String, runtimeIdentifier: String) throws -> DXMTRuntimeSmokeResult {
        let lower = log.lowercased()
        var loaded: Set<String> = []

        for module in requiredModules {
            let moduleLower = module.lowercased()
            let lines = lower.split(whereSeparator: \Character.isNewline)
            if lines.contains(where: { line in
                line.contains(moduleLower) && line.contains("builtin")
            }) {
                loaded.insert(module)
            }
        }

        let missing = requiredModules.subtracting(loaded)
        guard missing.isEmpty else {
            throw DXMTRuntimeSmokeError.modulesNotLoaded(Array(missing).sorted())
        }

        return DXMTRuntimeSmokeResult(
            runtimeIdentifier: runtimeIdentifier,
            loadedModules: loaded
        )
    }

    public static func run(
        installedRuntime: InstalledRuntime,
        cpu: CPUBackend = .rosetta,
        fileManager: FileManager = .default
    ) throws -> DXMTRuntimeSmokeResult {
        let scratch = fileManager.temporaryDirectory.appendingPathComponent(
            "outRage-dxmt-smoke-" + UUID().uuidString,
            isDirectory: true
        )
        defer { try? fileManager.removeItem(at: scratch) }

        let targetRoot = scratch.appendingPathComponent("Target", isDirectory: true)
        let prefixRoot = scratch.appendingPathComponent("Prefix", isDirectory: true)
        let cacheRoot = scratch.appendingPathComponent("Cache", isDirectory: true)
        let logURL = scratch.appendingPathComponent("dxmt-smoke.log")
        for url in [
            targetRoot,
            prefixRoot,
            cacheRoot,
            cacheRoot.appendingPathComponent("dxmt-shaders", isDirectory: true),
            cacheRoot.appendingPathComponent("dxmt-logs", isDirectory: true)
        ] {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }

        let context = RuntimeLaunchContext(
            runtimeRoot: installedRuntime.rootURL,
            targetRoot: targetRoot,
            prefixRoot: prefixRoot,
            cacheRoot: cacheRoot
        )

        try PrefixManager.ensureInitialized(
            runtime: installedRuntime.descriptor,
            runtimeRoot: installedRuntime.rootURL,
            cpu: cpu,
            graphics: .dxmt,
            context: context,
            logURL: logURL,
            fileManager: fileManager
        )
        try RuntimeOverlayInstaller.apply(
            runtime: installedRuntime.descriptor,
            cpu: cpu,
            graphics: .dxmt,
            context: context,
            fileManager: fileManager
        )

        let command = try probeCommand(
            runtime: installedRuntime.descriptor,
            runtimeRoot: installedRuntime.rootURL,
            cpu: cpu,
            context: context
        )
        let running = try ProcessRunner.start(
            command,
            outputURL: logURL,
            fileManager: fileManager
        )
        running.waitUntilExit()

        let log = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
        return try evaluate(
            log: log,
            runtimeIdentifier: installedRuntime.descriptor.id
        )
    }
}

public enum DXMTRuntimeSmokeError: Error, Equatable, CustomStringConvertible {
    case dxmtUnsupported
    case modulesNotLoaded([String])

    public var description: String {
        switch self {
        case .dxmtUnsupported:
            return "Runtime does not advertise the DXMT graphics backend"
        case .modulesNotLoaded(let modules):
            return "DXMT smoke check did not load builtin modules: \(modules.joined(separator: ", "))"
        }
    }
}
