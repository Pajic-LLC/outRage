import Foundation
import OutRageKit

#if canImport(SwiftUI)
import SwiftUI

@main
struct OutRageHostApp: App {
    @State private var state = HostState.loading

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
            .task { load() }
        }
        .windowResizability(.contentSize)
    }

    private func load() {
        do {
            guard let profileURL = BundledProfile.locate() else {
                state = .error("Missing runtime profile")
                return
            }
            let profile = try ProfileLoader.load(from: profileURL)
            let paths = RuntimePaths()
            try paths.ensureDirectories()
            let plan = try LaunchPlanner.makePlan(
                profile: profile,
                targetRoot: paths.targetURL(for: profile.id)
            )
            if FileManager.default.fileExists(atPath: plan.executableURL.path) {
                state = .ready(profile.displayName)
            } else {
                state = .needsInstall(profile.displayName)
            }
        } catch {
            state = .error(String(describing: error))
        }
    }
}

private enum HostState {
    case loading
    case ready(String)
    case needsInstall(String)
    case error(String)

    var title: String {
        switch self {
        case .loading: return "Preparing…"
        case .ready(let name): return "\(name) is ready"
        case .needsInstall(let name): return "\(name) needs setup"
        case .error: return "Unable to continue"
        }
    }

    var detail: String? {
        switch self {
        case .loading, .ready: return nil
        case .needsInstall: return "Installation support is being wired into the runtime."
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
