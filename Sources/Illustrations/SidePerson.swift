import SwiftUI

/// Simple proportioned side-view person for the topic scenes (first aid has its own kit in Figures.swift).
/// Local frame: hip at the origin, facing +x, y down; `h` = standing height.
struct Person {
    var h: Double = 230
    var skin = hex("#F2C9A5")
    var line = hex("#C9A58A")
    var shirt = hex("#8FB3E0")
    var shirtLine = hex("#5F87B8")
    var trousers = hex("#5B6B8C")
    /// forward bend of the upper body at the hips, degrees
    var lean: Double = 0
    /// arm: shoulder flexion (0 = hanging, 90 = straight forward) and elbow bend, degrees
    var shoulder: Double = 5
    var elbow: Double = 10
    /// legs: hip flexion and knee bend, degrees (kneeling ≈ 0 / 90)
    var hip: Double = 0
    var knee: Double = 0

    /// Where the hand ends up, in the local frame (after lean) — for placing contact points.
    func hand() -> CGPoint {
        let s = rotate(shoulderPoint, by: lean)
        let upper = h * 0.17, fore = h * 0.16
        let a1 = (shoulder + lean) * .pi / 180
        let elbowP = CGPoint(x: s.x + sin(a1) * upper, y: s.y + cos(a1) * upper)
        let a2 = (shoulder + lean + elbow) * .pi / 180
        return CGPoint(x: elbowP.x + sin(a2) * fore, y: elbowP.y + cos(a2) * fore)
    }

    var shoulderPoint: CGPoint { CGPoint(x: 0, y: -h * 0.29) }

    func draw(_ s: inout Sketch, at origin: CGPoint, rotation: Double = 0, farArm: Bool = true) {
        s.group(translate: origin, rotate: rotation, about: .zero) { g in
            legs(&g)
            if farArm { arm(&g, shade: 0.8) }
            g.group(rotate: lean, about: .zero) { u in torso(&u) }
            arm(&g, shade: 1)
        }
    }

    private func rotate(_ p: CGPoint, by deg: Double) -> CGPoint {
        let a = deg * .pi / 180
        return CGPoint(x: p.x * cos(a) - p.y * sin(a), y: p.x * sin(a) + p.y * cos(a))
    }

    private func pt(_ x: Double, _ y: Double) -> String { "\(x * h) \(y * h)" }

    private func torso(_ g: inout Sketch) {
        // body outline: throat → chest → belly → pubis, then back up the spine
        g.path("M \(pt(0.035, -0.335)) C \(pt(0.075, -0.3)) \(pt(0.085, -0.22)) \(pt(0.07, -0.17)) C \(pt(0.055, -0.12)) \(pt(0.065, -0.05)) \(pt(0.045, 0.02)) "
               + "L \(pt(-0.05, 0.04)) C \(pt(-0.085, 0.0)) \(pt(-0.06, -0.07)) \(pt(-0.06, -0.12)) C \(pt(-0.075, -0.2)) \(pt(-0.07, -0.29)) \(pt(-0.03, -0.335)) Z",
               fill: shirt, stroke: shirtLine, lw: 1.5)
        g.path("M \(pt(-0.018, -0.34)) L \(pt(-0.02, -0.375)) L \(pt(0.028, -0.375)) L \(pt(0.03, -0.34)) Z", fill: skin, stroke: line)
        // head with a face profile: brow, nose, lips, chin
        g.circle(0.015 * h, -0.43 * h, 0.062 * h, fill: skin, stroke: line, lw: 1.5)
        g.path("M \(pt(0.06, -0.455)) L \(pt(0.09, -0.425)) L \(pt(0.068, -0.418)) C \(pt(0.072, -0.405)) \(pt(0.07, -0.39)) \(pt(0.05, -0.375))",
               fill: skin, stroke: line, lw: 1.2)
        g.circle(0.045 * h, -0.445 * h, 0.006 * h, fill: hex("#4A4550"))
        g.path("M \(pt(-0.045, -0.47)) C \(pt(-0.02, -0.5)) \(pt(0.04, -0.5)) \(pt(0.07, -0.465))", stroke: hex("#6B5344"), lw: 0.02 * h, cap: .round)
    }

    private func arm(_ g: inout Sketch, shade: Double) {
        let s0 = rotate(shoulderPoint, by: lean)
        let upper = h * 0.17
        let a1 = (shoulder + lean) * .pi / 180
        let e = CGPoint(x: s0.x + sin(a1) * upper, y: s0.y + cos(a1) * upper)
        let w = hand()
        g.line(s0.x, s0.y, e.x, e.y, stroke: shirt.opacity(shade), lw: 0.05 * h, cap: .round)
        g.line(e.x, e.y, w.x, w.y, stroke: skin.opacity(shade), lw: 0.04 * h, cap: .round)
        g.circle(w.x, w.y, 0.026 * h, fill: skin.opacity(shade), stroke: line.opacity(shade))
    }

    private func legs(_ g: inout Sketch) {
        let thigh = h * 0.245, shin = h * 0.245
        let a1 = hip * .pi / 180
        let k = CGPoint(x: sin(a1) * thigh, y: cos(a1) * thigh)
        let a2 = (hip - knee) * .pi / 180
        let a = CGPoint(x: k.x + sin(a2) * shin, y: k.y + cos(a2) * shin)
        g.line(0, 0, k.x, k.y, stroke: trousers, lw: 0.075 * h, cap: .round)
        g.line(k.x, k.y, a.x, a.y, stroke: trousers, lw: 0.06 * h, cap: .round)
        let toe = knee > 60 ? CGPoint(x: a.x - 0.05 * h, y: a.y) : CGPoint(x: a.x + 0.1 * h, y: a.y + 0.01 * h)
        g.line(a.x, a.y, toe.x, toe.y, stroke: hex("#3E3E4A"), lw: 0.035 * h, cap: .round)
    }
}
