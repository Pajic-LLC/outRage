import Foundation

#if canImport(Metal)
import Metal
#endif

public struct HostCapabilities: Equatable, Sendable {
    public let architecture: String
    public let operatingSystemVersion: String
    public let hasMetal: Bool
    public let hasRosetta: Bool
    public let physicalMemory: UInt64
    public let metalDeviceName: String?
    public let metalRecommendedMaxWorkingSetSize: UInt64?
    public let hasUnifiedMemory: Bool?

    public init(
        architecture: String,
        operatingSystemVersion: String,
        hasMetal: Bool,
        hasRosetta: Bool,
        physicalMemory: UInt64 = 0,
        metalDeviceName: String? = nil,
        metalRecommendedMaxWorkingSetSize: UInt64? = nil,
        hasUnifiedMemory: Bool? = nil
    ) {
        self.architecture = architecture
        self.operatingSystemVersion = operatingSystemVersion
        self.hasMetal = hasMetal
        self.hasRosetta = hasRosetta
        self.physicalMemory = physicalMemory
        self.metalDeviceName = metalDeviceName
        self.metalRecommendedMaxWorkingSetSize = metalRecommendedMaxWorkingSetSize
        self.hasUnifiedMemory = hasUnifiedMemory
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
        let device = MTLCreateSystemDefaultDevice()
        let hasMetal = device != nil
        let deviceName = device?.name
        let workingSet = device?.recommendedMaxWorkingSetSize
        let unifiedMemory = device?.hasUnifiedMemory
        #else
        let hasMetal = false
        let deviceName: String? = nil
        let workingSet: UInt64? = nil
        let unifiedMemory: Bool? = nil
        #endif

        return HostCapabilities(
            architecture: architecture,
            operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            hasMetal: hasMetal,
            hasRosetta: Self.detectRosetta(architecture: architecture),
            physicalMemory: ProcessInfo.processInfo.physicalMemory,
            metalDeviceName: deviceName,
            metalRecommendedMaxWorkingSetSize: workingSet,
            hasUnifiedMemory: unifiedMemory
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
