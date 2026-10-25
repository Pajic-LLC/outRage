import Foundation
import OutRageKit

@main
struct OutRageCLI {
    static func main() {
        do {
            try run()
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            exit(1)
        }
    }

    static func run() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard let command = arguments.first else {
            printHelp()
            return
        }

        switch command {
        case "doctor":
            let host = HostCapabilities.current()
            print("architecture: \(host.architecture)")
            print("os: \(host.operatingSystemVersion)")
            print("metal: \(host.hasMetal ? "yes" : "no")")
            print("rosetta: \(host.hasRosetta ? "yes" : "no")")
            print("preferred-cpu: \(host.recommendedCPUBackend.rawValue)")

        case "paths":
            let paths = RuntimePaths()
            try paths.ensureDirectories()
            print(paths.baseURL.path)

        case "validate":
            guard arguments.count == 2 else { throw CLIError.usage("validate <profile.json>") }
            let profile = try ProfileLoader.load(from: URL(fileURLWithPath: arguments[1]))
            print("valid: \(profile.id)")

        case "plan":
            guard arguments.count == 2 else { throw CLIError.usage("plan <profile.json>") }
            let profile = try ProfileLoader.load(from: URL(fileURLWithPath: arguments[1]))
            let paths = RuntimePaths()
            let plan = try LaunchPlanner.makePlan(profile: profile, targetRoot: paths.targetURL(for: profile.id))
            print(plan)

        case "bundle":
            try bundle(arguments: Array(arguments.dropFirst()))

        default:
            throw CLIError.usage("unknown command: \(command)")
        }
    }

    static func bundle(arguments: [String]) throws {
        guard let profilePath = arguments.first else {
            throw CLIError.usage("bundle <profile.json> [--host <outrage-host>] [--output <directory>]")
        }

        var hostPath: String?
        var outputPath = FileManager.default.currentDirectoryPath
        var index = 1
        while index < arguments.count {
            switch arguments[index] {
            case "--host":
                guard index + 1 < arguments.count else { throw CLIError.usage("--host requires a path") }
                hostPath = arguments[index + 1]
                index += 2
            case "--output":
                guard index + 1 < arguments.count else { throw CLIError.usage("--output requires a path") }
                outputPath = arguments[index + 1]
                index += 2
            default:
                throw CLIError.usage("unknown bundle option: \(arguments[index])")
            }
        }

        let profile = try ProfileLoader.load(from: URL(fileURLWithPath: profilePath))
        let executable = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let defaultHost = executable.deletingLastPathComponent().appendingPathComponent("outrage-host")
        let host = URL(fileURLWithPath: hostPath ?? defaultHost.path)
        guard FileManager.default.isExecutableFile(atPath: host.path) else {
            throw CLIError.hostNotFound(host.path)
        }

        let app = try AppBundleBuilder().build(
            profile: profile,
            hostExecutable: host,
            outputDirectory: URL(fileURLWithPath: outputPath, isDirectory: true)
        )
        print(app.path)
    }

    static func printHelp() {
        print("""
        outRage developer utility

          doctor                         Inspect host capabilities
          paths                          Create and print runtime data path
          validate <profile.json>        Validate a target profile
          plan <profile.json>            Resolve a launch plan
          bundle <profile.json> [...]    Build a native .app wrapper
        """)
    }
}

enum CLIError: Error, CustomStringConvertible {
    case usage(String)
    case hostNotFound(String)

    var description: String {
        switch self {
        case .usage(let value): return "usage: outrage \(value)"
        case .hostNotFound(let value): return "host executable not found: \(value)"
        }
    }
}
