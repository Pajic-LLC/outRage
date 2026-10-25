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
            .task { launch() }
        }
        .windowResizability(.contentSize)
    }

    @MainActor
    private func launch() {
        do {
            guard let profileURL = BundledProfile.locate() else {
                state = .error("Missing runtime profile")
                return
            }

            let profile = try ProfileLoader.load(from: profileURL)
            state = .preparing(profile.displayName)

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
        } catch LaunchSessionError.targetExecutableMissing {
            state = .needsSetup("Target files are not installed")
        } catch is RuntimeCatalogError {
            state = .needsSetup("Runtime setup is required")
        } catch LaunchSessionError.runtimeExecutableMissing {
            state = .needsSetup("Runtime installation is incomplete")
        } catch {
            state = .error(String(describing: error))
        }
    }
}

private enum HostState {
    case loading
    case preparing(String)
    case launching(String)
    case running(String, Int32)
    case needsSetup(String)
    case error(String)

    var title: String {
        switch self {
        case .loading: return "Preparing…"
        case .preparing(let name): return "Preparing \(name)…"
        case .launching(let name): return "Opening \(name)…"
        case .running(let name, _): return "\(name) is running"
        case .needsSetup: return "Setup required"
        case .error: return "Unable to continue"
        }
    }

    var detail: String? {
        switch self {
        case .loading, .preparing, .launching: return nil
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
