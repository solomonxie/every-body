import SwiftUI

/// Front-facing person from the waist up, soft-shaded, for faces and hands that must read (health topics).
/// Local frame: base of the neck at the origin, y down; `h` = standing height.
struct Bust {
    enum Expression { case calm, smile, worried, pain, distress }
    var h: Double
    var look: Look
    var head: Double = 1
    var face = Expression.calm
    /// the person's right side (image left) sags: brow, eyelid, mouth corner
    var droop = 0.0
    var sweat = false
    var bump = false
    /// palm targets in the local frame; right = person's right = image left; nil = hanging
    var rightHand: CGPoint? = nil
    var leftHand: CGPoint? = nil
    var rightFist = false, leftFist = false
    /// torso is drawn down to here
    var waist = 0.42

    init(_ c: Casualty) {
        h = c.h
        look = c.look
        head = min(1.5, c.build.headR / 0.064)
        bump = c.bump > 0
    }

    var headRx: Double { 0.05 * h * head }
    var headRy: Double { 0.062 * h * head }
    var headCenter: CGPoint { CGPoint(x: 0, y: -0.022 * h - headRy * 0.9) }
    var mouth: CGPoint { CGPoint(x: 0, y: headCenter.y + headRy * 0.56) }
    var chin: CGPoint { CGPoint(x: 0, y: headCenter.y + headRy) }
    var chest: CGPoint { CGPoint(x: 0.03 * h, y: 0.11 * h) }
    func shoulder(_ side: Double) -> CGPoint { CGPoint(x: side * 0.108 * h, y: 0.03 * h) }
    func eye(_ side: Double) -> CGPoint { CGPoint(x: side * headRx * 0.4, y: headCenter.y + headRy * 0.04) }

    /// −1 = image left (person's right)
    func arm(_ side: Double) -> (elbow: CGPoint, hand: CGPoint) {
        let s = shoulder(side)
        let target = (side < 0 ? rightHand : leftHand) ?? CGPoint(x: s.x + side * 0.035 * h, y: s.y + 0.33 * h)
        return twoBone(s, target, 0.165 * h, 0.16 * h, bend: CGPoint(x: side * 0.6, y: 1))
    }

    func draw(_ s: inout Sketch, at o: CGPoint) {
        drawBody(&s, at: o)
        drawArms(&s, at: o)
    }

    func drawBody(_ s: inout Sketch, at o: CGPoint) {
        s.group(translate: o) { g in body(&g) }
    }

    func drawArms(_ s: inout Sketch, at o: CGPoint) {
        s.group(translate: o) { g in
            for side in [-1.0, 1.0] { arm(&g, side) }
        }
    }

    private func arm(_ g: inout Sketch, _ side: Double) {
        let s0 = shoulder(side), (e, hand) = arm(side)
        let d = unit(CGPoint(x: hand.x - e.x, y: hand.y - e.y))
        let L = 0.075 * h, wrist = CGPoint(x: hand.x - d.x * L * 0.3, y: hand.y - d.y * L * 0.3)
        let aw = 0.046 * h
        let fist = side < 0 ? rightFist : leftFist
        if look.longSleeves {
            g.limb([e, wrist], w: aw * 0.78, fill: look.skin, line: look.skinLine)
            g.limb([s0, e, lerp(e, wrist, 0.8)], w: aw, fill: look.top, line: look.topLine)
        } else {
            g.limb([s0, e, wrist], w: aw * 0.78, fill: look.skin, line: look.skinLine)
            shortSleeve(&g, s0, e, aw: aw, look: look)
        }
        drawHand(&g, at: hand, dir: d, len: L, shape: fist ? .fist : .open, look: look, thumb: side)
    }

    private func body(_ g: inout Sketch) {
        let c = headCenter, rx = headRx, ry = headRy
        let W = 0.118 * h
        if look.style == .long {
            g.path("M \(-rx * 1.05) \(c.y - ry * 0.2) C \(-rx * 1.35) \(c.y + ry * 1.1) \(-rx * 1.2) \(c.y + ry * 1.7) \(-rx * 0.5) \(c.y + ry * 1.75) "
                   + "L \(rx * 0.5) \(c.y + ry * 1.75) C \(rx * 1.2) \(c.y + ry * 1.7) \(rx * 1.35) \(c.y + ry * 1.1) \(rx * 1.05) \(c.y - ry * 0.2) Z",
                   fill: darker(look.hair))
        }
        if waist > 0.43 {
            g.shade("M \(-0.1 * h) \(0.38 * h) L \(0.1 * h) \(0.38 * h) L \(0.105 * h) \(waist * h) L \(-0.105 * h) \(waist * h) Z",
                    look.bottom, darker(look.bottom), stroke: darker(look.bottom), lw: 1, vertical: true)
            g.line(0, 0.46 * h, 0, waist * h, stroke: darker(look.bottom), lw: 0.8)
        }
        let wb = min(waist, 0.42) * h
        // torso
        let torso = "M \(-W) \(0.035 * h) C \(-W - 0.025 * h) \(0.08 * h) \(-0.105 * h) \(0.22 * h) \(-0.098 * h) \(wb) L \(0.098 * h) \(wb) "
            + "C \(0.105 * h) \(0.22 * h) \(W + 0.025 * h) \(0.08 * h) \(W) \(0.035 * h) C \(0.07 * h) \(0.0) \(-0.07 * h) \(0.0) \(-W) \(0.035 * h) Z"
        g.shade(torso, dim(look.top, 1.03), dim(look.top, 0.9), stroke: look.topLine, lw: 0.9, vertical: true)
        if bump {
            let c = CGPoint(x: 0.005 * h, y: 0.33 * h), rx = 0.1 * h, ry = 0.09 * h
            let belly = Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: 2 * rx, height: 2 * ry))
            g.ctx.fill(belly, with: .radialGradient(Gradient(colors: [dim(look.top, 1.08), look.top]), center: CGPoint(x: c.x - rx * 0.2, y: c.y - ry * 0.3),
                                                    startRadius: 0, endRadius: rx))
            g.path("M \(c.x - rx * 0.95) \(c.y + ry * 0.3) C \(c.x - rx * 0.7) \(c.y + ry * 1.05) \(c.x + rx * 0.7) \(c.y + ry * 1.05) \(c.x + rx * 0.95) \(c.y + ry * 0.3)",
                   stroke: look.topLine, lw: 0.8, opacity: 0.6)
        }
        // neck with a shadow under the chin
        g.shade("M \(-0.024 * h) \(c.y + ry * 0.6) L \(-0.027 * h) \(0.012 * h) Q 0 \(0.04 * h) \(0.027 * h) \(0.012 * h) L \(0.024 * h) \(c.y + ry * 0.6) Z",
                dim(look.skin, 0.88), look.skin, vertical: true)
        g.path("M \(-0.045 * h) \(0.012 * h) Q 0 \(0.05 * h) \(0.045 * h) \(0.012 * h)", stroke: look.topLine, lw: 1)
        // ears, head
        if look.style == .curly {
            for (x, y, rr) in [(-0.62, -0.6, 0.44), (0.62, -0.6, 0.44), (-0.2, -0.92, 0.44), (0.25, -0.92, 0.44), (-0.92, -0.08, 0.32), (0.92, -0.08, 0.32)] {
                g.circle(c.x + x * rx, c.y + y * ry, rr * rx, fill: look.hair)
            }
        }
        for side in [-1.0, 1.0] { g.ellipse(side * rx * 0.97, c.y + ry * 0.08, rx * 0.15, ry * 0.18, fill: dim(look.skin, 0.95)) }
        let headPath = Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: 2 * rx, height: 2 * ry))
        g.shade(headPath, dim(look.skin, 1.02), dim(look.skin, 0.94), stroke: look.skinLine, lw: 0.9)
        hair(&g, c, rx, ry)
        faceDetails(&g, c, rx, ry)
        if sweat {
            for (dx, dy) in [(-0.8, -0.3), (0.78, -0.12), (0.62, 0.4)] {
                let x = c.x + dx * rx, y = c.y + dy * ry
                g.path("M \(x) \(y - 4.5) Q \(x + 2.8) \(y + 1) \(x) \(y + 2.2) Q \(x - 2.8) \(y + 1) \(x) \(y - 4.5) Z", fill: hex("#8CC4EC"), stroke: hex("#5C9FD0"), lw: 0.5)
            }
        }
    }

    private func hair(_ g: inout Sketch, _ c: CGPoint, _ rx: Double, _ ry: Double) {
        let hc = look.hair
        switch look.style {
        case .curly:
            break
        case .baby:
            g.path("M \(-rx * 0.2) \(c.y - ry * 0.98) Q \(0) \(c.y - ry * 1.2) \(rx * 0.15) \(c.y - ry * 0.95)", stroke: hc, lw: 1.5, cap: .round)
        case .thin:
            for side in [-1.0, 1.0] {
                g.path("M \(side * rx * 1.0) \(c.y + ry * 0.1) C \(side * rx * 1.08) \(c.y - ry * 0.5) \(side * rx * 0.8) \(c.y - ry * 0.85) \(side * rx * 0.4) \(c.y - ry * 0.95) "
                       + "C \(side * rx * 0.7) \(c.y - ry * 0.7) \(side * rx * 0.86) \(c.y - ry * 0.4) \(side * rx * 0.88) \(c.y + ry * 0.05) Z", fill: hc)
            }
        default:
            var p = Path()
            p.move(to: CGPoint(x: c.x - rx * 1.02, y: c.y - ry * 0.02))
            p.addCurve(to: CGPoint(x: c.x + rx * 1.02, y: c.y - ry * 0.02), control1: CGPoint(x: c.x - rx * 1.15, y: c.y - ry * 1.3),
                       control2: CGPoint(x: c.x + rx * 1.15, y: c.y - ry * 1.3))
            p.addCurve(to: CGPoint(x: c.x - rx * 0.1, y: c.y - ry * 0.52), control1: CGPoint(x: c.x + rx * 0.92, y: c.y - ry * 0.35),
                       control2: CGPoint(x: c.x + rx * 0.45, y: c.y - ry * 0.62))
            p.addCurve(to: CGPoint(x: c.x - rx * 1.02, y: c.y - ry * 0.02), control1: CGPoint(x: c.x - rx * 0.6, y: c.y - ry * 0.45),
                       control2: CGPoint(x: c.x - rx * 0.92, y: c.y - ry * 0.3))
            p.closeSubpath()
            g.shade(p, hc, dim(hc, 0.9))
            if look.style == .bun { g.circle(c.x, c.y - ry * 1.1, rx * 0.32, fill: hc) }
            if look.style == .long {
                g.path("M \(-rx * 1.03) \(c.y + ry * 0.1) C \(-rx * 1.1) \(c.y + ry * 0.6) \(-rx * 1.05) \(c.y + ry * 1.0) \(-rx * 0.95) \(c.y + ry * 1.25) L \(-rx * 0.82) \(c.y + ry * 0.3) Z", fill: hc)
                g.path("M \(rx * 1.03) \(c.y + ry * 0.1) C \(rx * 1.1) \(c.y + ry * 0.6) \(rx * 1.05) \(c.y + ry * 1.0) \(rx * 0.95) \(c.y + ry * 1.25) L \(rx * 0.82) \(c.y + ry * 0.3) Z", fill: hc)
            }
        }
    }

    private func faceDetails(_ g: inout Sketch, _ c: CGPoint, _ rx: Double, _ ry: Double) {
        let ink = Ink.ink, brow = look.style == .thin ? hex("#A8A4A0") : look.hair
        let ey = c.y + ry * 0.04
        let squint = face == .pain || face == .distress
        for side in [-1.0, 1.0] {
            let sag = side < 0 ? droop : 0
            let x = c.x + side * rx * 0.4, y = ey + sag * ry * 0.07
            if squint {
                g.path("M \(x - rx * 0.14) \(y - ry * 0.02) Q \(x) \(y + ry * 0.08) \(x + rx * 0.14) \(y - ry * 0.02)", stroke: ink, lw: 1.3, cap: .round)
            } else {
                g.ellipse(x, y, rx * 0.1, ry * 0.095 * (1 - 0.45 * sag), fill: ink)
                if sag > 0.1 { g.path("M \(x - rx * 0.17) \(y - ry * 0.07) Q \(x) \(y - ry * 0.02) \(x + rx * 0.17) \(y - ry * 0.05)", stroke: look.skin, lw: ry * 0.09 * sag) }
            }
            let worried = face == .worried || face == .pain || face == .distress
            let inner = worried ? -ry * 0.1 : 0
            g.line(x - side * rx * 0.2, ey - ry * 0.27 + inner + sag * ry * 0.06, x + side * rx * 0.2, ey - ry * 0.25 + sag * ry * 0.1,
                   stroke: brow, lw: 1.4, cap: .round, opacity: 0.85)
            g.circle(c.x + side * rx * 0.56, c.y + ry * 0.36 + sag * ry * 0.05, rx * 0.15, fill: Ink.blush, opacity: 0.25)
        }
        g.path("M \(c.x - rx * 0.02) \(c.y + ry * 0.22) Q \(c.x - rx * 0.08) \(c.y + ry * 0.33) \(c.x + rx * 0.04) \(c.y + ry * 0.34)", stroke: look.skinLine, lw: 1, cap: .round)
        let my = c.y + ry * 0.58, mw = rx * 0.28, lip = Ink.lip
        let ly = my + droop * ry * 0.22
        switch face {
        case .smile: g.path("M \(-mw) \(ly - ry * 0.04) Q 0 \(my + ry * 0.17) \(mw) \(my - ry * 0.04)", stroke: lip, lw: 1.6, cap: .round)
        case .calm: g.path("M \(-mw) \(ly) Q 0 \(my + ry * 0.06) \(mw) \(my)", stroke: lip, lw: 1.6, cap: .round)
        case .worried: g.path("M \(-mw) \(ly + ry * 0.03) Q 0 \(my - ry * 0.07) \(mw) \(my + ry * 0.03)", stroke: lip, lw: 1.6, cap: .round)
        case .pain:
            g.path("M \(-mw) \(ly + ry * 0.05) Q 0 \(my - ry * 0.1) \(mw) \(my + ry * 0.05) Q 0 \(my + ry * 0.06) \(-mw) \(ly + ry * 0.05) Z",
                   fill: .white, stroke: lip, lw: 1.4)
        case .distress: g.ellipse(0, my + ry * 0.02, mw * 0.55, ry * 0.12, fill: Ink.mouth)
        }
    }
}
