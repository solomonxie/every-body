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

/// Front-facing person, for faces and hands that must read. Local frame: base of the neck at the origin, y down; `h` = standing height.
struct FacingPerson {
    var h: Double = 240
    var skin = Look.Skin.light
    var line = Look.edge(Look.Skin.light)
    var shirt = hex("#7F9BE0")
    var shirtLine = Look.edge(hex("#7F9BE0"))
    var trousers = hex("#3A4766")
    var hair = hex("#3A2C28")
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
    /// hair style and glasses of a cast member; nil = short or long hair from `longHair`
    var style: Look.Hair? = nil
    var glasses = false

    var headRx: Double { 0.05 * h * head }
    var headRy: Double { 0.064 * h * head }
    var headCenter: CGPoint { CGPoint(x: 0, y: -0.014 * h - headRy * 0.92) }
    var mouth: CGPoint { CGPoint(x: 0, y: headCenter.y + headRy * 0.5) }
    var chin: CGPoint { CGPoint(x: 0, y: headCenter.y + headRy) }
    func shoulderPoint(_ side: Double) -> CGPoint { CGPoint(x: side * 0.102 * h, y: 0.04 * h) }
    /// −1 = image left (person's right)
    func arm(_ side: Double) -> (elbow: CGPoint, hand: CGPoint) {
        let s = shoulderPoint(side)
        let target = (side < 0 ? rightHand : leftHand) ?? CGPoint(x: s.x + side * 0.025 * h, y: s.y + 0.31 * h)
        return twoBone(s, target, 0.17 * h, 0.15 * h, bend: CGPoint(x: side * 0.6, y: 1))
    }

    /// the same person as a `Look`, for the shared drawing kit
    var look: Look {
        var l = Look(skin: skin, hair: hair, style: style ?? (longHair ? .long : .short), top: shirt, bottom: trousers, female: longHair, glasses: glasses)
        (l.skinLine, l.topLine) = (line, shirtLine)
        return l
    }

    /// dress this person as a cast member (skin, hair, glasses)
    mutating func wear(_ l: Look) {
        (skin, line, hair, style, glasses) = (l.skin, l.skinLine, l.hair, l.style, l.glasses)
        longHair = l.female
    }

    private var expr: Expr {
        switch face { case .calm: .calm; case .smile: .smile; case .pain: .pain; case .sneeze: .sneeze; case .worried: .worried }
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
                let (e, hd) = arm(side)
                limb(&g, side, elbow: e, hand: hd)
            }
        }
    }

    /// one arm from the shoulder via `e` to the palm centre `hd` (local frame)
    func limb(_ g: inout Sketch, _ side: Double, elbow e: CGPoint, hand hd: CGPoint, sleeve: Color? = nil) {
        var l = look
        l.top = sleeve ?? dim(shirt, 0.92)
        let d = unit(CGPoint(x: hd.x - e.x, y: hd.y - e.y)), L = 0.068 * h
        let wrist = CGPoint(x: hd.x - d.x * L * 0.4, y: hd.y - d.y * L * 0.4)
        dressedArm(&g, shoulderPoint(side), e, wrist, aw: 0.05 * h, look: l)
        drawHand(&g, at: hd, dir: d, len: L, shape: .open, look: l, thumb: side)
    }

    private func body(_ g: inout Sketch) {
        let c = headCenter, rx = headRx, ry = headRy, l = look
        faceOnHairBack(&g, c: c, rx: rx, ry: ry, look: l)
        if legs {
            for side in [-1.0, 1.0] {
                let hip = CGPoint(x: side * 0.052 * h, y: 0.36 * h), knee = CGPoint(x: side * 0.054 * h, y: 0.58 * h), ankle = CGPoint(x: side * 0.056 * h, y: 0.8 * h)
                g.ellipse(side * 0.066 * h, 0.822 * h, 0.042 * h, 0.018 * h, fill: hex("#2A2D3A"))
                var p = segmentPath(hip, 0.042 * h, knee, 0.032 * h, bulge: 0.004 * h * side, -0.004 * h * side)
                p.addPath(segmentPath(knee, 0.031 * h, ankle, 0.024 * h, bulge: 0.004 * h * side, 0.004 * h * side, peak: 0.3))
                g.shape(p, fill: side > 0 ? dim(trousers, 0.92) : trousers)
            }
        }
        frontTorso(&g, h: h, look: l, shoulderW: 0.115 * h, waist: legs ? 0.44 : 0.4, bump: bump)
        faceOnHead(&g, c: c, rx: rx, ry: ry, look: l, expr: expr, droop: droop)
        if sweat { sweatDrops(&g, c, rx, ry) }
    }
}
