import Foundation

/// Every pushable screen.
enum Route: Hashable {
    case viewer(system: String, point: String? = nil, part: String? = nil)
    case chart(id: String, face: String? = nil, zone: String? = nil, side: Side? = nil)
    case illustration(id: String)
    case info(system: String)
    case search

    /// "/reflex/foot", "/illustration/stroke" — links stored in systems.json
    init?(path: String) {
        let parts = path.split(separator: "/").map(String.init)
        if parts == ["search"] { self = .search; return }
        guard parts.count == 2 else { return nil }
        switch parts[0] {
        case "reflex": self = .chart(id: parts[1])
        case "illustration": self = .illustration(id: parts[1])
        case "viewer": self = .viewer(system: parts[1])
        case "info": self = .info(system: parts[1])
        default: return nil
        }
    }
}
