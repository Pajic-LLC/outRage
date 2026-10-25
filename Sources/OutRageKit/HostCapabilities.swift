import Foundation

#if canImport(Metal)
import Metal
#endif

public struct HostCapabilities: Equatable, Sendable {
    public let architecture: String
    public let operatingSystemVersion: String
    public let hasMetal: Bool
    public let hasRosetta: Bool

    public init(
        architecture: String,
        operatingSystemVersion: String,
        hasMetal: Bool,
        hasRosetta: Bool
    ) {
        self.architecture = architecture
        self.operatingSystemVersion = operatingSystemVersion
        self.hasMetal = hasMetal
        self.hasRosetta = hasRosetta
    }

    public static func current() -> HostCapabilities {
        #if arch(arm64)
        let architecture = "arm64"
        #elseif arch(x86_64)
        let architecture = "x86_64"
        #else
        let architecture = "unknown"
        #endif

        #if canImport(Metal)
        let hasMetal = MTLCreateSystemDefaultDevice() != nil
        #else
        let hasMetal = false
        #endif

        return HostCapabilities(
            architecture: architecture,
            operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            hasMetal: hasMetal,
            hasRosetta: Self.detectRosetta(architecture: architecture)
        )
    }

    public var recommendedCPUBackend: CPUBackend {
        if architecture == "arm64", hasRosetta {
            return .rosetta
        }
        return .native
    }

    private static func detectRosetta(architecture: String) -> Bool {
        #if os(macOS)
        guard architecture == "arm64" else { return false }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/arch")
        process.arguments = ["-x86_64", "/usr/bin/true"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
        #else
        return false
        #endif
    }
}
