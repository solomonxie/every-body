import SwiftUI

/// Label for a schematic part or organ.
func partLabel(_ id: String, female: Bool) -> (name: String, nameZh: String, layer: String)? {
    if let part = Catalog.part(id) {
        let layer = Catalog.body.layers.first { $0.id == part.layer }
        return (part.name, part.nameZh, layer.map { "\($0.labelZh) \($0.label)" } ?? "")
    }
    guard let names = Catalog.organ(id)?.names else { return nil }
    if id == "uterus" { return female ? ("Uterus", "子宫", "器官 Organs") : ("Prostate", "前列腺", "器官 Organs") }
    return (names[0], names[1], "器官 Organs")
}

/// Every chart zone said to act on an organ.
func zonesForOrgan(_ id: String) -> [(label: String, route: Route)] {
    Catalog.charts.charts.flatMap { chart in
        chart.faces.flatMap { face in
            face.zones.filter { $0.organIds.contains(id) }.map { zone in
                ("\(chart.titleZh.replacingOccurrences(of: "反射区", with: "").replacingOccurrences(of: "穴", with: ""))·\(zone.nameZh)",
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
                        Text(settings.name(label.name, label.nameZh)).font(.subheadline.weight(.semibold))
                        Text(label.layer).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Hide 隐藏") {
                        var p = parts; p.hidden.insert(partID); onChange(p); onClose()
                    }
                    Button(parts.faded.contains(partID) ? "Unfade" : "Fade 淡化") {
                        var p = parts
                        if p.faded.contains(partID) { p.faded.remove(partID) } else { p.faded.insert(partID) }
                        onChange(p)
                    }
                    Button(parts.isolated == partID ? "Show rest" : "Isolate 单独") {
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
                            Text("Reflex zones 反射区:").font(.caption).foregroundStyle(.secondary)
                            ForEach(zones, id: \.label) { zone in
                                NavigationLink(value: zone.route) { Text("\(zone.label) ›").font(.caption) }
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
                Text("Try ▸ \(settings.name(joint.name, joint.nameZh))").font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int(angle))°").font(.subheadline.weight(.semibold))
            }
            Slider(value: Binding(get: { Double(angle) }, set: { onChange(Float($0)) }), in: 0...Double(joint.maxDeg))
            Text("Working muscle: \(joint.movers.map { $0.replacingOccurrences(of: "-l", with: "").replacingOccurrences(of: "-r", with: "") }.joined(separator: ", ")) · range 0–\(Int(joint.maxDeg))°")
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

    private let filters: [(id: String, label: String, focus: Focus)] = [
        ("all", "All", .all), ("foot", "Foot 足", .foot), ("hand", "Hand 手", .hand), ("ear", "Ear 耳", .ear), ("body", "Body 身", .all),
    ]

    var body: some View {
        let visible = filter == "all" ? points : points.filter { $0.region == filter }
        let active = points.first { $0.id == activeID }
        VStack(alignment: .leading, spacing: 8) {
            PillRow {
                ForEach(filters, id: \.id) { f in
                    Pill(label: f.label, selected: filter == f.id) { filter = f.id; onFocus(f.focus) }
                }
            }
            PillRow {
                ForEach(visible) { p in
                    Pill(label: settings.names == .en ? p.name : p.nameZh, selected: p.id == activeID) { onPress(p.id) }
                }
            }
            if ["foot", "hand", "ear"].contains(filter) {
                NavigationLink(value: Route.chart(id: filter)) {
                    Text("Open \(filter) chart ›").font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 16)
            }
            if let p = active {
                VStack(alignment: .leading, spacing: 4) {
                    Text(settings.name(p.name, p.nameZh)).font(.subheadline.weight(.semibold))
                    Text(p.description).font(.caption).foregroundStyle(.secondary)
                    if let t = p.target {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("→ \(settings.name(t.name, t.nameZh))").font(.subheadline.weight(.semibold))
                            if settings.showEn { Text(t.effect).font(.caption) }
                            if settings.showZh { Text(t.effectZh).font(.caption) }
                            HStack {
                                Text("Traditional reflexology claim — not medical advice.").font(.caption2).foregroundStyle(.secondary)
                                Spacer()
                                Button("↻ Replay") { onPress(p.id) }.font(.caption.weight(.semibold))
                            }
                        }
                        .opacity(effectVisible ? 1 : 0)
                    }
                }
                .padding(12)
                .background(Color(uiColor: .systemBackground), in: .rect(cornerRadius: 14))
                .padding(.horizontal, 16)
            } else {
                Text("Press a point — watch where it acts. Tap a dot on the body or a name above.")
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
                Text("Heart rate 心率").font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int(bpm)) bpm").font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 16)
            Slider(value: Binding(get: { Double(bpm) }, set: { bpm = Float($0) }), in: 40...180).padding(.horizontal, 16)
            PillRow {
                ForEach(Array(stops.enumerated()), id: \.element.id) { i, stop in
                    Pill(label: "\(i + 1). \(stop.name)", selected: stop.id == activeID) { onStop(stop.id) }
                }
            }
            Group {
                if let stop = stops.first(where: { $0.id == activeID }) {
                    VStack(alignment: .leading) {
                        Text(settings.name(stop.name, stop.nameZh)).font(.subheadline.weight(.semibold))
                        Text(stop.description).font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text("Red = oxygen-rich, blue = oxygen-poor. Drag the heart rate and watch the flow follow.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
