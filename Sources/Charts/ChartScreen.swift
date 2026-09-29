import SwiftUI

struct ChartScreen: View {
    let chartID: String
    var initialFace: String?
    var initialZone: String?
    var initialSide: Side?

    @Environment(Settings.self) private var settings
    @State private var faceID = ""
    @State private var side: Side = .right
    @State private var selected: ReflexZone?
    @State private var effectVisible = false
    @State private var zoom: CGFloat = 1
    @State private var zoomBase: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var panBase: CGSize = .zero
    @State private var inset = BodyScene()
    /// share of the stage given to the 3D body; the bar between the halves drags it
    @State private var split: CGFloat = 0.42
    @State private var splitStart: CGFloat?
    @State private var layout: ChartLayout = .overlay
    /// what the 3D body shows besides the skin; every visit starts fresh
    @State private var insetLayersRaw = "organs"
    @State private var ready = false

    private var chart: ReflexChart { Catalog.chart(chartID) ?? Catalog.charts.charts[0] }
    private var face: ChartFace { chart.faces.first { $0.id == faceID } ?? chart.faces[0] }
    private var zones: [ReflexZone] { face.zones.filter { $0.side == nil || $0.side == side } }

    var body: some View {
        VStack(spacing: 0) {
            controls
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            // each half pinch-zooms on its own; both start fitted
            GeometryReader { stage in
                // one body view and one chart view for every layout — only their frames move,
                // so the 3D scene is never torn down and re-attached
                let r = rects(stage.size)
                ZStack(alignment: .topLeading) {
                    bodyPane
                        .frame(width: r.body.width, height: r.body.height)
                        .offset(x: r.body.minX, y: r.body.minY)
                    chartPane
                        .background(layout == .overlay ? Color(uiColor: .systemBackground) : .clear, in: .rect(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.secondary.opacity(layout == .overlay ? 0.4 : 0)))
                        .frame(width: r.chart.width, height: r.chart.height)
                        .offset(x: r.chart.minX, y: r.chart.minY)
                    if let bar = r.bar {
                        splitBar(total: layout == .stacked ? stage.size.height : stage.size.width, vertical: layout == .stacked)
                            .frame(width: bar.width, height: bar.height)
                            .offset(x: bar.minX, y: bar.minY)
                    }
                }
                // zone details pop over the stage; any tap elsewhere closes them
                .overlay(alignment: .bottom) {
                    if let zone = selected {
                        popup(zone)
                            .padding(12)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.snappy(duration: 0.25), value: selected?.id)
            }
        }
        .navigationTitle(settings.name(chart.title, chart.titleZh))
        .profileToolbar()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: setUp)
        .onChange(of: settings.profile) {
            inset.setAge(settings.age)
            buildInset()
        }
        .onChange(of: settings.heritage) { buildInset() }
        .onChange(of: layout) { placeBody() }
        .onChange(of: settings.showUnderwear) { buildInset() }
        .onChange(of: settings.chest) { buildInset() }
        .onChange(of: settings.hips) { buildInset() }
    }

    /// One row of compact menus: which view, which zone, what the body shows, and the layout.
    private var controls: some View {
        HStack(spacing: 8) {
            Menu {
                Picker(settings.t("Side", "左右"), selection: Binding(get: { side }, set: { side = $0; clear() })) {
                    Text(settings.t("Left", "左")).tag(Side.left)
                    Text(settings.t("Right", "右")).tag(Side.right)
                }
                if chart.faces.count > 1 {
                    Picker(settings.t("View", "视图"), selection: Binding(get: { face.id }, set: { faceID = $0; clear() })) {
                        ForEach(chart.faces) { f in Text(settings.name(f.label, f.labelZh)).tag(f.id) }
                    }
                }
            } label: {
                menuLabel(settings.t(side == .left ? "Left" : "Right", side == .left ? "左" : "右")
                          + (chart.faces.count > 1 ? " · " + settings.name(face.label, face.labelZh) : ""), symbol: "hand.raised")
            }
            Menu {
                let groups = Array(Set(zones.map(\.group))).sorted()
                ForEach(groups, id: \.self) { g in
                    Section(Catalog.charts.groups[g].map { settings.name($0.label, $0.labelZh) } ?? g) {
                        ForEach(zones.filter { $0.group == g }) { zone in
                            Button { press(zone) } label: {
                                Text((Cautions.avoid(zone.id, for: settings.profile) ? "⚠ " : "") + settings.name(zone.name, zone.nameZh))
                            }
                        }
                    }
                }
            } label: {
                menuLabel(selected.map { settings.name($0.name, $0.nameZh) } ?? settings.t("Zones", "反射区"), symbol: "list.bullet")
            }
            Spacer(minLength: 0)
            Menu {
                ForEach(InsetLayer.allCases, id: \.self) { layer in
                    Toggle(settings.t(layer.label), isOn: Binding(get: { insetLayers.contains(layer) }, set: { _ in toggle(layer) }))
                }
            } label: {
                iconLabel("square.3.layers.3d")
            }
            .accessibilityLabel(settings.t("Body layers", "人体图层"))
            Menu {
                Picker(settings.t("Layout", "布局"), selection: $layout) {
                    ForEach(ChartLayout.allCases, id: \.self) { l in
                        Label(settings.t(l.label), systemImage: l.symbol).tag(l)
                    }
                }
            } label: {
                iconLabel(layout.symbol)
            }
            .accessibilityLabel(settings.t("Layout", "布局"))
        }
    }

    private func menuLabel(_ text: String, symbol: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.footnote)
            Text(text).font(.subheadline.weight(.semibold)).lineLimit(1)
            Image(systemName: "chevron.down").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12).frame(height: 34)
        .background(Color.secondary.opacity(0.12), in: .capsule)
        .foregroundStyle(.primary)
    }

    private func iconLabel(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .frame(width: 34, height: 34)
            .background(Color.secondary.opacity(0.12), in: .circle)
            .foregroundStyle(.primary)
    }

    /// Floating explanation for the tapped zone.
    private func popup(_ zone: ReflexZone) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Circle().fill(Color(hex: Catalog.charts.groups[zone.group]?.color ?? "#999999")).frame(width: 9, height: 9)
                Text(settings.name(zone.name, zone.nameZh)).font(.headline)
                Spacer(minLength: 8)
                Button { press(zone) } label: { Image(systemName: "arrow.counterclockwise") }
                    .accessibilityLabel(settings.t("Replay", "重播"))
                Button { clear() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .accessibilityLabel(settings.t("Close", "关闭"))
            }
            let organs = zone.organIds.compactMap { Catalog.organ($0)?.names }.map { settings.name($0[0], $0[1]) }
            if !organs.isEmpty {
                Text("→ " + organs.joined(separator: settings.zh ? "、" : ", ")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            CautionList(warnings: Array(Cautions.warnings(zone.id, for: settings.profile).prefix(1)))
            Text(settings.name(zone.effect, zone.effectZh)).font(.subheadline)
            Text(settings.t("Traditional claim — not medical advice.", "传统说法，非医疗建议。")).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: 520, alignment: .leading)
        .background(.regularMaterial, in: .rect(cornerRadius: 18))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .buttonStyle(.plain)
    }

    private var chartPane: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottomTrailing) {
                GeometryReader { geo in
                    ChartCanvas(chart: chart, face: face, side: side, zones: zones, selectedID: selected?.id,
                                showLabels: false, zh: settings.zh, flagged: Set(zones.filter { Cautions.avoid($0.id, for: settings.profile) }.map(\.id)), zoom: zoom, pan: pan)
                        .contentShape(.rect)
                        .gesture(SpatialTapGesture().onEnded { value in
                            let hit = ChartCanvas.hitTest(value.location, size: geo.size, chart: chart, face: face, side: side,
                                                          zones: zones, zoom: zoom, pan: pan)
                            if let hit { press(hit) } else { clear() }
                        })
                        .gesture(MagnifyGesture()
                            .onChanged { zoom = max(1, min(4, zoomBase * $0.magnification)) }
                            .onEnded { _ in zoomBase = zoom })
                        .simultaneousGesture(DragGesture(minimumDistance: 10)
                            .onChanged { pan = CGSize(width: panBase.width + $0.translation.width, height: panBase.height + $0.translation.height) }
                            .onEnded { _ in panBase = pan })
                }
                .clipped()
                if zoom > 1.01 || pan != .zero {
                    Button("⟲ 1×") { withAnimation { zoom = 1; zoomBase = 1; pan = .zero; panBase = .zero } }
                        .font(.caption).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color(hex: "#2B2250").opacity(0.7), in: .capsule)
                        .padding(8)
                }
            }
        }
    }

    /// Full-height body: a standing figure is tall and narrow, so a tall pane shows it large.
    private func rects(_ size: CGSize) -> (body: CGRect, chart: CGRect, bar: CGRect?) {
        let bar: CGFloat = 22
        switch layout {
        case .stacked:
            let h = (size.height - bar) * split
            return (CGRect(x: 0, y: 0, width: size.width, height: h),
                    CGRect(x: 0, y: h + bar, width: size.width, height: size.height - h - bar),
                    CGRect(x: 0, y: h, width: size.width, height: bar))
        case .sideBySide:
            let w = (size.width - bar) * split
            let chartW = size.width - w - bar
            return (CGRect(x: chartW + bar, y: 0, width: w, height: size.height),
                    CGRect(x: 0, y: 0, width: chartW, height: size.height),
                    CGRect(x: chartW, y: 0, width: bar, height: size.height))
        case .overlay:
            let w = size.width * 0.46, h = size.height * 0.46
            return (CGRect(origin: .zero, size: size),
                    CGRect(x: size.width - w - 16, y: size.height - h - 16, width: w, height: h), nil)
        }
    }

    /// Drag handle between the halves; `split` is always the body's share.
    private func splitBar(total: CGFloat, vertical: Bool) -> some View {
        Capsule()
            .fill(Color.secondary.opacity(splitStart == nil ? 0.35 : 0.7))
            .frame(width: vertical ? 44 : 5, height: vertical ? 5 : 44)
            .frame(maxWidth: vertical ? .infinity : 22, maxHeight: vertical ? 22 : .infinity)
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    let start = splitStart ?? split
                    splitStart = start
                    // stacked: body above, dragging down grows it; side by side: body right, dragging left grows it
                    let delta = vertical ? v.translation.height : -v.translation.width
                    split = min(0.8, max(0.15, start + delta / max(total, 1)))
                }
                .onEnded { _ in splitStart = nil })
            .accessibilityLabel(settings.t("Resize body and chart", "调整人体与图的大小"))
    }

    private var insetLayers: Set<InsetLayer> {
        Set(insetLayersRaw.split(separator: ",").compactMap { InsetLayer(rawValue: String($0)) })
    }

    /// In the body + box layout the body stands left of centre, a little closer, so the box never covers it.
    private func placeBody() {
        let overlay = layout == .overlay
        inset.basePanX = overlay ? 0.62 : 0
        inset.baseZoom = overlay ? 0.88 : 1
        inset.focus(.all)
    }

    private func buildInset() {
        inset.heritage = settings.heritage
        inset.underwear = settings.showUnderwear
        inset.chest = settings.chest
        inset.hips = settings.hips
        inset.build(skinColor: UIColor(hex: "#F2C9A5"), female: settings.female, pregnant: settings.profile.isPregnant,
                    points: [], flowStops: [], meridians: Catalog.points["acupuncture"]?.meridians ?? [])
        applyInsetLayers()
        placeBody()
    }

    private func applyInsetLayers() {
        let on = insetLayers
        var layers: Set<LayerID> = [.skin]
        if on.contains(.organs) { layers.insert(.organs) }
        if on.contains(.nerves) { layers.insert(.nervous) }
        if on.contains(.vessels) { layers.insert(.circulatory) }
        if on.contains(.bones) { layers.insert(.skeletal) }
        inset.setLayers(layers)
        // the channels that run through this chart's region
        inset.showMeridians(on.contains(.meridians), ids: InsetLayer.meridians(for: chartID))
    }

    private func toggle(_ layer: InsetLayer) {
        var on = insetLayers
        if on.contains(layer) { on.remove(layer) } else { on.insert(layer) }
        insetLayersRaw = on.map(\.rawValue).sorted().joined(separator: ",")
        applyInsetLayers()
    }

    private var bodyPane: some View {
        ZStack(alignment: .top) {
            BodyView(scene: inset, compact: true)
                .simultaneousGesture(TapGesture().onEnded { clear() })
            Text(selected.map { z in
                let organs = z.organIds.compactMap { Catalog.organ($0)?.names }.map { settings.name($0[0], $0[1]) }
                    .joined(separator: settings.zh ? "、" : ", ")
                return settings.name(z.name, z.nameZh) + (organs.isEmpty ? "" : " → " + organs)
            } ?? settings.t("where it acts", "作用部位"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(hex: "#2B2250"))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(.white.opacity(0.75), in: .capsule)
                .padding(.top, 8)
                .padding(.horizontal, 6)
        }
        .clipShape(.rect(cornerRadius: 16))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    private func setUp() {
        guard !ready else { return }
        ready = true
        settings.resetViewOptions()
        faceID = initialFace ?? chart.faces[0].id
        side = initialSide ?? .right
        Task {
            await BodyScene.prepare()
            inset.setAge(settings.age)
            buildInset()
            if let id = initialZone, let zone = face.zones.first(where: { $0.id == id }) { press(zone) }
        }
    }

    private func clear() {
        guard selected != nil else { return }
        selected = nil
        effectVisible = false
    }

    private func press(_ zone: ReflexZone) {
        selected = zone
        effectVisible = false
        inset.touched = true
        inset.faceFront()
        inset.pulse(from: (chart.anchors[side.rawValue] ?? Vec3(0, 0, 0)).simd, to: zone.organIds)
        Task {
            try? await Task.sleep(for: .milliseconds(1400))
            if selected?.id == zone.id { effectVisible = true }
        }
    }
}

enum ChartLayout: String, CaseIterable {
    case stacked, sideBySide, overlay

    var label: Bilingual {
        switch self {
        case .stacked: Bilingual("Up / down", "上下")
        case .sideBySide: Bilingual("Left / right", "左右")
        case .overlay: Bilingual("Body + chart box", "人体 + 小图")
        }
    }

    var symbol: String {
        switch self {
        case .stacked: "rectangle.split.1x2"
        case .sideBySide: "rectangle.split.2x1"
        case .overlay: "rectangle.inset.bottomright.filled"
        }
    }
}

/// Extra layers for the chart page's 3D body. No muscles: they hide what the chart is about.
enum InsetLayer: String, CaseIterable {
    case organs, meridians, nerves, vessels, bones

    var label: Bilingual {
        switch self {
        case .organs: Bilingual("Organs", "器官")
        case .meridians: Bilingual("Meridians", "经络")
        case .nerves: Bilingual("Nerves", "神经")
        case .vessels: Bilingual("Blood vessels", "血管")
        case .bones: Bilingual("Bones", "骨骼")
        }
    }

    var color: Color {
        switch self {
        case .organs: Color(hex: "#C77DA0")
        case .meridians: Color(hex: "#3F95D6")
        case .nerves: Color(hex: "#E8B923")
        case .vessels: Color(hex: "#D23A3A")
        case .bones: Color(hex: "#B8A58A")
        }
    }

    /// hand: the six arm channels; foot: the six leg channels; ear: all of them
    static func meridians(for chart: String) -> Set<String>? {
        switch chart {
        case "hand": ["LU", "LI", "HT", "SI", "PC", "TE"]
        case "foot": ["ST", "SP", "BL", "KI", "GB", "LR"]
        default: nil
        }
    }
}
