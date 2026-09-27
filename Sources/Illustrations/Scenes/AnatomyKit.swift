import SwiftUI

/// Shared palette for the anatomy scenes (bones, joints, organs), so they read as one set.
enum Anat {
    static let bone = hex("#F3ECDC"), boneShade = hex("#DCCFB2"), boneEdge = hex("#B3A07C")
    static let marrow = hex("#E6D7B8")
    static let cartilage = hex("#D9ECF2"), cartilageEdge = hex("#8DB9C8")
    static let ligament = hex("#C9584F"), ligamentLight = hex("#E79A8F")
    static let tendon = hex("#E9DDC4"), tendonEdge = hex("#BBA77F")
    static let skin = hex("#F8E4D6"), skinShade = hex("#EFCDB8"), skinEdge = hex("#DDB39A")
    static let ink = hex("#3A3530"), text = hex("#6B5F4E"), muted = hex("#9A8F80")
    static let red = hex("#D8434B"), green = hex("#2E9E5B"), blue = hex("#3F87C6"), amber = hex("#D99A2B")
    static let purple = hex("#6C4F9E"), pink = hex("#C9788A")
}

extension Anat {
    /// 0…1 → 0…1 with soft ends
    static func ease(_ x: Double) -> Double { let t = x.clamped(0, 1); return t * t * (3 - 2 * t) }
    static func mix(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
}

extension Sketch {
    /// fill with a linear gradient between two scene points, then outline
    mutating func gradFill(_ p: Path, _ colors: [Color], from a: CGPoint, to b: CGPoint, stroke: Color? = nil, lw: Double = 1, opacity: Double = 1) {
        ctx.fill(p, with: .linearGradient(Gradient(colors: colors.map { $0.opacity(opacity) }), startPoint: a, endPoint: b))
        if let stroke { ctx.stroke(p, with: .color(stroke.opacity(opacity)), style: StrokeStyle(lineWidth: lw, lineJoin: .round)) }
    }

    mutating func gradFill(_ d: String, _ colors: [Color], from a: CGPoint, to b: CGPoint, stroke: Color? = nil, lw: Double = 1, opacity: Double = 1) {
        gradFill(SVGPath.parse(d), colors, from: a, to: b, stroke: stroke, lw: lw, opacity: opacity)
    }

    /// soft radial glow (swelling, pain, heat)
    mutating func softGlow(_ c: CGPoint, _ rx: Double, _ ry: Double, _ color: Color, _ alpha: Double) {
        guard alpha > 0.01 else { return }
        let p = Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: 2 * rx, height: 2 * ry))
        ctx.fill(p, with: .radialGradient(Gradient(colors: [color.opacity(alpha), color.opacity(alpha * 0.6), color.opacity(0)]),
                                          center: c, startRadius: 0, endRadius: max(rx, ry)))
    }

    /// Bone: ivory body lit from `light`, darker toward the far edge, with a crisp outline.
    mutating func boneFill(_ d: String, light a: CGPoint, dark b: CGPoint, fill: Color = Anat.bone, shade: Color = Anat.boneShade,
                       edge: Color = Anat.boneEdge, lw: Double = 1.2) {
        gradFill(d, [fill, fill, shade], from: a, to: b, stroke: edge, lw: lw)
    }

    mutating func boneFill(_ p: Path, light a: CGPoint, dark b: CGPoint, fill: Color = Anat.bone, shade: Color = Anat.boneShade,
                       edge: Color = Anat.boneEdge, lw: Double = 1.2) {
        gradFill(p, [fill, fill, shade], from: a, to: b, stroke: edge, lw: lw)
    }

    /// Measured text box, for placing labels without overlap.
    func measureText(_ s: String, size: Double, bold: Bool = false) -> CGSize {
        ctx.resolve(Text(s).font(.system(size: size, weight: bold ? .semibold : .medium))).measure(in: CGSize(width: 400, height: 100))
    }

    /// Anatomy label: dot on the structure, thin leader, text with a soft halo so it reads over anything.
    mutating func leader(_ en: String, _ zh: String, at target: CGPoint, _ x: Double, _ y: Double, anchor: Anchor = .start,
                          color: Color = Anat.text, size: Double = 9, bold: Bool = false, dot: Bool = true) {
        let s = t(en, zh), m = measureText(s, size: size, bold: bold)
        let x0 = anchor == .start ? x : anchor == .middle ? x - m.width / 2 : x - m.width
        // leader meets the nearest side of the text
        let ex = target.x < x0 ? x0 - 2 : target.x > x0 + m.width ? x0 + m.width + 2 : target.x
        let ey = abs(target.x - ex) < 1 ? (target.y < y ? y - m.height * 0.8 : y + 3) : y - m.height * 0.3
        if hypot(target.x - ex, target.y - ey) > 4 {
            line(target.x, target.y, ex, ey, stroke: color, lw: 0.7, opacity: 0.65)
        }
        if dot { circle(target.x, target.y, 2, fill: color, stroke: .white, lw: 0.8) }
        rect(x0 - 2, y - m.height * 0.82, m.width + 4, m.height * 0.95, r: 3, fill: .white, opacity: 0.72)
        let txt = Text(s).font(.system(size: size, weight: bold ? .semibold : .medium)).foregroundStyle(color)
        ctx.draw(txt, at: CGPoint(x: x0, y: y + size * 0.25), anchor: .bottomLeading)
    }

    /// Status chip, top of the scene: coloured dot + short bold state.
    mutating func stateChip(_ en: String, _ zh: String, _ x: Double, _ y: Double, color: Color, anchor: Anchor = .start) {
        let s = t(en, zh), m = measureText(s, size: 11, bold: true)
        let w = m.width + 28, x0 = anchor == .start ? x : anchor == .middle ? x - w / 2 : x - w
        rect(x0, y + 2, w, 24, r: 12, fill: Palette.shadow)
        rect(x0, y, w, 24, r: 12, fill: .white)
        rect(x0, y, w, 24, r: 12, fill: color.opacity(0.13))
        circle(x0 + 12, y + 12, 3.5, fill: color)
        ctx.draw(Text(s).font(.system(size: 11, weight: .semibold)).foregroundStyle(color), at: CGPoint(x: x0 + 21, y: y + 12), anchor: .leading)
    }

    /// Short caption line centred in a card, wrapped to `width`.
    mutating func cardNote(_ en: String, _ zh: String, _ x: Double, _ y: Double, width: Double, size: Double = 9, color: Color = Anat.text,
                       bold: Bool = false) {
        let txt = ctx.resolve(Text(t(en, zh)).font(.system(size: size, weight: bold ? .semibold : .medium)).foregroundStyle(color))
        let m = txt.measure(in: CGSize(width: width, height: 200))
        ctx.draw(txt, in: CGRect(x: x - m.width / 2, y: y - m.height / 2, width: m.width + 1, height: m.height + 1))
    }

    /// Curved arrow along a quadratic curve a → b bending through `via`.
    mutating func bendArrow(_ a: CGPoint, via c: CGPoint, _ b: CGPoint, color: Color, lw: Double = 1.8, dash: [CGFloat] = []) {
        var p = Path()
        p.move(to: a)
        p.addQuadCurve(to: b, control: c)
        shape(p, stroke: color, lw: lw, cap: .round, dash: dash)
        let d = unit(CGPoint(x: b.x - c.x, y: b.y - c.y)), n = CGPoint(x: -d.y, y: d.x), k = 3 + lw * 1.4
        path("M \(b.x + d.x * 2) \(b.y + d.y * 2) L \(b.x - d.x * k + n.x * k * 0.65) \(b.y - d.y * k + n.y * k * 0.65) "
             + "L \(b.x - d.x * k - n.x * k * 0.65) \(b.y - d.y * k - n.y * k * 0.65) Z", fill: color)
    }

    /// Ligament band a → b: parallel fibres. `stretch` thins and pales it; `tear` 0…1 breaks fibres from the middle.
    mutating func ligamentBand(_ a: CGPoint, _ b: CGPoint, width w: Double, stretch: Double = 0, tear: Double = 0) {
        let d = unit(CGPoint(x: b.x - a.x, y: b.y - a.y)), n = CGPoint(x: -d.y, y: d.x)
        let len = hypot(b.x - a.x, b.y - a.y), ww = w * (1 - 0.35 * stretch)
        let base = stretch > 0.5 ? Anat.ligamentLight : Anat.ligament
        let fibres = 5
        if tear < 0.4 {
            // sheath: pale band with a darker rim, fibres run inside it
            line(a.x, a.y, b.x, b.y, stroke: darker(base), lw: ww + 2.4, cap: .round, opacity: 0.5 * (1 - tear * 2))
            line(a.x, a.y, b.x, b.y, stroke: hex("#F4D3CC"), lw: ww + 1, cap: .round, opacity: 1 - tear * 2)
        }
        for i in 0..<fibres {
            let off = (Double(i) / Double(fibres - 1) - 0.5) * ww
            let s0 = CGPoint(x: a.x + n.x * off, y: a.y + n.y * off), s1 = CGPoint(x: b.x + n.x * off, y: b.y + n.y * off)
            // fibres break from the edges inward as `tear` grows
            let broken = tear > 0.02 && (Double(abs(i - fibres / 2)) / Double(fibres / 2) >= 1 - tear * 1.05 || tear > 0.95)
            if broken {
                let gap = 0.1 + 0.08 * tear, jitter = (Double(i % 2) - 0.5) * 0.1
                let m1 = 0.5 - gap + jitter, m2 = 0.5 + gap + jitter
                let curl = n.x * 2.5 * (i % 2 == 0 ? 1 : -1), curly = n.y * 2.5 * (i % 2 == 0 ? 1 : -1)
                path("M \(s0.x) \(s0.y) Q \(s0.x + d.x * len * m1 * 0.7) \(s0.y + d.y * len * m1 * 0.7) \(s0.x + d.x * len * m1 + curl) \(s0.y + d.y * len * m1 + curly)",
                     stroke: base, lw: ww / Double(fibres) * 0.8 + 0.3, cap: .round)
                path("M \(s1.x) \(s1.y) Q \(s1.x - d.x * len * (1 - m2) * 0.7) \(s1.y - d.y * len * (1 - m2) * 0.7) \(s0.x + d.x * len * m2 - curl) \(s0.y + d.y * len * m2 - curly)",
                     stroke: base, lw: ww / Double(fibres) * 0.8 + 0.3, cap: .round)
            } else {
                line(s0.x, s0.y, s1.x, s1.y, stroke: base, lw: ww / Double(fibres) * 0.8 + 0.3, cap: .round)
            }
        }
    }
}

extension Sketch {
    /// Person tripping onto an outstretched hand: front knee dropping, body pitching onto a straight arm.
    @discardableResult
    mutating func fallOnHand(x: Double, ground: Double, h: Double, look: Look = .man, build: Build = .adult) -> (shoulder: CGPoint, hand: CGPoint) {
        var fall = SideFigure(h: h, build: build, look: look, hip: .zero, rotation: 58, face: .distress)
        fall.headTilt = -30
        fall.nearLeg = .init(hip: 50, knee: 95, point: 30)
        fall.farLeg = .init(hip: -12, knee: 30, point: 60)
        let palmY = ground - build.hand * h * 0.22
        let armLen = (build.upperArm + build.foreArm + build.hand * 0.45) * h * 0.97
        let knee: Double = fall.legPoint(near: true, 1).y + build.legW * h * 0.5
        let feet = [true, false].map { n -> Double in let f = fall.foot(near: n); return max(Double(f.ankle.y) + 3, Double(f.toe.y) + 2) }.max() ?? 0
        fall.hip = CGPoint(x: x, y: ground - max(knee, feet))
        let sh = fall.shoulderPoint
        let hand = CGPoint(x: sh.x + max(4, armLen * armLen - (palmY - sh.y) * (palmY - sh.y)).squareRoot(), y: palmY)
        fall.near = .init(reach: hand, hand: .open, handAngle: 0)
        fall.far = .init(reach: CGPoint(x: hand.x - 7, y: palmY), hand: .open, handAngle: 0)
        fall.draw(&self)
        return (sh, hand)
    }
}

extension FacingPerson {
    /// One arm drawn from explicit joints (local frame), outlined, for poses `arm(_:)` can't reach.
    func drawArm(_ s: inout Sketch, at o: CGPoint, side: Double, elbow e: CGPoint, hand w: CGPoint, sleeve: Color? = nil) {
        let sh = shoulderPoint(side)
        func q(_ p: CGPoint) -> CGPoint { CGPoint(x: o.x + p.x, y: o.y + p.y) }
        s.limb([q(sh), q(e)], w: 0.05 * h, fill: sleeve ?? shirt, line: shirtLine)
        s.limb([q(e), q(w)], w: 0.034 * h, fill: skin, line: line)
        s.circle(q(w).x, q(w).y, 0.023 * h, fill: skin, stroke: line)
    }

    /// Triangular sling cradling a forearm from `e` to `w` (local), strap round the neck.
    func drawSling(_ s: inout Sketch, at o: CGPoint, elbow e: CGPoint, hand w: CGPoint, color: Color = Anat.blue) {
        func q(_ x: Double, _ y: Double) -> String { "\(o.x + x) \(o.y + y)" }
        let dark = darker(color), k = 0.03 * h
        s.path("M \(q(e.x - k, e.y - k * 1.2)) L \(q(w.x + k * 1.3, w.y - k * 1.1)) L \(q(w.x + k * 1.2, w.y + k * 1.2)) "
               + "Q \(q((e.x + w.x) / 2, w.y + k * 3)) \(q(e.x - k * 0.4, e.y + k * 1.6)) Z", fill: color, stroke: dark, lw: 1, opacity: 0.92)
        s.path("M \(q(w.x + k, w.y - k)) L \(q(0.05 * h, -0.005 * h)) M \(q(e.x - k * 0.6, e.y - k)) L \(q(-0.045 * h, -0.005 * h)) "
               + "M \(q(-0.045 * h, -0.005 * h)) Q \(q(0, 0.025 * h)) \(q(0.05 * h, -0.005 * h))", stroke: color, lw: 0.02 * h, cap: .round)
        s.circle(o.x + 0.05 * h, o.y - 0.005 * h, 0.014 * h, fill: dark)
    }
}
