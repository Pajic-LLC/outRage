import Foundation

public struct ProcessHandoffMonitor: Sendable {
    public typealias SnapshotProvider = @Sendable () throws -> [ProcessSnapshot]
    public typealias Sleeper = @Sendable (Duration) async throws -> Void

    private let snapshotProvider: SnapshotProvider
    private let sleeper: Sleeper

    public init(
        snapshotProvider: @escaping SnapshotProvider = { try ProcessDiscovery.snapshots() },
        sleeper: @escaping Sleeper = { duration in try await Task.sleep(for: duration) }
    ) {
        self.snapshotProvider = snapshotProvider
        self.sleeper = sleeper
    }

    public func baselinePIDs(commandContains needle: String) throws -> Set<Int32> {
        let normalized = needle.lowercased()
        return Set(try snapshotProvider()
            .filter { $0.command.lowercased().contains(normalized) }
            .map(\.pid))
    }

    public func waitForTarget(
        commandContains needle: String,
        launcherPID: Int32?,
        excluding baselinePIDs: Set<Int32>,
        timeout: Duration = .seconds(90),
        pollInterval: Duration = .milliseconds(250)
    ) async throws -> ProcessSnapshot {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while clock.now < deadline {
            let snapshots = try snapshotProvider()
            if let target = ProcessHandoffResolver.selectTarget(
                commandContains: needle,
                launcherPID: launcherPID,
                excluding: baselinePIDs,
                snapshots: snapshots
            ) {
                return target
            }
            try await sleeper(pollInterval)
        }

        throw ProcessHandoffMonitorError.targetNotFound(needle)
    }

    public func waitUntilExit(
        pid: Int32,
        pollInterval: Duration = .milliseconds(500)
    ) async throws {
        while try snapshotProvider().contains(where: { $0.pid == pid }) {
            try await sleeper(pollInterval)
        }
    }
}

public enum ProcessHandoffMonitorError: Error, Equatable, CustomStringConvertible {
    case targetNotFound(String)

    public var description: String {
        switch self {
        case .targetNotFound(let needle):
            return "Timed out waiting for target process matching: \(needle)"
        }
    }
}
