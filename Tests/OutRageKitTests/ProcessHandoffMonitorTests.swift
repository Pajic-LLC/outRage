import Foundation
import Testing
@testable import OutRageKit

@Test func processHandoffMonitorFindsNewTargetAfterLauncherSpawn() async throws {
    actor Feed {
        var snapshots: [[ProcessSnapshot]] = [
            [ProcessSnapshot(pid: 10, parentPID: 1, command: "/runtime/wine Launcher.exe")],
            [
                ProcessSnapshot(pid: 10, parentPID: 1, command: "/runtime/wine Launcher.exe"),
                ProcessSnapshot(pid: 11, parentPID: 10, command: "/runtime/wine Helper.exe"),
                ProcessSnapshot(pid: 12, parentPID: 11, command: "/runtime/wine Target.exe")
            ]
        ]

        func next() -> [ProcessSnapshot] {
            if snapshots.count > 1 { return snapshots.removeFirst() }
            return snapshots[0]
        }
    }

    let feed = Feed()
    let monitor = ProcessHandoffMonitor(
        snapshotProvider: { await feed.next() },
        sleeper: { _ in }
    )

    let target = try await monitor.waitForTarget(
        commandContains: "Target.exe",
        launcherPID: 10,
        excluding: [],
        timeout: .seconds(1),
        pollInterval: .milliseconds(1)
    )

    #expect(target.pid == 12)
}
