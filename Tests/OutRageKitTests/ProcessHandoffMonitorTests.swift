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

@Test func processHandoffMonitorOneShotFindsDescendantTarget() throws {
    let monitor = ProcessHandoffMonitor(
        snapshotProvider: {
            [
                ProcessSnapshot(pid: 100, parentPID: 1, command: "/runtime/wine Launcher.exe"),
                ProcessSnapshot(pid: 101, parentPID: 100, command: "/runtime/wine Helper.exe"),
                ProcessSnapshot(pid: 102, parentPID: 101, command: "/runtime/wine Target.exe --started")
            ]
        },
        sleeper: { _ in }
    )

    let target = try monitor.targetIfPresent(
        commandContains: "Target.exe",
        launcherPID: 100,
        excluding: []
    )

    #expect(target?.pid == 102)
}

@Test func processHandoffMonitorOneShotIgnoresPreexistingTarget() throws {
    let monitor = ProcessHandoffMonitor(
        snapshotProvider: {
            [
                ProcessSnapshot(pid: 200, parentPID: 1, command: "/runtime/wine Target.exe"),
                ProcessSnapshot(pid: 210, parentPID: 1, command: "/runtime/wine Launcher.exe")
            ]
        },
        sleeper: { _ in }
    )

    let target = try monitor.targetIfPresent(
        commandContains: "Target.exe",
        launcherPID: 210,
        excluding: [200]
    )

    #expect(target == nil)
}
