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
    static let organ = make { x, y in 0.9 + 0.1 * smooth(x, y, 8) }

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

    /// value noise on an 8-px lattice, bilinear — soft mottling, tiles seamlessly at 64
    private static func smooth(_ x: Int, _ y: Int, _ cell: Int) -> Double {
        let n = 64 / cell
        let gx = x / cell, gy = y / cell
        let fx = Double(x % cell) / Double(cell), fy = Double(y % cell) / Double(cell)
        func v(_ i: Int, _ j: Int) -> Double { noise(i % n, j % n, 3) }
        let sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy)
        let top = v(gx, gy) + (v(gx + 1, gy) - v(gx, gy)) * sx
        let bottom = v(gx, gy + 1) + (v(gx + 1, gy + 1) - v(gx, gy + 1)) * sx
        return top + (bottom - top) * sy
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
