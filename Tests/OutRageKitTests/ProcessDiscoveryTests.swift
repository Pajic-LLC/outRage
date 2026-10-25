import Foundation
import Testing
@testable import OutRageKit

@Test func processDiscoveryDrainsOutputLargerThanPipeCapacity() throws {
    let snapshots = try ProcessDiscovery.snapshots(
        executableURL: URL(fileURLWithPath: "/usr/bin/awk"),
        arguments: ["BEGIN { for (i = 1; i <= 20000; i++) print i, 1, \"/runtime/Launcher.exe\" }"]
    )
    #expect(snapshots.count == 20000)
    #expect(snapshots.last?.pid == 20000)
    #expect(snapshots.last?.command == "/runtime/Launcher.exe")
}

@Test func processDiscoveryParsesAndFindsDescendants() {
    let output = """
      100     1 /runtime/wine Launcher.exe
      101   100 /runtime/wine helper.exe
      102   101 /runtime/wine Target.exe
      200     1 /usr/bin/other
    """

    let snapshots = ProcessDiscovery.parse(output)
    #expect(snapshots.count == 4)

    let descendants = ProcessDiscovery.descendants(of: 100, in: snapshots)
    #expect(Set(descendants.map(\.pid)) == Set([101, 102]))
    #expect(descendants.first(where: { $0.pid == 102 })?.command.contains("Target.exe") == true)
}
