import SwiftUI

struct ExploreView: View {
    private struct Tile: Identifiable {
        let id: String
        let name: String
        let color: String
        let route: Route
        let interactive: Bool
    }

    private var tiles: [Tile] {
        let systems = Catalog.systems.map {
            Tile(id: $0.id, name: $0.name, color: $0.color, route: .viewer(system: $0.id), interactive: Catalog.points[$0.id] != nil)
        }
        let charts = [
            Tile(id: "hand-chart", name: "Hand Chart 手部反射区", color: "#E8A87C", route: .chart(id: "hand"), interactive: true),
            Tile(id: "foot-chart", name: "Foot Chart 足底反射区", color: "#C9A06A", route: .chart(id: "foot"), interactive: true),
            Tile(id: "ear-chart", name: "Ear Points 耳穴", color: "#D98BA8", route: .chart(id: "ear"), interactive: true),
        ]
        return [systems[0]] + charts + systems.dropFirst()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                NavigationLink(value: Route.search) {
                    Label("Search parts, points, zones, topics 搜索", systemImage: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.secondary.opacity(0.12), in: .rect(cornerRadius: 14))
                }
                Text("Pick a system or chart. ▶ tiles are interactive.")
                    .font(.footnote).foregroundStyle(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(tiles) { tile in
                        NavigationLink(value: tile.route) { TileView(tile: tile) }
                            .buttonStyle(.plain)
                    }
                }
                IllustrationsSection()
            }
            .padding(16)
        }
        .navigationTitle("Explore")
    }

    private struct TileView: View {
        let tile: Tile

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Color(hex: tile.color)
                    if UIImage(named: "tile-\(tile.id)") != nil {
                        Image("tile-\(tile.id)").resizable().scaledToFill()
                    }
                    if tile.interactive {
                        Image(systemName: "play.fill").font(.caption).foregroundStyle(.white).padding(6)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 8))
                Text(tile.name).font(.caption.weight(.semibold)).lineLimit(2)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1), in: .rect(cornerRadius: 14))
        }
    }
}
