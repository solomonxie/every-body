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

        var symbol: String {
            switch self {
            case .illustration: "play.fill"
            case .system: "square.grid.2x2.fill"
            case .zone: "hand.raised.fill"
            case .point: "smallcircle.filled.circle"
            case .part: "figure.stand"
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
        "needle": ["acupuncture"], "扎针": ["针灸"], "针刺": ["针灸"], "经络": ["经"],
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
            let channels = Dictionary((sp.meridians ?? []).map { ($0.id, $0) }) { a, _ in a }
            for point in sp.points {
                if let acu = point.acu {
                    // "Quchi (LI11)" / "曲池 (LI11)"; found by code, pinyin, English and Chinese names, aliases and location
                    let channel = channels[acu.meridian]
                    out.append(SearchEntry(.point, id: "p-\(systemID)-\(point.id)",
                                           name: Bilingual("\(acu.pinyin) (\(acu.code)) · \(point.name)", "\(point.nameZh)（\(acu.code)）"),
                                           detail: Bilingual("Acupuncture · \(channel?.name ?? "")", "针灸 · \(channel?.nameZh ?? "")"),
                                           route: .viewer(system: systemID, point: point.id),
                                           extra: [acu.pinyin, point.description, point.descriptionZh, acu.uses, acu.usesZh] + (acu.aliases ?? [])))
                    continue
                }
                out.append(SearchEntry(.point, id: "p-\(systemID)-\(point.id)", name: Bilingual(point.name, point.nameZh),
                                       detail: Bilingual(point.description, point.descriptionZh),
                                       route: .viewer(system: systemID, point: point.id),
                                       extra: [point.target?.name ?? "", point.target?.nameZh ?? "", point.target?.effect ?? "", point.target?.effectZh ?? ""]))
            }
        }
        let layerSystem: [LayerID: String] = [.skin: "organs", .muscular: "muscular", .skeletal: "skeletal", .circulatory: "circulatory", .nervous: "nervous", .organs: "organs"]
        var seen = Set<String>()
        // the generated parts, then the real models' (muscles like the quadratus lumborum exist only there)
        let parts = Catalog.body.parts.map { ($0.id, $0.name, $0.nameZh, $0.layer) }
            + ModelLibrary.allParts.map { ($0.id, $0.name, $0.nameZh, $0.layer) }
            + InternalModels.allParts.filter { $0.organ == nil }.map { ($0.id, $0.name, $0.nameZh, $0.layer) }
        for (id, name, nameZh, layerID) in parts where layerID != .skin {
            // one hit per name — left/right and numbered copies are the same answer
            let key = name.replacingOccurrences(of: #" \((L|R)\)$"#, with: "", options: .regularExpression)
            guard seen.insert(key).inserted else { continue }
            let layer = Catalog.body.layers.first { $0.id == layerID }
            out.append(SearchEntry(.part, id: "b-\(id)", name: Bilingual(key, nameZh.replacingOccurrences(of: #"^[左右]"#, with: "", options: .regularExpression)),
                                   detail: layer.map { Bilingual($0.label, $0.labelZh) } ?? Bilingual("", ""),
                                   route: .viewer(system: layerSystem[layerID] ?? "organs", part: id)))
        }
        for organ in Catalog.body.organs {
            guard let names = organ.names else { continue }
            out.append(SearchEntry(.part, id: "o-\(organ.id)", name: Bilingual(names[0], names[1]), detail: Bilingual("Organ", "器官"),
                                   route: .viewer(system: "organs", part: organ.id)))
        }
        return out
    }()

    static func search(_ query: String, for profile: Profile = .standard) -> [(kind: SearchEntry.Kind, items: [SearchEntry])] {
        let scored = rank(entries, query, for: profile)
        return SearchEntry.Kind.allCases.compactMap { kind in
            let items = scored.filter { $0.kind == kind }
            return items.isEmpty ? nil : (kind, Array(items.prefix(kind == .part ? 12 : 20)))
        }
    }

    /// The entries that match, best first.
    static func rank(_ entries: [SearchEntry], _ query: String, for profile: Profile = .standard) -> [SearchEntry] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        let terms = q.split(separator: " ").map(String.init)
        // each term (or the whole query) may stand for several words
        func alternatives(_ t: String) -> [String] { [t] + (synonyms[t] ?? []) + synonyms.filter { t.count > 1 && $0.key.contains(t) }.flatMap(\.value) }
        let groups = synonyms[q] != nil ? [alternatives(q)] : terms.map(alternatives)
        var scored: [(SearchEntry, Int)] = []
        for e in entries {
            if case let .illustration(id) = e.route, !Illustrations.shown(id, for: profile) { continue }
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
        return scored.sorted { $0.1 > $1.1 }.map(\.0)
    }
}

/// Results under the home page's search field.
struct SearchResults: View {
    let query: String
    @Environment(Settings.self) private var settings

    var body: some View {
        let sections = SearchIndex.search(query, for: settings.profile)
        VStack(alignment: .leading, spacing: Space.xl) {
            if sections.isEmpty {
                NoMatches(query: query)
            }
            ForEach(sections, id: \.kind) { section in
                VStack(alignment: .leading, spacing: Space.s) {
                    Eyebrow("\(settings.t(section.kind.title)) · \(section.items.count)").padding(.horizontal, Space.xs)
                    VStack(spacing: 0) {
                        ForEach(Array(section.items.enumerated()), id: \.element.id) { i, item in
                            if i > 0 { Divider().padding(.leading, Space.l + 30 + Space.m) }
                            NavigationLink(value: item.route) { SearchRow(entry: item) }
                                .buttonStyle(RowButtonStyle())
                                .simultaneousGesture(TapGesture().onEnded { settings.remember(search: query) })
                        }
                    }
                    .background(Color.card, in: .rect(cornerRadius: Radius.card, style: .continuous))
                    .clipShape(.rect(cornerRadius: Radius.card, style: .continuous))
                }
            }
        }
    }
}

struct SearchRow: View {
    let entry: SearchEntry
    var chevron = true
    @Environment(Settings.self) private var settings

    private var tint: Color {
        switch entry.route {
        case let .illustration(id): Illustrations.find(id)?.group.color ?? .brandFill
        case .chart: Color(hex: "#D9853B")
        default:
            switch entry.kind {
            case .system: .brandFill
            case .point: Color(hex: "#3E8E7E")
            default: Color(hex: "#4A7BD0")
            }
        }
    }

    var body: some View {
        HStack(spacing: Space.m) {
            IconBadge(symbol: entry.kind.symbol, color: tint)
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(settings.t(entry.name)).foregroundStyle(.primary).lineLimit(2)
                let detail = settings.t(entry.detail)
                if !detail.isEmpty {
                    Text(detail).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: Space.s)
            if chevron {
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.m)
        .frame(minHeight: minTap)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

private struct NoMatches: View {
    let query: String
    @Environment(Settings.self) private var settings

    var body: some View {
        VStack(spacing: Space.s) {
            Image(systemName: "magnifyingglass").font(.system(size: 40, weight: .light)).foregroundStyle(.tertiary)
                .padding(.bottom, Space.xs)
            Text(settings.t("No matches for “\(query)”", "没有找到“\(query)”")).font(.headline)
                .multilineTextAlignment(.center)
            Text(settings.t("Try a body part, a symptom, or a procedure like “CPR”.", "试试身体部位、症状，或“心肺复苏”等操作名称。"))
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xxl)
        .accessibilityElement(children: .combine)
    }
}

/// Focused, nothing typed: recent and suggested searches.
struct SearchSuggestions: View {
    @Binding var query: String
    @Environment(Settings.self) private var settings

    private static let suggested: [Bilingual] = [
        Bilingual("CPR", "心肺复苏"), Bilingual("Choking", "海姆立克"), Bilingual("Stroke", "中风"), Bilingual("Burn", "烧伤"),
        Bilingual("Femur", "股骨"), Bilingual("Heart", "心脏"), Bilingual("Blood pressure", "血压"), Bilingual("Hegu", "合谷"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            if !settings.recentSearches.isEmpty {
                VStack(alignment: .leading, spacing: Space.s) {
                    HStack {
                        Eyebrow(settings.t("Recent", "最近搜索"))
                        Spacer()
                        Button(settings.t("Clear", "清除")) { settings.clearRecentSearches() }
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: minTap)
                    }
                    .padding(.horizontal, Space.xs)
                    VStack(spacing: 0) {
                        ForEach(Array(settings.recentSearches.enumerated()), id: \.element) { i, recent in
                            if i > 0 { Divider().padding(.leading, Space.l + 24 + Space.m) }
                            Button { query = recent } label: {
                                HStack(spacing: Space.m) {
                                    Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary).frame(width: 24)
                                    Text(recent).foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "arrow.up.left").font(.footnote).foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, Space.l)
                                .frame(minHeight: minTap + 4)
                                .contentShape(.rect)
                            }
                            .buttonStyle(RowButtonStyle())
                        }
                    }
                    .background(Color.card, in: .rect(cornerRadius: Radius.card, style: .continuous))
                    .clipShape(.rect(cornerRadius: Radius.card, style: .continuous))
                }
            }
            VStack(alignment: .leading, spacing: Space.s) {
                Eyebrow(settings.t("Try searching", "试试搜索")).padding(.horizontal, Space.xs)
                FlowLayout(spacing: Space.s) {
                    ForEach(Self.suggested, id: \.en) { s in
                        Pill(label: settings.t(s), symbol: "magnifyingglass") { query = settings.t(s) }
                    }
                }
            }
        }
    }
}

/// everybody://search — the same results on their own page.
struct SearchScreen: View {
    @State private var query = ""
    @Environment(Settings.self) private var settings

    var body: some View {
        ScrollView {
            Group {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    SearchSuggestions(query: $query)
                } else {
                    SearchResults(query: query)
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.vertical, Space.s)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Color.page)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: settings.t("Body parts, illnesses, procedures", "身体部位、疾病、操作"))
        .onSubmit(of: .search) { settings.remember(search: query) }
        .navigationTitle(settings.t("Search", "搜索"))
        .navigationBarTitleDisplayMode(.inline)
        .profileToolbar()
    }
}
