import RealityKit
import simd
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Who is being resuscitated: sets depth, hand position, head tilt and pad sizes.
enum CPRVictim: Sendable {
    case adult, child, infant

    init(_ age: AgeGroup) {
        switch age {
        case .infant: self = .infant
        case .toddler, .child: self = .child
        case .adult, .senior: self = .adult
        }
    }

    /// compression depth band, cm
    var depth: ClosedRange<Float> {
        switch self {
        case .adult: 5...6
        case .child: 4.5...5.5
        case .infant: 3.5...4.5
        }
    }

    /// full head tilt, degrees (infant: neutral "sniffing" position)
    var tilt: Float {
        switch self { case .adult: 32; case .child: 20; case .infant: 8 }
    }

    /// hand placement accepted within this distance of the target, cm
    var tolerance: Float {
        switch self { case .adult: 2.5; case .child: 2; case .infant: 1.5 }
    }

    /// AED pad size, cm
    var pad: SIMD2<Float> {
        switch self { case .adult: SIMD2(13, 9); case .child: SIMD2(10, 7); case .infant: SIMD2(6.5, 4.5) }
    }
}

/// Body parts the trainer recognises under a tap.
enum CPRSpot: Equatable {
    case shoulder, feet, forehead, chin, mouth, chest, belly, other
}

/// The 3D CPR trainer: the figure on its back on the floor (an infant on a table), rescuer's hands, AED pads,
/// and the chest, head and bump moved by the step being practised.
@MainActor
final class CPRTrainerScene {
    /// world units per centimetre (adult figure ≈ 3.25 units tall ≈ 175 cm)
    static let cm: Float = 3.25 / 175

    let body = BodyScene()
    let root = Entity()
    let victim: CPRVictim
    let pregnant: Bool
    private(set) var ready = false
    private var female = false

    // driven by the coach
    var depthCm: Float = 0
    var breath: Float = 0
    var tilt: Float = 0
    var bump: Float = 0
    var glass = false { didSet { if glass != oldValue { applyLayers(); applyGloves() } } }

    // camera orbit around `focus` (world)
    var azimuth: Float = 0.95
    var elevation: Float = 0.8
    var distance: Float = 2.4
    var zoom: Float = 1
    /// one-finger slide of the view, in world units across the screen plane
    var panOffset = SIMD3<Float>.zero
    /// eased toward when set (a step that needs a higher view)
    var goalElevation: Float?
    private var goalFocus: SIMD3<Float>?
    private var goalDistance: Float?
    private var homeFocus = SIMD3<Float>.zero
    private var homeDistance: Float = 1

    /// Pull back to show the whole body, head to feet, or come back to the chest.
    /// screen right and up in world, for sliding the view under a finger
    var screenAxes: (right: SIMD3<Float>, up: SIMD3<Float>) {
        let forward = -simd_normalize(SIMD3(-cos(elevation) * cos(azimuth), sin(elevation), cos(elevation) * sin(azimuth)))
        let right = simd_normalize(simd_cross(forward, SIMD3(0, 1, 0)))
        return (right, simd_cross(right, forward))
    }

    func frameWhole(_ whole: Bool) {
        panOffset = .zero
        // the feet are nearer the camera and look longer: aim a little below the middle and stand further back
        let length = marks.headTop - marks.feetY
        let mid = world(SIMD3(0, marks.feetY + length * 0.42, marks.target.z * 0.5))
        goalFocus = whole ? mid : homeFocus
        goalDistance = whole ? Self.fit(length * scale) * 1.25 : homeDistance
    }

    /// camera distance at which a length (world) spans 80% of the 40° view
    private static func fit(_ length: Float) -> Float { length / 2 / tan(20 * .pi / 180) / 0.8 }
    private var focus = SIMD3<Float>(0, 0, 0)

    struct Landmarks {
        var target = SIMD3<Float>.zero, targetNormal = SIMD3<Float>(0, 0, 1)
        var shoulders: [SIMD3<Float>] = []
        var feet = SIMD3<Float>.zero
        var forehead = SIMD3<Float>.zero, chin = SIMD3<Float>.zero, mouth = SIMD3<Float>.zero
        var belly = SIMD3<Float>.zero
        var sternumTop: Float = 0, sternumBottom: Float = 0
        var halfWidth: Float = 0.2, chestDepth: Float = 0.3, backZ: Float = -0.15
        var heart = SIMD3<Float>.zero, brain = SIMD3<Float>.zero
        var pads: [(point: SIMD3<Float>, normal: SIMD3<Float>, axis: SIMD3<Float>)] = []
        var floorZ: Float = -0.2
        var feetY: Float = -1.6
        var headTop: Float = 1.65
        var minX: Float = -0.6, maxX: Float = 0.6
    }

    private(set) var marks = Landmarks()
    private var rig: Entity { skin?.entity.parent ?? body.root }
    private var scale: Float = 1
    private var skin: SkinDeformer?
    private var garments: [SkinDeformer] = []
    private var fields: Fields?
    private var headRigid: [(Entity, float4x4, Float)] = []
    private var chestRigid: [(Entity, float4x4, Float)] = []
    private var lungs: [(Entity, float4x4)] = []
    private var heart: (Entity, float4x4)?
    private var bumpRigid: [(Entity, float4x4)] = []
    private var applied: SIMD4<Float> = SIMD4(repeating: -1)
    private var clock: Float = 0

    // overlay (children of body.root; placed in root space = rig coords × scale)
    private let hands = Entity()
    private let bumpHand = Entity()
    private let ring = ModelEntity()
    private let tapDot = ModelEntity()
    private var hintRings: [ModelEntity] = []
    private var tapTime: Float = -10
    private(set) var padEntities: [Entity] = []
    private var padGhosts: [ModelEntity] = []
    /// pad → target index it sits on
    private(set) var padPlaced: [Int?] = [nil, nil]
    private var flowDots: [ModelEntity] = []
    private var flowPath: [SIMD3<Float>] = []
    private var flowStart: Float = -10
    private var shakeStart: Float = -10
    private var joltStart: Float = -10
    private var rootRest = Transform.identity
    private var bumpEdge: (SIMD3<Float>, SIMD3<Float>) = (.zero, SIMD3(0, 0, 1))
    private var bumpCore = SIMD3<Float>.zero
    private var bumpPlaced: Float = -1
    /// gloves: fingers across the chest toward her left (x → her feet); infant grip: x → her left
    private var handAxis: SIMD3<Float> { victim == .infant ? SIMD3(1, 0, 0) : SIMD3(0, -1, 0) }

    var showHands = false { didSet { hands.isEnabled = showHands } }
    var showRing = false { didSet { ring.isEnabled = showRing } }
    var ringGood = false { didSet { if ringGood != oldValue { ring.model?.materials = [Self.ringMaterial(ringGood)] } } }
    var showPads = false { didSet { for p in padEntities { p.isEnabled = showPads }; updateGhosts() } }

    init(victim: CPRVictim, pregnant: Bool) {
        self.victim = victim
        self.pregnant = pregnant && victim == .adult
    }

    // MARK: build

    func build(female: Bool, heritage: Heritage, age: AgeGroup, chest: BodySize = .small, hips: BodySize = .medium) {
        body.chest = chest
        body.hips = hips
        self.female = female && victim == .adult
        body.heritage = heritage
        body.underwear = true
        body.setAge(age)
        body.build(skinColor: UIColor(hex: "#F2C9A5"), female: female, pregnant: pregnant, points: [], flowStops: [])
        body.touched = true
        applyLayers()

        // one world: the body's own camera, new lights and a floor
        root.children.removeAll()
        body.root.children.filter { $0 is DirectionalLight }.forEach { $0.removeFromParent() }
        body.camera.removeFromParent()
        body.camera.camera.fieldOfViewInDegrees = 40
        body.camera.camera.fieldOfViewOrientation = .vertical
        root.addChild(body.camera)
        root.addChild(body.root)
        addLights()

        guard let skinEntity = body.root.findEntity(named: "skin:body") as? ModelEntity, let skin = SkinDeformer(skinEntity) else { return }
        self.skin = skin
        garments = rig.children.compactMap { e in
            guard e.name.hasPrefix("skin:underwear"), let m = e as? ModelEntity else { return nil }
            return SkinDeformer(m)
        }
        scale = rig.scale.x
        // bounds of hidden parts read empty: show everything while measuring
        body.setLayers([.skin, .skeletal, .organs])
        body.setParts(PartState(), selected: nil)
        findLandmarks()
        // her right flank of the bump, facing out and up
        // bump: its fullest height, then out through her right flank at mid-height
        var apex = marks.belly
        for k in 0...16 {
            let p = surface(x: 0, y: marks.sternumBottom - 0.1 - Float(k) * 0.03).0
            if p.z > apex.z { apex = p }
        }
        bumpCore = SIMD3(0, apex.y - 0.1, marks.backZ + (apex.z - marks.backZ) * 0.5)
        bumpEdge = surface(y: apex.y, from: bumpCore, outward: SIMD3(-1, 0, 0.35))

        // on its back: body front (+z) up, head toward -z; back on the floor (y = 0)
        body.root.orientation = simd_quatf(angle: -.pi / 2, axis: SIMD3(1, 0, 0))
        body.root.position = SIMD3(0, -marks.floorZ * scale, 0)
        rootRest = body.root.transform
        addFloor()
        collectRigid()
        applyLayers()
        fields = Fields(scene: self)
        buildOverlay()
        // head to chest in view; a pregnant woman's bump too
        // head to hips fill ~80% of the (portrait) height, head up
        // head to mid-thigh, running diagonally across the portrait view
        let thigh = marks.feetY + (marks.headTop - marks.feetY) * 0.33
        focus = world(SIMD3(0, (marks.headTop + thigh) / 2, marks.backZ + marks.chestDepth * 0.4))
        distance = Self.fit((marks.headTop - thigh) * scale) * 1.02
        homeFocus = focus
        homeDistance = distance
        // it opens on the whole body (checking for a response), then comes in to the chest
        frameWhole(true)
        focus = goalFocus ?? focus
        distance = goalDistance ?? distance
        ready = true
        update(dt: 0)
    }

    private func applyLayers() {
        body.setLayers(glass ? [.skin, .skeletal, .organs] : [.skin])
        // chest organs only: the belly's organs would hide the heart and lungs
        let keep: Set<String> = ["heart", "lung-l", "lung-r", "brain", "uterus", "fetus", "placenta"]
        body.setParts(PartState(hidden: Set(Catalog.body.organs.map(\.id)).subtracting(keep)), selected: nil)
    }

    /// see-through gloves over a see-through body, so the heart shows
    private func applyGloves() {
        func walk(_ e: Entity) {
            if let m = e as? ModelEntity, ["glove", "forearm"].contains(e.name), var mat = m.model?.materials.first as? PhysicallyBasedMaterial {
                let forearm = e.name == "forearm"
                // see-through: faint gloves so the sternum and heart show under them
                let faint: Float = forearm ? (glass ? 0.15 : 0.35) : 0.3
                mat.blending = glass || forearm ? .transparent(opacity: .init(floatLiteral: faint)) : .opaque
                m.model?.materials = [mat]
            }
            e.children.forEach(walk)
        }
        walk(hands)
        walk(bumpHand)
    }

    private func addLights() {
        let key = DirectionalLight()
        key.light.intensity = 3200
        key.shadow = DirectionalLightComponent.Shadow(maximumDistance: 6, depthBias: 2)
        key.look(at: .zero, from: SIMD3(-2.5, 6, 1.5), relativeTo: nil)
        root.addChild(key)
        let fill = DirectionalLight()
        fill.light.intensity = 1300
        fill.look(at: .zero, from: SIMD3(3, 3, 2), relativeTo: nil)
        root.addChild(fill)
        let rim = DirectionalLight()
        rim.light.intensity = 900
        rim.look(at: .zero, from: SIMD3(0.5, 2, -5), relativeTo: nil)
        root.addChild(rim)
    }

    private func addFloor() {
        let floor = ModelEntity(mesh: .generatePlane(width: 30, depth: 30), materials: [Self.flat("#D2D0CB", roughness: 1)])
        root.addChild(floor)
        let c = Self.cm
        if victim == .infant {
            // a table: top at the floor plane, legs under it
            let top = SIMD3<Float>(60 * c, 3 * c, 90 * c)
            let table = ModelEntity(mesh: .generateBox(size: top, cornerRadius: 0.8 * c), materials: [Self.flat("#B98E63", roughness: 0.6)])
            table.position = SIMD3(0, -top.y / 2, focusZ())
            root.addChild(table)
            floor.position.y = -75 * c
            for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
                let leg = ModelEntity(mesh: .generateBox(size: SIMD3(4 * c, 72 * c, 4 * c)), materials: [Self.flat("#9C7552", roughness: 0.6)])
                leg.position = SIMD3(sx * 26 * c, -39 * c, focusZ() + sz * 40 * c)
                root.addChild(leg)
            } }
            let blanket = ModelEntity(mesh: .generateBox(size: SIMD3(40 * c, 0.6 * c, 62 * c), cornerRadius: 0.3 * c), materials: [Self.flat("#E8E2F2", roughness: 0.95)])
            blanket.position = SIMD3(0, 0.3 * c, focusZ())
            root.addChild(blanket)
        } else {
            // a mat just bigger than the body, rounded corners
            let w = (marks.maxX - marks.minX) * scale + 24 * c, len = (marks.headTop - marks.feetY) * scale + 26 * c
            let mat = ModelEntity(mesh: .generateBox(size: SIMD3(w, 1.2 * c, len), cornerRadius: 0.6 * c), materials: [Self.flat("#8A95A3", roughness: 0.95)])
            let mid = world(SIMD3(0, (marks.headTop + marks.feetY) / 2, 0))
            mat.position = SIMD3(0, 0.1 * c, mid.z)
            root.addChild(mat)
            // the rescuer's knees, faint, beside the chest
            var knee = PhysicallyBasedMaterial()
            knee.baseColor = .init(tint: UIColor(hex: "#4A515C"))
            knee.roughness = .init(floatLiteral: 1)
            knee.blending = .transparent(opacity: .init(floatLiteral: 0.18))
            let chest = world(SIMD3(marks.minX * 0.55, marks.target.y, 0))
            for dz: Float in [-13, 13] {
                let shin = Self.capsule(SIMD3(chest.x - 34 * c * scale.squareRoot() - 22 * c, 6 * c, chest.z + dz * c), radius: 6 * c, length: 44 * c,
                                        along: SIMD3(1, 0, 0), material: knee)
                shin.name = "knee"
                root.addChild(shin)
            }
        }
        // lift the body onto the mat/blanket top
        body.root.position.y += (victim == .infant ? 0.6 : 0.7) * c
        rootRest = body.root.transform
    }

    private func focusZ() -> Float { world(SIMD3(0, (marks.target.y + marks.chin.y) / 2, 0)).z }

    // MARK: landmarks

    private func bounds(_ name: String) -> BoundingBox? {
        guard let skin, let e = rig.findEntity(named: name) else { return nil }
        let b = e.visualBounds(relativeTo: skin.entity)
        return b.isEmpty ? nil : b
    }

    /// front-most skin point near (x, y), with its normal
    func surface(x: Float, y: Float, front: Bool = true) -> (SIMD3<Float>, SIMD3<Float>) {
        guard let skin else { return (SIMD3(x, y, 0), SIMD3(0, 0, 1)) }
        let dir: Float = front ? -1 : 1
        guard let hit = skin.intersect(origin: SIMD3(x, y, -dir * 3), direction: SIMD3(0, 0, dir)) else { return (SIMD3(x, y, 0), SIMD3(0, 0, -dir)) }
        return (hit.point, hit.normal)
    }

    /// skin point met coming in toward the middle of the trunk along -dir (at height y)
    private func surface(y: Float, along dir: SIMD3<Float>) -> (SIMD3<Float>, SIMD3<Float>) {
        let centre = SIMD3(0, y, marks.backZ + marks.chestDepth * 0.5)
        guard let skin, let hit = skin.intersect(origin: centre + dir * 3, direction: -dir) else { return (centre + dir * 0.2, dir) }
        return (hit.point, hit.normal)
    }

    /// skin met going out from inside the trunk at height y (never an arm lying against the side)
    private func surface(y: Float, from core: SIMD3<Float>? = nil, outward dir: SIMD3<Float>) -> (SIMD3<Float>, SIMD3<Float>) {
        let o = core ?? SIMD3(0, y, marks.backZ + marks.chestDepth * 0.45)
        guard let skin, let hit = skin.intersect(origin: o, direction: simd_normalize(dir)) else { return (o + dir * 0.2, dir) }
        return (hit.point, hit.normal)
    }

    /// outermost skin point at height y on one side (the chest wall, not the arm)
    private func side(y: Float, sign: Float, maxX: Float) -> (SIMD3<Float>, SIMD3<Float>) {
        guard let skin else { return (.zero, SIMD3(sign, 0, 0)) }
        var best = -1
        var bestX: Float = 0
        for (i, p) in skin.rest.enumerated() where abs(p.y - y) < 0.02 && p.x * sign > bestX && p.x * sign < maxX && abs(p.z - marks.backZ - marks.chestDepth * 0.45) < marks.chestDepth * 0.3 {
            bestX = p.x * sign; best = i
        }
        guard best >= 0 else { return (SIMD3(sign * marks.halfWidth, y, 0), SIMD3(sign, 0, 0)) }
        return (skin.rest[best], simd_normalize(skin.normals[best]))
    }

    private func findLandmarks() {
        guard let skin else { return }
        var m = Landmarks()
        let st = bounds("sternum") ?? BoundingBox(min: SIMD3(-0.03, 0.62, 0.05), max: SIMD3(0.03, 0.95, 0.12))
        m.sternumTop = st.max.y
        m.sternumBottom = st.min.y
        let len = st.max.y - st.min.y
        // lower half of the breastbone, just below the nipple line and above the xiphoid
        let ty = st.min.y + len * (victim == .infant ? 0.06 : 0.17)
        m.target = surface(x: 0, y: ty).0
        m.target.x = 0
        m.floorZ = skin.rest.map(\.z).min() ?? -0.2
        let chestBand = skin.rest.filter { abs($0.y - ty) < 0.02 && abs($0.x) < 0.05 }
        m.backZ = chestBand.map(\.z).min() ?? m.floorZ
        m.chestDepth = m.target.z - m.backZ
        marks = m
        // chest half width: the ribcage (below the armpit, inside the arm)
        let ribs = bounds("rib-6-l").map { $0.max.x } ?? 0.2
        m.halfWidth = side(y: ty, sign: 1, maxX: ribs * 1.35).0.x
        marks = m

        let shoulderY = bounds("clavicle-l").map(\.center.y) ?? m.sternumTop
        let shoulderX = bounds("clavicle-l").map { $0.max.x * 0.95 } ?? 0.3
        m.shoulders = [-1, 1].map { s in surface(x: s * shoulderX, y: shoulderY).0 }
        let lowest = skin.rest.min { $0.y < $1.y } ?? .zero
        m.feet = SIMD3(lowest.x, lowest.y + 0.12, lowest.z)
        let frontal = bounds("frontal-bone")
        let jaw = bounds("mandible")
        let foreheadY = frontal.map { $0.min.y + ($0.max.y - $0.min.y) * 0.35 } ?? 1.52
        m.forehead = surface(x: 0, y: foreheadY).0
        m.chin = surface(x: 0, y: (jaw?.min.y ?? 1.25) + 0.025).0
        let teeth = bounds("upper-teeth").map(\.min.y) ?? ((jaw?.max.y ?? 1.35) - 0.03)
        m.mouth = surface(x: 0, y: teeth).0
        let bellyY = m.sternumBottom - (pregnant ? 0.32 : 0.2)
        m.belly = surface(x: 0, y: bellyY).0
        m.feetY = lowest.y
        m.headTop = skin.rest.map(\.y).max() ?? 1.65
        m.minX = skin.rest.map(\.x).min() ?? -0.6
        m.maxX = skin.rest.map(\.x).max() ?? 0.6

        m.heart = rig.findEntity(named: "heart")?.parent.map { $0.position(relativeTo: skin.entity) } ?? SIMD3(0.03, 0.72, 0)
        m.brain = rig.findEntity(named: "brain")?.parent.map { $0.position(relativeTo: skin.entity) } ?? SIMD3(0, 1.5, 0.02)

        // pads: right, below the collarbone beside the breastbone; left, on the side below the armpit (infant: front + back)
        if victim == .infant {
            let front = surface(x: 0, y: ty)
            let back = surface(x: 0, y: ty + 0.02, front: false)
            m.pads = [(front.0, front.1, SIMD3(1, 0, 0)), (back.0, back.1, SIMD3(1, 0, 0))]
        } else {
            let clav = bounds("clavicle-r")
            let rx = clav.map { $0.min.x * 0.52 } ?? -0.14
            let ry = (clav?.min.y ?? m.sternumTop) - victim.pad.y * Self.cm / scale * 0.58
            let right = surface(x: rx, y: ry)
            // apex pad: her left side on the mid-axillary line, below the armpit, beside and below the nipple
            let left = surface(y: m.sternumBottom - len * (pregnant ? 0.12 : female ? 0.3 : 0.08), outward: SIMD3(1, 0, 0.12))
            m.pads = [(right.0, right.1, SIMD3(1, 0, 0)), (left.0, left.1, SIMD3(0, 1, 0))]
        }
        marks = m
    }

    // MARK: moving parts

    private func collectRigid() {
        guard let skin else { return }
        let pivot = headPivot
        for e in rig.children {
            let name = e.name.isEmpty ? (e.children.first?.name ?? "") : e.name
            guard !name.isEmpty, e !== skin.entity, !name.hasPrefix("skin:underwear") else { continue }
            let c = name.hasPrefix("skin:") ? e.visualBounds(relativeTo: skin.entity).center : (e is ModelEntity ? e.visualBounds(relativeTo: skin.entity).center : e.position)
            // the head: skin extras (eyes, brows, lashes, hair) and the skull turn with the tilt
            let w = headWeight(c, pivot: pivot)
            if w > 0.01 && (name.hasPrefix("skin:") || c.y > marks.sternumTop) { headRigid.append((e, e.transform.matrix, w)) }
            let id = name
            if id == "sternum" || id.hasPrefix("costal-cartilage") { chestRigid.append((e, e.transform.matrix, 1)) }
            if id.hasPrefix("rib-") { chestRigid.append((e, e.transform.matrix, 0.45)) }
            if id == "heart" { heart = (e, e.transform.matrix) }
            if id.hasPrefix("lung-") { lungs.append((e, e.transform.matrix)) }
            if ["uterus", "fetus", "placenta"].contains(id) { bumpRigid.append((e, e.transform.matrix)) }
        }
    }

    /// neck: rotation point (mid cervical spine) and the band over which the tilt blends in
    var headPivot: (point: SIMD3<Float>, low: Float, high: Float) {
        let c4 = bounds("vertebra-C4")?.center ?? SIMD3(0, 1.3, -0.04)
        let c7 = bounds("vertebra-C7")?.center.y ?? c4.y - 0.08
        let c1 = bounds("vertebra-C1")?.center.y ?? c4.y + 0.08
        return (c4, c7, max(c1, marks.chin.y + 0.02))
    }

    /// 0 at the lower neck, 1 on the head; the throat under the jaw blends later than the back of the neck
    func headWeight(_ p: SIMD3<Float>, pivot: (point: SIMD3<Float>, low: Float, high: Float)) -> Float {
        let front = max(0, p.z - pivot.point.z)
        let hi = pivot.high - min(front * 0.6, pivot.high - marks.chin.y + 0.005)
        let t = (p.y - pivot.low) / max(0.01, hi - pivot.low)
        let u = min(1, max(0, t))
        return u * u * (3 - 2 * u)
    }

    /// per-vertex weights for each moving region, computed once
    private struct Fields {
        struct Region { var indices: [Int]; var weights: [Float] }
        var skin: [(chest: [Float], breath: [Float], bump: [Float], head: [Float], indices: [Int])] = []
        var chestSigma: SIMD2<Float>
        var breathSigma: SIMD2<Float>
        var breathCentre: SIMD3<Float>
        var bumpSigma: Float

        @MainActor init(scene s: CPRTrainerScene) {
            let m = s.marks
            let len = m.sternumTop - m.sternumBottom
            chestSigma = SIMD2(m.halfWidth * 0.55, len * 0.62)
            breathCentre = SIMD3(0, m.target.y + len * 0.35, m.target.z)
            breathSigma = SIMD2(m.halfWidth * 0.8, len * 0.85)
            bumpSigma = 0.24
            let pivot = s.headPivot
            for d in [s.skin].compactMap({ $0 }) + s.garments {
                var ch: [Float] = [], br: [Float] = [], bu: [Float] = [], hd: [Float] = [], idx: [Int] = []
                for (i, p) in d.rest.enumerated() {
                    let frontness = Self.smooth((p.z - m.backZ) / max(0.01, m.chestDepth), 0.35, 0.8)
                    let dc = SIMD2(p.x - m.target.x, p.y - m.target.y) / chestSigma
                    let c = exp(-simd_length_squared(dc)) * frontness
                    let db = SIMD2(p.x, p.y - breathCentre.y) / breathSigma
                    let b = exp(-simd_length_squared(db)) * frontness
                    var u: Float = 0
                    if s.pregnant {
                        let dd = SIMD2(p.x - m.belly.x, p.y - m.belly.y) / bumpSigma
                        u = exp(-simd_length_squared(dd)) * Self.smooth((p.z - m.backZ) / max(0.01, m.belly.z - m.backZ), 0.25, 0.7)
                    }
                    let h = s.headWeight(p, pivot: pivot)
                    if c > 0.003 || b > 0.003 || u > 0.003 || h > 0.001 {
                        idx.append(i); ch.append(c); br.append(b); bu.append(u); hd.append(h)
                    }
                }
                skin.append((ch, br, bu, hd, idx))
            }
        }

        static func smooth(_ x: Float, _ a: Float, _ b: Float) -> Float {
            let t = min(1, max(0, (x - a) / (b - a)))
            return t * t * (3 - 2 * t)
        }
    }

    /// where a point on the head is now (rest point elsewhere on the body comes back as is)
    func headPoint(_ p: SIMD3<Float>) -> SIMD3<Float> {
        let pivot = headPivot
        let w = headWeight(p, pivot: pivot)
        guard w > 0, tilt > 0 else { return p }
        let (q, lift) = headTransform(w)
        return q.act(p - pivot.point) + pivot.point + lift
    }

    /// head rotation for the current tilt, with the lift that keeps the back of the head on the floor
    private func headTransform(_ w: Float) -> (simd_quatf, SIMD3<Float>) {
        let angle = -victim.tilt * .pi / 180 * tilt * w
        let q = simd_quatf(angle: angle, axis: SIMD3(1, 0, 0))
        return (q, SIMD3(0, 0, headLift * tilt * w))
    }

    private lazy var headLift: Float = {
        guard let skin else { return 0 }
        let pivot = headPivot
        let q = simd_quatf(angle: -victim.tilt * .pi / 180, axis: SIMD3(1, 0, 0))
        var before: Float = .infinity, after: Float = .infinity
        for p in skin.rest where p.y > pivot.high {
            before = min(before, p.z)
            after = min(after, (q.act(p - pivot.point) + pivot.point).z)
        }
        return before.isFinite ? max(0, before - after) : 0
    }()

    private func deform() {
        let state = SIMD4(depthCm, breath, tilt, bump)
        guard state != applied, let fields, let skin else { return }
        applied = state
        let m = marks
        let pivot = headPivot
        let sink = -depthCm * Self.cm / scale
        let rise = breath * m.chestDepth * 0.09
        let push = bump * 7 * Self.cm / scale
        let deformers = [skin] + garments
        for (k, d) in deformers.enumerated() where k < fields.skin.count {
            let f = fields.skin[k]
            var ps: [SIMD3<Float>] = [], ns: [SIMD3<Float>] = []
            ps.reserveCapacity(f.indices.count); ns.reserveCapacity(f.indices.count)
            for (j, i) in f.indices.enumerated() {
                let p0 = d.rest[i], n0 = d.normals[i]
                var p = p0, n = n0
                // chest (sink) and breath (rise): along z, normals tipped by the slope of the dent
                let gc = -2 * SIMD2(p0.x - m.target.x, p0.y - m.target.y) / (fields.chestSigma * fields.chestSigma) * f.chest[j]
                let gb = -2 * SIMD2(p0.x, p0.y - fields.breathCentre.y) / (fields.breathSigma * fields.breathSigma) * f.breath[j]
                let dz = sink * f.chest[j] + rise * f.breath[j]
                p.z += dz
                let g = SIMD3(gc.x * sink + gb.x * rise, gc.y * sink + gb.y * rise, 0)
                n = simd_normalize(n - n.z * (g - simd_dot(g, n) * n))
                if f.bump[j] > 0 {
                    p.x += push * f.bump[j]
                    p.z -= push * 0.25 * f.bump[j]
                }
                if f.head[j] > 0 && tilt > 0 {
                    let (q, lift) = headTransform(f.head[j])
                    p = q.act(p - pivot.point) + pivot.point + lift
                    n = q.act(n)
                }
                ps.append(p); ns.append(n)
            }
            d.write(indices: f.indices, positions: ps, normals: ns)
        }
        for (e, rest, w) in headRigid {
            let (q, lift) = headTransform(w)
            e.transform.matrix = Self.about(pivot.point, q, lift) * rest
        }
        for (e, rest, w) in chestRigid {
            var t = matrix_identity_float4x4
            t.columns.3.z = (sink + rise * 0.6) * w
            e.transform.matrix = t * rest
        }
        let squeeze = min(1, depthCm / victim.depth.upperBound)
        glowBreastbone(glass ? squeeze : 0)
        if let (e, rest) = heart {
            var t = matrix_identity_float4x4
            t.columns.3.z = sink * 0.45
            let c = SIMD3(rest.columns.3.x, rest.columns.3.y, rest.columns.3.z)
            let s = SIMD3<Float>(1 + 0.06 * squeeze, 1 - 0.05 * squeeze, 1 - 0.28 * squeeze)
            e.transform.matrix = t * Self.scaleAbout(c, s) * rest
        }
        for (e, rest) in lungs {
            // anchored at the back: the front of the lungs follows the ribs in
            let c = SIMD3(rest.columns.3.x, rest.columns.3.y, m.backZ + 0.03)
            let s = SIMD3<Float>(1 + 0.05 * breath, 1 + 0.04 * breath, 1 + 0.12 * breath - 0.3 * squeeze)
            e.transform.matrix = Self.scaleAbout(c, s) * rest
        }
        for (e, rest) in bumpRigid {
            var t = matrix_identity_float4x4
            t.columns.3.x = push * 0.8
            t.columns.3.z = -push * 0.2
            e.transform.matrix = t * rest
        }
    }

    private var glow: Float = 0

    /// see-through: the breastbone and rib cartilage light up as they're pushed in
    private func glowBreastbone(_ level: Float) {
        let q = (level * 8).rounded() / 8
        guard q != glow else { return }
        glow = q
        for (e, _, w) in chestRigid where w == 1 {
            guard let m = e as? ModelEntity, var mat = m.model?.materials.first as? PhysicallyBasedMaterial else { continue }
            mat.emissiveColor = .init(color: UIColor(hex: "#FFB020"))
            mat.emissiveIntensity = 0.7 * q
            m.model?.materials = [mat]
        }
    }

    private static func about(_ p: SIMD3<Float>, _ q: simd_quatf, _ lift: SIMD3<Float>) -> float4x4 {
        var a = matrix_identity_float4x4; a.columns.3 = SIMD4(-p, 1)
        var b = matrix_identity_float4x4; b.columns.3 = SIMD4(p + lift, 1)
        return b * float4x4(q) * a
    }

    private static func scaleAbout(_ c: SIMD3<Float>, _ s: SIMD3<Float>) -> float4x4 {
        var m = matrix_identity_float4x4
        m.columns.0.x = s.x; m.columns.1.y = s.y; m.columns.2.z = s.z
        m.columns.3 = SIMD4(c - s * c, 1)
        return m
    }

    // MARK: overlay

    /// rig (body) coordinates → body.root space
    private func local(_ p: SIMD3<Float>) -> SIMD3<Float> { p * scale }

    /// rig (body) coordinates → world
    func world(_ p: SIMD3<Float>) -> SIMD3<Float> { body.root.convert(position: local(p), to: nil) }

    private func buildOverlay() {
        let c = Self.cm
        hands.children.removeAll()
        let skinDepth: Float = 0.2 * c
        switch victim {
        case .adult:
            // lower hand's heel on the target; upper hand stacked on its back, arms shared
            hands.addChild(Self.glove(interlaced: true))
            let top = Self.glove(top: true, shadow: false)
            top.position = SIMD3(0, 0.2 * c, 2.8 * c)
            hands.addChild(top)
        case .child:
            hands.addChild(Self.glove())
        case .infant:
            hands.addChild(infantGrip())
        }
        hands.isEnabled = false
        place(hands, at: marks.target, normal: marks.targetNormal, axis: handAxis, lift: skinDepth)
        body.root.addChild(hands)

        if pregnant {
            bumpHand.children.removeAll()
            // a helper's hand flat on her right side of the bump, fingers toward her head
            bumpHand.addChild(Self.glove(flat: true))
            bumpHand.isEnabled = false
            body.root.addChild(bumpHand)
        }

        ring.model = ModelComponent(mesh: Self.torus(radius: victim.tolerance * c, tube: 0.25 * c), materials: [Self.ringMaterial(false)])
        ring.isEnabled = false
        place(ring, at: marks.target, normal: marks.targetNormal, axis: SIMD3(1, 0, 0), lift: 1.1 * c)
        body.root.addChild(ring)

        tapDot.model = ModelComponent(mesh: .generateSphere(radius: 0.7 * c), materials: [UnlitMaterial(color: UIColor(hex: "#E03A3E"))])
        tapDot.isEnabled = false
        body.root.addChild(tapDot)

        padEntities = (0..<2).map { i in
            let pad = Self.pad(victim.pad * c)
            pad.isEnabled = false
            body.root.addChild(pad)
            return pad
        }
        padGhosts = marks.pads.map { t in
            let g = ModelEntity(mesh: .generateBox(size: SIMD3(victim.pad.x * c, victim.pad.y * c, 0.15 * c), cornerRadius: 1.2 * c),
                                materials: [Self.ghostMaterial])
            place(g, at: t.point, normal: t.normal, axis: t.axis, lift: 0.1 * c)
            g.isEnabled = false
            body.root.addChild(g)
            return g
        }
        resetPads()

        let m = marks
        let arch = m.heart + SIMD3(0, (m.sternumTop - m.heart.y) * 0.9, -0.02)
        let neck = SIMD3<Float>(0.06, m.chin.y - 0.06, headPivot.point.z + 0.06)
        flowPath = [m.heart, arch, neck, m.brain]
        flowDots = (0..<7).map { i in
            let d = ModelEntity(mesh: .generateSphere(radius: (1.3 - Float(i) * 0.12) * c * max(0.6, scale)), materials: [UnlitMaterial(color: UIColor(hex: "#E8303A"))])
            d.isEnabled = false
            body.root.addChild(d)
            return d
        }
    }

    /// z → normal, x → axis on the tangent plane; lift along the normal (world units)
    private func place(_ e: Entity, at p: SIMD3<Float>, normal: SIMD3<Float>, axis: SIMD3<Float>, lift: Float) {
        e.orientation = Self.frame(normal: normal, axis: axis)
        e.position = local(p) + simd_normalize(normal) * lift
    }

    private static func frame(normal: SIMD3<Float>, axis: SIMD3<Float>) -> simd_quatf {
        let z = simd_normalize(normal)
        var x = axis - simd_dot(axis, z) * z
        x = simd_length(x) > 1e-4 ? simd_normalize(x) : SIMD3(1, 0, 0)
        let y = simd_cross(z, x)
        return simd_quatf(simd_float3x3(columns: (x, y, z)))
    }

    func resetPads() {
        padPlaced = [nil, nil]
        let c = Self.cm
        for (i, pad) in padEntities.enumerated() {
            // side by side on the floor at the rescuer's knee, flat
            let x = -(marks.halfWidth * scale + (victim == .infant ? 8 : 18) * c)
            let y = marks.target.y * scale + (Float(i) - 0.5) * (victim.pad.y + 3) * c
            pad.position = SIMD3(x, y, marks.floorZ * scale + 0.9 * c)
            pad.orientation = Self.frame(normal: SIMD3(0, 0, 1), axis: SIMD3(1, 0, 0))
        }
        updateGhosts()
    }

    private func updateGhosts() {
        for (i, g) in padGhosts.enumerated() { g.isEnabled = showPads && !padPlaced.contains(i) }
    }

    // MARK: interaction

    /// World ray through a point of a view of this size.
    func ray(_ pt: CGPoint, size: CGSize) -> (SIMD3<Float>, SIMD3<Float>) {
        let t = tan(body.camera.camera.fieldOfViewInDegrees * .pi / 360)
        let aspect = Float(size.width / max(1, size.height))
        let x = (2 * Float(pt.x / max(1, size.width)) - 1) * t * aspect
        let y = (1 - 2 * Float(pt.y / max(1, size.height))) * t
        let m = body.camera.transformMatrix(relativeTo: nil)
        let d = m * SIMD4(x, y, -1, 0)
        return (SIMD3(m.columns.3.x, m.columns.3.y, m.columns.3.z), simd_normalize(SIMD3(d.x, d.y, d.z)))
    }

    /// World point → point in a view of this size.
    func project(_ w: SIMD3<Float>, size: CGSize) -> CGPoint {
        let c = body.camera.transformMatrix(relativeTo: nil).inverse * SIMD4(w, 1)
        let t = tan(body.camera.camera.fieldOfViewInDegrees * .pi / 360)
        let aspect = Float(size.width / max(1, size.height))
        let depth = max(1e-4, -c.z)
        let x = c.x / depth / (t * aspect), y = c.y / depth / t
        return CGPoint(x: CGFloat((x + 1) / 2) * size.width, y: CGFloat((1 - y) / 2) * size.height)
    }

    /// A touch close enough to the hands on the chest to count as a push (screen test: no ray cast per push).
    func onChest(_ pt: CGPoint, size: CGSize) -> Bool {
        let c = project(world(marks.target), size: size)
        let edge = project(world(marks.target + SIMD3(marks.halfWidth * 0.8, 0, 0)), size: size)
        let r = max(60, hypot(edge.x - c.x, edge.y - c.y))
        return hypot(pt.x - c.x, pt.y - c.y) < r
    }

    /// On screen: the bump's centre and 7 cm toward her left of it.
    func screenAxis(size: CGSize) -> (CGPoint, CGPoint) {
        (project(world(marks.belly), size: size), project(world(marks.belly + SIMD3(7 * Self.cm / scale, 0, 0)), size: size))
    }

    /// First skin point along a world ray (body coordinates) and its normal.
    func hitBody(_ ray: (SIMD3<Float>, SIMD3<Float>)) -> (point: SIMD3<Float>, normal: SIMD3<Float>)? {
        guard let skin else { return nil }
        let inv = rig.transformMatrix(relativeTo: nil).inverse
        let o4 = inv * SIMD4(ray.0, 1), d4 = inv * SIMD4(ray.1, 0)
        let o = SIMD3(o4.x, o4.y, o4.z), d = simd_normalize(SIMD3(d4.x, d4.y, d4.z))
        return skin.intersect(origin: o, direction: d)
    }

    /// World ray → floor (y = 0 world) in body.root space.
    private func hitFloor(_ ray: (SIMD3<Float>, SIMD3<Float>)) -> SIMD3<Float>? {
        guard ray.1.y < -1e-4 else { return nil }
        let t = -ray.0.y / ray.1.y
        return body.root.convert(position: ray.0 + t * ray.1, from: nil)
    }

    /// What a tap at this body point touched.
    func spot(_ p: SIMD3<Float>) -> CPRSpot {
        let m = marks
        let d = { (q: SIMD3<Float>) in simd_distance(p, q) * self.scale / Self.cm }
        // reach of each spot, cm, shrinks with the body
        let k: Float = victim == .adult ? 1 : victim == .child ? 0.75 : 0.45
        let len = m.sternumTop - m.sternumBottom
        if p.y > m.sternumBottom - len * 0.35 && p.y < m.sternumTop - len * 0.1 && abs(p.x) < m.halfWidth * 0.8 && p.z > m.backZ + m.chestDepth * 0.5 { return .chest }
        if m.shoulders.contains(where: { d($0) < 9 * k }) { return .shoulder }
        if p.y < m.feetY + 0.3 { return .feet }
        // face: the nearest of forehead, mouth and chin, where the tilted head has put them
        let (q, lift) = headTransform(1)
        let pivot = headPivot.point
        let face: [(CPRSpot, SIMD3<Float>, Float)] = [(.forehead, m.forehead, 6), (.mouth, m.mouth, 3.5), (.chin, m.chin, 4)]
        let near = face.map { ($0.0, d(q.act($0.1 - pivot) + pivot + lift), $0.2 * k) }
            .filter { $0.1 < $0.2 }.min { $0.1 < $1.1 }
        if let near { return near.0 }
        if pregnant && d(m.belly) < 16 { return .belly }
        return .other
    }

    /// offset of a body point from the hand target, cm: x (+ her left), y (+ toward the head)
    func offsetFromTarget(_ p: SIMD3<Float>) -> SIMD2<Float> {
        SIMD2(p.x - marks.target.x, p.y - marks.target.y) * scale / Self.cm
    }

    func markTap(_ p: SIMD3<Float>, normal: SIMD3<Float>) {
        tapDot.position = local(p) + normal * 0.4 * Self.cm
        tapDot.isEnabled = true
        tapTime = clock
    }

    /// Pulsing rings on the spots to tap (none: hide).
    func hint(_ spots: [CPRSpot]) {
        hintRings.forEach { $0.removeFromParent() }
        let k: Float = victim == .adult ? 1 : victim == .child ? 0.75 : 0.5
        let rest: [SIMD3<Float>] = spots.flatMap { s -> [SIMD3<Float>] in
            switch s {
            case .shoulder: marks.shoulders
            case .feet: [marks.feet]
            case .forehead: [marks.forehead]
            case .chin: [marks.chin]
            case .mouth: [marks.mouth]
            case .belly: [marks.belly]
            default: []
            }
        }
        let (q, _) = headTransform(1)
        hintRings = rest.map { p0 in
            let (p, n) = surface(x: p0.x, y: p0.y)
            let onHead = headWeight(p, pivot: headPivot) > 0.5
            let r = ModelEntity(mesh: Self.torus(radius: 2.2 * k * Self.cm, tube: 0.22 * Self.cm), materials: [Self.ringMaterial(false)])
            place(r, at: headPoint(p), normal: onHead ? q.act(n) : n, axis: SIMD3(1, 0, 0), lift: 0.8 * Self.cm)
            body.root.addChild(r)
            return r
        }
    }

    /// world points of the ring's centre, the hands' heel and the target (renderer check)
    var alignment: (ring: SIMD3<Float>, heel: SIMD3<Float>, target: SIMD3<Float>) {
        (ring.position(relativeTo: nil), hands.position(relativeTo: nil), world(marks.target))
    }

    /// close-up on the hands (renderer)
    func focusOnTarget() {
        focus = world(marks.target)
        homeFocus = focus
    }

    func shake() { shakeStart = clock }
    func jolt() { joltStart = clock }
    func pumpBlood() { flowStart = clock }

    /// Pad under the finger (index), for dragging.
    func pad(at ray: (SIMD3<Float>, SIMD3<Float>)) -> Int? {
        var best: (Int, Float)?
        for (i, e) in padEntities.enumerated() where e.isEnabled {
            let p = e.position(relativeTo: nil)
            let v = p - ray.0
            let t = simd_dot(v, ray.1)
            let miss = simd_length(v - t * ray.1)
            if miss < max(victim.pad.x, 9) * Self.cm * 0.75, best == nil || miss < best!.1 { best = (i, miss) }
        }
        return best?.0
    }

    /// Drags a pad along the skin (or the floor); returns the target it would snap to.
    @discardableResult
    func drag(pad i: Int, ray: (SIMD3<Float>, SIMD3<Float>)) -> Int? {
        let e = padEntities[i]
        padPlaced[i] = nil
        let c = Self.cm
        if let hit = hitBody(ray) {
            var target = nearestFreeTarget(hit.point, excluding: i)
            // infant: front and back pads; anywhere on the chest takes the free one (the back pad slides under)
            if victim == .infant, target == nil, abs(hit.point.y - marks.target.y) * scale < 8 * c, abs(hit.point.x) < marks.halfWidth {
                target = [0, 1].first { t in !padPlaced.enumerated().contains { $0.offset != i && $0.element == t } }
            }
            if let t = target {
                let p = marks.pads[t]
                place(e, at: p.point, normal: p.normal, axis: p.axis, lift: 0.5 * c)
            } else {
                place(e, at: hit.point, normal: hit.normal, axis: SIMD3(1, 0, 0), lift: 0.3 * c)
            }
            updateGhosts()
            return target
        }
        if let f = hitFloor(ray) {
            e.position = SIMD3(f.x, f.y, marks.floorZ * scale + 0.9 * c)
            e.orientation = Self.frame(normal: SIMD3(0, 0, 1), axis: SIMD3(1, 0, 0))
        }
        return nil
    }

    /// Finishes a drag: snapped onto a free target, or left where it is.
    func drop(pad i: Int, on target: Int?) {
        if let t = target, !padPlaced.contains(t) {
            padPlaced[i] = t
            let p = marks.pads[t]
            place(padEntities[i], at: p.point, normal: p.normal, axis: p.axis, lift: 0.5 * Self.cm)
        }
        updateGhosts()
    }

    /// For the Mac renderer and "show me": put pad i on target t.
    func placePad(_ i: Int, on t: Int) { drop(pad: i, on: t) }

    private func nearestFreeTarget(_ p: SIMD3<Float>, excluding i: Int) -> Int? {
        let snap: Float = victim == .infant ? 4 : 9
        var best: (Int, Float)?
        for (t, target) in marks.pads.enumerated() where !padPlaced.enumerated().contains(where: { $0.offset != i && $0.element == t }) {
            let d = simd_distance(p, target.point) * scale / Self.cm
            if d < snap || inZone(t, p), best == nil || d < best!.1 { best = (t, d) }
        }
        return best?.0
    }

    /// the side pad's spot is half hidden from the rescuer: anywhere on her left flank counts; the other, her upper right chest
    private func inZone(_ t: Int, _ p: SIMD3<Float>) -> Bool {
        guard victim != .infant else { return false }
        let m = marks, len = m.sternumTop - m.sternumBottom
        if t == 1 { return p.x > m.halfWidth * 0.4 && p.y > m.sternumBottom - len * (female ? 0.8 : 0.45) && p.y < m.sternumBottom + len * 0.5 }
        return p.x < -m.halfWidth * 0.2 && p.x > -m.halfWidth * 0.85 && p.y > m.sternumBottom + len * 0.45 && p.y < m.sternumTop + len * 0.05
    }

    var padsDone: Bool { padPlaced.allSatisfy { $0 != nil } }

    // MARK: frame

    func update(dt: Float) {
        clock += dt
        guard ready else { return }
        deform()

        let ease = 1 - exp(-dt * 4)
        if let g = goalFocus {
            focus += (g - focus) * ease
            if simd_distance(g, focus) < 1e-4 { goalFocus = nil }
        }
        if let g = goalDistance {
            distance += (g - distance) * ease
            if abs(g - distance) < 1e-4 { goalDistance = nil }
        }
        if let g = goalElevation {
            elevation += (g - elevation) * (1 - exp(-dt * 4))
            if abs(g - elevation) < 0.002 { goalElevation = nil }
        }
        // camera orbits the chest from the rescuer's side (her right, -x)
        let d = distance * zoom
        let dir = SIMD3(-cos(elevation) * cos(azimuth), sin(elevation), cos(elevation) * sin(azimuth))
        // screen up toward her head
        body.camera.look(at: focus + panOffset, from: focus + panOffset + dir * d, relativeTo: nil)

        // hands ride the chest down; the infant grip too
        let c = Self.cm
        if showHands {
            let sink = -depthCm * c / scale
            place(hands, at: marks.target + SIMD3(0, 0, sink), normal: marks.targetNormal, axis: handAxis, lift: 0.2 * c)
        }
        if pregnant {
            bumpHand.isEnabled = bump > 0.02
            // palm on her right side of the bump as it is now (pushed), found on the moved skin
            if bumpHand.isEnabled && bump != bumpPlaced {
                bumpPlaced = bump
                let push = bump * 7 * c / scale
                if let skin, let hit = skin.intersect(origin: bumpCore + SIMD3(push, 0, 0), direction: simd_normalize(SIMD3(-1, 0, 0.35))) {
                    let n = simd_normalize(hit.normal)
                    let axis = simd_normalize(simd_cross(SIMD3<Float>(0, 1, 0), n))
                    // heel below the contact point so the palm's centre sits on it
                    place(bumpHand, at: hit.point - SIMD3(0, 4.6 * c / scale, 0), normal: n, axis: axis, lift: 0.5 * c)
                }
            }
        }

        for r in hintRings { r.scale = SIMD3(repeating: 1 + 0.15 * sin(clock * 5)) }
        if showRing {
            let pulse = 1 + 0.08 * sin(clock * 5)
            ring.scale = SIMD3(repeating: ringGood ? 1 : pulse)
        }
        tapDot.isEnabled = clock - tapTime < 1.6

        // blood pushed from the heart to the brain after a compression
        let u = (clock - flowStart) / 0.7
        for (i, dot) in flowDots.enumerated() {
            let v = u - Float(i) * 0.06
            dot.isEnabled = glass && v > 0 && v < 1
            if dot.isEnabled { dot.position = local(Meshes.catmullRom(flowPath, v)) }
        }

        // shoulder tap: a small shake; shock: a jolt
        var t = rootRest
        let s = clock - shakeStart
        if s < 0.6 { t.translation.x += sin(s * 40) * 0.6 * c * (1 - s / 0.6) }
        let j = clock - joltStart
        if j < 0.25 { t.translation.y += sin(j / 0.25 * .pi) * 2.2 * c * scale.squareRoot() }
        body.root.transform = t
    }

    // MARK: parts

    private static func flat(_ hex: String, roughness: Float) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: UIColor(hex: hex))
        m.roughness = .init(floatLiteral: roughness)
        m.metallic = .init(floatLiteral: 0)
        return m
    }

    private static func ringMaterial(_ good: Bool) -> UnlitMaterial {
        var m = UnlitMaterial(color: UIColor(hex: good ? "#2E9E5B" : "#FFB020"))
        m.blending = .transparent(opacity: .init(floatLiteral: 0.9))
        return m
    }

    private static let ghostMaterial: UnlitMaterial = {
        var m = UnlitMaterial(color: UIColor(hex: "#2E9E5B"))
        m.blending = .transparent(opacity: .init(floatLiteral: 0.45))
        return m
    }()

    /// matte blue nitrile
    private static let gloveMaterial: PhysicallyBasedMaterial = {
        var m = flat("#4F73C4", roughness: 0.72)
        m.specular = .init(floatLiteral: 0.25)
        m.sheen = .init(tint: UIColor(white: 0.25, alpha: 1))
        return m
    }()

    private static func blob(_ centre: SIMD3<Float>, _ radii: SIMD3<Float>, along dir: SIMD3<Float>? = nil) -> ModelEntity {
        let e = ModelEntity(mesh: unitSphere, materials: [gloveMaterial])
        e.name = "glove"
        e.position = centre
        e.scale = radii
        if let dir { e.orientation = simd_quatf(from: SIMD3(0, 1, 0), to: simd_normalize(dir)) }
        return e
    }

    private static let unitSphere = MeshResource.generateSphere(radius: 1)

    private static var capsules: [SIMD2<Float>: MeshResource] = [:]

    /// capsule of this radius and overall length along `dir`, centred at `centre`
    private static func capsule(_ centre: SIMD3<Float>, radius: Float, length: Float, along dir: SIMD3<Float>, material: RealityKit.Material? = nil) -> ModelEntity {
        let key = SIMD2(radius, length)
        let mesh = capsules[key] ?? Meshes.capsule(radius: radius, length: length).resource()
        capsules[key] = mesh
        let e = ModelEntity(mesh: mesh, materials: [material ?? gloveMaterial])
        e.name = material == nil ? "glove" : "forearm"
        e.position = centre
        e.orientation = simd_quatf(from: SIMD3(0, 1, 0), to: simd_normalize(dir))
        return e
    }


    /// finger or thumb as jointed segments from `base`, each segment turning by `bend` (radians, about x) from `dir`
    private static func digit(_ base: SIMD3<Float>, dir: SIMD3<Float>, lengths: [Float], radius: Float, bend: Float, bends: [Float]? = nil, into hand: Entity) {
        var p = base, d = simd_normalize(dir)
        let axis = simd_normalize(simd_cross(d, SIMD3(0, 0, 1))) * -1
        for (k, len) in lengths.enumerated() {
            let r = radius * (1 - 0.08 * Float(k))
            hand.addChild(capsule(p + d * (len / 2), radius: r, length: len + r, along: d))
            p += d * len
            let b = bends.map { k < $0.count ? $0[k] : 0 } ?? bend
            d = simd_quatf(angle: b, axis: simd_length(axis) > 0.1 ? axis : SIMD3(1, 0, 0)).act(d)
        }
    }

    /// A nitrile-gloved hand, palm down, ending in a short cuff at the wrist. Origin: the heel of the hand;
    /// fingers along +y, back of the hand +z.
    /// `top`: upper hand of the two-hand grip, fingers curling down between the lower hand's (`interlaced`), which lift.
    /// `flat`: palm and fingers lying on the skin (the bump push). `shadow`: soft contact shadow under the palm.
    static func glove(top: Bool = false, interlaced: Bool = false, flat: Bool = false, shadow: Bool = true) -> Entity {
        let c = cm
        let hand = Entity()
        let palm = ModelEntity(mesh: .generateBox(size: SIMD3(8.2 * c, 9.8 * c, 2.7 * c), cornerRadius: 1.25 * c), materials: [gloveMaterial])
        palm.name = "glove"
        palm.position = SIMD3(0, 3.9 * c, 1.35 * c)
        palm.orientation = simd_quatf(angle: top || flat ? 0 : 0.1, axis: SIMD3(1, 0, 0))
        hand.addChild(palm)
        let widths: [Float] = [0.95, 1, 0.93, 0.82]
        let lengths: [[Float]] = [[4.2, 2.5, 2.1], [4.6, 2.8, 2.3], [4.3, 2.7, 2.2], [3.4, 2.1, 1.9]]
        for k in 0..<4 {
            // the two hands' fingers alternate: the top hand's sit in the lower hand's gaps
            let x = (2.85 - 1.9 * Float(k) + (top ? 0.95 : 0)) * c
            let base = SIMD3<Float>(x, 8.4 * c, (top ? 1.6 : flat ? 1.1 : 2.1) * c)
            let dir: SIMD3<Float>, bend: Float
            if top { dir = SIMD3(0, 1, -0.3); bend = 0.72 }                 // down between the lower fingers
            else if interlaced { dir = SIMD3(0, 0.95, 0.3); bend = -0.08 }  // lifted off the chest
            else if flat { dir = SIMD3(0, 1, -0.12); bend = 0.14 }          // lying on the skin, following its curve
            else { dir = SIMD3(0, 1, 0.18); bend = 0.1 }                    // single hand: lifted off the chest
            digit(base, dir: dir, lengths: lengths[k].map { $0 * c }, radius: widths[k] * c, bend: bend, into: hand)
        }
        // thumb: out along the side of the palm; flat on the skin it lies close beside the index finger
        digit(SIMD3(3.6 * c, 1.6 * c, (flat ? 0.9 : 1.2) * c), dir: flat ? SIMD3(0.3, 0.95, -0.08) : SIMD3(0.55, 0.8, 0.1),
              lengths: [3.4 * c, 2.9 * c], radius: 1.15 * c, bend: flat ? 0.05 : 0.25, into: hand)
        addCuff(to: hand, wrist: SIMD3(0, -0.4 * c, 1.4 * c), back: SIMD3(0, -1, 0.12))
        if shadow { addShadow(to: hand, centre: SIMD3(0, 4.4 * c, 0.12 * c), radii: SIMD2(4.8 * c, 7.2 * c)) }
        return hand
    }

    /// short cuff at the wrist, capped, with a faint wider rim fading out past its edge
    private static func addCuff(to e: Entity, wrist: SIMD3<Float>, back: SIMD3<Float>) {
        let c = cm
        let d = simd_normalize(back)
        let cuff = capsule(wrist + d * (1.6 * c), radius: 2.6 * c, length: 4.4 * c, along: d)
        e.addChild(cuff)
        let fade = capsule(wrist + d * (3 * c), radius: 2.75 * c, length: 3 * c, along: d, material: cuffFade)
        fade.name = "cuff"
        e.addChild(fade)
    }

    /// soft contact shadow: nested flat discs, darkest in the middle
    private static func addShadow(to e: Entity, centre: SIMD3<Float>, radii: SIMD2<Float>) {
        for (k, (grow, alpha)) in [(Float(1.25), Float(0.07)), (1, 0.1), (0.72, 0.12)].enumerated() {
            let disc = ModelEntity(mesh: unitSphere, materials: [shadowMaterial(alpha)])
            disc.name = "shadow"
            disc.position = centre + SIMD3(0, 0, Float(k) * 0.02 * cm)
            disc.scale = SIMD3(radii.x * grow, radii.y * grow, 0.05 * cm)
            e.addChild(disc)
        }
    }

    private static func shadowMaterial(_ alpha: Float) -> UnlitMaterial {
        var m = UnlitMaterial(color: UIColor(hex: "#1E2230"))
        m.blending = .transparent(opacity: .init(floatLiteral: alpha))
        return m
    }

    private static let cuffFade: PhysicallyBasedMaterial = {
        var m = gloveMaterial
        m.blending = .transparent(opacity: .init(floatLiteral: 0.35))
        return m
    }()

    /// Infant: two fingers (index and middle) side by side on the breastbone just below the nipple line;
    /// the hand comes down from the rescuer's side, ring and little fingers curled.
    private func infantGrip() -> Entity {
        let c = Self.cm
        let grip = Entity()
        func chain(_ pts: [SIMD3<Float>], radius: Float) {
            for (k, (a, b)) in zip(pts, pts.dropFirst()).enumerated() {
                let r = radius * (1 - 0.07 * Float(k))
                grip.addChild(Self.capsule((a + b) / 2, radius: r, length: simd_distance(a, b) + r, along: b - a))
            }
        }
        // grip space: x her left, y toward the head, z out of the chest; origin on the target
        // wrist → fingertips: the hand comes down from the rescuer's side, toward her feet, not over the face
        let f = simd_normalize(SIMD3<Float>(0.2, 0.8, -0.56))
        let width = simd_normalize(SIMD3<Float>(0, 1, 0) - f.y * f)
        let palmSide = simd_normalize(simd_cross(f, width))       // palm faces her far side
        let knuckle = { (y: Float) in SIMD3<Float>(0, 0, 0.9 * c) + width * y - f * 7.6 * c }
        for (y, w) in [(Float(0.95), Float(0.95)), (-0.95, 1)] {
            let tip = SIMD3<Float>(0, y * c, 0.9 * c)
            let k = knuckle(y * c)
            let bend = simd_normalize(f + palmSide * 0.15)
            chain([k, k + f * 4 * c, k + f * 4 * c + bend * 2.2 * c, tip], radius: w * c)
        }
        for (y, w) in [(Float(-2.85), Float(0.93)), (-4.75, 0.82)] {
            let k = knuckle(y * c)
            let a = k + simd_normalize(f + palmSide) * 3.2 * c
            chain([k, a, a + simd_normalize(palmSide - f) * 2.4 * c], radius: w * c)
        }
        let palmCentre = knuckle(-1.9 * c) - f * 4.9 * c + palmSide * -0.2 * c
        let palm = ModelEntity(mesh: .generateBox(size: SIMD3(8 * c, 9.6 * c, 2.7 * c), cornerRadius: 1.2 * c), materials: [Self.gloveMaterial])
        palm.name = "glove"
        palm.position = palmCentre
        // box x across the knuckles (her length), y along the fingers, z the back of the hand
        palm.orientation = simd_quatf(simd_float3x3(columns: (width, f, simd_cross(width, f))))
        grip.addChild(palm)
        let wrist = palmCentre - f * 4.8 * c
        chain([wrist + width * 3.4 * c + palmSide * 0.8 * c, knuckle(2.4 * c) + palmSide * 1.4 * c - f * 1.2 * c], radius: 1.15 * c)
        Self.addCuff(to: grip, wrist: wrist + f * 0.6 * c, back: -f)
        // contact shadow round the two fingertips
        Self.addShadow(to: grip, centre: SIMD3(0.3 * c, 0, 0.12 * c), radii: SIMD2(2.4 * c, 2.8 * c))
        return grip
    }

    /// An AED pad: white gel pad with a red rim and a small heart-and-bolt mark.
    private static func pad(_ size: SIMD2<Float>) -> Entity {
        let c = cm
        let e = Entity()
        let rim = ModelEntity(mesh: .generateBox(size: SIMD3(size.x + 0.9 * c, size.y + 0.9 * c, 0.25 * c), cornerRadius: 1.4 * c),
                              materials: [flat("#D8434B", roughness: 0.6)])
        let face = ModelEntity(mesh: .generateBox(size: SIMD3(size.x, size.y, 0.4 * c), cornerRadius: 1.2 * c), materials: [flat("#F7F7F5", roughness: 0.5)])
        face.position.z = 0.1 * c
        let mark = ModelEntity(mesh: .generateBox(size: SIMD3(size.y * 0.28, size.y * 0.28, 0.2 * c), cornerRadius: size.y * 0.08),
                               materials: [flat("#D8434B", roughness: 0.6)])
        mark.position = SIMD3(size.x * 0.28, 0, 0.25 * c)
        let cable = ModelEntity(mesh: .generateBox(size: SIMD3(0.5 * c, size.y * 0.5, 0.5 * c), cornerRadius: 0.25 * c), materials: [flat("#2B2D33", roughness: 0.5)])
        cable.position = SIMD3(-size.x * 0.5 - 0.3 * c, 0, 0.2 * c)
        cable.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3(0, 0, 1))
        e.addChild(rim); e.addChild(face); e.addChild(mark); e.addChild(cable)
        return e
    }

    private static func torus(radius: Float, tube: Float) -> MeshResource {
        var p: [SIMD3<Float>] = [], n: [SIMD3<Float>] = [], idx: [UInt32] = []
        let a = 48, b = 10
        for i in 0...a {
            let u = Float(i) / Float(a) * 2 * .pi
            for j in 0...b {
                let v = Float(j) / Float(b) * 2 * .pi
                let dir = SIMD3(cos(u), sin(u), 0)
                let nn = cos(v) * dir + sin(v) * SIMD3(0, 0, 1)
                p.append(dir * radius + nn * tube); n.append(nn)
            }
        }
        for i in 0..<a { for j in 0..<b {
            let k = UInt32(i * (b + 1) + j), k2 = UInt32((i + 1) * (b + 1) + j)
            idx += [k, k2, k + 1, k + 1, k2, k2 + 1]
        } }
        var d = MeshDescriptor(name: "ring")
        d.positions = MeshBuffers.Positions(p)
        d.normals = MeshBuffers.Normals(n)
        d.primitives = .triangles(idx)
        return (try? MeshResource.generate(from: [d])) ?? .generateSphere(radius: radius)
    }
}
