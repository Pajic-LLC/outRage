import Testing
@testable import OutRageKit

@Test func rosettaInstallerUsesSystemSoftwareUpdateWithExplicitConsent() {
    let command = RosettaInstaller.command
    #expect(command.executableURL.path == "/usr/sbin/softwareupdate")
    #expect(command.arguments == ["--install-rosetta", "--agree-to-license"])
}
