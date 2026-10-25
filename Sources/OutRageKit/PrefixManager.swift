import Foundation

public struct PrefixState: Codable, Equatable, Sendable {
    public var runtimeIdentifier: String
    public var runtimeRevision: Int

    public init(runtimeIdentifier: String, runtimeRevision: Int) {
        self.runtimeIdentifier = runtimeIdentifier
        self.runtimeRevision = runtimeRevision
    }
}

public enum PrefixManager {
    public static func ensureInitialized(
        runtime: RuntimeDescriptor,
        runtimeRoot: URL,
        cpu: CPUBackend,
        graphics: GraphicsBackend,
        context: RuntimeLaunchContext,
        logURL: URL? = nil,
        fileManager: FileManager = .default
    ) throws {
        guard let initializer = runtime.prefixInitializer else { return }

        try fileManager.createDirectory(at: context.prefixRoot, withIntermediateDirectories: true)
        let markerURL = context.prefixRoot.appendingPathComponent(".outrage-prefix.json")
        let desiredState = PrefixState(
            runtimeIdentifier: runtime.id,
            runtimeRevision: runtime.revision ?? 1
        )

        if let data = try? Data(contentsOf: markerURL),
           let state = try? JSONDecoder().decode(PrefixState.self, from: data),
           state == desiredState {
            return
        }

        let command = try RuntimeToolCommandBuilder.make(
            runtime: runtime,
            runtimeRoot: runtimeRoot,
            command: initializer,
            cpu: cpu,
            graphics: graphics,
            context: context
        )
        let running = try ProcessRunner.start(
            command,
            outputURL: logURL,
            fileManager: fileManager
        )
        running.waitUntilExit()
        guard running.terminationStatus == 0 else {
            throw PrefixManagerError.initializerFailed(running.terminationStatus)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(desiredState).write(to: markerURL, options: .atomic)
    }
}

public enum PrefixManagerError: Error, Equatable, CustomStringConvertible {
    case initializerFailed(Int32)

    public var description: String {
        switch self {
        case .initializerFailed(let status):
            return "Runtime prefix initialization failed with status \(status)"
        }
    }
}
