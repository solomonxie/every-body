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
        let target = (side < 0 ? rightHand : leftHand) ?? CGPoint(x: s.x + side * 0.012 * h, y: s.y + 0.305 * h)
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
        let L = 0.075 * h, wrist = CGPoint(x: hand.x - d.x * L * 0.4, y: hand.y - d.y * L * 0.4)
        let fist = side < 0 ? rightFist : leftFist
        dressedArm(&g, s0, e, wrist, aw: 0.048 * h, look: look)
        drawHand(&g, at: hand, dir: d, len: L, shape: fist ? .fist : .open, look: look, thumb: side)
    }

    private var expr: Expr {
        switch face { case .calm: .calm; case .smile: .smile; case .worried: .worried; case .pain: .pain; case .distress: .distress }
    }

    private func body(_ g: inout Sketch) {
        let c = headCenter, rx = headRx, ry = headRy
        faceOnHairBack(&g, c: c, rx: rx, ry: ry, look: look)
        frontTorso(&g, h: h, look: look, shoulderW: 0.118 * h, waist: waist, bump: bump)
        faceOnHead(&g, c: c, rx: rx, ry: ry, look: look, expr: expr, droop: droop)
        if sweat { sweatDrops(&g, c, rx, ry) }
    }
}

/// Front torso from the neck (origin) down to `waist` × h: shoulders, soft waist, flat colour with one shade; trousers below 0.42 h.
func frontTorso(_ g: inout Sketch, h: Double, look: Look, shoulderW W: Double, waist: Double, bump: Bool) {
    if waist > 0.43 {
        g.path("M \(-0.1 * h) \(0.38 * h) L \(0.1 * h) \(0.38 * h) L \(0.106 * h) \(waist * h) L \(-0.106 * h) \(waist * h) Z", fill: look.bottom)
        g.line(0, 0.46 * h, 0, waist * h, stroke: .black, lw: 0.8, opacity: 0.12)
    }
    let wb = min(waist, 0.42) * h
    let k = W / (0.118 * h)
    let torso = smoothPath([(-0.03, -0.002), (-0.085 * k, 0.012), (-0.118 * k, 0.048), (-0.12 * k, 0.1), (-0.104, 0.2), (-0.09, 0.3), (-0.096, wb / h),
                            (0.096, wb / h), (0.09, 0.3), (0.104, 0.2), (0.12 * k, 0.1), (0.118 * k, 0.048), (0.085 * k, 0.012), (0.03, -0.002)]
        .map { CGPoint(x: $0.0 * h, y: $0.1 * h) })
    g.shape(torso, fill: look.top)
    var sh = g.clipped(to: torso)
    sh.shape(openPath([CGPoint(x: W + 0.01 * h, y: 0.05 * h), CGPoint(x: 0.1 * h, y: 0.22 * h), CGPoint(x: 0.098 * h, y: wb + 4)]),
             stroke: .black.opacity(0.07), lw: 0.05 * h)
    if waist > 0.43 { sh.rect(-0.12 * h, wb - 0.018 * h, 0.24 * h, 0.018 * h, fill: .black, opacity: 0.06) }
    if bump {
        let c = CGPoint(x: 0.005 * h, y: 0.33 * h), rx = 0.1 * h, ry = 0.09 * h
        g.ellipse(c.x, c.y, rx, ry, fill: look.top)
        g.path("M \(c.x + rx * 0.2) \(c.y + ry * 0.95) C \(c.x + rx * 0.8) \(c.y + ry * 0.8) \(c.x + rx * 1.02) \(c.y + ry * 0.3) \(c.x + rx * 0.96) \(c.y - ry * 0.2)",
               stroke: .black, lw: 0.035 * h, opacity: 0.06)
        g.ellipse(c.x - rx * 0.35, c.y - ry * 0.4, rx * 0.28, ry * 0.2, fill: .white, opacity: 0.18)
    }
    // neck with a shadow under the chin, then the neckline
    let nw = 0.024 * h
    g.path("M \(-nw) \(-0.07 * h) L \(-nw * 1.08) \(0.012 * h) Q 0 \(0.034 * h) \(nw * 1.08) \(0.012 * h) L \(nw) \(-0.07 * h) Z", fill: look.skin)
    g.path("M \(-nw) \(-0.045 * h) L \(-nw * 1.08) \(0.012 * h) Q 0 \(0.034 * h) \(nw * 1.08) \(0.012 * h) L \(nw) \(-0.045 * h) Q 0 \(-0.02 * h) \(-nw) \(-0.045 * h) Z",
           fill: .black, opacity: 0.08)
    g.path("M \(-0.04 * h) \(0.01 * h) Q 0 \(0.046 * h) \(0.04 * h) \(0.01 * h)", stroke: dim(look.top, 0.8), lw: 1.1, cap: .round)
}

/// three sweat beads round a face-on head
func sweatDrops(_ g: inout Sketch, _ c: CGPoint, _ rx: Double, _ ry: Double) {
    for (dx, dy) in [(-0.85, -0.3), (0.82, -0.12), (0.64, 0.4)] {
        let x = c.x + dx * rx, y = c.y + dy * ry
        g.path("M \(x) \(y - 4.5) Q \(x + 2.8) \(y + 1) \(x) \(y + 2.2) Q \(x - 2.8) \(y + 1) \(x) \(y - 4.5) Z", fill: hex("#8CC4EC"))
        g.circle(x - 0.6, y - 0.2, 0.8, fill: .white, opacity: 0.7)
    }
}
