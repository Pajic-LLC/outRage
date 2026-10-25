import Foundation
import Testing
@testable import OutRageKit

@Test func profilePathMappingsCanDescribeDefaultInstallRedirects() throws {
    let mapping = RuntimePathMapping(
        sourceScope: .target,
        source: ".",
        destinationScope: .prefix,
        destination: "drive_c/Program Files/Example/Target"
    )
    let profile = RuntimeProfile(
        id: "mapped-target",
        displayName: "Mapped Target",
        bundleIdentifier: "com.pajic.mapped-target",
        executable: "target.exe",
        pathMappings: [mapping]
    )

    try profile.validate()
    #expect(profile.pathMappings == [mapping])
}

@Test func profilePathMappingsRejectTraversal() {
    let profile = RuntimeProfile(
        id: "bad-mapping",
        displayName: "Bad Mapping",
        bundleIdentifier: "com.pajic.bad-mapping",
        executable: "target.exe",
        pathMappings: [
            RuntimePathMapping(
                sourceScope: .target,
                destinationScope: .prefix,
                destination: "../outside"
            )
        ]
    )

    #expect(throws: RuntimeDescriptorError.self) {
        try profile.validate()
    }
}
