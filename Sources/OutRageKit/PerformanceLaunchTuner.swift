import Foundation

public enum PerformanceLaunchTuner {
    public static func tune(
        _ command: LaunchCommand,
        cache: RuntimeCacheLocation,
        policy: PerformancePolicy? = nil,
        explicitEnvironment: [String: String] = [:]
    ) -> LaunchCommand {
        var environment = command.environment
        environment["OUTRAGE_BUILD_CACHE_ROOT"] = cache.rootURL.path
        environment["OUTRAGE_SHADER_CACHE_PATH"] = cache.shaderURL.path

        switch command.graphics {
        case .dxmt:
            environment["DXMT_SHADER_CACHE_PATH"] = cache.shaderURL.path
            applyDXMTPolicy(
                policy,
                explicitEnvironment: explicitEnvironment,
                environment: &environment
            )
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

    private static func applyDXMTPolicy(
        _ policy: PerformancePolicy?,
        explicitEnvironment: [String: String],
        environment: inout [String: String]
    ) {
        guard let policy else { return }

        // A profile-authored DXMT_CONFIG is authoritative. Typed policy only
        // augments runtime defaults when the title has not supplied raw config.
        if explicitEnvironment["DXMT_CONFIG"] == nil {
            var directives: [String] = []
            if let preferredMaxFrameRate = policy.preferredMaxFrameRate {
                directives.append("d3d11.preferredMaxFrameRate=\(preferredMaxFrameRate)")
            }
            if let factor = policy.metalFXSpatialUpscaleFactor {
                directives.append("d3d11.metalSpatialUpscaleFactor=\(format(factor))")
            }

            if !directives.isEmpty {
                let existing = environment["DXMT_CONFIG"]?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let prefix: String
                if existing.isEmpty {
                    prefix = ""
                } else {
                    prefix = existing.hasSuffix(";") ? existing : existing + ";"
                }
                environment["DXMT_CONFIG"] = prefix + directives.joined(separator: ";") + ";"
            }
        }

        if explicitEnvironment["DXMT_METALFX_SPATIAL_SWAPCHAIN"] == nil,
           let enabled = policy.metalFXSpatialUpscaling {
            environment["DXMT_METALFX_SPATIAL_SWAPCHAIN"] = enabled ? "1" : "0"
        }
    }

    private static func format(_ value: Double) -> String {
        var result = String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), value)
        while result.contains(".") && result.last == "0" {
            result.removeLast()
        }
        if result.last == "." {
            result.removeLast()
        }
        return result
    }
}
