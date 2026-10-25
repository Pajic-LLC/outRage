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
            print("metal-device: \(host.metalDeviceName ?? "unknown")")
            print("unified-memory: \(describe(host.hasUnifiedMemory))")
            print("physical-memory: \(host.physicalMemory)")
            print("metal-working-set: \(host.metalRecommendedMaxWorkingSetSize.map(String.init) ?? "unknown")")
            print("rosetta: \(host.hasRosetta ? "yes" : "no")")
            print("preferred-cpu: \(host.recommendedCPUBackend.rawValue)")

        case "paths":
            let paths = RuntimePaths()
            try paths.ensureDirectories()
            print(paths.baseURL.path)

        case "runtimes":
            let paths = RuntimePaths()
            try paths.ensureDirectories()
            let runtimes = try RuntimeCatalog(runtimesURL: paths.runtimesURL).installed()
            if runtimes.isEmpty {
                print("no runtimes installed")
            } else {
                for runtime in runtimes {
                    print("\(runtime.descriptor.id)\t\(runtime.rootURL.path)")
                }
            }

        case "runtime-build-metal":
            guard arguments.count == 6 else {
                throw CLIError.usage("runtime-build-metal <engine-dir> <backend-dir> <runtime-id> <version> <output-dir>")
            }
            let artifacts = try BuiltinMetalRuntimeBuilder.build(
                engineRoot: URL(fileURLWithPath: arguments[1], isDirectory: true),
                backendRoot: URL(fileURLWithPath: arguments[2], isDirectory: true),
                runtimeIdentifier: arguments[3],
                version: arguments[4],
                outputDirectory: URL(fileURLWithPath: arguments[5], isDirectory: true)
            )
            printPackage(artifacts)

        case "runtime-pack":
            guard arguments.count == 4 else {
                throw CLIError.usage("runtime-pack <runtime-directory> <version> <output-directory>")
            }
            let artifacts = try RuntimePackager.build(
                runtimeRoot: URL(fileURLWithPath: arguments[1], isDirectory: true),
                version: arguments[2],
                outputDirectory: URL(fileURLWithPath: arguments[3], isDirectory: true)
            )
            printPackage(artifacts)

        case "runtime-install":
            guard arguments.count == 3 else {
                throw CLIError.usage("runtime-install <runtime.zip> <manifest.json>")
            }
            let archive = URL(fileURLWithPath: arguments[1])
            let manifestData = try Data(contentsOf: URL(fileURLWithPath: arguments[2]))
            let manifest = try JSONDecoder().decode(RuntimePackageManifest.self, from: manifestData)
            let installed = try RuntimeInstaller.install(archiveURL: archive, manifest: manifest)
            print("installed: \(installed.descriptor.id)\t\(installed.rootURL.path)")

        case "runtime-smoke-dxmt":
            guard arguments.count == 2 else {
                throw CLIError.usage("runtime-smoke-dxmt <runtime-id>")
            }
            let paths = RuntimePaths()
            try paths.ensureDirectories()
            let installed = try RuntimeCatalog(runtimesURL: paths.runtimesURL).resolve(
                identifier: arguments[1]
            )
            let cpu = try BackendResolver.resolveCPU(
                requested: .auto,
                runtime: installed.descriptor,
                host: .current()
            )
            let result = try DXMTRuntimeSmokeVerifier.run(
                installedRuntime: installed,
                cpu: cpu
            )
            print("verified: \(result.runtimeIdentifier)")
            print("modules: \(result.loadedModules.sorted().joined(separator: ","))")

        case "validate":
            guard arguments.count == 2 else { throw CLIError.usage("validate <profile.json>") }
            let profile = try ProfileLoader.load(from: URL(fileURLWithPath: arguments[1]))
            print("valid: \(profile.id)")

        case "plan":
            guard arguments.count == 2 else { throw CLIError.usage("plan <profile.json>") }
            let profile = try ProfileLoader.load(from: URL(fileURLWithPath: arguments[1]))
            let paths = RuntimePaths()
            let plan = try LaunchPlanner.makePlan(
                profile: profile,
                targetRoot: paths.targetURL(for: profile.id),
                prefixRoot: paths.prefixURL(for: profile.id)
            )
            print(plan)

        case "prepare":
            guard arguments.count == 2 else { throw CLIError.usage("prepare <profile.json>") }
            let profile = try ProfileLoader.load(from: URL(fileURLWithPath: arguments[1]))
            let session = try LaunchSessionBuilder.prepare(profile: profile)
            print("target: \(session.profile.id)")
            print("runtime: \(session.runtimeIdentifier ?? "native")")
            print("cpu: \(session.plan.cpu.rawValue)")
            print("graphics: \(session.command.graphics.rawValue)")
            print("command: \(session.command)")

        case "acquisition-plan":
            guard arguments.count == 2 else { throw CLIError.usage("acquisition-plan <profile.json>") }
            let profile = try ProfileLoader.load(from: URL(fileURLWithPath: arguments[1]))
            let acquisition = try AcquisitionPlanner.makePlan(profile: profile)
            print(describe(acquisition))

        case "probe":
            guard arguments.count == 2 else { throw CLIError.usage("probe <windows-executable>") }
            let result = try PEProbe.inspect(URL(fileURLWithPath: arguments[1]))
            print("architecture: \(result.architecture.rawValue)")
            print(String(format: "machine: 0x%04x", result.machine))
            print("size: \(result.fileSize)")
            print("graphics: \(result.graphicsHints.map(\.rawValue).joined(separator: ","))")

        case "launch":
            try launch(arguments: Array(arguments.dropFirst()))

        case "bundle":
            try bundle(arguments: Array(arguments.dropFirst()))

        default:
            throw CLIError.usage("unknown command: \(command)")
        }
    }

    static func launch(arguments: [String]) throws {
        guard let profilePath = arguments.first else {
            throw CLIError.usage("launch <profile.json> [--wait]")
        }

        var wait = false
        for option in arguments.dropFirst() {
            switch option {
            case "--wait": wait = true
            default: throw CLIError.usage("unknown launch option: \(option)")
            }
        }

        let profile = try ProfileLoader.load(from: URL(fileURLWithPath: profilePath))
        let paths = RuntimePaths()
        let session = try LaunchSessionBuilder.prepare(profile: profile, paths: paths)
        let running = try ProcessRunner.start(
            session.command,
            outputURL: paths.logURL(for: profile.id)
        )
        print("launched: pid \(running.processIdentifier)")

        if wait {
            running.waitUntilExit()
            print("exit: \(running.terminationStatus)")
            if running.terminationStatus != 0 {
                exit(running.terminationStatus)
            }
        }
    }

    static func bundle(arguments: [String]) throws {
        guard let profilePath = arguments.first else {
            throw CLIError.usage("bundle <profile.json> [--host <outrage-host>] [--icon <AppIcon.icns>] [--output <directory>]")
        }

        var hostPath: String?
        var iconPath: String?
        var outputPath = FileManager.default.currentDirectoryPath
        var index = 1
        while index < arguments.count {
            switch arguments[index] {
            case "--host":
                guard index + 1 < arguments.count else { throw CLIError.usage("--host requires a path") }
                hostPath = arguments[index + 1]
                index += 2
            case "--icon":
                guard index + 1 < arguments.count else { throw CLIError.usage("--icon requires a path") }
                iconPath = arguments[index + 1]
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
            iconURL: iconPath.map { URL(fileURLWithPath: $0) },
            outputDirectory: URL(fileURLWithPath: outputPath, isDirectory: true)
        )
        print(app.path)
    }

    static func printPackage(_ artifacts: RuntimePackageArtifacts) {
        print("archive: \(artifacts.archiveURL.path)")
        print("manifest: \(artifacts.manifestURL.path)")
        print("sha256: \(artifacts.manifest.archiveSHA256)")
    }

    static func describe(_ value: Bool?) -> String {
        guard let value else { return "unknown" }
        return value ? "yes" : "no"
    }

    static func describe(_ action: AcquisitionAction) -> String {
        switch action {
        case let .managedLauncher(
            sourceURL,
            _,
            destinationURL,
            installerArguments,
            installedLauncherURL,
            launcherArguments,
            targetRoot
        ):
            return [
                "kind: managed-launcher",
                "source: \(sourceURL.absoluteString)",
                "installer: \(destinationURL.path)",
                "installer-arguments: \(installerArguments.joined(separator: " "))",
                "launcher: \(installedLauncherURL?.path ?? "unconfigured")",
                "launcher-arguments: \(launcherArguments.joined(separator: " "))",
                "target: \(targetRoot.path)"
            ].joined(separator: "\n")
        case let .steam(appID, branch, targetRoot):
            return [
                "kind: steam",
                "app-id: \(appID)",
                "branch: \(branch ?? "default")",
                "target: \(targetRoot.path)"
            ].joined(separator: "\n")
        case let .importExisting(targetRoot):
            return "kind: import-existing\ntarget: \(targetRoot.path)"
        }
    }

    static func printHelp() {
        print("""
        outRage developer utility

          doctor                                                    Inspect host capabilities
          paths                                                     Create and print runtime data path
          runtimes                                                  List installed runtimes
          runtime-build-metal <engine> <backend> <id> <ver> <out>  Compose and package a Metal runtime
          runtime-pack <dir> <version> <output-dir>                 Build a verified runtime package
          runtime-install <zip> <manifest.json>                     Install a verified runtime package
          runtime-smoke-dxmt <runtime-id>                           Verify DXMT initializes through Wine
          validate <profile.json>                                   Validate a target profile
          plan <profile.json>                                       Resolve a launch plan
          prepare <profile.json>                                    Resolve a complete launch session
          acquisition-plan <profile.json>                           Resolve target acquisition
          probe <windows-executable>                                Inspect a PE target
          launch <profile.json> [--wait]                            Launch a configured target
          bundle <profile.json> [...]                               Build a native .app wrapper
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
