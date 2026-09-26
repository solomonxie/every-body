import RealityKit
import UIKit
import simd

/// What the user has done to individual parts; every change is one undo step.
struct PartState: Equatable {
    var hidden: Set<String> = []
    var faded: Set<String> = []
    var isolated: String?

    func visible(_ id: String) -> Bool { !hidden.contains(id) && (isolated == nil || isolated == id) }
    var changedCount: Int { hidden.count + faded.count + (isolated == nil ? 0 : 1) }
}

enum Focus {
    case all, foot, hand, ear

    var y: Float { switch self { case .all: 0.05; case .foot: -1.48; case .hand: -0.1; case .ear: 1.43 } }
    var distance: Float { switch self { case .all: 5.8; case .foot: 1.3; case .hand: 1.5; case .ear: 0.9 } }
}

/// The schematic body as RealityKit entities, plus everything animated on it.
@MainActor
final class BodyScene {
    /// set from a bodyatlas://…?yaw= link: start at this angle, no auto-rotate
    static var pinnedYaw: Float?

    let root = Entity()
    let camera = PerspectiveCamera()
    var subscription: EventSubscription?

    // camera + orbit state
    var yaw: Float = 0
    var pitch: Float = 0
    var distance: Float = Focus.all.distance
    var focusY: Float = 0
    var panX: Float = 0
    var goalDistance: Float = Focus.all.distance
    var goalFocusY: Float = 0
    var goalYaw: Float?
    var touched = false
    var bpm: Float = 72

    private let rig = Entity()
    private var partEntities: [String: ModelEntity] = [:]
    private var partLayer: [String: LayerID] = [:]
    private var baseMaterials: [String: PhysicallyBasedMaterial] = [:]
    private var skinEntities: [ModelEntity] = []
    private var organEntities: [String: Entity] = [:]
    private var jointOuter: [String: Entity] = [:]
    private var pointEntities: [String: ModelEntity] = [:]
    private var pulseDots: [ModelEntity] = []
    private var pulseCurves: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = []
    private var pulseStart: Float = -100
    private var litOrgans: Set<String> = []
    private var flashStart: Float = -1
    private var flowDots: [ModelEntity] = []
    private var flowStops: [SIMD3<Float>] = []
    private var flowSplit: (capillary: Float, lungs: Float) = (0, 0)
    private var flowPhase: Float = 0
    private var clock: Float = 0

    private var layers: Set<LayerID> = []
    private var parts = PartState()
    private var selected: String?
    private var female = false
    private var skinColor = UIColor(hex: "#F2C9A5")

    init() {
        if let yaw = Self.pinnedYaw {
            self.yaw = yaw
            touched = true
        }
        root.addChild(rig)
        root.addChild(camera)
        camera.camera.fieldOfViewInDegrees = 40
        let sun = DirectionalLight()
        sun.light.intensity = 3000
        sun.look(at: .zero, from: SIMD3(3, 4, 5), relativeTo: nil)
        root.addChild(sun)
        let fill = DirectionalLight()
        fill.light.intensity = 1200
        fill.look(at: .zero, from: SIMD3(-3, 2, -4), relativeTo: nil)
        root.addChild(fill)
    }

    // MARK: build

    func build(skinColor: UIColor, female: Bool, points: [BodyPoint], flowStops: [BodyPoint]) {
        self.skinColor = skinColor
        self.female = female
        rig.children.removeAll()
        partEntities = [:]; skinEntities = []; organEntities = [:]; jointOuter = [:]; pointEntities = [:]

        // joint pivots: outer at the pivot (rotates), inner offset back so children use body coords
        var inner: [String: Entity] = [:]
        func container(for joint: Joint) -> Entity {
            if let existing = inner[joint.id] { return existing }
            let parent = joint.parent.flatMap { Catalog.joint($0) }.map(container(for:)) ?? rig
            let outer = Entity()
            outer.position = joint.pivot.simd
            let offset = Entity()
            offset.position = -joint.pivot.simd
            outer.addChild(offset)
            parent.addChild(outer)
            jointOuter[joint.id] = outer
            inner[joint.id] = offset
            return offset
        }
        Catalog.body.joints.forEach { _ = container(for: $0) }
        func parent(of id: String) -> Entity {
            Catalog.body.joints.first { $0.parts.contains(id) }.map(container(for:)) ?? rig
        }

        let sex = female ? "female" : "male"
        for part in Catalog.body.parts where part.layer == .skin && (part.sex == nil || part.sex == sex) {
            let entity = Self.entity(for: part.shape)
            entity.model?.materials = [Self.material(skinColor, opacity: 0.3)]
            parent(of: part.id).addChild(entity)
            skinEntities.append(entity)
        }

        for organ in Catalog.body.organs {
            let variant = (!female ? organ.male : nil) ?? Organ.Variant(position: organ.position, color: organ.color, shapes: organ.shapes)
            // container sits on the pulse target so it scales about it
            let container = Entity()
            container.position = variant.position.simd
            for shape in variant.shapes {
                let piece = Self.entity(for: shape)
                piece.position -= variant.position.simd
                piece.model?.materials = [Self.material(UIColor(hex: variant.color), opacity: organ.region == true ? 0.45 : 1)]
                piece.name = organ.names == nil ? "" : organ.id
                if organ.names != nil { Self.makeTappable(piece) }
                container.addChild(piece)
            }
            container.isEnabled = organ.region != true
            rig.addChild(container)
            organEntities[organ.id] = container
        }

        for part in Catalog.body.parts where part.layer != .skin {
            let entity = Self.entity(for: part.shape)
            entity.name = part.id
            baseMaterials[part.id] = Self.material(UIColor(hex: part.color), opacity: 1)
            entity.model?.materials = [baseMaterials[part.id]!]
            Self.makeTappable(entity)
            parent(of: part.id).addChild(entity)
            partEntities[part.id] = entity
            partLayer[part.id] = part.layer
        }

        for point in points {
            let dot = ModelEntity(mesh: .generateSphere(radius: 0.035), materials: [UnlitMaterial(color: UIColor(hex: "#6C4F9E"))])
            dot.name = "point:\(point.id)"
            dot.position = point.position.simd
            dot.components.set(InputTargetComponent())
            dot.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.09)]))
            rig.addChild(dot)
            pointEntities[point.id] = dot
        }

        pulseDots = (0..<15).map { i in
            let dot = ModelEntity(mesh: .generateSphere(radius: 0.035 * (1 - Float(i % 5) * 0.16)), materials: [UnlitMaterial(color: UIColor(hex: "#FFD166"))])
            dot.isEnabled = false
            rig.addChild(dot)
            return dot
        }

        self.flowStops = flowStops.map(\.position.simd)
        if !flowStops.isEmpty {
            let n = Float(flowStops.count)
            flowSplit = (Float(flowStops.firstIndex { $0.id == "capillaries" } ?? 0) / n, Float(flowStops.firstIndex { $0.id == "lungs" } ?? 0) / n)
            flowDots = (0..<18).map { _ in
                let dot = ModelEntity(mesh: .generateSphere(radius: 0.03), materials: [UnlitMaterial(color: UIColor(hex: "#E03A3E"))])
                rig.addChild(dot)
                return dot
            }
        } else {
            flowDots = []
        }
        applyVisibility()
    }

    // MARK: state

    func setLayers(_ layers: Set<LayerID>) {
        self.layers = layers
        applyVisibility()
    }

    func setParts(_ parts: PartState, selected: String?) {
        self.parts = parts
        self.selected = selected
        applyVisibility()
    }

    func setJoint(_ id: String, degrees: Float) {
        guard let joint = Catalog.joint(id), let outer = jointOuter[id] else { return }
        outer.orientation = simd_quatf(angle: degrees * .pi / 180, axis: simd_normalize(joint.axis.simd))
        for mover in joint.movers {
            guard let entity = partEntities[mover], case let .spindle(from, to, radius) = Catalog.part(mover)?.shape else { continue }
            let bulge = 1 + 0.6 * min(1, degrees / joint.maxDeg)
            let length = simd_distance(from.simd, to.simd)
            entity.scale = SIMD3(radius * bulge, length / 2 * (2 - bulge).squareRoot(), radius * 0.8 * bulge)
        }
    }

    func setActivePoint(_ id: String?) {
        for (pid, dot) in pointEntities {
            dot.model?.materials = [UnlitMaterial(color: UIColor(hex: pid == id ? "#FFD166" : "#6C4F9E"))]
            dot.scale = SIMD3(repeating: pid == id ? 1.4 : 1)
        }
    }

    /// Pulse from a point to each organ it acts on; organs light when it arrives.
    func pulse(from start: SIMD3<Float>, to organIds: [String]) {
        litOrgans = Set(organIds)
        flashStart = -1
        pulseStart = clock
        pulseCurves = organIds.compactMap { organEntities[$0]?.position }.map { end in
            var mid = (start + end) / 2
            mid.z += 0.35
            return (start, mid, end)
        }
    }

    private func applyVisibility() {
        let inner = layers.contains { $0 != .skin }
        let skinOpacity: Float = layers.contains(.skin) ? (inner ? 0.12 : 0.3) : 0
        for skin in skinEntities {
            skin.isEnabled = skinOpacity > 0
            skin.model?.materials = [Self.material(skinColor, opacity: skinOpacity)]
        }
        let muscleOpacity: Float = layers.contains(.skeletal) ? 0.55 : 0.95
        for (id, entity) in partEntities {
            guard let layer = partLayer[id] else { continue }
            entity.isEnabled = layers.contains(layer) && parts.visible(id)
            var m = baseMaterials[id]!
            let opacity: Float = parts.faded.contains(id) ? 0.18 : layer == .muscular ? muscleOpacity : 1
            if opacity < 1 { m.blending = .transparent(opacity: .init(floatLiteral: opacity)) }
            if id == selected { m.emissiveColor = .init(color: UIColor(hex: "#FFD166")); m.emissiveIntensity = 0.8 }
            entity.model?.materials = [m]
        }
        for (id, entity) in organEntities where Catalog.organ(id)?.region != true {
            entity.isEnabled = layers.contains(.organs) && parts.visible(id)
        }
    }

    // MARK: frame

    func update(dt: Float) {
        clock += dt
        let k = 1 - exp(-6 * dt)
        if !touched { yaw += dt * 0.35 }
        if let goal = goalYaw {
            yaw += (goal - yaw) * k
            if abs(goal - yaw) < 0.001 { goalYaw = nil }
        }
        distance += (goalDistance - distance) * k
        focusY += (goalFocusY - focusY) * k
        rig.orientation = simd_quatf(angle: pitch, axis: SIMD3(1, 0, 0)) * simd_quatf(angle: yaw, axis: SIMD3(0, 1, 0))
        camera.look(at: SIMD3(panX, focusY, 0), from: SIMD3(panX, focusY, distance), relativeTo: nil)

        updatePulse()
        updateOrgans()
        updateFlow(dt: dt)
    }

    private func updatePulse() {
        let progress = (clock - pulseStart) / 1.4
        if progress >= 1, flashStart < 0, !pulseCurves.isEmpty { flashStart = clock }
        for (i, dot) in pulseDots.enumerated() {
            let c = i / 5
            let u = progress - Float(i % 5) * 0.035
            guard c < pulseCurves.count, u > 0, u < 1 else { dot.isEnabled = false; continue }
            let (a, b, e) = pulseCurves[c]
            dot.isEnabled = true
            dot.position = (1 - u) * (1 - u) * a + 2 * u * (1 - u) * b + u * u * e
        }
    }

    private func updateOrgans() {
        for (id, entity) in organEntities {
            let organ = Catalog.organ(id)
            let lit = litOrgans.contains(id) && flashStart >= 0
            var pulse: Float = 0
            if lit {
                let t = clock - flashStart
                pulse = t < 0.8 ? sin(t / 0.8 * .pi) * 0.6 : 0
            }
            if id == "heart" { pulse += pow(max(0, sin(clock * bpm / 60 * 2 * .pi)), 4) * 0.18 }
            entity.scale = SIMD3(repeating: 1 + pulse)
            if organ?.region == true { entity.isEnabled = lit }
            for case let piece as ModelEntity in entity.children {
                guard var m = piece.model?.materials.first as? PhysicallyBasedMaterial else { continue }
                m.emissiveColor = .init(color: organ?.region == true ? UIColor(hex: organ!.color) : UIColor(hex: id == selected ? "#FFD166" : "#4ECB71"))
                m.emissiveIntensity = lit ? 0.6 + pulse : id == selected ? 0.6 : 0
                piece.model?.materials = [m]
            }
        }
    }

    private func updateFlow(dt: Float) {
        guard flowStops.count > 1 else { return }
        flowPhase = (flowPhase + dt * bpm / 60 * 0.06).truncatingRemainder(dividingBy: 1)
        let loop = flowStops + [flowStops[0]]
        for (i, dot) in flowDots.enumerated() {
            let u = (flowPhase + Float(i) / Float(flowDots.count)).truncatingRemainder(dividingBy: 1)
            dot.position = Meshes.catmullRom(loop, u)
            let venous = u > flowSplit.capillary && u < flowSplit.lungs
            dot.model?.materials = [UnlitMaterial(color: UIColor(hex: venous ? "#3A5BD9" : "#E03A3E"))]
        }
    }

    // MARK: helpers

    func faceFront() {
        goalYaw = (yaw / (2 * .pi)).rounded() * 2 * .pi
    }

    func focus(_ f: Focus) {
        goalFocusY = f.y
        goalDistance = f.distance
    }

    func resetView() {
        pitch = 0; panX = 0
        faceFront()
        focus(.all)
    }

    static func material(_ color: UIColor, opacity: Float) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: color)
        m.roughness = .init(floatLiteral: 0.55)
        m.metallic = .init(floatLiteral: 0)
        m.faceCulling = .none
        if opacity < 1 { m.blending = .transparent(opacity: .init(floatLiteral: opacity)) }
        return m
    }

    private static func makeTappable(_ entity: ModelEntity) {
        entity.components.set(InputTargetComponent())
        if let mesh = entity.model?.mesh {
            Task { @MainActor in
                if let shape = try? await ShapeResource.generateStaticMesh(from: mesh) {
                    entity.components.set(CollisionComponent(shapes: [shape]))
                }
            }
        }
    }

    private static func orient(_ e: ModelEntity, from a: SIMD3<Float>, to b: SIMD3<Float>) {
        e.position = (a + b) / 2
        e.orientation = simd_quatf(from: SIMD3(0, 1, 0), to: simd_normalize(b - a))
    }

    private static func entity(for shape: PartShape) -> ModelEntity {
        switch shape {
        case let .sphere(center, radius, scale, rotation):
            let e = ModelEntity(mesh: .generateSphere(radius: radius))
            e.position = center.simd
            if let scale { e.scale = scale.simd }
            if let r = rotation { e.orientation = euler(r) }
            return e
        case let .box(center, size, rotation):
            let e = ModelEntity(mesh: .generateBox(size: size.simd))
            e.position = center.simd
            if let r = rotation { e.orientation = euler(r) }
            return e
        case let .segment(from, to, radius):
            let e = ModelEntity(mesh: Meshes.capsule(radius: radius, length: max(0.001, simd_distance(from.simd, to.simd))))
            orient(e, from: from.simd, to: to.simd)
            return e
        case let .spindle(from, to, radius):
            let e = ModelEntity(mesh: .generateSphere(radius: 1))
            orient(e, from: from.simd, to: to.simd)
            e.scale = SIMD3(radius, simd_distance(from.simd, to.simd) / 2, radius * 0.8)
            return e
        case let .lathe(from, to, radii, scale):
            let e = ModelEntity(mesh: Meshes.profile(radii: radii, length: max(0.001, simd_distance(from.simd, to.simd))))
            orient(e, from: from.simd, to: to.simd)
            if let scale { e.scale = scale.simd }
            return e
        case let .tube(points, radius, radii):
            return ModelEntity(mesh: Meshes.tube(points: points.map(\.simd), radius: radius, radii: radii))
        case let .plate(points, thickness):
            return ModelEntity(mesh: Meshes.plate(points: points.map(\.simd), thickness: thickness))
        }
    }

    /// three.js-style XYZ Euler
    private static func euler(_ r: Vec3) -> simd_quatf {
        simd_quatf(angle: r.x, axis: SIMD3(1, 0, 0)) * simd_quatf(angle: r.y, axis: SIMD3(0, 1, 0)) * simd_quatf(angle: r.z, axis: SIMD3(0, 0, 1))
    }
}
