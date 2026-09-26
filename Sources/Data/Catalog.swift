import Foundation

/// Bundled data, decoded once from Resources/Data/*.json.
enum Catalog {
    static let body: BodyData = load("body")
    static let points: [String: SystemPoints] = load("points")
    static let charts: ChartData = load("charts")
    static let systems: [BodySystem] = load("systems")

    static func system(_ id: String) -> BodySystem? { systems.first { $0.id == id } }
    static func chart(_ id: String) -> ReflexChart? { charts.charts.first { $0.id == id } }
    static func part(_ id: String) -> SchematicPart? { body.parts.first { $0.id == id } }
    static func organ(_ id: String) -> Organ? { body.organs.first { $0.id == id } }
    static func joint(_ id: String) -> Joint? { body.joints.first { $0.id == id } }

    private static func load<T: Decodable>(_ name: String) -> T {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            fatalError("missing \(name).json in the bundle")
        }
        do {
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
        } catch {
            fatalError("\(name).json: \(error)")
        }
    }
}
