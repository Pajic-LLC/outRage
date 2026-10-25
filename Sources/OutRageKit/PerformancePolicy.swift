import Foundation

public struct PerformancePolicy: Codable, Equatable, Sendable {
    public var preferredMaxFrameRate: Int?
    public var metalFXSpatialUpscaling: Bool?
    public var metalFXSpatialUpscaleFactor: Double?

    public init(
        preferredMaxFrameRate: Int? = nil,
        metalFXSpatialUpscaling: Bool? = nil,
        metalFXSpatialUpscaleFactor: Double? = nil
    ) {
        self.preferredMaxFrameRate = preferredMaxFrameRate
        self.metalFXSpatialUpscaling = metalFXSpatialUpscaling
        self.metalFXSpatialUpscaleFactor = metalFXSpatialUpscaleFactor
    }

    public func validate() throws {
        if let preferredMaxFrameRate,
           !(0...1000).contains(preferredMaxFrameRate) {
            throw PerformancePolicyError.invalidPreferredMaxFrameRate(preferredMaxFrameRate)
        }
        if let metalFXSpatialUpscaleFactor,
           !(1.0...2.0).contains(metalFXSpatialUpscaleFactor) {
            throw PerformancePolicyError.invalidMetalFXSpatialUpscaleFactor(metalFXSpatialUpscaleFactor)
        }
    }
}

public enum PerformancePolicyError: Error, Equatable, CustomStringConvertible {
    case invalidPreferredMaxFrameRate(Int)
    case invalidMetalFXSpatialUpscaleFactor(Double)

    public var description: String {
        switch self {
        case .invalidPreferredMaxFrameRate(let value):
            return "Preferred maximum frame rate must be between 0 and 1000: \(value)"
        case .invalidMetalFXSpatialUpscaleFactor(let value):
            return "MetalFX spatial upscale factor must be between 1.0 and 2.0: \(value)"
        }
    }
}
