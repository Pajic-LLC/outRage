import Foundation

public struct SteamCMDInstallRequest: Equatable, Sendable {
    public let appID: Int
    public let branch: String?
    public let targetRoot: URL
    public let username: String
    public let validate: Bool

    public init(
        appID: Int,
        branch: String? = nil,
        targetRoot: URL,
        username: String,
        validate: Bool = true
    ) {
        self.appID = appID
        self.branch = branch
        self.targetRoot = targetRoot
        self.username = username
        self.validate = validate
    }
}

public enum SteamCMDCommandBuilder {
    public static func makeInstallCommand(
        toolURL: URL,
        request: SteamCMDInstallRequest
    ) throws -> LaunchCommand {
        guard request.appID > 0 else { throw SteamCMDError.invalidAppID }
        guard !request.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SteamCMDError.usernameRequired
        }

        var arguments = [
            "+@sSteamCmdForcePlatformType", "windows",
            "+force_install_dir", request.targetRoot.path,
            "+login", request.username,
            "+app_update", String(request.appID)
        ]

        if let branch = request.branch, !branch.isEmpty {
            arguments += ["-beta", branch]
        }
        if request.validate {
            arguments.append("validate")
        }
        arguments.append("+quit")

        return LaunchCommand(
            executableURL: toolURL,
            arguments: arguments,
            workingDirectoryURL: toolURL.deletingLastPathComponent(),
            environment: [:],
            graphics: .metal
        )
    }
}

public enum SteamCMDError: Error, Equatable, CustomStringConvertible {
    case invalidAppID
    case usernameRequired

    public var description: String {
        switch self {
        case .invalidAppID: return "Steam app identifier must be greater than zero"
        case .usernameRequired: return "Steam username is required; credentials are not stored in the command"
        }
    }
}
