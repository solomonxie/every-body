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
        /// vertices lie in body triangles abc (weights w of a and b); f: distance to the garment edge
        struct Garment: Decodable { let vertices: Int; let triangles: Int; let abc: Int; let w: Int; let f: Int; let index: Int; let lift: Float; let color: String }
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
            let id = name.hasPrefix("brows") ? "brows" : name.hasPrefix("lashes") ? "lashes" : name.hasPrefix("hair") ? "hair" : name
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
                    m.baseColor = .init(tint: UIColor(hex: g.color), texture: texture("fabric.png", semantic: .color).map { .init($0) })
                    m.roughness = .init(floatLiteral: 0.9)
                    // soft cotton: a faint sheen at grazing angles
                    m.sheen = .init(tint: UIColor(white: 0.35, alpha: 1))
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

        /// how far `q` lies outside the skin (negative: inside), against the nearest skin vertex's normal
        func depth(_ q: SIMD3<Float>) -> Float { depthNormal(q).depth }

        /// depth and the nearest skin vertex's normal (zero when no skin is near). Where two surfaces are close (an arm
        /// by the trunk) the nearest one may be the wrong one: inside either of the near ones counts as inside.
        func depthNormal(_ q: SIMD3<Float>) -> (depth: Float, normal: SIMD3<Float>) {
            let k = Self.key(q)
            let cells = (-1...1).flatMap { dx in (-1...1).flatMap { dy in (-1...1).compactMap { dz in grid[k &+ SIMD3<Int32>(Int32(dx), Int32(dy), Int32(dz))] } } }
            var best = -1, bestD = Float.infinity
            for cell in cells { for i in cell {
                let d = simd_distance_squared(positions[Int(i)], q)
                if d < bestD { bestD = d; best = Int(i) }
            } }
            guard best >= 0 else { return (-1, .zero) }
            let reach = 1.5 * bestD.squareRoot() + 0.005
            var depth = Float.infinity
            for cell in cells { for i in cell where simd_distance_squared(positions[Int(i)], q) <= reach * reach {
                depth = min(depth, simd_dot(q - positions[Int(i)], normals[Int(i)]))
            } }
            return (depth, normals[best])
        }

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

    /// hem width (scene units) the fabric texture spans, from the garment's edge inward
    private static let hem: Float = 0.025

    /// A thin shell on the body, pushed out along the skin's normal; its edge hugs the skin.
    private static func garment(_ g: Header.Garment, reader: Reader, body: (positions: [SIMD3<Float>], normals: [SIMD3<Float>])) -> MeshResource? {
        let abc: [UInt32] = reader.array(g.abc, count: g.vertices * 3)
        let w: [Float] = reader.array(g.w, count: g.vertices * 2)
        let f: [Float] = reader.array(g.f, count: g.vertices)
        var positions: [SIMD3<Float>] = [], normals: [SIMD3<Float>] = [], uv: [SIMD2<Float>] = []
        for v in 0..<g.vertices {
            let a = Int(abc[3 * v]), b = Int(abc[3 * v + 1]), c = Int(abc[3 * v + 2])
            let wa = w[2 * v], wb = w[2 * v + 1], wc = max(0, 1 - wa - wb)
            let n = simd_normalize(wa * body.normals[a] + wb * body.normals[b] + wc * body.normals[c])
            let edge = min(f[v] / 0.01, 1)
            positions.append(wa * body.positions[a] + wb * body.positions[b] + wc * body.positions[c] + n * g.lift * (0.8 + 0.2 * edge))
            normals.append(n)
            uv.append(SIMD2(min(f[v] / hem, 0.97), 0.5))  // not 1: the sampler wraps
        }
        var d = MeshDescriptor(name: "underwear")
        d.positions = MeshBuffers.Positions(positions)
        d.normals = MeshBuffers.Normals(normals)
        d.textureCoordinates = MeshBuffers.TextureCoordinates(uv)
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
            // children's skin is the young female one (no stubble or body hair) with their own scalp
            let skin = kid ? "kid" : "\(look.female ? "female" : "male")-\(look.age == .senior ? "old" : "young")"
            file = "skin-\(look.heritage.rawValue)-\(skin).jpg"
        case "eyes": file = "eyes.jpg"
        default:
            file = "\(piece).jpg"
            alpha = "\(piece)-alpha.png"
        }
        // hair and brows are grey strands, coloured here; a senior's brows stay a shade darker than the hair
        let tint = piece.hasPrefix("hair") ? hairColor(look.heritage, grey: grey)
            : piece.hasPrefix("brows") ? (grey ? UIColor(hex: "#B8B4AE") : hairColor(look.heritage, grey: false)) : .white
        m.baseColor = .init(tint: tint, texture: texture(file, semantic: .color).map { .init($0) })
        if let alpha, let t = texture(alpha, semantic: .raw) {
            m.blending = .transparent(opacity: .init(scale: 1, texture: .init(t)))
            // hair cards fade out in wide see-through margins: cut them, or they haze the forehead
            m.opacityThreshold = piece.hasPrefix("hair") ? 0.3 : 0.05
            // a faint sheen only: see-through hair (acupuncture) keeps its specular and would read as a grey film
            m.specular = .init(floatLiteral: 0.15)
        }
        return m
    }

    /// Hair textures are light grey strands; this is the colour they take.
    private static func hairColor(_ heritage: Heritage, grey: Bool) -> UIColor {
        if grey { return UIColor(hex: "#FFFEFA") }
        return switch heritage {
        case .white: UIColor(hex: "#86674F")
        case .hispanic: UIColor(hex: "#4F3B2E")
        case .southAsian, .southeastAsian: UIColor(hex: "#362B26")
        case .eastAsian, .black: UIColor(hex: "#2E2622")
        }
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
