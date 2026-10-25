import Testing
@testable import OutRageKit

@Test func processMatchDefaultsToExecutableName() throws {
    let profile = RuntimeProfile(
        id: "handoff-default",
        displayName: "Handoff Default",
        bundleIdentifier: "com.pajic.handoff-default",
        executable: "bin/Target.exe"
    )

    try profile.validate()
    #expect(profile.resolvedProcessMatch == "Target.exe")
}

@Test func processMatchCanOverrideExecutableName() throws {
    let profile = RuntimeProfile(
        id: "handoff-custom",
        displayName: "Handoff Custom",
        bundleIdentifier: "com.pajic.handoff-custom",
        executable: "bin/Target.exe",
        processMatch: "target-runtime --product 42"
    )

    try profile.validate()
    #expect(profile.resolvedProcessMatch == "target-runtime --product 42")
}

@Test func processMatchRejectsMultilineValues() {
    let profile = RuntimeProfile(
        id: "handoff-invalid",
        displayName: "Handoff Invalid",
        bundleIdentifier: "com.pajic.handoff-invalid",
        executable: "Target.exe",
        processMatch: "Target.exe\nother"
    )

    #expect(throws: ProfileValidationError.invalidProcessMatch("Target.exe\nother")) {
        try profile.validate()
    }
}
