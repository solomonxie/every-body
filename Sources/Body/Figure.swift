import Foundation
import RealityKit
import simd
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// The outer skin figure (MakeHuman, CC0) from Resources/Models/figure.bin: one topology per piece, positions per
/// sex × age × heritage (and pregnant), plus underwear cut from the body's own triangles.
/// Written by scripts/models/build_figure.py; children are already fitted to BodyScene's age reshaping.
@MainActor
enum Figure {
    struct Look: Hashable {
        var female: Bool
        var age: AgeGroup
        var pregnant: Bool
        var heritage: Heritage
        var underwear: Bool
    }

    private struct Header: Decodable {
        struct Piece: Decodable { let vertices: Int; let render: Int; let triangles: Int; let uv: Int; let vmap: Int; let index: Int }
        struct Block: Decodable { let ref: Int?; let offset: Int; let count: Int; let lo: [Float]; let step: [Float] }
        /// vertices lie on body edges: mix(ab.0, ab.1, t)
        struct Garment: Decodable { let vertices: Int; let triangles: Int; let ab: Int; let t: Int; let index: Int; let lift: Float; let color: String }
        let pieces: [String: Piece]
        let blocks: [Block]
        let variants: [String: [String: Int]]
        let garments: [String: Garment]
    }

    private static let file: (header: Header, payload: Data)? = {
        guard let url = ModelLibrary.url(for: "figure.bin"), let raw = try? Data(contentsOf: url), raw.count > 12,
              raw.prefix(4) == Data("EBF1".utf8) else { return nil }
        let n = Int(raw.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: UInt32.self) })
        guard let header = try? JSONDecoder().decode(Header.self, from: raw.subdata(in: 12..<12 + n)),
              let payload = try? (raw.subdata(in: 12 + n..<raw.count) as NSData).decompressed(using: .zlib) as Data
        else { return nil }
        return (header, payload)
    }()

    static var available: Bool { file != nil }

    private static var cache: [Look: [ModelLibrary.Piece]] = [:]
    private static var surfaces: [Look: Surface] = [:]
    private static var textures: [String: TextureResource] = [:]

    /// The figure's pieces (body, eyes, brows, lashes, hair, underwear), or nil if this look isn't built.
    static func pieces(_ look: Look) -> [ModelLibrary.Piece]? {
        if let hit = cache[look] { return hit }
        guard let (header, payload) = file else { return nil }
        let kid = look.age == .infant || look.age.isChild
        let sex = look.female ? "female" : "male"
        let key = look.pregnant && look.female && look.age == .adult ? "female.pregnant.\(look.heritage.rawValue)" : "\(sex).\(look.age.rawValue).\(look.heritage.rawValue)"
        guard let variant = header.variants[key] else { return nil }
        let reader = Reader(payload: payload, header: header)

        var out: [ModelLibrary.Piece] = []
        var body: (positions: [SIMD3<Float>], normals: [SIMD3<Float>])?
        for (name, block) in variant.sorted(by: { $0.key < $1.key }) {
            guard let info = header.pieces[name] else { continue }
            let positions = reader.positions(block)
            let vmap: [UInt32] = reader.array(info.vmap, count: info.render)
            let index: [UInt32] = reader.array(info.index, count: info.triangles * 3)
            let uv16: [UInt16] = reader.array(info.uv, count: info.render * 2)
            let normals = Self.normals(positions, vmap: vmap, index: index)
            if name == "body" {
                body = (positions, normals)
                surfaces[look] = Surface(positions: positions, normals: normals)
            }
            var d = MeshDescriptor(name: name)
            d.positions = MeshBuffers.Positions(vmap.map { positions[Int($0)] })
            d.normals = MeshBuffers.Normals(vmap.map { normals[Int($0)] })
            d.textureCoordinates = MeshBuffers.TextureCoordinates((0..<info.render).map {
                SIMD2(Float(uv16[2 * $0]) / 65535, Float(uv16[2 * $0 + 1]) / 65535)
            })
            d.primitives = .triangles(index)
            guard let mesh = try? MeshResource.generate(from: [d]) else { continue }
            let id = name.hasPrefix("brows") ? "brows" : name.hasPrefix("hair") ? "hair" : name
            out.append(.init(id: id, mesh: mesh, transform: .identity, material: material(name, look: look, kid: kid)))
        }

        // modest underwear; a child's body is never shown without it
        if let body, look.underwear || kid {
            let names: [String] = switch look.age {
            case .infant, .toddler: ["nappy"]
            case .child: look.female ? ["briefs-kid", "top-kid"] : ["briefs-kid"]
            case .adult, .senior: look.female ? ["briefs-female", "bra"] : ["briefs-male"]
            }
            for name in names {
                guard let g = header.garments[name] else { continue }
                if let mesh = garment(g, reader: reader, body: body) {
                    var m = PhysicallyBasedMaterial()
                    m.baseColor = .init(tint: UIColor(hex: g.color))
                    m.roughness = .init(floatLiteral: 0.85)
                    m.metallic = .init(floatLiteral: 0)
                    out.append(.init(id: "underwear-\(name)", mesh: mesh, transform: .identity, material: m))
                }
            }
        }
        cache[look] = out
        return out
    }

    /// The body's skin for this look (built with its pieces), to put points and lines onto.
    static func surface(_ look: Look) -> Surface? {
        if surfaces[look] == nil { _ = pieces(look) }
        return surfaces[look]
    }

    /// Skin vertices in a coarse grid: drops a point onto the nearest skin.
    struct Surface {
        let positions: [SIMD3<Float>]
        let normals: [SIMD3<Float>]
        private let grid: [SIMD3<Int32>: [Int32]]
        private static let cell: Float = 0.05

        init(positions: [SIMD3<Float>], normals: [SIMD3<Float>]) {
            self.positions = positions
            self.normals = normals
            var g: [SIMD3<Int32>: [Int32]] = [:]
            for (i, p) in positions.enumerated() { g[Self.key(p), default: []].append(Int32(i)) }
            grid = g
        }

        private static func key(_ p: SIMD3<Float>) -> SIMD3<Int32> { SIMD3<Int32>((p / cell).rounded(.down)) }

        /// onto the tangent plane of the nearest skin vertex, then `lift` out along its normal
        func snap(_ q: SIMD3<Float>, lift: Float) -> SIMD3<Float> {
            let k = Self.key(q)
            for r: Int32 in 1...3 {
                var best: (Int, Float)?
                for dx in -r...r { for dy in -r...r { for dz in -r...r {
                    for i in grid[k &+ SIMD3(dx, dy, dz)] ?? [] {
                        let d = simd_distance_squared(positions[Int(i)], q)
                        if best == nil || d < best!.1 { best = (Int(i), d) }
                    }
                } } }
                if let (i, _) = best {
                    let n = normals[i]
                    return q - n * simd_dot(q - positions[i], n) + n * lift
                }
            }
            return q
        }
    }

    /// Smooth normals per position (shared across UV seams).
    private static func normals(_ p: [SIMD3<Float>], vmap: [UInt32], index: [UInt32]) -> [SIMD3<Float>] {
        var n = [SIMD3<Float>](repeating: .zero, count: p.count)
        for t in stride(from: 0, to: index.count, by: 3) {
            let a = Int(vmap[Int(index[t])]), b = Int(vmap[Int(index[t + 1])]), c = Int(vmap[Int(index[t + 2])])
            let f = simd_cross(p[b] - p[a], p[c] - p[a])
            n[a] += f; n[b] += f; n[c] += f
        }
        return n.map { simd_length($0) > 0 ? simd_normalize($0) : SIMD3(0, 1, 0) }
    }

    /// A thin shell on the body, pushed out along the skin's normal.
    private static func garment(_ g: Header.Garment, reader: Reader, body: (positions: [SIMD3<Float>], normals: [SIMD3<Float>])) -> MeshResource? {
        let ab: [UInt32] = reader.array(g.ab, count: g.vertices * 2)
        let t: [Float] = reader.array(g.t, count: g.vertices)
        var positions: [SIMD3<Float>] = [], normals: [SIMD3<Float>] = []
        for v in 0..<g.vertices {
            let a = Int(ab[2 * v]), b = Int(ab[2 * v + 1])
            let n = simd_normalize(simd_mix(body.normals[a], body.normals[b], SIMD3(repeating: t[v])))
            positions.append(simd_mix(body.positions[a], body.positions[b], SIMD3(repeating: t[v])) + n * g.lift)
            normals.append(n)
        }
        var d = MeshDescriptor(name: "underwear")
        d.positions = MeshBuffers.Positions(positions)
        d.normals = MeshBuffers.Normals(normals)
        d.primitives = .triangles(reader.array(g.index, count: g.triangles * 3) as [UInt32])
        return try? MeshResource.generate(from: [d])
    }

    private static func material(_ piece: String, look: Look, kid: Bool) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.metallic = .init(floatLiteral: 0)
        m.roughness = .init(floatLiteral: piece == "eyes" ? 0.35 : piece == "body" ? 0.6 : 0.75)
        let grey = look.age == .senior
        let file: String
        var alpha: String?
        switch piece {
        case "body":
            // children wear the young female skin: no stubble or body hair
            let sex = kid || look.female ? "female" : "male"
            file = "skin-\(look.heritage.rawValue)-\(sex)-\(look.age == .senior ? "old" : "young").jpg"
        case "eyes": file = "eyes.jpg"
        default:
            file = "\(piece)\(grey && piece.hasPrefix("hair") ? "-grey" : "").jpg"
            alpha = "\(piece)-alpha.png"
        }
        m.baseColor = .init(tint: .white, texture: texture(file, semantic: .color).map { .init($0) })
        if let alpha, let t = texture(alpha, semantic: .raw) {
            m.blending = .transparent(opacity: .init(scale: 1, texture: .init(t)))
            m.opacityThreshold = 0.05
        }
        return m
    }

    private static func texture(_ file: String, semantic: TextureResource.Semantic) -> TextureResource? {
        if let hit = textures[file] { return hit }
        guard let url = ModelLibrary.url(for: file),
              let t = try? TextureResource.load(contentsOf: url, withName: file, options: .init(semantic: semantic)) else { return nil }
        textures[file] = t
        return t
    }

    private struct Reader {
        let payload: Data
        let header: Header

        func array<T>(_ offset: Int, count: Int) -> [T] {
            payload.withUnsafeBytes { raw in
                (0..<count).map { raw.loadUnaligned(fromByteOffset: offset + $0 * MemoryLayout<T>.stride, as: T.self) }
            }
        }

        func positions(_ i: Int) -> [SIMD3<Float>] {
            let b = header.blocks[i]
            let q: [Int16] = array(b.offset, count: b.count * 3)
            let lo = SIMD3(b.lo[0], b.lo[1], b.lo[2]), step = SIMD3(b.step[0], b.step[1], b.step[2])
            var out = (0..<b.count).map { v in
                (SIMD3(Float(q[3 * v]), Float(q[3 * v + 1]), Float(q[3 * v + 2])) + 32767) * step + lo
            }
            if let ref = b.ref {
                let base = positions(ref)
                for v in out.indices { out[v] += base[v] }
            }
            return out
        }
    }
}
