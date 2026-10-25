import Foundation

public enum BundledProfile {
    public static func locate(
        executableURL: URL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    ) -> URL? {
        let contents = executableURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let profile = contents
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("profile.json")
        return FileManager.default.fileExists(atPath: profile.path) ? profile : nil
    }
}
