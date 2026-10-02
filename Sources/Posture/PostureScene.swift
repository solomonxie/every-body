import Foundation
import RealityKit
import simd
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// A posed figure on a chair, blending between two posture keys: see-through skin over the skeleton,
/// the discs coloured by their load and the back muscles by their strain.
@MainActor
final class PostureScene {
    enum View: CaseIterable { case side, back, front, spine }

    let root = Entity()
    let rig = Entity()
    /// the posed scene, offset so the rig turns about the figure's middle
    private let stage = Entity()
    /// transparent pieces draw in a fixed order: back muscles, disc halos, the glass skin, then hair
    private let sortGroup = ModelSortGroup()
    let camera = PerspectiveCamera()
    var subscription: EventSubscription?

    var yaw: Float = 0
    var pitch: Float = 0
    var distance: Float = 4.6
    var focusY: Float = 0
    var panX: Float = 0
    var goalYaw: Float?
    var goalDistance: Float = 4.6
    var goalFocusY: Float = 0
    var goalPanX: Float = 0
    var goalPitch: Float?
    /// 0 = first key, 1 = second (eased toward goalBlend)
    private(set) var blend: Float = 0
    var goalBlend: Float = 0
    /// see-through skin over the bones, or a solid figure
    var seeThrough = true { didSet { if oldValue != seeThrough { applyLook() } } }
    static let glassOpacity: Float = 0.2

    private var model: PostureModel?
    private var meshes: [DeformMesh] = []
    private var skin: [(entity: ModelEntity, base: PhysicallyBasedMaterial)] = []
    private var headPieces: [ModelEntity] = []
    private var hair: HairMesh?
    private var body: DeformMesh?
    private var garments: [GarmentMesh] = []
    private var transforms: [String: [simd_float4x4]] = [:]
    /// forward lean of the neck per key (degrees), for the neck load
    private(set) var neck: [Float] = []
    private var bones: [(entity: ModelEntity, bone: String, rest: simd_float4x4)] = []
    private var discs: [(entity: ModelEntity, level: Int)] = []
    private var muscles: [ModelEntity] = []
    private var dimmed: [(entity: ModelEntity, base: PhysicallyBasedMaterial)] = []
    private var halos: [ModelEntity] = []
    private var shown: Float = -1
    private var clock: Float = 0
    private var load: Float = 1
    private var strain: Float = 0
    /// load of each key (relative disc pressure, standing = 1), for the disc colour
    var loads: [Float] = [1.4, 1.85]

    init() {
        root.addChild(rig)
        rig.addChild(stage)
        root.addChild(camera)
        camera.camera.fieldOfViewInDegrees = 36
        let sun = DirectionalLight()
        sun.light.intensity = 2800
        sun.look(at: .zero, from: SIMD3(3, 4, 5), relativeTo: nil)
        root.addChild(sun)
        let fill = DirectionalLight()
        fill.light.intensity = 1300
        fill.look(at: .zero, from: SIMD3(-4, 1.5, 3), relativeTo: nil)
        root.addChild(fill)
        let rim = DirectionalLight()
        rim.light.intensity = 1700
        rim.look(at: .zero, from: SIMD3(1.5, 3, -5), relativeTo: nil)
        root.addChild(rim)
    }

    // MARK: build

    func build(topic: String, female: Bool, pregnant: Bool = false, heritage: Heritage, underwear: Bool = true,
               chest: BodySize = .small, hips: BodySize = .medium) {
        stage.children.removeAll()
        meshes = []; skin = []; headPieces = []; hair = nil; garments = []; body = nil; bones = []; discs = []; muscles = []; dimmed = []; halos = []
        shown = -1
        guard let model = (modelCache?.topic == topic ? modelCache?.data : nil) ?? PostureModel.load(topic) else { return }
        modelCache = (topic, model)
        self.model = model
        let sex = female ? (pregnant ? "pregnant" : "female") : "male"
        guard let figure = model.figures[sex] ?? model.figures["male"] else { return }
        transforms = figure.transforms ?? model.transforms
        neck = figure.neck ?? model.neck
        let look = Figure.Look(female: female, age: .adult, pregnant: pregnant && female, heritage: heritage, underwear: false, chest: chest, hips: hips)
        let pieces = Figure.pieces(look) ?? []

        // skin: base heritage per key, plus this heritage's head turned with the head
        var keys = figure.keys
        if let delta = figure.heritage[heritage.rawValue] {
            for k in keys.indices {
                let m = transforms["head"]?[k] ?? matrix_identity_float4x4
                let r = simd_float3x3(SIMD3(m.columns.0.x, m.columns.0.y, m.columns.0.z), SIMD3(m.columns.1.x, m.columns.1.y, m.columns.1.z),
                                      SIMD3(m.columns.2.x, m.columns.2.y, m.columns.2.z))
                for v in keys[k].indices where delta[v] != .zero { keys[k][v] += r * delta[v] }
            }
        }
        // chest and hips options (the bump keeps the default lower body)
        if female {
            for shape in ["chest-\(chest.rawValue)"] + (pregnant ? [] : ["hips-\(hips.rawValue)"]) {
                guard let deltas = figure.shapes[shape] else { continue }
                for k in keys.indices { for v in keys[k].indices { keys[k][v] += deltas[k][v] } }
            }
        }
        if let body = DeformMesh(keys: keys, vmap: model.vmap, uv: model.uv, index: model.index) {
            let entity = ModelEntity(mesh: body.resource)
            entity.name = "skin"
            var m = pieces.first { $0.id == "body" }?.material as? PhysicallyBasedMaterial ?? BodyScene.material(UIColor(hex: "#F2C9A5"), opacity: 1)
            m.faceCulling = .back
            // a matte skin: the key light grazes the tops of the shoulders
            m.roughness = .init(floatLiteral: 0.7)
            m.specular = .init(floatLiteral: 0.22)
            meshes.append(body)
            self.body = body
            skin.append((entity, m))
            stage.addChild(entity)
        }
        for piece in pieces where ["eyes", "brows", "lashes", "hair"].contains(piece.id) {
            // hair that falls to the shoulders follows the upper back, not the skull
            let deform = piece.id == "hair" ? HairMesh(piece.mesh) : nil
            let entity = ModelEntity(mesh: deform?.resource ?? piece.mesh)
            entity.name = "skin:\(piece.id)"
            var m = piece.material as? PhysicallyBasedMaterial ?? BodyScene.material(.white, opacity: 1)
            if piece.id != "hair" { m.faceCulling = .none }
            skin.append((entity, m))
            if let deform { hair = deform } else { headPieces.append(entity) }
            stage.addChild(entity)
        }
        if underwear {
            for g in figure.garments {
                guard let mesh = GarmentMesh(g) else { continue }
                let entity = ModelEntity(mesh: mesh.resource)
                var m = PhysicallyBasedMaterial()
                m.baseColor = .init(tint: UIColor(hex: g.color), texture: Self.texture("fabric.png").map { .init($0) })
                m.roughness = .init(floatLiteral: 0.9)
                m.metallic = .init(floatLiteral: 0)
                m.sheen = .init(tint: UIColor(white: 0.35, alpha: 1))
                garments.append(mesh)
                skin.append((entity, m))
                stage.addChild(entity)
            }
        }

        // bones: each moves with its rig bone; the spine and pelvis in full, the rest a little quieter
        for piece in ModelLibrary.bones {
            guard let bone = model.rigid[piece.id], let part = ModelLibrary.part(piece.id) else { continue }
            let entity = ModelEntity(mesh: piece.mesh)
            entity.name = piece.id
            let focus = Self.focusBone(piece.id)
            let m = BodyScene.material(UIColor(hex: part.color), opacity: 1, texture: Textures.bone)
            entity.model?.materials = [m]
            if !focus { dimmed.append((entity, m)) }
            bones.append((entity, bone, piece.transform.matrix))
            stage.addChild(entity)
        }
        for piece in figure.soft ?? model.soft {
            guard let mesh = DeformMesh(keys: piece.keys, vmap: nil, uv: [], index: piece.index) else { continue }
            let entity = ModelEntity(mesh: mesh.resource)
            entity.name = piece.id
            meshes.append(mesh)
            stage.addChild(entity)
            if piece.id.hasPrefix("disc-") {
                let level = Self.lumbar.firstIndex(of: String(piece.id.dropFirst(5))) ?? -1
                discs.append((entity, level))
                if level >= 0 {
                    let halo = ModelEntity(mesh: .generateSphere(radius: 1))
                    halo.components.set(ModelSortGroupComponent(group: sortGroup, order: 2))
                    halos.append(halo)
                    stage.addChild(halo)
                }
            } else {
                entity.components.set(ModelSortGroupComponent(group: sortGroup, order: 1))
                muscles.append(entity)
            }
        }
        addChair(model.chair)
        applyLook()
        apply(blend)
    }

    private var modelCache: (topic: String, data: PostureModel)?

    private static let lumbar = ["L1", "L2", "L3", "L4", "L5"]

    private static func focusBone(_ id: String) -> Bool {
        id.hasPrefix("vertebra-") || ["sacrum", "coccyx"].contains(id)
    }

    private func applyLook() {
        let opacity: Float = seeThrough ? Self.glassOpacity : 1
        for (entity, base) in skin {
            var m = base
            if case let .transparent(o) = base.blending, let texture = o.texture {
                m.blending = .transparent(opacity: .init(scale: seeThrough ? 0.3 : 1, texture: texture))
            } else if opacity < 1 {
                m.blending = .transparent(opacity: .init(floatLiteral: opacity))
            }
            // glass never hides what's inside it
            m.writesDepth = !seeThrough
            entity.model?.materials = [m]
            entity.components.set(ModelSortGroupComponent(group: sortGroup, order: entity.name == "skin:hair" ? 4 : 3))
        }
        // the limbs, ribs and skull a paler grey so the spine and pelvis read first
        for (entity, base) in dimmed {
            var m = base
            m.baseColor = .init(tint: UIColor(hex: "#E4E6EA"), texture: base.baseColor.texture)
            m.blending = .transparent(opacity: .init(floatLiteral: 0.38))
            m.writesDepth = false
            entity.model?.materials = [m]
            entity.components.set(ModelSortGroupComponent(group: sortGroup, order: 0))
        }
        let inner = seeThrough
        for bone in bones { bone.entity.isEnabled = inner }
        for (entity, _) in discs { entity.isEnabled = inner }
        for halo in halos { halo.isEnabled = inner }
        for entity in muscles { entity.isEnabled = inner }
        shown = -1
    }

    // MARK: chair and floor

    private func addChair(_ c: PostureModel.Chair) {
        var cushion = PhysicallyBasedMaterial()
        cushion.baseColor = .init(tint: UIColor(hex: "#3C4250"))
        cushion.roughness = .init(floatLiteral: 0.85)
        cushion.metallic = .init(floatLiteral: 0)
        var metal = PhysicallyBasedMaterial()
        metal.baseColor = .init(tint: UIColor(hex: "#9AA1AC"))
        metal.roughness = .init(floatLiteral: 0.35)
        metal.metallic = .init(floatLiteral: 0.8)
        // a mesh back: see-through, so the spine behind it still shows
        var mesh = cushion
        mesh.baseColor = .init(tint: UIColor(hex: "#2A2F3A"))
        mesh.blending = .transparent(opacity: .init(floatLiteral: 0.4))
        mesh.faceCulling = .none
        mesh.writesDepth = false

        let chair = Entity()
        chair.name = "chair"
        let floor: Float = -1.6
        let depth = c.seatFront - c.seatBack
        let mid = (c.seatFront + c.seatBack) / 2
        let seat = ModelEntity(mesh: .generateBox(width: c.seatWidth, height: 0.1, depth: depth, cornerRadius: 0.045), materials: [cushion])
        seat.position = SIMD3(0, c.seatY - 0.05, mid)
        chair.addChild(seat)

        let tilt = c.backTilt * .pi / 180
        let up = SIMD3<Float>(0, cos(tilt), -sin(tilt)), normal = SIMD3<Float>(0, sin(tilt), cos(tilt))
        let origin = SIMD3<Float>(0, c.backY, c.backZ)
        let back = ModelEntity(mesh: .generateBox(width: c.backWidth, height: c.backHeight, depth: 0.05, cornerRadius: 0.025), materials: [mesh])
        back.position = origin + up * (c.backHeight / 2) - normal * 0.025
        back.orientation = simd_quatf(angle: -tilt, axis: SIMD3(1, 0, 0))
        back.components.set(ModelSortGroupComponent(group: sortGroup, order: 0))
        chair.addChild(back)
        // the back's frame: a rim round the mesh, carried by one bar from under the seat's rear
        for (w, h, dy, dx) in [(c.backWidth, Float(0.035), c.backHeight, Float(0)), (c.backWidth, 0.035, 0, 0),
                               (0.035, c.backHeight, c.backHeight / 2, c.backWidth / 2), (0.035, c.backHeight, c.backHeight / 2, -c.backWidth / 2)] {
            let bar = ModelEntity(mesh: .generateBox(width: w, height: h, depth: 0.04, cornerRadius: 0.012), materials: [metal])
            bar.position = origin + up * dy - normal * 0.03 + SIMD3(dx, 0, 0)
            bar.orientation = back.orientation
            chair.addChild(bar)
        }
        let low = SIMD3<Float>(0, c.seatY - 0.1, c.seatBack + 0.08)
        let high = origin + up * 0.1 - normal * 0.045
        let rise = SIMD3<Float>(0, c.seatY - 0.02, c.seatBack - 0.04)
        for (a, b) in [(low, rise), (rise, high)] {
            let bar = ModelEntity(mesh: .generateBox(width: 0.11, height: simd_distance(a, b) + 0.04, depth: 0.03, cornerRadius: 0.012), materials: [metal])
            bar.position = (a + b) / 2
            bar.orientation = simd_quatf(from: SIMD3(0, 1, 0), to: simd_normalize(b - a))
            chair.addChild(bar)
        }
        let postTop = c.seatY - 0.1
        let post = ModelEntity(mesh: .generateCylinder(height: postTop - (floor + 0.12), radius: 0.035), materials: [metal])
        post.position = SIMD3(0, (postTop + floor + 0.12) / 2, mid)
        chair.addChild(post)
        for i in 0..<5 {
            let a = Float(i) / 5 * 2 * .pi + .pi / 10
            let leg = ModelEntity(mesh: .generateBox(width: 0.05, height: 0.04, depth: 0.55, cornerRadius: 0.015), materials: [metal])
            leg.orientation = simd_quatf(angle: a, axis: SIMD3(0, 1, 0))
            leg.position = SIMD3(0, floor + 0.11, mid) + leg.orientation.act(SIMD3(0, 0, 0.26))
            chair.addChild(leg)
            let wheel = ModelEntity(mesh: .generateSphere(radius: 0.045), materials: [cushion])
            wheel.position = SIMD3(0, floor + 0.045, mid) + leg.orientation.act(SIMD3(0, 0, 0.5))
            chair.addChild(wheel)
        }
        stage.addChild(chair)
        stage.position = -SIMD3(0, -0.45, mid + 0.25)

        // a soft shadow on the floor under the figure and the chair
        if let shade = Self.shadowTexture {
            var m = UnlitMaterial()
            m.color = .init(tint: .black, texture: .init(shade))
            m.blending = .transparent(opacity: .init(floatLiteral: 0.3))
            let plane = ModelEntity(mesh: .generatePlane(width: 1.9, depth: 2.3), materials: [m])
            plane.position = SIMD3(0, floor + 0.002, mid + 0.25)
            stage.addChild(plane)
        }
    }

    private static let shadowTexture: TextureResource? = {
        let n = 128
        var px = [UInt8](repeating: 0, count: n * n * 4)
        for y in 0..<n { for x in 0..<n {
            let dx = (Float(x) + 0.5) / Float(n) * 2 - 1, dy = (Float(y) + 0.5) / Float(n) * 2 - 1
            let r = min(1, (dx * dx + dy * dy).squareRoot())
            let a = UInt8(255 * pow(1 - r, 1.6))
            px[4 * (y * n + x)] = 255; px[4 * (y * n + x) + 1] = 255; px[4 * (y * n + x) + 2] = 255; px[4 * (y * n + x) + 3] = a
        } }
        guard let provider = CGDataProvider(data: Data(px) as CFData),
              let image = CGImage(width: n, height: n, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4 * n,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return nil }
        return try? TextureResource(image: image, options: .init(semantic: .color))
    }()

    private static func texture(_ file: String) -> TextureResource? {
        guard let url = ModelLibrary.url(for: file) else { return nil }
        return try? TextureResource.load(contentsOf: url, withName: file, options: .init(semantic: .color))
    }

    // MARK: blend

    private func apply(_ t: Float) {
        guard let model else { return }
        let (a, b, w) = model.span(t)
        for mesh in meshes { mesh.set(a, b, w) }
        if let body { for g in garments { g.set(on: body) } }
        func lerp(_ ms: [simd_float4x4]) -> simd_float4x4 {
            guard ms.count > b else { return matrix_identity_float4x4 }
            return ms[a] * (1 - w) + ms[b] * w
        }
        let head = Transform(matrix: lerp(transforms["head"] ?? []))
        for e in headPieces { e.transform = head }
        hair?.set(head: lerp(transforms["head"] ?? []), chest: lerp(transforms["T1"] ?? []))
        for (entity, bone, rest) in bones {
            entity.transform = Transform(matrix: lerp(transforms[bone] ?? []) * rest)
        }
        load = loads.count > 1 ? loads[0] + (loads[1] - loads[0]) * t : 1
        strain = t
        paintLoad()
        shown = t
    }

    /// discs from calm to hot with the load, glowing and throbbing past sitting tall; back muscles from slack to hot as they stretch
    private func paintLoad() {
        let heat = PostureColors.load(load)
        let glow = min(max((load - 1.3) / 0.55, 0), 1)
        let beat = glow * (0.5 + 0.5 * sin(clock * 2 * .pi * 1.1))
        let lumbar = discs.filter { $0.level >= 0 }
        for (entity, level) in discs {
            var m = BodyScene.material(level >= 0 ? heat : UIColor(hex: "#B9C8D8"), opacity: 1)
            if level >= 0 {
                m.emissiveColor = .init(color: heat)
                m.emissiveIntensity = 0.3 + 1.4 * glow + 0.6 * beat
            }
            entity.model?.materials = [m]
        }
        for (halo, disc) in zip(halos, lumbar) {
            let box = disc.entity.visualBounds(relativeTo: stage)
            halo.position = box.center
            let swell = 0.6 + 0.2 * glow + 0.06 * beat
            halo.scale = SIMD3(box.extents.x * swell, box.extents.y * (0.7 + 0.5 * glow), box.extents.z * swell)
            var m = UnlitMaterial(color: heat)
            m.blending = .transparent(opacity: .init(floatLiteral: 0.1 + 0.4 * glow + 0.12 * beat))
            m.writesDepth = false
            halo.model?.materials = [m]
        }
        let s = strain
        for entity in muscles {
            var m = BodyScene.material(PostureColors.mix(UIColor(hex: "#A98683"), UIColor(hex: "#FF3B1F"), s), opacity: 0.3 + 0.5 * s, texture: Textures.muscle)
            m.emissiveColor = .init(color: UIColor(hex: "#FF3B1F"))
            m.emissiveIntensity = 1.1 * s + 0.35 * s * beat
            entity.model?.materials = [m]
        }
    }

    // MARK: camera

    func show(_ view: View) {
        let target: Float = switch view {
        case .side: .pi / 2 + 0.3
        case .spine: .pi / 2 + 0.12
        case .back: .pi - 0.55
        case .front: 0.6
        }
        goalYaw = target + ((yaw - target) / (2 * .pi)).rounded() * 2 * .pi
        goalPitch = view == .back ? 0.12 : 0.06
        goalDistance = view == .spine ? 2.3 : view == .side ? 4.4 : 4.6
        goalFocusY = 0
        goalPanX = 0
        if view == .spine, let model {
            // the lumbar spine in the middle, between the two keys
            let p = (model.focus.first! + model.focus.last!) / 2 + stage.position
            let turned = (simd_quatf(angle: goalPitch!, axis: SIMD3(1, 0, 0)) * simd_quatf(angle: target, axis: SIMD3(0, 1, 0))).act(p)
            goalPanX = turned.x
            goalFocusY = turned.y + 0.1
        }
    }

    func update(dt: Float) {
        clock += dt
        let k = 1 - exp(-6 * dt)
        if let goal = goalYaw {
            yaw += (goal - yaw) * k
            if abs(goal - yaw) < 0.001 { goalYaw = nil }
        }
        if let goal = goalPitch {
            pitch += (goal - pitch) * k
            if abs(goal - pitch) < 0.001 { goalPitch = nil }
        }
        distance += (goalDistance - distance) * k
        focusY += (goalFocusY - focusY) * k
        panX += (goalPanX - panX) * k
        let bk = 1 - exp(-8 * dt)
        blend += (goalBlend - blend) * bk
        if abs(goalBlend - blend) < 0.0005 { blend = goalBlend }
        if abs(blend - shown) > 0.0001 { apply(blend) }
        else if load > 1.3, seeThrough, Int(clock * 30) != Int((clock - dt) * 30) { paintLoad() }
        rig.orientation = simd_quatf(angle: pitch, axis: SIMD3(1, 0, 0)) * simd_quatf(angle: yaw, axis: SIMD3(0, 1, 0))
        camera.look(at: SIMD3(panX, focusY, 0), from: SIMD3(panX, focusY, distance), relativeTo: nil)
    }

    /// jump straight to the goals (first frame, renders)
    func settle() {
        if let g = goalYaw { yaw = g; goalYaw = nil }
        if let g = goalPitch { pitch = g; goalPitch = nil }
        distance = goalDistance; focusY = goalFocusY; panX = goalPanX; blend = goalBlend
        apply(blend)
        update(dt: 0)
    }
}

/// A mesh whose vertices blend between keys (positions and smooth normals per key).
@MainActor
final class DeformMesh {
    let mesh: LowLevelMesh
    let resource: MeshResource
    private let keys: [[SIMD3<Float>]]
    private let normals: [[SIMD3<Float>]]
    private let vmap: [UInt32]?
    private let uv: [SIMD2<Float>]
    private let count: Int
    private let indexCount: Int
    /// the blended positions and normals per position vertex (garments are built on them)
    private(set) var positions: [SIMD3<Float>] = []
    private(set) var currentNormals: [SIMD3<Float>] = []

    init?(keys: [[SIMD3<Float>]], vmap: [UInt32]?, uv: [SIMD2<Float>], index: [UInt32]) {
        guard let first = keys.first, !first.isEmpty else { return nil }
        count = vmap?.count ?? first.count
        indexCount = index.count
        self.keys = keys
        self.vmap = vmap
        self.uv = uv
        // smooth normals per position vertex (shared across uv seams)
        normals = keys.map { p in
            var n = [SIMD3<Float>](repeating: .zero, count: p.count)
            for t in stride(from: 0, to: index.count, by: 3) {
                let a = Int(vmap.map { $0[Int(index[t])] } ?? index[t]), b = Int(vmap.map { $0[Int(index[t + 1])] } ?? index[t + 1]),
                    c = Int(vmap.map { $0[Int(index[t + 2])] } ?? index[t + 2])
                let f = simd_cross(p[b] - p[a], p[c] - p[a])
                n[a] += f; n[b] += f; n[c] += f
            }
            return n.map { simd_length($0) > 0 ? simd_normalize($0) : SIMD3(0, 1, 0) }
        }
        var d = LowLevelMesh.Descriptor()
        d.vertexAttributes = [.init(semantic: .position, format: .float3, offset: 0),
                              .init(semantic: .normal, format: .float3, offset: 12),
                              .init(semantic: .uv0, format: .float2, offset: 24)]
        d.vertexLayouts = [.init(bufferIndex: 0, bufferStride: 32)]
        d.vertexCapacity = count
        d.indexCapacity = index.count
        d.indexType = .uint32
        guard let mesh = try? LowLevelMesh(descriptor: d) else { return nil }
        self.mesh = mesh
        mesh.withUnsafeMutableIndices { raw in
            let out = raw.bindMemory(to: UInt32.self)
            for i in index.indices { out[i] = index[i] }
        }
        mesh.parts.replaceAll([LowLevelMesh.Part(indexCount: index.count, topology: .triangle, bounds: Self.bounds(first))])
        guard let resource = try? MeshResource(from: mesh) else { return nil }
        self.resource = resource
        write(0, 0, 0)
    }

    private static func bounds(_ p: [SIMD3<Float>]) -> BoundingBox {
        var lo = p[0], hi = p[0]
        for q in p { lo = simd_min(lo, q); hi = simd_max(hi, q) }
        return BoundingBox(min: lo - 0.05, max: hi + 0.05)
    }

    func set(_ a: Int, _ b: Int, _ w: Float) {
        write(a, b, w)
    }

    private func write(_ a: Int, _ b: Int, _ w: Float) {
        let pa = keys[a], pb = keys[b], na = normals[a], nb = normals[b]
        positions = zip(pa, pb).map { $0 + ($1 - $0) * w }
        currentNormals = zip(na, nb).map { let n = $0 + ($1 - $0) * w; return simd_length(n) > 0 ? simd_normalize(n) : SIMD3(0, 1, 0) }
        let vmap = vmap, uv = uv, count = count
        var lo = SIMD3<Float>(repeating: .infinity), hi = SIMD3<Float>(repeating: -.infinity)
        mesh.withUnsafeMutableBytes(bufferIndex: 0) { raw in
            let f = raw.bindMemory(to: Float.self)
            for r in 0..<count {
                let v = vmap.map { Int($0[r]) } ?? r
                let p = pa[v] + (pb[v] - pa[v]) * w
                var n = na[v] + (nb[v] - na[v]) * w
                let len = simd_length(n)
                n = len > 0 ? n / len : SIMD3(0, 1, 0)
                lo = simd_min(lo, p); hi = simd_max(hi, p)
                let o = r * 8
                f[o] = p.x; f[o + 1] = p.y; f[o + 2] = p.z
                f[o + 3] = n.x; f[o + 4] = n.y; f[o + 5] = n.z
                let t = r < uv.count ? uv[r] : .zero
                f[o + 6] = t.x; f[o + 7] = t.y
            }
        }
        mesh.parts.replaceAll([LowLevelMesh.Part(indexCount: indexCount, topology: .triangle, bounds: BoundingBox(min: lo, max: hi))])
    }
}

/// Hair cards blended between the skull (above the ears) and the upper back (where long hair lies on the shoulders).
@MainActor
final class HairMesh {
    let mesh: LowLevelMesh
    let resource: MeshResource
    private let p: [SIMD3<Float>], n: [SIMD3<Float>], t: [SIMD3<Float>], uv: [SIMD2<Float>]
    private let w: [Float]
    private let indexCount: Int

    init?(_ source: MeshResource) {
        guard let part = source.contents.models.first?.parts.first, let index = part.triangleIndices?.elements else { return nil }
        p = part.positions.elements
        n = part.normals?.elements ?? Array(repeating: SIMD3(0, 1, 0), count: p.count)
        t = part.tangents?.elements ?? Array(repeating: SIMD3(0, -1, 0), count: p.count)
        uv = part.textureCoordinates?.elements ?? Array(repeating: .zero, count: p.count)
        // skull above y 1.3, back and shoulders below 1.16 (scene units, rest pose)
        w = p.map { q in
            let k = min(max((1.3 - q.y) / 0.14, 0), 1)
            return k * k * (3 - 2 * k)
        }
        indexCount = index.count
        var d = LowLevelMesh.Descriptor()
        d.vertexAttributes = [.init(semantic: .position, format: .float3, offset: 0), .init(semantic: .normal, format: .float3, offset: 12),
                              .init(semantic: .tangent, format: .float3, offset: 24), .init(semantic: .uv0, format: .float2, offset: 36)]
        d.vertexLayouts = [.init(bufferIndex: 0, bufferStride: 44)]
        d.vertexCapacity = p.count
        d.indexCapacity = index.count
        d.indexType = .uint32
        guard let mesh = try? LowLevelMesh(descriptor: d) else { return nil }
        self.mesh = mesh
        mesh.withUnsafeMutableIndices { raw in
            let out = raw.bindMemory(to: UInt32.self)
            for i in index.indices { out[i] = index[i] }
        }
        guard let resource = try? MeshResource(from: mesh) else { return nil }
        self.resource = resource
        set(head: matrix_identity_float4x4, chest: matrix_identity_float4x4)
    }

    func set(head: simd_float4x4, chest: simd_float4x4) {
        let p = p, n = n, t = t, uv = uv, w = w
        var lo = SIMD3<Float>(repeating: .infinity), hi = SIMD3<Float>(repeating: -.infinity)
        mesh.withUnsafeMutableBytes(bufferIndex: 0) { raw in
            let f = raw.bindMemory(to: Float.self)
            for i in p.indices {
                let m = head * (1 - w[i]) + chest * w[i]
                let q4 = m * SIMD4(p[i], 1), q = SIMD3(q4.x, q4.y, q4.z)
                let n4 = m * SIMD4(n[i], 0), t4 = m * SIMD4(t[i], 0)
                let nn = simd_normalize(SIMD3(n4.x, n4.y, n4.z)), tt = simd_normalize(SIMD3(t4.x, t4.y, t4.z))
                lo = simd_min(lo, q); hi = simd_max(hi, q)
                let o = i * 11
                f[o] = q.x; f[o + 1] = q.y; f[o + 2] = q.z
                f[o + 3] = nn.x; f[o + 4] = nn.y; f[o + 5] = nn.z
                f[o + 6] = tt.x; f[o + 7] = tt.y; f[o + 8] = tt.z
                f[o + 9] = uv[i].x; f[o + 10] = uv[i].y
            }
        }
        mesh.parts.replaceAll([LowLevelMesh.Part(indexCount: indexCount, topology: .triangle, bounds: BoundingBox(min: lo, max: hi))])
    }
}

/// Underwear rebuilt on the posed body each time it moves (Figure.garment's construction).
@MainActor
final class GarmentMesh {
    let mesh: LowLevelMesh
    let resource: MeshResource
    private let g: PostureModel.Garment

    init?(_ g: PostureModel.Garment) {
        self.g = g
        var d = LowLevelMesh.Descriptor()
        d.vertexAttributes = [.init(semantic: .position, format: .float3, offset: 0), .init(semantic: .normal, format: .float3, offset: 12),
                              .init(semantic: .uv0, format: .float2, offset: 24)]
        d.vertexLayouts = [.init(bufferIndex: 0, bufferStride: 32)]
        d.vertexCapacity = g.f.count
        d.indexCapacity = g.index.count
        d.indexType = .uint32
        guard let mesh = try? LowLevelMesh(descriptor: d) else { return nil }
        self.mesh = mesh
        mesh.withUnsafeMutableIndices { raw in
            let out = raw.bindMemory(to: UInt32.self)
            for i in g.index.indices { out[i] = g.index[i] }
        }
        guard let resource = try? MeshResource(from: mesh) else { return nil }
        self.resource = resource
    }

    func set(on body: DeformMesh) {
        let p = body.positions, n = body.currentNormals, g = g
        guard !p.isEmpty else { return }
        var lo = SIMD3<Float>(repeating: .infinity), hi = SIMD3<Float>(repeating: -.infinity)
        var qs = [SIMD3<Float>](), ns = [SIMD3<Float>]()
        qs.reserveCapacity(g.f.count); ns.reserveCapacity(g.f.count)
        for v in g.f.indices {
            let a = Int(g.abc[3 * v]), b = Int(g.abc[3 * v + 1]), c = Int(g.abc[3 * v + 2])
            let wa = g.w[v].x, wb = g.w[v].y, wc = max(0, 1 - wa - wb)
            let nn = simd_normalize(wa * n[a] + wb * n[b] + wc * n[c])
            let edge = min(g.f[v] / 0.01, 1)
            let move = g.offset.isEmpty ? .zero : Figure.frameOffset(g.offset, v, p[a], p[b], p[c], side: nn)
            let q = wa * p[a] + wb * p[b] + wc * p[c] + (move == .zero ? nn * g.lift * (0.8 + 0.2 * edge) : move)
            lo = simd_min(lo, q); hi = simd_max(hi, q)
            qs.append(q); ns.append(nn)
        }
        if !g.offset.isEmpty { ns = Figure.surfaceNormals(qs, g.index, fallback: ns, offset: g.offset) }
        mesh.withUnsafeMutableBytes(bufferIndex: 0) { raw in
            let f = raw.bindMemory(to: Float.self)
            for v in g.f.indices {
                let q = qs[v], nn = ns[v], o = v * 8
                f[o] = q.x; f[o + 1] = q.y; f[o + 2] = q.z
                f[o + 3] = nn.x; f[o + 4] = nn.y; f[o + 5] = nn.z
                f[o + 6] = min(g.f[v] / 0.025, 0.97); f[o + 7] = 0.5
            }
        }
        mesh.parts.replaceAll([LowLevelMesh.Part(indexCount: g.index.count, topology: .triangle, bounds: BoundingBox(min: lo, max: hi))])
    }
}
