import Foundation
import RealityKit

/// Z-Anatomy muscles, organs, vessels and nerves from Resources/Models (scripts/models/build_internals.py),
/// fitted to the same body coordinates as the real skeleton. Loaded once per launch.
@MainActor
enum InternalModels {
    /// false = the generated muscles, organs, vessels and nerves
    static var enabled = ModelLibrary.enabled && ProcessInfo.processInfo.environment["REAL_INTERNALS"] != "0"

    struct Part: Decodable, Sendable {
        let id: String
        let name: String
        let nameZh: String
        let layer: LayerID
        let color: String
        /// joint pivot this piece turns with, like the bones
        let joint: String?
        /// body.json organ this mesh stands in for (heart, liver…; the prostate is the male "uterus")
        let organ: String?
        let sex: String?
    }

    private struct Index: Decodable, Sendable {
        struct Internals: Decodable, Sendable {
            let files: [String: String]
            /// generated parts with no one-to-one real twin that the real set still covers (deep-*, arm-artery-2…)
            let replaces: [String]
            let parts: [Part]
        }
        let internals: Internals?
    }

    nonisolated private static let index: Index.Internals? = {
        guard let url = ModelLibrary.url(for: "models.json"), let data = try? Data(contentsOf: url) else { return nil }
        return (try? JSONDecoder().decode(Index.self, from: data))?.internals
    }()
    nonisolated private static let partsByID = Dictionary((index?.parts ?? []).map { ($0.id, $0) }) { a, _ in a }
    nonisolated private static let replaced = Set(index?.replaces ?? [])

    nonisolated static func part(_ id: String) -> Part? { partsByID[id] }
    nonisolated static var allParts: [Part] { index?.parts ?? [] }

    private static var pieces: [String: ModelLibrary.Piece] = [:]
    /// muscles re-fitted under the female skin ("<id>--female" in the file)
    private static var femalePieces: [String: ModelLibrary.Piece] = [:]
    private static var loading: Task<Void, Never>?

    static var isReady: Bool { enabled && !pieces.isEmpty }

    /// A generated part that the real models stand in for.
    static func replaces(_ id: String) -> Bool { isReady && (replaced.contains(id) || pieces[id] != nil) }

    /// Real muscles, vessels, nerves and organ-layer parts for this body (organs come through `organ`).
    static func parts(female: Bool) -> [(part: Part, piece: ModelLibrary.Piece)] {
        guard isReady else { return [] }
        return (index?.parts ?? []).compactMap { part in
            guard part.organ == nil, part.sex == nil || part.sex == (female ? "female" : "male"),
                  let piece = (female ? femalePieces[part.id] : nil) ?? pieces[part.id] else { return nil }
            return (part, piece)
        }
    }

    /// Real mesh for a body.json organ, or nil to draw the generated one (kidneys, larynx, the womb, the baby…).
    static func organ(_ id: String, female: Bool) -> (part: Part, piece: ModelLibrary.Piece, centre: SIMD3<Float>)? {
        guard isReady, let part = (index?.parts ?? []).first(where: { $0.organ == id }),
              part.sex == nil || part.sex == (female ? "female" : "male"), let piece = pieces[part.id] else { return nil }
        let c = piece.mesh.bounds.center
        let centre = piece.transform.matrix * SIMD4(c, 1)
        return (part, piece, SIMD3(centre.x, centre.y, centre.z))
    }

    static func prepare() async {
        guard enabled, let index else { return }
        if let loading { return await loading.value }
        let task = Task { @MainActor in
            for file in Set(index.files.values) {
                for piece in await ModelLibrary.pieces(file) {
                    if piece.id.hasSuffix("--female") {
                        femalePieces[String(piece.id.dropLast(8))] = piece
                    } else if partsByID[piece.id] != nil {
                        pieces[piece.id] = piece
                    }
                }
            }
        }
        loading = task
        await task.value
    }
}
