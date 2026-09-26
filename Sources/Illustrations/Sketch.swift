import SwiftUI

/// SVG-like drawing on a GraphicsContext, so scenes read like the shapes they draw.
struct Sketch {
    var ctx: GraphicsContext

    mutating func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, r: Double = 0, fill: Color? = nil,
                       stroke: Color? = nil, lw: Double = 1, opacity: Double = 1) {
        shape(Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r), fill: fill, stroke: stroke, lw: lw, opacity: opacity)
    }

    mutating func circle(_ cx: Double, _ cy: Double, _ r: Double, fill: Color? = nil, stroke: Color? = nil, lw: Double = 1, opacity: Double = 1) {
        ellipse(cx, cy, r, r, fill: fill, stroke: stroke, lw: lw, opacity: opacity)
    }

    mutating func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, fill: Color? = nil, stroke: Color? = nil,
                          lw: Double = 1, opacity: Double = 1) {
        shape(Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: 2 * rx, height: 2 * ry)), fill: fill, stroke: stroke, lw: lw, opacity: opacity)
    }

    mutating func path(_ d: String, fill: Color? = nil, stroke: Color? = nil, lw: Double = 1, opacity: Double = 1,
                       cap: CGLineCap = .butt, dash: [CGFloat] = []) {
        shape(SVGPath.parse(d), fill: fill, stroke: stroke, lw: lw, opacity: opacity, cap: cap, dash: dash)
    }

    mutating func line(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, stroke: Color, lw: Double = 1,
                       cap: CGLineCap = .butt, dash: [CGFloat] = [], opacity: Double = 1) {
        var p = Path()
        p.move(to: CGPoint(x: x1, y: y1))
        p.addLine(to: CGPoint(x: x2, y: y2))
        shape(p, stroke: stroke, lw: lw, opacity: opacity, cap: cap, dash: dash)
    }

    enum Anchor { case start, middle, end }

    /// `y` is the baseline, like SVG text.
    mutating func text(_ s: String, _ x: Double, _ y: Double, size: Double = 10, color: Color = Color(hex: "#555555"),
                       anchor: Anchor = .start, bold: Bool = false) {
        let t = Text(s).font(.system(size: size, weight: bold ? .bold : .regular)).foregroundStyle(color)
        let unit: UnitPoint = switch anchor { case .start: .bottomLeading; case .middle: .bottom; case .end: .bottomTrailing }
        ctx.draw(t, at: CGPoint(x: x, y: y + size * 0.25), anchor: unit)
    }

    /// Draw inside a transformed frame (translate / rotate / scale).
    mutating func group(translate: CGPoint = .zero, rotate: Double = 0, about: CGPoint? = nil, scale: Double = 1,
                        opacity: Double = 1, _ body: (inout Sketch) -> Void) {
        var inner = Sketch(ctx: ctx)
        inner.ctx.opacity *= opacity
        inner.ctx.translateBy(x: translate.x, y: translate.y)
        if rotate != 0 {
            let c = about ?? .zero
            inner.ctx.translateBy(x: c.x, y: c.y)
            inner.ctx.rotate(by: .degrees(rotate))
            inner.ctx.translateBy(x: -c.x, y: -c.y)
        }
        if scale != 1 { inner.ctx.scaleBy(x: scale, y: scale) }
        body(&inner)
    }

    mutating func shape(_ p: Path, fill: Color? = nil, stroke: Color? = nil, lw: Double = 1, opacity: Double = 1,
                                cap: CGLineCap = .butt, dash: [CGFloat] = []) {
        if let fill { ctx.fill(p, with: .color(fill.opacity(opacity))) }
        if let stroke { ctx.stroke(p, with: .color(stroke.opacity(opacity)), style: StrokeStyle(lineWidth: lw, lineCap: cap, dash: dash)) }
    }
}

extension Double {
    /// ((x % span) + span) % span
    func wrap(_ span: Double) -> Double { ((truncatingRemainder(dividingBy: span)) + span).truncatingRemainder(dividingBy: span) }
    func clamped(_ lo: Double, _ hi: Double) -> Double { Swift.min(hi, Swift.max(lo, self)) }
}

/// Short colour constructor for scenes.
func hex(_ s: String) -> Color { Color(hex: s) }

extension Dictionary where Key == String, Value == Double {
    subscript(v key: String) -> Double { self[key] ?? 0 }
}
