import Testing
@testable import OutRageKit

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
