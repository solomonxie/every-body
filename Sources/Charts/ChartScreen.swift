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
    @State private var ready = false

    private var chart: ReflexChart { Catalog.chart(chartID) ?? Catalog.charts.charts[0] }
    private var face: ChartFace { chart.faces.first { $0.id == faceID } ?? chart.faces[0] }
    private var zones: [ReflexZone] { face.zones.filter { $0.side == nil || $0.side == side } }

    var body: some View {
        VStack(spacing: 0) {
            controls
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            // body on top, chart below — each pinch-zooms on its own, both start fitted
            GeometryReader { stage in
                VStack(spacing: 0) {
                    bodyPane
                        .frame(height: stage.size.height * split)
                    splitBar(total: stage.size.height)
                    chartPane
                }
            }
            zoneList
            card
        }
        .navigationTitle(settings.name(chart.title, chart.titleZh))
        .profileToolbar()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: setUp)
        .onChange(of: settings.age) { inset.setAge(settings.age) }
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
    private func splitBar(total: CGFloat) -> some View {
        Capsule()
            .fill(Color.secondary.opacity(splitStart == nil ? 0.35 : 0.7))
            .frame(width: 44, height: 5)
            .frame(maxWidth: .infinity, minHeight: 22)
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    let start = splitStart ?? split
                    splitStart = start
                    split = min(0.8, max(0.15, start + v.translation.height / max(total, 1)))
                }
                .onEnded { _ in splitStart = nil })
            .accessibilityLabel(settings.t("Resize body and chart", "调整人体与图的大小"))
    }

    private var bodyPane: some View {
        ZStack(alignment: .top) {
            BodyView(scene: inset, compact: true)
            Text(selected.map { z in
                settings.name(z.name, z.nameZh) + " → " + z.organIds.compactMap { Catalog.organ($0)?.names }.map { settings.name($0[0], $0[1]) }
                    .joined(separator: settings.zh ? "、" : ", ")
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
                Text(settings.t("Tap a zone — the pulse on the figure shows where it acts.", "点按区域，右侧人体会显示对应器官。"))
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 72, maxHeight: 150, alignment: .topLeading)
        .padding(16)
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
            inset.build(skinColor: UIColor(hex: "#F2C9A5"), female: settings.female, points: [], flowStops: [])
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

/// Draws one chart face; the undrawn side is the drawing mirrored.
struct ChartCanvas: View {
    let chart: ReflexChart
    let face: ChartFace
    let side: Side
    let zones: [ReflexZone]
    let selectedID: String?
    let showLabels: Bool
    var zh = true
    var flagged: Set<String> = []
    let zoom: CGFloat
    let pan: CGSize

    private static let skin = Color(hex: "#F5D7BF")
    private static let line = Color(hex: "#C9A58A")
    private static let ink = Color(hex: "#2B2250")

    var body: some View {
        Canvas { ctx, size in
            let view = Self.viewTransform(size: size, chart: chart, zoom: zoom, pan: pan)
            let mirror = Self.mirror(chart: chart, face: face, side: side)
            var drawing = ctx
            drawing.transform = mirror.concatenating(view)

            for shape in face.outline {
                drawing.fill(Self.outlinePath(shape), with: .color(Self.skin))
            }
            for shape in face.outline {
                drawing.stroke(Self.outlinePath(shape), with: .color(Self.line), lineWidth: 2)
            }
            for d in face.bones {
                drawing.stroke(SVGPath.parse(d), with: .color(Self.line), style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
            }
            for d in face.guides {
                drawing.stroke(SVGPath.parse(d), with: .color(Self.line), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            for zone in zones {
                let isSelected = zone.id == selectedID
                let dimmed = selectedID != nil && !isSelected
                let color = Color(hex: Catalog.charts.groups[zone.group]?.color ?? "#999999")
                for e in zone.shapes {
                    let p = Self.ellipse(e)
                    drawing.fill(p, with: .color(color.opacity(isSelected ? 0.95 : dimmed ? 0.3 : 0.65)))
                    let warn = flagged.contains(zone.id)
                    drawing.stroke(p, with: .color(isSelected ? Self.ink : warn ? Color(hex: "#D8434B") : .white),
                                   style: StrokeStyle(lineWidth: isSelected ? 2.5 : warn ? 2 : 1.2, dash: warn && !isSelected ? [3, 2] : []))
                }
            }
            do {
                var labels = ctx
                labels.transform = view
                for zone in zones where showLabels || zone.id == selectedID {
                    guard let e = zone.shapes.first else { continue }
                    let below = zone.point == true || e.rx < 10
                    let x = side == face.drawnSide ? e.cx : chart.mirrorWidth - e.cx
                    let y = e.cy + (below ? e.ry + chart.labelSize : 0)
                    let text = Text(zh ? zone.label ?? String(zone.nameZh.split(separator: "·").first ?? "") : Self.shortName(zone.name))
                        .font(.system(size: chart.labelSize, weight: zone.id == selectedID ? .bold : .regular))
                        .foregroundStyle(Self.ink)
                    if zone.id == selectedID {
                        // selected name sits on a white tag so it reads over the zones
                        let resolved = labels.resolve(Text(zh ? zone.nameZh : zone.name)
                            .font(.system(size: chart.labelSize * 1.15, weight: .bold)).foregroundStyle(Self.ink))
                        let size = resolved.measure(in: CGSize(width: 400, height: 100))
                        let at = CGPoint(x: x, y: e.cy - e.ry - size.height)
                        labels.fill(Path(roundedRect: CGRect(x: at.x - size.width / 2 - 4, y: at.y - size.height / 2 - 2,
                                                             width: size.width + 8, height: size.height + 4), cornerRadius: 4),
                                    with: .color(.white.opacity(0.92)))
                        labels.draw(resolved, at: at, anchor: .center)
                    } else {
                        labels.draw(text, at: CGPoint(x: x, y: y), anchor: .center)
                    }
                }
            }
        }
    }

    /// "Lung & bronchi" → "Lung"; keeps chart labels as short as the Chinese ones
    static func shortName(_ name: String) -> String {
        let first = name.components(separatedBy: CharacterSet(charactersIn: "&/(,·")).first ?? name
        return first.trimmingCharacters(in: .whitespaces)
    }

    static func viewTransform(size: CGSize, chart: ReflexChart, zoom: CGFloat, pan: CGSize) -> CGAffineTransform {
        let (vx, vy, vw, vh) = (chart.viewBox[0], chart.viewBox[1], chart.viewBox[2], chart.viewBox[3])
        let s = min(size.width / vw, size.height / vh)
        let ox = (size.width - vw * s) / 2, oy = (size.height - vh * s) / 2
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        return CGAffineTransform(translationX: -vx, y: -vy)
            .concatenating(CGAffineTransform(scaleX: s, y: s))
            .concatenating(CGAffineTransform(translationX: ox - c.x, y: oy - c.y))
            .concatenating(CGAffineTransform(scaleX: zoom, y: zoom))
            .concatenating(CGAffineTransform(translationX: c.x + pan.width, y: c.y + pan.height))
    }

    static func mirror(chart: ReflexChart, face: ChartFace, side: Side) -> CGAffineTransform {
        side == face.drawnSide ? .identity : CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: chart.mirrorWidth, ty: 0)
    }

    static func ellipse(_ e: ChartEllipse) -> Path {
        let rect = CGRect(x: e.cx - e.rx, y: e.cy - e.ry, width: e.rx * 2, height: e.ry * 2)
        let p = Path(ellipseIn: rect)
        guard let rot = e.rot else { return p }
        return p.applying(CGAffineTransform(translationX: -e.cx, y: -e.cy)
            .concatenating(CGAffineTransform(rotationAngle: rot * .pi / 180))
            .concatenating(CGAffineTransform(translationX: e.cx, y: e.cy)))
    }

    static func outlinePath(_ s: OutlineShape) -> Path {
        if s.kind == "path", let d = s.d { return SVGPath.parse(d) }
        let rect = CGRect(x: s.x ?? 0, y: s.y ?? 0, width: s.w ?? 0, height: s.h ?? 0)
        let p = Path(roundedRect: rect, cornerRadius: s.r ?? 0)
        guard let rot = s.rot, let ox = s.ox, let oy = s.oy else { return p }
        return p.applying(CGAffineTransform(translationX: -ox, y: -oy)
            .concatenating(CGAffineTransform(rotationAngle: rot * .pi / 180))
            .concatenating(CGAffineTransform(translationX: ox, y: oy)))
    }

    /// Topmost (smallest) zone under a tap.
    static func hitTest(_ point: CGPoint, size: CGSize, chart: ReflexChart, face: ChartFace, side: Side, zones: [ReflexZone],
                        zoom: CGFloat, pan: CGSize) -> ReflexZone? {
        let toDrawing = mirror(chart: chart, face: face, side: side).concatenating(viewTransform(size: size, chart: chart, zoom: zoom, pan: pan)).inverted()
        let p = point.applying(toDrawing)
        let hits = zones.filter { zone in zone.shapes.contains { ellipse($0).contains(p) || hypot($0.cx - p.x, $0.cy - p.y) < 9 } }
        return hits.min { a, b in (a.shapes.first.map { $0.rx * $0.ry } ?? 0) < (b.shapes.first.map { $0.rx * $0.ry } ?? 0) }
    }
}
