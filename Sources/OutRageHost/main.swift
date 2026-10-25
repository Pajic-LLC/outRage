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
            state = .preparing(profile.displayName)

            do {
                try launchTarget(profile)
            } catch LaunchSessionError.targetExecutableMissing {
                try await beginSetupIfAvailable(profile)
            }
        } catch is RuntimeCatalogError {
            state = .needsSetup("Runtime setup is required")
        } catch LaunchSessionError.runtimeExecutableMissing {
            state = .needsSetup("Runtime installation is incomplete")
        } catch {
            state = .error(String(describing: error))
        }
    }

    @MainActor
    private func launchTarget(_ profile: RuntimeProfile) throws {
        let session = try LaunchSessionBuilder.prepare(profile: profile)
        state = .launching(profile.displayName)

        let running = try ProcessRunner.start(session.command)
        runningProcess = running
        state = .running(profile.displayName, running.processIdentifier)

        running.process.terminationHandler = { _ in
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard running.isRunning else { return }
            NSApplication.shared.setActivationPolicy(.accessory)
            NSApplication.shared.hide(nil)
        }
    }

    @MainActor
    private func beginSetupIfAvailable(_ profile: RuntimeProfile) async throws {
        guard let acquisition = profile.acquisition else {
            state = .needsSetup("Target files are not installed")
            return
        }

        switch acquisition.kind {
        case .managedLauncher:
            state = .downloadingSetup(profile.displayName)
            let installerURL = try await ManagedLauncherBootstrap.prepareInstaller(profile: profile)
            let command = try ManagedLauncherBootstrap.makeInstallerCommand(
                profile: profile,
                installerURL: installerURL
            )

            state = .runningSetup(profile.displayName)
            let running = try ProcessRunner.start(command)
            runningProcess = running
            running.process.terminationHandler = { _ in
                DispatchQueue.main.async {
                    let targetURL = RuntimePaths().targetURL(for: profile.id)
                        .appendingPathComponent(profile.executable)
                    if FileManager.default.fileExists(atPath: targetURL.path) {
                        do {
                            try launchTarget(profile)
                        } catch {
                            state = .error(String(describing: error))
                        }
                    } else {
                        state = .needsSetup("Finish setup in the launcher, then open this app again.")
                    }
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
                profile: profile
            )
            try launchTarget(profile)
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

private enum HostState {
    case loading
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
        case .loading, .preparing, .downloadingSetup, .runningSetup, .selectingFiles, .launching: return nil
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
