import RealityKit
import simd

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
        guard let part = entity.model?.mesh.contents.models.first?.parts.first,
              let tri = part.triangleIndices else { return nil }
        let p = Array(part.positions)
        let n = part.normals.map(Array.init) ?? Array(repeating: SIMD3(0, 0, 1), count: p.count)
        let uv = part.textureCoordinates.map(Array.init) ?? Array(repeating: SIMD2<Float>(0, 0), count: p.count)
        let index = Array(tri)
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

    /// positions and normals as last written
    func current() -> ([SIMD3<Float>], [SIMD3<Float>]) {
        var p = rest, n = normals
        for (k, i) in last.indices.enumerated() { p[i] = last.positions[k]; n[i] = last.normals[k] }
        return (p, n)
    }

    /// Moves the listed vertices; all others are written at rest.
    func write(indices: [Int], positions: [SIMD3<Float>], normals moved: [SIMD3<Float>]) {
        last = (indices, positions, moved)
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
}
