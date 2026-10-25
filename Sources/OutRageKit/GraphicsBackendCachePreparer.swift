import Foundation

public enum GraphicsBackendCachePreparer {
    public static func prepare(
        graphics: GraphicsBackend,
        context: RuntimeLaunchContext,
        fileManager: FileManager = .default
    ) throws {
        try fileManager.createDirectory(
            at: context.cacheRoot,
            withIntermediateDirectories: true
        )

        switch graphics {
        case .dxmt:
            for relative in ["dxmt-shaders", "dxmt-logs"] {
                try fileManager.createDirectory(
                    at: context.cacheRoot.appendingPathComponent(relative, isDirectory: true),
                    withIntermediateDirectories: true
                )
            }
        case .auto, .metal, .d3dMetal, .dxvk, .vkd3d:
            break
        }
    }
}
