import SwiftUI

/// Label for a schematic part or organ.
func partLabel(_ id: String, female: Bool) -> (name: Bilingual, layer: Bilingual)? {
    if let part = Catalog.part(id) {
        let layer = Catalog.body.layers.first { $0.id == part.layer }
        return (Bilingual(part.name, part.nameZh), layer.map { Bilingual($0.label, $0.labelZh) } ?? Bilingual("", ""))
    }
    if let part = ModelLibrary.part(id) {
        let layer = Catalog.body.layers.first { $0.id == part.layer }
        return (Bilingual(part.name, part.nameZh), layer.map { Bilingual($0.label, $0.labelZh) } ?? Bilingual("", ""))
    }
    if let part = InternalModels.part(id), part.organ == nil {
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
            let faded = parts.faded.contains(partID)
            let isolated = parts.isolated == partID
            VStack(alignment: .leading, spacing: Space.m) {
                HStack(alignment: .top, spacing: Space.s) {
                    VStack(alignment: .leading, spacing: Space.xxs) {
                        Text(settings.t(label.name)).font(.title3.weight(.semibold))
                            .lineLimit(2)
                            .accessibilityAddTraits(.isHeader)
                        Text(settings.t(label.layer)).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: Space.s)
                    Button(action: onClose) {
                        Image(systemName: "xmark").font(.footnote.weight(.bold)).foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                            .background(Color.fill, in: .circle)
                            .frame(width: minTap, height: minTap)
                            .contentShape(.rect)
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.top, -Space.s).padding(.trailing, -Space.s)
                    .accessibilityLabel(settings.t("Close", "关闭"))
                }
                HStack(spacing: Space.s) {
                    action(settings.t("Hide", "隐藏"), "eye.slash", on: false) {
                        var p = parts; p.hidden.insert(partID); onChange(p); onClose()
                    }
                    action(settings.t("Fade", "淡化"), "circle.lefthalf.filled", on: faded) {
                        var p = parts
                        if faded { p.faded.remove(partID) } else { p.faded.insert(partID) }
                        onChange(p)
                    }
                    action(settings.t("Isolate", "单独显示"), "scope", on: isolated) {
                        var p = parts; p.isolated = isolated ? nil : partID; onChange(p)
                    }
                }
                let zones = zonesForOrgan(partID)
                if !zones.isEmpty {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Eyebrow(settings.t("Reflex zones", "反射区"))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Space.s) {
                                ForEach(zones, id: \.label.en) { zone in
                                    NavigationLink(value: zone.route) {
                                        HStack(spacing: Space.xs) {
                                            Text(settings.t(zone.label))
                                            Image(systemName: "chevron.right").imageScale(.small)
                                        }
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.brand)
                                        .padding(.horizontal, Space.m)
                                        .frame(minHeight: 34)
                                        .background(Color.brand.opacity(0.12), in: .capsule)
                                        .padding(.vertical, 5)
                                        .contentShape(.rect)
                                    }
                                    .buttonStyle(PressableStyle())
                                }
                            }
                        }
                        .padding(.horizontal, -Space.l)
                        .contentMargins(.horizontal, Space.l, for: .scrollContent)
                    }
                }
            }
            .padding(.horizontal, Space.l)
        }
    }

    /// equal-width icon-over-label action; `on` marks a toggled state
    private func action(_ title: String, _ symbol: String, on: Bool, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            VStack(spacing: Space.xxs) {
                Image(systemName: symbol).font(.body.weight(.semibold))
                Text(title).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(on ? Color.white : Color.brand)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(on ? Color.brandFill : Color.brand.opacity(0.12), in: .rect(cornerRadius: Radius.tile, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
        .sensoryFeedback(.impact(weight: .light), trigger: on)
    }
}

struct JointControl: View {
    let joint: Joint
    let angle: Float
    let onChange: (Float) -> Void
    @Environment(Settings.self) private var settings

    var body: some View {
        let name = settings.name(joint.name, joint.nameZh)
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(alignment: .firstTextBaseline) {
                Label(name, systemImage: "hand.draw.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.brand)
                Spacer()
                Text("\(Int(angle))°").font(.subheadline.weight(.semibold).monospacedDigit())
            }
            Slider(value: Binding(get: { Double(angle) }, set: { onChange(Float($0)) }), in: 0...Double(joint.maxDeg))
                .accessibilityLabel(name)
                .accessibilityValue("\(Int(angle))°")
            let movers = joint.movers.compactMap(Catalog.part).map { settings.name($0.name, $0.nameZh) }
            Text(settings.t("Working muscle: \(movers.joined(separator: ", ")) · range 0–\(Int(joint.maxDeg))°",
                            "工作肌肉：\(movers.joined(separator: "、")) · 活动范围 0–\(Int(joint.maxDeg))°"))
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(Space.m)
        .background(Color.brand.opacity(0.08), in: .rect(cornerRadius: Radius.tile, style: .continuous))
        .padding(.horizontal, Space.l)
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
    private let chartTitle = ["foot": Bilingual("Open the foot chart", "打开足部反射区图"), "hand": Bilingual("Open the hand chart", "打开手部反射区图"),
                              "ear": Bilingual("Open the ear chart", "打开耳穴图")]

    var body: some View {
        let visible = filter == "all" ? points : points.filter { $0.region == filter }
        let active = points.first { $0.id == activeID }
        VStack(alignment: .leading, spacing: Space.s) {
            Picker(settings.t("Region", "部位"), selection: Binding(get: { filter }, set: { id in
                filter = id
                if let f = filters.first(where: { $0.id == id }) { onFocus(f.focus) }
            })) {
                ForEach(filters, id: \.id) { Text(settings.t($0.label)).tag($0.id) }
            }
            .adaptivePickerStyle()
            .padding(.horizontal, Space.l)
            PillRow {
                ForEach(visible) { p in
                    Pill(label: settings.name(p.name, p.nameZh), selected: p.id == activeID,
                         warn: Cautions.avoid(p.id, for: settings.profile)) { onPress(p.id) }
                }
            }
            if let title = chartTitle[filter] {
                NavigationLink(value: Route.chart(id: filter)) {
                    Label(settings.t(title), systemImage: "hand.raised.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: minTap)
                }
                .padding(.horizontal, Space.l)
            }
            if let p = active {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text(settings.name(p.name, p.nameZh)).font(.headline)
                    Text(settings.name(p.description, p.descriptionZh)).font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    CautionList(warnings: Cautions.warnings(p.id, for: settings.profile))
                    if let t = p.target {
                        VStack(alignment: .leading, spacing: Space.xs) {
                            Label(settings.name(t.name, t.nameZh), systemImage: "scope")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(Color.success)
                            Text(settings.name(t.effect, t.effectZh)).font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(alignment: .center) {
                                Text(settings.t("Traditional reflexology claim — not medical advice.", "传统反射疗法说法，非医疗建议。"))
                                    .font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Button { onPress(p.id) } label: {
                                    Label(settings.t("Replay", "重播"), systemImage: "arrow.counterclockwise")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(minHeight: minTap)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .opacity(effectVisible ? 1 : 0)
                        .animation(.easeOut(duration: 0.3), value: effectVisible)
                    }
                }
                .padding(Space.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.page, in: .rect(cornerRadius: Radius.tile, style: .continuous))
                .padding(.horizontal, Space.l)
                .sensoryFeedback(.impact(weight: .light), trigger: effectVisible) { _, new in new }
            } else {
                Hint(symbol: "hand.point.up.left", text: settings.t("Press a point — watch where it acts. Tap a dot on the body or a name above.", "按一个穴位，看它作用在哪里。点身体上的圆点或上方名称。"))
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
        VStack(alignment: .leading, spacing: Space.s) {
            VStack(spacing: Space.xxs) {
                HStack(alignment: .firstTextBaseline) {
                    Label(settings.t("Heart rate", "心率"), systemImage: "heart.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.emergency)
                    Spacer()
                    Text(settings.t("\(Int(bpm)) bpm", "\(Int(bpm)) 次/分")).font(.subheadline.weight(.semibold).monospacedDigit())
                }
                Slider(value: Binding(get: { Double(bpm) }, set: { bpm = Float($0) }), in: 40...180)
                    .accessibilityLabel(settings.t("Heart rate", "心率"))
                    .accessibilityValue(settings.t("\(Int(bpm)) beats per minute", "每分钟 \(Int(bpm)) 次"))
            }
            .padding(.horizontal, Space.l)
            PillRow {
                ForEach(Array(stops.enumerated()), id: \.element.id) { i, stop in
                    Pill(label: "\(i + 1). \(settings.name(stop.name, stop.nameZh))", selected: stop.id == activeID) { onStop(stop.id) }
                }
            }
            if let stop = stops.first(where: { $0.id == activeID }) {
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(settings.name(stop.name, stop.nameZh)).font(.headline)
                    Text(settings.name(stop.description, stop.descriptionZh)).font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Space.l)
            } else {
                Hint(symbol: "drop.fill", text: settings.t("Red = oxygen-rich, blue = oxygen-poor. Drag the heart rate and watch the flow follow.", "红色为富氧血，蓝色为缺氧血。拖动心率，观察血流变化。"))
            }
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
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.caution)
                .padding(Space.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.cautionFill, in: .rect(cornerRadius: Radius.small, style: .continuous))
        }
    }
}
