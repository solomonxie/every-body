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
    /// false for the App Store build: adults keep their underwear on, opaque; true restores the Clothing toggle
    static let clothingOptional = false

    struct Look: Hashable {
        var female: Bool
        var age: AgeGroup
        var pregnant: Bool
        var heritage: Heritage
        var underwear: Bool
        var chest: BodySize = .small
        var hips: BodySize = .medium
    }

    private struct Header: Decodable {
        struct Piece: Decodable { let vertices: Int; let render: Int; let triangles: Int; let uv: Int; let vmap: Int; let index: Int }
        struct Block: Decodable { let ref: Int?; let offset: Int; let count: Int; let lo: [Float]; let step: [Float] }
        /// vertices lie in body triangles abc (weights w of a and b); f: distance to the garment edge
        struct Garment: Decodable {
            let vertices: Int; let triangles: Int; let abc: Int; let w: Int; let f: Int; let index: Int; let lift: Float; let color: String
            /// per vertex, a move in its triangle's frame (first edge, across, normal): the cups' stand-off
            let offset: Int?
        }
        let pieces: [String: Piece]
        let blocks: [Block]
        let variants: [String: [String: Int]]
        let garments: [String: Garment]
        /// adult female body options: position deltas on the body ("chest-small", "hips-large", …)
        let shapes: [String: Int]?
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
            var positions = reader.positions(block)
            if name == "body" && look.female && look.age == .adult {
                // (the bump keeps the default lower body)
                for shape in ["chest-\(look.chest.rawValue)"] + (look.pregnant ? [] : ["hips-\(look.hips.rawValue)"]) {
                    guard let i = header.shapes?[shape] else { continue }
                    for (v, d) in reader.positions(i).enumerated() { positions[v] += d }
                }
            }
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
            // the skin shades with its normals evened out a little (garments and points keep the plain ones)
            let shade = name == "body" ? Self.normals(positions, vmap: vmap, index: index, blur: 2) : normals
            d.normals = MeshBuffers.Normals(vmap.map { shade[Int($0)] })
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
            case .adult, .senior: look.female ? [look.pregnant ? "briefs-pregnant" : "briefs-female", "bra"] : ["briefs-male"]
            }
            for name in names {
                // the bra cut for the chest option (the large one is the base)
                let cut = name != "bra" ? name : look.age == .senior ? "bra-senior" : look.age == .adult && look.chest != .large ? "bra-\(look.chest.rawValue)" : name
                guard let g = header.garments[cut] ?? header.garments[name] else { continue }
                if let mesh = garment(g, reader: reader, body: body) {
                    var m = PhysicallyBasedMaterial()
                    m.baseColor = .init(tint: UIColor(hex: ProcessInfo.processInfo.environment["GARMENT_COLOR"] ?? g.color), texture: texture("fabric.png", semantic: .color).map { .init($0) })
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

    /// Smooth normals per position (shared across UV seams), averaged with their neighbours' `blur` times: the
    /// skin's coarse facets (shoulders, neck) shade as one curve.
    private static func normals(_ p: [SIMD3<Float>], vmap: [UInt32], index: [UInt32], blur: Int = 0) -> [SIMD3<Float>] {
        var n = [SIMD3<Float>](repeating: .zero, count: p.count)
        for t in stride(from: 0, to: index.count, by: 3) {
            let a = Int(vmap[Int(index[t])]), b = Int(vmap[Int(index[t + 1])]), c = Int(vmap[Int(index[t + 2])])
            let f = simd_cross(p[b] - p[a], p[c] - p[a])
            n[a] += f; n[b] += f; n[c] += f
        }
        n = n.map { simd_length($0) > 0 ? simd_normalize($0) : SIMD3(0, 1, 0) }
        for _ in 0..<blur {
            var m = n
            for t in stride(from: 0, to: index.count, by: 3) {
                let a = Int(vmap[Int(index[t])]), b = Int(vmap[Int(index[t + 1])]), c = Int(vmap[Int(index[t + 2])])
                m[a] += n[b] + n[c]; m[b] += n[a] + n[c]; m[c] += n[a] + n[b]
            }
            n = m.map { simd_length($0) > 0 ? simd_normalize($0) : SIMD3(0, 1, 0) }
        }
        return n
    }

    /// hem width (scene units) the fabric texture spans, from the garment's edge inward
    private static let hem: Float = 0.025

    /// A thin shell on the body, pushed out along the skin's normal; its edge hugs the skin.
    private static func garment(_ g: Header.Garment, reader: Reader, body: (positions: [SIMD3<Float>], normals: [SIMD3<Float>])) -> MeshResource? {
        let abc: [UInt32] = reader.array(g.abc, count: g.vertices * 3)
        let w: [Float] = reader.array(g.w, count: g.vertices * 2)
        let f: [Float] = reader.array(g.f, count: g.vertices)
        let offset: [Float] = g.offset.map { reader.array($0, count: g.vertices * 3) } ?? []
        var positions: [SIMD3<Float>] = [], normals: [SIMD3<Float>] = [], uv: [SIMD2<Float>] = []
        for v in 0..<g.vertices {
            let a = Int(abc[3 * v]), b = Int(abc[3 * v + 1]), c = Int(abc[3 * v + 2])
            let wa = w[2 * v], wb = w[2 * v + 1], wc = max(0, 1 - wa - wb)
            let n = simd_normalize(wa * body.normals[a] + wb * body.normals[b] + wc * body.normals[c])
            let edge = min(f[v] / 0.01, 1)
            // (a stored move replaces the lift: it carries its own)
            let move = offset.isEmpty ? .zero : frameOffset(offset, v, body.positions[a], body.positions[b], body.positions[c], side: n)
            let base = wa * body.positions[a] + wb * body.positions[b] + wc * body.positions[c]
            positions.append(base + (move == .zero ? n * g.lift * (0.8 + 0.2 * edge) : move))
            normals.append(n)
            uv.append(SIMD2(min(f[v] / hem, 0.97), 0.5))  // not 1: the sampler wraps
        }
        let index: [UInt32] = reader.array(g.index, count: g.triangles * 3)
        if !offset.isEmpty { normals = surfaceNormals(positions, index, fallback: normals, offset: offset) }
        var d = MeshDescriptor(name: "underwear")
        d.positions = MeshBuffers.Positions(positions)
        d.normals = MeshBuffers.Normals(normals)
        d.textureCoordinates = MeshBuffers.TextureCoordinates(uv)
        d.primitives = .triangles(index)
        return try? MeshResource.generate(from: [d])
    }

    /// vertex v's stored move in its triangle's own frame (first edge, across, the triangle's normal turned to `side`)
    static func frameOffset(_ o: [Float], _ v: Int, _ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, side: SIMD3<Float>) -> SIMD3<Float> {
        let x = o[3 * v], y = o[3 * v + 1], z = o[3 * v + 2]
        guard x != 0 || y != 0 || z != 0 else { return .zero }
        let t1 = simd_normalize(b - a)
        var nt = simd_normalize(simd_cross(b - a, c - a))
        if simd_dot(nt, side) < 0 { nt = -nt }
        return x * t1 + y * simd_cross(nt, t1) + z * nt
    }

    /// a garment with its own shape (the bra's cups) shades as its own surface
    static func surfaceNormals(_ p: [SIMD3<Float>], _ index: [UInt32], fallback: [SIMD3<Float>], offset: [Float]) -> [SIMD3<Float>] {
        var n = [SIMD3<Float>](repeating: .zero, count: p.count)
        for t in stride(from: 0, to: index.count - 2, by: 3) {
            let a = Int(index[t]), b = Int(index[t + 1]), c = Int(index[t + 2])
            let f = simd_cross(p[b] - p[a], p[c] - p[a])
            n[a] += f; n[b] += f; n[c] += f
        }
        return n.indices.map { i in
            let l = simd_length(n[i])
            guard l > 0 else { return fallback[i] }
            return n[i] / l
        }
    }

    private static func material(_ piece: String, look: Look, kid: Bool) -> PhysicallyBasedMaterial {
        if piece.hasSuffix(".shell") { return hairShellMaterial(look) }
        if piece.hasPrefix("hair") { return sculptedHairMaterial(look) }
        var m = PhysicallyBasedMaterial()
        m.metallic = .init(floatLiteral: 0)
        m.roughness = .init(floatLiteral: piece == "eyes" ? 0.3 : piece == "body" ? 0.55 : 0.75)
        // skin reflects ~3% head-on (RealityKit's default 0.5 is 4%, reads as plastic)
        if piece == "body" { m.specular = .init(floatLiteral: 0.35) }
        if piece == "eyes" {
            // a moist eye: one soft catch-light, not a glassy sheen
            m.specular = .init(floatLiteral: 0.5)
            m.clearcoat = .init(floatLiteral: 0.5)
            m.clearcoatRoughness = .init(floatLiteral: 0.08)
        }
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
        // brows are grey strands, coloured here; a senior's brows stay a shade darker than the hair
        let tint = piece.hasPrefix("brows") ? (grey ? UIColor(hex: "#B8B4AE") : browColor(look.heritage))
            : piece.hasPrefix("lashes") ? UIColor(hex: look.female && !kid ? "#2A2522" : "#4A4440") : .white
        m.baseColor = .init(tint: tint, texture: texture(file, semantic: .color).map { .init($0) })
        if let alpha, let t = texture(alpha, semantic: .raw) {
            // a woman's brows: a soft fill, a little lighter, its edge fading out (no cut-off line)
            let softBrow = piece.hasPrefix("brows") && (look.female || look.age == .infant || look.age == .toddler)
            // a baby's brows are faint
            let faint: Float = piece.hasPrefix("brows") ? (look.age == .infant ? 0.1 : look.age == .toddler ? 0.45 : 1) : 1
            m.blending = .transparent(opacity: .init(scale: faint, texture: .init(t)))
            m.opacityThreshold = softBrow ? 0.005 : 0.05
            // a faint sheen only: see-through hair (acupuncture) keeps its specular and would read as a grey film
            m.specular = .init(floatLiteral: 0.15)
        }
        return m
    }

    /// Strand cards (hair-strands.jpg + -alpha.jpg: grey strands, darker roots, lighter tips, a baked sheen band):
    /// tinted per heritage, blended strand by strand (cards come inner layers first), matte with a faint streaked sheen.
    private static func hairMaterial(_ look: Look) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.metallic = .init(floatLiteral: 0)
        m.baseColor = .init(tint: hairColor(look.heritage, grey: look.age == .senior), texture: texture("hair-strands.jpg", semantic: .color).map { .init($0) })
        if let t = texture("hair-strands-alpha.jpg", semantic: .raw) {
            m.blending = .transparent(opacity: .init(scale: 1, texture: .init(t)))
            m.opacityThreshold = 0.02
        }
        m.roughness = .init(floatLiteral: 0.85)
        m.specular = .init(floatLiteral: 0.04)
        m.anisotropyLevel = .init(floatLiteral: 0.85)
        m.faceCulling = .none
        return m
    }

    /// Sculpted hair: one smooth solid, soft sheen, faint streaks down it (seniors: dark and white strands through the grey).
    private static func sculptedHairMaterial(_ look: Look) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        let grey = look.age == .senior
        m.baseColor = .init(tint: hairColor(look.heritage, grey: grey), texture: texture(grey ? "hair-sculpt-grey.jpg" : "hair-sculpt.jpg", semantic: .color).map { .init($0) })
        // a broad soft highlight and a faint velvet rim, not one hard hotspot (reads as plastic)
        m.roughness = .init(floatLiteral: 0.7)
        m.specular = .init(floatLiteral: 0.16)
        m.sheen = .init(tint: UIColor(white: 0.2, alpha: 1))
        m.metallic = .init(floatLiteral: 0)
        return m
    }

    /// The opaque layer under the strand cards: the hair's own colour, matte.
    private static func hairShellMaterial(_ look: Look) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: hairColor(look.heritage, grey: look.age == .senior), texture: texture("hair-strands.jpg", semantic: .color).map { .init($0) })
        m.roughness = .init(floatLiteral: 0.9)
        m.specular = .init(floatLiteral: 0.05)
        m.metallic = .init(floatLiteral: 0)
        return m
    }

    /// Hair is lit as one soft volume: normals point out from the head (sideways below it), not per card.
    private static func hairNormals(_ p: [SIMD3<Float>]) -> [SIMD3<Float>] {
        guard let first = p.first else { return [] }
        var lo = first, hi = first
        for q in p { lo = simd_min(lo, q); hi = simd_max(hi, q) }
        let depth = hi.z - lo.z
        let c = SIMD3((lo.x + hi.x) / 2, hi.y - 0.5 * depth, (lo.z + hi.z) / 2)
        return p.map { q in
            var d = q - c
            d.y = d.y < 0 ? 0.35 * d.y : d.y
            return simd_length(d) > 0 ? simd_normalize(d) : SIMD3(0, 1, 0)
        }
    }

    /// Per vertex: the direction the strand runs (the cards' v), for the stretched sheen.
    private static func hairTangents(_ d: MeshDescriptor, index: [UInt32]) -> [SIMD3<Float>] {
        let p = Array(d.positions), uv = Array(d.textureCoordinates ?? .init([]))
        var t = [SIMD3<Float>](repeating: .zero, count: p.count)
        for i in stride(from: 0, to: index.count, by: 3) {
            let a = Int(index[i]), b = Int(index[i + 1]), c = Int(index[i + 2])
            let e1 = p[b] - p[a], e2 = p[c] - p[a], d1 = uv[b] - uv[a], d2 = uv[c] - uv[a]
            let det = d1.x * d2.y - d2.x * d1.y
            guard abs(det) > 1e-12 else { continue }
            let dv = (e2 * d1.x - e1 * d2.x) / det
            t[a] += dv; t[b] += dv; t[c] += dv
        }
        return t.map { simd_length($0) > 0 ? simd_normalize($0) : SIMD3(0, -1, 0) }
    }

    /// Hair colour per heritage (strands are light grey, tinted by it); seniors silver.
    private static func hairColor(_ heritage: Heritage, grey: Bool) -> UIColor {
        if grey { return UIColor(hex: "#ECE8E2") }
        return switch heritage {
        case .white: UIColor(hex: "#E2BE8A")
        case .hispanic: UIColor(hex: "#58412F")
        case .southAsian, .southeastAsian: UIColor(hex: "#4E3E35")
        case .eastAsian: UIColor(hex: "#2B2522")
        case .black: UIColor(hex: "#40352F")
        }
    }

    private static func browColor(_ heritage: Heritage) -> UIColor {
        switch heritage {
        case .white: UIColor(hex: "#9C7A52")
        case .hispanic: UIColor(hex: "#3A2B22")
        case .southAsian, .southeastAsian: UIColor(hex: "#362B26")
        case .eastAsian: UIColor(hex: "#2E2724")
        case .black: UIColor(hex: "#3A2F2A")
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
