import RealityKit
import simd
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// The double hip squeeze in 3D: a pregnant woman leaning forward with her hands on a bed, a partner's gloved hands on
/// her buttocks pressing in through a contraction (the skin dents under the palms), on a loop.
@MainActor
final class HipSqueezeScene {
    static let cm = CPRTrainerScene.cm
    /// forward at the hips and along the spine, elbows bent onto the bed
    static let pose: [(String, Float)] = [("back", 62), ("elbow-l", 100), ("elbow-r", 100)]

    enum Phase: Int, CaseIterable { case building, squeeze, hold, easing, release, rest }

    /// one loop, seconds (a real contraction lasts about a minute)
    nonisolated static let cycle: Float = 14

    /// the contraction's strength through the loop: up to a peak at 5 s, gone by 10 s
    nonisolated static func contraction(at t: Float) -> Float {
        guard t < 10 else { return 0 }
        let s = sin(.pi * t / 10)
        return s * s
    }

    /// how hard the hands press: in as the contraction builds, held, out once it has eased
    nonisolated static func press(at t: Float) -> Float {
        BodyScene.smooth(2, 3.2, t) * (1 - BodyScene.smooth(9, 10.2, t))
    }

    nonisolated static func phase(at t: Float) -> Phase {
        switch t {
        case ..<2: .building
        case ..<3.2: .squeeze
        case ..<6.5: .hold
        case ..<9: .easing
        case ..<10.2: .release
        default: .rest
        }
    }

    let body = BodyScene()
    let root = Entity()
    private(set) var ready = false
    var playing = true
    /// time in the loop
    private(set) var time: Float = 0
    var phase: Phase { Self.phase(at: time) }
    var contraction: Float { Self.contraction(at: time) }
    /// bones under a glass skin, the hip bones turning a hair
    var bones = false { didSet { if bones != oldValue { applyLayers() } } }

    // camera orbit round `focus` (world); azimuth 0 looks at her front
    var azimuth: Float = -2.45
    var elevation: Float = 0.32
    var zoom: Float = 1
    var panOffset = SIMD3<Float>.zero
    private(set) var distance: Float = 4.6
    private var focus = SIMD3<Float>.zero
    private var goal: (azimuth: Float, elevation: Float, zoom: Float)?

    private var skin: SkinDeformer?
    private var garments: [SkinDeformer] = []
    /// per deformer, the pose's positions and normals (the dents go on top)
    private var base: [([SIMD3<Float>], [SIMD3<Float>])] = []
    /// per deformer, the vertices near a palm and their share of each palm's dent
    private var dents: [(indices: [Int], share: [SIMD2<Float>], slope: [(SIMD3<Float>, SIMD3<Float>)])] = []
    private var applied: Float = -1

    struct Palm {
        let side: Float
        /// on the posed skin (skin coordinates): centre, outward normal, her "up", fingers' way, the press
        let centre, normal, up, fingers, push: SIMD3<Float>
    }
    private(set) var palms: [Palm] = []
    private let hands = Entity()
    private var handEntities: [Entity] = []
    private var arrows: [ModelEntity] = []
    private var hipBones: [(entity: Entity, posed: float4x4, pivot: SIMD3<Float>, axis: SIMD3<Float>, side: Float)] = []
    private var pelvisArrows: [(ModelEntity, SIMD3<Float>, SIMD3<Float>)] = []

    /// palm dent: deepest under the palm's centre (cm), Gaussian widths across and along the hand (cm)
    private static let depth: Float = 2.2, across: Float = 4.4, along: Float = 5.4

    // MARK: build

    func build(heritage: Heritage, chest: BodySize = .small) {
        body.chest = chest
        body.hips = .medium
        body.heritage = heritage
        body.underwear = true
        body.setAge(.adult)
        body.build(skinColor: UIColor(hex: "#F2C9A5"), female: true, pregnant: true, points: [], flowStops: [])
        body.touched = true

        root.children.removeAll()
        body.root.children.filter { $0 is DirectionalLight }.forEach { $0.removeFromParent() }
        body.camera.removeFromParent()
        body.camera.camera.fieldOfViewInDegrees = 40
        body.camera.camera.fieldOfViewOrientation = .vertical
        root.addChild(body.camera)
        root.addChild(body.root)
        addLights()

        // landmarks at rest, bones shown (hidden parts measure empty)
        body.setLayers([.skin, .skeletal])
        body.setParts(PartState(), selected: nil)
        let hip = bounds("hip-bone-l") ?? BoundingBox(min: SIMD3(0.005, 0, -0.16), max: SIMD3(0.257, 0.378, 0.114))
        let sacrum = bounds("sacrum") ?? BoundingBox(min: SIMD3(-0.117, 0.13, -0.17), max: SIMD3(0.117, 0.325, 0))
        let restBones = ["hip-bone-l", "hip-bone-r"].compactMap { id in body.root.findEntity(named: id).map { ($0, $0.transform.matrix) } }

        for (id, degrees) in Self.pose { body.setJoint(id, degrees: degrees) }
        let deformers = body.skinDeformers
        guard let skin = deformers.first(where: { $0.entity.name == "skin:body" }) else { return }
        self.skin = skin
        garments = deformers.filter { $0.entity.name.hasPrefix("skin:underwear") }
        base = ([skin] + garments).map { $0.current() }
        toRoot = skin.entity.transformMatrix(relativeTo: body.root)

        // palms on the fleshy upper buttocks: below the hip bones' crest, level with the bottom of the sacrum
        let x = hip.max.x * 0.78, y = sacrum.min.y - 0.01
        palms = [1, -1].compactMap { s in palm(side: s, x: s * x, y: y) }
        findDents()
        placeBed()
        addHands()
        addPelvis(rest: restBones, hip: hip, sacrum: sacrum)
        applyLayers()

        // back three-quarter view of the hips and both hands, her head and the bed in frame
        let mid = palms.isEmpty ? SIMD3<Float>(0, y, 0) : (palms[0].centre + palms[palms.count - 1].centre) / 2
        focus = world(mid) + SIMD3(0, -0.25, 0.35)
        ready = true
        update(dt: 0)
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

    private func applyLayers() {
        body.setLayers(bones ? [.skin, .skeletal] : [.skin])
        body.setParts(PartState(), selected: nil)
        for (e, _, _) in pelvisArrows { e.isEnabled = bones }
        applied = -1
    }

    private func bounds(_ name: String) -> BoundingBox? {
        guard let skinEntity = body.root.findEntity(named: "skin:body"), let e = body.root.findEntity(named: name) else { return nil }
        let b = e.visualBounds(relativeTo: skinEntity)
        return b.isEmpty ? nil : b
    }

    // MARK: palms

    /// back-most rest vertex near (x, y)
    private func backVertex(_ x: Float, _ y: Float) -> Int? {
        guard let skin else { return nil }
        var best: (Int, Float)?
        for (i, p) in skin.rest.enumerated() where abs(p.y - y) < 0.012 && abs(p.x - x) < 0.012 && p.z < 0 {
            if best == nil || p.z < best!.1 { best = (i, p.z) }
        }
        return best?.0
    }

    /// where the pose put a rest point: its rest neighbours' posed positions and normals, averaged
    private func posed(_ i: Int) -> (SIMD3<Float>, SIMD3<Float>) {
        guard let skin, let (p, n) = base.first else { return (.zero, SIMD3(0, 0, -1)) }
        var sp = SIMD3<Float>.zero, sn = SIMD3<Float>.zero, k: Float = 0
        for (j, q) in skin.rest.enumerated() where simd_distance(q, skin.rest[i]) < 0.015 {
            sp += p[j]; sn += n[j]; k += 1
        }
        return k > 0 ? (sp / k, simd_normalize(sn)) : (p[i], n[i])
    }

    private func palm(side s: Float, x: Float, y: Float) -> Palm? {
        guard let i = backVertex(x, y), let j = backVertex(x, y + 0.07) else { return nil }
        let (c, n) = posed(i)
        var up = posed(j).0 - c
        up = simd_normalize(up - simd_dot(up, n) * n)
        let inward = SIMD3<Float>(-s, 0, 0)
        var fingers = 0.55 * SIMD3<Float>(s, 0, 0) + up
        fingers = simd_normalize(fingers - simd_dot(fingers, n) * n)
        // in toward the middle and a little up, into the flesh
        return Palm(side: s, centre: c, normal: n, up: up, fingers: fingers, push: simd_normalize(-n + 0.7 * inward + 0.25 * up))
    }

    /// each palm's dent over the posed skin and underwear: share (Gaussian, the flesh round it pushed out a little)
    /// and its slope for the normals, computed once
    private func findDents() {
        let su = Self.across * Self.cm, sv = Self.along * Self.cm
        dents = base.map { pos, _ in
            var idx: [Int] = [], share: [SIMD2<Float>] = [], slope: [(SIMD3<Float>, SIMD3<Float>)] = []
            for (i, p) in pos.enumerated() {
                var w = SIMD2<Float>.zero
                var g: [SIMD3<Float>] = [.zero, .zero]
                for (k, palm) in palms.enumerated() {
                    let d = p - palm.centre
                    guard abs(simd_dot(d, palm.normal)) < 0.08 else { continue }
                    let side = simd_cross(palm.normal, palm.fingers)
                    let u = simd_dot(d, side) / su, v = simd_dot(d, palm.fingers) / sv
                    let q = u * u + v * v
                    guard q < 9 else { continue }
                    w[k] = 1.3 * exp(-q) - 0.3 * exp(-q / 3.2)
                    // d(share)/dq times the gradient of q: where the dent's wall faces
                    let dq = -1.3 * exp(-q) + 0.3 / 3.2 * exp(-q / 3.2)
                    g[k] = dq * (2 * u / su * side + 2 * v / sv * palm.fingers)
                }
                if w != .zero { idx.append(i); share.append(w); slope.append((g[0], g[1])) }
            }
            return (idx, share, slope)
        }
    }

    private func deform(_ press: Float) {
        guard abs(press - applied) > 0.002 || (press == 0 && applied != 0) else { return }
        applied = press
        let sink = press * Self.depth * Self.cm
        for (k, d) in ([skin].compactMap { $0 } + garments).enumerated() where k < dents.count {
            var (p, n) = base[k]
            let dent = dents[k]
            for (j, i) in dent.indices.enumerated() {
                var tilt = SIMD3<Float>.zero
                for (m, palm) in palms.enumerated() {
                    let w = dent.share[j][m]
                    guard w != 0 else { continue }
                    p[i] += sink * w * palm.push
                    // the surface sinks along -normal by this much: its normal leans toward the deeper side
                    let into = sink * simd_dot(palm.push, -palm.normal)
                    tilt += into * (m == 0 ? dent.slope[j].0 : dent.slope[j].1)
                }
                n[i] = simd_normalize(n[i] + tilt)
            }
            d.write(indices: Array(p.indices), positions: p, normals: n)
        }
    }

    // MARK: props and hands

    /// skin coordinates → body.root space
    private var toRoot = matrix_identity_float4x4

    private func local(_ p: SIMD3<Float>) -> SIMD3<Float> {
        let q = toRoot * SIMD4(p, 1)
        return SIMD3(q.x, q.y, q.z)
    }

    private func localDirection(_ d: SIMD3<Float>) -> SIMD3<Float> {
        let q = toRoot * SIMD4(d, 0)
        return simd_normalize(SIMD3(q.x, q.y, q.z))
    }

    func world(_ p: SIMD3<Float>) -> SIMD3<Float> { body.root.convert(position: local(p), to: nil) }

    /// The floor under her feet, and a bed whose edge is just in front of her thighs, the mattress under her hands.
    private func placeBed() {
        guard let skin, let pos = base.first?.0 else { return }
        let c = Self.cm
        let feet = pos.map { local($0).y }.min() ?? -1.6
        // stand her on the floor (y = 0)
        body.root.position = SIMD3(0, -feet, 0)
        // her hands: rest vertices out at the sides below the hips, now in front of her
        var top: Float = .infinity, thigh: Float = -.infinity
        for (i, r) in skin.rest.enumerated() {
            let q = local(pos[i])
            if abs(r.x) > 0.3 && r.y < 0 && r.y > -0.38 && q.z > 0.15 { top = min(top, q.y) }
            if abs(r.x) < 0.22 && r.y < -0.1 && r.y > -0.7 { thigh = max(thigh, q.z) }
        }
        if !top.isFinite { top = -0.26 }
        if !thigh.isFinite { thigh = 0.22 }
        let lift = body.root.position.y
        let mattress = SIMD3<Float>(100 * c, 14 * c, 60 * c)
        let edge = thigh + 3 * c, deck = top + lift - mattress.y
        func add(_ size: SIMD3<Float>, _ at: SIMD3<Float>, _ hex: String, roughness: Float, corner: Float = 0.6) {
            let e = ModelEntity(mesh: .generateBox(size: size, cornerRadius: corner * c), materials: [CPRTrainerScene.flat(hex, roughness: roughness)])
            e.position = at
            root.addChild(e)
        }
        add(mattress, SIMD3(0, deck + mattress.y / 2, edge + mattress.z / 2), "#E8E2F2", roughness: 0.95, corner: 3)
        add(SIMD3(mattress.x + 2 * c, 8 * c, mattress.z + 2 * c), SIMD3(0, deck - 4 * c, edge + mattress.z / 2), "#B98E63", roughness: 0.6)
        let leg = deck - 8 * c
        for sx: Float in [-1, 1] { for sz: Float in [0.08, 0.92] {
            add(SIMD3(5 * c, leg, 5 * c), SIMD3(sx * (mattress.x / 2 - 3 * c), leg / 2, edge + mattress.z * sz), "#9C7552", roughness: 0.6, corner: 0.4)
        } }
        let floor = ModelEntity(mesh: .generatePlane(width: 30, depth: 30), materials: [CPRTrainerScene.flat("#D2D0CB", roughness: 1)])
        root.addChild(floor)
    }

    /// The partner's hands (left on her left buttock, right on her right), fingers up and out, faint level forearms
    /// back toward the partner behind her; an arrow beside each showing the push.
    private func addHands() {
        let c = Self.cm
        hands.children.removeAll()
        var forearm = CPRTrainerScene.gloveMaterial
        forearm.blending = .transparent(opacity: .init(floatLiteral: 0.3))
        handEntities = palms.map { palm in
            let hand = Entity()
            hand.addChild(CPRTrainerScene.glove(flat: true, right: palm.side < 0, cuff: false))
            hand.isEnabled = true
            hands.addChild(hand)
            return hand
        }
        for (palm, hand) in zip(palms, handEntities) {
            // in the hand's frame (fingers +y, back +z): see-through, from the wrist back and a little out, level
            let q = Self.frame(normal: localDirection(palm.normal), fingers: localDirection(palm.fingers)).inverse
            let dir = q.act(localDirection(palm.normal + 0.5 * SIMD3(palm.side, 0, 0) - 0.08 * palm.up))
            let wrist = SIMD3<Float>(0, -0.4 * c, 1.4 * c)
            let arm = CPRTrainerScene.capsule(wrist + dir * 9.5 * c, radius: 2.8 * c, length: 20 * c, along: dir, material: forearm)
            hand.addChild(arm)
        }
        body.root.addChild(hands)
        arrows = palms.map { _ in
            let a = Self.arrow(length: 5.5 * c, radius: 0.55 * c, color: "#FFB020")
            body.root.addChild(a)
            return a
        }
    }

    private func placeHands(_ press: Float) {
        let c = Self.cm
        let sink = press * Self.depth * c
        for (palm, hand) in zip(palms, handEntities) {
            // heel below the palm's centre, riding the dent in
            let heel = palm.centre - palm.fingers * 4.4 * c + palm.push * sink
            hand.orientation = Self.frame(normal: localDirection(palm.normal), fingers: localDirection(palm.fingers))
            hand.position = local(heel) + localDirection(palm.normal) * 0.5 * c
        }
        for (palm, arrow) in zip(palms, arrows) {
            // beside the hand's outer edge, pointing in and a little up
            let inward = SIMD3<Float>(-palm.side, 0, 0)
            let dir = localDirection(inward + 0.35 * palm.up)
            arrow.isEnabled = press > 0.05
            arrow.position = local(palm.centre - inward * 8.5 * c + palm.normal * 3 * c) - dir * (1 - press) * 1.5 * c
            arrow.orientation = simd_quatf(from: SIMD3(0, 1, 0), to: dir)
            arrow.scale = SIMD3(repeating: 0.6 + 0.4 * press)
        }
    }

    // MARK: pelvis

    /// Under glass: each hip bone turns a hair about its joint with the sacrum (crest in, the sit bones out), shown
    /// by arrows. Much exaggerated: the real movement is a millimetre or two.
    private func addPelvis(rest: [(Entity, float4x4)], hip: BoundingBox, sacrum: BoundingBox) {
        let c = Self.cm
        hipBones = rest.map { e, restMatrix in
            let s: Float = e.name.hasSuffix("-l") ? 1 : -1
            // rest (rig) point and axis → the bone's own space
            let pivot = SIMD3(s * sacrum.max.x * 0.85, (sacrum.min.y + sacrum.max.y) / 2, sacrum.center.z)
            let toBone = restMatrix.inverse
            let p4 = toBone * SIMD4(pivot, 1), a4 = toBone * SIMD4(0, 0, 1, 0)
            return (e, e.transform.matrix, SIMD3(p4.x, p4.y, p4.z), simd_normalize(SIMD3(a4.x, a4.y, a4.z)), s)
        }
        pelvisArrows.forEach { $0.0.removeFromParent() }
        pelvisArrows = []
        for (e, posedMatrix, _, _, s) in hipBones {
            guard let restMatrix = rest.first(where: { $0.0 === e })?.1, let parent = e.parent, let skin else { continue }
            func onBone(_ p: SIMD3<Float>) -> SIMD3<Float> {
                let q = posedMatrix * restMatrix.inverse * SIMD4(p, 1)
                return parent.convert(position: SIMD3(q.x, q.y, q.z), to: skin.entity)
            }
            let h = hip.max - hip.min
            let crest = onBone(SIMD3(s * hip.max.x * 0.82, hip.max.y - 0.03 * h.y, hip.min.z + 0.45 * h.z))
            let sit = onBone(SIMD3(s * (hip.min.x + 0.45 * h.x), hip.min.y + 0.1 * h.y, hip.min.z + 0.3 * h.z))
            for (at, dir) in [(crest + SIMD3(s * 5 * c, 0, 0), SIMD3<Float>(-s, 0, 0)), (sit + SIMD3(s * 1.5 * c, 0, 0), SIMD3<Float>(s, 0, 0))] {
                let a = Self.arrow(length: 4.5 * c, radius: 0.45 * c, color: "#00C2E0")
                a.isEnabled = false
                body.root.addChild(a)
                pelvisArrows.append((a, at, dir))
            }
        }
    }

    private func movePelvis(_ press: Float) {
        let c = Self.cm
        let angle = (bones ? press : 0) * 2.5 * .pi / 180
        for (e, posedMatrix, pivot, axis, s) in hipBones {
            var to = matrix_identity_float4x4; to.columns.3 = SIMD4(pivot, 1)
            var back = matrix_identity_float4x4; back.columns.3 = SIMD4(-pivot, 1)
            e.transform.matrix = posedMatrix * to * float4x4(simd_quatf(angle: s * angle, axis: axis)) * back
        }
        for (a, at, dir) in pelvisArrows where a.isEnabled {
            let d = localDirection(dir)
            a.position = local(at) + d * press * 1.2 * c
            a.orientation = simd_quatf(from: SIMD3(0, 1, 0), to: d)
            a.scale = SIMD3(repeating: 0.4 + 0.6 * press)
        }
    }

    // MARK: frame

    /// screen right and up in world, for sliding the view under a finger
    var screenAxes: (right: SIMD3<Float>, up: SIMD3<Float>) {
        let forward = -eyeDirection
        let right = simd_normalize(simd_cross(forward, SIMD3(0, 1, 0)))
        return (right, simd_cross(right, forward))
    }

    private var eyeDirection: SIMD3<Float> {
        SIMD3(cos(elevation) * sin(azimuth), sin(elevation), cos(elevation) * cos(azimuth))
    }

    /// back to the opening view
    func resetView() {
        goal = (-2.45, 0.32, 1)
        panOffset = .zero
    }

    /// jump to a moment in the loop (renderer, paused screens)
    func seek(_ t: Float) {
        time = t.truncatingRemainder(dividingBy: Self.cycle)
    }

    func update(dt: Float) {
        guard ready else { return }
        if playing { time = (time + dt).truncatingRemainder(dividingBy: Self.cycle) }
        if let g = goal {
            let k = 1 - exp(-dt * 5)
            azimuth += (g.azimuth - azimuth) * k
            elevation += (g.elevation - elevation) * k
            zoom += (g.zoom - zoom) * k
            if abs(g.azimuth - azimuth) < 0.002 && abs(g.elevation - elevation) < 0.002 && abs(g.zoom - zoom) < 0.002 { goal = nil }
        }
        let press = Self.press(at: time)
        deform(press)
        placeHands(press)
        movePelvis(press)
        let at = focus + panOffset
        body.camera.look(at: at, from: at + eyeDirection * distance * zoom, relativeTo: nil)
    }

    /// stop any eased camera move (a finger took over)
    func holdCamera() { goal = nil }

    // MARK: parts

    /// the glove's frame: back of the hand (+z) along the normal, fingers (+y) toward `fingers`
    private static func frame(normal: SIMD3<Float>, fingers: SIMD3<Float>) -> simd_quatf {
        let z = simd_normalize(normal)
        var y = fingers - simd_dot(fingers, z) * z
        y = simd_length(y) > 1e-4 ? simd_normalize(y) : SIMD3(0, 1, 0)
        return simd_quatf(simd_float3x3(columns: (simd_cross(y, z), y, z)))
    }

    /// An arrow along +y from its origin: a shaft and a cone tip, unlit.
    private static func arrow(length: Float, radius: Float, color: String) -> ModelEntity {
        let m = UnlitMaterial(color: UIColor(hex: color))
        let shaft = length * 0.62
        let e = ModelEntity(mesh: .generateCylinder(height: shaft, radius: radius), materials: [m])
        let holder = ModelEntity()
        e.position.y = shaft / 2
        holder.addChild(e)
        let tip = ModelEntity(mesh: .generateCone(height: length - shaft, radius: radius * 2.4), materials: [m])
        tip.position.y = shaft + (length - shaft) / 2
        holder.addChild(tip)
        return holder
    }
}
