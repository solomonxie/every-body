import SwiftUI

struct SearchEntry: Identifiable {
    enum Kind: Int, CaseIterable {
        case illustration, system, zone, point, part

        var title: Bilingual {
            switch self {
            case .system: Bilingual("Systems", "系统")
            case .illustration: Bilingual("Illustrations & procedures", "图解与操作")
            case .zone: Bilingual("Reflex chart zones", "反射区")
            case .point: Bilingual("Points", "穴位")
            case .part: Bilingual("Body parts", "身体部位")
            }
        }
    }

    let id: String
    let kind: Kind
    let name: Bilingual
    let detail: Bilingual
    let route: Route
    let names: String
    let text: String

    init(_ kind: Kind, id: String, name: Bilingual, detail: Bilingual, route: Route, extra: [String] = []) {
        self.kind = kind
        self.id = id
        self.name = name
        self.detail = detail
        self.route = route
        names = "\(name.en) \(name.zh)".lowercased()
        text = ([name.en, name.zh, detail.en, detail.zh] + extra).joined(separator: " ").lowercased()
    }
}

/// One in-memory index over everything. Ranked: name hits over text hits; every term must match somewhere.
@MainActor
enum SearchIndex {
    /// everyday words → the words the content actually uses
    private static let synonyms: [String: [String]] = [
        "broken": ["fracture"], "骨折": ["fracture"], "断": ["fracture", "骨折"],
        "heimlich": ["choking"], "海姆立克": ["choking"], "噎": ["choking"], "卡": ["choking"],
        "resuscitation": ["cpr"], "心肺复苏": ["cpr"], "cardiac arrest": ["cpr"], "心脏骤停": ["cpr"], "aed": ["cpr"],
        "bleed": ["bleeding"], "blood loss": ["bleeding"], "cut": ["bleeding"], "wound": ["bleeding"], "伤口": ["bleeding"], "出血": ["bleeding"],
        "scald": ["burn"], "烫": ["burn"], "烧伤": ["burn"],
        "sprain": ["ankle"], "扭": ["ankle", "sprain"], "崴": ["ankle"],
        "dislocation": ["shoulder"], "脱臼": ["shoulder", "dislocat"], "错位": ["shoulder", "dislocat"], "接骨": ["fracture", "shoulder"],
        "diabetes": ["blood sugar", "glucose"], "糖尿病": ["血糖"], "insulin": ["blood sugar"],
        "hypertension": ["blood pressure"], "高血压": ["血压"], "cholesterol": ["blood fats", "ldl"], "高血脂": ["血脂"], "三高": ["血压", "血糖", "血脂"],
        "heart attack": ["heart attack"], "心梗": ["心肌梗死"], "chest pain": ["heart attack"], "胸痛": ["心肌梗死"],
        "fast": ["stroke"], "中风": ["脑卒中"], "脑梗": ["脑卒中"],
        "cold": ["cold", "flu"], "感冒": ["感冒"], "fever": ["flu"], "发烧": ["流感"], "cough": ["cold", "asthma"], "咳嗽": ["感冒", "哮喘"],
        "heartburn": ["reflux"], "烧心": ["反流"], "胃酸": ["反流"],
        "pregnant": ["pregnancy", "fetal"], "baby": ["fetal", "labor"], "birth": ["labor"], "分娩": ["分娩"], "生孩子": ["分娩"], "怀孕": ["孕"],
        "massage": ["reflex", "point"], "按摩": ["反射", "穴"], "acupressure": ["point"], "穴位": ["穴"], "虎口": ["合谷"],
        "bone": ["skeletal"], "骨头": ["骨"], "muscle": ["muscular"], "肌肉": ["肌"], "blood": ["circulatory"], "nerve": ["nervous"],
    ]

    static let entries: [SearchEntry] = {
        var out: [SearchEntry] = []
        for s in Catalog.systems {
            out.append(SearchEntry(.system, id: "s-\(s.id)", name: Bilingual(s.name, s.nameZh), detail: Bilingual("Body system", "人体系统"),
                                   route: .viewer(system: s.id), extra: s.info.map { [$0.summary, $0.summaryZh] } ?? []))
        }
        for s in Illustrations.all {
            out.append(SearchEntry(.illustration, id: "i-\(s.id)", name: s.title, detail: s.group.title,
                                   route: .illustration(id: s.id), extra: s.keywords + s.steps.flatMap { [$0.caption.en, $0.caption.zh] }))
        }
        for chart in Catalog.charts.charts {
            for face in chart.faces {
                for zone in face.zones {
                    let side = zone.side.map { $0 == .left ? Bilingual(" · left", " · 左") : Bilingual(" · right", " · 右") } ?? Bilingual("", "")
                    out.append(SearchEntry(.zone, id: "z-\(chart.id)-\(face.id)-\(zone.id)", name: Bilingual(zone.name, zone.nameZh),
                                           detail: Bilingual("\(chart.title) · \(face.label)\(side.en)", "\(chart.titleZh) · \(face.labelZh)\(side.zh)"),
                                           route: .chart(id: chart.id, face: face.id, zone: zone.id, side: zone.side ?? .right),
                                           extra: [zone.effect, zone.effectZh]))
                }
            }
        }
        for (systemID, sp) in Catalog.points {
            for point in sp.points {
                out.append(SearchEntry(.point, id: "p-\(systemID)-\(point.id)", name: Bilingual(point.name, point.nameZh),
                                       detail: Bilingual(point.description, point.descriptionZh),
                                       route: .viewer(system: systemID, point: point.id),
                                       extra: [point.target?.name ?? "", point.target?.nameZh ?? "", point.target?.effect ?? "", point.target?.effectZh ?? ""]))
            }
        }
        let layerSystem: [LayerID: String] = [.skin: "organs", .muscular: "muscular", .skeletal: "skeletal", .circulatory: "circulatory", .nervous: "nervous", .organs: "organs"]
        var seen = Set<String>()
        for part in Catalog.body.parts where part.layer != .skin {
            // one hit per name — left/right and numbered copies are the same answer
            let key = part.name.replacingOccurrences(of: #" \((L|R)\)$"#, with: "", options: .regularExpression)
            guard seen.insert(key).inserted else { continue }
            let layer = Catalog.body.layers.first { $0.id == part.layer }
            out.append(SearchEntry(.part, id: "b-\(part.id)", name: Bilingual(key, part.nameZh.replacingOccurrences(of: #"^[左右]"#, with: "", options: .regularExpression)),
                                   detail: layer.map { Bilingual($0.label, $0.labelZh) } ?? Bilingual("", ""),
                                   route: .viewer(system: layerSystem[part.layer] ?? "organs", part: part.id)))
        }
        for organ in Catalog.body.organs {
            guard let names = organ.names else { continue }
            out.append(SearchEntry(.part, id: "o-\(organ.id)", name: Bilingual(names[0], names[1]), detail: Bilingual("Organ", "器官"),
                                   route: .viewer(system: "organs", part: organ.id)))
        }
        return out
    }()

    static func search(_ query: String) -> [(kind: SearchEntry.Kind, items: [SearchEntry])] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        let terms = q.split(separator: " ").map(String.init)
        // each term (or the whole query) may stand for several words
        func alternatives(_ t: String) -> [String] { [t] + (synonyms[t] ?? []) + synonyms.filter { t.count > 1 && $0.key.contains(t) }.flatMap(\.value) }
        let groups = synonyms[q] != nil ? [alternatives(q)] : terms.map(alternatives)
        var scored: [(SearchEntry, Int)] = []
        for e in entries {
            var score = 0
            var all = true
            for alts in groups {
                if alts.contains(where: { e.names.hasPrefix($0) }) { score += 6 }
                else if alts.contains(where: { e.names.contains($0) }) { score += 4 }
                else if alts.contains(where: { e.text.contains($0) }) { score += 1 }
                else { all = false; break }
            }
            if all { scored.append((e, score)) }
        }
        return SearchEntry.Kind.allCases.compactMap { kind in
            let items = scored.filter { $0.0.kind == kind }.sorted { $0.1 > $1.1 }.map(\.0)
            return items.isEmpty ? nil : (kind, Array(items.prefix(kind == .part ? 12 : 20)))
        }
    }
}

/// Results under the home page's search field.
struct SearchResults: View {
    let query: String
    @Environment(Settings.self) private var settings

    var body: some View {
        let sections = SearchIndex.search(query)
        VStack(alignment: .leading, spacing: 16) {
            if sections.isEmpty {
                Text(settings.t("No matches for “\(query)”. Try a body part, a symptom, or a procedure like “CPR”.",
                                "没有找到“\(query)”。试试身体部位、症状，或“心肺复苏”等操作名称。"))
                    .foregroundStyle(.secondary)
            }
            ForEach(sections, id: \.kind) { section in
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(settings.t(section.kind.title)) · \(section.items.count)")
                        .font(.footnote.weight(.semibold)).foregroundStyle(.secondary).padding(.bottom, 4)
                    ForEach(section.items) { item in
                        NavigationLink(value: item.route) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(settings.t(item.name)).foregroundStyle(.primary).lineLimit(1)
                                    Text(settings.t(item.detail)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 8)
                        }
                        Divider()
                    }
                }
            }
        }
    }
}

/// bodyatlas://search — the same results on their own page.
struct SearchScreen: View {
    @State private var query = ""
    @Environment(Settings.self) private var settings

    var body: some View {
        ScrollView {
            SearchResults(query: query).padding(16)
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: settings.t("Body parts, illnesses, procedures", "身体部位、疾病、操作"))
        .navigationTitle(settings.t("Search", "搜索"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
