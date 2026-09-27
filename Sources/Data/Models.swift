import Foundation
import simd

/// Decodes `[x, y, z]`.
struct Vec3: Codable, Sendable, Hashable {
    var x: Float, y: Float, z: Float
    var simd: SIMD3<Float> { SIMD3(x, y, z) }

    init(_ x: Float, _ y: Float, _ z: Float) { (self.x, self.y, self.z) = (x, y, z) }

    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        (x, y, z) = (try c.decode(Float.self), try c.decode(Float.self), try c.decode(Float.self))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(x); try c.encode(y); try c.encode(z)
    }
}

// MARK: - Body

enum LayerID: String, Codable, Sendable, CaseIterable {
    case skin, muscular, skeletal, circulatory, nervous, organs
}

enum PartShape: Codable, Sendable, Hashable {
    case sphere(center: Vec3, radius: Float, scale: Vec3?, rotation: Vec3?)
    case box(center: Vec3, size: Vec3, rotation: Vec3?)
    /// capsule between two points
    case segment(from: Vec3, to: Vec3, radius: Float)
    /// ellipsoid stretched between two points — muscle bellies
    case spindle(from: Vec3, to: Vec3, radius: Float)
    /// surface of revolution from → to, radii sampled evenly along the axis; `scale` squashes the cross-section
    case lathe(from: Vec3, to: Vec3, radii: [Float], scale: Vec3?)
    /// tube along a smooth curve; optional per-point radii taper it
    case tube(points: [Vec3], radius: Float, radii: [Float]?)
    /// flat bone: a polygon given a thickness
    case plate(points: [Vec3], thickness: Float)
    /// stacked ellipses along a path — each section is centre + half-width (sideways) + half-depth
    case loft(sections: [[Float]])
    /// flat muscle: a curved slab from a line of origins to its insertions, bowed by `bulge`, thickest mid-belly
    case sheet(origins: [Vec3], insertions: [Vec3], bulge: Vec3, thickness: Float)
    /// muscle lying on the body: a grid of surface points (rows run along the fibres)
    case slab(grid: [[Vec3]], thickness: Float)
    /// many thin branches drawn as one piece (small vessels, nerve roots)
    case tubes(paths: [[Vec3]], radius: Float)

    private enum Key: String, CodingKey {
        case kind, center, radius, scale, size, rotation, from, to, points, radii, thickness, sections, origins, insertions, bulge, grid
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        func v(_ k: Key) throws -> Vec3 { try c.decode(Vec3.self, forKey: k) }
        func f(_ k: Key) throws -> Float { try c.decode(Float.self, forKey: k) }
        switch try c.decode(String.self, forKey: .kind) {
        case "sphere":
            self = .sphere(center: try v(.center), radius: try f(.radius), scale: try c.decodeIfPresent(Vec3.self, forKey: .scale),
                           rotation: try c.decodeIfPresent(Vec3.self, forKey: .rotation))
        case "box":
            self = .box(center: try v(.center), size: try v(.size), rotation: try c.decodeIfPresent(Vec3.self, forKey: .rotation))
        case "segment":
            self = .segment(from: try v(.from), to: try v(.to), radius: try f(.radius))
        case "spindle":
            self = .spindle(from: try v(.from), to: try v(.to), radius: try f(.radius))
        case "lathe":
            self = .lathe(from: try v(.from), to: try v(.to), radii: try c.decode([Float].self, forKey: .radii),
                          scale: try c.decodeIfPresent(Vec3.self, forKey: .scale))
        case "tube":
            self = .tube(points: try c.decode([Vec3].self, forKey: .points), radius: try f(.radius),
                         radii: try c.decodeIfPresent([Float].self, forKey: .radii))
        case "loft":
            self = .loft(sections: try c.decode([[Float]].self, forKey: .sections))
        case "tubes":
            self = .tubes(paths: try c.decode([[Vec3]].self, forKey: .grid), radius: try f(.radius))
        case "slab":
            self = .slab(grid: try c.decode([[Vec3]].self, forKey: .grid), thickness: try f(.thickness))
        case "sheet":
            self = .sheet(origins: try c.decode([Vec3].self, forKey: .origins), insertions: try c.decode([Vec3].self, forKey: .insertions),
                          bulge: try v(.bulge), thickness: try f(.thickness))
        default:
            self = .plate(points: try c.decode([Vec3].self, forKey: .points), thickness: try f(.thickness))
        }
    }

    func encode(to encoder: Encoder) throws {}
}

struct SchematicPart: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let nameZh: String
    let layer: LayerID
    let color: String
    let shape: PartShape
    /// "male" / "female" for sex-specific skin; nil = both
    let sex: String?
}

struct Joint: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let nameZh: String
    let pivot: Vec3
    let axis: Vec3
    let maxDeg: Float
    let parent: String?
    let parts: [String]
    let movers: [String]
}

struct LayerInfo: Codable, Sendable, Identifiable {
    let id: LayerID
    let label: String
    let labelZh: String
}

struct Organ: Codable, Sendable, Identifiable {
    struct Variant: Codable, Sendable {
        let position: Vec3
        let color: String
        let shapes: [PartShape]
    }
    let id: String
    let color: String
    /// where a reflex pulse lands
    let position: Vec3
    let shapes: [PartShape]
    let names: [String]?
    /// a region, invisible until it lights up
    let region: Bool?
    /// male variant (prostate) where it differs
    let male: Variant?
}

struct BodyData: Codable, Sendable {
    let parts: [SchematicPart]
    let joints: [Joint]
    let layers: [LayerInfo]
    let defaultLayers: [String: [LayerID]]
    let organs: [Organ]
}

// MARK: - Points

struct ReflexTarget: Codable, Sendable {
    let name: String
    let nameZh: String
    let effect: String
    let effectZh: String
    let organIds: [String]
}

struct BodyPoint: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let nameZh: String
    let description: String
    let descriptionZh: String
    let region: String?
    let position: Vec3
    let target: ReflexTarget?
    let acu: Acupoint?
}

/// An acupuncture point (WHO 2008): `description` holds its location.
struct Acupoint: Codable, Sendable {
    let code: String
    let meridian: String
    let pinyin: String
    let uses: String
    let usesZh: String
    let needling: String
    let needlingZh: String
    let organIds: [String]
    /// among the points most often needled in practice
    let common: Bool
    /// outward direction of the skin at the point — the camera turns to face it
    let normal: Vec3
    /// left (and right, for paired points) on the male / child body
    let sites: [Vec3]
    let femaleSites: [Vec3]?
    let aliases: [String]?

    func sites(female: Bool) -> [Vec3] { female ? femaleSites ?? sites : sites }
}

/// A channel drawn on the skin; each piece is one region's paths (so it follows that region's age scaling).
struct Meridian: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let nameZh: String
    let color: String
    let pieces: [[[Vec3]]]
    let femalePieces: [[[Vec3]]]?

    func pieces(female: Bool) -> [[[Vec3]]] { female ? femalePieces ?? pieces : pieces }
}

struct SystemPoints: Codable, Sendable {
    struct Flow: Codable, Sendable {
        let kind: String
        let pointIds: [String]
    }
    let points: [BodyPoint]
    let flow: Flow?
    let meridians: [Meridian]?
}

// MARK: - Charts

struct ZoneGroup: Codable, Sendable {
    let label: String
    let labelZh: String
    let color: String
}

struct ChartEllipse: Codable, Sendable {
    let cx: Double, cy: Double, rx: Double, ry: Double
    let rot: Double?
}

struct OutlineShape: Codable, Sendable {
    let kind: String
    let x: Double?, y: Double?, w: Double?, h: Double?, r: Double?
    let rot: Double?, ox: Double?, oy: Double?
    let d: String?
    /// nil = silhouette; otherwise a shading layer drawn on it ("shade", "deep", "nail", "light")
    let tone: String?
}

enum Side: String, Codable, Sendable, CaseIterable {
    case left, right
}

struct ReflexZone: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let nameZh: String
    let label: String?
    /// SVG d; drawn and hit-tested instead of `shapes` when present
    let path: String?
    let shapes: [ChartEllipse]?
    let group: String
    let organIds: [String]
    let effect: String
    let effectZh: String
    let side: Side?
    let point: Bool?
}

struct ChartFace: Codable, Sendable, Identifiable {
    let id: String
    let label: String
    let labelZh: String
    let drawnSide: Side
    let outline: [OutlineShape]
    let guides: [String]
    let bones: [String]
    let zones: [ReflexZone]
}

struct ReflexChart: Codable, Sendable, Identifiable {
    let id: String
    let title: String
    let titleZh: String
    let viewBox: [Double]
    let mirrorWidth: Double
    let labelSize: Double
    let faces: [ChartFace]
    let anchors: [String: Vec3]
}

struct ChartData: Codable, Sendable {
    let groups: [String: ZoneGroup]
    let charts: [ReflexChart]
}

// MARK: - Systems

struct BodySystem: Codable, Sendable, Identifiable {
    struct Info: Codable, Sendable {
        struct Link: Codable, Sendable {
            let label: String
            let route: String
        }
        let summary: String
        let summaryZh: String
        let facts: [[String]]
        let links: [Link]
    }
    let id: String
    let name: String
    let nameZh: String
    let color: String
    let info: Info?
}
