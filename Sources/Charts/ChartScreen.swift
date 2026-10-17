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
    @State private var ready = false
    @State private var stageSize: CGSize = .zero

    private var chart: ReflexChart { Catalog.chart(chartID) ?? Catalog.charts.charts[0] }
    private var face: ChartFace { chart.faces.first { $0.id == faceID } ?? chart.faces[0] }
    private var zones: [ReflexZone] { face.zones.filter { $0.side == nil || $0.side == side } }

    var body: some View {
        VStack(spacing: 0) {
            controls
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            chartPane
            // a picked zone's card sits under the chart, never over it
            if let zone = selected {
                detail(zone)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.25), value: selected?.id)
        .navigationTitle(settings.name(chart.title, chart.titleZh))
        .profileToolbar()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: setUp)
        .onChange(of: settings.profile) {
            inset.setAge(settings.age)
            buildInset()
        }
        .onChange(of: settings.heritage) { buildInset() }
        .onChange(of: settings.showUnderwear) { buildInset() }
        .onChange(of: settings.chest) { buildInset() }
        .onChange(of: settings.hips) { buildInset() }
    }

    /// Which view and which zone.
    private var controls: some View {
        HStack(spacing: 8) {
            Menu {
                Picker(settings.t("Side", "左右"), selection: Binding(get: { side }, set: { focus($0) })) {
                    Text(settings.t("Left", "左")).tag(Side.left)
                    Text(settings.t("Right", "右")).tag(Side.right)
                }
                if chart.faces.count > 1 {
                    Picker(settings.t("View", "视图"), selection: Binding(get: { face.id }, set: { faceID = $0; clear(); centre(on: focusIndex, animated: true) })) {
                        ForEach(chart.faces) { f in Text(settings.name(f.label, f.labelZh)).tag(f.id) }
                    }
                }
            } label: {
                menuLabel((chart.faces.count > 1 ? settings.name(face.label, face.labelZh) + " · " : "")
                          + settings.t(side == .left ? "Left" : "Right", side == .left ? "左" : "右"), symbol: chartID == "foot" ? "shoeprints.fill" : "hand.raised")
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

    /// The picked zone: the 3D body with its pulse beside what the zone is said to do.
    private func detail(_ zone: ReflexZone) -> some View {
        HStack(alignment: .top, spacing: 12) {
            BodyView(scene: inset, compact: true)
                .frame(width: 110, height: 150)
                .clipShape(.rect(cornerRadius: 12))
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
                    .fixedSize(horizontal: false, vertical: true)
                Text(settings.t("Traditional claim — not medical advice.", "传统说法，非医疗建议。")).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
                .ignoresSafeArea(edges: .bottom)
        }
        .buttonStyle(.plain)
    }

    private var chartPane: some View {
        ZStack(alignment: .bottomTrailing) {
            GeometryReader { geo in
                let tiles = self.tiles
                ZStack(alignment: .topLeading) {
                    ForEach(tiles.indices, id: \.self) { i in
                        let t = tiles[i]
                        ChartCanvas(chart: chart, face: t.face, side: t.side, zones: zones(t), selectedID: isFocus(t) ? selected?.id : nil,
                                    showLabels: true, zh: settings.zh,
                                    flagged: Set(zones(t).filter { Cautions.avoid($0.id, for: settings.profile) }.map(\.id)),
                                    zoom: zoom, pan: tilePan(i, geo.size), labelSpan: geo.size.width)
                        if tiles.count > 1 { tileCaption(t, at: geo.size.width / 2 + tilePan(i, geo.size).width) }
                    }
                }
                .contentShape(.rect)
                .gesture(SpatialTapGesture().onEnded { value in
                    for (i, t) in tiles.enumerated() {
                        if let hit = ChartCanvas.hitTest(value.location, size: geo.size, chart: chart, face: t.face, side: t.side,
                                                         zones: zones(t), zoom: zoom, pan: tilePan(i, geo.size)) {
                            faceID = t.face.id
                            side = t.side
                            press(hit)
                            return
                        }
                    }
                    clear()
                })
                .gesture(MagnifyGesture()
                    .onChanged { v in
                        zoom = max(minZoom, min(4, zoomBase * v.magnification))
                        // zoom about the middle of the screen
                        let k = zoom / zoomBase
                        pan = CGSize(width: panBase.width * k, height: panBase.height * k)
                    }
                    .onEnded { _ in zoomBase = zoom; panBase = pan; followCentre(geo.size) })
                .simultaneousGesture(DragGesture(minimumDistance: 10)
                    .onChanged { pan = CGSize(width: panBase.width + $0.translation.width, height: panBase.height + $0.translation.height) }
                    .onEnded { _ in panBase = pan; followCentre(geo.size) })
                .onAppear { stageSize = geo.size; centre(on: focusIndex, animated: false) }
                .onChange(of: geo.size) { stageSize = geo.size }
            }
            .clipped()
            if zoom > 1.01 || zoom < 0.99 || pan != focusPan {
                Button("⟲ 1×") { centre(on: focusIndex, animated: true) }
                    .font(.caption).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color(hex: "#2B2250").opacity(0.7), in: .capsule)
                    .padding(8)
            }
        }
    }

    /// One drawing of a face on one side; the foot lays all four out in a row.
    struct Tile { let face: ChartFace; let side: Side }

    /// feet: sole and top, left and right, side by side; other charts: the chosen one
    private var tiles: [Tile] {
        guard chartID == "foot" else { return [Tile(face: face, side: side)] }
        return chart.faces.flatMap { f in [Tile(face: f, side: .left), Tile(face: f, side: .right)] }
    }

    private var focusIndex: Int { tiles.firstIndex { isFocus($0) } ?? 0 }
    private func isFocus(_ t: Tile) -> Bool { tiles.count == 1 || (t.face.id == face.id && t.side == side) }
    private func zones(_ t: Tile) -> [ReflexZone] { t.face.zones.filter { $0.side == nil || $0.side == t.side } }
    /// zoomed out far enough to see every tile
    private var minZoom: CGFloat { tiles.count > 1 ? 1 / CGFloat(tiles.count) * 0.9 : 1 }

    /// a whole screen width per tile at 1×: its margin labels have room and the neighbours stay off-screen
    private func stride(_ size: CGSize) -> CGFloat { size.width }

    /// pan = 0 centres the first tile
    private func tilePan(_ i: Int, _ size: CGSize) -> CGSize {
        CGSize(width: pan.width + CGFloat(i) * stride(size) * zoom, height: pan.height)
    }

    private var focusPan: CGSize { CGSize(width: -CGFloat(focusIndex) * stride(stageSize), height: 0) }

    private func centre(on i: Int, animated: Bool) {
        let target = CGSize(width: -CGFloat(i) * stride(stageSize), height: 0)
        withAnimation(animated ? .snappy(duration: 0.35) : nil) {
            zoom = 1; zoomBase = 1; pan = target; panBase = target
        }
    }

    /// the tile nearest the middle becomes the one the menus talk about
    private func followCentre(_ size: CGSize) {
        guard tiles.count > 1, zoom >= 0.75 else { return }
        let i = Int((-pan.width / (stride(size) * zoom)).rounded())
        let t = tiles[min(max(i, 0), tiles.count - 1)]
        guard !isFocus(t) else { return }
        faceID = t.face.id
        side = t.side
        clear()
    }

    private func tileCaption(_ t: Tile, at x: CGFloat) -> some View {
        Text(settings.name(t.face.label, t.face.labelZh) + " · " + settings.t(t.side == .left ? "Left" : "Right", t.side == .left ? "左" : "右"))
            .font(.caption.weight(.semibold))
            .foregroundStyle(isFocus(t) ? Color.primary : .secondary)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(.regularMaterial, in: .capsule)
            .fixedSize()
            .position(x: x, y: 14)
            .allowsHitTesting(false)
    }

    private func focus(_ s: Side) {
        side = s
        clear()
        centre(on: focusIndex, animated: true)
    }

    private func placeBody() {
        inset.basePanX = 0
        inset.baseZoom = 1
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
        inset.setLayers([.skin, .organs])
        inset.showMeridians(false, ids: nil)
    }

    private func setUp() {
        guard !ready else { return }
        ready = true
        settings.resetViewOptions()
        faceID = initialFace ?? chart.faces[0].id
        side = initialSide ?? .right
        if stageSize != .zero { centre(on: focusIndex, animated: false) }
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
