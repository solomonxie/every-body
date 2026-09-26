import SwiftUI

/// Two-bone arm: elbow on the side of `bend`, hand clamped to reach.
func twoBone(_ s: CGPoint, _ t: CGPoint, _ l1: Double, _ l2: Double, bend: CGPoint) -> (elbow: CGPoint, hand: CGPoint) {
    let dx = t.x - s.x, dy = t.y - s.y
    let d = min(l1 + l2 - 0.01, max(abs(l1 - l2) + 0.01, hypot(dx, dy)))
    let base = atan2(dy, dx), a = acos(((l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)).clamped(-1, 1))
    let hand = CGPoint(x: s.x + cos(base) * d, y: s.y + sin(base) * d)
    let e1 = CGPoint(x: s.x + cos(base + a) * l1, y: s.y + sin(base + a) * l1)
    let e2 = CGPoint(x: s.x + cos(base - a) * l1, y: s.y + sin(base - a) * l1)
    let score: (CGPoint) -> Double = { ($0.x - s.x) * bend.x + ($0.y - s.y) * bend.y }
    return (score(e1) >= score(e2) ? e1 : e2, hand)
}

extension Person {
    /// Set shoulder / elbow so the hand lands on `target` (local frame, after lean), elbow below.
    mutating func aimHand(at target: CGPoint) {
        let a = lean * .pi / 180
        let s = CGPoint(x: -shoulderPoint.y * sin(a), y: shoulderPoint.y * cos(a))
        let (e, w) = twoBone(s, target, h * 0.17, h * 0.16, bend: CGPoint(x: 0, y: 1))
        let up = atan2(e.x - s.x, e.y - s.y) * 180 / .pi, fore = atan2(w.x - e.x, w.y - e.y) * 180 / .pi
        shoulder = up - lean
        elbow = (fore - up + 540).truncatingRemainder(dividingBy: 360) - 180
    }
}

/// Front-facing person, for faces and hands that must read. Local frame: base of the neck at the origin, y down; `h` = standing height.
struct FacingPerson {
    var h: Double = 240
    var skin = hex("#F2C9A5")
    var line = hex("#C9A58A")
    var shirt = hex("#8FB3E0")
    var shirtLine = hex("#5F87B8")
    var trousers = hex("#5B6B8C")
    var hair = hex("#6B5344")
    var longHair = false
    /// head size multiplier: children have bigger heads for their height
    var head: Double = 1
    enum Face { case calm, smile, pain, sneeze, worried }
    var face: Face = .calm
    /// the person's right side (image left) sags: eyelid, mouth corner
    var droop: Double = 0
    var sweat = false
    /// hand targets in the local frame, nil = hanging; right = the person's right = image left
    var rightHand: CGPoint? = nil
    var leftHand: CGPoint? = nil
    var legs = false
    var bump = false

    var headRx: Double { 0.05 * h * head }
    var headRy: Double { 0.064 * h * head }
    var headCenter: CGPoint { CGPoint(x: 0, y: -0.014 * h - headRy * 0.92) }
    var mouth: CGPoint { CGPoint(x: 0, y: headCenter.y + headRy * 0.5) }
    var chin: CGPoint { CGPoint(x: 0, y: headCenter.y + headRy) }
    func shoulderPoint(_ side: Double) -> CGPoint { CGPoint(x: side * 0.115 * h, y: 0.03 * h) }
    /// −1 = image left (person's right)
    func arm(_ side: Double) -> (elbow: CGPoint, hand: CGPoint) {
        let s = shoulderPoint(side)
        let target = (side < 0 ? rightHand : leftHand) ?? CGPoint(x: s.x + side * 0.03 * h, y: s.y + 0.31 * h)
        return twoBone(s, target, 0.17 * h, 0.15 * h, bend: CGPoint(x: side, y: 0.6))
    }

    func draw(_ s: inout Sketch, at origin: CGPoint) {
        drawBody(&s, at: origin)
        drawArms(&s, at: origin)
    }

    /// body without arms, so scenes can put things between the torso and the arms
    func drawBody(_ s: inout Sketch, at origin: CGPoint) {
        s.group(translate: origin) { g in body(&g) }
    }

    func drawArms(_ s: inout Sketch, at origin: CGPoint) {
        s.group(translate: origin) { g in
            for side in [-1.0, 1.0] {
                let s0 = shoulderPoint(side), (e, hd) = arm(side)
                g.line(s0.x, s0.y, e.x, e.y, stroke: shirt, lw: 0.05 * h, cap: .round)
                g.line(e.x, e.y, hd.x, hd.y, stroke: skin, lw: 0.036 * h, cap: .round)
                g.circle(hd.x, hd.y, 0.024 * h, fill: skin, stroke: line)
            }
        }
    }

    private func body(_ g: inout Sketch) {
        let c = headCenter, rx = headRx, ry = headRy
        if legs {
            for side in [-1.0, 1.0] {
                g.line(side * 0.05 * h, 0.34 * h, side * 0.055 * h, 0.8 * h, stroke: trousers, lw: 0.075 * h, cap: .round)
                g.ellipse(side * 0.065 * h, 0.83 * h, 0.045 * h, 0.018 * h, fill: hex("#3E3E4A"))
            }
        }
        if longHair { g.path("M \(-rx * 1.05) \(c.y) C \(-rx * 1.2) \(c.y + ry * 1.2) \(-rx * 0.9) \(c.y + ry * 1.5) \(-rx * 0.4) \(c.y + ry * 1.3) L \(rx * 0.4) \(c.y + ry * 1.3) C \(rx * 0.9) \(c.y + ry * 1.5) \(rx * 1.2) \(c.y + ry * 1.2) \(rx * 1.05) \(c.y) Z", fill: hair) }
        // torso: shoulders, waist, hips
        let w = 0.115 * h
        g.path("M \(-w) \(0.02 * h) C \(-w - 0.02 * h) \(0.06 * h) \(-0.1 * h) \(0.2 * h) \(-0.09 * h) \(0.3 * h) L \(-0.1 * h) \(0.37 * h) L \(0.1 * h) \(0.37 * h) L \(0.09 * h) \(0.3 * h) "
               + "C \(0.1 * h) \(0.2 * h) \(w + 0.02 * h) \(0.06 * h) \(w) \(0.02 * h) C \(0.06 * h) \(-0.005 * h) \(-0.06 * h) \(-0.005 * h) \(-w) \(0.02 * h) Z",
               fill: shirt, stroke: shirtLine, lw: 1.5)
        if bump { g.ellipse(0, 0.3 * h, 0.085 * h, 0.07 * h, fill: shirt, stroke: shirtLine, lw: 1) }
        g.path("M \(-0.03 * h) \(c.y + ry * 0.7) L \(-0.032 * h) \(0.01 * h) Q 0 \(0.035 * h) \(0.032 * h) \(0.01 * h) L \(0.03 * h) \(c.y + ry * 0.7) Z", fill: skin, stroke: line)
        // head
        for side in [-1.0, 1.0] { g.ellipse(side * rx * 0.98, c.y + ry * 0.05, rx * 0.16, ry * 0.2, fill: skin, stroke: line) }
        g.ellipse(c.x, c.y, rx, ry, fill: skin, stroke: line, lw: 1.5)
        g.path("M \(-rx * 1.02) \(c.y + ry * 0.05) C \(-rx * 1.1) \(c.y - ry * 1.25) \(rx * 1.1) \(c.y - ry * 1.25) \(rx * 1.02) \(c.y + ry * 0.05) "
               + "C \(rx * 0.9) \(c.y - ry * 0.4) \(rx * 0.3) \(c.y - ry * 0.62) \(-rx * 0.2) \(c.y - ry * 0.5) C \(-rx * 0.6) \(c.y - ry * 0.45) \(-rx * 0.9) \(c.y - ry * 0.3) \(-rx * 1.02) \(c.y + ry * 0.05) Z",
               fill: hair)
        faceDetails(&g, c, rx, ry)
        if sweat {
            for (dx, dy) in [(-0.85, -0.25), (0.8, -0.1), (0.6, 0.35)] {
                let x = c.x + dx * rx, y = c.y + dy * ry
                g.path("M \(x) \(y - 4) Q \(x + 2.5) \(y + 1) \(x) \(y + 2) Q \(x - 2.5) \(y + 1) \(x) \(y - 4) Z", fill: hex("#8CC4EC"))
            }
        }
    }

    private func faceDetails(_ g: inout Sketch, _ c: CGPoint, _ rx: Double, _ ry: Double) {
        let ink = hex("#4A4550"), ey = c.y + ry * 0.02
        for side in [-1.0, 1.0] {
            let sag = side < 0 ? droop : 0
            let x = c.x + side * rx * 0.4, y = ey + sag * ry * 0.06
            if face == .sneeze || face == .pain {
                g.path("M \(x - rx * 0.14) \(y) Q \(x) \(y + ry * 0.07) \(x + rx * 0.14) \(y)", stroke: ink, lw: 1.4, cap: .round)
            } else {
                g.ellipse(x, y, rx * 0.12, ry * 0.1 * (1 - 0.5 * sag), fill: ink)
                if sag > 0.1 { g.path("M \(x - rx * 0.17) \(y - ry * 0.06) L \(x + rx * 0.17) \(y - ry * 0.04)", stroke: skin, lw: ry * 0.08 * sag) }
            }
            let inner = face == .pain || face == .worried ? -ry * 0.1 : 0
            g.line(x - side * rx * 0.2, ey - ry * 0.29 + inner + sag * ry * 0.04, x + side * rx * 0.2, ey - ry * 0.26 + sag * ry * 0.08,
                   stroke: hair, lw: 1.6, cap: .round)
        }
        g.path("M \(c.x) \(c.y + ry * 0.1) Q \(c.x - rx * 0.14) \(c.y + ry * 0.3) \(c.x + rx * 0.06) \(c.y + ry * 0.32)", stroke: line, lw: 1.2, cap: .round)
        let my = c.y + ry * 0.55, mw = rx * 0.34, lip = hex("#B5646A")
        let leftY = my + droop * ry * 0.2
        switch face {
        case .smile: g.path("M \(-mw) \(leftY - ry * 0.04) Q 0 \(my + ry * 0.16) \(mw) \(my - ry * 0.04)", stroke: lip, lw: 1.6, cap: .round)
        case .calm: g.path("M \(-mw) \(leftY) Q 0 \(my + ry * 0.06) \(mw) \(my)", stroke: lip, lw: 1.6, cap: .round)
        case .worried: g.path("M \(-mw) \(leftY + ry * 0.03) Q 0 \(my - ry * 0.06) \(mw) \(my + ry * 0.03)", stroke: lip, lw: 1.6, cap: .round)
        case .pain:
            g.path("M \(-mw) \(leftY + ry * 0.05) Q 0 \(my - ry * 0.1) \(mw) \(my + ry * 0.05) Q 0 \(my + ry * 0.04) \(-mw) \(leftY + ry * 0.05) Z",
                   fill: .white, stroke: lip, lw: 1.4)
        case .sneeze: g.ellipse(0, my, mw * 0.7, ry * 0.12, fill: hex("#7A3B45"))
        }
    }
}
