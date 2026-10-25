import Foundation
import Testing
@testable import OutRageKit

@Test func peProbeFindsArchitectureAndGraphicsImports() throws {
    var data = Data(repeating: 0, count: 512)
    data[0] = 0x4d
    data[1] = 0x5a

    let peOffset: UInt32 = 0x80
    data[0x3c] = UInt8(peOffset & 0xff)
    data[0x3d] = UInt8((peOffset >> 8) & 0xff)
    data[0x3e] = UInt8((peOffset >> 16) & 0xff)
    data[0x3f] = UInt8((peOffset >> 24) & 0xff)

    data[0x80] = 0x50
    data[0x81] = 0x45
    data[0x82] = 0x00
    data[0x83] = 0x00
    data[0x84] = 0x64
    data[0x85] = 0x86

    data.append(Data("noise D3D12.dll more noise dxgi.dll".utf8))

    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".exe")
    defer { try? FileManager.default.removeItem(at: url) }
    try data.write(to: url)

    let result = try PEProbe.inspect(url)

    #expect(result.architecture == .x86_64)
    #expect(result.machine == 0x8664)
    #expect(result.graphicsHints.contains(.d3d12))
    #expect(result.graphicsHints.contains(.dxgi))
}
