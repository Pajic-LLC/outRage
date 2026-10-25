import Foundation

public enum BackendResolver {
    public static func resolveCPU(
        requested: CPUBackend,
        runtime: RuntimeDescriptor,
        host: HostCapabilities
    ) throws -> CPUBackend {
        if requested != .auto {
            guard runtime.supportedCPUBackends.contains(requested) else {
                throw BackendResolverError.unsupportedCPU(requested)
            }
            return requested
        }

        let preference: [CPUBackend]
        if host.architecture == "arm64" {
            preference = host.hasRosetta
                ? [.rosetta, .fex, .native]
                : [.fex, .native]
        } else {
            preference = [.native, .fex, .rosetta]
        }

        guard let backend = preference.first(where: runtime.supportedCPUBackends.contains) else {
            throw BackendResolverError.noCompatibleCPUBackend
        }
        return backend
    }

    public static func resolveGraphics(
        requested: GraphicsBackend,
        runtime: RuntimeDescriptor,
        hints: [GraphicsAPIHint] = []
    ) throws -> GraphicsBackend {
        if requested != .auto {
            guard runtime.supportedGraphicsBackends.contains(requested) else {
                throw BackendResolverError.unsupportedGraphics(requested)
            }
            return requested
        }

        let preference: [GraphicsBackend]
        if hints.contains(.d3d12) {
            preference = [.d3dMetal, .vkd3d]
        } else if hints.contains(.d3d11) || hints.contains(.d3d10) {
            preference = [.dxmt, .d3dMetal, .dxvk]
        } else if hints.contains(.d3d9) {
            preference = [.dxvk]
        } else {
            preference = [.dxmt, .d3dMetal, .dxvk, .vkd3d, .metal]
        }

        guard let backend = preference.first(where: runtime.supportedGraphicsBackends.contains) else {
            throw BackendResolverError.noCompatibleGraphicsBackend
        }
        return backend
    }
}

public enum BackendResolverError: Error, Equatable, CustomStringConvertible {
    case unsupportedCPU(CPUBackend)
    case unsupportedGraphics(GraphicsBackend)
    case noCompatibleCPUBackend
    case noCompatibleGraphicsBackend

    public var description: String {
        switch self {
        case .unsupportedCPU(let backend): return "Runtime does not support CPU backend: \(backend.rawValue)"
        case .unsupportedGraphics(let backend): return "Runtime does not support graphics backend: \(backend.rawValue)"
        case .noCompatibleCPUBackend: return "Runtime has no CPU backend compatible with this host"
        case .noCompatibleGraphicsBackend: return "Runtime has no compatible graphics backend for this target"
        }
    }
}
