import Foundation
import simd
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// One posture topic's poses from Resources/Models/postures/<topic>.bin (scripts/models/build_postures.py):
/// the skin figure's positions per key (topology shared with figure.bin), bone transforms per key, soft inner
/// pieces (discs, back muscles, spinal cord) per key, the chair they sit on (if any) and props they hold. Keys blend linearly.
struct PostureModel: Sendable {
    struct Chair: Decodable, Sendable {
        let seatY: Float, seatFront: Float, seatBack: Float, seatWidth: Float
        let backZ: Float, backY: Float, backHeight: Float, backTilt: Float, backWidth: Float
        /// nil: an office chair; "couch"; "floor" (a mat and a wall)
        var kind: String?
        enum CodingKeys: String, CodingKey {
            case seatY = "seat_y", seatFront = "seat_front", seatBack = "seat_back", seatWidth = "seat_width"
            case backZ = "back_z", backY = "back_y", backHeight = "back_height", backTilt = "back_tilt", backWidth = "back_width", kind
        }
    }

    /// something held or leant on (a phone…): its size and its transform per key
    struct Prop: Sendable {
        let size: SIMD3<Float>
        let keys: [simd_float4x4]
        /// opacity per key (empty: always shown)
        var alpha: [Float] = []
    }

    struct Mesh: Sendable {
        let id: String
        /// per key, per vertex
        let keys: [[SIMD3<Float>]]
        let uv: [SIMD2<Float>]
        let index: [UInt32]
        var color: String?
    }

    /// underwear as points in body triangles (a, b, c with weights of a and b), lifted off the skin
    struct Garment: Sendable {
        let id: String
        let color: String
        let abc: [UInt32]
        let w: [SIMD2<Float>]
        /// distance to the garment's edge
        let f: [Float]
        let lift: Float
        /// per vertex, a move in its triangle's frame (empty: none)
        let offset: [Float]
        let index: [UInt32]
    }

    struct Figure: Sendable {
        /// per key, per position vertex (vmap expands them to render vertices)
        let keys: [[SIMD3<Float>]]
        /// rest-pose change from the base heritage to another (head and neck), turned with the head
        let heritage: [String: [SIMD3<Float>]]
        let garments: [Garment]
        /// body options ("chest-small", "hips-large"…): the change each makes to the posed body, per key
        var shapes: [String: [[SIMD3<Float>]]] = [:]
        /// a figure posed its own way (a pregnant slump): its bones, soft pieces and neck lean
        var transforms: [String: [simd_float4x4]]?
        var soft: [Mesh]?
        var neck: [Float]?
    }

    let steps: [Float]
    let chair: Chair?
    let props: [String: Prop]
    let vmap: [UInt32]
    let uv: [SIMD2<Float>]
    let index: [UInt32]
    let figures: [String: Figure]
    /// bone → per key transform
    let transforms: [String: [simd_float4x4]]
    /// rigid inner piece id → its bone
    let rigid: [String: String]
    let soft: [Mesh]
    let focus: [SIMD3<Float>]
    /// forward lean of the neck per key, degrees from the first key
    let neck: [Float]

    // MARK: file

    private struct Header: Decodable {
        struct Block: Decodable { let ref: Int?; let offset: Int; let count: Int; let lo: [Float]; let step: [Float] }
        /// from: another topic's file holds the (shared) topology
        struct Body: Decodable { let vertices: Int; let render: Int; let triangles: Int; let vmap: Int?; let uv: Int?; let index: Int?; let from: String? }
        struct Garment: Decodable { let name: String; let color: String; let vertices: Int; let triangles: Int; let lift: Float; let abc: Int; let w: Int; let f: Int; let index: Int; let offset: Int? }
        struct Sex: Decodable {
            let variant: String; let body: [Int]; let heritage: [String: Int]; let garments: [Garment]
            let transforms: [[String: [Float]]]?; let inner: [Int]?; let neck: [Float]?; let shapes: [String: [Int]]?
        }
        struct Piece: Decodable { let id: String; let start: Int; let count: Int; let triangles: Int; let index: Int }
        struct Inner: Decodable { let count: Int; let blocks: [Int]; let pieces: [Piece] }
        struct Prop: Decodable { let size: [Float]; let keys: [[Float]]; let alpha: [Float]? }
        let steps: [Float]
        let chair: Chair?
        let props: [String: Prop]?
        let body: Body
        let sexes: [String: Sex]
        let rigid: [String: String]
        let transforms: [[String: [Float]]]
        let inner: Inner
        let blocks: [Block]
        let focus: [[Float]]
        let neck: [Float]?
    }

    static func url(_ topic: String) -> URL? {
        if let dir = ProcessInfo.processInfo.environment["BODY_ATLAS_MODELS"] {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("postures/\(topic).bin")
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        return Bundle.main.url(forResource: topic, withExtension: "bin")
    }

    static func load(_ topic: String) -> PostureModel? {
        guard let (h, payload) = read(topic) else { return nil }
        guard let from = h.body.from else { return PostureModel(h, payload, topology: (h, payload)) }
        guard let shared = read(from), shared.0.body.render == h.body.render, shared.0.body.vertices == h.body.vertices else { return nil }
        return PostureModel(h, payload, topology: shared)
    }

    private static func read(_ topic: String) -> (Header, Data)? {
        guard let url = url(topic), let raw = try? Data(contentsOf: url), raw.count > 12, raw.prefix(4) == Data("EBP1".utf8) else { return nil }
        let n = Int(raw.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: UInt32.self) })
        guard let h = try? JSONDecoder().decode(Header.self, from: raw.subdata(in: 12..<12 + n)),
              let payload = try? (raw.subdata(in: 12 + n..<raw.count) as NSData).decompressed(using: .zlib) as Data else { return nil }
        return (h, payload)
    }

    private init(_ h: Header, _ payload: Data, topology: (Header, Data)) {
        func array<T>(_ offset: Int, _ count: Int, in data: Data? = nil) -> [T] {
            (data ?? payload).withUnsafeBytes { raw in (0..<count).map { raw.loadUnaligned(fromByteOffset: offset + $0 * MemoryLayout<T>.stride, as: T.self) } }
        }
        var cache: [Int: [SIMD3<Float>]] = [:]
        func block(_ i: Int) -> [SIMD3<Float>] {
            if let hit = cache[i] { return hit }
            let b = h.blocks[i]
            let d: [Int16] = array(b.offset, b.count * 3)
            let lo = SIMD3(b.lo[0], b.lo[1], b.lo[2]), step = SIMD3(b.step[0], b.step[1], b.step[2])
            var q = SIMD3<Int16>.zero
            var out = [SIMD3<Float>](repeating: .zero, count: b.count)
            for v in 0..<b.count {
                // each vertex is stored as the change from the previous one
                q &+= SIMD3(d[3 * v], d[3 * v + 1], d[3 * v + 2])
                out[v] = (SIMD3<Float>(q) + 32767) * step + lo
            }
            if let ref = b.ref {
                let base = block(ref)
                for v in out.indices { out[v] += base[v] }
            }
            cache[i] = out
            return out
        }
        func uv16(_ offset: Int, _ count: Int, in data: Data? = nil) -> [SIMD2<Float>] {
            let raw: [UInt16] = array(offset, count * 2, in: data)
            return (0..<count).map { SIMD2(Float(raw[2 * $0]) / 65535, Float(raw[2 * $0 + 1]) / 65535) }
        }
        func index16(_ offset: Int, _ triangles: Int, in data: Data? = nil) -> [UInt32] {
            (array(offset, triangles * 3, in: data) as [UInt16]).map(UInt32.init)
        }

        steps = h.steps
        chair = h.chair
        props = (h.props ?? [:]).mapValues { p in
            Prop(size: SIMD3(p.size[0], p.size[1], p.size[2]), keys: p.keys.map { m in
                simd_float4x4(SIMD4(m[0], m[1], m[2], m[3]), SIMD4(m[4], m[5], m[6], m[7]), SIMD4(m[8], m[9], m[10], m[11]), SIMD4(m[12], m[13], m[14], m[15]))
            }, alpha: p.alpha ?? [])
        }
        let (th, tp) = topology
        vmap = (array(th.body.vmap ?? 0, th.body.render, in: tp) as [UInt16]).map(UInt32.init)
        uv = uv16(th.body.uv ?? 0, th.body.render, in: tp)
        index = index16(th.body.index ?? 0, th.body.triangles, in: tp)
        func matrices(_ keys: [[String: [Float]]]) -> [String: [simd_float4x4]] {
            var out: [String: [simd_float4x4]] = [:]
            for key in keys {
                for (bone, m) in key {
                    out[bone, default: []].append(simd_float4x4(SIMD4(m[0], m[1], m[2], m[3]), SIMD4(m[4], m[5], m[6], m[7]),
                                                               SIMD4(m[8], m[9], m[10], m[11]), SIMD4(m[12], m[13], m[14], m[15])))
                }
            }
            return out
        }
        func softPieces(_ blocks: [Int]) -> [Mesh] {
            let all = blocks.map(block)
            return h.inner.pieces.map { p in
                Mesh(id: p.id, keys: all.map { Array($0[p.start..<p.start + p.count]) }, uv: [], index: index16(p.index, p.triangles))
            }
        }
        var figures: [String: Figure] = [:]
        for (sex, s) in h.sexes {
            let garments = s.garments.map { g in
                let w: [Float] = array(g.w, g.vertices * 2)
                return Garment(id: g.name, color: g.color, abc: (array(g.abc, g.vertices * 3) as [UInt16]).map(UInt32.init),
                               w: (0..<g.vertices).map { SIMD2(w[2 * $0], w[2 * $0 + 1]) }, f: array(g.f, g.vertices), lift: g.lift,
                               offset: g.offset.map { array($0, g.vertices * 3) } ?? [], index: index16(g.index, g.triangles))
            }
            figures[sex] = Figure(keys: s.body.map(block), heritage: s.heritage.mapValues(block), garments: garments,
                                  shapes: (s.shapes ?? [:]).mapValues { $0.map(block) },
                                  transforms: s.transforms.map(matrices), soft: s.inner.map(softPieces), neck: s.neck)
        }
        self.figures = figures
        transforms = matrices(h.transforms)
        rigid = h.rigid
        soft = softPieces(h.inner.blocks)
        focus = h.focus.map { SIMD3($0[0], $0[1], $0[2]) }
        neck = h.neck ?? []
    }

    /// the two keys around blend t (0…1) and the weight of the second
    func span(_ t: Float) -> (Int, Int, Float) {
        let t = min(max(t, 0), 1)
        for i in 0..<steps.count - 1 where t <= steps[i + 1] {
            return (i, i + 1, (t - steps[i]) / max(steps[i + 1] - steps[i], 1e-6))
        }
        return (steps.count - 2, steps.count - 1, 1)
    }
}

/// The part of the body a posture topic is about: its discs glow with the load, its muscles with the strain.
enum PostureRegion: Sendable {
    case lumbar, neck, wrist, legs

    var discs: [String] {
        switch self {
        case .lumbar: ["L1", "L2", "L3", "L4", "L5"]
        case .neck: ["C2", "C3", "C4", "C5", "C6", "C7"]
        case .wrist, .legs: []
        }
    }

    /// muscles that strain (nil: every soft muscle)
    var muscles: [String]? {
        switch self {
        case .lumbar: nil
        case .neck: ["splenius", "levator-scapulae"]
        case .wrist: ["levator-scapulae"]
        case .legs: ["gastrocnemius", "soleus"]
        }
    }

    /// soft pieces that glow with the load (the leg veins)
    var vessels: [String] {
        self == .legs ? ["leg-vein", "small-saphenous"] : []
    }

    /// the muscles work at the first end (the calf pump), not the second
    var workAtStart: Bool { self == .legs }

    /// bones that glow with the load
    var bones: [String] {
        switch self {
        case .wrist: ["carpals-l", "carpals-r"]
        default: []
        }
    }
}

/// Load colours shared by the 3D discs and the gauge.
enum PostureColors {
    /// relative disc pressure (standing = 1) → colour: blue lying, green standing, amber sitting tall, red slumped
    static func load(_ load: Float) -> UIColor {
        let stops: [(Float, UIColor)] = [(0.25, UIColor(hex: "#4A90E2")), (1.0, UIColor(hex: "#3DBE6E")), (1.4, UIColor(hex: "#F2B233")),
                                        (1.85, UIColor(hex: "#E5483B")), (2.75, UIColor(hex: "#9E1B32"))]
        guard load > stops[0].0 else { return stops[0].1 }
        for i in 1..<stops.count where load <= stops[i].0 {
            return mix(stops[i - 1].1, stops[i].1, (load - stops[i - 1].0) / (stops[i].0 - stops[i - 1].0))
        }
        return stops.last!.1
    }

    static func mix(_ a: UIColor, _ b: UIColor, _ t: Float) -> UIColor {
        var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        #if canImport(UIKit)
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        #else
        a.usingColorSpace(.sRGB)?.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.usingColorSpace(.sRGB)?.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        #endif
        let k = CGFloat(min(max(t, 0), 1))
        return UIColor(red: r1 + (r2 - r1) * k, green: g1 + (g2 - g1) * k, blue: b1 + (b2 - b1) * k, alpha: 1)
    }
}
