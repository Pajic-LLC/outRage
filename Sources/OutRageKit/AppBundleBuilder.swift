import Foundation

public struct AppBundleBuilder {
    public init() {}

    @discardableResult
    public func build(
        profile: RuntimeProfile,
        hostExecutable: URL,
        iconURL: URL? = nil,
        outputDirectory: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        try profile.validate()

        let appName = sanitizeFileName(profile.displayName) + ".app"
        let appURL = outputDirectory.appendingPathComponent(appName, isDirectory: true)
        let contents = appURL.appendingPathComponent("Contents", isDirectory: true)
        let macOS = contents.appendingPathComponent("MacOS", isDirectory: true)
        let resources = contents.appendingPathComponent("Resources", isDirectory: true)
        let destinationExecutable = macOS.appendingPathComponent("outRageHost")

        if fileManager.fileExists(atPath: appURL.path) {
            try fileManager.removeItem(at: appURL)
        }

        try fileManager.createDirectory(at: macOS, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: resources, withIntermediateDirectories: true)
        try fileManager.copyItem(at: hostExecutable, to: destinationExecutable)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destinationExecutable.path)

        var iconName: String?
        if let iconURL {
            guard iconURL.pathExtension.lowercased() == "icns",
                  fileManager.fileExists(atPath: iconURL.path) else {
                throw AppBundleBuilderError.invalidIcon(iconURL.path)
            }
            let destinationIcon = resources.appendingPathComponent("AppIcon.icns")
            try fileManager.copyItem(at: iconURL, to: destinationIcon)
            iconName = "AppIcon"
        }

        try ProfileLoader.save(profile, to: resources.appendingPathComponent("profile.json"))
        try writeInfoPlist(
            profile: profile,
            iconName: iconName,
            to: contents.appendingPathComponent("Info.plist")
        )

        return appURL
    }

    private func writeInfoPlist(
        profile: RuntimeProfile,
        iconName: String?,
        to url: URL
    ) throws {
        var plist: [String: Any] = [
            "CFBundleDevelopmentRegion": "en",
            "CFBundleDisplayName": profile.displayName,
            "CFBundleExecutable": "outRageHost",
            "CFBundleIdentifier": profile.bundleIdentifier,
            "CFBundleInfoDictionaryVersion": "6.0",
            "CFBundleName": profile.displayName,
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": "0.1",
            "CFBundleVersion": "1",
            "LSApplicationCategoryType": "public.app-category.games",
            "LSMinimumSystemVersion": "14.0",
            "LSMultipleInstancesProhibited": true,
            "NSHighResolutionCapable": true,
            "NSSupportsAutomaticGraphicsSwitching": true
        ]
        if let iconName {
            plist["CFBundleIconFile"] = iconName
        }

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: url, options: .atomic)
    }

    private func sanitizeFileName(_ value: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/:")
        return value.components(separatedBy: forbidden).joined(separator: "-")
    }
}

public enum AppBundleBuilderError: Error, Equatable, CustomStringConvertible {
    case invalidIcon(String)

    public var description: String {
        switch self {
        case .invalidIcon(let path): return "App icon must be an existing .icns file: \(path)"
        }
    }
}
