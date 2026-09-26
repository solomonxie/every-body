import CoreGraphics
import RealityKit

/// Tiny procedural greyscale textures, tinted by each part's colour: muscle fibres, bone grain, organ speckle.
/// 64×64, made once — detail without extra geometry.
@MainActor
enum Textures {
    static let muscle = make { x, y in
        // fibres run along the length (v), so stripes vary around (u)
        let stripe = 0.5 + 0.5 * sin(Double(x) / 64 * 2 * .pi * 14 + sin(Double(y) / 64 * 2 * .pi) * 0.8)
        return 0.78 + 0.22 * stripe
    }
    static let bone = make { x, y in 0.9 + 0.1 * noise(x, y, 11) }
    static let organ = make { x, y in 0.86 + 0.14 * noise(x / 2, y / 2, 7) }

    static func `for`(_ layer: LayerID) -> TextureResource? {
        switch layer {
        case .muscular: muscle
        case .skeletal: bone
        default: nil
        }
    }

    private static func noise(_ x: Int, _ y: Int, _ seed: Int) -> Double {
        var h = UInt32(truncatingIfNeeded: x &* 374761393 &+ y &* 668265263 &+ seed &* 2147483647)
        h = (h ^ (h >> 13)) &* 1274126177
        return Double(h & 0xFFFF) / 65535
    }

    private static func make(_ value: (Int, Int) -> Double) -> TextureResource? {
        let n = 64
        var pixels = [UInt8](repeating: 255, count: n * n * 4)
        for y in 0..<n {
            for x in 0..<n {
                let v = UInt8(max(0, min(1, value(x, y))) * 255)
                let i = (y * n + x) * 4
                pixels[i] = v; pixels[i + 1] = v; pixels[i + 2] = v
            }
        }
        guard let ctx = CGContext(data: &pixels, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
              let image = ctx.makeImage() else { return nil }
        return try? TextureResource(image: image, options: .init(semantic: .color))
    }
}
