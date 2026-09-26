import SwiftUI

/// Label for a schematic part or organ.
func partLabel(_ id: String, female: Bool) -> (name: Bilingual, layer: Bilingual)? {
    if let part = Catalog.part(id) {
        let layer = Catalog.body.layers.first { $0.id == part.layer }
        return (Bilingual(part.name, part.nameZh), layer.map { Bilingual($0.label, $0.labelZh) } ?? Bilingual("", ""))
    }
    guard let names = Catalog.organ(id)?.names else { return nil }
    let organs = Bilingual("Organs", "器官")
    if id == "uterus" { return (female ? Bilingual("Uterus", "子宫") : Bilingual("Prostate", "前列腺"), organs) }
    return (Bilingual(names[0], names[1]), organs)
}

/// Every chart zone said to act on an organ.
func zonesForOrgan(_ id: String) -> [(label: Bilingual, route: Route)] {
    let chartName = ["hand": Bilingual("Hand", "手"), "foot": Bilingual("Foot", "足"), "ear": Bilingual("Ear", "耳")]
    return Catalog.charts.charts.flatMap { chart in
        chart.faces.flatMap { face in
            face.zones.filter { $0.organIds.contains(id) }.map { zone in
                let c = chartName[chart.id] ?? Bilingual(chart.title, chart.titleZh)
                return (Bilingual("\(c.en): \(zone.name)", "\(c.zh)·\(zone.nameZh)"),
                        Route.chart(id: chart.id, face: face.id, zone: zone.id, side: zone.side ?? .right))
            }
        }
    }
}

struct PartCard: View {
    let partID: String
    let parts: PartState
    let female: Bool
    let onChange: (PartState) -> Void
    let onClose: () -> Void
    @Environment(Settings.self) private var settings

    var body: some View {
        if let label = partLabel(partID, female: female) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading) {
                        Text(settings.t(label.name)).font(.subheadline.weight(.semibold))
                        Text(settings.t(label.layer)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(settings.t("Hide", "隐藏")) {
                        var p = parts; p.hidden.insert(partID); onChange(p); onClose()
                    }
                    Button(parts.faded.contains(partID) ? settings.t("Unfade", "取消淡化") : settings.t("Fade", "淡化")) {
                        var p = parts
                        if p.faded.contains(partID) { p.faded.remove(partID) } else { p.faded.insert(partID) }
                        onChange(p)
                    }
                    Button(parts.isolated == partID ? settings.t("Show all", "显示全部") : settings.t("Isolate", "单独显示")) {
                        var p = parts; p.isolated = p.isolated == partID ? nil : partID; onChange(p)
                    }
                    Button { onClose() } label: { Image(systemName: "xmark") }
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderless)
                let zones = zonesForOrgan(partID)
                if !zones.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            Text(settings.t("Reflex zones:", "反射区：")).font(.caption).foregroundStyle(.secondary)
                            ForEach(zones, id: \.label.en) { zone in
                                NavigationLink(value: zone.route) { Text("\(settings.t(zone.label)) ›").font(.caption) }
                            }
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(uiColor: .systemBackground), in: .rect(cornerRadius: 14))
            .padding(.horizontal, 16)
        }
    }
}

struct JointControl: View {
    let joint: Joint
    let angle: Float
    let onChange: (Float) -> Void
    @Environment(Settings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("\(settings.t("Try", "试一试")) ▸ \(settings.name(joint.name, joint.nameZh))").font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int(angle))°").font(.subheadline.weight(.semibold))
            }
            Slider(value: Binding(get: { Double(angle) }, set: { onChange(Float($0)) }), in: 0...Double(joint.maxDeg))
            let movers = joint.movers.compactMap(Catalog.part).map { settings.name($0.name, $0.nameZh) }
            Text(settings.t("Working muscle: \(movers.joined(separator: ", ")) · range 0–\(Int(joint.maxDeg))°",
                            "工作肌肉：\(movers.joined(separator: "、")) · 活动范围 0–\(Int(joint.maxDeg))°"))
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
    }
}

struct ReflexPanel: View {
    let points: [BodyPoint]
    @Binding var filter: String
    let activeID: String?
    let effectVisible: Bool
    let onPress: (String) -> Void
    let onFocus: (Focus) -> Void
    @Environment(Settings.self) private var settings

    private let filters: [(id: String, label: Bilingual, focus: Focus)] = [
        ("all", Bilingual("All", "全部"), .all), ("foot", Bilingual("Foot", "足"), .foot), ("hand", Bilingual("Hand", "手"), .hand),
        ("ear", Bilingual("Ear", "耳"), .ear), ("body", Bilingual("Body", "身体"), .all),
    ]

    var body: some View {
        let visible = filter == "all" ? points : points.filter { $0.region == filter }
        let active = points.first { $0.id == activeID }
        VStack(alignment: .leading, spacing: 8) {
            PillRow {
                ForEach(filters, id: \.id) { f in
                    Pill(label: settings.t(f.label), selected: filter == f.id) { filter = f.id; onFocus(f.focus) }
                }
            }
            PillRow {
                ForEach(visible) { p in
                    Pill(label: (Cautions.avoid(p.id, for: settings.profile) ? "⚠ " : "") + settings.name(p.name, p.nameZh), selected: p.id == activeID) { onPress(p.id) }
                }
            }
            if ["foot", "hand", "ear"].contains(filter) {
                NavigationLink(value: Route.chart(id: filter)) {
                    Text(settings.t("Open \(filter) chart ›", "打开\(filters.first { $0.id == filter }!.label.zh)部图 ›")).font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 16)
            }
            if let p = active {
                VStack(alignment: .leading, spacing: 4) {
                    Text(settings.name(p.name, p.nameZh)).font(.subheadline.weight(.semibold))
                    Text(settings.name(p.description, p.descriptionZh)).font(.caption).foregroundStyle(.secondary)
                    CautionList(warnings: Cautions.warnings(p.id, for: settings.profile))
                    if let t = p.target {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("→ \(settings.name(t.name, t.nameZh))").font(.subheadline.weight(.semibold))
                            Text(settings.name(t.effect, t.effectZh)).font(.caption)
                            HStack {
                                Text(settings.t("Traditional reflexology claim — not medical advice.", "传统反射疗法说法，非医疗建议。")).font(.caption2).foregroundStyle(.secondary)
                                Spacer()
                                Button(settings.t("↻ Replay", "↻ 重播")) { onPress(p.id) }.font(.caption.weight(.semibold))
                            }
                        }
                        .opacity(effectVisible ? 1 : 0)
                    }
                }
                .padding(12)
                .background(Color(uiColor: .systemBackground), in: .rect(cornerRadius: 14))
                .padding(.horizontal, 16)
            } else {
                Text(settings.t("Press a point — watch where it acts. Tap a dot on the body or a name above.", "按一个穴位，看它作用在哪里。点身体上的圆点或上方名称。"))
                    .font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 16)
            }
        }
    }
}

struct FlowPanel: View {
    let stops: [BodyPoint]
    @Binding var bpm: Float
    let activeID: String?
    let onStop: (String) -> Void
    @Environment(Settings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(settings.t("Heart rate", "心率")).font(.subheadline.weight(.semibold))
                Spacer()
                Text(settings.t("\(Int(bpm)) bpm", "\(Int(bpm)) 次/分")).font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 16)
            Slider(value: Binding(get: { Double(bpm) }, set: { bpm = Float($0) }), in: 40...180).padding(.horizontal, 16)
            PillRow {
                ForEach(Array(stops.enumerated()), id: \.element.id) { i, stop in
                    Pill(label: "\(i + 1). \(settings.name(stop.name, stop.nameZh))", selected: stop.id == activeID) { onStop(stop.id) }
                }
            }
            Group {
                if let stop = stops.first(where: { $0.id == activeID }) {
                    VStack(alignment: .leading) {
                        Text(settings.name(stop.name, stop.nameZh)).font(.subheadline.weight(.semibold))
                        Text(settings.name(stop.description, stop.descriptionZh)).font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text(settings.t("Red = oxygen-rich, blue = oxygen-poor. Drag the heart rate and watch the flow follow.", "红色为富氧血，蓝色为缺氧血。拖动心率，观察血流变化。"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

/// Person-type warnings for a point or zone.
struct CautionList: View {
    let warnings: [Bilingual]
    @Environment(Settings.self) private var settings

    var body: some View {
        ForEach(warnings, id: \.en) { w in
            Label(settings.t(w), systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(hex: "#B5462E"))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "#FBE3DC"), in: .rect(cornerRadius: 8))
        }
    }
}
