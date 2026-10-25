import Foundation

public struct ProcessSnapshot: Equatable, Sendable {
    public let pid: Int32
    public let parentPID: Int32
    public let command: String

    public init(pid: Int32, parentPID: Int32, command: String) {
        self.pid = pid
        self.parentPID = parentPID
        self.command = command
    }
}

public enum ProcessDiscovery {
    public static func snapshots() throws -> [ProcessSnapshot] {
        try snapshots(executableURL: URL(fileURLWithPath: "/bin/ps"), arguments: ["-axo", "pid=,ppid=,command="])
    }

    static func snapshots(executableURL: URL, arguments: [String]) throws -> [ProcessSnapshot] {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        // Drain while ps runs: a full pipe otherwise prevents ps from exiting.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ProcessDiscoveryError.psFailed(process.terminationStatus)
        }

        return parse(String(decoding: data, as: UTF8.self))
    }

    public static func find(
        commandContains needle: String,
        excludingPIDs: Set<Int32> = []
    ) throws -> [ProcessSnapshot] {
        guard !needle.isEmpty else { return [] }
        let normalized = needle.lowercased()
        return try snapshots().filter {
            !excludingPIDs.contains($0.pid) && $0.command.lowercased().contains(normalized)
        }
    }

    public static func descendants(
        of rootPID: Int32,
        in snapshots: [ProcessSnapshot]
    ) -> [ProcessSnapshot] {
        var descendantPIDs = Set<Int32>()
        var changed = true
        while changed {
            changed = false
            for snapshot in snapshots {
                if snapshot.parentPID == rootPID || descendantPIDs.contains(snapshot.parentPID) {
                    if descendantPIDs.insert(snapshot.pid).inserted {
                        changed = true
                    }
                }
            }
        }
        return snapshots.filter { descendantPIDs.contains($0.pid) }
    }

    public static func parse(_ output: String) -> [ProcessSnapshot] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }

            let fields = trimmed.split(
                maxSplits: 2,
                omittingEmptySubsequences: true,
                whereSeparator: { $0 == " " || $0 == "\t" }
            )
            guard fields.count == 3,
                  let pid = Int32(fields[0]),
                  let parentPID = Int32(fields[1]) else {
                return nil
            }
            return ProcessSnapshot(
                pid: pid,
                parentPID: parentPID,
                command: String(fields[2])
            )
        }
    }
}

public enum ProcessDiscoveryError: Error, Equatable, CustomStringConvertible {
    case psFailed(Int32)

    public var description: String {
        switch self {
        case .psFailed(let status): return "Process discovery failed with status \(status)"
        }
    }
}
