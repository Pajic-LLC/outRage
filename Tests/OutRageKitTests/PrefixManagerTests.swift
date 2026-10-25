import Foundation
import Testing
@testable import OutRageKit

@Test func prefixInitializerRunsOncePerRuntimeRevision() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }

    let runtimeRoot = root.appendingPathComponent("runtime", isDirectory: true)
    let bin = runtimeRoot.appendingPathComponent("bin", isDirectory: true)
    let targetRoot = root.appendingPathComponent("target", isDirectory: true)
    let prefixRoot = root.appendingPathComponent("prefix", isDirectory: true)
    let cacheRoot = root.appendingPathComponent("cache", isDirectory: true)
    for directory in [bin, targetRoot, prefixRoot, cacheRoot] {
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    let initializer = bin.appendingPathComponent("initialize")
    let script = """
    #!/bin/sh
    count=0
    if [ -f "$1" ]; then count=$(cat "$1"); fi
    echo $((count + 1)) > "$1"
    """
    try Data(script.utf8).write(to: initializer)
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: initializer.path)

    let context = RuntimeLaunchContext(
        runtimeRoot: runtimeRoot,
        targetRoot: targetRoot,
        prefixRoot: prefixRoot,
        cacheRoot: cacheRoot
    )
    let countURL = cacheRoot.appendingPathComponent("count")

    func runtime(revision: Int) -> RuntimeDescriptor {
        RuntimeDescriptor(
            id: "prefix-runtime",
            revision: revision,
            executable: "bin/initialize",
            prefixInitializer: RuntimeCommandDescriptor(
                executable: "bin/initialize",
                arguments: ["${CACHE_ROOT}/count"]
            ),
            supportedCPUBackends: [.native],
            supportedGraphicsBackends: [.metal]
        )
    }

    try PrefixManager.ensureInitialized(
        runtime: runtime(revision: 1),
        runtimeRoot: runtimeRoot,
        cpu: .native,
        graphics: .metal,
        context: context,
        fileManager: fm
    )
    #expect(try String(contentsOf: countURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) == "1")

    try PrefixManager.ensureInitialized(
        runtime: runtime(revision: 1),
        runtimeRoot: runtimeRoot,
        cpu: .native,
        graphics: .metal,
        context: context,
        fileManager: fm
    )
    #expect(try String(contentsOf: countURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) == "1")

    try PrefixManager.ensureInitialized(
        runtime: runtime(revision: 2),
        runtimeRoot: runtimeRoot,
        cpu: .native,
        graphics: .metal,
        context: context,
        fileManager: fm
    )
    #expect(try String(contentsOf: countURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) == "2")
}
