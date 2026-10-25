import Foundation

public enum ProcessHandoffResolver {
    public static func selectTarget(
        commandContains needle: String,
        launcherPID: Int32?,
        excluding baselinePIDs: Set<Int32>,
        snapshots: [ProcessSnapshot]
    ) -> ProcessSnapshot? {
        let normalized = needle.lowercased()
        guard !normalized.isEmpty else { return nil }

        let candidates = snapshots.filter {
            !baselinePIDs.contains($0.pid) &&
            $0.pid != launcherPID &&
            $0.command.lowercased().contains(normalized)
        }
        guard !candidates.isEmpty else { return nil }

        if let launcherPID {
            let descendantPIDs = Set(ProcessDiscovery.descendants(of: launcherPID, in: snapshots).map(\.pid))
            if let descendant = candidates.first(where: { descendantPIDs.contains($0.pid) }) {
                return descendant
            }
        }

        return candidates.min(by: { $0.pid < $1.pid })
    }
}
