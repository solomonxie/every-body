import RealityKit
import simd
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// What the user has done to individual parts; every change is one undo step.
struct PartState: Equatable {
    var hidden: Set<String> = []
    var isolated: String?

    func visible(_ id: String) -> Bool { !hidden.contains(id) && (isolated == nil || isolated == id) }
    var changedCount: Int { hidden.count + (isolated == nil ? 0 : 1) }
}

enum Focus {
    case all, foot, hand, ear, head, arm, front, back, leg

    var y: Float {
        switch self {
        case .all: 0.05; case .foot: -1.48; case .hand: -0.1; case .ear: 1.43
        case .head: 1.36; case .arm: 0.28; case .front: 0.55; case .back: 0.55; case .leg: -0.78
        }
    }
    var distance: Float {
        switch self {
        case .all: 5.8; case .foot: 1.3; case .hand: 1.5; case .ear: 0.9
        case .head: 1.25; case .arm: 2.4; case .front, .back: 2.6; case .leg: 3.1
        }
    }
    /// sideways camera slide, scene units (the left arm hangs off the midline)
    var panX: Float { self == .arm ? 0.44 : 0 }
}

/// The schematic body as RealityKit entities, plus everything animated on it.
@MainActor
final class BodyScene {
    /// set from a everybody://…?yaw= link: start at this angle, no auto-rotate
    static var pinnedYaw: Float?
    /// skin opacity over inner layers (the Mac renderer raises it to check the fit)
    static var glassOpacity: Float = 0.12

    let root = Entity()
    let camera = PerspectiveCamera()
    var subscription: EventSubscription?

    // camera + orbit state
    var yaw: Float = 0
    var pitch: Float = 0
    var distance: Float = Focus.all.distance
    var focusY: Float = 0
    var panX: Float = 0
    var goalPanX: Float = 0
    /// resting sideways offset (e.g. the chart page keeps the body clear of its corner box)
    var basePanX: Float = 0
    var baseZoom: Float = 1
    var goalDistance: Float = Focus.all.distance
    var goalFocusY: Float = 0
    var goalYaw: Float?
    var touched = false
    var bpm: Float = 72
    private var framedAge: AgeGroup?

    private let rig = Entity()
    private var partEntities: [String: ModelEntity] = [:]
    private var partLayer: [String: LayerID] = [:]
    /// each part's own material (Self.material's key)
    private var baseMaterials: [String: MaterialKey] = [:]
    private var skinEntities: [(entity: ModelEntity, material: PhysicallyBasedMaterial)] = []
    /// the real (MakeHuman) skin is one mesh: it can't bend, so it steps aside while a joint is bent
    private var realSkin = false
    /// acupuncture: points and channels show through the hair (and underwear, if clothing is optional); the real hair hides
    private var seeThrough = false
    /// the real skin: points (every age) and children's channels are dropped onto it
    private var surface: Figure.Surface?
    private var organEntities: [String: Entity] = [:]
    /// each organ piece's own opacity (the see-through womb)
    private var organOpacity: [ObjectIdentifier: Float] = [:]
    private var jointOuter: [String: Entity] = [:]
    private var jointInner: [String: Entity] = [:]
    private var pointEntities: [String: [ModelEntity]] = [:]
    private var pointColors: [String: UIColor] = [:]
    private var smallPoints: Set<String> = []
    /// inner parts that would poke through a child's skin (tuckInside)
    private var hiddenForAge: Set<String> = []
    private var meridianEntities: [String: [ModelEntity]] = [:]
    /// kept across rebuilds so a new body never brings the lines back
    private var meridianFilter: (visible: Bool, ids: Set<String>?) = (true, nil)
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
    /// outer skin look; set before build
    var heritage: Heritage = .white
    var underwear = true
    /// adult female figure options
    var chest: BodySize = .small
    var hips: BodySize = .small

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
        // from behind and above, so the back's relief reads when the body is turned
        let rim = DirectionalLight()
        rim.light.intensity = 1600
        rim.look(at: .zero, from: SIMD3(1.5, 3, -5), relativeTo: nil)
        root.addChild(rim)
    }

    // MARK: build

    func build(skinColor: UIColor, female: Bool, pregnant: Bool = false, points: [BodyPoint], flowStops: [BodyPoint], meridians: [Meridian] = []) {
        self.skinColor = skinColor
        self.female = female
        let pregnant = pregnant && female && age == .adult
        rig.children.removeAll()
        partEntities = [:]; skinEntities = []; organEntities = [:]; organOpacity = [:]; jointOuter = [:]; pointEntities = [:]; pointColors = [:]; smallPoints = []; meridianEntities = [:]
        benders = [:]; crossing = [:]; unbent = [:]; pendingJoints = [:]; skinBends = []; skinPose = nil; holders = []; jointAngles = [:]; backRest = [:]

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
            jointInner[joint.id] = offset
            inner[joint.id] = offset
            return offset
        }
        Catalog.body.joints.forEach { _ = container(for: $0) }
        func parent(of id: String) -> Entity {
            Catalog.body.joints.first { $0.parts.contains(id) }.map(container(for:)) ?? rig
        }

        // before puberty the body shape doesn't differ by sex
        let sex = female && !(age == .infant || age.isChild) ? "female" : "male"
        let look = Figure.Look(female: female, age: age, pregnant: pregnant, heritage: heritage, underwear: underwear, chest: chest, hips: hips)
        let realSkin = ModelLibrary.skin(look)
        let plain = Figure.Look(female: female, age: .adult, pregnant: false, heritage: heritage, underwear: underwear)
        unshaped = look != plain ? plain : nil
        surface = realSkin == nil ? nil : Figure.surface(look)
        self.realSkin = realSkin != nil
        seeThrough = !meridians.isEmpty
        for piece in realSkin ?? [] {
            let entity = ModelEntity(mesh: piece.mesh)
            entity.transform = piece.transform
            entity.name = "skin:\(piece.id)"
            skinEntities.append((entity, Self.skinMaterial(piece)))
            rig.addChild(entity)
            // the body itself can be tapped (a joint to bend, on a skin-only view)
            if piece.id == "body" {
                entity.components.set(InputTargetComponent())
                let mesh = piece.mesh, key = ObjectIdentifier(mesh)
                if let hit = Self.skinShapes[key], hit.mesh === mesh {
                    entity.components.set(CollisionComponent(shapes: [hit.shape]))
                } else {
                    Task { @MainActor in
                        if let shape = try? await ShapeResource.generateStaticMesh(from: mesh) {
                            Self.skinShapes[key] = (mesh, shape)
                            entity.components.set(CollisionComponent(shapes: [shape]))
                        }
                    }
                }
            }
        }
        // a pregnant body swaps the female torso for one with the bump
        for part in Catalog.body.parts where realSkin == nil && part.layer == .skin && Self.skinWanted(part, sex: sex, pregnant: pregnant) {
            let entity = Self.entity(for: part.shape)
            // eyes, lips and brows keep their own colour; everything else takes the skin tone
            let color = part.color == "#F2C9A5" ? skinColor : UIColor(hex: part.color)
            entity.name = "skin:\(part.id)"
            let texture = part.id.hasPrefix("hair") ? Textures.hair : nil
            parent(of: part.id).addChild(entity)
            skinEntities.append((entity, Self.material(color, opacity: 1, texture: texture)))
        }

        for organ in Catalog.body.organs where organ.onlyPregnant != true || pregnant {
            let variant = (!female ? organ.male : nil) ?? (pregnant ? organ.pregnant : nil)
                ?? Organ.Variant(position: organ.position, color: organ.color, shapes: organ.shapes)
            // container sits on the pulse target so it scales about it
            let container = Entity()
            let real = pregnant && organ.id == "uterus" ? nil : InternalModels.organ(organ.id, female: female)
            container.position = real?.centre ?? variant.position.simd
            if let real {
                let piece = ModelEntity(mesh: real.piece.mesh)
                piece.transform = real.piece.transform
                piece.position -= real.centre
                piece.model?.materials = [Self.material(UIColor(hex: real.part.color), opacity: 1, texture: Textures.organ)]
                piece.name = organ.id
                organOpacity[ObjectIdentifier(piece)] = 1
                piece.components.set(InputTargetComponent())
                Task { @MainActor in
                    if let shape = await ModelLibrary.collision(for: real.piece) { piece.components.set(CollisionComponent(shapes: [shape])) }
                }
                container.addChild(piece)
            }
            for shape in real == nil ? variant.shapes : [] {
                let piece = Self.entity(for: shape)
                piece.position -= variant.position.simd
                // the pregnant womb is see-through so the baby shows
                let see = organ.region == true ? 0.45 : pregnant && organ.id == "uterus" ? 0.35 : 1
                piece.model?.materials = [Self.material(UIColor(hex: variant.color), opacity: Float(see),
                                                        texture: organ.region == true ? nil : organ.id == "brain" ? Textures.brain : Textures.organ)]
                piece.name = organ.names == nil ? "" : organ.id
                organOpacity[ObjectIdentifier(piece)] = Float(see)
                if organ.names != nil { Self.makeTappable(piece, shape: shape) }
                container.addChild(piece)
            }
            container.isEnabled = organ.region != true
            // at term the womb reaches the ribs: the gut is crowded up, back and to the sides of it
            if pregnant && organ.id == "intestines" {
                container.scale = SIMD3(1.15, 0.45, 0.6)
                container.position.y += 0.28
                container.position.z -= 0.09
            }
            rig.addChild(container)
            organEntities[organ.id] = container
        }

        // real bones replace the generated skeleton; each still turns with its joint
        let realBones = ModelLibrary.hasSkeleton
        for piece in realBones ? ModelLibrary.bones : [] {
            guard let part = ModelLibrary.part(piece.id) else { continue }
            let entity = ModelEntity(mesh: piece.mesh)
            entity.transform = piece.transform
            entity.name = part.id
            baseMaterials[part.id] = MaterialKey(UIColor(hex: part.color), opacity: 1)
            entity.model?.materials = [Self.material(baseMaterials[part.id]!)]
            entity.components.set(InputTargetComponent())
            Task { @MainActor in
                if let shape = await ModelLibrary.collision(for: piece) { entity.components.set(CollisionComponent(shapes: [shape])) }
            }
            (part.joint.flatMap { Catalog.joint($0) }.map(container(for:)) ?? rig).addChild(entity)
            partEntities[part.id] = entity
            partLayer[part.id] = part.layer
        }

        // real muscles, vessels and nerves: bone-fitted meshes, limb pieces turn with their joint
        for (part, piece) in InternalModels.parts(female: female) {
            let entity = ModelEntity(mesh: piece.mesh)
            entity.transform = piece.transform
            entity.name = part.id
            let texture = part.layer == .muscular ? Textures.muscle : part.layer == .organs ? Textures.organ : nil
            baseMaterials[part.id] = MaterialKey(UIColor(hex: part.color), opacity: 1, texture: texture)
            entity.model?.materials = [Self.material(baseMaterials[part.id]!)]
            entity.components.set(InputTargetComponent())
            Task { @MainActor in
                if let shape = await ModelLibrary.collision(for: piece) { entity.components.set(CollisionComponent(shapes: [shape])) }
            }
            (part.joint.flatMap { Catalog.joint($0) }.map(container(for:)) ?? rig).addChild(entity)
            partEntities[part.id] = entity
            partLayer[part.id] = part.layer
        }

        // internal sex-specific parts (ovaries, testes) exist at every age
        let organSex = female ? "female" : "male"
        for part in Catalog.body.parts where part.layer != .skin && !(realBones && part.layer == .skeletal) && !InternalModels.replaces(part.id)
            && (part.sex == nil || part.sex == organSex) {
            let entity = Self.entity(for: part.shape)
            entity.name = part.id
            baseMaterials[part.id] = MaterialKey(UIColor(hex: part.color), opacity: 1, texture: Textures.for(part.layer))
            entity.model?.materials = [Self.material(baseMaterials[part.id]!)]
            Self.makeTappable(entity, shape: part.shape)
            parent(of: part.id).addChild(entity)
            partEntities[part.id] = entity
            partLayer[part.id] = part.layer
        }

        let meridianColor = Dictionary(meridians.map { ($0.id, UIColor(hex: $0.color)) }) { a, _ in a }
        let adultShape = sex == "female"
        for point in points {
            // acupuncture points are small, coloured by meridian, on both sides; reflex points one big dot
            let sites = point.acu?.sites(female: adultShape).map(\.simd) ?? [point.position.simd]
            let color = point.acu.flatMap { meridianColor[$0.meridian] } ?? UIColor(hex: "#6C4F9E")
            pointColors[point.id] = color
            if point.acu != nil { smallPoints.insert(point.id) }
            pointEntities[point.id] = sites.map { site in
                let small = point.acu != nil
                let dot = ModelEntity(mesh: small ? Self.acuDot : Self.reflexDot, materials: [UnlitMaterial(color: color)])
                dot.name = "point:\(point.id)"
                dot.position = site
                dot.components.set(InputTargetComponent())
                dot.components.set(CollisionComponent(shapes: [.generateSphere(radius: small ? 0.032 : 0.09)]))
                rig.addChild(dot)
                return dot
            }
        }
        // adult channels already lie on the default adult skin; other figures (with their body options) are laid onto
        // its own (a new mesh, not reshaped)
        let lay = age == .infant || age.isChild || (female && age == .adult)
        for meridian in meridians {
            let material = UnlitMaterial(color: meridianColor[meridian.id] ?? .gray)
            meridianEntities[meridian.id] = meridian.pieces(female: adultShape).map { paths in
                let mesh: MeshResource
                if lay, let surface {
                    let laid = paths.map { $0.map { p -> Vec3 in
                        let q = surface.snap(agePoint(p.simd), lift: 0.0026)
                        return Vec3(q.x, q.y, q.z)
                    } }
                    mesh = Meshes.raw(for: Self.meridianShape(laid))?.resource() ?? Self.unitSphere
                } else {
                    mesh = Self.mesh(for: Self.meridianShape(paths))
                }
                let line = ModelEntity(mesh: mesh, materials: [material])
                line.name = lay && surface != nil ? "laid" : ""
                rig.addChild(line)
                return line
            }
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
        // remember every body piece at rest (adult pose, body coordinates) so age can reshape it
        rest = []
        func keep(_ e: Entity, centre: SIMD3<Float>) { rest.append((e, e.transform.matrix, centre)) }
        for e in partEntities.values { keep(e, centre: e.visualBounds(relativeTo: rig).center) }
        for (e, _) in skinEntities { keep(e, centre: e.visualBounds(relativeTo: rig).center) }
        for e in organEntities.values { keep(e, centre: e.position) }
        innerEntities = Set(organEntities.values.map(ObjectIdentifier.init))
        for e in pointEntities.values.joined() { keep(e, centre: e.position) }
        for e in meridianEntities.values.joined() { keep(e, centre: e.visualBounds(relativeTo: rig).center) }
        applyVisibility()
        applyMeridians()
        applyAge()
        addFieldJoints()
    }

    /// Skin part for this body: sex-specific parts match the sex; the pregnant torso replaces the female one.
    private static func skinWanted(_ part: SchematicPart, sex: String, pregnant: Bool) -> Bool {
        switch part.sex {
        case nil: true
        case "pregnant": pregnant
        // a female part with a pregnant twin (torso, head, hair) gives way to it
        case "female": sex == "female" && !(pregnant && Catalog.part(part.id.replacingOccurrences(of: "female", with: "pregnant")) != nil)
        default: part.sex == sex
        }
    }

    // MARK: age — children have their own proportions

    /// scene y of the chin; everything above it is "head" for proportions
    private static let chinY: Float = 1.25
    /// the neck (shoulders to chin) shortens in young children; the head sits down on it
    private static let neckBaseY: Float = 1.05
    /// below this (scene y) a piece belongs to a leg; hips and shoulders are the limb pivots
    private static let legTopY: Float = -0.04
    private static let hip = SIMD3<Float>(0.167, 0.12, 0)
    private static let shoulder = SIMD3<Float>(0.344, 1.004, -0.056)
    private var rest: [(entity: Entity, matrix: float4x4, centre: SIMD3<Float>)] = []
    /// organ containers: inside the body like the parts in partLayer, fitted to the skeleton's head
    private var innerEntities: Set<ObjectIdentifier> = []
    private var organScale: [String: SIMD3<Float>] = [:]
    private var age: AgeGroup = .adult

    private struct Proportions {
        var body: Float = 1          // overall size vs adult
        var head: Float = 1          // head enlargement on top of that
        var legLength: Float = 1, legGirth: Float = 1
        var armLength: Float = 1, armGirth: Float = 1
        var trunkWidth: Float = 1, trunkDepth: Float = 1
        var neck: Float = 1
    }

    private var proportions: Proportions {
        switch age {
        // ~70 cm, head a quarter of height, legs a third, round belly
        case .infant: Proportions(body: 0.4, head: 1.85, legLength: 0.72, legGirth: 1.4, armLength: 0.85, armGirth: 1.3, trunkWidth: 1.12, trunkDepth: 1.3, neck: 0.3)
        // ~88 cm, head a fifth of height
        case .toddler: Proportions(body: 0.5, head: 1.5, legLength: 0.82, legGirth: 1.25, armLength: 0.9, armGirth: 1.2, trunkWidth: 1.08, trunkDepth: 1.2, neck: 0.45)
        // ~120 cm, head a sixth, limbs nearly adult proportion
        case .child: Proportions(body: 0.68, head: 1.25, legLength: 0.95, legGirth: 1.05, armLength: 0.97, armGirth: 1.05, trunkWidth: 1.0, trunkDepth: 1.05, neck: 0.75)
        case .adult, .senior: Proportions()
        }
    }

    /// Body-coordinate reshaping for whatever region `c` falls in.
    /// the jaw hangs below the chin line but moves with the head
    private static let jawParts = ["mandible", "chin", "lower-teeth", "masseter", "skin:chin", "skin:lip", "deep-head", "skin:head", "skin:hair"]

    /// The real skull, brain, face muscles… are fitted to the man's head (build_models.SKULL); on the other skins they're
    /// scaled about the eyeball centre and shifted so the orbits hold the eyes and the cranium the scalp
    /// (build_models.HEAD_FIT, adult body coordinates before the age reshape).
    private static let headPivot = SIMD3<Float>(0, 1.45, 0.132)
    private var headFit: (scale: SIMD3<Float>, shift: SIMD3<Float>)? {
        switch age {
        case .infant: (SIMD3(1.3, 0.95, 1.2), SIMD3(0, 0.02, -0.006))
        case .toddler: (SIMD3(1.3, 0.93, 1.2), SIMD3(0, 0.012, 0.008))
        case .child: (SIMD3(1.22, 0.98, 1.16), SIMD3(0, 0.008, 0.006))
        case .adult, .senior: female ? (SIMD3(1.03, 0.98, 0.87), SIMD3(0, -0.001, -0.006)) : nil
        }
    }

    /// A young child's skull: a bigger cranial vault (and brain) over a smaller face, each about its own centre
    /// (adult body coordinates, before the head fit).
    private static let vaultParts = ["frontal-bone", "parietal-bone", "occipital-bone", "temporal-bone", "brain", "dural-sinuses",
                                     "cerebral-arteries", "epicranial-aponeurosis", "frontalis", "occipitalis", "temporalis"]
    private static let faceParts = ["maxilla", "mandible", "upper-teeth", "lower-teeth", "zygomatic", "nasal-", "vomer", "palatine",
                                    "lacrimal", "masseter", "orbicularis-oris", "facial-muscles", "zygomaticus", "suprahyoid"]
    private static let vaultCentre = SIMD3<Float>(0, 1.53, 0.02), faceCentre = SIMD3<Float>(0, 1.41, 0.1)

    /// The stylized faces' noses are smaller than the anatomy's: the nose's bones and cartilage sit further back.
    private func noseBack(_ name: String) -> float4x4 {
        let id = name.hasPrefix("skin:") ? String(name.dropFirst(5)) : name
        guard id.hasPrefix("nasal-") else { return matrix_identity_float4x4 }
        var m = matrix_identity_float4x4
        m.columns.3.z = female || age.isChild || age == .infant ? -0.015 : -0.018
        return m
    }

    private func youngSkull(_ name: String) -> float4x4 {
        let (vault, face): (Float, Float) = switch age {
        case .infant: (1.2, 0.8)
        case .toddler: (1.13, 0.86)
        case .child: (1.05, 0.94)
        default: (1, 1)
        }
        let id = name.hasPrefix("skin:") ? String(name.dropFirst(5)) : name
        let (k, c): (Float, SIMD3<Float>) = Self.vaultParts.contains(where: { id.hasPrefix($0) }) ? (vault, Self.vaultCentre)
            : Self.faceParts.contains(where: { id.hasPrefix($0) }) ? (face, Self.faceCentre) : (1, .zero)
        guard k != 1 else { return matrix_identity_float4x4 }
        var m = matrix_identity_float4x4
        m.columns.0.x = k; m.columns.1.y = k; m.columns.2.z = k
        m.columns.3 = SIMD4(c - k * c, 1)
        return m
    }

    private func reshape(_ c: SIMD3<Float>, name: String = "", inner: Bool = false) -> float4x4 {
        let p = proportions
        func about(_ pivot: SIMD3<Float>, _ s: SIMD3<Float>) -> float4x4 {
            var m = matrix_identity_float4x4
            m.columns.0.x = s.x; m.columns.1.y = s.y; m.columns.2.z = s.z
            m.columns.3 = SIMD4(pivot - s * pivot, 1)
            return m
        }
        if c.y > Self.chinY || Self.jawParts.contains(where: { name.hasPrefix($0) }) {
            // scaled about the midline, chin put on top of the shortened neck
            var m = about(.zero, SIMD3(repeating: p.head))
            m.columns.3.y = Self.neckBaseY + (Self.chinY - Self.neckBaseY) * p.neck - Self.chinY * p.head
            if inner, let fit = headFit {
                var h = matrix_identity_float4x4
                h.columns.0.x = fit.scale.x; h.columns.1.y = fit.scale.y; h.columns.2.z = fit.scale.z
                h.columns.3 = SIMD4(Self.headPivot - fit.scale * Self.headPivot + fit.shift, 1)
                m = m * h * youngSkull(name)
            }
            return inner ? m * noseBack(name) : m
        }
        let side: Float = c.x < 0 ? -1 : 1
        // arms first: hands hang lower than the hips
        if abs(c.x) > 0.316 {
            return about(Self.shoulder * SIMD3(side, 1, 1), SIMD3(p.armGirth, p.armLength, p.armGirth))
        }
        if c.y < Self.legTopY {
            return about(Self.hip * SIMD3(side, 1, 1), SIMD3(p.legGirth, p.legLength, p.legGirth))
        }
        if c.y > Self.neckBaseY {
            return about(SIMD3(0, Self.neckBaseY, 0), SIMD3(p.trunkWidth, p.neck, p.trunkDepth))
        }
        return about(.zero, SIMD3(p.trunkWidth, 1, p.trunkDepth))
    }

    /// Age-specific pieces.
    private func feature(_ name: String) -> Float {
        let id = name.hasPrefix("skin:") ? String(name.dropFirst(5)) : name
        let young: Float = switch age { case .infant: 1; case .toddler: 0.75; case .child: 0.4; default: 0 }
        guard young > 0 else { return 1 }
        if id.hasPrefix("breast") || id == "adams-apple" { return 0.0001 }
        if id.hasPrefix("hair-long") && young >= 0.75 { return 0.0001 }
        if id == "nose" || id.hasPrefix("nostril") { return 1 - 0.35 * young }
        if id.hasPrefix("eye-") || id.hasPrefix("iris") || id.hasPrefix("pupil") || id.hasPrefix("eyelid") { return 1 + 0.2 * young }
        if id.hasPrefix("brow") { return 1 - 0.4 * young }
        if id.hasPrefix("lip") { return 1 - 0.2 * young }
        return 1
    }

    /// adult body point → where it sits on this age's body (rig space, before the overall scale)
    private func agePoint(_ q: SIMD3<Float>) -> SIMD3<Float> {
        let r = reshape(q) * SIMD4(q, 1)
        return SIMD3(r.x, r.y, r.z)
    }

    func setAge(_ age: AgeGroup) {
        self.age = age
        applyAge()
    }

    private func applyAge() {
        rig.scale = SIMD3(repeating: proportions.body)
        // eye parts grow together about their eyeball, so the iris stays on its surface
        let eyeCentre = Dictionary(rest.filter { $0.entity.name.hasPrefix("skin:eye-") }.map { (String($0.entity.name.suffix(1)), $0.centre) }) { a, _ in a }
        for (entity, matrix, centre) in rest {
            // a feature's own size change happens about its centre, before the region reshape
            // the real figure is already built for this age, children's channels already laid on it
            if (realSkin && entity.name.hasPrefix("skin:")) || entity.name == "laid" {
                entity.transform.matrix = matrix
                continue
            }
            if let surface, entity.name.hasPrefix("point:") {
                let site = agePoint(SIMD3(matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z))
                entity.transform = Transform(translation: surface.snap(site, lift: smallPoints.contains(String(entity.name.dropFirst(6))) ? 0.0047 : 0.02))
                continue
            }
            let f = feature(entity.name)
            var local = matrix_identity_float4x4
            if f != 1 {
                let isEye = ["skin:eye-", "skin:iris-", "skin:pupil-", "skin:eyelid-"].contains { entity.name.hasPrefix($0) }
                let pivot = isEye ? eyeCentre[String(entity.name.suffix(1))] ?? centre : centre
                local.columns.0.x = f; local.columns.1.y = f; local.columns.2.z = f
                local.columns.3 = SIMD4(pivot - f * pivot, 1)
            }
            let inner = partLayer[entity.name].map { $0 != .skin } ?? innerEntities.contains(ObjectIdentifier(entity))
            entity.transform.matrix = reshape(centre, name: entity.name, inner: inner) * local * matrix
        }
        for joint in Catalog.body.joints {
            guard let outer = jointOuter[joint.id], let inner = jointInner[joint.id] else { continue }
            let pivot = agePoint(joint.pivot.simd)
            outer.position = pivot
            inner.position = -pivot
        }
        tuckInside()
        backRest = [:]
        placeBack()
        organScale = organEntities.mapValues(\.scale)
        // a new size of body is framed again; the same body (another look, sex, clothes) keeps the view
        if framedAge != age {
            framedAge = age
            focus(.all)
        }
    }

    /// A child's skin is its own mesh, not the reshaped adult one: a muscle, vessel or nerve that would poke
    /// through it is thinned about its long axis until it sits inside; one lying just under the skin (a long vein) hides.
    private func tuckInside() {
        let before = hiddenForAge
        hiddenForAge = []
        defer { if hiddenForAge != before { applyVisibility() } }
        guard let surface, age == .infant || age.isChild else { return }
        let chin = agePoint(SIMD3(0, Self.chinY, 0)).y
        for (id, entity) in partEntities {
            guard let layer = partLayer[id], [.muscular, .circulatory, .nervous].contains(layer), let model = entity.model else { continue }
            let m = entity.transform.matrix
            var pts: [SIMD3<Float>] = []
            for part in model.mesh.contents.models.flatMap({ Array($0.parts) }) {
                let pos = part.positions.elements
                for i in stride(from: 0, to: pos.count, by: max(1, pos.count / 400)) {
                    let p = m * SIMD4(pos[i], 1)
                    pts.append(SIMD3(p.x, p.y, p.z))
                }
            }
            guard !pts.isEmpty else { continue }
            // a piece wholly in the head (fitted as a whole, its muscles hug the face) only shrinks a little, never hides
            let head = pts.map(\.y).min()! >= chin
            var c = pts.reduce(.zero, +) / Float(pts.count)
            // shrink toward a point well inside the skin (a thin piece along the skin has its own centre near it)
            let (depth, normal) = surface.depthNormal(c)
            if depth > -0.03 && !head { c -= normal * (depth + 0.03) }
            // thinned across its length (a limb muscle keeps its attachments), not shortened
            var axis = SIMD3<Float>(0, 1, 0)
            for _ in 0..<8 {
                var next = SIMD3<Float>.zero
                for p in pts { let d = p - c; next += d * simd_dot(d, axis) }
                if simd_length(next) > 1e-9 { axis = simd_normalize(next) }
            }
            // a Transform holds no shear: a lengthwise (mostly vertical) piece thins in x and z, any other shrinks evenly
            let upright = abs(axis.y) > 0.7 && !head
            let squeeze = { (s: Float) in simd_float3x3(diagonal: SIMD3(s, upright ? 1 : s, s)) }
            let out = { (s: Float) in let q = squeeze(s); return pts.contains { surface.depth(c + q * ($0 - c)) > -0.005 } }
            guard out(1) else { continue }
            // still out even thinned: it lies just under this skin (a superficial vein, a slip of muscle) and hides
            let floor: Float = head ? 0.8 : layer == .muscular ? 0.5 : 0.35  // thinner still would leave gaps
            if out(floor) && !head {
                hiddenForAge.insert(id)
                continue
            }
            var (s, big): (Float, Float) = (floor, 1)
            for _ in 0..<5 {
                let mid = (s + big) / 2
                if out(mid) { big = mid } else { s = mid }
            }
            let q = squeeze(s)
            var k = matrix_identity_float4x4
            k.columns.0 = SIMD4(q.columns.0, 0); k.columns.1 = SIMD4(q.columns.1, 0); k.columns.2 = SIMD4(q.columns.2, 0)
            k.columns.3 = SIMD4(c - q * c, 1)
            entity.transform.matrix = k * m
        }
    }

    /// adult scene y (on the body's midline, or a limb) → scene y for this age
    private func ageY(_ y: Float, x: Float = 0) -> Float {
        agePoint(SIMD3(x, y, 0)).y * proportions.body
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

    /// A slider's move, bent on the next frame (update): a drag sends more moves than frames, each a full skin bend.
    func dragJoint(_ id: String, degrees: Float) { pendingJoints[id] = degrees }
    private var pendingJoints: [String: Float] = [:]

    func setJoint(_ id: String, degrees: Float) {
        pendingJoints[id] = nil
        guard let joint = joints.first(where: { $0.id == id }), let outer = jointOuter[id] else { return }
        outer.orientation = simd_quatf(angle: degrees * .pi / 180, axis: simd_normalize(joint.axis.simd))
        jointAngles[id] = degrees
        // the working muscle shortens and thickens
        let bulge = 1 + 0.6 * min(1, degrees / joint.maxDeg)
        for mover in joint.movers where !InternalModels.replaces(mover) {
            guard let entity = partEntities[mover], let shape = Catalog.part(mover)?.shape else { continue }
            switch shape {
            case let .spindle(from, to, radius):
                entity.scale = SIMD3(radius * bulge, simd_distance(from.simd, to.simd) / 2 * (2 - bulge).squareRoot(), radius * 0.8 * bulge)
            case let .lathe(_, _, _, scale):
                entity.scale = (scale?.simd ?? SIMD3(repeating: 1)) * SIMD3(bulge, (2 - bulge).squareRoot(), bulge)
            default:
                break
            }
        }
        bendCrossing(joint)
        if id == "back" { placeBack() }
        bendSkin()
    }

    nonisolated static func smooth(_ a: Float, _ b: Float, _ x: Float) -> Float {
        let t = max(0, min(1, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }

    /// how much a point beside a joint (not under it) follows it, by its distance from the joint's vertical line:
    /// a chest muscle's far end stays while the shoulder lifts the arm
    private static func beside(_ q: SIMD3<Float>, _ pivot: SIMD3<Float>) -> Float {
        1 - smooth(0.1, 0.22, simd_length(SIMD2(q.x - pivot.x, q.z - pivot.z)))
    }

    // MARK: the skin over bent joints

    private struct SkinBend {
        let bender: SkinDeformer
        let toLocal: float4x4
        /// rest positions and normals in the rig's space, and per vertex the container its nearest bone sits under
        let rest: [SIMD3<Float>]
        let normals: [SIMD3<Float>]
        let holder: [Int]
        /// per vertex its side's shoulder share (shoulderShares) and that side (the sign of x)
        let shoulder: [Float]
        let side: [Float]
        /// per vertex how much it lies on the shoulder top (shoulderTop; a garment's from the skin it follows)
        var top: [Float] = []
        /// body: welded index per vertex, the welded band skin relaxShoulders moves, its welded neighbours, its cut on
        /// convex moves and the triangles touching it; garment: per vertex its nearest body skin and weights (it carries the body's relax)
        var canon: [Int] = []
        var band: [Int] = []
        var bandNear: [[Int]] = []
        var bandConvex: [Float] = []
        var bandTris: [Int] = []
        /// the share's gradient over the rest skin per band vertex, and each vertex's band slot (-1 off the band)
        var bandGrad: [SIMD3<Float>] = []
        var bandOf: [Int] = []
        var follow: [[(Int, Float)]] = []
        /// garment: per vertex its rest offset from that skin point and how far behind the shoulder it lies (wrapGarment)
        var followOffset: [SIMD3<Float>] = []
        var followBehind: [Float] = []
        /// packed for bendSkin: band neighbours as offsets + slots (a band vertex's slot, or past the band one per neighbour
        /// off it: `ghosts`, held fixed during a smoothing), the vertices whose welded one is on the band, the garment's follow
        var nearStart: [Int32] = [], nearSlot: [Int32] = [], ghosts: [Int32] = []
        var bandVerts: [Int32] = []
        var followStart: [Int32] = [], followIdx: [Int32] = [], followW: [Float] = []
        /// every vertex relaxShoulders reads (band, ghosts, band vertices, the band triangles' corners)
        var relaxInputs: [Int32] = []
        var scratch = SkinScratch(count: 0, banded: false, slots: 0, start: [0], slot: [])

        mutating func pack() {
            nearStart = [0]
            var ghost: [Int: Int32] = [:]
            for near in bandNear {
                for j in near {
                    if bandOf[j] >= 0 { nearSlot.append(Int32(bandOf[j])); continue }
                    if ghost[j] == nil { ghost[j] = Int32(band.count + ghosts.count); ghosts.append(Int32(j)) }
                    nearSlot.append(ghost[j]!)
                }
                nearStart.append(Int32(nearSlot.count))
            }
            scratch = SkinScratch(count: rest.count, banded: !bandOf.isEmpty, slots: band.count + ghosts.count, start: nearStart, slot: nearSlot)
            bandVerts = bandOf.indices.filter { bandOf[$0] >= 0 }.map(Int32.init)
            if !band.isEmpty {
                let t = bender.triangles
                relaxInputs = Set(band.map(Int32.init) + ghosts + bandVerts + bandTris.flatMap { [Int32(t[$0]), Int32(t[$0 + 1]), Int32(t[$0 + 2])] }).sorted()
            }
            if !follow.isEmpty {
                followStart = [0]
                for f in follow {
                    for (j, w) in f { followIdx.append(Int32(j)); followW.append(w) }
                    followStart.append(Int32(followIdx.count))
                }
            }
        }

        /// The band slots garmentMove must smooth for these vertices (garments follow only them): a slot k rings from
        /// them matters for the last garmentPasses - k passes.
        func carry(_ followed: Set<Int>) {
            let n = band.count
            var ring = [Int](repeating: .max, count: n), queue: [Int] = []
            for i in followed where bandOf[i] >= 0 && ring[bandOf[i]] == .max { ring[bandOf[i]] = 0; queue.append(bandOf[i]) }
            var head = 0
            while head < queue.count {
                let b = queue[head]; head += 1
                guard ring[b] < garmentPasses else { continue }
                for e in Int(nearStart[b])..<Int(nearStart[b + 1]) {
                    let j = Int(nearSlot[e])
                    if j < n && ring[j] == .max { ring[j] = ring[b] + 1; queue.append(j) }
                }
            }
            // queue is in ring order
            scratch.carry(order: queue.map(Int32.init), reach: (0..<garmentPasses).map { k in queue.lazy.filter { ring[$0] <= k }.count })
        }
    }

    /// per-call buffers for bendSkin, allocated once per skin, and the band's neighbour lists (SkinBend.nearStart, nearSlot)
    private final class SkinScratch {
        /// per vertex; pre, jac, move and the turned skin (now, nowN, for wrapGarment) only on the body (`banded`)
        let pos, nrm, pre, jac, move, now, nowN: UnsafeMutablePointer<SIMD3<Float>>
        let occ: UnsafeMutablePointer<Float>
        /// per vertex: the hinge side whose crease it lies in (contactShade), 0 none
        let crease: UnsafeMutablePointer<Int32>
        /// per band slot (with ghosts)
        let k, kn, wn, size, inward, ridge: UnsafeMutablePointer<Float>
        let delta, ref, p, step, g, m, next, t: UnsafeMutablePointer<SIMD3<Float>>
        let active, start, slot: UnsafeMutablePointer<Int32>
        /// relaxShoulders' last input (relaxInputs' positions, normals, pre-turn points and chord normals, the turns, carry) and
        /// its output (the band vertices' positions and normals, what it returned)
        var relaxIn: [SIMD3<Float>] = [], relaxOut: [SIMD3<Float>] = [], relaxed = false
        /// the slots garmentMove smooths, nearest the garments first, and per ring how many
        private(set) var order: UnsafeMutablePointer<Int32>?
        private(set) var reach: [Int] = []
        private var all: [UnsafeMutableRawPointer] = []

        /// n vertices, b band slots (with ghosts)
        init(count n: Int, banded: Bool, slots b: Int, start: [Int32], slot: [Int32]) {
            func make<T>(_ c: Int, _ v: T) -> UnsafeMutablePointer<T> {
                let q = UnsafeMutablePointer<T>.allocate(capacity: max(1, c))
                q.initialize(repeating: v, count: max(1, c))
                return q
            }
            func copy(_ a: [Int32]) -> UnsafeMutablePointer<Int32> {
                let q = make(a.count, Int32(0))
                for (i, v) in a.enumerated() { q[i] = v }
                return q
            }
            let nb = banded ? n : 0
            pos = make(n, .zero); nrm = make(n, .zero); pre = make(nb, .zero); jac = make(nb, .zero); move = make(nb, .zero)
            now = make(nb, .zero); nowN = make(nb, .zero)
            occ = make(n, 0); crease = make(n, Int32(0))
            k = make(b, 0); kn = make(b, 0); wn = make(b, 0); active = make(b, 0); inward = make(b, 0); ridge = make(b, 0)
            delta = make(b, .zero); ref = make(b, .zero); p = make(b, .zero); step = make(b, .zero)
            g = make(b, .zero); m = make(b, .zero); next = make(b, .zero); t = make(b, .zero)
            self.start = copy(start); self.slot = copy(slot)
            size = make(start.count, 0)
            for i in 0..<start.count - 1 { size[i] = Float(start[i + 1] - start[i]) }
            all = [pos, nrm, pre, jac, move, now, nowN, delta, ref, p, step, g, m, next, t].map { UnsafeMutableRawPointer($0) }
                + [occ, k, kn, wn, size, inward, ridge].map { UnsafeMutableRawPointer($0) } + [active, self.start, self.slot, crease].map { UnsafeMutableRawPointer($0) }
        }

        func carry(order o: [Int32], reach r: [Int]) {
            order?.deallocate()
            let q = UnsafeMutablePointer<Int32>.allocate(capacity: max(1, o.count))
            for (i, v) in o.enumerated() { q[i] = v }
            order = q
            reach = r
        }

        deinit {
            for q in all { q.deallocate() }
            order?.deallocate()
        }
    }
    private var skinBends: [SkinBend] = []
    /// the pose (bendSkin's key) and deformer versions the skin was last bent for: unchanged, nothing to redo
    private var skinPose: (key: [Float], versions: [Int])?
    /// the skin and underwear as last bent, for moves laid over a pose (a hand pressing in)
    var skinDeformers: [SkinDeformer] { skinBends.map(\.bender) }
    /// half-width of the shoulder's blend band round the arm/torso split (body units)
    private static let shoulderBand: Float = 0.2
    /// passes smoothing the shoulder share over the skin
    private static let shoulderSmoothing = 40
    /// the smoothing also takes the arm's rigid skin this far (x band) from the split: the share's corner at 1 creased the
    /// coarse arm skin behind the armpit
    private static let shoulderReach: Float = 1.25
    /// inner arm bound to the ribs: within this of the humerus, this far below the shoulder pivot
    private static let innerArm: Float = 0.11, innerBelow: Float = 0.14
    /// torso skin above the shoulder pivot: its share fades out from farFrom to farTo off the pivot (body units), so the
    /// upper back and neck base don't slide down with a raised arm
    private static let farFrom: Float = 0.12, farTo: Float = 0.32, farUp: Float = 0.06
    /// relaxShoulders: passes, rate, the cut on moves sinking convex skin, and the arm turn it eases in over
    private static let relaxPasses = 80, relaxRate: Float = 0.8, relaxConvex: Float = 0.1
    private static let relaxFrom: Float = 60 * .pi / 180, relaxFull: Float = 160 * .pi / 180
    /// from this arm turn a ridge (skin pulled in, its neighbours not) escapes the convex cut, fully at relaxFull: the
    /// chord left a lit crease at the front armpit
    private static let ridgeFrom: Float = 110 * .pi / 180
    /// behind the pivot (body units) the convex cut fades out: the chord leaves a rounded bump on the back of the shoulder;
    /// garments ride the skin fully this far behind it, not at all this far in front (wrapGarment)
    private static let relaxBehind: Float = 0.06
    /// the cut's leak per pass scales by (relaxScale / edge length)^2, up to free: the mean's pull grows with the edge
    /// length squared, so coarse armpit skin sank far and the fine skin below it not (a crease along their seam)
    private static let relaxScale: Float = 0.04
    /// shoulder top: above the pivot and not behind it (ramps, body units). A raised arm's chord shrinks the skin's radius
    /// round its axis and sinks the top into the joint; there it keeps the radius and topKeep - 1 of what it lost more
    /// (the skin bunches up), eased in like the relax
    private static let topFrom: Float = -0.03, topTo: Float = 0.09, topKeep: Float = 1.5
    private static func shoulderTop(_ q: SIMD3<Float>, pivot: SIMD3<Float>) -> Float {
        smooth(topFrom, topTo, q.y - pivot.y) * (1 - smooth(topFrom, topTo, pivot.z - q.z))
    }
    /// band normals: the share's gradient fades out over this much share before the arm (its kink there would shade a
    /// ring), then passes averaging them with their neighbours, easing in over these arm turns (below, the chord's normals
    /// are exact and the averaging would blur the shoulder) and giving way to the relax's surface
    private static let gradFade: Float = 0.3, normalPasses = 20, normalFrom: Float = 45 * .pi / 180, normalFull: Float = 90 * .pi / 180
    /// passes smoothing the relax's slide along the skin before garments carry it
    nonisolated private static let garmentPasses = 40
    /// the plain adult look (no bump, chest or hips options): those move skin (a hand beside the bump) off its bones, and a child's
    /// skin isn't on the adult bones, so the skin binds on this (same vertices) with the bones at rest
    private var unshaped: Figure.Look?
    private var holders: [Entity] = []
    private var jointAngles: [String: Float] = [:]
    /// joints the body can bend: the catalogue's (shoulders hung from the back) plus the back and neck found on the
    /// real skeleton at build (fieldJoints), or the catalogue's alone
    private(set) var joints: [Joint] = Catalog.body.joints
    /// whether to add the back and neck (the CPR trainer keeps its rig flat)
    var fieldJoints = true
    /// joints whose moving side is above the pivot
    private static let upward: Set<String> = ["back", "neck"]

    /// a point's share of a joint's turn by its height: all on the moving side past the band, none past it the other way
    private static func share(up: Bool, pivotY: Float, _ y: Float) -> Float {
        let band = bendBand
        return up ? smooth(pivotY - band, pivotY + band, y) : smooth(pivotY + band, pivotY - band, y)
    }

    /// the neck's turn over the neck alone: from the old band's foot up to a top tilted along the jaw line (under the chin
    /// in front, the skull's base behind) so the face turns whole; off the neck's column only the head turns (collarbones,
    /// straps stay). Fitted on the adult woman
    private static let neckTop: Float = 0.02, neckBottom: Float = -0.12, neckTilt: Float = 0.469, neckColumn: (Float, Float) = (0.09, 0.14)
    private static func neckShare(_ q: SIMD3<Float>, pivot: SIMD3<Float>) -> Float {
        let y = q.y - pivot.y, tilt = neckTilt * (q.z - pivot.z)
        let r = simd_length(SIMD2(q.x - pivot.x, q.z - pivot.z))
        return smooth(neckBottom, max(neckTop - tilt, neckBottom + 0.02), y)
            * max(1 - smooth(neckColumn.0, neckColumn.1, r), smooth(neckTop - 0.04, neckTop, y + tilt))
    }
    /// whether the neck turns by neckShare (fitted on the adult woman), else by height
    private var neckFitted: Bool { female && age == .adult }

    /// joints folding like a hinge (knees, elbows): inside the bend the far limb presses on the near one
    private static func hinge(_ id: String) -> Bool { id.hasPrefix("knee") || id.hasPrefix("elbow") }
    /// on the extensor side the band drops below the knee's pivot (the kneecap rides the thigh) and widens, spreading the stretch
    private static let kneecapDrop: Float = 0.02, kneeWiden: Float = 0.08, elbowWiden: Float = 0.04
    /// depth (about the limb's radius) over which the band turns from the flexor to the extensor side: no step at the sides
    private static let kneeDepth: Float = 0.2, elbowDepth: Float = 0.07
    /// pressed flesh pushed out along the contact, per unit pressed; the contact fades in over this depth into the bend
    private static let pressBulge: Float = 0.5, pressRamp: Float = 0.03
    /// the press eases in over this either side of the contact plane: no edge where the skin meets it (a notch, a lit sliver)
    private static let pressSoft: Float = 0.004
    /// a crease's shadow (the renderer has no ambient occlusion): darkest in the contact, fading over `shadeFalloff` off the
    /// plane on skin facing it; in the contact (within `shadeContact`) whatever way the normal turned
    private static let shadeStrength: Float = 0.85, shadeFalloff: Float = 0.024, shadeContact: Float = 0.003
    /// the knee front's even turn eases in and out over this share of the band at each end: no edge where the band ends
    private static let kneeEase: Float = 0.3
    /// pressed knee skin facing along the axis (the limb's sides) keeps its own normal over this |n·axis|: the contact's rim
    /// isn't turned to face the other limb (a lit wedge in the pit's side)
    private static let sideKeep: (Float, Float) = (0.4, 0.9)
    /// a knee bent less than this (radians) is an open corner: its sides see the light, so no crease shade there (streaks
    /// below the crease end at knee-90); fully shaded from the top on (knee-135 unchanged)
    private static let kneeOpen: (Float, Float) = (1.75, 2.27)
    /// the crease's shade fades out with the distance to the other side's nearest pressed vertex: each side is pressed
    /// flat on the plane past the other limb's edge too (the forearm sits off the biceps), open skin there isn't shaded
    private static let contactReach: (Float, Float) = (0.015, 0.037)
    /// foldNormal: 1 + g·v held at foldFloor; the correction fades out over foldFade where the map turns inside out (the
    /// knee-135 pit's normals would flip) and where it would turn the normal past a right angle (cos below foldTurn)
    private static let foldFloor: Float = 0.1, foldFade: (Float, Float) = (-0.2, 0.05), foldTurn: Float = 0.3
    /// ... and only once the corner closes (radians; an open one keeps its soft radial normals, else a lit edge along the
    /// crease): the calf meets the thigh sooner than the forearm the biceps
    private static let foldKnee: (Float, Float) = (1.2, 1.5), foldElbow: (Float, Float) = (1.9, 2.35)

    /// a hinge's share: the height band, moved and widened toward the extensor side; over the kneecap it turns evenly
    /// (a smoothstep's steep middle stretched the front past 2x at full bend), widened to keep that slope with eased ends
    private static func hingeShare(knee: Bool, _ q: SIMD3<Float>, pivot: SIMD3<Float>, axis: SIMD3<Float>) -> Float {
        let f = simd_cross(axis, SIMD3(0, -1, 0))
        let e = smooth(0.2, -0.6, simd_dot(q - pivot, f) / (knee ? kneeDepth : elbowDepth))
        let o = (knee ? -kneecapDrop : 0) * e, band = bendBand + (knee ? kneeWiden : elbowWiden) * e
        let t = max(0, min(1, (pivot.y + o + band - q.y) / (2 * band))), s = t * t * (3 - 2 * t)
        guard knee else { return s }
        let a = kneeEase, wide = band / (1 - a * e), v = 1 / (1 - a)
        let u = max(0, min(1, (pivot.y + o + wide - q.y) / (2 * wide)))
        let g = u < a ? v * u * u / (2 * a) : u > 1 - a ? 1 - v * (1 - u) * (1 - u) / (2 * a) : v * (u - a / 2)
        return s + e * (g - s)
    }

    /// A hinge turn's normal with the share's gradient g (before the turn): p = pivot + R(wθ)d has Jacobian R(I + v gᵀ),
    /// v = θ axis × d, so n → n - g (v·n) / (1 + g·v). g by finite differences in height and depth into the limb, in the
    /// bend's moved frame (`up`, `axis`), times the share's scale beside the joint. Without it the fold ring (w ≈ 0.5) kept
    /// radial normals facing out of the crease, lit at its end. Returns the normal and how much of it to use.
    private static func foldNormal(_ q: SIMD3<Float>, d: SIMD3<Float>, nrm: SIMD3<Float>, scale: Float, knee: Bool,
                                   restPivot: SIMD3<Float>, restAxis: SIMD3<Float>, axis: SIMD3<Float>, up: SIMD3<Float>,
                                   theta: Float) -> (SIMD3<Float>, Float) {
        let h: Float = 1e-3, up0 = SIMD3<Float>(0, 1, 0), f0 = simd_cross(restAxis, SIMD3(0, -1, 0))
        func w(_ dq: SIMD3<Float>) -> Float { hingeShare(knee: knee, q + dq, pivot: restPivot, axis: restAxis) }
        let gy = (w(h * up0) - w(-h * up0)) / (2 * h), gf = (w(h * f0) - w(-h * f0)) / (2 * h)
        let g = scale * (gy * up + gf * simd_cross(axis, -up)), v = theta * simd_cross(axis, d)
        let raw = 1 + simd_dot(g, v)
        let nc = nrm - g * (simd_dot(v, nrm) / max(raw, foldFloor))
        let ln = simd_length(nrm)
        guard simd_length(nc) > 1e-12, ln > 1e-12 else { return (nrm, 0) }
        let n = simd_normalize(nc)
        return (n, smooth(foldFade.0, foldFade.1, raw) * smooth(0, foldTurn, simd_dot(n, nrm) / ln))
    }

    /// max(0, x) rounded over |x| < pressSoft, and its slope
    private static func eased(_ x: Float) -> (Float, Float) {
        let h = pressSoft
        if x >= h { return (x, 1) }
        if x <= -h { return (0, 0) }
        return ((x + h) * (x + h) / (4 * h), (x + h) / (2 * h))
    }

    /// inside a hinge's bend each side kept off the bisector plane (the calf pressed flat on the thigh, not through it),
    /// the pressed flesh pushed out along it; the normal follows the press (its Jacobian's inverse transpose, bulge left out).
    /// Also the crease's occlusion there (0...1). `n`: the bisector plane's normal (`up` turned by half the bend), `m`: n × axis.
    private static func pressed(_ p: SIMD3<Float>, _ nrm: SIMD3<Float>, near: Bool, weight k: Float, pivot: SIMD3<Float>,
                                n: SIMD3<Float>, m: SIMD3<Float>, knee: Bool, open: Float = 0, plain: SIMD3<Float>? = nil)
        -> (SIMD3<Float>, SIMD3<Float>, Float) {
        let d = p - pivot
        let s: Float = near ? 1 : -1
        let (e, de) = eased(-s * simd_dot(d, n))
        let sm = simd_dot(d, m), g = smooth(0, pressRamp, sm)
        let r = max(0, min(1, sm / pressRamp)), dg = 6 * r * (1 - r) / pressRamp
        let push = e * g * k
        let v = k * (-s * g * de * n + e * dg * m), u = s * n
        let q = (1 + simd_dot(u, v)) * nrm - simd_dot(u, nrm) * v
        let to = p + s * push * n + pressBulge * push * m
        var tn = simd_length(q) > 1e-6 ? simd_normalize(q) : nrm
        // skin facing along the axis: the limb's sides
        let side = smooth(sideKeep.0, sideKeep.1, abs(simd_dot(nrm, simd_cross(m, n))))
        // the open corner's side fade by the normal without foldNormal (that turns the crease end's sides to the contact)
        let openSide = plain.map { smooth(sideKeep.0, sideKeep.1, abs(simd_dot($0, simd_cross(m, n)))) } ?? side
        if knee {
            let kept = tn + side * (nrm - tn)
            if side > 0, simd_length(kept) > 1e-6 { tn = simd_normalize(kept) }
        }
        let gap = max(0, s * simd_dot(to - pivot, n)), off = 1 - smooth(0, shadeFalloff, gap)
        // a side only meets the plane, it isn't pressed: no contact shade there (a lone dark vertex, a dimple)
        let facing = max(smooth(-0.3, 0.5, -s * simd_dot(tn, n)), (1 - smooth(0, shadeContact, gap)) * (1 - side)) * (1 - openSide * open)
        return (to, tn, shadeStrength * k * smooth(0, pressRamp, simd_dot(to - pivot, m)) * off * facing)
    }

    /// each crease vertex's shade scaled by how near the other side's skin is (contactReach)
    private static func contactShade(occ: UnsafeMutablePointer<Float>, pos: UnsafeMutablePointer<SIMD3<Float>>,
                                     crease: UnsafeMutablePointer<Int32>, count: Int) {
        let r = contactReach.1, inv = 1 / r
        func cell(_ p: SIMD3<Float>) -> SIMD3<Int32> { SIMD3<Int32>((p * inv).rounded(.down)) }
        var cells: [SIMD3<Int32>: [Int32]] = [:]
        for i in 0..<count where crease[i] > 0 { cells[cell(pos[i]), default: []].append(Int32(i)) }
        if cells.isEmpty { return }
        for i in 0..<count where crease[i] > 0 && occ[i] > 0 {
            let other = ((crease[i] - 1) ^ 1) + 1, c = cell(pos[i])
            var best = r * r
            for dz in Int32(-1)...1 { for dy in Int32(-1)...1 { for dx in Int32(-1)...1 {
                guard let list = cells[c &+ SIMD3(dx, dy, dz)] else { continue }
                for j in list where crease[Int(j)] == other { best = min(best, simd_distance_squared(pos[i], pos[Int(j)])) }
            } } }
            occ[i] *= 1 - smooth(contactReach.0, r, best.squareRoot())
        }
    }

    /// a knee crease's rim: bins along m, the contact's half-thickness, a whole section's share; its fade off the plane, in
    /// from the pivot (sooner, the pit's end shears into a wedge) and out past the whole sections
    private static let rimBin: Float = 0.02, rimBins = 12, rimContact: Float = 0.012, rimWhole: Float = 0.8
    private static let rimDepth: Float = 0.05, rimRamp: Float = 0.08, rimEnd: Float = 0.05

    /// the calf's flare overhung the thigh's side at the crease (a ledge, a lit wedge at its end): near the plane each side's
    /// extent along the axis is remapped to the two sides' mean. Extents: per rimBin along m in the contact, out from the
    /// pivot while both sections are whole, fitted as lines in s. Positions only: the rim keeps its pressed normal (sideKeep)
    private static func kneeRim(pos: UnsafeMutablePointer<SIMD3<Float>>, crease: UnsafeMutablePointer<Int32>, count: Int,
                                tag: Int32, pivot: SIMD3<Float>, n: SIMD3<Float>, m: SIMD3<Float>) {
        let ax = simd_cross(m, n)
        var lo = [[Float]](repeating: [Float](repeating: .infinity, count: rimBins), count: 2)
        var hi = [[Float]](repeating: [Float](repeating: -.infinity, count: rimBins), count: 2)
        var rows: [Int] = []
        for i in 0..<count where crease[i] == tag || crease[i] == tag + 1 {
            rows.append(i)
            let d = pos[i] - pivot, h = simd_dot(d, n)
            guard abs(h) < rimContact else { continue }
            let side = crease[i] == tag + 1 ? 1 : 0, a = simd_dot(d, ax)
            let k = max(0, min(rimBins - 1, Int(simd_dot(d, m) / rimBin)))
            lo[side][k] = min(lo[side][k], a)
            hi[side][k] = max(hi[side][k], a)
        }
        let span = (0..<2).map { s in (0..<rimBins).map { k in hi[s][k] > lo[s][k] ? hi[s][k] - lo[s][k] : 0 } }
        let widest = span.map { $0.max() ?? 0 }
        var nb = 0
        while nb < rimBins, (0..<2).allSatisfy({ span[$0][nb] > 0 && span[$0][nb] >= rimWhole * widest[$0] }) { nb += 1 }
        guard nb >= 2 else { return }
        // least-squares line (slope, offset) through the bin centres
        func line(_ y: [Float]) -> (Float, Float) {
            var sx: Float = 0, sy: Float = 0, sxx: Float = 0, sxy: Float = 0
            for k in 0..<nb { let x = (Float(k) + 0.5) * rimBin; sx += x; sy += y[k]; sxx += x * x; sxy += x * y[k] }
            let c = Float(nb), slope = (c * sxy - sx * sy) / (c * sxx - sx * sx)
            return (slope, (sy - slope * sx) / c)
        }
        let l = [line(lo[0]), line(lo[1])], u = [line(hi[0]), line(hi[1])]
        let end = Float(nb) * rimBin
        for i in rows {
            let d = pos[i] - pivot, h = simd_dot(d, n), s = simd_dot(d, m), a = simd_dot(d, ax)
            let w = (1 - smooth(0, rimDepth, abs(h))) * smooth(0, rimRamp, s) * smooth(end, end - rimEnd, s)
            guard w > 0 else { continue }
            let side = crease[i] == tag + 1 ? 1 : 0
            let ownLo = l[side].0 * s + l[side].1, ownHi = u[side].0 * s + u[side].1
            let toLo = (l[0].0 + l[1].0) / 2 * s + (l[0].1 + l[1].1) / 2, toHi = (u[0].0 + u[1].0) / 2 * s + (u[0].1 + u[1].1) / 2
            let scale = (toHi - toLo) / max(ownHi - ownLo, 1e-3)
            pos[i] += w * (toLo + (a - ownLo) * scale - a) * ax
        }
    }

    /// The back bends partly at the hips (the pelvis turning on the femurs) and the rest along the spine above, a curve
    /// growing over the lumbar and lower chest: the belly folds softly instead of creasing over one hinge.
    /// Each point rides the bent spine line at its height, turned as the line turns there.
    struct BackBend {
        static let atHips: Float = 0.35
        static let hipBand: Float = 0.16
        /// the hip share fades out higher above the pivot, into the spine curve: no straight stretch (a shelf) between the two turns
        static let hipBandUp: Float = 0.30
        /// skin far behind the pivot (big buttocks) turns higher up, over the flatter lower back: the fullest point isn't stretched flat
        static let raiseFrom: Float = 0.1, raise: Float = 1
        static let samples = 32
        let pivot: SIMD3<Float>
        let hips, spine, y0, y1: Float
        /// the bent spine line (y, z) from y0 to y1
        private let line: [SIMD2<Float>]

        init(pivot: SIMD3<Float>, neckY: Float, theta: Float) {
            self.pivot = pivot
            hips = Self.atHips * theta
            spine = theta - hips
            let span = neckY - pivot.y
            y0 = pivot.y + 0.11 * span
            y1 = pivot.y + 0.55 * span
            let h = (y1 - y0) / Float(Self.samples)
            var c = SIMD2(y0, pivot.z), line = [c]
            for i in 0..<Self.samples {
                let a = (BodyScene.smooth(y0, y1, y0 + Float(i) * h) + BodyScene.smooth(y0, y1, y0 + Float(i + 1) * h)) / 2 * spine
                c += h * SIMD2(cos(a), sin(a))
                line.append(c)
            }
            self.line = line
        }

        private func centre(_ y: Float) -> SIMD2<Float> {
            if y <= y0 { return SIMD2(y, pivot.z) }
            if y >= y1 { return line[Self.samples] + (y - y1) * SIMD2(cos(spine), sin(spine)) }
            let u = (y - y0) / (y1 - y0) * Float(Self.samples)
            let i = min(Int(u), Self.samples - 1), f = u - Float(i)
            return line[i] * (1 - f) + line[i + 1] * f
        }

        /// a point well in front of the spine (a bump, a big belly) turns over a longer stretch: its front isn't squeezed into a fold
        static let spread: Float = 5
        private static func widen(_ turn: Float, _ d: Float, _ span: Float) -> Float { max(0, spread * abs(turn) * max(0, d) - span) / 2 }

        /// inverse of smooth on 0...1
        private static func unsmooth(_ t: Float) -> Float { 0.5 - sin(asin(1 - 2 * max(0, min(1, t))) / 3) }

        /// a point on the bent spine, turned with the line where it has turned as much; and that turn
        private func onSpine(_ q: SIMD3<Float>) -> (SIMD3<Float>, Float) {
            let d = q.z - pivot.z, w = Self.widen(spine, d, y1 - y0)
            let a = spine * BodyScene.smooth(y0 - w, y1 + w, q.y)
            let ye = abs(spine) > 1e-6 ? y0 + (y1 - y0) * Self.unsmooth(a / spine) : q.y
            let c = centre(ye), h = q.y - ye
            return (SIMD3(q.x, c.x + cos(a) * h - sin(a) * d, c.y + sin(a) * h + cos(a) * d), a)
        }

        private func hinge(_ p: SIMD3<Float>, _ a: Float) -> SIMD3<Float> {
            let y = p.y - pivot.y, z = p.z - pivot.z
            return SIMD3(p.x, pivot.y + cos(a) * y - sin(a) * z, pivot.z + sin(a) * y + cos(a) * z)
        }

        private static func turned(_ a: Float) -> simd_quatf { simd_quatf(angle: a, axis: SIMD3(1, 0, 0)) }

        /// a skin point: the hip share blends across a band round the pivot
        func move(_ q: SIMD3<Float>) -> (SIMD3<Float>, simd_quatf) {
            let w = Self.widen(hips, q.z - pivot.z, 2 * Self.hipBand)
            let up = Self.raise * max(0, pivot.z - q.z - Self.raiseFrom)
            let a = hips * BodyScene.smooth(pivot.y - Self.hipBand - w + up, pivot.y + Self.hipBandUp + w + up, q.y)
            let (p, t) = onSpine(q)
            return (hinge(p, a), Self.turned(a + t))
        }

        /// a rigid piece (a bone, an organ) at its centre's height, the pelvis turned fully on the femurs
        func rigid(at c: SIMD3<Float>) -> float4x4 {
            let (p, t) = onSpine(c), r = Self.turned(hips + t)
            var m = float4x4(r)
            m.columns.3 = SIMD4(hinge(p, hips) - r.act(c), 1)
            return m
        }

        /// everything above the curve: the joint's turn about the pivot, then this shift
        var shift: SIMD3<Float> {
            let top = SIMD3(pivot.x, pivot.y - y1, 0)
            let s = SIMD3(top.x, line[Self.samples].x + cos(spine) * top.y, line[Self.samples].y + sin(spine) * top.y)
            return hinge(s, hips) - pivot
        }

        var top: float4x4 {
            let r = Self.turned(hips + spine)
            var m = float4x4(r)
            m.columns.3 = SIMD4(pivot + shift - r.act(pivot), 1)
            return m
        }
    }

    private func backBend(degrees: Float? = nil) -> BackBend? {
        guard let outer = jointOuter["back"], let neck = jointOuter["neck"] else { return nil }
        return BackBend(pivot: outer.position, neckY: neck.position.y, theta: (degrees ?? jointAngles["back"] ?? 0) * .pi / 180)
    }

    /// rest matrix and centre of each piece the back holds directly, placed on the bent spine
    private var backRest: [ObjectIdentifier: (matrix: float4x4, centre: SIMD3<Float>)] = [:]

    /// The back's container carries the trunk above the curve; the pelvis, lumbar bones and organs below it sit on the
    /// curve at their height. Parts bent vertex by vertex (crossing) are left to bendCrossing.
    private func placeBack() {
        guard let outer = jointOuter["back"], let inner = jointInner["back"], let bend = backBend(), !crossing.isEmpty else { return }
        inner.position = -outer.position + outer.orientation.inverse.act(bend.shift)
        let top = bend.top.inverse
        let skip = Set(jointOuter.values.map(ObjectIdentifier.init)).union((crossing["back"] ?? []).compactMap { partEntities[$0] }.map(ObjectIdentifier.init))
        for e in inner.children where !skip.contains(ObjectIdentifier(e)) {
            let key = ObjectIdentifier(e)
            if backRest[key] == nil { backRest[key] = (e.transform.matrix, e.visualBounds(relativeTo: inner).center) }
            guard let (base, c) = backRest[key], c.y < bend.y1 else { continue }
            e.transform.matrix = top * bend.rigid(at: c) * base
        }
    }

    /// under another joint's container that itself sits under `container`
    private func inLimb(_ e: Entity, _ container: Entity?) -> Bool {
        let inners = Set(jointInner.values.map(ObjectIdentifier.init))
        var p = e.parent
        while let q = p, q !== container {
            if inners.contains(ObjectIdentifier(q)) { return under(q, container) }
            p = q.parent
        }
        return false
    }

    private func under(_ e: Entity, _ container: Entity?) -> Bool {
        var p = e.parent
        while let q = p { if q === container { return true }; p = q.parent }
        return false
    }

    /// The back (bending forward at the hips and along the spine: BackBend) and the neck (turning), as joint containers: everything the
    /// rig holds above the hips moves with the back, above the neck with the head. The whole-body skin and the
    /// underwear stay put and bend vertex by vertex.
    private func addFieldJoints() {
        guard fieldJoints, let fl = partEntities["femur-l"], let fr = partEntities["femur-r"], let c4 = partEntities["vertebra-C4"] else {
            joints = Catalog.body.joints
            return
        }
        let bl = fl.visualBounds(relativeTo: rig), br = fr.visualBounds(relativeTo: rig), bc = c4.visualBounds(relativeTo: rig)
        let hip = SIMD3<Float>(0, (bl.max.y + br.max.y) / 2, (bl.center.z + br.center.z) / 2)
        let neck = SIMD3<Float>(0, bc.center.y, bc.center.z)
        func container(_ id: String, pivot: SIMD3<Float>, under parent: Entity) -> Entity {
            let outer = Entity(), offset = Entity()
            outer.position = pivot
            offset.position = -pivot
            outer.addChild(offset)
            parent.addChild(outer)
            jointOuter[id] = outer
            jointInner[id] = offset
            return offset
        }
        let back = container("back", pivot: hip, under: rig)
        let head = container("neck", pivot: neck, under: back)
        var backParts: [String] = [], neckParts: [String] = []
        func place(_ e: Entity, id: String) {
            guard e.parent === rig else { return }
            let box = e.visualBounds(relativeTo: rig)
            guard !box.isEmpty else { return }
            if box.center.y > neck.y { head.addChild(e); neckParts.append(id); backParts.append(id) }
            else if box.center.y > hip.y { back.addChild(e); backParts.append(id) }
        }
        for (id, e) in partEntities { place(e, id: id) }
        for (id, e) in organEntities { place(e, id: id) }
        for (e, _) in skinEntities where e.name != "skin:body" && !e.name.hasPrefix("skin:underwear") { place(e, id: e.name) }
        for s in ["shoulder-l", "shoulder-r"] { if let o = jointOuter[s], o.parent === rig { back.addChild(o) } }
        func hung(_ j: Joint, from parent: String) -> Joint {
            Joint(id: j.id, name: j.name, nameZh: j.nameZh, pivot: j.pivot, axis: j.axis, maxDeg: j.maxDeg, parent: parent, parts: j.parts, movers: j.movers)
        }
        joints = [Joint(id: "neck", name: "Neck — turn", nameZh: "颈部 转动", pivot: Vec3(neck.x, neck.y, neck.z), axis: Vec3(0, 1, 0), maxDeg: 70,
                        parent: "back", parts: neckParts, movers: [])]
            + Catalog.body.joints.map { $0.id.hasPrefix("shoulder") ? hung($0, from: "back") : $0 }
            + [Joint(id: "back", name: "Back — bend forward", nameZh: "腰部 前屈", pivot: Vec3(hip.x, hip.y, hip.z), axis: Vec3(1, 0, 0), maxDeg: 90,
                     parent: nil, parts: backParts, movers: [])]
    }

    /// The body's skin and underwear made movable, each vertex bound to the joint container of its nearest bone.
    private func bindSkin() {
        var index: [ObjectIdentifier: Int] = [:]
        func holder(_ e: Entity) -> Int {
            if let i = index[ObjectIdentifier(e)] { return i }
            holders.append(e)
            index[ObjectIdentifier(e)] = holders.count - 1
            return holders.count - 1
        }
        // points over every bone at rest, in their container's space (the rig's rest coordinates), in a grid
        let cell: Float = 0.08
        var bonePoints: [(SIMD3<Float>, Int, Float)] = []
        // how far a bone's skin reaches: a hand hangs beside the thigh, whose skin must stay with the deep femur
        func reach(_ id: String) -> Float {
            if ["phalanges", "metacarpal", "carpals", "thumb", "metatarsal", "toe", "talus", "tarsal", "calcaneus"].contains(where: id.hasPrefix) { return 0.06 }
            if ["radius", "ulna", "tibia", "fibula", "patella"].contains(where: id.hasPrefix) { return 0.1 }
            if ["humerus", "femur"].contains(where: id.hasPrefix) { return 0.12 }
            return 0.3
        }
        let restMatrix = Dictionary(rest.map { (ObjectIdentifier($0.entity), $0.matrix) }) { a, _ in a }
        for (id, e) in partEntities.sorted(by: { $0.key < $1.key }) where partLayer[id] == .skeletal {
            guard let part = e.model?.mesh.contents.models.first?.parts.first else { continue }
            let p = part.positions.elements, m = restMatrix[ObjectIdentifier(e)] ?? e.transform.matrix, h = holder(e.parent ?? rig), far = reach(id)
            let step = max(1, p.count / 400)
            for i in stride(from: 0, to: p.count, by: step) {
                let q = m * SIMD4(p[i], 1)
                bonePoints.append((SIMD3(q.x, q.y, q.z), h, far))
            }
        }
        let grid = CellGrid(bonePoints.map(\.0), cell: cell)
        // the nearest bone within its reach and under the skin (a hand resting on the thigh is outside the thigh's
        // surface, so it can't claim that skin); failing that the nearest large bone; failing that whatever is nearest
        func nearest(_ q: SIMD3<Float>, _ n: SIMD3<Float>, cells: Int, _ ok: (Float, Float, Float) -> Bool) -> Int? {
            let c = grid.key(q)
            var best = Float.infinity, pick: Int?
            for r in 1...cells {
                // the cells inside were searched by the smaller rings
                for dx in -r...r { for dy in -r...r { for dz in stride(from: -r, through: r, by: r == 1 || abs(dx) == r || abs(dy) == r ? 1 : 2 * r) {
                    for e in grid.cell(c &+ SIMD3<Int32>(Int32(dx), Int32(dy), Int32(dz))) {
                        let (p, h, far) = bonePoints[Int(grid.items[e])]
                        let d = simd_length_squared(p - q)
                        if d < best && ok(d, far, simd_dot(p - q, n)) { best = d; pick = h }
                    }
                } } }
                // the nearest point found inside r - 1 cells can't be beaten by one further out
                if pick != nil && best < Float(r - 1) * cell * Float(r - 1) * cell { return pick }
            }
            return pick
        }
        func nearest(_ q: SIMD3<Float>, _ n: SIMD3<Float>) -> Int {
            nearest(q, n, cells: 4) { d, far, inside in d < far * far && inside < 0.01 }
                ?? nearest(q, n, cells: 8) { _, far, inside in far >= 0.12 && inside < 0.01 }
                ?? nearest(q, n, cells: 12) { _, _, _ in true } ?? 0
        }
        // garments follow the body skin under them, the body (bound first) its nearest bone
        var skinGrid = CellGrid([], cell: 0.03)
        var skinPoints: [SIMD3<Float>] = [], skinHolder: [Int] = [], skinTris: [UInt32] = [], skinVertTris: [[Int]] = []
        let skinCell: Float = 0.03
        func skinKey(_ p: SIMD3<Float>) -> SIMD3<Int32> { skinGrid.key(p) }
        func underSkin(_ q: SIMD3<Float>) -> Int {
            let c = skinKey(q)
            for r in 1...6 {
                var best = Float.infinity, pick = -1
                for dx in -r...r { for dy in -r...r { for dz in -r...r {
                    for e in skinGrid.cell(c &+ SIMD3<Int32>(Int32(dx), Int32(dy), Int32(dz))) {
                        let i = Int(skinGrid.items[e]), d = simd_length_squared(skinPoints[i] - q)
                        if d < best { best = d; pick = i }
                    }
                } } }
                if pick >= 0 { return pick }
            }
            return 0
        }
        // a garment point's shoulder share: the skin's round it on its holder, nearer counting more (one vertex's would step)
        var skinShare: [Float] = [], skinSide: [Float] = [], skinTop: [Float] = []
        // a garment point's closest point on the body skin (the triangles round its 8 nearest vertices), as barycentric
        // weights: a blend of the near vertices instead would sit flat at each and step between them
        func skinFollow(_ q: SIMD3<Float>, near: Int) -> [(Int, Float)] {
            let c = skinKey(q)
            var found: [(Float, Int)] = []
            for dx in -1...1 { for dy in -1...1 { for dz in -1...1 {
                for e in skinGrid.cell(c &+ SIMD3<Int32>(Int32(dx), Int32(dy), Int32(dz))) {
                    let i = Int(skinGrid.items[e]), d = simd_distance_squared(skinPoints[i], q)
                    // the 8 nearest, ties in the order found (as a stable sort's first 8)
                    guard found.count < 8 || d < found[7].0 else { continue }
                    let at = found.firstIndex { d < $0.0 } ?? found.count
                    found.insert((d, i), at: at)
                    if found.count > 8 { found.removeLast() }
                }
            } } }
            var best = Float.infinity, pick: [(Int, Float)] = [(near, 1)]
            for k in Set(found.flatMap { skinVertTris[$0.1] }).sorted() {
                let v = (Int(skinTris[3 * k]), Int(skinTris[3 * k + 1]), Int(skinTris[3 * k + 2]))
                let w = Self.closestOnTriangle(q, skinPoints[v.0], skinPoints[v.1], skinPoints[v.2])
                let d = simd_distance_squared(w.x * skinPoints[v.0] + w.y * skinPoints[v.1] + w.z * skinPoints[v.2], q)
                if d < best { best = d; pick = [(v.0, w.x), (v.1, w.y), (v.2, w.z)] }
            }
            return pick
        }
        func garmentShare(_ q: SIMD3<Float>, _ h: Int, near: Int) -> (Float, Float) {
            let reach: Float = 0.04, c = skinKey(q)
            var sum: Float = 0, total: Float = 0
            for dx in -2...2 { for dy in -2...2 { for dz in -2...2 {
                for e in skinGrid.cell(c &+ SIMD3<Int32>(Int32(dx), Int32(dy), Int32(dz))) {
                    let i = Int(skinGrid.items[e])
                    guard skinHolder[i] == h else { continue }
                    let d = simd_distance(skinPoints[i], q)
                    guard d < reach else { continue }
                    let k = (1 - d / reach) * (1 - d / reach)
                    sum += k * skinShare[i]; total += k
                }
            } } }
            if total > 0 { return (sum / total, skinSide[near]) }
            // no skin of its holder close by (briefs beside the hanging hand): the nearest skin that is, not the hand's
            var best = Float.infinity, pick = -1
            for r in 3...8 {
                for dx in -r...r { for dy in -r...r { for dz in -r...r where max(abs(dx), abs(dy), abs(dz)) == r {
                    for e in skinGrid.cell(c &+ SIMD3<Int32>(Int32(dx), Int32(dy), Int32(dz))) {
                        let i = Int(skinGrid.items[e])
                        guard skinHolder[i] == h else { continue }
                        let d = simd_distance_squared(skinPoints[i], q)
                        if d < best { best = d; pick = i }
                    }
                } } }
                if pick >= 0 { break }
            }
            return (pick >= 0 ? skinShare[pick] : skinShare[near], skinSide[near])
        }
        // the shoulders' containers: each one's own and below it (the arm), and the one it hangs from (the torso)
        let shoulders = joints.filter { $0.id.hasPrefix("shoulder") }.compactMap { j -> ShoulderBind? in
            guard let outer = jointOuter[j.id], let inner = jointInner[j.id] else { return nil }
            let lower = joints.filter { $0.parent == j.id }.compactMap { jointInner[$0.id] }.map(holder)
            let elbow = joints.first { $0.parent == j.id }?.pivot.simd ?? j.pivot.simd
            return ShoulderBind(pivot: j.pivot.simd, elbow: elbow, own: holder(inner), arm: Set([holder(inner)] + lower), torso: holder(outer.parent ?? rig))
        }
        for (entity, _) in skinEntities.sorted(by: { $0.entity.name == "skin:body" && $1.entity.name != "skin:body" })
        where entity.name == "skin:body" || entity.name.hasPrefix("skin:underwear") {
            guard let b = SkinDeformer(entity) else { continue }
            let m = entity.transform.matrix
            let rest = b.rest.map { (p: SIMD3<Float>) -> SIMD3<Float> in let q = m * SIMD4(p, 1); return SIMD3(q.x, q.y, q.z) }
            let normals = b.normals.map { (p: SIMD3<Float>) -> SIMD3<Float> in let n = m * SIMD4(p, 0); return simd_normalize(SIMD3(n.x, n.y, n.z)) }
            var bindRest = rest, bindNormals = normals
            if entity.name == "skin:body", let look = unshaped, let plain = ModelLibrary.skin(look)?.first(where: { $0.id == "body" }),
               let part = plain.mesh.contents.models.first?.parts.first, part.positions.count == rest.count {
                let pm = plain.transform.matrix, source = Figure.source(plain.mesh)
                bindRest = (source?.positions ?? part.positions.elements).map { (p: SIMD3<Float>) -> SIMD3<Float> in let q = pm * SIMD4(p, 1); return SIMD3(q.x, q.y, q.z) }
                if let pn = source?.normals ?? part.normals?.elements {
                    bindNormals = pn.map { (p: SIMD3<Float>) -> SIMD3<Float> in let n = pm * SIMD4(p, 0); return simd_normalize(SIMD3(n.x, n.y, n.z)) }
                }
            }
            let body = entity.name == "skin:body" || skinPoints.isEmpty
            let under = body ? [] : rest.map { underSkin($0) }
            var hold = body ? zip(bindRest, bindNormals).map { nearest($0, $1) } : under.map { skinHolder[$0] }
            var adjacent = [[Int]](repeating: [], count: rest.count)
            let t = b.triangles
            for k in stride(from: 0, to: t.count - 2, by: 3) {
                let a = Int(t[k]), bb = Int(t[k + 1]), c = Int(t[k + 2])
                adjacent[a].append(bb); adjacent[a].append(c); adjacent[bb].append(a); adjacent[bb].append(c); adjacent[c].append(a); adjacent[c].append(bb)
            }
            hold = Self.tidy(hold, adjacent)
            var share = [Float](repeating: 0, count: rest.count), side = rest.map { $0.x < 0 ? Float(-1) : 1 }
            var canon: [Int] = [], band: [Int] = [], bandNear: [[Int]] = [], bandTris: [Int] = [], follow: [[(Int, Float)]] = []
            var followOffset: [SIMD3<Float>] = [], followBehind: [Float] = [], top: [Float] = []
            var bandConvex: [Float] = [], bandGrad: [SIMD3<Float>] = [], bandOf: [Int] = []
            if body {
                (share, side, canon) = Self.shoulderShares(bindRest, normals: bindNormals, adjacent: adjacent, hold: hold, shoulders: shoulders)
                (band, bandNear, bandTris) = Self.relaxBand(share, canon: canon, adjacent: adjacent, triangles: t)
                let pivotZ = shoulders.first?.pivot.z ?? 0
                bandConvex = zip(band, bandNear).map { i, near in
                    let h = near.reduce(0) { $0 + simd_distance(bindRest[$1], bindRest[i]) } / Float(max(near.count, 1))
                    let leak = min(1, Self.relaxConvex * (Self.relaxScale / max(h, 1e-6)) * (Self.relaxScale / max(h, 1e-6)))
                    return leak + (1 - leak) * Self.smooth(0, Self.relaxBehind, pivotZ - bindRest[i].z)
                }
                bandGrad = zip(band, bandNear).map { Self.shareGradient($0, $1, rest: rest, normals: normals, share: share) }
                var slot = [Int](repeating: -1, count: rest.count)
                for (b, i) in band.enumerated() { slot[i] = b }
                bandOf = canon.map { slot[$0] }
                if let pivot = shoulders.first?.pivot { top = bindRest.map { Self.shoulderTop($0, pivot: pivot) } }
            } else if !skinShare.isEmpty {
                for i in rest.indices { (share[i], side[i]) = garmentShare(rest[i], hold[i], near: under[i]) }
                follow = rest.indices.map { skinFollow(rest[$0], near: under[$0]) }
                let pivotZ = shoulders.first?.pivot.z ?? 0
                for (q, f) in zip(rest, follow) {
                    let on = f.reduce(SIMD3<Float>.zero) { $0 + $1.1 * skinPoints[$1.0] }
                    followOffset.append(q - on)
                    followBehind.append(Self.smooth(-Self.relaxBehind, Self.relaxBehind, pivotZ - on.z))
                }
                if !skinTop.isEmpty { top = follow.map { $0.reduce(0) { $0 + $1.1 * skinTop[$1.0] } } }
            }
            if entity.name == "skin:body" {
                skinPoints = rest; skinHolder = hold; skinShare = share; skinSide = side; skinTop = top; skinTris = t
                skinVertTris = [[Int]](repeating: [], count: rest.count)
                for k in 0..<t.count / 3 { for j in 0..<3 { skinVertTris[Int(t[3 * k + j])].append(k) } }
                skinGrid = CellGrid(rest, cell: skinCell)
            }
            var bend = SkinBend(bender: b, toLocal: m.inverse, rest: rest, normals: normals, holder: hold, shoulder: share, side: side,
                                top: top, canon: canon, band: band, bandNear: bandNear, bandConvex: bandConvex, bandTris: bandTris,
                                bandGrad: bandGrad, bandOf: bandOf, follow: follow, followOffset: followOffset, followBehind: followBehind)
            bend.pack()
            skinBends.append(bend)
        }
        let followed = Set(skinBends.flatMap { $0.followIdx.map(Int.init) })
        for s in skinBends where !s.band.isEmpty { s.carry(followed) }
    }

    /// Points in a dense grid of cubes `cell` wide (lookups were most of bindSkin as a dictionary): per cube, its points'
    /// indices in the order given.
    private struct CellGrid {
        let cell: Float
        let items: [Int32]
        private let lo, size: SIMD3<Int32>
        private let start: [Int32]

        init(_ p: [SIMD3<Float>], cell: Float) {
            self.cell = cell
            let keys = p.map { SIMD3<Int32>(Int32(floor($0.x / cell)), Int32(floor($0.y / cell)), Int32(floor($0.z / cell))) }
            var lo = keys.first ?? .zero, hi = lo
            for k in keys { lo = simd_min(lo, k); hi = simd_max(hi, k) }
            let size = keys.isEmpty ? .zero : hi &- lo &+ 1
            self.lo = lo; self.size = size
            var start = [Int32](repeating: 0, count: Int(size.x) * Int(size.y) * Int(size.z) + 1)
            func at(_ k: SIMD3<Int32>) -> Int { Int(k.x - lo.x) + Int(size.x) * (Int(k.y - lo.y) + Int(size.y) * Int(k.z - lo.z)) }
            for k in keys { start[at(k) + 1] += 1 }
            for c in 1..<start.count { start[c] += start[c - 1] }
            var fill = start, items = [Int32](repeating: 0, count: p.count)
            for (i, k) in keys.enumerated() { let c = at(k); items[Int(fill[c])] = Int32(i); fill[c] += 1 }
            self.start = start; self.items = items
        }

        func key(_ p: SIMD3<Float>) -> SIMD3<Int32> { SIMD3<Int32>(Int32(floor(p.x / cell)), Int32(floor(p.y / cell)), Int32(floor(p.z / cell))) }

        /// the cube's slots in `items` (none outside the grid)
        func cell(_ k: SIMD3<Int32>) -> Range<Int> {
            let d = k &- lo
            guard d.x >= 0, d.y >= 0, d.z >= 0, d.x < size.x, d.y < size.y, d.z < size.z else { return 0..<0 }
            let c = Int(d.x) + Int(size.x) * (Int(d.y) + Int(size.y) * Int(d.z))
            return Int(start[c])..<Int(start[c + 1])
        }
    }

    /// strays (a few vertices bound across a gap, where a hand rests on the thigh) take their neighbours' side
    private static func tidy(_ labels: [Int], _ adjacent: [[Int]]) -> [Int] {
        var hold = labels
        // the most common neighbour label (ties: the smallest), counted in place of a dictionary per vertex
        var key: [Int] = [], count: [Int] = []
        for _ in 0..<8 {
            var next = hold
            for i in hold.indices where !adjacent[i].isEmpty {
                key.removeAll(keepingCapacity: true); count.removeAll(keepingCapacity: true)
                for j in adjacent[i] {
                    if let k = key.firstIndex(of: hold[j]) { count[k] += 1 } else { key.append(hold[j]); count.append(1) }
                }
                var top = 0
                for k in 1..<key.count where count[k] > count[top] || (count[k] == count[top] && key[k] < key[top]) { top = k }
                if key[top] != hold[i], count[top] * 3 >= adjacent[i].count * 2 { next[i] = key[top] }
            }
            hold = next
        }
        // a small island of one holder inside another's skin (a few hand vertices bound to a far bone) joins its surround
        var label = [Int](repeating: -1, count: hold.count), sizes: [Int] = []
        for start in hold.indices where label[start] < 0 {
            var stack = [start], n = 0
            label[start] = sizes.count
            while let v = stack.popLast() {
                n += 1
                for w in adjacent[v] where label[w] < 0 && hold[w] == hold[v] { label[w] = sizes.count; stack.append(w) }
            }
            sizes.append(n)
        }
        var votes = [[Int: Int]](repeating: [:], count: sizes.count)
        for i in hold.indices where sizes[label[i]] < 150 {
            for j in adjacent[i] where label[j] != label[i] { votes[label[i]][hold[j], default: 0] += 1 }
        }
        for i in hold.indices where sizes[label[i]] < 150 {
            if let top = votes[label[i]].max(by: { ($0.value, $1.key) < ($1.value, $0.key) })?.key { hold[i] = top }
        }
        return hold
    }

    private struct ShoulderBind { let pivot: SIMD3<Float>; let elbow: SIMD3<Float>; let own: Int; let arm: Set<Int>; let torso: Int }

    /// Each skin vertex's share of its side's shoulder turn. The arm is its bones' skin and, near the joint, all skin
    /// lateral of it (the deltoid lies over the shoulder blade, nearer it than the humerus); the share ramps from the
    /// torso to the arm across a band round that split, by distance over the skin (the arm's inner side touches the
    /// chest), so the armpit opens over a hand's width instead of a sheet a few triangles wide. Then smoothed over the skin
    /// (the arm's rigid part held, but not near the split), the arm side eased into 1: the split's corner behind the armpit
    /// would fold into a sharp flap.
    /// Below the armpit, skin bound to the ribs but round the humerus and facing away from it is the inner arm.
    /// Torso skin above the pivot and far off it keeps little share (farFrom).
    private static func shoulderShares(_ p: [SIMD3<Float>], normals: [SIMD3<Float>], adjacent: [[Int]], hold: [Int],
                                       shoulders: [ShoulderBind]) -> ([Float], [Float], [Int]) {
        let band = shoulderBand
        let side = p.map { $0.x < 0 ? Float(-1) : 1 }
        var share = [Float](repeating: 0, count: p.count)
        // welded: the texture seam down the back of the armpit splits vertices
        var first: [SIMD3<Float>: Int] = [:], canon = [Int](repeating: 0, count: p.count)
        for i in p.indices {
            if let j = first[p[i]] { canon[i] = j } else { first[p[i]] = i; canon[i] = i }
        }
        var welded = [[Int]](repeating: [], count: p.count)
        for i in p.indices { welded[canon[i]] += adjacent[i].map { canon[$0] } }
        let adjacent = welded, hold = hold.indices.map { hold[canon[$0]] }
        for s in shoulders {
            let sd: Float = s.pivot.x < 0 ? -1 : 1
            let u = s.elbow - s.pivot
            let arm = tidy(p.indices.map { i in
                guard side[i] == sd else { return 0 }
                let d = p[i] - s.pivot
                let near = simd_length(d) < 0.22 && d.y > -0.12 && (hold[i] == s.torso || hold[i] == s.own)
                let r = d - max(0, min(1, simd_dot(d, u) / simd_dot(u, u))) * u
                let inner = hold[i] == s.torso && d.y < -innerBelow && simd_length(r) < innerArm && simd_dot(r, normals[canon[i]]) > 0
                return (near ? sd * d.x > -0.03 : s.arm.contains(hold[i]) || inner) ? 1 : 0
            }, adjacent)
            // distance over the skin from the split (edge midpoints), as far as the band's reach
            let reach = band * shoulderReach
            var dist = [Float](repeating: .infinity, count: p.count)
            var heap = MinHeap()
            for i in p.indices {
                for j in adjacent[i] where arm[j] != arm[i] { dist[i] = min(dist[i], simd_distance(p[i], p[j]) / 2) }
                if dist[i] < reach { heap.push(dist[i], i) }
            }
            while let (d, i) = heap.pop() {
                guard d <= dist[i] else { continue }
                for j in adjacent[i] {
                    let e = d + simd_distance(p[i], p[j])
                    if e < dist[j] && e < reach { dist[j] = e; heap.push(e, j) }
                }
            }
            for i in p.indices where canon[i] == i && side[i] == sd && (hold[i] == s.torso || s.arm.contains(hold[i])) {
                share[i] = max(0, min(1, ((arm[i] == 1 ? dist[i] : -dist[i]) + band) / (2 * band)))
            }
            let free = p.indices.filter { canon[$0] == $0 && side[$0] == sd && (hold[$0] == s.torso || s.arm.contains(hold[$0])) && (share[$0] < 1 || dist[$0] < reach) }
            let near = free.map { i in Set(adjacent[i].filter { $0 != i && side[$0] == sd }).sorted() }
            for _ in 0..<shoulderSmoothing {
                let next = zip(free, near).map { i, n in n.isEmpty ? share[i] : n.reduce(0) { $0 + share[$1] } / Float(n.count) }
                for (k, i) in free.enumerated() { share[i] = next[k] }
            }
            // arm side eased into 1 (slope 1 at the split, 0 at 1)
            for i in free where share[i] > 0.5 {
                let x = min(1, share[i] * 2 - 1)
                share[i] = 0.5 + 0.5 * (x + x * x - x * x * x)
            }
            for i in free where arm[i] == 0 {
                let d = p[i] - s.pivot
                share[i] *= 1 - smooth(farFrom, farTo, simd_length(d)) * smooth(-0.02, farUp, d.y)
            }
        }
        return (p.indices.map { share[canon[$0]] }, side, canon)
    }

    /// the skin relaxShoulders moves: welded vertices inside a shoulder band, their welded neighbours, the triangles touching them
    private static func relaxBand(_ share: [Float], canon: [Int], adjacent: [[Int]], triangles t: [UInt32]) -> ([Int], [[Int]], [Int]) {
        var near = [Set<Int>](repeating: [], count: share.count)
        for i in share.indices { for j in adjacent[i] where canon[j] != canon[i] { near[canon[i]].insert(canon[j]) } }
        let band = share.indices.filter { canon[$0] == $0 && share[$0] >= 1e-3 && share[$0] <= 1 - 1e-3 && !near[$0].isEmpty }
        var inBand = [Bool](repeating: false, count: share.count)
        for i in band { inBand[i] = true }
        let tris = stride(from: 0, to: t.count - 2, by: 3).filter { k in (0..<3).contains { inBand[canon[Int(t[k + $0])]] } }
        return (band, band.map { Array(near[$0]) }, tris)
    }

    /// barycentric weights of the point on triangle abc closest to q (Ericson, Real-Time Collision Detection 5.1.5)
    private static func closestOnTriangle(_ q: SIMD3<Float>, _ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) -> SIMD3<Float> {
        let ab = b - a, ac = c - a, ap = q - a
        let d1 = simd_dot(ab, ap), d2 = simd_dot(ac, ap)
        if d1 <= 0 && d2 <= 0 { return [1, 0, 0] }
        let bp = q - b, d3 = simd_dot(ab, bp), d4 = simd_dot(ac, bp)
        if d3 >= 0 && d4 <= d3 { return [0, 1, 0] }
        let vc = d1 * d4 - d3 * d2
        if vc <= 0 && d1 >= 0 && d3 <= 0 { let v = d1 / (d1 - d3); return [1 - v, v, 0] }
        let cp = q - c, d5 = simd_dot(ab, cp), d6 = simd_dot(ac, cp)
        if d6 >= 0 && d5 <= d6 { return [0, 0, 1] }
        let vb = d5 * d2 - d1 * d6
        if vb <= 0 && d2 >= 0 && d6 <= 0 { let w = d2 / (d2 - d6); return [1 - w, 0, w] }
        let va = d3 * d6 - d5 * d4
        if va <= 0 && d4 - d3 >= 0 && d5 - d6 >= 0 { let w = (d4 - d3) / ((d4 - d3) + (d5 - d6)); return [0, 1 - w, w] }
        let den = 1 / max(va + vb + vc, 1e-20), v = vb * den, w = vc * den
        return [1 - v - w, v, w]
    }

    /// a band vertex's share gradient: least squares over its welded neighbours, in its tangent plane
    private static func shareGradient(_ i: Int, _ near: [Int], rest: [SIMD3<Float>], normals: [SIMD3<Float>], share: [Float]) -> SIMD3<Float> {
        var m = simd_float3x3(0), r = SIMD3<Float>.zero
        for j in near {
            let e = rest[j] - rest[i]
            m += simd_float3x3(e * e.x, e * e.y, e * e.z)
            r += e * (share[j] - share[i])
        }
        let n = normals[i], tr = m[0][0] + m[1][1] + m[2][2]
        m += simd_float3x3(n * n.x, n * n.y, n * n.z) * tr
        guard abs(m.determinant) > 1e-20 else { return .zero }
        let g = m.inverse * r
        return g - simd_dot(g, n) * n
    }

    /// The chord's normal: through the inverse transpose of its Jacobian J = (1-w)I + wR + (Rd - d)gᵀ (d off the pivot, g the
    /// share's gradient). Turning by the chord direction alone leaves out the gradient term: behind the armpit that shades a
    /// knob the surface doesn't have.
    /// (c, s: 1 - w + w cos θ and w sin θ; q: the turn by atan2(s, c); turn: the full turn by θ)
    private static func chordNormal(_ n: SIMD3<Float>, grad g: SIMD3<Float>, d: SIMD3<Float>, w: Float, c: Float, s: Float,
                                    q: simd_quatf, turn: simd_quatf, axis: SIMD3<Float>) -> SIMD3<Float> {
        let rho = max(1e-6, (c * c + s * s).squareRoot())
        func ainvt(_ v: SIMD3<Float>) -> SIMD3<Float> {
            let va = simd_dot(v, axis) * axis
            return va + q.act(v - va) / rho
        }
        let u = turn.act(d) - d
        let an = ainvt(n), ag = ainvt(g * smooth(0, gradFade, 1 - w))
        let r = an - ag * (simd_dot(u, an) / (1 + simd_dot(ag, u)))
        let l = simd_length(r)
        return l > 1e-12 ? r / l : q.act(n)
    }

    /// At a high arm the chord pulls the band skin toward the pivot: a pinched ring and a shelf where the arm meets the
    /// torso. Band skin moves toward its neighbours' mean plus its offset from theirs before the turn (that detail fading
    /// out mid band); a move sinking convex skin is cut to relaxConvex (less behind the joint, not on a ridge at a high arm), so hollows fill and the arm stays round. Band
    /// normals (the chord's, chordNormal) then blend to the surface's and are averaged with their neighbours. Returns whether
    /// it moved; each vertex's move is left in scratch.move, for the garments to carry if `carry` (garmentMove).
    /// Each smoothing stops early once nothing moves more than `settled` a pass.
    private static func relaxShoulders(_ s: SkinBend, turns: [(side: Float, theta: Float, axis: SIMD3<Float>)],
                                       pos: UnsafeMutablePointer<SIMD3<Float>>, nrm: UnsafeMutablePointer<SIMD3<Float>>,
                                       pre: UnsafePointer<SIMD3<Float>>, jac: UnsafePointer<SIMD3<Float>>, carry: Bool) -> Bool {
        let n = s.band.count, x = s.scratch
        // the same input as last time (a knee or elbow moved, the band didn't): the same output, already in x.move
        var input: [SIMD3<Float>] = []
        input.reserveCapacity(4 * s.relaxInputs.count + 2 * turns.count + 1)
        for v in s.relaxInputs { let i = Int(v); input.append(pos[i]); input.append(nrm[i]); input.append(pre[i]); input.append(jac[i]) }
        for t in turns { input.append(SIMD3(t.side, t.theta, 0)); input.append(t.axis) }
        input.append(SIMD3(carry ? 1 : 0, 0, 0))
        let same = input.count == x.relaxIn.count && input.withUnsafeBytes { a in x.relaxIn.withUnsafeBytes { b in memcmp(a.baseAddress!, b.baseAddress!, a.count) == 0 } }
        if same {
            for (k, v) in s.bandVerts.enumerated() { pos[Int(v)] = x.relaxOut[2 * k]; nrm[Int(v)] = x.relaxOut[2 * k + 1] }
            return x.relaxed
        }
        let relaxed = relax(s, turns: turns, pos: pos, nrm: nrm, pre: pre, jac: jac, carry: carry)
        x.relaxIn = input
        x.relaxOut = s.bandVerts.flatMap { [pos[Int($0)], nrm[Int($0)]] }
        x.relaxed = relaxed
        return relaxed
    }

    private static func relax(_ s: SkinBend, turns: [(side: Float, theta: Float, axis: SIMD3<Float>)],
                              pos: UnsafeMutablePointer<SIMD3<Float>>, nrm: UnsafeMutablePointer<SIMD3<Float>>,
                              pre: UnsafePointer<SIMD3<Float>>, jac: UnsafePointer<SIMD3<Float>>, carry: Bool) -> Bool {
        let n = s.band.count, x = s.scratch
        let k = x.k, kn = x.kn, wn = x.wn, delta = x.delta, ref = x.ref, p = x.p, active = x.active
        let inward = x.inward, ridge = x.ridge
        let band = s.band, shoulder = s.shoulder, side = s.side, convex = s.bandConvex, canon = s.canon, bandOf = s.bandOf
        let start = x.start, slot = x.slot, size = x.size, verts = s.bandVerts, ghosts = s.ghosts
        let still = settled * settled
        var relaxing = false, smoothing = false, nActive = 0
        for b in 0..<n {
            let i = band[b]
            k[b] = 0; kn[b] = 0; wn[b] = 0; delta[b] = .zero; ref[b] = .zero; p[b] = pos[i]; ridge[b] = 0
            guard let t = turns.first(where: { $0.side == side[i] }) else { continue }
            let amt = smooth(relaxFrom, relaxFull, abs(t.theta)), w = shoulder[i], c = min(1, 4 * w * (1 - w))
            let lo = Int(start[b]), hi = Int(start[b + 1])
            var mean = SIMD3<Float>.zero
            for e in lo..<hi { let j = Int(slot[e]); mean += pre[j < n ? band[j] : Int(ghosts[j - n])] }
            mean /= size[b]
            k[b] = c * relaxRate * amt
            ridge[b] = smooth(ridgeFrom, relaxFull, abs(t.theta))
            kn[b] = min(1, 8 * w * (1 - w)) * amt
            wn[b] = min(1, 8 * w * (1 - w)) * smooth(normalFrom, normalFull, abs(t.theta)) * (1 - amt)
            delta[b] = simd_quatf(angle: atan2(w * sin(t.theta), 1 - w + w * cos(t.theta)), axis: t.axis).act(pre[i] - mean) * (1 - c)
            ref[b] = nrm[i]
            if k[b] > 1e-3 { relaxing = true; active[nActive] = Int32(b); nActive += 1 }
            if wn[b] > 1e-3 { smoothing = true }
        }
        if relaxing {
            let step = x.step
            for (e, j) in ghosts.enumerated() { p[n + e] = pos[Int(j)] }
            inward.update(repeating: 0, count: n + ghosts.count)
            for _ in 0..<relaxPasses {
                var most: Float = 0
                for a in 0..<nActive {
                    let b = Int(active[a]), lo = Int(start[b]), hi = Int(start[b + 1])
                    var sum = SIMD3<Float>.zero
                    for e in lo..<hi { sum += p[Int(slot[e])] }
                    step[b] = sum / size[b] + delta[b] - p[b]
                    inward[b] = min(0, simd_dot(step[b], ref[b]))
                }
                for a in 0..<nActive {
                    let b = Int(active[a]), lo = Int(start[b]), hi = Int(start[b + 1])
                    var u = step[b]
                    let un = simd_dot(u, ref[b])
                    if un <= 0 {
                        // share of the sinking the neighbours have too: all of it a convex patch (cut), none a ridge (free)
                        var r: Float = 1
                        if un < -1e-12 {
                            var sum: Float = 0
                            for e in lo..<hi { sum += inward[Int(slot[e])] }
                            r = 1 - (1 - min(1, max(0, sum / size[b] / un))) * ridge[b]
                        }
                        u *= 1 - (1 - convex[b]) * r
                    }
                    step[b] = k[b] * u
                    most = max(most, simd_length_squared(step[b]))
                }
                for a in 0..<nActive { let b = Int(active[a]); p[b] += step[b] }
                if most < still { break }
            }
            let move = x.move
            move.update(repeating: .zero, count: s.rest.count)
            for v in verts { let i = Int(v); move[i] = p[bandOf[i]] - pos[canon[i]] }
            for v in verts { let i = Int(v); pos[i] += move[i] }
        }
        for v in verts { let i = Int(v); if jac[i] != .zero { nrm[i] = jac[i] } }
        if relaxing {
            // band normals of the relaxed surface, per band slot
            let g = x.g, tri = s.bender.triangles
            g.update(repeating: .zero, count: n)
            for k0 in s.bandTris {
                let a = Int(tri[k0]), b = Int(tri[k0 + 1]), c = Int(tri[k0 + 2])
                let f = simd_cross(pos[b] - pos[a], pos[c] - pos[a])
                let sa = bandOf[a], sb = bandOf[b], sc = bandOf[c]
                if sa >= 0 { g[sa] += f }
                if sb >= 0 { g[sb] += f }
                if sc >= 0 { g[sc] += f }
            }
            for v in verts {
                let i = Int(v), b = bandOf[i], w = kn[b]
                guard w > 1e-3, simd_length(g[b]) > 1e-12 else { continue }
                nrm[i] = simd_normalize(nrm[i] * (1 - w) + simd_normalize(g[b]) * w)
            }
            if carry { garmentMove(s) }
        }
        // the chord's kinks (the share's ends, the relax's edge) shade soft
        guard smoothing else { return relaxing }
        var m = x.m, next = x.next
        for b in 0..<n { m[b] = nrm[band[b]]; next[b] = m[b] }
        for (e, j) in ghosts.enumerated() { m[n + e] = nrm[Int(j)]; next[n + e] = m[n + e] }
        for _ in 0..<normalPasses {
            var most: Float = 0
            for b in 0..<n where wn[b] > 1e-3 {
                let lo = Int(start[b]), hi = Int(start[b + 1])
                var sum = SIMD3<Float>.zero
                for e in lo..<hi { sum += m[Int(slot[e])] }
                next[b] = simd_normalize(m[b] + wn[b] * (sum / size[b] - m[b]))
                most = max(most, simd_length_squared(next[b] - m[b]))
            }
            swap(&m, &next)
            if most < still { break }
        }
        for v in verts { let i = Int(v), b = bandOf[i]; if wn[b] > 1e-3 { nrm[i] = m[b] } }
        return relaxing
    }

    /// a smoothing pass moving nothing more than this (body units, or radians for normals) has settled
    private static let settled: Float = 1e-7

    /// The relax's move for the garments: its slide along the skin smoothed over the band (a strap samples it at a few
    /// vertices, and where it varies fast the strap's edges zigzag), the part along the normal kept so they stay on the skin.
    /// In place on scratch.move, from scratch.g (the band's surface normals).
    private static func garmentMove(_ s: SkinBend) {
        let x = s.scratch, n = s.band.count, g = x.g, move = x.move, nb = x.m
        let band = s.band, start = x.start, slot = x.slot, size = x.size, bandOf = s.bandOf
        guard let order = x.order else { return }
        var t = x.t, next = x.next
        for b in 0..<n {
            nb[b] = simd_length(g[b]) > 1e-12 ? simd_normalize(g[b]) : .zero
            let mv = move[band[b]]
            t[b] = mv - simd_dot(mv, nb[b]) * nb[b]
            next[b] = t[b]
        }
        // off the band nothing slides
        for e in 0..<s.ghosts.count { t[n + e] = .zero; next[n + e] = .zero }
        // only as far from the followed vertices as can still reach them
        for pass in 0..<garmentPasses {
            var most: Float = 0
            for o in 0..<x.reach[garmentPasses - 1 - pass] {
                let b = Int(order[o]), lo = Int(start[b]), hi = Int(start[b + 1])
                var sum = SIMD3<Float>.zero
                for e in lo..<hi { sum += t[Int(slot[e])] }
                let u = t[b] + 0.5 * (sum / size[b] - t[b])
                next[b] = u - simd_dot(u, nb[b]) * nb[b]
                most = max(most, simd_length_squared(next[b] - t[b]))
            }
            swap(&t, &next)
            if most < settled * settled { break }
        }
        for v in s.bandVerts {
            let i = Int(v), b = bandOf[i]
            move[i] = simd_dot(move[i], nb[b]) * nb[b] + t[b]
        }
    }

    /// Over a turned shoulder's band a garment rides its skin: the closest skin point plus its rest offset, offset and
    /// normal turned as the skin's normal did; behind the shoulder fully, fading out in front (there the smoothed slide
    /// keeps a strap from stretching with the skin). Its own chord and the smoothed slide leave a back strap wavy, the
    /// chord's normal shades it in facets. In place on pos, nrm (rig space), after the relax's carry.
    private static func wrapGarment(_ s: SkinBend, skin: SkinBend, sides: [Float],
                                    pos: UnsafeMutablePointer<SIMD3<Float>>, nrm: UnsafeMutablePointer<SIMD3<Float>>) {
        let fs = s.followStart, fi = s.followIdx, fw = s.followW, now = skin.scratch.now, nowN = skin.scratch.nowN
        for i in 0..<s.rest.count {
            var w: Float = 0, a = SIMD3<Float>.zero, b = SIMD3<Float>.zero, on = SIMD3<Float>.zero
            for e in Int(fs[i])..<Int(fs[i + 1]) {
                let j = Int(fi[e]), f = fw[e]
                if skin.bandOf[j] >= 0 && sides.contains(skin.side[j]) { w += f }
                a += f * skin.normals[j]; b += f * nowN[j]; on += f * now[j]
            }
            guard w > 0, simd_length(a) > 1e-12, simd_length(b) > 1e-12 else { continue }
            a = simd_normalize(a); b = simd_normalize(b)
            let c = simd_dot(a, b), k = simd_cross(a, b)
            guard c > -0.99 else { continue }
            func turn(_ v: SIMD3<Float>) -> SIMD3<Float> { v * c + simd_cross(k, v) + k * (simd_dot(k, v) / (1 + c)) }
            pos[i] += w * s.followBehind[i] * (on + turn(s.followOffset[i]) - pos[i])
            nrm[i] += w * (simd_normalize(turn(s.normals[i])) - simd_normalize(nrm[i]))
        }
    }

    private struct MinHeap {
        private var items: [(Float, Int)] = []
        mutating func push(_ key: Float, _ value: Int) {
            items.append((key, value))
            var c = items.count - 1
            while c > 0, items[(c - 1) / 2].0 > items[c].0 { items.swapAt(c, (c - 1) / 2); c = (c - 1) / 2 }
        }
        mutating func pop() -> (Float, Int)? {
            guard let top = items.first else { return nil }
            items[0] = items[items.count - 1]
            items.removeLast()
            var p = 0
            while true {
                let l = 2 * p + 1, r = l + 1
                var m = p
                if l < items.count && items[l].0 < items[m].0 { m = l }
                if r < items.count && items[r].0 < items[m].0 { m = r }
                if m == p { break }
                items.swapAt(p, m); p = m
            }
            return top
        }
    }

    /// The skin follows every bent joint: a vertex under a joint turns with it (blended across the band round the
    /// pivot), one beside it turns by its share, a shoulder by bindSkin's share; joints compose parent first, each pivot moved by its ancestors.
    private func bendSkin() {
        guard realSkin else { return }
        let band = Self.bendBand
        struct Bend { let id: String; let own, parent: ObjectIdentifier; let restPivot, restAxis, pivot, axis, up, shift: SIMD3<Float>; let theta: Float; let under: Set<ObjectIdentifier>; let back: BackBend? }
        func joint(_ id: String) -> Joint? { joints.first { $0.id == id } }
        func depth(_ j: Joint) -> Int { j.parent.flatMap(joint).map { depth($0) + 1 } ?? 0 }
        var bends: [Bend] = []
        var key: [Float] = []
        for j in joints.filter({ abs(jointAngles[$0.id] ?? 0) > 0.5 }).sorted(by: { depth($0) < depth($1) }) {
            guard let outer = jointOuter[j.id], let offset = jointInner[j.id] else { continue }
            var under: Set<ObjectIdentifier> = [ObjectIdentifier(offset)]
            for k in joints {
                var p = k.parent
                while let id = p {
                    if id == j.id { if let o = jointInner[k.id] { under.insert(ObjectIdentifier(o)) }; break }
                    p = joint(id)?.parent
                }
            }
            var pivot = outer.position, axis = simd_normalize(j.axis.simd), up = SIMD3<Float>(0, 1, 0)
            for b in bends where b.under.contains(ObjectIdentifier(offset)) {
                let r = simd_quatf(angle: b.theta, axis: b.axis)
                pivot = b.pivot + r.act(pivot - b.pivot) + b.shift
                axis = r.act(axis)
                up = r.act(up)
            }
            let back = j.id == "back" ? backBend() : nil
            let bend = Bend(id: j.id, own: ObjectIdentifier(offset), parent: ObjectIdentifier(outer.parent ?? rig), restPivot: outer.position, restAxis: simd_normalize(j.axis.simd),
                            pivot: pivot, axis: axis, up: up, shift: back?.shift ?? .zero, theta: (jointAngles[j.id] ?? 0) * .pi / 180, under: under, back: back)
            bends.append(bend)
            key += [Float(joints.firstIndex { $0.id == j.id } ?? -1), bend.theta, back?.y1 ?? 0]
            for v in [bend.restPivot, bend.pivot, bend.axis, bend.up, bend.shift] { key += [v.x, v.y, v.z] }
        }
        if bends.isEmpty && skinBends.isEmpty { return }
        if skinBends.isEmpty { bindSkin() }
        // the same pose as last time and nobody else wrote the skin since: it already shows
        if let last = skinPose, last.key == key, last.versions == skinBends.map(\.bender.version) {
            for s in skinBends { s.bender.shade?.isEnabled = solidSkin }
            return
        }
        defer { skinPose = (key, skinBends.map(\.bender.version)) }
        let turns = bends.filter { $0.id.hasPrefix("shoulder") }.map { (side: Float($0.restPivot.x < 0 ? -1 : 1), theta: $0.theta, axis: $0.axis) }

        // per bend, what every vertex reuses: its kind, holders by index, its turn and press plane
        enum Kind { case back, shoulder, hinge, plain }
        struct Prep {
            let kind: Kind; let knee, upward, left, neck: Bool; let own, parent: Int
            let restPivot, restAxis, pivot, axis, up, shift, pressN, pressM: SIMD3<Float>
            let theta, cosT, sinT: Float; let turn: simd_quatf
            /// knee: how open the corner is (kneeOpen), its sides unshaded
            let open: Float
            /// hinge: how closed the corner is for foldNormal (foldKnee, foldElbow)
            let fold: Float
            /// shoulder: topKeep eased in by the turn (0: the chord as is)
            let keep: Float
        }
        let nh = holders.count, holdID = holders.map { ObjectIdentifier($0) }
        var underHolder = [Bool](repeating: false, count: max(1, bends.count * nh))
        let preps = bends.enumerated().map { bi, b -> Prep in
            for h in 0..<nh { underHolder[bi * nh + h] = b.under.contains(holdID[h]) }
            let kind: Kind = b.back != nil ? .back : b.id.hasPrefix("shoulder") ? .shoulder : Self.hinge(b.id) ? .hinge : .plain
            let n = simd_quatf(angle: b.theta / 2, axis: b.axis).act(b.up)
            return Prep(kind: kind, knee: b.id.hasPrefix("knee"), upward: Self.upward.contains(b.id), left: b.restPivot.x < 0,
                        neck: b.id == "neck" && neckFitted,
                        own: holdID.firstIndex(of: b.own) ?? -1, parent: holdID.firstIndex(of: b.parent) ?? -1,
                        restPivot: b.restPivot, restAxis: b.restAxis, pivot: b.pivot, axis: b.axis, up: b.up, shift: b.shift,
                        pressN: n, pressM: simd_cross(n, b.axis), theta: b.theta, cosT: cos(b.theta), sinT: sin(b.theta),
                        turn: simd_quatf(angle: b.theta, axis: b.axis),
                        open: b.id.hasPrefix("knee") ? 1 - Self.smooth(Self.kneeOpen.0, Self.kneeOpen.1, abs(b.theta)) : 0,
                        fold: kind != .hinge ? 0 : b.id.hasPrefix("knee") ? Self.smooth(Self.foldKnee.0, Self.foldKnee.1, abs(b.theta))
                            : Self.smooth(Self.foldElbow.0, Self.foldElbow.1, abs(b.theta)),
                        keep: kind == .shoulder ? Self.topKeep * Self.smooth(Self.relaxFrom, Self.relaxFull, abs(b.theta)) : 0)
        }
        let backBend = bends.lazy.compactMap(\.back).first
        // garments carrying the relax (else its move isn't smoothed for them)
        let carry = skinBends.contains { !$0.followStart.isEmpty }
        var relaxMove: UnsafeMutablePointer<SIMD3<Float>>?
        var wrapSkin: SkinBend?
        for s in skinBends {
            if bends.isEmpty { s.bender.write(indices: [], positions: [], normals: []); continue }
            let x = s.scratch, count = s.rest.count
            let pos = x.pos, nrm = x.nrm, pre = x.pre, jac = x.jac, occ = x.occ, crease = x.crease
            let shaded = s.bender.entity.name == "skin:body", hasJac = !s.bandOf.isEmpty
            let rest = s.rest, normals = s.normals, holder = s.holder, side = s.side, shoulder = s.shoulder, top = s.top
            let bandOf = s.bandOf, bandGrad = s.bandGrad
            underHolder.withUnsafeBufferPointer { under in
                preps.withUnsafeBufferPointer { bp in
                    for i in 0..<count {
                        let h = holder[i], q = rest[i]
                        var p = q, nm = normals[i], pr = q, jv = SIMD3<Float>.zero, oc: Float = 0, cr: Int32 = 0
                        var preSet = false
                        // the turn so far, carrying the share's gradient to the chord
                        var turn = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
                        for bi in 0..<bp.count {
                            let b = bp[bi], held = under[bi * nh + h]
                            switch b.kind {
                            case .back:
                                if held && h != b.own {
                                    // a limb hung from the back follows the trunk above the curve
                                    p = b.pivot + b.turn.act(p - b.pivot) + b.shift
                                    nm = b.turn.act(nm)
                                    turn = b.turn * turn
                                } else if h == b.own || h == b.parent, let back = backBend {
                                    let (moved, r) = back.move(p)
                                    p = moved
                                    nm = r.act(nm)
                                    turn = r * turn
                                }
                            case .shoulder:
                                // the arm's turn blended in by the vertex's share (bindSkin), along the chord rather than round the
                                // pivot: the armpit folds into a hollow instead of swinging out past the arm
                                if !preSet { pr = p; preSet = true }
                                guard held || h == b.parent, (side[i] < 0) == b.left, shoulder[i] >= 1e-3 else { continue }
                                let w = shoulder[i], c = 1 - w + w * b.cosT, sn = w * b.sinT
                                // turned as far as the chord point's direction did
                                let chord = simd_quatf(angle: atan2(sn, c), axis: b.axis)
                                if hasJac, bandOf[i] >= 0 {
                                    jv = Self.chordNormal(nm, grad: turn.act(bandGrad[bandOf[i]]), d: p - b.pivot, w: w, c: c, s: sn,
                                                          q: chord, turn: b.turn, axis: b.axis)
                                }
                                p += w * (b.pivot + b.turn.act(p - b.pivot) - p)
                                // the chord left the radius round the axis at rho: over the shoulder top give it back
                                let k = top.isEmpty ? 0 : b.keep * top[i]
                                if k > 0 {
                                    let rho = (c * c + sn * sn).squareRoot(), d = p - b.pivot
                                    p += (d - simd_dot(d, b.axis) * b.axis) * ((rho + k * (1 - rho)) / max(rho, 1e-6) - 1)
                                }
                                nm = chord.act(nm)
                            case .hinge, .plain:
                                let hinge = b.kind == .hinge
                                var w = hinge ? Self.hingeShare(knee: b.knee, q, pivot: b.restPivot, axis: b.restAxis)
                                    : b.neck ? Self.neckShare(q, pivot: b.restPivot) : Self.share(up: b.upward, pivotY: b.restPivot.y, q.y)
                                var pressing: Float = 1, scale: Float = 1
                                if held {
                                    // a limb hung from the joint (an arm from the back) turns whole, wherever its hand hangs
                                    if h != b.own { w = 1 }
                                } else if h == b.parent {
                                    // beside the joint: only round it (the torso hangs below a shoulder but stays)
                                    let up = b.upward
                                    scale = (up ? 1 : Self.beside(q, b.restPivot))
                                        * (1 - (up ? Self.smooth(b.restPivot.y + band, b.restPivot.y + 2.5 * band, q.y)
                                                   : Self.smooth(b.restPivot.y - band, b.restPivot.y - 2.5 * band, q.y)))
                                    w *= scale
                                    // the other leg isn't pressed
                                    pressing = 1 - Self.smooth(0.12, 0.2, abs(simd_dot(q - b.restPivot, b.restAxis)))
                                } else { continue }
                                var plain = nm
                                if w >= 1e-3 {
                                    let r = simd_quatf(angle: w * b.theta, axis: b.axis), d = p - b.pivot
                                    plain = r.act(nm)
                                    // inside the bend (after the turn) on the flexor side (not over the kneecap) the share's
                                    // gradient turns the normal too
                                    var c: Float = 0
                                    if b.fold > 0 && !(held && h != b.own) {
                                        let f = simd_cross(b.restAxis, SIMD3(0, -1, 0))
                                        let flexor = 1 - Self.smooth(0.2, -0.6, simd_dot(q - b.restPivot, f) / (b.knee ? Self.kneeDepth : Self.elbowDepth))
                                        c = b.fold * flexor * Self.smooth(0, Self.pressRamp, simd_dot(r.act(d), b.pressM))
                                    }
                                    if c > 0 {
                                        let (fn, use) = Self.foldNormal(q, d: d, nrm: nm, scale: scale, knee: b.knee, restPivot: b.restPivot,
                                                                        restAxis: b.restAxis, axis: b.axis, up: b.up, theta: b.theta)
                                        var to = nm + c * use * (fn - nm)
                                        // keep the side of the press plane it faces: pressed() flattens it to ±n by that sign
                                        let pn = r.inverse.act(b.pressN), a0 = simd_dot(nm, pn), a1 = simd_dot(to, pn)
                                        if a0 * a1 < 0 { to -= a1 * pn }
                                        if simd_length(to) > 1e-12 { nm = simd_normalize(to) }
                                    }
                                    p = b.pivot + r.act(d)
                                    nm = r.act(nm)
                                    if hasJac && jv != .zero { jv = r.act(jv) } else { turn = r * turn }
                                }
                                if hinge && pressing > 1e-3 {
                                    let r = Self.pressed(p, nm, near: w < 0.5, weight: pressing, pivot: b.pivot, n: b.pressN, m: b.pressM, knee: b.knee,
                                                         open: b.open, plain: plain)
                                    p = r.0; nm = r.1
                                    if shaded {
                                        oc = max(oc, r.2)
                                        let d = p - b.pivot
                                        if abs(simd_dot(d, b.pressN)) < Self.shadeFalloff + Self.contactReach.1, simd_dot(d, b.pressM) > 0 {
                                            cr = Int32(bi * 2) + (w < 0.5 ? 1 : 0) + 1
                                        }
                                    }
                                }
                            }
                        }
                        pos[i] = p; nrm[i] = nm; occ[i] = oc; crease[i] = cr
                        if hasJac { pre[i] = pr; jac[i] = jv }
                    }
                }
            }
            if shaded {
                for (bi, b) in preps.enumerated() where b.knee {
                    Self.kneeRim(pos: pos, crease: crease, count: count, tag: Int32(bi * 2) + 1, pivot: b.pivot, n: b.pressN, m: b.pressM)
                }
                Self.contactShade(occ: occ, pos: pos, crease: crease, count: count)
            }
            if !s.band.isEmpty && !turns.isEmpty {
                relaxMove = Self.relaxShoulders(s, turns: turns, pos: pos, nrm: nrm, pre: pre, jac: jac, carry: carry) ? x.move : nil
                x.now.update(from: pos, count: count)
                x.nowN.update(from: nrm, count: count)
                wrapSkin = s
            } else if !s.followStart.isEmpty {
                let fs = s.followStart, fi = s.followIdx, fw = s.followW
                if let move = relaxMove {
                    for i in 0..<count { for e in Int(fs[i])..<Int(fs[i + 1]) { pos[i] += fw[e] * move[Int(fi[e])] } }
                }
                if let skin = wrapSkin { Self.wrapGarment(s, skin: skin, sides: turns.map(\.side), pos: pos, nrm: nrm) }
            }
            // into the mesh's space, in place
            let m = s.toLocal
            for i in 0..<count {
                let q = m * SIMD4(pos[i], 1), n = m * SIMD4(nrm[i], 0)
                pos[i] = SIMD3(q.x, q.y, q.z)
                nrm[i] = simd_normalize(SIMD3(n.x, n.y, n.z))
            }
            s.bender.write(count: count, positions: pos, normals: nrm, occlusion: shaded ? occ : nil)
            s.bender.shade?.isEnabled = solidSkin
        }
    }

    /// parts crossing a joint, turned into movable meshes on its first bend, by part id
    private var benders: [String: SkinDeformer] = [:]
    private var crossing: [String: [String]] = [:]
    /// half-width of the band over a joint where a crossing part turns gradually (body units)
    private static let bendBand: Float = 0.12

    /// Parts crossing the joint (muscles, vessels, nerves; bones stay rigid) bend with it: each vertex turns by its
    /// share of the angle, none on the near side to all on the far side, so a hamstring stays joined to the shin.
    private func bendCrossing(_ joint: Joint) {
        let band = Self.bendBand
        if crossing.isEmpty {
            // every joint's set, measured at rest before any part is made movable (a movable part's box is padded
            // for culling, wide enough to reach the other leg's joint); in the parent's space (the joint's own
            // parts sit under its offset: the same coordinates)
            for j in joints {
                guard let p = jointOuter[j.id]?.position else { continue }
                // the back and neck cut right across the body; a limb's joint only reaches its own limb
                let (rx, rz): (Float, Float) = Self.upward.contains(j.id) ? (0.6, 0.6) : (0.06, 0.1)
                // the back's curve reaches up the spine
                let (lo, hi) = j.id == "back" ? (p.y - BackBend.hipBand, backBend(degrees: 0)?.y1 ?? p.y + band) : (p.y - band, p.y + band)
                crossing[j.id] = partEntities.filter { id, entity in
                    guard let layer = partLayer[id], layer != .skeletal, layer != .skin else { return false }
                    let box = entity.visualBounds(relativeTo: entity.parent)
                    return !box.isEmpty && box.min.y < hi && box.max.y > lo
                        && box.min.x - rx < p.x && box.max.x + rx > p.x && box.min.z - rz < p.z && box.max.z + rz > p.z
                }.map(\.key)
            }
        }
        for id in crossing[joint.id] ?? [] {
            guard let entity = partEntities[id] else { continue }
            // hidden (another layer): bent as now once shown
            guard entity.isEnabled else { unbent[id] = (joint.id, entity.transform.matrix); continue }
            unbent[id] = nil
            bend(id, entity, by: joint, matrix: entity.transform.matrix)
        }
    }

    /// hidden parts the last bend of a joint they cross skipped: that joint and the part's transform then
    private var unbent: [String: (joint: String, matrix: float4x4)] = [:]

    /// the bends hidden parts missed, now they show
    private func bendShown() {
        for (id, missed) in unbent where partEntities[id]?.isEnabled == true {
            unbent[id] = nil
            if let entity = partEntities[id], let joint = joints.first(where: { $0.id == missed.joint }) { bend(id, entity, by: joint, matrix: missed.matrix) }
        }
    }

    /// One part crossing `joint` bent by it and every other bent joint it crosses (`matrix`: its transform)
    private func bend(_ id: String, _ entity: ModelEntity, by joint: Joint, matrix m: float4x4) {
        // a part crossing several joints (a chest muscle under the back and a shoulder) bends by all of them, the inner first
        func depth(_ j: Joint) -> Int { j.parent.flatMap { p in joints.first { $0.id == p } }.map { depth($0) + 1 } ?? 0 }
        let bender: SkinDeformer
        if let b = benders[id] { bender = b } else {
            guard let b = SkinDeformer(entity) else { return }
            benders[id] = b
            bender = b
        }
        let inv = m.inverse
        let rest = bender.rest.map { (p: SIMD3<Float>) -> SIMD3<Float> in let q = m * SIMD4(p, 1); return SIMD3(q.x, q.y, q.z) }
        var pos = rest
        var nrm = bender.normals.map { (n: SIMD3<Float>) -> SIMD3<Float> in let q = m * SIMD4(n, 0); return SIMD3(q.x, q.y, q.z) }
        let bent = joints.filter { $0.id == joint.id || (abs(jointAngles[$0.id] ?? 0) > 0.5 && crossing[$0.id]?.contains(id) == true) }
        for j in bent.sorted(by: { depth($0) > depth($1) }) {
            guard let pivot = jointOuter[j.id]?.position else { continue }
            let within = jointInner[j.id], axis = simd_normalize(j.axis.simd), theta = (jointAngles[j.id] ?? 0) * .pi / 180
            // already turned whole by a child joint's container (an arm muscle under the back's shoulder)
            if inLimb(entity, within) { continue }
            let held = under(entity, within)
            if let back = j.id == "back" ? backBend() : nil {
                // onto the curve; a part under the back's container is carried by its top already
                let undo = held ? back.top.inverse : matrix_identity_float4x4
                let unturn = simd_quatf(angle: held ? -theta : 0, axis: axis)
                for i in pos.indices {
                    let (p, r) = back.move(pos[i])
                    let q = undo * SIMD4(p, 1)
                    pos[i] = SIMD3(q.x, q.y, q.z)
                    nrm[i] = unturn.act(r.act(nrm[i]))
                }
                continue
            }
            let up = Self.upward.contains(j.id), neck = j.id == "neck" && neckFitted
            for i in pos.indices {
                let q = rest[i]
                // the far side (below the joint) turns fully; a part under the joint already turns with it
                let w = neck ? Self.neckShare(q, pivot: pivot) : Self.share(up: up, pivotY: pivot.y, q.y)
                let a = held ? (w - 1) * theta : w * (up ? 1 : Self.beside(q, pivot)) * theta
                if abs(a) < 1e-4 { continue }
                let r = simd_quatf(angle: a, axis: axis)
                pos[i] = pivot + r.act(pos[i] - pivot)
                nrm[i] = r.act(nrm[i])
            }
        }
        let local = pos.map { (p: SIMD3<Float>) -> SIMD3<Float> in let q = inv * SIMD4(p, 1); return SIMD3(q.x, q.y, q.z) }
        let ln = nrm.map { (n: SIMD3<Float>) -> SIMD3<Float> in let q = inv * SIMD4(n, 0); return simd_normalize(SIMD3(q.x, q.y, q.z)) }
        bender.write(indices: Array(local.indices), positions: local, normals: ln)
    }

    /// The named entity under a view point (a ray from the camera), or nil; a part keeps the spot touched (anchor).
    /// A miss is retried in a small ring round the point: a finger lands beside a thin bone or vessel.
    func pick(at p: CGPoint, in size: CGSize) -> String? {
        guard let scene = root.scene, size.width > 0, size.height > 0 else { return nil }
        let t = tan(camera.camera.fieldOfViewInDegrees * .pi / 360), aspect = Float(size.width / size.height)
        let m = camera.transformMatrix(relativeTo: nil)
        let origin = SIMD3(m.columns.3.x, m.columns.3.y, m.columns.3.z)
        // over inner layers the skin is glass: a tap goes through it to the part beneath
        let through = layers.contains { $0 != .skin }
        func cast(_ q: CGPoint) -> CollisionCastHit? {
            let d = SIMD4(Float(2 * q.x / size.width - 1) * t * aspect, Float(1 - 2 * q.y / size.height) * t, -1, 0)
            let w = m * d
            let hits = scene.raycast(origin: origin, direction: simd_normalize(SIMD3(w.x, w.y, w.z)), length: 50, query: .all, mask: .all, relativeTo: nil)
            return hits.sorted { $0.distance < $1.distance }.first { !(through && $0.entity.name.hasPrefix("skin:")) }
        }
        if let id = nearestPoint(to: p, in: size, origin: origin, cast: { scene.raycast(origin: origin, direction: $0, length: 50, query: .all, mask: .all, relativeTo: nil) }) {
            return "point:\(id)"
        }
        var hit = cast(p)
        for r in [10.0, 20.0] where hit == nil {
            for k in 0..<8 where hit == nil {
                let a = Double(k) * .pi / 4
                hit = cast(CGPoint(x: p.x + r * cos(a), y: p.y + r * sin(a)))
            }
        }
        guard let hit else { return nil }
        anchor = (hit.entity.name, hit.entity.convert(position: hit.position, from: nil))
        lastHit = hit.position
        return hit.entity.name
    }

    /// Points are smaller than a fingertip: the visible dot nearest the tap on screen, within reach.
    private func nearestPoint(to p: CGPoint, in size: CGSize, origin: SIMD3<Float>, reach: CGFloat = 28,
                              cast: (SIMD3<Float>) -> [CollisionCastHit]) -> String? {
        var best = reach, found: (id: String, world: SIMD3<Float>)?
        for (id, dots) in pointEntities {
            for dot in dots where dot.isEnabledInHierarchy {
                let world = dot.position(relativeTo: nil)
                guard let q = screenPoint(world, in: size) else { continue }
                let d = hypot(q.x - p.x, q.y - p.y)
                guard d < best, !occluded(world, origin: origin, cast: cast) else { continue }
                best = d
                found = (id, world)
            }
        }
        guard let found else { return nil }
        anchor = nil
        lastHit = found.world
        return found.id
    }

    /// something solid (not a point, hair or underwear) sits between the camera and the spot
    private func occluded(_ world: SIMD3<Float>, origin: SIMD3<Float>, cast: (SIMD3<Float>) -> [CollisionCastHit]) -> Bool {
        let distance = simd_length(world - origin)
        let through = layers.contains { $0 != .skin }
        let solid = cast(simd_normalize(world - origin)).filter {
            let n = $0.entity.name
            return !n.hasPrefix("point:") && n != "skin:hair" && !n.hasPrefix("skin:underwear") && !(through && n.hasPrefix("skin:"))
        }
        return solid.contains { $0.distance < distance - 0.03 }
    }

    /// where the last pick landed (world)
    private(set) var lastHit = SIMD3<Float>(repeating: 0)

    /// The joint nearest a world point (a tap on the skin), within reach of it.
    func nearestJoint(to p: SIMD3<Float>, within reach: Float = 0.5) -> String? {
        var best = reach, pick: String?
        for j in joints {
            guard let outer = jointOuter[j.id] else { continue }
            let d = simd_distance(outer.position(relativeTo: nil), p)
            if d < best { best = d; pick = j.id }
        }
        return pick
    }

    /// where a part was last touched, in its own space (a callout's anchor; otherwise its centre)
    private var anchor: (id: String, local: SIMD3<Float>)?

    /// A part's anchor on screen (nil when behind the camera or not built), for a callout that follows it.
    func project(_ id: String, in size: CGSize) -> CGPoint? {
        guard let entity = partEntities[id] ?? organEntities[id], size.width > 0, size.height > 0 else { return nil }
        let world: SIMD3<Float>
        if let anchor, anchor.id == id {
            world = entity.convert(position: anchor.local, to: nil)
        } else {
            let box = entity.visualBounds(relativeTo: nil)
            guard !box.isEmpty else { return nil }
            world = box.center
        }
        return screenPoint(world, in: size)
    }

    private func screenPoint(_ world: SIMD3<Float>, in size: CGSize) -> CGPoint? {
        let p = camera.transformMatrix(relativeTo: nil).inverse * SIMD4(world, 1)
        guard p.z < 0 else { return nil }
        let t = tan(camera.camera.fieldOfViewInDegrees * .pi / 360), aspect = Float(size.width / size.height)
        let x = (-p.x / p.z) / (t * aspect), y = (-p.y / p.z) / t
        return CGPoint(x: CGFloat((x + 1) / 2) * size.width, y: CGFloat((1 - y) / 2) * size.height)
    }

    func setActivePoint(_ id: String?) {
        for (pid, dots) in pointEntities {
            for dot in dots {
                dot.model?.materials = [UnlitMaterial(color: pid == id ? UIColor(hex: "#FFD166") : pointColors[pid] ?? UIColor(hex: "#6C4F9E"))]
                dot.scale = SIMD3(repeating: pid == id ? (smallPoints.contains(pid) ? 1.8 : 1.4) : 1)
            }
        }
    }

    /// Only these points show (nil = all).
    func showPoints(_ ids: Set<String>?) {
        for (pid, dots) in pointEntities {
            for dot in dots { dot.isEnabled = ids?.contains(pid) ?? true }
        }
    }

    /// Just these channels (nil = all).
    func showMeridians(_ visible: Bool, ids: Set<String>?) {
        meridianFilter = (visible, ids)
        applyMeridians()
    }

    /// Meridian lines on or off; with `only`, just that channel.
    func showMeridians(_ visible: Bool, only: String? = nil) {
        showMeridians(visible, ids: only.map { [$0] })
    }

    var meridiansVisible: Bool { meridianFilter.visible }

    private func applyMeridians() {
        for (id, lines) in meridianEntities {
            for line in lines { line.isEnabled = meridianFilter.visible && (meridianFilter.ids?.contains(id) ?? true) }
        }
    }

    /// Pulse from a point to each organ it acts on; organs light when it arrives.
    func pulse(from start: SIMD3<Float>, to organIds: [String]) {
        litOrgans = Set(organIds)
        flashStart = -1
        pulseStart = clock
        // data positions are adult; a head point moves with the head's age scaling
        let start = agePoint(start)
        pulseCurves = organIds.compactMap { organEntities[$0]?.position }.map { end in
            var mid = (start + end) / 2
            mid.z += 0.35
            return (start, mid, end)
        }
    }

    private var solidSkin = true

    private func applyVisibility() {
        let inner = layers.contains { $0 != .skin }
        // skin alone is solid; over inner layers it's a faint glass
        let skinOpacity: Float = layers.contains(.skin) ? (inner ? Self.glassOpacity : 1) : 0
        for (skin, base) in skinEntities {
            // the real figure's hair steps aside for points and channels: its scalp is already tinted the hair's colour
            let hidden = seeThrough && realSkin && skin.name == "skin:hair"
            skin.isEnabled = skinOpacity > 0 && !hidden
            let hair = seeThrough && (skin.name == "skin:hair" || (Figure.clothingOptional && skin.name.hasPrefix("skin:underwear")))
            skin.model?.materials = [Self.faded(base, hair ? min(skinOpacity, 0.35) : skinOpacity)]
        }
        // the crease shadow only on solid skin
        solidSkin = skinOpacity >= 1
        for s in skinBends { s.bender.shade?.isEnabled = solidSkin }
        let muscleOpacity: Float = layers.contains(.skeletal) ? 0.55 : 1
        for (id, entity) in partEntities {
            guard let layer = partLayer[id] else { continue }
            // deep muscle cores fill gaps in a muscle-only view but would hide the bones
            let deep = id.hasPrefix("deep-") && layers.contains(.skeletal)
            entity.isEnabled = layers.contains(layer) && parts.visible(id) && !deep && !hiddenForAge.contains(id)
            let look = PartLook(base: baseMaterials[id]!, opacity: layer == .muscular ? muscleOpacity : 1, selected: id == selected)
            entity.model?.materials = [Self.partMaterial(look)]
        }
        for (id, entity) in organEntities where Catalog.organ(id)?.region != true {
            // the brain is an organ but belongs in the nervous system view too
            entity.isEnabled = (layers.contains(.organs) || (id == "brain" && layers.contains(.nervous))) && parts.visible(id)
            for case let piece as ModelEntity in entity.children {
                guard let own = organOpacity[ObjectIdentifier(piece)], var m = piece.model?.materials.first as? PhysicallyBasedMaterial else { continue }
                // (already so: a setter rebuilds the material's shader parameters)
                switch m.blending {
                case .opaque where own >= 1: continue
                case let .transparent(o) where own < 1 && o.scale == own && o.texture == nil: continue
                default: break
                }
                m.blending = own < 1 ? .transparent(opacity: .init(floatLiteral: own)) : .opaque
                piece.model?.materials = [m]
            }
        }
        bendShown()
    }

    /// Every tappable part and organ in this body.
    var partIDs: [String] {
        Array(partEntities.keys) + organEntities.keys.filter { Catalog.organ($0)?.names != nil && Catalog.organ($0)?.region != true }
    }

    // MARK: frame

    func update(dt: Float) {
        clock += dt
        for (id, degrees) in pendingJoints.sorted(by: { $0.key < $1.key }) { setJoint(id, degrees: degrees) }
        let k = 1 - exp(-6 * dt)
        if !touched { yaw += dt * 0.35 }
        if let goal = goalYaw {
            yaw += (goal - yaw) * k
            if abs(goal - yaw) < 0.001 { goalYaw = nil }
        }
        distance += (goalDistance - distance) * k
        focusY += (goalFocusY - focusY) * k
        panX += (goalPanX - panX) * k
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

    /// last emissive written per organ — materials are only rebuilt when it changes
    private var organGlow: [String: Float] = [:]

    private func updateOrgans() {
        for (id, entity) in organEntities {
            let lit = litOrgans.contains(id) && flashStart >= 0
            var pulse: Float = 0
            if lit {
                let t = clock - flashStart
                pulse = t < 0.8 ? sin(t / 0.8 * .pi) * 0.6 : 0
            }
            if id == "heart" { pulse += pow(max(0, sin(clock * bpm / 60 * 2 * .pi)), 4) * 0.18 }
            let base = organScale[id] ?? SIMD3(repeating: 1)
            if pulse != 0 || entity.scale != base { entity.scale = base * (1 + pulse) }
            guard lit || id == selected || organGlow[id] != nil else { continue }
            let organ = Catalog.organ(id)
            if organ?.region == true { entity.isEnabled = lit }
            let glow: Float = lit ? 0.6 + pulse : id == selected ? 0.6 : 0
            guard organGlow[id] != glow else { continue }
            organGlow[id] = glow == 0 ? nil : glow
            for case let piece as ModelEntity in entity.children {
                guard var m = piece.model?.materials.first as? PhysicallyBasedMaterial else { continue }
                m.emissiveColor = .init(color: organ?.region == true ? UIColor(hex: organ!.color) : UIColor(hex: id == selected ? "#FFD166" : "#4ECB71"))
                m.emissiveIntensity = glow
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
            if dot.name != (venous ? "v" : "a") {
                dot.name = venous ? "v" : "a"
                dot.model?.materials = [venous ? Self.venous : Self.arterial]
            }
        }
    }

    private static let arterial = UnlitMaterial(color: UIColor(hex: "#E03A3E"))
    private static let venous = UnlitMaterial(color: UIColor(hex: "#3A5BD9"))

    // MARK: helpers

    func faceFront() {
        goalYaw = (yaw / (2 * .pi)).rounded() * 2 * .pi
    }

    func faceBack() {
        goalYaw = ((yaw - .pi) / (2 * .pi)).rounded() * 2 * .pi + .pi
    }

    func focus(_ f: Focus) {
        let body = proportions.body
        switch f {
        case .all:
            // centre between the (raised) feet and the (enlarged) crown
            goalFocusY = (ageY(-1.6, x: 0.17) + ageY(1.646)) / 2
        case .foot, .leg: goalFocusY = ageY(f.y, x: 0.17)
        case .hand, .arm: goalFocusY = ageY(f.y, x: 0.45)
        case .ear, .head, .front, .back: goalFocusY = ageY(f.y)
        }
        if f == .back { faceBack() }
        goalPanX = f == .all ? basePanX : f.panX * body
        // smaller bodies bring the camera a little closer but still read as small
        goalDistance = f.distance * (f == .all ? (0.55 + 0.45 * body) * baseZoom : body.squareRoot())
    }

    /// Turn and zoom so a point on the skin faces the camera, centred.
    func focus(on point: SIMD3<Float>, normal n: SIMD3<Float>, distance: Float = 1.45) {
        let body = proportions.body
        // straight up (crown): look from the front
        var target: Float = abs(n.x) + abs(n.z) < 0.3 ? 0 : -atan2(n.x, n.z)
        target += ((yaw - target) / (2 * .pi)).rounded() * 2 * .pi
        goalYaw = target
        let turned = (simd_quatf(angle: pitch, axis: SIMD3(1, 0, 0)) * simd_quatf(angle: target, axis: SIMD3(0, 1, 0))).act(agePoint(point) * body)
        goalPanX = turned.x
        goalFocusY = turned.y
        goalDistance = distance * body.squareRoot()
    }

    /// Turn and zoom so a part faces the camera, centred: from behind when it lies in the back half of the body.
    func focus(onPart id: String) {
        guard let entity = partEntities[id] ?? organEntities[id] else { return }
        let box = entity.visualBounds(relativeTo: rig)
        guard !box.isEmpty else { return }
        let body = proportions.body
        var target: Float = box.center.z < -0.03 ? .pi : 0
        target += ((yaw - target) / (2 * .pi)).rounded() * 2 * .pi
        goalYaw = target
        let turned = (simd_quatf(angle: pitch, axis: SIMD3(1, 0, 0)) * simd_quatf(angle: target, axis: SIMD3(0, 1, 0))).act(box.center * body)
        goalPanX = turned.x
        goalFocusY = turned.y
        goalDistance = min(Focus.all.distance, max(1.2, max(box.extents.x, box.extents.y) * body * 1.8 + 0.5))
    }

    /// Parts over this one as focus(onPart:) shows it (a deep muscle under the back's), to hide so it shows.
    func covering(_ id: String) -> Set<String> {
        guard let scene = root.scene, let entity = partEntities[id] ?? organEntities[id] else { return [] }
        let box = entity.visualBounds(relativeTo: rig)
        guard !box.isEmpty else { return [] }
        let n = SIMD3<Float>(0, 0, box.center.z < -0.03 ? -1 : 1)
        let dir = simd_normalize(rig.convert(direction: -n, to: nil))
        var out = Set<String>()
        for dx: Float in [-0.3, 0, 0.3] {
            for dy: Float in [-0.3, 0, 0.3] {
                let p = box.center + SIMD3(dx * box.extents.x, dy * box.extents.y, 0)
                let origin = rig.convert(position: p + n * 2, to: nil)
                let depth = simd_distance(origin, rig.convert(position: p, to: nil))
                for hit in scene.raycast(origin: origin, direction: dir, length: depth, query: .all, mask: .all, relativeTo: nil) {
                    let name = hit.entity.name
                    if name == id { break }
                    if partEntities[name] != nil || organEntities[name] != nil { out.insert(name) }
                }
            }
        }
        return out
    }

    func resetView() {
        pitch = 0; goalPanX = basePanX
        faceFront()
        focus(.all)
    }

    static func material(_ color: UIColor, opacity: Float, texture: TextureResource? = nil) -> PhysicallyBasedMaterial {
        material(MaterialKey(color, opacity: opacity, texture: texture))
    }

    struct MaterialKey: Hashable {
        let color: UIColor, opacity: Float, texture: TextureResource?
        init(_ color: UIColor, opacity: Float, texture: TextureResource? = nil) { self.color = color; self.opacity = opacity; self.texture = texture }
        static func == (a: Self, b: Self) -> Bool { a.color == b.color && a.opacity == b.opacity && a.texture === b.texture }
        func hash(into h: inout Hasher) { h.combine(color); h.combine(opacity); h.combine(texture.map(ObjectIdentifier.init)) }
    }

    /// Every material setter rebuilds its shader parameters (~0.1 ms): materials are made once per look and copied.
    private static var materials: [MaterialKey: PhysicallyBasedMaterial] = [:]
    static func material(_ key: MaterialKey) -> PhysicallyBasedMaterial {
        if let hit = materials[key] { return hit }
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: key.color, texture: key.texture.map { .init($0) })
        m.roughness = .init(floatLiteral: 0.55)
        m.metallic = .init(floatLiteral: 0)
        m.faceCulling = .back
        if key.opacity < 1 { m.blending = .transparent(opacity: .init(floatLiteral: key.opacity)) }
        if materials.count > 512 { materials = [:] }
        materials[key] = m
        return m
    }

    /// a part's material as shown: faded (muscles over bones), lit when selected
    private struct PartLook: Hashable { let base: MaterialKey; let opacity: Float; let selected: Bool }
    private static var partMaterials: [PartLook: PhysicallyBasedMaterial] = [:]
    private static func partMaterial(_ look: PartLook) -> PhysicallyBasedMaterial {
        if let hit = partMaterials[look] { return hit }
        var m = material(look.base)
        if look.opacity < 1 { m.blending = .transparent(opacity: .init(floatLiteral: look.opacity)) }
        // written both ways: on iOS the copy can share the base's resource, so a plain copy keeps the glow
        m.emissiveColor = .init(color: look.selected ? UIColor(hex: "#FFD166") : .black)
        m.emissiveIntensity = look.selected ? 0.8 : 0
        if partMaterials.count > 512 { partMaterials = [:] }
        partMaterials[look] = m
        return m
    }

    /// The model's own textured material, lit like the rest of the body.
    private static func skinMaterial(_ piece: ModelLibrary.Piece) -> PhysicallyBasedMaterial {
        var m = piece.material as? PhysicallyBasedMaterial ?? material(UIColor(hex: "#F2C9A5"), opacity: 1)
        m.faceCulling = piece.id == "body" ? .back : .none
        m.metallic = .init(floatLiteral: 0)
        return m
    }

    /// Skin at this opacity; hair, brows and lashes keep their alpha texture.
    private static func faded(_ base: PhysicallyBasedMaterial, _ opacity: Float) -> PhysicallyBasedMaterial {
        var m = base
        if case let .transparent(o) = base.blending, let texture = o.texture {
            m.blending = .transparent(opacity: .init(scale: opacity, texture: texture))
        } else if opacity < 1 {
            m.blending = .transparent(opacity: .init(floatLiteral: opacity))
        }
        return m
    }

    private static func makeTappable(_ entity: ModelEntity, shape: PartShape) {
        entity.components.set(InputTargetComponent())
        if let cached = collisionCache[shape] {
            entity.components.set(CollisionComponent(shapes: [cached]))
        } else if let mesh = entity.model?.mesh {
            Task { @MainActor in
                if let collision = try? await ShapeResource.generateStaticMesh(from: mesh) {
                    collisionCache[shape] = collision
                    entity.components.set(CollisionComponent(shapes: [collision]))
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
            let e = ModelEntity(mesh: unitSphere)
            e.position = center.simd
            e.scale = (scale?.simd ?? SIMD3(repeating: 1)) * radius
            if let r = rotation { e.orientation = euler(r) }
            return e
        case let .box(center, size, rotation):
            let e = ModelEntity(mesh: .generateBox(size: size.simd))
            e.position = center.simd
            if let r = rotation { e.orientation = euler(r) }
            return e
        case let .spindle(from, to, radius):
            let e = ModelEntity(mesh: unitSphere)
            orient(e, from: from.simd, to: to.simd)
            e.scale = SIMD3(radius, simd_distance(from.simd, to.simd) / 2, radius * 0.8)
            return e
        case let .segment(from, to, _):
            let e = ModelEntity(mesh: mesh(for: shape))
            orient(e, from: from.simd, to: to.simd)
            return e
        case let .lathe(from, to, _, scale):
            let e = ModelEntity(mesh: mesh(for: shape))
            orient(e, from: from.simd, to: to.simd)
            if let scale { e.scale = scale.simd }
            return e
        case .tube, .plate, .loft, .sheet, .slab, .tubes:
            return ModelEntity(mesh: mesh(for: shape))
        }
    }

    // MARK: mesh cache — generated once per launch, shared by every screen

    private static let unitSphere = MeshResource.generateSphere(radius: 1)
    private static let reflexDot = MeshResource.generateSphere(radius: 0.035)
    private static let acuDot = MeshResource.generateSphere(radius: 0.0125)

    static func meridianShape(_ paths: [[Vec3]]) -> PartShape { .tubes(paths: paths, radius: 0.0036) }
    private static var meshCache: [PartShape: MeshResource] = [:]
    /// the skin's tap shape per figure mesh (~88k triangles): made once per look, not per build
    private static var skinShapes: [ObjectIdentifier: (mesh: MeshResource, shape: ShapeResource)] = [:]
    private static var collisionCache: [PartShape: ShapeResource] = [:]
    private static var warming: Task<Void, Never>?

    private static func mesh(for shape: PartShape) -> MeshResource {
        if let cached = meshCache[shape] { return cached }
        let mesh = Meshes.raw(for: shape)?.resource() ?? unitSphere
        meshCache[shape] = mesh
        return mesh
    }

    /// Builds every body mesh: vertex math off the main thread, resources on it in small batches.
    static func prepare() async {
        if let warming { return await warming.value }
        let task = Task { @MainActor in
            async let figure: Void = Figure.warm()
            await ModelLibrary.prepare()
            await InternalModels.prepare()
            var shapes = Catalog.body.parts.filter { !(ModelLibrary.hasSkeleton && $0.layer == .skeletal) && !InternalModels.replaces($0.id) }.map(\.shape)
            for organ in Catalog.body.organs { shapes += organ.shapes + (organ.male?.shapes ?? []) }
            for m in Catalog.points.values.flatMap({ $0.meridians ?? [] }) {
                shapes += (m.pieces + (m.femalePieces ?? [])).map(meridianShape)
            }
            let pending = Array(Set(shapes)).filter { meshCache[$0] == nil }
            let raws = await Task.detached(priority: .userInitiated) { pending.map(Meshes.raw(for:)) }.value
            for (i, (shape, raw)) in zip(pending, raws).enumerated() {
                if let raw { meshCache[shape] = raw.resource() }
                if i % 40 == 0 { await Task.yield() }
            }
            await figure
        }
        warming = task
        await task.value
    }

    /// three.js-style XYZ Euler
    private static func euler(_ r: Vec3) -> simd_quatf {
        simd_quatf(angle: r.x, axis: SIMD3(1, 0, 0)) * simd_quatf(angle: r.y, axis: SIMD3(0, 1, 0)) * simd_quatf(angle: r.z, axis: SIMD3(0, 0, 1))
    }
}
