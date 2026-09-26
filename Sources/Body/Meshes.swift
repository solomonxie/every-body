import RealityKit
import simd

/// Schematic shapes as generated meshes — every body part is math, not an asset.
@MainActor
enum Meshes {
    /// Surface of revolution around +Y from a (radius, y) profile, bottom to top.
    static func lathe(_ profile: [SIMD2<Float>], segments: Int = 20) -> MeshResource {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        let rows = profile.count
        for (i, p) in profile.enumerated() {
            let prev = profile[max(0, i - 1)], next = profile[min(rows - 1, i + 1)]
            let tangent = simd_normalize(next - prev + SIMD2(0, 1e-6))
            let n2 = SIMD2(tangent.y, -tangent.x) // outward in (r, y)
            for s in 0...segments {
                let a = Float(s) / Float(segments) * 2 * .pi
                positions.append(SIMD3(p.x * cos(a), p.y, p.x * sin(a)))
                normals.append(simd_normalize(SIMD3(n2.x * cos(a), n2.y, n2.x * sin(a)) + 1e-6))
            }
        }
        let stride = UInt32(segments + 1)
        for i in 0..<UInt32(rows - 1) {
            for s in 0..<UInt32(segments) {
                let a = i * stride + s, b = a + stride
                indices += [a, a + 1, b, b, a + 1, b + 1]
            }
        }
        return build(positions, normals, indices)
    }

    /// Capsule along +Y, centred at the origin; `length` excludes the caps.
    static func capsule(radius: Float, length: Float) -> MeshResource {
        let cap = 8
        var profile: [SIMD2<Float>] = []
        for i in 0...cap {
            let a = -Float.pi / 2 + Float(i) / Float(cap) * .pi / 2
            profile.append(SIMD2(max(0.0001, radius * cos(a)), -length / 2 + radius * sin(a)))
        }
        for i in 0...cap {
            let a = Float(i) / Float(cap) * .pi / 2
            profile.append(SIMD2(max(0.0001, radius * cos(a)), length / 2 + radius * sin(a)))
        }
        return lathe(profile, segments: 16)
    }

    /// Tube of constant radius along a Catmull-Rom curve through the points.
    static func tube(points: [SIMD3<Float>], radius: Float, samples: Int = 40, sides: Int = 8) -> MeshResource {
        let path = (0...samples).map { catmullRom(points, Float($0) / Float(samples)) }
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        // parallel-transport frames so the tube doesn't twist
        var normal = anyPerpendicular(to: simd_normalize(path[1] - path[0]))
        for (i, p) in path.enumerated() {
            let t = simd_normalize(path[min(path.count - 1, i + 1)] - path[max(0, i - 1)])
            normal = simd_normalize(normal - simd_dot(normal, t) * t)
            let binormal = simd_cross(t, normal)
            for s in 0...sides {
                let a = Float(s) / Float(sides) * 2 * .pi
                let n = cos(a) * normal + sin(a) * binormal
                positions.append(p + radius * n)
                normals.append(n)
            }
        }
        let stride = UInt32(sides + 1)
        for i in 0..<UInt32(path.count - 1) {
            for s in 0..<UInt32(sides) {
                let a = i * stride + s, b = a + stride
                indices += [a, b, a + 1, a + 1, b, b + 1]
            }
        }
        return build(positions, normals, indices)
    }

    /// Torus arc lying in the XZ plane; angle 0 = +X, π/2 = +Z (front); `depth` squashes Z.
    static func arc(radius: Float, tube: Float, start: Float, sweep: Float, depth: Float) -> MeshResource {
        let rings = max(8, Int(sweep / (2 * .pi) * 48)), sides = 8
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        for i in 0...rings {
            let u = start + Float(i) / Float(rings) * sweep
            let center = SIMD3(radius * cos(u), 0, radius * sin(u) * depth)
            let out = SIMD3(cos(u), 0, sin(u))
            for s in 0...sides {
                let v = Float(s) / Float(sides) * 2 * .pi
                let n = cos(v) * out + sin(v) * SIMD3(0, 1, 0)
                positions.append(center + tube * n)
                normals.append(n)
            }
        }
        let stride = UInt32(sides + 1)
        for i in 0..<UInt32(rings) {
            for s in 0..<UInt32(sides) {
                let a = i * stride + s, b = a + stride
                indices += [a, a + 1, b, b, a + 1, b + 1]
            }
        }
        return build(positions, normals, indices)
    }

    static func catmullRom(_ p: [SIMD3<Float>], _ u: Float) -> SIMD3<Float> {
        let n = p.count - 1
        let f = min(Float(n) - 0.0001, max(0, u * Float(n)))
        let i = Int(f), t = f - Float(i)
        let p0 = p[max(0, i - 1)], p1 = p[i], p2 = p[min(n, i + 1)], p3 = p[min(n, i + 2)]
        let t2 = t * t, t3 = t2 * t
        return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
    }

    private static func anyPerpendicular(to v: SIMD3<Float>) -> SIMD3<Float> {
        simd_normalize(simd_cross(v, abs(v.y) < 0.9 ? SIMD3(0, 1, 0) : SIMD3(1, 0, 0)))
    }

    private static func build(_ positions: [SIMD3<Float>], _ normals: [SIMD3<Float>], _ indices: [UInt32]) -> MeshResource {
        var d = MeshDescriptor()
        d.positions = MeshBuffer(positions)
        d.normals = MeshBuffer(normals)
        d.primitives = .triangles(indices)
        return (try? MeshResource.generate(from: [d])) ?? MeshResource.generateSphere(radius: 0.01)
    }
}
