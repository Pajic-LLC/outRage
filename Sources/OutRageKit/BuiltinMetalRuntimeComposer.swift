import Foundation

public struct ComposedRuntime: Equatable, Sendable {
    public let rootURL: URL
    public let descriptor: RuntimeDescriptor

    public init(rootURL: URL, descriptor: RuntimeDescriptor) {
        self.rootURL = rootURL
        self.descriptor = descriptor
    }
}

public enum BuiltinMetalRuntimeComposer {
    public static func compose(
        engineRoot: URL,
        backendRoot: URL,
        runtimeIdentifier: String,
        outputRoot: URL,
        fileManager: FileManager = .default
    ) throws -> ComposedRuntime {
        guard !runtimeIdentifier.isEmpty, !runtimeIdentifier.contains("/") else {
            throw BuiltinMetalRuntimeComposerError.invalidRuntimeIdentifier(runtimeIdentifier)
        }
        guard fileManager.fileExists(atPath: engineRoot.path) else {
            throw BuiltinMetalRuntimeComposerError.engineRootMissing(engineRoot.path)
        }
        guard fileManager.fileExists(atPath: backendRoot.path) else {
            throw BuiltinMetalRuntimeComposerError.backendRootMissing(backendRoot.path)
        }

        if fileManager.fileExists(atPath: outputRoot.path) {
            try fileManager.removeItem(at: outputRoot)
        }
        try copyDirectoryPreservingLayout(from: engineRoot, to: outputRoot)

        let wineExecutable = try chooseEngineExecutable(in: outputRoot, fileManager: fileManager)
        let wineboot = try requireRelativeExecutable(
            candidates: ["bin/wineboot", "bin/wineboot.exe"],
            root: outputRoot,
            fileManager: fileManager
        )

        let unixDirectory = outputRoot.appendingPathComponent("lib/wine/x86_64-unix", isDirectory: true)
        let windowsDirectory = outputRoot.appendingPathComponent("lib/wine/x86_64-windows", isDirectory: true)
        try fileManager.createDirectory(at: unixDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: windowsDirectory, withIntermediateDirectories: true)

        let winemetalSO = try findBackendFile(named: "winemetal.so", under: backendRoot, fileManager: fileManager)
        let winemetalDLL = try findBackendFile(named: "winemetal.dll", under: backendRoot, fileManager: fileManager)
        let d3d11DLL = try findBackendFile(named: "d3d11.dll", under: backendRoot, fileManager: fileManager)
        let dxgiDLL = try findBackendFile(named: "dxgi.dll", under: backendRoot, fileManager: fileManager)
        let d3d10coreDLL = try? findBackendFile(named: "d3d10core.dll", under: backendRoot, fileManager: fileManager)

        try replaceFile(winemetalSO, at: unixDirectory.appendingPathComponent("winemetal.so"), fileManager: fileManager)
        try replaceFile(winemetalDLL, at: windowsDirectory.appendingPathComponent("winemetal.dll"), fileManager: fileManager)
        try replaceFile(d3d11DLL, at: windowsDirectory.appendingPathComponent("d3d11.dll"), fileManager: fileManager)
        try replaceFile(dxgiDLL, at: windowsDirectory.appendingPathComponent("dxgi.dll"), fileManager: fileManager)
        if let d3d10coreDLL {
            try replaceFile(d3d10coreDLL, at: windowsDirectory.appendingPathComponent("d3d10core.dll"), fileManager: fileManager)
        }

        let descriptor = RuntimeDescriptor(
            id: runtimeIdentifier,
            revision: 1,
            executable: wineExecutable,
            environment: [
                "WINEPREFIX": "${PREFIX_ROOT}",
                "WINEDEBUG": "-all",
                "DXMT_SHADER_CACHE_PATH": "${CACHE_ROOT}/dxmt-shaders",
                "DXMT_LOG_PATH": "${CACHE_ROOT}/dxmt-logs",
                "DXMT_LOG_LEVEL": "error",
                "OUTRAGE_TARGET_DRIVE": "O:"
            ],
            prefixInitializer: RuntimeCommandDescriptor(
                executable: wineboot,
                arguments: ["--init"]
            ),
            pathMappings: [
                RuntimePathMapping(
                    sourceScope: .target,
                    source: ".",
                    destinationScope: .prefix,
                    destination: "dosdevices/o:"
                )
            ],
            supportedCPUBackends: [.rosetta],
            supportedGraphicsBackends: [.dxmt],
            graphicsConfigurations: [
                "dxmt": RuntimeBackendConfiguration(
                    fileMappings: [
                        RuntimeFileMapping(
                            source: "lib/wine/x86_64-windows/winemetal.dll",
                            destinationScope: .prefix,
                            destination: "drive_c/windows/system32/winemetal.dll",
                            mode: .symlink
                        )
                    ]
                )
            ]
        )
        try descriptor.validate()

        let descriptorURL = outputRoot.appendingPathComponent("runtime.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(descriptor).write(to: descriptorURL, options: .atomic)

        return ComposedRuntime(rootURL: outputRoot, descriptor: descriptor)
    }

    private static func chooseEngineExecutable(
        in root: URL,
        fileManager: FileManager
    ) throws -> String {
        try requireRelativeExecutable(
            candidates: ["bin/wine64", "bin/wine"],
            root: root,
            fileManager: fileManager
        )
    }

    private static func requireRelativeExecutable(
        candidates: [String],
        root: URL,
        fileManager: FileManager
    ) throws -> String {
        for candidate in candidates {
            let url = root.appendingPathComponent(candidate)
            if fileManager.isExecutableFile(atPath: url.path) {
                return candidate
            }
        }
        throw BuiltinMetalRuntimeComposerError.engineExecutableMissing(candidates)
    }

    private static func findBackendFile(
        named name: String,
        under root: URL,
        fileManager: FileManager
    ) throws -> URL {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw BuiltinMetalRuntimeComposerError.backendFileMissing(name)
        }

        var candidates: [URL] = []
        for case let url as URL in enumerator where url.lastPathComponent.caseInsensitiveCompare(name) == .orderedSame {
            candidates.append(url)
        }
        guard !candidates.isEmpty else {
            throw BuiltinMetalRuntimeComposerError.backendFileMissing(name)
        }

        return candidates.sorted { lhs, rhs in
            let lhsScore = architectureScore(lhs.path)
            let rhsScore = architectureScore(rhs.path)
            if lhsScore != rhsScore { return lhsScore > rhsScore }
            return lhs.path.count < rhs.path.count
        }.first!
    }

    private static func architectureScore(_ path: String) -> Int {
        let lower = path.lowercased()
        if lower.contains("x86_64") || lower.contains("x64") || lower.contains("win64") { return 3 }
        if lower.contains("arm64") || lower.contains("aarch64") { return 2 }
        if lower.contains("i386") || lower.contains("x86") || lower.contains("win32") { return 0 }
        return 1
    }

    private static func replaceFile(
        _ source: URL,
        at destination: URL,
        fileManager: FileManager
    ) throws {
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
    }

    private static func copyDirectoryPreservingLayout(from source: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = [source.path, destination.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw BuiltinMetalRuntimeComposerError.copyFailed(process.terminationStatus)
        }
    }
}

public enum BuiltinMetalRuntimeComposerError: Error, Equatable, CustomStringConvertible {
    case invalidRuntimeIdentifier(String)
    case engineRootMissing(String)
    case backendRootMissing(String)
    case engineExecutableMissing([String])
    case backendFileMissing(String)
    case copyFailed(Int32)

    public var description: String {
        switch self {
        case .invalidRuntimeIdentifier(let value): return "Invalid runtime identifier: \(value)"
        case .engineRootMissing(let path): return "Engine root does not exist: \(path)"
        case .backendRootMissing(let path): return "Backend root does not exist: \(path)"
        case .engineExecutableMissing(let paths): return "No compatible engine executable found: \(paths.joined(separator: ", "))"
        case .backendFileMissing(let name): return "Required backend file is missing: \(name)"
        case .copyFailed(let status): return "Runtime composition copy failed with status \(status)"
        }
    }
}
