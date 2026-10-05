import SwiftUI

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

    private static let skinLight = Color(hex: "#FAE3D0")
    private static let skinDark = Color(hex: "#EDC4A6")
    private static let rim = Color(hex: "#B98468")
    private static let edge = Color(hex: "#A87C64")
    private static let crease = Color(hex: "#B07F66")
    private static let ink = Color(hex: "#2B2250")
    private static let warn = Color(hex: "#D8434B")
    private static let tones: [String: Color] = [
        "light": Color(hex: "#FFF1E6").opacity(0.75),
        "shade": Color(hex: "#E2B394").opacity(0.45),
        "deep": Color(hex: "#C98F72").opacity(0.5),
        "nail": Color(hex: "#F7DDD6"),
    ]

    var body: some View {
        Canvas { ctx, size in
            let view = Self.viewTransform(size: size, chart: chart, zoom: zoom, pan: pan)
            var drawing = ctx
            drawing.transform = Self.mirror(chart: chart, face: face, side: side).concatenating(view)
            let skin = Self.silhouette(face)
            let box = skin.boundingRect
            let fine = 1 / max(view.a, 0.01)

            drawing.fill(skin, with: .linearGradient(Gradient(colors: [Self.skinLight, Self.skinDark]),
                                                     startPoint: CGPoint(x: box.minX, y: box.minY),
                                                     endPoint: CGPoint(x: box.maxX, y: box.maxY)))
            // a soft rim inside the edge plus blurred mounds and hollows give the flat drawing volume
            for (tones, blur) in [(["shade", "light"], 4.5), (["deep"], 1.5)] {
                drawing.drawLayer { g in
                    g.clip(to: skin)
                    g.addFilter(.blur(radius: max(view.a, 0.2) * blur))
                    if blur > 2 { g.stroke(skin, with: .color(Self.rim.opacity(0.45)), lineWidth: 9) }
                    for tone in tones {
                        for shape in face.outline where shape.tone == tone {
                            g.fill(Self.outlinePath(shape), with: .color(Self.tones[tone] ?? .clear))
                        }
                    }
                }
            }
            var inside = drawing
            inside.clip(to: skin)
            for shape in face.outline where shape.tone == "nail" {
                let p = Self.outlinePath(shape)
                inside.fill(p, with: .color(Self.tones["nail"] ?? .clear))
                inside.stroke(p, with: .color(Self.edge.opacity(0.6)), lineWidth: 0.8)
            }
            for d in face.bones {
                inside.stroke(SVGPath.parse(d), with: .color(Self.crease.opacity(0.35)), style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
            }
            for d in face.guides {
                inside.stroke(SVGPath.parse(d), with: .color(Self.crease.opacity(0.7)),
                              style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
            }
            for zone in zones where zone.path != nil {
                drawZone(zone, in: &inside)
            }
            drawing.stroke(skin, with: .color(Self.edge), lineWidth: max(1.4, fine * 0.8))
            // points sit on top and may hang over the edge
            for zone in zones where zone.path == nil {
                drawZone(zone, in: &drawing)
            }
            drawLabels(ctx, view: view)
        }
    }

    private func drawZone(_ zone: ReflexZone, in g: inout GraphicsContext) {
        let isSelected = zone.id == selectedID
        let dimmed = selectedID != nil && !isSelected
        let color = Self.tint(zone, in: face)
        let p = Self.zonePath(zone)
        let warn = flagged.contains(zone.id)
        if zone.path != nil {
            g.fill(p, with: .color(color.opacity(isSelected ? 0.85 : dimmed ? 0.12 : 0.36)))
            g.stroke(p, with: .color(isSelected ? Self.ink : warn ? Self.warn : color.opacity(dimmed ? 0.3 : 0.75)),
                     style: StrokeStyle(lineWidth: isSelected ? 2 : warn ? 1.4 : 0.7, lineJoin: .round, dash: warn && !isSelected ? [3, 2] : []))
        } else {
            g.fill(p, with: .color(color.opacity(isSelected ? 1 : dimmed ? 0.35 : 0.9)))
            g.stroke(p, with: .color(isSelected ? Self.ink : warn ? Self.warn : .white),
                     style: StrokeStyle(lineWidth: isSelected ? 2 : 1.2, dash: warn && !isSelected ? [3, 2] : []))
        }
    }

    private func drawLabels(_ ctx: GraphicsContext, view: CGAffineTransform) {
        var labels = ctx
        labels.transform = view
        let mirror = Self.mirror(chart: chart, face: face, side: side)
        let base = chart.labelSize * 0.8
        func name(_ zone: ReflexZone) -> String {
            zh ? zone.label ?? String(zone.nameZh.split(separator: "·").first ?? "") : Self.shortName(zone.name)
        }
        func text(_ s: String, _ size: CGFloat) -> Text { Text(s).font(.system(size: size)).foregroundStyle(Self.ink) }
        func measure(_ s: String, _ size: CGFloat) -> CGSize { labels.resolve(text(s, size)).measure(in: CGSize(width: 400, height: 100)) }

        var callouts: [(zone: ReflexZone, box: CGRect)] = []
        for zone in zones where showLabels || zone.id == selectedID {
            let box = Self.zonePath(zone).boundingRect.applying(mirror)
            if zone.id == selectedID {
                // selected name sits on a white tag above the zone
                let resolved = labels.resolve(Text(zh ? zone.nameZh : zone.name)
                    .font(.system(size: chart.labelSize * 1.15, weight: .bold)).foregroundStyle(Self.ink))
                let size = resolved.measure(in: CGSize(width: 400, height: 100))
                let half = size.width / 2 + 4
                let lo = chart.viewBox[0] + half, hi = chart.viewBox[0] + chart.viewBox[2] - half
                let at = CGPoint(x: min(max(box.midX, lo), max(lo, hi)), y: max(box.minY - size.height * 0.75, chart.viewBox[1] + size.height))
                labels.fill(Path(roundedRect: CGRect(x: at.x - half, y: at.y - size.height / 2 - 2, width: half * 2, height: size.height + 4),
                                 cornerRadius: 4), with: .color(.white.opacity(0.92)))
                labels.draw(resolved, at: at, anchor: .center)
            } else if zone.path == nil {
                labels.draw(labels.resolve(text(name(zone), base)), at: CGPoint(x: box.midX, y: box.maxY + chart.labelSize * 0.6), anchor: .center)
            } else {
                let fit = measure(name(zone), base)
                let k = min(1, box.width * 0.92 / max(fit.width, 1), box.height * 0.9 / max(fit.height, 1))
                if k < 0.6 { callouts.append((zone, box)) }
                else { labels.draw(labels.resolve(text(name(zone), base * k)), at: CGPoint(x: box.midX, y: box.midY), anchor: .center) }
            }
        }
        drawCallouts(labels, callouts, size: base, name: name, text: text, measure: measure)
    }

    /// Zones too small to hold their name get it in a side margin, on a line to the zone.
    private func drawCallouts(_ context: GraphicsContext, _ items: [(zone: ReflexZone, box: CGRect)], size: CGFloat,
                              name: (ReflexZone) -> String, text: (String, CGFloat) -> Text, measure: (String, CGFloat) -> CGSize) {
        guard !items.isEmpty else { return }
        var g = context
        let (vx, vy, vw, vh) = (chart.viewBox[0], chart.viewBox[1], chart.viewBox[2], chart.viewBox[3])
        let mirror = Self.mirror(chart: chart, face: face, side: side)
        let drawn = zones.map { Self.zonePath($0).boundingRect.applying(mirror) }.reduce(CGRect.null) { $0.union($1) }
        let pad: CGFloat = 6
        let leftRoom = max(0, drawn.minX - vx - 2 * pad), rightRoom = max(0, vx + vw - drawn.maxX - 2 * pad)
        let gap = size * 0.5
        for onRight in [false, true] {
            let room = onRight ? rightRoom : leftRoom
            let column = items.filter { ($0.box.midX > drawn.midX) == onRight }.sorted { $0.box.midY < $1.box.midY }
            guard !column.isEmpty, room > size else { continue }
            let widest = column.map { measure(name($0.zone), size).width }.max() ?? 1
            let k = min(1, room / max(widest, 1))
            let h = measure("Ag", size * k).height * 1.1
            var ys = column.map { $0.box.midY }
            for i in ys.indices.dropFirst() { ys[i] = max(ys[i], ys[i - 1] + h) }
            let overflow = (ys.last ?? 0) + h / 2 - (vy + vh - pad)
            if overflow > 0 { ys = ys.map { $0 - overflow } }
            for i in ys.indices.reversed().dropFirst() { ys[i] = min(ys[i], ys[i + 1] - h) }
            let x = onRight ? vx + vw - pad : vx + pad
            for (item, y) in zip(column, ys) {
                let w = measure(name(item.zone), size * k).width
                let edge = CGPoint(x: onRight ? x - w - gap : x + w + gap, y: y)
                let target = CGPoint(x: item.box.midX, y: item.box.midY)
                var line = Path()
                line.move(to: edge)
                line.addLine(to: target)
                g.stroke(line, with: .color(Self.ink.opacity(0.55)), lineWidth: 0.7)
                g.fill(Path(ellipseIn: CGRect(x: target.x - 1.6, y: target.y - 1.6, width: 3.2, height: 3.2)), with: .color(Self.ink))
                g.draw(g.resolve(text(name(item.zone), size * k)), at: CGPoint(x: x, y: y), anchor: onRight ? .trailing : .leading)
            }
        }
    }

    /// Group colour, a shade lighter or darker per zone so neighbours in one group stay apart.
    static func tint(_ zone: ReflexZone, in face: ChartFace) -> Color {
        let hex = Catalog.charts.groups[zone.group]?.color ?? "#999999"
        let v = UInt64(hex.dropFirst(), radix: 16) ?? 0x999999
        let index = face.zones.filter { $0.group == zone.group && $0.path != nil }.firstIndex { $0.id == zone.id } ?? 0
        let t = zone.path == nil ? 0 : [0, 0.22, -0.16, 0.1, -0.08, 0.3][index % 6]
        func channel(_ shift: UInt64) -> Double {
            let c = Double((v >> shift) & 0xFF) / 255
            return t > 0 ? c + (1 - c) * t : c * (1 + t)
        }
        return Color(red: channel(16), green: channel(8), blue: channel(0))
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

    static func zonePath(_ zone: ReflexZone) -> Path {
        if let d = zone.path { return SVGPath.parse(d) }
        var p = Path()
        for e in zone.shapes ?? [] { p.addPath(ellipse(e)) }
        return p
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

    /// The untoned outline shapes as one path.
    static func silhouette(_ face: ChartFace) -> Path {
        var p = Path()
        for shape in face.outline where shape.tone == nil { p.addPath(outlinePath(shape)) }
        return p
    }

    /// Smallest zone under a tap; thin zones and points get a little slack.
    static func hitTest(_ point: CGPoint, size: CGSize, chart: ReflexChart, face: ChartFace, side: Side, zones: [ReflexZone],
                        zoom: CGFloat, pan: CGSize) -> ReflexZone? {
        let view = viewTransform(size: size, chart: chart, zoom: zoom, pan: pan)
        let p = point.applying(mirror(chart: chart, face: face, side: side).concatenating(view).inverted())
        let slack = 8 / max(view.a, 0.01)
        func area(_ z: ReflexZone) -> CGFloat { let b = zonePath(z).boundingRect; return b.width * b.height }
        let paths = zones.map { ($0, zonePath($0)) }
        if let inside = paths.filter({ $0.1.contains(p) }).min(by: { area($0.0) < area($1.0) }) { return inside.0 }
        let near = paths.filter { $0.1.strokedPath(StrokeStyle(lineWidth: slack * 2)).contains(p) }
        return near.min { area($0.0) < area($1.0) }?.0
    }
}
