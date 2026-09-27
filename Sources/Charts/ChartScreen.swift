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
    @AppStorage("chartLayout") private var layout: ChartLayout = .stacked
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
            }
            zoneList
            card
        }
        .navigationTitle(settings.name(chart.title, chart.titleZh))
        .profileToolbar()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: setUp)
        .onChange(of: settings.profile) {
            inset.setAge(settings.age)
            inset.build(skinColor: UIColor(hex: "#F2C9A5"), female: settings.female, pregnant: settings.profile.isPregnant, points: [], flowStops: [])
            inset.setLayers([.skin, .organs])
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Picker("Side", selection: Binding(get: { side }, set: { side = $0; clear() })) {
                Text(settings.t("Left", "左")).tag(Side.left)
                Text(settings.t("Right", "右")).tag(Side.right)
            }
            .pickerStyle(.segmented)
            if chart.faces.count > 1 {
                Picker("Face", selection: Binding(get: { face.id }, set: { faceID = $0; clear() })) {
                    ForEach(chart.faces) { f in Text(settings.name(f.label, f.labelZh)).tag(f.id) }
                }
                .pickerStyle(.segmented)
            }
            Menu {
                Picker(settings.t("Layout", "布局"), selection: $layout) {
                    ForEach(ChartLayout.allCases, id: \.self) { l in
                        Label(settings.t(l.label), systemImage: l.symbol).tag(l)
                    }
                }
            } label: {
                Image(systemName: layout.symbol)
                    .frame(width: 32, height: 32)
                    .background(Color.secondary.opacity(0.12), in: .rect(cornerRadius: 8))
            }
            .accessibilityLabel(settings.t("Layout", "布局"))
        }
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
                            if let hit { press(hit) }
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

    private var bodyPane: some View {
        ZStack(alignment: .top) {
            BodyView(scene: inset, compact: true)
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

    /// Every zone by name; tapping one lights it on the chart, tapping the chart scrolls here.
    private var zoneList: some View {
        let groups = Array(Set(zones.map(\.group))).sorted()
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(groups, id: \.self) { g in
                        let info = Catalog.charts.groups[g]
                        let color = Color(hex: info?.color ?? "#999999")
                        FlowLayout(spacing: 6) {
                            ForEach(zones.filter { $0.group == g }) { zone in
                                let on = zone.id == selected?.id
                                Button { press(zone) } label: {
                                    HStack(spacing: 4) {
                                        if Cautions.avoid(zone.id, for: settings.profile) { Text("⚠").font(.caption2) }
                                        Circle().fill(on ? .white : color).frame(width: 7, height: 7)
                                        Text(settings.name(zone.name, zone.nameZh)).font(.caption)
                                    }
                                    .padding(.horizontal, 9).padding(.vertical, 5)
                                    .background(on ? color : color.opacity(0.14), in: .capsule)
                                    .foregroundStyle(on ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                                .id(zone.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .frame(height: 96)
            .onChange(of: selected?.id) { _, id in
                if let id { withAnimation { proxy.scrollTo(id, anchor: .center) } }
            }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let zone = selected {
                Text(settings.name(zone.name, zone.nameZh)).font(.subheadline.weight(.semibold))
                CautionList(warnings: Array(Cautions.warnings(zone.id, for: settings.profile).prefix(1)))
                Group {
                    Text(settings.name(zone.effect, zone.effectZh)).font(.caption)
                    HStack {
                        Text(settings.t("Traditional claim — not medical advice.", "传统说法，非医疗建议。")).font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Button(settings.t("↻ Replay", "↻ 重播")) { press(zone) }.font(.caption.weight(.semibold))
                    }
                }
                .opacity(effectVisible ? 1 : 0)
            } else {
                Text(settings.t("Tap a zone — the pulse on the figure shows where it acts.", "点按区域，人体上会显示对应器官。"))
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    private func setUp() {
        guard !ready else { return }
        ready = true
        faceID = initialFace ?? chart.faces[0].id
        side = initialSide ?? .right
        Task {
            await BodyScene.prepare()
            inset.setAge(settings.age)
            inset.build(skinColor: UIColor(hex: "#F2C9A5"), female: settings.female, pregnant: settings.profile.isPregnant, points: [], flowStops: [])
            inset.setLayers([.skin, .organs])
            if let id = initialZone, let zone = face.zones.first(where: { $0.id == id }) { press(zone) }
        }
    }

    private func clear() {
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
