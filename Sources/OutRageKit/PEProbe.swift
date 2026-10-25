import Foundation

public enum PEArchitecture: String, Codable, Equatable, Sendable {
    case x86
    case x86_64
    case arm64
    case unknown
}

public enum GraphicsAPIHint: String, Codable, Equatable, Sendable, CaseIterable {
    case d3d9
    case d3d10
    case d3d11
    case d3d12
    case dxgi
    case vulkan
}

public struct PEProbeResult: Equatable, Sendable {
    public let architecture: PEArchitecture
    public let machine: UInt16
    public let graphicsHints: [GraphicsAPIHint]
    public let fileSize: UInt64

    public init(
        architecture: PEArchitecture,
        machine: UInt16,
        graphicsHints: [GraphicsAPIHint],
        fileSize: UInt64
    ) {
        self.architecture = architecture
        self.machine = machine
        self.graphicsHints = graphicsHints
        self.fileSize = fileSize
    }
}

public enum PEProbe {
    public static func inspect(
        _ url: URL,
        fileManager: FileManager = .default
    ) throws -> PEProbeResult {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSize = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let dos = try readExact(handle: handle, offset: 0, count: 64)
        guard dos.count >= 64, dos[0] == 0x4d, dos[1] == 0x5a else {
            throw PEProbeError.invalidDOSHeader
        }

        let peOffset = Int(readUInt32LE(dos, at: 0x3c))
        guard peOffset >= 64, peOffset < Int(fileSize) else {
            throw PEProbeError.invalidPEOffset(peOffset)
        }

        let peHeader = try readExact(handle: handle, offset: UInt64(peOffset), count: 6)
        guard peHeader.count == 6,
              peHeader[0] == 0x50,
              peHeader[1] == 0x45,
              peHeader[2] == 0x00,
              peHeader[3] == 0x00 else {
            throw PEProbeError.invalidPESignature
        }

        let machine = readUInt16LE(peHeader, at: 4)
        let architecture: PEArchitecture
        switch machine {
        case 0x014c: architecture = .x86
        case 0x8664: architecture = .x86_64
        case 0xaa64: architecture = .arm64
        default: architecture = .unknown
        }

        let hints = try scanGraphicsHints(handle: handle)
        return PEProbeResult(
            architecture: architecture,
            machine: machine,
            graphicsHints: hints,
            fileSize: fileSize
        )
    }

    private static func scanGraphicsHints(handle: FileHandle) throws -> [GraphicsAPIHint] {
        try handle.seek(toOffset: 0)
        let needles: [(GraphicsAPIHint, Data)] = [
            (.d3d9, Data("d3d9.dll".utf8)),
            (.d3d10, Data("d3d10.dll".utf8)),
            (.d3d11, Data("d3d11.dll".utf8)),
            (.d3d12, Data("d3d12.dll".utf8)),
            (.dxgi, Data("dxgi.dll".utf8)),
            (.vulkan, Data("vulkan-1.dll".utf8))
        ]

        var found = Set<GraphicsAPIHint>()
        var carry = Data()
        let chunkSize = 1024 * 1024
        let overlap = needles.map(\.1.count).max() ?? 16

        while let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty {
            var searchable = carry
            searchable.append(chunk)
            let lower = Data(String(decoding: searchable, as: UTF8.self).lowercased().utf8)

            for (hint, needle) in needles where !found.contains(hint) {
                if lower.range(of: needle) != nil {
                    found.insert(hint)
                }
            }

            carry = searchable.suffix(overlap)
        }

        return GraphicsAPIHint.allCases.filter(found.contains)
    }

    private static func readExact(handle: FileHandle, offset: UInt64, count: Int) throws -> Data {
        try handle.seek(toOffset: offset)
        return try handle.read(upToCount: count) ?? Data()
    }

    private static func readUInt16LE(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func readUInt32LE(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }
}

public enum PEProbeError: Error, Equatable, CustomStringConvertible {
    case invalidDOSHeader
    case invalidPEOffset(Int)
    case invalidPESignature

    public var description: String {
        switch self {
        case .invalidDOSHeader: return "File is not a valid PE executable (missing MZ header)"
        case .invalidPEOffset(let value): return "PE header offset is invalid: \(value)"
        case .invalidPESignature: return "File is not a valid PE executable (missing PE signature)"
        }
    }
}
