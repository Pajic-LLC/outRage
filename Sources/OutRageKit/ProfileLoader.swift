import Foundation

public enum ProfileLoader {
    public static func load(from url: URL) throws -> RuntimeProfile {
        let data = try Data(contentsOf: url)
        let profile = try JSONDecoder().decode(RuntimeProfile.self, from: data)
        try profile.validate()
        return profile
    }

    public static func save(
        _ profile: RuntimeProfile,
        to url: URL,
        fileManager: FileManager = .default
    ) throws {
        try profile.validate()
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(profile)
        try data.write(to: url, options: .atomic)
    }
}
