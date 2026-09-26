import SwiftUI

struct SearchEntry: Identifiable {
    enum Kind: Int, CaseIterable {
        case system, illustration, zone, point, part

        var title: String {
            switch self {
            case .system: "SYSTEMS 系统"
            case .illustration: "ILLUSTRATIONS 图解"
            case .zone: "REFLEX CHART ZONES 反射区"
            case .point: "POINTS 穴位"
            case .part: "BODY PARTS 部位"
            }
        }
    }

    let id: String
    let kind: Kind
    let name: String
    let nameZh: String
    let detail: String
    let route: Route
    let text: String

    init(_ kind: Kind, id: String, name: String, nameZh: String, detail: String, route: Route, extra: [String] = []) {
        self.kind = kind
        self.id = id
        self.name = name
        self.nameZh = nameZh
        self.detail = detail
        self.route = route
        text = ([name, nameZh, detail] + extra).joined(separator: " ").lowercased()
    }
}

/// One in-memory index over everything; every term must match (EN or 中文).
@MainActor
enum SearchIndex {
    static let entries: [SearchEntry] = {
        var out: [SearchEntry] = []
        for s in Catalog.systems {
            out.append(SearchEntry(.system, id: "s-\(s.id)", name: s.name, nameZh: "", detail: "System", route: .viewer(system: s.id)))
        }
        for s in Illustrations.all {
            out.append(SearchEntry(.illustration, id: "i-\(s.id)", name: s.title.en, nameZh: s.title.zh, detail: "\(s.steps.count) steps",
                                   route: .illustration(id: s.id), extra: s.steps.flatMap { [$0.caption.en, $0.caption.zh] }))
        }
        for chart in Catalog.charts.charts {
            for face in chart.faces {
                for zone in face.zones {
                    let sideLabel = zone.side.map { $0 == .left ? " · 左" : " · 右" } ?? ""
                    out.append(SearchEntry(.zone, id: "z-\(chart.id)-\(face.id)-\(zone.id)", name: zone.name, nameZh: zone.nameZh,
                                           detail: "\(chart.titleZh) · \(face.labelZh)\(sideLabel)",
                                           route: .chart(id: chart.id, face: face.id, zone: zone.id, side: zone.side ?? .right),
                                           extra: [zone.effect, zone.effectZh]))
                }
            }
        }
        for (systemID, sp) in Catalog.points {
            for point in sp.points {
                out.append(SearchEntry(.point, id: "p-\(systemID)-\(point.id)", name: point.name, nameZh: point.nameZh, detail: point.description,
                                       route: .viewer(system: systemID, point: point.id), extra: [point.target?.name ?? "", point.target?.nameZh ?? ""]))
            }
        }
        let layerSystem: [LayerID: String] = [.skin: "organs", .muscular: "muscular", .skeletal: "skeletal", .circulatory: "circulatory", .nervous: "nervous", .organs: "organs"]
        for part in Catalog.body.parts {
            out.append(SearchEntry(.part, id: "b-\(part.id)", name: part.name, nameZh: part.nameZh, detail: part.layer.rawValue,
                                   route: .viewer(system: layerSystem[part.layer] ?? "organs", part: part.id)))
        }
        for organ in Catalog.body.organs {
            guard let names = organ.names else { continue }
            out.append(SearchEntry(.part, id: "o-\(organ.id)", name: names[0], nameZh: names[1], detail: "organ", route: .viewer(system: "organs", part: organ.id)))
        }
        return out
    }()

    static func search(_ query: String) -> [(kind: SearchEntry.Kind, items: [SearchEntry])] {
        let terms = query.lowercased().split(separator: " ").map(String.init)
        guard !terms.isEmpty else { return [] }
        let hits = entries.filter { e in terms.allSatisfy { e.text.contains($0) } }
        func nameHit(_ e: SearchEntry) -> Bool { terms.contains { "\(e.name) \(e.nameZh)".lowercased().contains($0) } }
        return SearchEntry.Kind.allCases.compactMap { kind in
            let items = hits.filter { $0.kind == kind }.sorted { nameHit($0) && !nameHit($1) }
            return items.isEmpty ? nil : (kind, Array(items.prefix(30)))
        }
    }
}

struct SearchScreen: View {
    @State private var query = ""
    @Environment(Settings.self) private var settings
    private let suggestions = ["肾", "heart", "合谷", "femur", "血压", "CPR", "耳", "stroke"]

    var body: some View {
        List {
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                Section("Try 试试") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack { ForEach(suggestions, id: \.self) { s in Pill(label: s) { query = s } } }
                    }
                }
            } else {
                let sections = SearchIndex.search(query)
                if sections.isEmpty {
                    Text("No matches for “\(query)”. Try the English or Chinese name. 试试中文或英文名称。").foregroundStyle(.secondary)
                }
                ForEach(sections, id: \.kind) { section in
                    Section("\(section.kind.title) · \(section.items.count)") {
                        ForEach(section.items) { item in
                            NavigationLink(value: item.route) {
                                VStack(alignment: .leading) {
                                    Text(item.nameZh.isEmpty ? item.name : "\(item.nameZh) · \(item.name)").lineLimit(1)
                                    Text(item.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search parts, points, zones, topics 搜索")
        .navigationTitle("Search 搜索")
        .navigationBarTitleDisplayMode(.inline)
    }
}
