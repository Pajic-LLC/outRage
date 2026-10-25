import Foundation

public enum RuntimeToolCommandBuilder {
    public static func make(
        runtime: RuntimeDescriptor,
        runtimeRoot: URL,
        command: RuntimeCommandDescriptor,
        cpu: CPUBackend,
        graphics: GraphicsBackend,
        context: RuntimeLaunchContext
    ) throws -> LaunchCommand {
        try runtime.validate()
        try command.validate()

        guard runtime.supportedCPUBackends.contains(cpu) else {
            throw BackendResolverError.unsupportedCPU(cpu)
        }
        guard runtime.supportedGraphicsBackends.contains(graphics) else {
            throw BackendResolverError.unsupportedGraphics(graphics)
        }

        let toolURL = runtimeRoot.appendingPathComponent(command.executable)
        let arguments = context.expanding(command.arguments)

        var rawEnvironment = runtime.environment
        runtime.configuration(for: cpu)?.environment?.forEach { rawEnvironment[$0.key] = $0.value }
        runtime.configuration(for: graphics)?.environment?.forEach { rawEnvironment[$0.key] = $0.value }
        command.environment.forEach { rawEnvironment[$0.key] = $0.value }
        var environment = context.expanding(rawEnvironment)
        environment["OUTRAGE_CPU_BACKEND"] = cpu.rawValue
        environment["OUTRAGE_GRAPHICS_BACKEND"] = graphics.rawValue
        environment["OUTRAGE_RUNTIME_ROOT"] = context.runtimeRoot.path
        environment["OUTRAGE_TARGET_ROOT"] = context.targetRoot.path
        environment["OUTRAGE_PREFIX_ROOT"] = context.prefixRoot.path
        environment["OUTRAGE_CACHE_ROOT"] = context.cacheRoot.path

        if cpu == .rosetta {
            return LaunchCommand(
                executableURL: URL(fileURLWithPath: "/usr/bin/arch"),
                arguments: ["-x86_64", toolURL.path] + arguments,
                workingDirectoryURL: context.prefixRoot,
                environment: environment,
                graphics: graphics
            )
        }

        return LaunchCommand(
            executableURL: toolURL,
            arguments: arguments,
            workingDirectoryURL: context.prefixRoot,
            environment: environment,
            graphics: graphics
        )
    }
}
