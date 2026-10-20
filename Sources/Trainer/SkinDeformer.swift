import Foundation
import Metal
import RealityKit
import simd
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// A skin mesh copied into a LowLevelMesh so its vertices can move every frame.
/// Positions + normals share buffer 0 (rewritten on change), UVs sit in buffer 1 (written once).
@MainActor
final class SkinDeformer {
    let entity: ModelEntity
    let rest: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    let triangles: [UInt32]
    private let mesh: LowLevelMesh
    /// rest positions + normals, interleaved as in buffer 0
    private let restBuffer: [Float]

    /// nil when the entity's mesh can't be read back
    init?(_ entity: ModelEntity) {
        let p: [SIMD3<Float>], n: [SIMD3<Float>], uv: [SIMD2<Float>], index: [UInt32]
        if let resource = entity.model?.mesh, let s = Figure.source(resource) {
            (p, n, uv, index) = (s.positions, s.normals, s.uv, s.triangles)
        } else {
            guard let part = entity.model?.mesh.contents.models.first?.parts.first,
                  let tri = part.triangleIndices else { return nil }
            // (elements: iterating a MeshBuffer goes through AnyIterator, several times slower)
            p = part.positions.elements
            n = part.normals?.elements ?? Array(repeating: SIMD3(0, 0, 1), count: p.count)
            uv = part.textureCoordinates?.elements ?? Array(repeating: SIMD2<Float>(0, 0), count: p.count)
            index = tri.elements
        }
        var d = LowLevelMesh.Descriptor()
        d.vertexCapacity = p.count
        d.indexCapacity = index.count
        d.vertexAttributes = [
            .init(semantic: .position, format: .float3, layoutIndex: 0, offset: 0),
            .init(semantic: .normal, format: .float3, layoutIndex: 0, offset: 12),
            .init(semantic: .uv0, format: .float2, layoutIndex: 1, offset: 0),
        ]
        d.vertexLayouts = [.init(bufferIndex: 0, bufferStride: 24), .init(bufferIndex: 1, bufferStride: 8)]
        d.indexType = .uint32
        guard let mesh = try? LowLevelMesh(descriptor: d) else { return nil }
        var lo = p.first ?? .zero, hi = lo
        for q in p { lo = simd_min(lo, q); hi = simd_max(hi, q) }
        mesh.withUnsafeMutableIndices { raw in
            let dst = raw.bindMemory(to: UInt32.self)
            for i in index.indices { dst[i] = index[i] }
        }
        mesh.withUnsafeMutableBytes(bufferIndex: 1) { raw in
            let dst = raw.bindMemory(to: SIMD2<Float>.self)
            for i in uv.indices { dst[i] = uv[i] }
        }
        // padded: the moved vertices stay inside the culling box
        mesh.parts.replaceAll([LowLevelMesh.Part(indexCount: index.count, topology: .triangle, bounds: BoundingBox(min: lo - 0.3, max: hi + 0.3))])
        self.entity = entity
        self.mesh = mesh
        rest = p
        normals = n
        triangles = index
        restBuffer = zip(p, n).flatMap { [$0.x, $0.y, $0.z, $1.x, $1.y, $1.z] }
        write(indices: [], positions: [], normals: [])
        guard let resource = try? MeshResource(from: mesh) else { return nil }
        entity.model?.mesh = resource
    }

    private var last: (indices: [Int], positions: [SIMD3<Float>], normals: [SIMD3<Float>]) = ([], [], [])

    /// Nearest crossing of a ray (mesh coordinates) with the surface as last written: point and interpolated normal.
    func intersect(origin o: SIMD3<Float>, direction d: SIMD3<Float>) -> (point: SIMD3<Float>, normal: SIMD3<Float>)? {
        let (p, n) = current()
        var best: (t: Float, i: Int, u: Float, v: Float)?
        for k in stride(from: 0, to: triangles.count, by: 3) {
            let a = Int(triangles[k]), b = Int(triangles[k + 1]), c = Int(triangles[k + 2])
            let e1 = p[b] - p[a], e2 = p[c] - p[a]
            let h = simd_cross(d, e2)
            let det = simd_dot(e1, h)
            guard abs(det) > 1e-9 else { continue }
            let f = 1 / det
            let s = o - p[a]
            let u = f * simd_dot(s, h)
            guard u >= -1e-4, u <= 1 + 1e-4 else { continue }
            let q = simd_cross(s, e1)
            let v = f * simd_dot(d, q)
            guard v >= -1e-4, u + v <= 1 + 1e-4 else { continue }
            let t = f * simd_dot(e2, q)
            if t > 0, best == nil || t < best!.t { best = (t, k, u, v) }
        }
        guard let hit = best else { return nil }
        let a = Int(triangles[hit.i]), b = Int(triangles[hit.i + 1]), c = Int(triangles[hit.i + 2])
        let normal = simd_normalize((1 - hit.u - hit.v) * n[a] + hit.u * n[b] + hit.v * n[c])
        return (o + hit.t * d, normal)
    }

    /// the occlusion overlay (a child of the skin's entity), made on first use
    private(set) var shade: ModelEntity?
    private var shadeMesh: LowLevelMesh?
    /// overlay lift off the skin (no depth fight) and the least occlusion drawn
    private static let shadeLift: Float = 0.0005, shadeMin: Float = 0.01

    /// shading drawn last time (false: an empty overlay, nothing to clear)
    private var shadeShown = false
    /// reused per write: each vertex's overlay slot, the vertices and indices drawn
    private var shadeSlot: [Int32] = [], shadeUsed: [Int] = [], shadeIndex: [UInt32] = []

    /// `value`: occlusion per vertex; `position`: a vertex's overlay point
    private func writeShade(_ value: UnsafeBufferPointer<Float>, position: (Int) -> SIMD3<Float>) {
        var any = false
        for v in value where v >= Self.shadeMin { any = true; break }
        if !any && !shadeShown { return }
        if shade == nil {
            guard let ramp = Self.shadeRamp else { return }
            var d = LowLevelMesh.Descriptor()
            d.vertexCapacity = rest.count
            d.indexCapacity = triangles.count
            d.vertexAttributes = [.init(semantic: .position, format: .float3, layoutIndex: 0, offset: 0),
                                  .init(semantic: .uv0, format: .float2, layoutIndex: 0, offset: 12)]
            d.vertexLayouts = [.init(bufferIndex: 0, bufferStride: 20)]
            d.indexType = .uint32
            guard let mesh = try? LowLevelMesh(descriptor: d), let resource = try? MeshResource(from: mesh) else { return }
            var m = UnlitMaterial()
            m.color = .init(tint: .black, texture: .init(ramp, sampler: .init(Self.shadeSampler)))
            m.blending = .transparent(opacity: .init(floatLiteral: 1))
            let e = ModelEntity(mesh: resource, materials: [m])
            e.name = "contact-shade"
            entity.addChild(e)
            shade = e; shadeMesh = mesh
        }
        guard let mesh = shadeMesh else { return }
        // compacted: only triangles with a shaded corner, their vertices renumbered
        if shadeSlot.count != rest.count { shadeSlot = [Int32](repeating: -1, count: rest.count) }
        var slot: [Int32] = [], used: [Int] = [], index: [UInt32] = []
        swap(&slot, &shadeSlot); swap(&used, &shadeUsed); swap(&index, &shadeIndex)
        defer { swap(&slot, &shadeSlot); swap(&used, &shadeUsed); swap(&index, &shadeIndex) }
        used.removeAll(keepingCapacity: true)
        index.removeAll(keepingCapacity: true)
        let tri = triangles, least = Self.shadeMin
        for t in stride(from: 0, to: tri.count - 2, by: 3) {
            let a = Int(tri[t]), b = Int(tri[t + 1]), c = Int(tri[t + 2])
            guard max(value[a], value[b], value[c]) >= least else { continue }
            if slot[a] < 0 { slot[a] = Int32(used.count); used.append(a) }
            if slot[b] < 0 { slot[b] = Int32(used.count); used.append(b) }
            if slot[c] < 0 { slot[c] = Int32(used.count); used.append(c) }
            index.append(UInt32(slot[a])); index.append(UInt32(slot[b])); index.append(UInt32(slot[c]))
        }
        for v in used { slot[v] = -1 }
        var lo = SIMD3<Float>(repeating: .infinity), hi = -lo
        mesh.replaceUnsafeMutableBytes(bufferIndex: 0) { raw in
            let f = raw.bindMemory(to: Float.self)
            for (k, v) in used.enumerated() {
                let q = position(v)
                lo = simd_min(lo, q); hi = simd_max(hi, q)
                let o = k * 5
                f[o] = q.x; f[o + 1] = q.y; f[o + 2] = q.z
                f[o + 3] = (0.5 + 254 * min(1, value[v])) / 256; f[o + 4] = 0.5
            }
        }
        mesh.replaceUnsafeMutableIndices { raw in
            let dst = raw.bindMemory(to: UInt32.self)
            for (k, i) in index.enumerated() { dst[k] = i }
        }
        mesh.parts.replaceAll(index.isEmpty ? [] : [LowLevelMesh.Part(indexCount: index.count, topology: .triangle, bounds: BoundingBox(min: lo, max: hi))])
        shadeShown = !index.isEmpty
    }

    /// white with alpha rising left to right: the overlay's opacity is its u
    private static let shadeRamp: TextureResource? = {
        let n = 256
        var px = [UInt8](repeating: 255, count: n * 4)
        for x in 0..<n { px[4 * x + 3] = UInt8(x) }
        guard let provider = CGDataProvider(data: Data(px) as CFData),
              let image = CGImage(width: n, height: 1, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4 * n,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return nil }
        return try? TextureResource(image: image, options: .init(semantic: .color))
    }()

    /// clamped, no mips: a sample just outside the overlay's edge must not wrap to the opaque end
    private static let shadeSampler: MTLSamplerDescriptor = {
        let d = MTLSamplerDescriptor()
        d.sAddressMode = .clampToEdge; d.tAddressMode = .clampToEdge
        d.minFilter = .linear; d.magFilter = .linear; d.mipFilter = .notMipmapped
        return d
    }()

    /// positions and normals as last written
    func current() -> ([SIMD3<Float>], [SIMD3<Float>]) {
        if wholeValid { return whole }
        var p = rest, n = normals
        for (k, i) in last.indices.enumerated() { p[i] = last.positions[k]; n[i] = last.normals[k] }
        return (p, n)
    }

    /// bumped on every write: a cached pose can tell someone else wrote since
    private(set) var version = 0
    /// every vertex as written by write(count:...), kept while wholeValid
    private var whole: ([SIMD3<Float>], [SIMD3<Float>]) = ([], [])
    private var wholeValid = false

    /// Moves the listed vertices; all others are written at rest. `occlusion` (per listed vertex, 0...1) darkens the skin
    /// there through a black overlay: no ambient occlusion or shadows light a pressed crease otherwise.
    func write(indices: [Int], positions: [SIMD3<Float>], normals moved: [SIMD3<Float>], occlusion: [Float] = []) {
        version += 1
        if !occlusion.isEmpty || shade != nil {
            var value = [Float](repeating: 0, count: rest.count), at = [Int32](repeating: -1, count: rest.count)
            for (k, i) in indices.enumerated() where k < occlusion.count { value[i] = occlusion[k] }
            for (k, i) in indices.enumerated() { at[i] = Int32(k) }
            let lift = Self.shadeLift
            value.withUnsafeBufferPointer { v in
                writeShade(v) { i in
                    let j = Int(at[i])
                    return j >= 0 ? positions[j] + moved[j] * lift : rest[i] + normals[i] * lift
                }
            }
        }
        last = (indices, positions, moved)
        wholeValid = false
        mesh.replaceUnsafeMutableBytes(bufferIndex: 0) { raw in
            // two packed float3 per vertex (SIMD3<Float> is 16 bytes, so floats)
            let f = raw.bindMemory(to: Float.self)
            func put(_ i: Int, _ p: SIMD3<Float>, _ n: SIMD3<Float>) {
                let o = i * 6
                f[o] = p.x; f[o + 1] = p.y; f[o + 2] = p.z
                f[o + 3] = n.x; f[o + 4] = n.y; f[o + 5] = n.z
            }
            restBuffer.withUnsafeBytes { src in raw.copyMemory(from: UnsafeRawBufferPointer(rebasing: src.prefix(raw.count))) }
            for (k, i) in indices.enumerated() { put(i, positions[k], moved[k]) }
        }
    }

    /// Every vertex moved (count == rest.count), as write(indices:) with all of them, without its per-call arrays.
    func write(count: Int, positions p: UnsafePointer<SIMD3<Float>>, normals n: UnsafePointer<SIMD3<Float>>, occlusion: UnsafePointer<Float>? = nil) {
        precondition(count == rest.count)
        version += 1
        let lift = Self.shadeLift
        if let occlusion {
            writeShade(UnsafeBufferPointer(start: occlusion, count: count)) { p[$0] + n[$0] * lift }
        } else if shade != nil {
            let zero = [Float](repeating: 0, count: count)
            zero.withUnsafeBufferPointer { writeShade($0) { p[$0] + n[$0] * lift } }
        }
        last = ([], [], [])
        if whole.0.count != count { whole = (rest, normals) }
        whole.0.withUnsafeMutableBufferPointer { $0.baseAddress!.update(from: p, count: count) }
        whole.1.withUnsafeMutableBufferPointer { $0.baseAddress!.update(from: n, count: count) }
        wholeValid = true
        mesh.replaceUnsafeMutableBytes(bufferIndex: 0) { raw in
            let f = raw.bindMemory(to: Float.self)
            for i in 0..<count {
                let o = i * 6, a = p[i], b = n[i]
                f[o] = a.x; f[o + 1] = a.y; f[o + 2] = a.z
                f[o + 3] = b.x; f[o + 4] = b.y; f[o + 5] = b.z
            }
        }
    }
}
