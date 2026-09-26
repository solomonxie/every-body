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

    /// Lathe along +Y centred at the origin: radii sampled evenly over `length`, smoothed, ends rounded shut.
    static func profile(radii: [Float], length: Float) -> MeshResource {
        let n = radii.count
        let steps = max(8, (n - 1) * 4)
        func radius(_ u: Float) -> Float {
            let f = u * Float(n - 1)
            let i = min(n - 2, max(0, Int(f)))
            let t = f - Float(i)
            let r0 = radii[max(0, i - 1)], r1 = radii[i], r2 = radii[min(n - 1, i + 1)], r3 = radii[min(n - 1, i + 2)]
            let t2 = t * t, t3 = t2 * t
            return max(0.0001, 0.5 * (2 * r1 + (-r0 + r2) * t + (2 * r0 - 5 * r1 + 4 * r2 - r3) * t2 + (-r0 + 3 * r1 - 3 * r2 + r3) * t3))
        }
        var points: [SIMD2<Float>] = []
        let r0 = radii.first!, rn = radii.last!
        points.append(SIMD2(0.0001, -length / 2 - r0 * 0.35))
        points.append(SIMD2(r0 * 0.75, -length / 2 - r0 * 0.22))
        for k in 0...steps {
            let u = Float(k) / Float(steps)
            points.append(SIMD2(radius(u), -length / 2 + u * length))
        }
        points.append(SIMD2(rn * 0.75, length / 2 + rn * 0.22))
        points.append(SIMD2(0.0001, length / 2 + rn * 0.35))
        return lathe(points, segments: 18)
    }

    /// Tube along a Catmull-Rom curve through the points; `radii` (one per point) taper it.
    static func tube(points: [SIMD3<Float>], radius: Float, radii: [Float]? = nil, samples: Int = 40, sides: Int = 8) -> MeshResource {
        let path = (0...samples).map { catmullRom(points, Float($0) / Float(samples)) }
        func r(_ i: Int) -> Float {
            guard let radii, radii.count > 1 else { return radius }
            let f = Float(i) / Float(samples) * Float(radii.count - 1)
            let k = min(radii.count - 2, Int(f))
            return radii[k] + (radii[k + 1] - radii[k]) * (f - Float(k))
        }
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
                positions.append(p + r(i) * n)
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

    /// Flat bone: the polygon given `thickness` along its average normal.
    static func plate(points: [SIMD3<Float>], thickness: Float) -> MeshResource {
        let n = points.count
        let c = points.reduce(SIMD3<Float>.zero, +) / Float(n)
        var normal = SIMD3<Float>.zero
        for i in 0..<n { normal += simd_cross(points[i] - c, points[(i + 1) % n] - c) }
        normal = simd_normalize(normal + 1e-6)
        let h = normal * thickness / 2
        var positions: [SIMD3<Float>] = [c + h, c - h]
        var normals: [SIMD3<Float>] = [normal, -normal]
        var indices: [UInt32] = []
        for p in points { positions += [p + h, p - h]; normals += [normal, -normal] }
        for i in 0..<UInt32(n) {
            let a = 2 + 2 * i, b = 2 + 2 * ((i + 1) % UInt32(n))
            indices += [0, a, b, 1, b + 1, a + 1]
            // side wall
            let out = simd_normalize(simd_cross(normal, points[Int((i + 1) % UInt32(n))] - points[Int(i)]) + 1e-6)
            let base = UInt32(positions.count)
            positions += [points[Int(i)] + h, points[Int(i)] - h, points[Int((i + 1) % UInt32(n))] + h, points[Int((i + 1) % UInt32(n))] - h]
            normals += [out, out, out, out]
            indices += [base, base + 1, base + 2, base + 2, base + 1, base + 3]
        }
        return build(positions, normals, indices)
    }

    /// Smooth skin through elliptical sections (centre, half-width along x, half-depth), capped at both ends.
    static func loft(sections: [[Float]], sides: Int = 20) -> MeshResource {
        let n = sections.count
        let steps = (n - 1) * 4
        func at(_ u: Float) -> [Float] {
            let f = min(Float(n - 1) - 0.0001, max(0, u * Float(n - 1)))
            let i = Int(f), t = f - Float(i)
            let a = sections[max(0, i - 1)], b = sections[i], c = sections[min(n - 1, i + 1)], d = sections[min(n - 1, i + 2)]
            let t2 = t * t, t3 = t2 * t
            return (0..<5).map { k in
                0.5 * (2 * b[k] + (-a[k] + c[k]) * t + (2 * a[k] - 5 * b[k] + 4 * c[k] - d[k]) * t2 + (-a[k] + 3 * b[k] - 3 * c[k] + d[k]) * t3)
            }
        }
        let rows = (0...steps).map { at(Float($0) / Float(steps)) }
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        for (i, r) in rows.enumerated() {
            let c = SIMD3(r[0], r[1], r[2])
            let prev = rows[max(0, i - 1)], next = rows[min(rows.count - 1, i + 1)]
            let t = simd_normalize(SIMD3(next[0] - prev[0], next[1] - prev[1], next[2] - prev[2]) + 1e-6)
            var side = SIMD3<Float>(1, 0, 0) - simd_dot(SIMD3<Float>(1, 0, 0), t) * t
            side = simd_normalize(side + 1e-6)
            let depth = simd_cross(side, t)
            for s in 0...sides {
                let a = Float(s) / Float(sides) * 2 * .pi
                positions.append(c + cos(a) * r[3] * side + sin(a) * r[4] * depth)
                normals.append(simd_normalize(cos(a) / max(r[3], 1e-4) * side + sin(a) / max(r[4], 1e-4) * depth))
            }
        }
        let stride = UInt32(sides + 1)
        for i in 0..<UInt32(rows.count - 1) {
            for s in 0..<UInt32(sides) {
                let a = i * stride + s, b = a + stride
                indices += [a, a + 1, b, b, a + 1, b + 1]
            }
        }
        // caps
        for (row, flip) in [(0, true), (rows.count - 1, false)] {
            let r = rows[row]
            let centre = UInt32(positions.count)
            positions.append(SIMD3(r[0], r[1], r[2]))
            let t = simd_normalize(SIMD3(rows[min(rows.count - 1, row + 1)][0] - rows[max(0, row - 1)][0],
                                         rows[min(rows.count - 1, row + 1)][1] - rows[max(0, row - 1)][1],
                                         rows[min(rows.count - 1, row + 1)][2] - rows[max(0, row - 1)][2]) + 1e-6)
            normals.append(flip ? -t : t)
            let base = UInt32(row) * stride
            for s in 0..<UInt32(sides) { indices += flip ? [centre, base + s + 1, base + s] : [centre, base + s, base + s + 1] }
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
