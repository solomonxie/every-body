import SwiftUI

/// The single home page: search, maps, illustrations, settings.
struct ExploreView: View {
    @Environment(Settings.self) private var settings
    @State private var query = ""

    var body: some View {
        ScrollView {
            HomeContent(query: $query)
                .padding(.horizontal, Space.l)
                .padding(.top, Space.s)
                .padding(.bottom, Space.xxl)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Color.page)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: settings.t("Body parts, illnesses, procedures", "身体部位、疾病、操作"))
        .onSubmit(of: .search) { settings.remember(search: query) }
        .navigationTitle("Every Body")
        .profileToolbar()
    }
}

/// Reads `isSearching`, which only exists below `.searchable`.
struct HomeContent: View {
    @Binding var query: String
    @Environment(\.isSearching) private var searching
    @Environment(Settings.self) private var settings
    @State private var showAllBody = false

    var body: some View {
        let empty = query.trimmingCharacters(in: .whitespaces).isEmpty
        VStack(alignment: .leading, spacing: Space.xl) {
            if !empty {
                SearchResults(query: query)
            } else if searching {
                SearchSuggestions(query: $query)
            } else {
                TileGrid(title: settings.t("Acupuncture & reflexology", "针灸与反射区"), tiles: Tile.reflex, expanded: nil)
                TileGrid(title: settings.t("Human body", "人体"), tiles: Tile.body, expanded: $showAllBody, rows: 1)
                IllustrationsSection()
                PregnancySection()
                ChildrenSection()
                SettingsSection()
            }
        }
        .animation(.snappy(duration: 0.2), value: searching)
    }
}

struct Tile: Identifiable {
    let id: String
    let name: Bilingual
    let color: String
    let route: Route
    var chart: String? = nil

    /// anatomy: the body systems
    @MainActor static var body: [Tile] {
        // the full-body figure comes last, after the systems
        let systems = Catalog.systems.filter { !Tile.pointSystems.contains($0.id) }
        return (systems.filter { $0.id != "body" } + systems.filter { $0.id == "body" }).map {
            Tile(id: $0.id, name: Bilingual($0.name, $0.nameZh), color: $0.color, route: .viewer(system: $0.id))
        }
    }

    /// systems shown as point maps, not anatomy
    static let pointSystems: Set<String> = ["acupoint-reflex-map", "acupuncture"]

    /// acupuncture, the 3D reflex point map and the three 2D reflex charts
    @MainActor static var reflex: [Tile] {
        let acupuncture = Catalog.system("acupuncture").map {
            Tile(id: $0.id, name: Bilingual("Acupuncture", "针灸穴位"), color: $0.color, route: .viewer(system: $0.id))
        }
        let map = Catalog.system("acupoint-reflex-map").map {
            Tile(id: $0.id, name: Bilingual("3D point map", "3D 穴位图"), color: $0.color, route: .viewer(system: $0.id))
        }
        return [acupuncture, map].compactMap { $0 } + [
            Tile(id: "hand-chart", name: Bilingual("Hand chart", "手部反射区"), color: "#E8A87C", route: .chart(id: "hand"), chart: "hand"),
            Tile(id: "foot-chart", name: Bilingual("Foot chart", "足底反射区"), color: "#C9A06A", route: .chart(id: "foot"), chart: "foot"),
            Tile(id: "ear-chart", name: Bilingual("Ear points", "耳穴"), color: "#D98BA8", route: .chart(id: "ear"), chart: "ear"),
        ]
    }
}

/// Titled grid; with `expanded`, shows two rows until "Show all".
private struct TileGrid: View {
    let title: String
    let tiles: [Tile]
    let expanded: Binding<Bool>?
    /// rows shown before "Show more"
    var rows = 2
    @Environment(Settings.self) private var settings
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let columns = typeSize.isAccessibilitySize ? 2 : 3
        let limit = columns * rows
        let open = expanded?.wrappedValue ?? true
        let shown = open ? tiles : Array(tiles.prefix(limit))
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader(title: title) {
                if let expanded, tiles.count > limit {
                    Button {
                        withAnimation(.snappy) { expanded.wrappedValue.toggle() }
                    } label: {
                        HStack(spacing: Space.xs) {
                            Text(open ? settings.t("Show less", "收起") : settings.t("Show all \(tiles.count)", "全部 \(tiles.count) 个"))
                            Image(systemName: "chevron.down").rotationEffect(.degrees(open ? 180 : 0))
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: minTap)
                        .contentShape(.rect)
                    }
                    .sensoryFeedback(.selection, trigger: open)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.m, alignment: .top), count: columns), spacing: Space.m) {
                ForEach(shown) { tile in
                    NavigationLink(value: tile.route) { TileView(tile: tile) }
                        .buttonStyle(PressableStyle())
                }
            }
        }
    }
}

private struct TileView: View {
    let tile: Tile
    @Environment(Settings.self) private var settings

    var body: some View {
        let color = Color(hex: tile.color)
        VStack(alignment: .leading, spacing: Space.s) {
            ZStack {
                if tile.chart == nil {
                    LinearGradient(colors: [color.opacity(0.18), color.opacity(0.42)], startPoint: .top, endPoint: .bottom)
                } else {
                    Color(hex: "#FBF6F1")
                }
                thumbnail(color)
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(.rect(cornerRadius: Radius.tile, style: .continuous))
            Text(settings.t(tile.name))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2, reservesSpace: true)
                .padding(.horizontal, Space.xs)
        }
        .padding(Space.s)
        .background(Color.card, in: .rect(cornerRadius: Radius.card, style: .continuous))
        .contentShape(.rect(cornerRadius: Radius.card))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(settings.t(tile.name))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder private func thumbnail(_ color: Color) -> some View {
        if let id = tile.chart, let chart = Catalog.chart(id) {
            let face = chart.faces[0]
            ChartCanvas(chart: chart, face: face, side: face.drawnSide,
                        zones: face.zones.filter { $0.side == nil || $0.side == face.drawnSide },
                        selectedID: nil, showLabels: false, zoom: 1, pan: .zero)
                .padding(Space.s)
        } else if tile.id == "acupoint-reflex-map" {
            ReflexMapThumb()
        } else if tile.id == "acupuncture" {
            AcupunctureThumb()
        } else if UIImage(named: "tile-\(tile.id)") != nil {
            Image("tile-\(tile.id)").resizable().scaledToFill()
        } else {
            Image(systemName: "figure.stand").font(.largeTitle).foregroundStyle(color)
        }
    }
}

/// A figure, a pressed foot point and the organ it's said to reach — the app icon's idea.
struct ReflexMapThumb: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let foot = CGPoint(x: geo.size.width * 0.58, y: geo.size.height * 0.86)
            let organ = CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.44)
            ZStack {
                LinearGradient(colors: [Color(hex: "#7A5CB0"), Color(hex: "#3B2A6E")], startPoint: .top, endPoint: .bottom)
                Image(systemName: "figure.stand")
                    .resizable().scaledToFit()
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(height: s * 0.82)
                Path { p in
                    p.move(to: foot)
                    p.addQuadCurve(to: organ, control: CGPoint(x: geo.size.width * 0.82, y: geo.size.height * 0.62))
                }
                .stroke(Color(hex: "#FFD166"), style: StrokeStyle(lineWidth: max(1.5, s * 0.02), lineCap: .round, dash: [s * 0.03, s * 0.04]))
                Circle().fill(Color(hex: "#FFD166")).frame(width: s * 0.1).position(foot)
                Circle().fill(Color(hex: "#4ECB71")).frame(width: s * 0.13)
                    .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: max(1, s * 0.012)))
                    .position(organ)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A figure with meridian lines and points, and a needle at the elbow.
struct AcupunctureThumb: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, s = min(w, h)
            let line = max(1.2, s * 0.018)
            let elbow = CGPoint(x: w * 0.66, y: h * 0.5)
            ZStack {
                LinearGradient(colors: [Color(hex: "#2A9384"), Color(hex: "#0F4D46")], startPoint: .top, endPoint: .bottom)
                Image(systemName: "figure.stand")
                    .resizable().scaledToFit()
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(height: s * 0.82)
                // two channels down the body, dotted with points
                ForEach(Array(zip([Color(hex: "#F2A20C"), Color(hex: "#5B8DEF")], [0.46, 0.54])), id: \.1) { color, x in
                    Path { p in
                        p.move(to: CGPoint(x: w * x, y: h * 0.3))
                        p.addCurve(to: CGPoint(x: w * x, y: h * 0.86), control1: CGPoint(x: w * (x + (x - 0.5) * 0.6), y: h * 0.5),
                                   control2: CGPoint(x: w * x, y: h * 0.7))
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                    ForEach([0.36, 0.52, 0.7], id: \.self) { y in
                        Circle().fill(color).frame(width: s * 0.055).position(x: w * x + (x - 0.5) * w * 0.12 * (y < 0.6 ? 1 : 0.4), y: h * y)
                    }
                }
                // the needle: a thin shaft into a lit point, a coiled handle above
                Path { p in
                    p.move(to: elbow)
                    p.addLine(to: CGPoint(x: w * 0.86, y: h * 0.2))
                }
                .stroke(Color(hex: "#E6E9EE"), style: StrokeStyle(lineWidth: max(1, s * 0.012), lineCap: .round))
                Path { p in
                    p.move(to: CGPoint(x: w * 0.8, y: h * 0.285))
                    p.addLine(to: CGPoint(x: w * 0.9, y: h * 0.14))
                }
                .stroke(Color(hex: "#FFD166"), style: StrokeStyle(lineWidth: max(2, s * 0.045), lineCap: .round))
                Circle().fill(Color(hex: "#FFD166")).frame(width: s * 0.1)
                    .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: max(1, s * 0.012)))
                    .position(elbow)
            }
        }
        .accessibilityHidden(true)
    }
}
