import Foundation

public extension RuntimePaths {
    func diagnosticsURL(for profileID: String) -> URL {
        logsURL.appendingPathComponent(profileID + ".diagnostics.json")
    }
}
