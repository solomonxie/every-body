import SwiftUI

/// One palette for the health-topic scenes (blood, heart, brain, airways, gut).
enum Tone {
    static let ink = hex("#34303A"), sub = hex("#6B6570"), faint = hex("#A49EA8"), rule = hex("#E4DFD8")
    static let paper = hex("#FBF9F6"), panel = hex("#F4F0EA")
    static let red = hex("#D63F48"), green = hex("#2A9A58"), amber = hex("#E0892B"), blue = hex("#3A78CF"), purple = hex("#6C4F9E")
    static let artery = hex("#C8323C"), arteryHi = hex("#E86A70"), vein = hex("#4F6DB5"), veinHi = hex("#7F97D6")
    static let blood = hex("#F6D4D4"), cell = hex("#C8323C")
    static let muscle = hex("#C9474F"), muscleHi = hex("#E6777B"), muscleLo = hex("#9E2F3A")
    static let fat = hex("#F2C94C"), fatLo = hex("#D9A53A"), sugar = hex("#E8A21B"), insulin = hex("#3A78CF")
    static let organLine = hex("#8A3B45"), label = hex("#5E4B52")
}

/// colour scaled in brightness (k < 1 darker, k > 1 lighter), opaque
func dim(_ c: Color, _ k: Double) -> Color {
    let r = c.resolve(in: EnvironmentValues())
    func f(_ v: Float) -> Double { k <= 1 ? Double(v) * k : Double(v) + (1 - Double(v)) * (k - 1) * 3 }
    return Color(red: f(r.red), green: f(r.green), blue: f(r.blue))
}

extension Sketch {
    // MARK: shading

    /// fill with a linear gradient from `a` (top-left) to `b` (bottom-right) across the path's box
    mutating func shade(_ p: Path, _ a: Color, _ b: Color, stroke: Color? = nil, lw: Double = 1, vertical: Bool = false, opacity: Double = 1) {
        let r = p.boundingRect
        let end = vertical ? CGPoint(x: r.minX, y: r.maxY) : CGPoint(x: r.maxX, y: r.maxY)
        ctx.fill(p, with: .linearGradient(Gradient(colors: [a.opacity(opacity), b.opacity(opacity)]), startPoint: r.origin, endPoint: end))
        if let stroke { ctx.stroke(p, with: .color(stroke.opacity(opacity)), style: StrokeStyle(lineWidth: lw, lineJoin: .round)) }
    }

    mutating func shade(_ d: String, _ a: Color, _ b: Color, stroke: Color? = nil, lw: Double = 1, vertical: Bool = false, opacity: Double = 1) {
        shade(SVGPath.parse(d), a, b, stroke: stroke, lw: lw, vertical: vertical, opacity: opacity)
    }

    /// soft round glow, strongest in the middle
    mutating func glow(_ x: Double, _ y: Double, _ r: Double, _ c: Color, opacity: Double = 0.5) {
        let p = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
        ctx.fill(p, with: .radialGradient(Gradient(colors: [c.opacity(opacity), c.opacity(0)]), center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r))
    }

    /// copy that only draws inside the path
    func clipped(to p: Path) -> Sketch {
        var g = self
        g.ctx.clip(to: p)
        return g
    }

    // MARK: cards and labels

    /// white card with a soft drop shadow; optional coloured strip on the left
    mutating func card(_ x: Double, _ y: Double, _ w: Double, _ h: Double, r: Double = 10, accent: Color? = nil, fill: Color = .white) {
        softCard(x, y, w, h, r: max(r, 12), fill: fill)
        if let accent {
            var g = clipped(to: Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: max(r, 12)))
            g.rect(x, y, 4, h, fill: accent)
        }
    }

    /// small caps-style section title
    mutating func caption(_ en: String, _ zh: String, _ x: Double, _ y: Double, color: Color = Tone.sub, anchor: Anchor = .start) {
        label(en.uppercased(), zh, x, y, size: 7.5, color: color, anchor: anchor, bold: true)
    }

    /// label with a leader line from the feature at `at`; the line ends beside the text
    mutating func callout(_ en: String, _ zh: String, at p: CGPoint, _ x: Double, _ y: Double, anchor: Anchor = .start,
                          color: Color = Tone.label, size: Double = 8.5, bold: Bool = true, dot: Bool = true) {
        let w = width(en, zh, size: size, bold: bold)
        let x0 = anchor == .start ? x : anchor == .middle ? x - w / 2 : x - w
        let d: String
        if anchor == .middle {
            let ly = p.y < y ? y - size - 1 : y + 3
            d = "M \(p.x) \(p.y) L \(x) \(ly)"
        } else {
            // attach on the side of the text that faces the feature
            let right = p.x > x0 + w / 2, ex = right ? x0 + w + 3 : x0 - 3, ly = y - size * 0.35
            let knee = CGPoint(x: ex + (right ? 6 : -6), y: ly)
            d = "M \(p.x) \(p.y) L \(knee.x) \(knee.y) L \(ex) \(ly)"
        }
        // white halo keeps the leader readable where it crosses a busy drawing
        path(d, stroke: .white, lw: 2.2, opacity: 0.6)
        path(d, stroke: color.opacity(0.75), lw: 0.8)
        if dot { circle(p.x, p.y, 2.1, fill: color, stroke: .white, lw: 0.9) }
        label(en, zh, x, y, size: size, color: color, anchor: anchor, bold: bold)
    }

    /// rounded pill with text, for states like "normal" / "high"
    mutating func pill(_ en: String, _ zh: String, _ x: Double, _ y: Double, color: Color, size: Double = 8.5, anchor: Anchor = .start, filled: Bool = true) {
        let txt = ctx.resolve(Text(t(en, zh)).font(.system(size: size, weight: .bold)).foregroundStyle(filled ? .white : color))
        let m = txt.measure(in: CGSize(width: 300, height: 100))
        let w = m.width + 12, hh = m.height + 3
        let x0 = anchor == .start ? x : anchor == .middle ? x - w / 2 : x - w
        rect(x0, y - hh / 2, w, hh, r: hh / 2, fill: filled ? color : color.opacity(0.12))
        ctx.draw(txt, at: CGPoint(x: x0 + w / 2, y: y), anchor: .center)
    }

    /// width of a label in the current language
    func width(_ en: String, _ zh: String, size: Double, bold: Bool = false) -> Double {
        ctx.resolve(Text(t(en, zh)).font(.system(size: size, weight: bold ? .bold : .regular))).measure(in: CGSize(width: 400, height: 100)).width
    }

    // MARK: zoom lens

    /// magnifier: a ring on the body at `from`, a soft cone, and a big white circle; returns a sketch clipped to it
    mutating func lens(_ c: CGPoint, _ r: Double, from f: CGPoint, _ fr: Double, fill: Color = .white, ring: Color = hex("#C4BCCB")) -> Sketch {
        let d = CGPoint(x: c.x - f.x, y: c.y - f.y), dist = max(1, hypot(d.x, d.y)), u = CGPoint(x: d.x / dist, y: d.y / dist)
        let n = CGPoint(x: -u.y, y: u.x)
        var cone = Path()
        cone.addLines([CGPoint(x: f.x + n.x * fr, y: f.y + n.y * fr), CGPoint(x: c.x + n.x * r, y: c.y + n.y * r),
                       CGPoint(x: c.x - n.x * r, y: c.y - n.y * r), CGPoint(x: f.x - n.x * fr, y: f.y - n.y * fr)])
        cone.closeSubpath()
        shape(cone, fill: ring, opacity: 0.16)
        circle(f.x, f.y, fr, stroke: ring, lw: 1.2)
        circle(c.x, c.y + 3, r, fill: Palette.shadow)
        circle(c.x, c.y, r, fill: fill)
        return clipped(to: Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)))
    }

    mutating func lensRing(_ c: CGPoint, _ r: Double, ring: Color = hex("#C4BCCB")) {
        circle(c.x, c.y, r, stroke: ring, lw: 1.5)
    }

    // MARK: readouts

    /// Horizontal scale with coloured bands and a pointer at `value`. Bands: (upper bound, colour, en, zh).
    mutating func bandScale(_ x: Double, _ y: Double, _ w: Double, lo: Double, hi: Double, value: Double,
                            bands: [(Double, Color, String, String)], ticks: [Double] = [], format: String = "%g", h: Double = 6) {
        func px(_ v: Double) -> Double { x + (v.clamped(lo, hi) - lo) / (hi - lo) * w }
        var start = lo
        var g = clipped(to: Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: h / 2))
        for b in bands {
            g.rect(px(start), y, px(min(b.0, hi)) - px(start), h, fill: b.1)
            start = b.0
        }
        start = lo
        for b in bands where !b.2.isEmpty {
            let mid = (px(start) + px(min(b.0, hi))) / 2
            label(b.2, b.3, mid, y + h + 17, size: 6.5, color: b.1, anchor: .middle, bold: true)
            start = b.0
        }
        for tk in ticks { text(String(format: format, tk), px(tk), y + h + 8, size: 6.5, color: Tone.sub, anchor: .middle) }
        let v = px(value)
        path("M \(v - 4.5) \(y - 6) L \(v + 4.5) \(y - 6) L \(v) \(y + 1) Z", fill: Tone.ink)
        line(v, y, v, y + h, stroke: .white, lw: 1.5)
    }

    /// thin track with a filled part; colour by value
    mutating func meterBar(_ x: Double, _ y: Double, _ w: Double, _ v: Double, color: Color, h: Double = 6) {
        rect(x, y, w, h, r: h / 2, fill: hex("#ECE8E3"))
        if v > 0.01 { rect(x, y, max(h, w * v.clamped(0, 1)), h, r: h / 2, fill: color) }
    }

    /// stopwatch face; the red sector is the time elapsed (one lap = 60 min, extra hours stack as dots)
    mutating func stopwatch(_ c: CGPoint, _ r: Double, minutes: Double, color: Color) {
        rect(c.x - 3, c.y - r - 6, 6, 5, r: 1.5, fill: color)
        circle(c.x, c.y, r + 1.5, fill: .white, stroke: color, lw: 2)
        let m = minutes.truncatingRemainder(dividingBy: 60) / 60, laps = Int(minutes / 60)
        if minutes > 0.5 {
            let frac = laps > 0 && m < 0.001 ? 1 : m
            var p = Path()
            p.move(to: c)
            p.addArc(center: c, radius: r - 2, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * frac), clockwise: false)
            p.closeSubpath()
            if laps > 0 { circle(c.x, c.y, r - 2, fill: color, opacity: 0.18) }
            shape(p, fill: color, opacity: 0.3)
        }
        for i in 0..<12 {
            let a = Double(i) / 12 * 2 * .pi
            line(c.x + sin(a) * r * 0.78, c.y - cos(a) * r * 0.78, c.x + sin(a) * r * 0.95, c.y - cos(a) * r * 0.95, stroke: Tone.sub, lw: i % 3 == 0 ? 1.2 : 0.6)
        }
        let a = m * 2 * .pi
        line(c.x, c.y, c.x + sin(a) * r * 0.8, c.y - cos(a) * r * 0.8, stroke: Tone.ink, lw: 1.6, cap: .round)
        circle(c.x, c.y, 1.8, fill: Tone.ink)
    }

    /// "☎ 120" style call chip
    mutating func callChip(_ x: Double, _ y: Double, number: String = "120", t: Double = 0) {
        rect(x, y, 58, 20, r: 10, fill: Tone.red)
        // handset
        path("M \(x + 9) \(y + 6) C \(x + 8) \(y + 12) \(x + 12) \(y + 16) \(x + 17) \(y + 15) L \(x + 17) \(y + 12.5) L \(x + 14.5) \(y + 11.5) L \(x + 13.5) \(y + 12.8) C \(x + 12) \(y + 12) \(x + 11.5) \(y + 11) \(x + 11) \(y + 9.8) L \(x + 12.3) \(y + 8.8) L \(x + 11.5) \(y + 6) Z",
             fill: .white)
        text(number, x + 38, y + 14, size: 11, color: .white, anchor: .middle, bold: true)
    }

    /// arrow along a straight line with a filled head
    mutating func pointer(_ a: CGPoint, _ b: CGPoint, color: Color, lw: Double = 1.6, head: Double = 5) {
        let d = unit(CGPoint(x: b.x - a.x, y: b.y - a.y)), n = CGPoint(x: -d.y, y: d.x)
        line(a.x, a.y, b.x - d.x * head * 0.6, b.y - d.y * head * 0.6, stroke: color, lw: lw, cap: .round)
        path("M \(b.x) \(b.y) L \(b.x - d.x * head + n.x * head * 0.6) \(b.y - d.y * head + n.y * head * 0.6) L \(b.x - d.x * head - n.x * head * 0.6) \(b.y - d.y * head - n.y * head * 0.6) Z", fill: color)
    }
}
