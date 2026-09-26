import SwiftUI

/// The single home page: search, maps, illustrations, settings.
struct ExploreView: View {
    @Environment(Settings.self) private var settings
    @State private var query = ""
    @State private var showAllBody = false

    private struct Tile: Identifiable {
        let id: String
        let name: Bilingual
        let color: String
        let route: Route
        var chart: String? = nil
    }

    /// acupressure: the 3D point map and the three 2D reflex charts
    private var reflexTiles: [Tile] {
        let map = Catalog.systems.first { $0.id == "acupoint-reflex-map" }.map {
            Tile(id: $0.id, name: Bilingual($0.name, $0.nameZh), color: $0.color, route: .viewer(system: $0.id))
        }
        return (map.map { [$0] } ?? []) + [
            Tile(id: "hand-chart", name: Bilingual("Hand chart", "手部反射区"), color: "#E8A87C", route: .chart(id: "hand"), chart: "hand"),
            Tile(id: "foot-chart", name: Bilingual("Foot chart", "足底反射区"), color: "#C9A06A", route: .chart(id: "foot"), chart: "foot"),
            Tile(id: "ear-chart", name: Bilingual("Ear points", "耳穴"), color: "#D98BA8", route: .chart(id: "ear"), chart: "ear"),
        ]
    }

    /// anatomy: the body systems
    private var bodyTiles: [Tile] {
        Catalog.systems.filter { $0.id != "acupoint-reflex-map" }.map {
            Tile(id: $0.id, name: Bilingual($0.name, $0.nameZh), color: $0.color, route: .viewer(system: $0.id))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    grid(settings.t("Human body", "人体"), bodyTiles, expanded: $showAllBody)
                    grid(settings.t("Reflex & acupressure", "反射区与穴位"), reflexTiles, expanded: nil)
                    IllustrationsSection()
                    SettingsSection()
                } else {
                    SearchResults(query: query)
                }
            }
            .padding(16)
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: settings.t("Body parts, illnesses, procedures", "身体部位、疾病、操作"))
        .navigationTitle("Every Body")
        .profileToolbar()
    }

    /// titled 3-column grid; with `expanded`, shows two rows until "Show more"
    private func grid(_ title: String, _ tiles: [Tile], expanded: Binding<Bool>?) -> some View {
        let columns = 3
        let limit = columns * 2
        let open = expanded?.wrappedValue ?? true
        let shown = open ? tiles : Array(tiles.prefix(limit))
        return VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
                ForEach(shown) { tile in
                    NavigationLink(value: tile.route) { TileView(tile: tile) }
                        .buttonStyle(.plain)
                }
            }
            if let expanded, tiles.count > limit {
                Button {
                    withAnimation { expanded.wrappedValue.toggle() }
                } label: {
                    Label(open ? settings.t("Show less", "收起") : settings.t("Show more (\(tiles.count - limit))", "显示更多（\(tiles.count - limit)）"),
                          systemImage: open ? "chevron.up" : "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
        }
    }

    private struct TileView: View {
        let tile: Tile
        @Environment(Settings.self) private var settings

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    Color(hex: tile.color).opacity(tile.chart == nil ? 1 : 0.35)
                    if let id = tile.chart, let chart = Catalog.chart(id) {
                        ChartCanvas(chart: chart, face: chart.faces[0], side: chart.faces[0].drawnSide,
                                    zones: chart.faces[0].zones.filter { $0.side == nil || $0.side == chart.faces[0].drawnSide },
                                    selectedID: nil, showLabels: false, zoom: 1, pan: .zero)
                            .padding(6)
                    } else if UIImage(named: "tile-\(tile.id)") != nil {
                        Image("tile-\(tile.id)").resizable().scaledToFill()
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 8))
                Text(settings.t(tile.name)).font(.caption.weight(.semibold)).lineLimit(2)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1), in: .rect(cornerRadius: 14))
        }
    }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(.title3.weight(.bold))
    }
}
