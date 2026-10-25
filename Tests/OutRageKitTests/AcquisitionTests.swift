import Foundation
import Testing
@testable import OutRageKit

@Test func managedLauncherAcquisitionPlansInstallerAndInstalledLauncher() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let paths = RuntimePaths(baseURL: root)
    let profile = RuntimeProfile(
        id: "managed-target",
        displayName: "Managed Target",
        bundleIdentifier: "com.pajic.managed-target",
        executable: "target.exe",
        acquisition: AcquisitionDescriptor(
            kind: .managedLauncher,
            installerURL: URL(string: "https://example.com/installer.exe")!,
            installerArguments: ["/quiet"],
            managedLauncherExecutable: "drive_c/Launcher/Launcher.exe",
            managedLauncherArguments: ["--resume"]
        )
    )

    let plan = try AcquisitionPlanner.makePlan(profile: profile, paths: paths)
    guard case let .managedLauncher(
        source,
        _,
        destination,
        installerArguments,
        launcherURL,
        launcherArguments,
        targetRoot
    ) = plan else {
        Issue.record("Expected managed launcher acquisition")
        return
    }

    #expect(source.absoluteString == "https://example.com/installer.exe")
    #expect(destination == paths.cacheURL(for: profile.id).appendingPathComponent("bootstrap-installer.exe"))
    #expect(installerArguments == ["/quiet"])
    #expect(launcherURL == paths.prefixURL(for: profile.id).appendingPathComponent("drive_c/Launcher/Launcher.exe"))
    #expect(launcherArguments == ["--resume"])
    #expect(targetRoot == paths.targetURL(for: profile.id))
}

@Test func managedLauncherRejectsPrefixTraversal() {
    let acquisition = AcquisitionDescriptor(
        kind: .managedLauncher,
        installerURL: URL(string: "https://example.com/installer.exe")!,
        managedLauncherExecutable: "../escape.exe"
    )

    #expect(throws: AcquisitionError.self) {
        try acquisition.validate()
    }
}

@Test func steamAcquisitionPlansWindowsTarget() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let paths = RuntimePaths(baseURL: root)
    let profile = RuntimeProfile(
        id: "steam-target",
        displayName: "Steam Target",
        bundleIdentifier: "com.pajic.steam-target",
        executable: "target.exe",
        acquisition: AcquisitionDescriptor(
            kind: .steam,
            steamAppID: 12345,
            steamBranch: "public"
        )
    )

    let plan = try AcquisitionPlanner.makePlan(profile: profile, paths: paths)
    guard case let .steam(appID, branch, targetRoot) = plan else {
        Issue.record("Expected Steam acquisition")
        return
    }

    #expect(appID == 12345)
    #expect(branch == "public")
    #expect(targetRoot == paths.targetURL(for: profile.id))
}

@Test func steamCMDCommandNeverEmbedsPassword() throws {
    let target = URL(fileURLWithPath: "/tmp/outRage-steam-target", isDirectory: true)
    let tool = URL(fileURLWithPath: "/tmp/steamcmd")
    let command = try SteamCMDCommandBuilder.makeInstallCommand(
        toolURL: tool,
        request: SteamCMDInstallRequest(
            appID: 12345,
            branch: "beta",
            targetRoot: target,
            username: "pilot"
        )
    )

    #expect(command.arguments.contains("windows"))
    #expect(command.arguments.contains("pilot"))
    #expect(command.arguments.contains("12345"))
    #expect(command.arguments.contains("beta"))
    #expect(!command.arguments.joined(separator: " ").lowercased().contains("password"))
}
