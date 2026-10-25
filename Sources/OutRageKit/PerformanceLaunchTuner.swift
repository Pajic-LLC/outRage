import Foundation

public enum PerformanceLaunchTuner {
    public static func tune(
        _ command: LaunchCommand,
        cache: RuntimeCacheLocation
    ) -> LaunchCommand {
        var environment = command.environment
        environment["OUTRAGE_BUILD_CACHE_ROOT"] = cache.rootURL.path
        environment["OUTRAGE_SHADER_CACHE_PATH"] = cache.shaderURL.path

        switch command.graphics {
        case .dxmt:
            environment["DXMT_SHADER_CACHE_PATH"] = cache.shaderURL.path
        case .auto, .metal, .d3dMetal, .dxvk, .vkd3d:
            break
        }

        return LaunchCommand(
            executableURL: command.executableURL,
            arguments: command.arguments,
            workingDirectoryURL: command.workingDirectoryURL,
            environment: environment,
            graphics: command.graphics
        )
    }
}
