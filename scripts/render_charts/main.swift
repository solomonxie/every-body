import AppKit
import SwiftUI

// Renders every chart face to PNGs with the app's ChartCanvas: plain, labels (en/zh), one zone selected,
// the mirrored side, and the home tile thumbnail.
// Usage: scripts/render_charts/render.sh [outDir] [zoneId]

@MainActor
func save(_ view: some View, _ size: CGSize, _ url: URL, scale: CGFloat = 2) {
    let r = ImageRenderer(content: view.frame(width: size.width, height: size.height).background(Color.white))
    r.scale = scale
    guard let cg = r.cgImage else { print("render failed", url.path); return }
    try? NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])?.write(to: url)
}

/// Taps a point inside each zone (both sides) and lists zones the hit test doesn't return.
func hitMisses(_ chart: ReflexChart, _ face: ChartFace, _ size: CGSize) -> [String] {
    var out: [String] = []
    for side in Side.allCases {
        let zones = face.zones.filter { $0.side == nil || $0.side == side }
        let toScreen = ChartCanvas.mirror(chart: chart, face: face, side: side)
            .concatenating(ChartCanvas.viewTransform(size: size, chart: chart, zoom: 1, pan: .zero))
        for zone in zones {
            let path = ChartCanvas.zonePath(zone), box = path.boundingRect
            var inside: CGPoint?
            for i in 0..<400 where inside == nil {
                let p = CGPoint(x: box.minX + box.width * CGFloat(i % 20 + 1) / 21, y: box.minY + box.height * CGFloat(i / 20 + 1) / 21)
                if path.contains(p) && !zones.contains(where: { $0.id != zone.id && $0.path == nil && ChartCanvas.zonePath($0).contains(p) }) { inside = p }
            }
            guard let p = inside else { out.append(zone.id + "(no point)"); continue }
            let hit = ChartCanvas.hitTest(p.applying(toScreen), size: size, chart: chart, face: face, side: side, zones: zones, zoom: 1, pan: .zero)
            if hit?.id != zone.id { out.append("\(zone.id)→\(hit?.id ?? "nil")") }
        }
    }
    return out
}

@main
struct Main {
    @MainActor static func main() {
        let a = CommandLine.arguments
        let out = URL(fileURLWithPath: a.count > 1 ? a[1] : "build/charts")
        let pick = a.count > 2 ? a[2] : ""
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let big = CGSize(width: 520, height: 620)
        for chart in Catalog.charts.charts {
            for face in chart.faces {
                let side = face.drawnSide
                let other: Side = side == .left ? .right : .left
                let zones = face.zones.filter { $0.side == nil || $0.side == side }
                let sel = zones.first { $0.id == pick } ?? zones.first { $0.path != nil } ?? zones.first
                let name = "\(chart.id)-\(face.id)"
                func canvas(_ side: Side, _ sel: String?, _ labels: Bool, zh: Bool = false) -> ChartCanvas {
                    ChartCanvas(chart: chart, face: face, side: side, zones: face.zones.filter { $0.side == nil || $0.side == side },
                                selectedID: sel, showLabels: labels, zh: zh, flagged: [], zoom: 1, pan: .zero)
                }
                save(canvas(side, nil, false), big, out.appendingPathComponent("\(name).png"))
                save(canvas(side, nil, true), big, out.appendingPathComponent("\(name)-labels.png"), scale: 3)
                save(canvas(side, nil, true, zh: true), big, out.appendingPathComponent("\(name)-labels-zh.png"), scale: 3)
                save(canvas(side, sel?.id, false), big, out.appendingPathComponent("\(name)-selected.png"))
                save(canvas(other, sel?.id, false), big, out.appendingPathComponent("\(name)-mirrored.png"))
                if face.id == chart.faces[0].id {
                    save(canvas(side, nil, false).padding(6).background(Color(hex: "#D98BA8").opacity(0.35)),
                         CGSize(width: 110, height: 110), out.appendingPathComponent("\(chart.id)-tile.png"))
                }
                print(name, zones.count, "zones", "hit misses:", hitMisses(chart, face, big))
            }
        }
    }
}
