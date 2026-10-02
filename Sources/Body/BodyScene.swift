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
    var faded: Set<String> = []
    var isolated: String?

    func visible(_ id: String) -> Bool { !hidden.contains(id) && (isolated == nil || isolated == id) }
    var changedCount: Int { hidden.count + faded.count + (isolated == nil ? 0 : 1) }
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
    private var baseMaterials: [String: PhysicallyBasedMaterial] = [:]
    private var skinEntities: [(entity: ModelEntity, material: PhysicallyBasedMaterial)] = []
    /// the real (MakeHuman) skin is one mesh: it can't bend, so it steps aside while a joint is bent
    private var realSkin = false
    /// acupuncture: points and channels show through underwear (and the generated skin's hair); the real hair hides
    private var seeThrough = false
    /// the real skin: points (every age) and children's channels are dropped onto it
    private var surface: Figure.Surface?
    private var bentJoints: Set<String> = []
    private var organEntities: [String: Entity] = [:]
    /// each organ piece's own opacity (the see-through womb), back when it's no longer faded
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
        bentJoints = []

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
        surface = realSkin == nil ? nil : Figure.surface(look)
        self.realSkin = realSkin != nil
        seeThrough = !meridians.isEmpty
        for piece in realSkin ?? [] {
            let entity = ModelEntity(mesh: piece.mesh)
            entity.transform = piece.transform
            entity.name = "skin:\(piece.id)"
            skinEntities.append((entity, Self.skinMaterial(piece)))
            rig.addChild(entity)
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
            baseMaterials[part.id] = Self.material(UIColor(hex: part.color), opacity: 1)
            entity.model?.materials = [baseMaterials[part.id]!]
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
            baseMaterials[part.id] = Self.material(UIColor(hex: part.color), opacity: 1, texture: texture)
            entity.model?.materials = [baseMaterials[part.id]!]
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
            baseMaterials[part.id] = Self.material(UIColor(hex: part.color), opacity: 1, texture: Textures.for(part.layer))
            entity.model?.materials = [baseMaterials[part.id]!]
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

    func setJoint(_ id: String, degrees: Float) {
        guard let joint = Catalog.joint(id), let outer = jointOuter[id] else { return }
        outer.orientation = simd_quatf(angle: degrees * .pi / 180, axis: simd_normalize(joint.axis.simd))
        let wasBent = !bentJoints.isEmpty
        if abs(degrees) > 0.5 { bentJoints.insert(id) } else { bentJoints.remove(id) }
        if realSkin && wasBent != !bentJoints.isEmpty { applyVisibility() }
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
    }

    /// The named entity under a view point (a ray from the camera), or nil.
    func pick(at p: CGPoint, in size: CGSize) -> String? {
        guard let scene = root.scene, size.width > 0, size.height > 0 else { return nil }
        let t = tan(camera.camera.fieldOfViewInDegrees * .pi / 360), aspect = Float(size.width / size.height)
        let d = SIMD4(Float(2 * p.x / size.width - 1) * t * aspect, Float(1 - 2 * p.y / size.height) * t, -1, 0)
        let m = camera.transformMatrix(relativeTo: nil)
        let origin = SIMD3(m.columns.3.x, m.columns.3.y, m.columns.3.z)
        let w = m * d
        let dir = simd_normalize(SIMD3(w.x, w.y, w.z))
        return scene.raycast(origin: origin, direction: dir, length: 50, query: .nearest, mask: .all, relativeTo: nil).first?.entity.name
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

    private func applyVisibility() {
        let inner = layers.contains { $0 != .skin }
        // skin alone is solid; over inner layers it's a faint glass
        let skinOpacity: Float = layers.contains(.skin) ? (inner ? Self.glassOpacity : 1) : 0
        for (skin, base) in skinEntities {
            // the real figure's hair steps aside for points and channels: its scalp is already tinted the hair's colour
            let hidden = seeThrough && realSkin && skin.name == "skin:hair"
            skin.isEnabled = skinOpacity > 0 && !(realSkin && !bentJoints.isEmpty) && !hidden
            let hair = seeThrough && (skin.name == "skin:hair" || skin.name.hasPrefix("skin:underwear"))
            skin.model?.materials = [Self.faded(base, hair ? min(skinOpacity, 0.35) : skinOpacity)]
        }
        let muscleOpacity: Float = layers.contains(.skeletal) ? 0.55 : 1
        for (id, entity) in partEntities {
            guard let layer = partLayer[id] else { continue }
            // deep muscle cores fill gaps in a muscle-only view but would hide the bones
            let deep = id.hasPrefix("deep-") && layers.contains(.skeletal)
            entity.isEnabled = layers.contains(layer) && parts.visible(id) && !deep && !hiddenForAge.contains(id)
            let faded = parts.faded.contains(id)
            var m = faded ? Self.ghost(baseMaterials[id]!) : baseMaterials[id]!
            if !faded && layer == .muscular && muscleOpacity < 1 { m.blending = .transparent(opacity: .init(floatLiteral: muscleOpacity)) }
            if id == selected { m.emissiveColor = .init(color: UIColor(hex: "#FFD166")); m.emissiveIntensity = faded ? 0.25 : 0.8 }
            entity.model?.materials = [m]
        }
        for (id, entity) in organEntities where Catalog.organ(id)?.region != true {
            // the brain is an organ but belongs in the nervous system view too
            entity.isEnabled = (layers.contains(.organs) || (id == "brain" && layers.contains(.nervous))) && parts.visible(id)
            let faded = parts.faded.contains(id)
            for case let piece as ModelEntity in entity.children {
                guard let own = organOpacity[ObjectIdentifier(piece)], var m = piece.model?.materials.first as? PhysicallyBasedMaterial else { continue }
                let opacity = faded ? min(own, Self.ghostOpacity) : own
                m.blending = opacity < 1 ? .transparent(opacity: .init(floatLiteral: opacity)) : .opaque
                piece.model?.materials = [m]
            }
        }
    }

    static let ghostOpacity: Float = 0.3

    /// A faded part: a pale see-through ghost of itself, unlike the solid parts behind it.
    private static func ghost(_ base: PhysicallyBasedMaterial) -> PhysicallyBasedMaterial {
        var m = base
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        base.baseColor.tint.getRed(&r, green: &g, blue: &b, alpha: &a)
        m.baseColor.tint = UIColor(red: (r + 2) / 3, green: (g + 2) / 3, blue: (b + 2) / 3, alpha: 1)
        m.blending = .transparent(opacity: .init(floatLiteral: ghostOpacity))
        return m
    }

    /// Every tappable part and organ in this body.
    var partIDs: [String] {
        Array(partEntities.keys) + organEntities.keys.filter { Catalog.organ($0)?.names != nil && Catalog.organ($0)?.region != true }
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

    /// Parts over this one as focus(onPart:) shows it (a deep muscle under the back's), to fade so it shows through.
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
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: color, texture: texture.map { .init($0) })
        m.roughness = .init(floatLiteral: 0.55)
        m.metallic = .init(floatLiteral: 0)
        m.faceCulling = .back
        if opacity < 1 { m.blending = .transparent(opacity: .init(floatLiteral: opacity)) }
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
        }
        warming = task
        await task.value
    }

    /// three.js-style XYZ Euler
    private static func euler(_ r: Vec3) -> simd_quatf {
        simd_quatf(angle: r.x, axis: SIMD3(1, 0, 0)) * simd_quatf(angle: r.y, axis: SIMD3(0, 1, 0)) * simd_quatf(angle: r.z, axis: SIMD3(0, 0, 1))
    }
}
