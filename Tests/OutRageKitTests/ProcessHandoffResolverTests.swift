import Testing
@testable import OutRageKit

@Test func processHandoffPrefersTargetDescendantOfLauncher() {
    let snapshots = [
        ProcessSnapshot(pid: 10, parentPID: 1, command: "/runtime/wine Launcher.exe"),
        ProcessSnapshot(pid: 11, parentPID: 10, command: "/runtime/wine Helper.exe"),
        ProcessSnapshot(pid: 12, parentPID: 11, command: "/runtime/wine Target.exe"),
        ProcessSnapshot(pid: 50, parentPID: 1, command: "/runtime/wine Target.exe")
    ]

    let selected = ProcessHandoffResolver.selectTarget(
        commandContains: "Target.exe",
        launcherPID: 10,
        excluding: [],
        snapshots: snapshots
    )

    #expect(selected?.pid == 12)
}

@Test func processHandoffIgnoresBaselineProcesses() {
    let snapshots = [
        ProcessSnapshot(pid: 20, parentPID: 1, command: "/runtime/wine Target.exe"),
        ProcessSnapshot(pid: 21, parentPID: 1, command: "/runtime/wine Target.exe")
    ]

    let selected = ProcessHandoffResolver.selectTarget(
        commandContains: "Target.exe",
        launcherPID: nil,
        excluding: [20],
        snapshots: snapshots
    )

    #expect(selected?.pid == 21)
}

@Test func processHandoffNeverReturnsLauncherWhenItsArgumentsMentionTarget() {
    let snapshots = [
        ProcessSnapshot(
            pid: 30,
            parentPID: 1,
            command: "/runtime/wine Launcher.exe --launch Target.exe"
        )
    ]

    let selected = ProcessHandoffResolver.selectTarget(
        commandContains: "Target.exe",
        launcherPID: 30,
        excluding: [],
        snapshots: snapshots
    )

    #expect(selected == nil)
}
