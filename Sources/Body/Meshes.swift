import RealityKit
import simd

/// Schematic shapes as generated meshes — every body part is math, not an asset.
enum Meshes {
    /// Surface of revolution around +Y from a (radius, y) profile, bottom to top.
    static func lathe(_ profile: [SIMD2<Float>], segments: Int = 20) -> RawMesh {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
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
                uvs.append(SIMD2(Float(s) / Float(segments), Float(i) / Float(rows - 1)))
            }
        }
        let stride = UInt32(segments + 1)
        for i in 0..<UInt32(rows - 1) {
            for s in 0..<UInt32(segments) {
                let a = i * stride + s, b = a + stride
                indices += [a, a + 1, b, b, a + 1, b + 1]
            }
        }
        return build(positions, normals, indices, uvs)
    }

    /// Capsule along +Y, centred at the origin; `length` excludes the caps.
    static func capsule(radius: Float, length: Float) -> RawMesh {
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
    static func profile(radii: [Float], length: Float) -> RawMesh {
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
    static func tube(points: [SIMD3<Float>], radius: Float, radii: [Float]? = nil, samples: Int = 40, sides: Int = 8) -> RawMesh {
        let path = (0...samples).map { catmullRom(points, Float($0) / Float(samples)) }
        // ends close to a rounded tip so an open tube never shows a hollow rim
        func r(_ i: Int) -> Float {
            let end = Float(min(i, samples - i)) / Float(max(1, samples)) * 40
            return body(i) * (end >= 1 ? 1 : max(0.05, sin(end * .pi / 2)))
        }
        func body(_ i: Int) -> Float {
            guard let radii, radii.count > 1 else { return radius }
            let f = Float(i) / Float(samples) * Float(radii.count - 1)
            let k = min(radii.count - 2, Int(f))
            return radii[k] + (radii[k + 1] - radii[k]) * (f - Float(k))
        }
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
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
                uvs.append(SIMD2(Float(s) / Float(sides), Float(i) / Float(samples)))
            }
        }
        let stride = UInt32(sides + 1)
        for i in 0..<UInt32(path.count - 1) {
            for s in 0..<UInt32(sides) {
                let a = i * stride + s, b = a + stride
                indices += [a, b, a + 1, a + 1, b, b + 1]
            }
        }
        return build(positions, normals, indices, uvs)
    }

    /// Flat bone: the polygon given `thickness` along its average normal.
    static func plate(points: [SIMD3<Float>], thickness: Float) -> RawMesh {
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
        let axisU = simd_normalize(points[0] - c + 1e-6), axisV = simd_cross(normal, axisU)
        let uvs = positions.map { p in SIMD2(simd_dot(p - c, axisU) * 4 + 0.5, simd_dot(p - c, axisV) * 4 + 0.5) }
        return build(positions, normals, indices, uvs)
    }

    /// Smooth skin through elliptical sections (centre, half-width along x, half-depth), capped at both ends.
    /// An optional 6th value squares the section off (superellipse exponent: 2 = ellipse, 3 ≈ rounded box).
    static func loft(sections: [[Float]], sides: Int = 20) -> RawMesh {
        let n = sections.count
        let steps = (n - 1) * 4
        func at(_ u: Float) -> [Float] {
            let f = min(Float(n - 1) - 0.0001, max(0, u * Float(n - 1)))
            let i = Int(f), t = f - Float(i)
            let a = sections[max(0, i - 1)], b = sections[i], c = sections[min(n - 1, i + 1)], d = sections[min(n - 1, i + 2)]
            let t2 = t * t, t3 = t2 * t
            return (0..<a.count).map { k in
                0.5 * (2 * b[k] + (-a[k] + c[k]) * t + (2 * a[k] - 5 * b[k] + 4 * c[k] - d[k]) * t2 + (-a[k] + 3 * b[k] - 3 * c[k] + d[k]) * t3)
            }
        }
        var rows = (0...steps).map { at(Float($0) / Float(steps)) }
        // round both ends into domes instead of flat discs
        func dome(_ end: [Float], _ inward: [Float]) -> [[Float]] {
            var d = SIMD3(end[0] - inward[0], end[1] - inward[1], end[2] - inward[2])
            d = simd_normalize(d + 1e-7)
            let r = min(end[3], end[4])
            return [(Float(0.34), Float(0.75)), (Float(0.5), Float(0.35))].map { k in
                var row = end
                row[0] += d.x * r * k.0; row[1] += d.y * r * k.0; row[2] += d.z * r * k.0
                row[3] *= k.1; row[4] *= k.1
                return row
            }
        }
        rows = dome(rows[0], rows[1]).reversed() + rows + dome(rows[rows.count - 1], rows[rows.count - 2])
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var indices: [UInt32] = []
        for (i, r) in rows.enumerated() {
            let c = SIMD3(r[0], r[1], r[2])
            let prev = rows[max(0, i - 1)], next = rows[min(rows.count - 1, i + 1)]
            let t = simd_normalize(SIMD3(next[0] - prev[0], next[1] - prev[1], next[2] - prev[2]) + 1e-6)
            // near-vertical lofts (body, head, limbs) are sliced horizontally, as their sections are given;
            // others measure sections against x, or against y when the loft itself runs sideways
            let side: SIMD3<Float>, depth: SIMD3<Float>
            if abs(t.y) > 0.6 {
                side = SIMD3(1, 0, 0)
                depth = SIMD3(0, 0, t.y > 0 ? -1 : 1)
            } else {
                let ref: SIMD3<Float> = abs(t.x) > 0.8 ? SIMD3(0, 1, 0) : SIMD3(1, 0, 0)
                side = simd_normalize(ref - simd_dot(ref, t) * t + 1e-6)
                depth = simd_cross(side, t)
            }
            for s in 0...sides {
                let a = Float(s) / Float(sides) * 2 * .pi
                let e = r.count > 5 ? 2 / max(r[5], 1) : 1
                let ca = cos(a), sa = sin(a)
                let cx = copysign(pow(abs(ca), e), ca), sy = copysign(pow(abs(sa), e), sa)
                positions.append(c + cx * r[3] * side + sy * r[4] * depth)
                // normal of |x/a|^n + |y/b|^n = 1
                let nExp = 2 / e
                let nx = copysign(pow(abs(cx), nExp - 1), cx) / max(r[3], 1e-4), ny = copysign(pow(abs(sy), nExp - 1), sy) / max(r[4], 1e-4)
                normals.append(simd_normalize(nx * side + ny * depth + 1e-6))
                uvs.append(SIMD2(Float(s) / Float(sides), Float(i) / Float(rows.count - 1)))
            }
        }
        // normals from the surface itself (sections can slope), pointing away from each ring's centre
        let ring = sides + 1
        for i in 0..<rows.count {
            let centre = SIMD3(rows[i][0], rows[i][1], rows[i][2])
            for s in 0...sides {
                let k = i * ring + s
                let around = positions[i * ring + (s + 1) % sides] - positions[i * ring + (s + sides - 1) % sides]
                let along = positions[min(rows.count - 1, i + 1) * ring + s] - positions[max(0, i - 1) * ring + s]
                var n = simd_cross(around, along)
                if simd_length(n) < 1e-9 { continue }
                n = simd_normalize(n)
                if simd_dot(n, positions[k] - centre) < 0 { n = -n }
                normals[k] = n
            }
        }
        let stride = UInt32(sides + 1)
        for i in 0..<UInt32(rows.count - 1) {
            for s in 0..<UInt32(sides) {
                let a = i * stride + s, b = a + stride
                indices += [a, a + 1, b, b, a + 1, b + 1]
            }
        }
        // caps: their own ring copies so the cap faces along the axis, not sideways
        for (row, flip) in [(0, true), (rows.count - 1, false)] {
            let r = rows[row]
            let p = rows[max(0, row - 1)], q = rows[min(rows.count - 1, row + 1)]
            let t = simd_normalize(SIMD3(q[0] - p[0], q[1] - p[1], q[2] - p[2]) + 1e-6)
            let n = flip ? -t : t
            let centre = UInt32(positions.count)
            positions.append(SIMD3(r[0], r[1], r[2]))
            normals.append(n)
            uvs.append(SIMD2(0.5, flip ? 0 : 1))
            let ring = UInt32(positions.count)
            for s in 0...sides {
                positions.append(positions[row * (sides + 1) + s])
                normals.append(n)
                uvs.append(uvs[row * (sides + 1) + s])
            }
            for s in 0..<UInt32(sides) { indices += [centre, ring + s, ring + s + 1] }
        }
        return build(positions, normals, indices, uvs)
    }

    /// Flat muscle as one closed slab: fibres run origin → insertion (u), side by side across the muscle (v).
    static func sheet(origins: [SIMD3<Float>], insertions: [SIMD3<Float>], bulge: SIMD3<Float>, thickness: Float) -> RawMesh {
        let nu = 14, nv = max(10, origins.count * 3)
        func along(_ pts: [SIMD3<Float>], _ v: Float) -> SIMD3<Float> { pts.count == 1 ? pts[0] : catmullRom(pts, v) }
        let grid = (0...nu).map { i in
            (0...nv).map { j in
                let u = Float(i) / Float(nu), v = Float(j) / Float(nv)
                let o = along(origins, v), n = along(insertions, v)
                let m = (o + n) / 2 + bulge * sin(.pi * v * 0.9 + 0.05)
                return (1 - u) * (1 - u) * o + 2 * u * (1 - u) * m + u * u * n
            }
        }
        return slab(grid: grid, thickness: thickness)
    }

    /// Closed slab around a surface grid (rows = origin → insertion, columns = across the muscle),
    /// thickest mid-belly and thinning to the tendon ends and free edges.
    static func slab(grid: [[SIMD3<Float>]], thickness: Float) -> RawMesh {
        let nu = grid.count - 1, nv = grid[0].count - 1
        func half(_ u: Float, _ v: Float) -> Float {
            thickness * pow(sin(.pi * (0.03 + 0.94 * u)), 0.8) * pow(sin(.pi * (0.02 + 0.96 * v)), 0.6)
        }
        var positions: [SIMD3<Float>] = [], normals: [SIMD3<Float>] = [], uvs: [SIMD2<Float>] = [], indices: [UInt32] = []
        for side: Float in [1, -1] {
            for i in 0...nu {
                for j in 0...nv {
                    let c = grid[i][j]
                    let du = grid[min(nu, i + 1)][j] - grid[max(0, i - 1)][j]
                    let dv = grid[i][min(nv, j + 1)] - grid[i][max(0, j - 1)]
                    let n = simd_normalize(simd_cross(du, dv) + 1e-7) * side
                    positions.append(c + n * half(Float(i) / Float(nu), Float(j) / Float(nv)))
                    normals.append(n)
                    uvs.append(SIMD2(Float(j) / Float(nv) * 1.5, Float(i) / Float(nu)))
                }
            }
        }
        let stride = UInt32(nv + 1), layer = UInt32((nu + 1) * (nv + 1))
        for l in 0..<UInt32(2) {
            for i in 0..<UInt32(nu) {
                for j in 0..<UInt32(nv) {
                    let a = l * layer + i * stride + j, b = a + stride
                    indices += [a, b, a + 1, a + 1, b, b + 1]
                }
            }
        }
        // stitch the two faces along the rim
        let middle = grid[nu / 2][nv / 2]
        var rim: [UInt32] = []
        for j in 0...UInt32(nv) { rim.append(j) }
        for i in 1...UInt32(nu) { rim.append(i * stride + UInt32(nv)) }
        for j in (0..<UInt32(nv)).reversed() { rim.append(UInt32(nu) * stride + j) }
        for i in (1..<UInt32(nu)).reversed() { rim.append(i * stride) }
        for k in 0..<rim.count {
            let a = rim[k], b = rim[(k + 1) % rim.count]
            let outward = simd_normalize(positions[Int(a)] + positions[Int(b)] - 2 * middle + 1e-7)
            let base = UInt32(positions.count)
            positions += [positions[Int(a)], positions[Int(b)], positions[Int(a + layer)], positions[Int(b + layer)]]
            normals += [outward, outward, outward, outward]
            uvs += [uvs[Int(a)], uvs[Int(b)], uvs[Int(a)], uvs[Int(b)]]
            indices += [base, base + 2, base + 1, base + 1, base + 2, base + 3]
        }
        return build(positions, normals, indices, uvs)
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

    /// Winds every triangle to face along its vertex normals — renderers light back faces as unlit insides.
    private static func build(_ positions: [SIMD3<Float>], _ normals: [SIMD3<Float>], _ indices: [UInt32], _ uvs: [SIMD2<Float>]? = nil) -> RawMesh {
        var out = indices
        for t in Swift.stride(from: 0, to: out.count - 2, by: 3) {
            let a = Int(out[t]), b = Int(out[t + 1]), c = Int(out[t + 2])
            let face = simd_cross(positions[b] - positions[a], positions[c] - positions[a])
            if simd_dot(face, normals[a] + normals[b] + normals[c]) < 0 { out.swapAt(t + 1, t + 2) }
        }
        return RawMesh(positions: positions, normals: normals, indices: out, uvs: uvs)
    }

    /// Geometry for shapes that aren't a built-in primitive; nil for sphere / box / spindle.
    static func raw(for shape: PartShape) -> RawMesh? {
        switch shape {
        case .sphere, .box, .spindle: nil
        case let .segment(from, to, radius): capsule(radius: radius, length: max(0.001, simd_distance(from.simd, to.simd)))
        case let .lathe(from, to, radii, _): profile(radii: radii, length: max(0.001, simd_distance(from.simd, to.simd)))
        case let .tube(points, radius, radii):
            // long winding paths (gut) need more samples than a bone
            tube(points: points.map(\.simd), radius: radius, radii: radii, samples: max(40, points.count * 3), sides: points.count > 40 ? 10 : 8)
        case let .plate(points, thickness): plate(points: points.map(\.simd), thickness: thickness)
        case let .loft(sections): loft(sections: sections)
        case let .sheet(origins, insertions, bulge, thickness):
            sheet(origins: origins.map(\.simd), insertions: insertions.map(\.simd), bulge: bulge.simd, thickness: thickness)
        case let .slab(grid, thickness): slab(grid: grid.map { $0.map(\.simd) }, thickness: thickness)
        case let .tubes(paths, radius):
            paths.filter { $0.count > 1 }.map { tube(points: $0.map(\.simd), radius: radius, samples: max(8, $0.count * 4), sides: 6) }
                .reduce(RawMesh(positions: [], normals: [], indices: [], uvs: [])) { $0.appending($1) }
        }
    }
}

/// Vertex data computed off the main thread; turned into a MeshResource on it.
struct RawMesh: Sendable {
    var positions: [SIMD3<Float>]
    var normals: [SIMD3<Float>]
    var indices: [UInt32]
    var uvs: [SIMD2<Float>]?

    func appending(_ other: RawMesh) -> RawMesh {
        let offset = UInt32(positions.count)
        return RawMesh(positions: positions + other.positions, normals: normals + other.normals,
                       indices: indices + other.indices.map { $0 + offset }, uvs: (uvs ?? []) + (other.uvs ?? []))
    }

    @MainActor func resource() -> MeshResource {
        var d = MeshDescriptor()
        d.positions = MeshBuffer(positions)
        d.normals = MeshBuffer(normals)
        if let uvs, uvs.count == positions.count { d.textureCoordinates = MeshBuffer(uvs) }
        d.primitives = .triangles(indices)
        return (try? MeshResource.generate(from: [d])) ?? MeshResource.generateSphere(radius: 0.01)
    }
}
