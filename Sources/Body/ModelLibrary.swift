import Foundation
import RealityKit

/// Real anatomy models from Resources/Models: the Z-Anatomy skeleton and MakeHuman skin figures,
/// already fitted to body coordinates by scripts/models/build_models.py. Loaded once per launch.
@MainActor
enum ModelLibrary {
    /// false = the generated skeleton and skin everywhere
    static var enabled = ProcessInfo.processInfo.environment["REAL_MODELS"] != "0"

    struct Part: Decodable, Sendable {
        let id: String
        let name: String
        let nameZh: String
        let layer: LayerID
        let color: String
        /// joint pivot this bone turns with (shoulder-l, elbow-l, knee-l…)
        let joint: String?
    }

    struct Piece {
        let id: String
        let mesh: MeshResource
        let transform: Transform
        let material: RealityKit.Material?
    }

    private struct Index: Decodable, Sendable {
        struct Skeleton: Decodable, Sendable { let file: String; let parts: [Part] }
        struct Skin: Decodable, Sendable { let file: String }
        let skeleton: Skeleton?
        let skins: [String: Skin]?
    }

    nonisolated private static let index: Index? = {
        guard let url = url(for: "models.json"), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Index.self, from: data)
    }()
    nonisolated private static let partsByID = Dictionary((index?.skeleton?.parts ?? []).map { ($0.id, $0) }) { a, _ in a }

    nonisolated static func part(_ id: String) -> Part? { partsByID[id] }

    private(set) static var bones: [Piece] = []
    private static var skins: [String: [Piece]] = [:]
    private static var collisions: [String: ShapeResource] = [:]
    private static var loading: Task<Void, Never>?

    /// Skin figure for this body, or nil to use the generated one (children, or not built).
    static func skin(female: Bool, pregnant: Bool, age: AgeGroup) -> [Piece]? {
        guard enabled, age == .adult || age == .senior else { return nil }
        return skins[female ? (pregnant ? "female-pregnant" : "female") : "male"]
    }

    static var hasSkeleton: Bool { enabled && !bones.isEmpty }

    static func prepare() async {
        guard enabled, let index else { return }
        if let loading { return await loading.value }
        let task = Task { @MainActor in
            if let file = index.skeleton?.file {
                bones = await pieces(file).filter { partsByID[$0.id] != nil }
            }
            for (variant, skin) in index.skins ?? [:] {
                skins[variant] = await pieces(skin.file)
            }
        }
        loading = task
        await task.value
    }

    /// Mesh collision for a bone, generated once and shared.
    static func collision(for piece: Piece) async -> ShapeResource? {
        if let cached = collisions[piece.id] { return cached }
        let shape = try? await ShapeResource.generateStaticMesh(from: piece.mesh)
        collisions[piece.id] = shape
        return shape
    }

    static func pieces(_ file: String) async -> [Piece] {
        guard let url = url(for: file), let root = try? await Entity(contentsOf: url) else { return [] }
        var out: [Piece] = []
        func walk(_ e: Entity) {
            if let model = e.components[ModelComponent.self] {
                // USD prim names can't hold "-": femur_l → femur-l
                out.append(Piece(id: e.name.replacingOccurrences(of: "_", with: "-"), mesh: model.mesh,
                                 transform: Transform(matrix: e.transformMatrix(relativeTo: nil)), material: model.materials.first))
            }
            e.children.forEach(walk)
        }
        walk(root)
        return out
    }

    nonisolated static func url(for file: String) -> URL? {
        // BODY_ATLAS_MODELS lets the Mac render tool read the repo's folder
        if let dir = ProcessInfo.processInfo.environment["BODY_ATLAS_MODELS"] {
            let url = URL(fileURLWithPath: dir).appendingPathComponent(file)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        let name = (file as NSString).deletingPathExtension, ext = (file as NSString).pathExtension
        return Bundle.main.url(forResource: name, withExtension: ext)
    }
}
