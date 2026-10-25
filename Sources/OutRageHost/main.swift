import Foundation
import OutRageKit

#if canImport(SwiftUI) && canImport(AppKit)
import AppKit
import SwiftUI

@main
struct OutRageHostApp: App {
    @State private var state = HostState.loading
    @State private var runningProcess: RunningProcess?

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                Text(state.title)
                    .font(.headline)
                if let detail = state.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(width: 420, height: 220)
            .padding()
            .task { await launch() }
        }
        .windowResizability(.contentSize)
    }

    @MainActor
    private func launch() async {
        do {
            guard let profileURL = BundledProfile.locate() else {
                state = .error("Missing runtime profile")
                return
            }

            let profile = try ProfileLoader.load(from: profileURL)
            let paths = RuntimePaths()

            if profile.runtime == .compatibility {
                state = .preparingRuntime(profile.displayName)
                _ = try await RuntimeBootstrap.ensureInstalled(
                    for: profile,
                    paths: paths
                )
            }

            state = .preparing(profile.displayName)
            do {
                try launchTarget(profile, paths: paths)
            } catch LaunchSessionError.targetExecutableMissing {
                try await beginSetupIfAvailable(profile, paths: paths)
            }
        } catch RuntimeBootstrapError.packageSourceMissing {
            state = .needsSetup("Runtime setup is required")
        } catch is RuntimeCatalogError {
            state = .needsSetup("Runtime setup is required")
        } catch LaunchSessionError.runtimeExecutableMissing {
            state = .needsSetup("Runtime installation is incomplete")
        } catch {
            state = .error(String(describing: error))
        }
    }

    @MainActor
    private func launchTarget(
        _ profile: RuntimeProfile,
        paths: RuntimePaths = RuntimePaths()
    ) throws {
        if profile.launcher == .managed,
           profile.acquisition?.kind == .managedLauncher {
            try launchManagedTarget(profile, paths: paths)
            return
        }

        try launchDirectTarget(profile, paths: paths)
    }

    @MainActor
    private func launchDirectTarget(
        _ profile: RuntimeProfile,
        paths: RuntimePaths
    ) throws {
        let session = try LaunchSessionBuilder.prepare(profile: profile, paths: paths)
        state = .launching(profile.displayName)

        let running = try ProcessRunner.start(
            session.command,
            outputURL: paths.logURL(for: profile.id)
        )
        runningProcess = running
        state = .running(profile.displayName, running.processIdentifier)

        running.process.terminationHandler = { _ in
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard running.isRunning else { return }
            hideNativeHost()
        }
    }

    @MainActor
    private func launchManagedTarget(
        _ profile: RuntimeProfile,
        paths: RuntimePaths
    ) throws {
        let targetURL = paths.executableURL(for: profile)
        guard FileManager.default.fileExists(atPath: targetURL.path) else {
            throw LaunchSessionError.targetExecutableMissing(targetURL.path)
        }

        let processNeedle = profile.resolvedProcessMatch
        let monitor = ProcessHandoffMonitor()
        let baselinePIDs = try monitor.baselinePIDs(commandContains: processNeedle)
        let command = try ManagedLauncherBootstrap.makeInstalledLauncherCommand(
            profile: profile,
            paths: paths
        )

        state = .launching(profile.displayName)
        let launcher = try ProcessRunner.start(
            command,
            outputURL: paths.logURL(for: profile.id)
        )
        runningProcess = launcher

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard launcher.isRunning else { return }
            hideNativeHost()
        }

        Task { @MainActor in
            do {
                let target = try await monitor.waitForTarget(
                    commandContains: processNeedle,
                    launcherPID: launcher.processIdentifier,
                    excluding: baselinePIDs,
                    timeout: .seconds(600)
                )
                state = .running(profile.displayName, target.pid)
                hideNativeHost()

                try await monitor.waitUntilExit(pid: target.pid)
                NSApplication.shared.terminate(nil)
            } catch {
                revealNativeHost()
                state = .error(String(describing: error))
            }
        }
    }

    @MainActor
    private func beginSetupIfAvailable(
        _ profile: RuntimeProfile,
        paths: RuntimePaths
    ) async throws {
        guard let acquisition = profile.acquisition else {
            state = .needsSetup("Target files are not installed")
            return
        }

        switch acquisition.kind {
        case .managedLauncher:
            if let launcherURL = try ManagedLauncherBootstrap.installedLauncherURL(
                profile: profile,
                paths: paths
            ), FileManager.default.fileExists(atPath: launcherURL.path) {
                try runInstalledLauncher(profile, paths: paths)
                return
            }

            state = .downloadingSetup(profile.displayName)
            let installerURL = try await ManagedLauncherBootstrap.prepareInstaller(
                profile: profile,
                paths: paths
            )
            let command = try ManagedLauncherBootstrap.makeInstallerCommand(
                profile: profile,
                installerURL: installerURL,
                paths: paths
            )

            state = .runningSetup(profile.displayName)
            let running = try ProcessRunner.start(
                command,
                outputURL: paths.logURL(for: profile.id)
            )
            runningProcess = running
            running.process.terminationHandler = { _ in
                DispatchQueue.main.async {
                    handleManagedInstallerExit(profile, paths: paths)
                }
            }

        case .steam:
            state = .needsSetup("Sign-in setup is required before this target can be installed.")

        case .importExisting:
            state = .selectingFiles(profile.displayName)
            guard let directory = selectExistingTargetDirectory(for: profile.displayName) else {
                state = .needsSetup("Select the folder containing the installed target to continue.")
                return
            }
            _ = try TargetImporter.linkExisting(
                sourceDirectory: directory,
                profile: profile,
                paths: paths
            )
            try launchTarget(profile, paths: paths)
        }
    }

    @MainActor
    private func handleManagedInstallerExit(
        _ profile: RuntimeProfile,
        paths: RuntimePaths
    ) {
        if FileManager.default.fileExists(atPath: paths.executableURL(for: profile).path) {
            do {
                try launchTarget(profile, paths: paths)
            } catch {
                state = .error(String(describing: error))
            }
            return
        }

        do {
            if let launcherURL = try ManagedLauncherBootstrap.installedLauncherURL(
                profile: profile,
                paths: paths
            ), FileManager.default.fileExists(atPath: launcherURL.path) {
                try runInstalledLauncher(profile, paths: paths)
            } else {
                state = .needsSetup("Launcher setup did not finish successfully.")
            }
        } catch {
            state = .error(String(describing: error))
        }
    }

    @MainActor
    private func runInstalledLauncher(
        _ profile: RuntimeProfile,
        paths: RuntimePaths
    ) throws {
        let processNeedle = profile.resolvedProcessMatch
        let monitor = ProcessHandoffMonitor()
        let baselinePIDs = try monitor.baselinePIDs(commandContains: processNeedle)
        let command = try ManagedLauncherBootstrap.makeInstalledLauncherCommand(
            profile: profile,
            paths: paths
        )

        state = .runningSetup(profile.displayName)
        let launcher = try ProcessRunner.start(
            command,
            outputURL: paths.logURL(for: profile.id)
        )
        runningProcess = launcher

        Task { @MainActor in
            do {
                while launcher.isRunning {
                    if let target = try monitor.targetIfPresent(
                        commandContains: processNeedle,
                        launcherPID: launcher.processIdentifier,
                        excluding: baselinePIDs
                    ) {
                        state = .running(profile.displayName, target.pid)
                        hideNativeHost()
                        try await monitor.waitUntilExit(pid: target.pid)
                        NSApplication.shared.terminate(nil)
                        return
                    }
                    try await Task.sleep(for: .milliseconds(500))
                }

                if let target = try monitor.targetIfPresent(
                    commandContains: processNeedle,
                    launcherPID: launcher.processIdentifier,
                    excluding: baselinePIDs
                ) {
                    state = .running(profile.displayName, target.pid)
                    hideNativeHost()
                    try await monitor.waitUntilExit(pid: target.pid)
                    NSApplication.shared.terminate(nil)
                    return
                }

                if FileManager.default.fileExists(atPath: paths.executableURL(for: profile).path) {
                    try launchTarget(profile, paths: paths)
                } else {
                    state = .needsSetup("Finish installing the target in the launcher, then open this app again.")
                }
            } catch {
                revealNativeHost()
                state = .error(String(describing: error))
            }
        }
    }

    @MainActor
    private func selectExistingTargetDirectory(for displayName: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Locate \(displayName)"
        panel.message = "Choose the folder containing the installed files."
        panel.prompt = "Use This Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        return panel.runModal() == .OK ? panel.url : nil
    }
}

@MainActor
private func hideNativeHost() {
    NSApplication.shared.setActivationPolicy(.accessory)
    NSApplication.shared.hide(nil)
}

@MainActor
private func revealNativeHost() {
    NSApplication.shared.setActivationPolicy(.regular)
    NSApplication.shared.unhide(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
}

private enum HostState {
    case loading
    case preparingRuntime(String)
    case preparing(String)
    case downloadingSetup(String)
    case runningSetup(String)
    case selectingFiles(String)
    case launching(String)
    case running(String, Int32)
    case needsSetup(String)
    case error(String)

    var title: String {
        switch self {
        case .loading: return "Preparing…"
        case .preparingRuntime(let name): return "Preparing \(name) runtime…"
        case .preparing(let name): return "Preparing \(name)…"
        case .downloadingSetup(let name): return "Preparing \(name) setup…"
        case .runningSetup(let name): return "Setting up \(name)…"
        case .selectingFiles(let name): return "Locate \(name)"
        case .launching(let name): return "Opening \(name)…"
        case .running(let name, _): return "\(name) is running"
        case .needsSetup: return "Setup required"
        case .error: return "Unable to continue"
        }
    }

    var detail: String? {
        switch self {
        case .loading, .preparingRuntime, .preparing, .downloadingSetup, .runningSetup, .selectingFiles, .launching:
            return nil
        case .running(_, let pid): return "Process \(pid)"
        case .needsSetup(let message): return message
        case .error(let message): return message
        }
    }
}
#else
@main
struct OutRageHostFallback {
    static func main() {
        print("outRage host requires macOS")
    }
}
#endif
