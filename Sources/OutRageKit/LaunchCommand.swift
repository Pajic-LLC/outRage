import Foundation

public struct LaunchCommand: Equatable, Sendable, CustomStringConvertible {
    public let executableURL: URL
    public let arguments: [String]
    public let workingDirectoryURL: URL
    public let environment: [String: String]
    public let graphics: GraphicsBackend

    public var description: String {
        let quoted = ([executableURL.path] + arguments).map(Self.shellQuote).joined(separator: " ")
        return quoted
    }

    private static func shellQuote(_ value: String) -> String {
        if value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil, !value.contains("'") {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

public enum LaunchCommandBuilder {
    public static func make(
        plan: LaunchPlan,
        runtime: RuntimeDescriptor? = nil,
        runtimeRoot: URL? = nil
    ) throws -> LaunchCommand {
        if plan.runtime == .native {
            return LaunchCommand(
                executableURL: plan.executableURL,
                arguments: plan.arguments,
                workingDirectoryURL: plan.workingDirectoryURL,
                environment: plan.environment,
                graphics: plan.graphics
            )
        }

        guard let runtime, let runtimeRoot else {
            throw LaunchCommandError.missingRuntime
        }
        try runtime.validate()

        guard runtime.supportedCPUBackends.contains(plan.cpu) else {
            throw LaunchCommandError.unsupportedCPU(plan.cpu)
        }

        let graphics = try resolveGraphics(plan.graphics, runtime: runtime)
        let runtimeExecutable = runtimeRoot.appendingPathComponent(runtime.executable)
        let runtimeArguments = runtime.argumentPrefix + [plan.executableURL.path] + plan.arguments

        var environment = runtime.environment
        plan.environment.forEach { environment[$0.key] = $0.value }
        environment["OUTRAGE_GRAPHICS_BACKEND"] = graphics.rawValue
        environment["OUTRAGE_CPU_BACKEND"] = plan.cpu.rawValue

        if plan.cpu == .rosetta {
            return LaunchCommand(
                executableURL: URL(fileURLWithPath: "/usr/bin/arch"),
                arguments: ["-x86_64", runtimeExecutable.path] + runtimeArguments,
                workingDirectoryURL: plan.workingDirectoryURL,
                environment: environment,
                graphics: graphics
            )
        }

        return LaunchCommand(
            executableURL: runtimeExecutable,
            arguments: runtimeArguments,
            workingDirectoryURL: plan.workingDirectoryURL,
            environment: environment,
            graphics: graphics
        )
    }

    private static func resolveGraphics(
        _ requested: GraphicsBackend,
        runtime: RuntimeDescriptor
    ) throws -> GraphicsBackend {
        if requested == .auto {
            if let first = runtime.supportedGraphicsBackends.first(where: { $0 != .auto }) {
                return first
            }
            throw LaunchCommandError.noGraphicsBackend
        }
        guard runtime.supportedGraphicsBackends.contains(requested) else {
            throw LaunchCommandError.unsupportedGraphics(requested)
        }
        return requested
    }
}

public enum LaunchCommandError: Error, Equatable, CustomStringConvertible {
    case missingRuntime
    case unsupportedCPU(CPUBackend)
    case unsupportedGraphics(GraphicsBackend)
    case noGraphicsBackend

    public var description: String {
        switch self {
        case .missingRuntime: return "Compatibility launch requires a runtime descriptor and root"
        case .unsupportedCPU(let backend): return "Runtime does not support CPU backend: \(backend.rawValue)"
        case .unsupportedGraphics(let backend): return "Runtime does not support graphics backend: \(backend.rawValue)"
        case .noGraphicsBackend: return "Runtime does not provide a usable graphics backend"
        }
    }
}
