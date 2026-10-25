import Foundation
import Testing
@testable import OutRageKit

@Test func machOInspectorRecognizesKnownMagics() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }
    try fm.createDirectory(at: root, withIntermediateDirectories: true)

    let machO = root.appendingPathComponent("binary")
    try Data([0xcf, 0xfa, 0xed, 0xfe, 0, 0, 0, 0]).write(to: machO)
    #expect(MachOInspector.isMachO(machO))

    let pe = root.appendingPathComponent("target.exe")
    try Data([0x4d, 0x5a, 0, 0]).write(to: pe)
    #expect(!MachOInspector.isMachO(pe))
}
