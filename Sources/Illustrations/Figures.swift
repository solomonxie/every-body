import SwiftUI

/// Body proportions as fractions of standing height.
struct Build: Sendable {
    var headR: Double, neck: Double, torso: Double, depth: Double, shoulderW: Double
    var upperArm: Double, foreArm: Double, hand: Double, armW: Double
    var thigh: Double, shin: Double, foot: Double, legW: Double

    static let adult = Build(headR: 0.064, neck: 0.04, torso: 0.3, depth: 0.12, shoulderW: 0.105,
                             upperArm: 0.18, foreArm: 0.155, hand: 0.1, armW: 0.05, thigh: 0.245, shin: 0.24, foot: 0.12, legW: 0.075)
    static let child = Build(headR: 0.085, neck: 0.03, torso: 0.29, depth: 0.13, shoulderW: 0.1,
                             upperArm: 0.165, foreArm: 0.14, hand: 0.1, armW: 0.055, thigh: 0.22, shin: 0.2, foot: 0.12, legW: 0.08)
    static let infant = Build(headR: 0.125, neck: 0.015, torso: 0.32, depth: 0.17, shoulderW: 0.13,
                              upperArm: 0.13, foreArm: 0.12, hand: 0.085, armW: 0.075, thigh: 0.16, shin: 0.14, foot: 0.11, legW: 0.1)
}

/// Colours, hair and clothes of one person.
struct Look: Sendable {
    enum Hair: Sendable { case short, long, bun, baby, thin }
    var skin = hex("#F2C9A5"), skinLine = hex("#C99A7A")
    var hair = hex("#5B4033"), style = Hair.short
    var top = hex("#6FA3DC"), topLine = hex("#4A7CB5")
    var bottom = hex("#4F5D7A"), shoes = hex("#34343E")
    var longSleeves = true
    /// dress or onesie: no separate trousers
    var onePiece = false
    var female = false
    /// disposable gloves
    var gloves: Color? = nil

    static let rescuer = Look()
    static let helper = Look(hair: hex("#2F2A28"), style: .bun, top: hex("#7CB98B"), topLine: hex("#4F8F60"), bottom: hex("#3F4A5E"), female: true)
    static let man = Look(hair: hex("#3B2F2A"), top: hex("#E6EBF2"), topLine: hex("#98A9BF"), bottom: hex("#6B7A99"))
    static let woman = Look(hair: hex("#3B2A24"), style: .long, top: hex("#D98FA6"), topLine: hex("#B06C84"), bottom: hex("#D98FA6"),
                            onePiece: true, female: true)
    static let senior = Look(skin: hex("#EDC4A2"), hair: hex("#D4D4D4"), style: .thin, top: hex("#B89F80"), topLine: hex("#8D7658"),
                             bottom: hex("#5E5E66"))
    static let kid = Look(hair: hex("#6B4A2F"), top: hex("#F2C14E"), topLine: hex("#C99A2E"), bottom: hex("#4E7FB8"), longSleeves: false)
    static let baby = Look(hair: hex("#A7825F"), style: .baby, top: hex("#BFE3D0"), topLine: hex("#7FB89A"), bottom: hex("#BFE3D0"),
                           shoes: hex("#F2C9A5"), onePiece: true)

    var bareFeet: Bool { style == .baby }
}

enum Face: Sendable { case calm, closed, distress, open }

/// The person a first-aid scene is about, sized relative to an adult of height `h`.
struct Casualty {
    var look: Look, build: Build, h: Double, bump: Double = 0

    init(_ p: Profile, adult h: Double, adultLook: Look = .man) {
        switch p.age {
        case .infant: (look, build, self.h) = (.baby, .infant, h * 0.4)
        case .child: (look, build, self.h) = (.kid, .child, h * 0.68)
        case .senior: (look, build, self.h) = (.senior, .adult, h * 0.97)
        case .adult: (look, build, self.h) = (p.isPregnant || p.female ? .woman : adultLook, .adult, h)
        }
        if p.isPregnant { bump = 1 }
    }
}

// MARK: - Side view

/// Side-view person built from joints; scenes place the hip, pose the limbs and aim hands at scene points.
/// Body frame: hip at the origin, facing +x, y down. `rotation` turns the whole body (−90 = lying on the back).
struct SideFigure {
    enum Hand: Sendable { case open, fist, twoFingers }
    struct Arm {
        /// palm centre in scene coords; nil = pose by angles
        var reach: CGPoint? = nil
        var shoulder = 8.0, elbow = 15.0
        var hand = Hand.open
        /// fingers direction in scene degrees; nil = along the forearm
        var handAngle: Double? = nil
        /// elbow bends the other way
        var flip = false
    }
    struct Leg {
        /// hip flexion forward, knee bend, and how far the foot points (90 = in line with the shin)
        var hip = 0.0, knee = 0.0, point = 0.0
    }

    var h: Double
    var build = Build.adult
    var look = Look.rescuer
    var hip: CGPoint
    var facing = 1.0
    var rotation = 0.0
    /// spine forward from the legs, degrees
    var lean = 0.0
    /// chin toward the chest (+) or back (−)
    var headTilt = 0.0
    var face = Face.calm
    var bump = 0.0
    var near = Arm(), far = Arm()
    var nearLeg = Leg(), farLeg = Leg()

    /// hip height above the floor when standing straight
    static func hipHeight(_ h: Double, _ b: Build) -> Double { (b.thigh + b.shin) * h + b.legW * h * 0.3 }

    var tf: CGAffineTransform {
        CGAffineTransform(translationX: hip.x, y: hip.y).rotated(by: rotation * facing * .pi / 180).scaledBy(x: facing, y: 1)
    }

    func scene(_ p: CGPoint) -> CGPoint { p.applying(tf) }

    /// point in the torso: x forward in depths, f up the spine (0 hip … 1 shoulder)
    func torso(_ x: Double, _ f: Double) -> CGPoint { scene(bodyTorso(x, f)) }
    /// front surface of the torso at spine fraction f (sternum ≈ 0.7, navel ≈ 0.3)
    func front(_ f: Double) -> CGPoint { torso(frontX(f), f) }
    func back(_ f: Double) -> CGPoint { torso(-0.5, f) }
    var headCentre: CGPoint { scene(headFrame().c) }
    var headR: Double { build.headR * h }
    /// point on the head in units of its radius (x toward the face, y down), in scene coords
    func headPoint(_ x: Double, _ y: Double) -> CGPoint {
        let (c, up) = headFrame()
        return scene(headSpot(c, up: up, r: headR, x, y))
    }
    var mouth: CGPoint { headPoint(0.97, 0.58) }
    func palm(near isNear: Bool = true) -> CGPoint { scene(armPoints(isNear ? near : far).palm) }
    func elbow(near isNear: Bool = true) -> CGPoint { scene(armPoints(isNear ? near : far).e) }
    var shoulderPoint: CGPoint { scene(bodyShoulder) }

    func draw(_ s: inout Sketch) {
        drawBack(&s)
        drawBody(&s)
        drawArm(&s, near: true)
    }

    /// far leg and far arm
    func drawBack(_ s: inout Sketch, farArm: Bool = true) {
        var g = framed(s)
        leg(&g, farLeg, shade: true)
        if farArm { arm(&g, far, shade: true) }
    }

    /// near leg, torso and head
    func drawBody(_ s: inout Sketch) {
        var g = framed(s)
        leg(&g, nearLeg, shade: false)
        trunk(&g)
        let (c, up) = headFrame()
        drawSideHead(&g, at: c, up: up, r: headR, look: look, face: face, baby: build.headR > 0.1)
    }

    func drawArm(_ s: inout Sketch, near isNear: Bool, shade: Bool = false) {
        var g = framed(s)
        arm(&g, isNear ? near : far, shade: shade)
    }

    // MARK: geometry

    private func framed(_ s: Sketch) -> Sketch {
        var g = s
        g.ctx.concatenate(tf)
        return g
    }

    private func rot(_ p: CGPoint, _ deg: Double) -> CGPoint {
        let a = deg * .pi / 180
        return CGPoint(x: p.x * cos(a) - p.y * sin(a), y: p.x * sin(a) + p.y * cos(a))
    }

    private func bodyTorso(_ x: Double, _ f: Double) -> CGPoint {
        rot(CGPoint(x: x * build.depth * h, y: -f * build.torso * h), lean)
    }

    private func frontX(_ f: Double) -> Double {
        let pts = frontPoints
        guard let i = pts.firstIndex(where: { $0.y <= f }), i > 0 else { return Double(pts.first?.x ?? 0.4) }
        let a = pts[i - 1], b = pts[i], u = (f - a.y) / (b.y - a.y)
        return a.x + (b.x - a.x) * u
    }

    /// front outline, top to bottom: x in depths, y = spine fraction
    private var frontPoints: [CGPoint] {
        let b = bump
        var p = [CGPoint(x: 0.22, y: 1.02), CGPoint(x: 0.5, y: 0.82)]
        if look.female { p.append(CGPoint(x: 0.64, y: 0.68)) }
        if b > 0 {
            p += [CGPoint(x: 0.46 + 0.15 * b, y: 0.55), CGPoint(x: 0.44 + 0.75 * b, y: 0.42), CGPoint(x: 0.42 + 0.95 * b, y: 0.26),
                  CGPoint(x: 0.45 + 0.6 * b, y: 0.1), CGPoint(x: 0.38, y: -0.04), CGPoint(x: 0.22, y: -0.12)]
        } else {
            p += [CGPoint(x: 0.46, y: 0.55), CGPoint(x: 0.42, y: 0.28), CGPoint(x: 0.45, y: 0.04), CGPoint(x: 0.22, y: -0.12)]
        }
        return p
    }

    private var bodyShoulder: CGPoint { bodyTorso(-0.12, 0.93) }

    private func headFrame() -> (c: CGPoint, up: CGPoint) {
        let neckTop = bodyTorso(0.05, 1 + build.neck / build.torso)
        let a = (lean + headTilt) * .pi / 180
        let up = CGPoint(x: sin(a), y: -cos(a)), f = CGPoint(x: -up.y, y: up.x), r = headR
        return (CGPoint(x: neckTop.x + f.x * 0.12 * r + up.x * 0.78 * r, y: neckTop.y + f.y * 0.12 * r + up.y * 0.78 * r), up)
    }

    private func armPoints(_ a: Arm) -> (s: CGPoint, e: CGPoint, w: CGPoint, palm: CGPoint, dir: CGPoint) {
        let s = bodyShoulder
        let U = build.upperArm * h, F = build.foreArm * h, half = build.hand * h * 0.45
        if let reach = a.reach {
            let t = reach.applying(tf.inverted())
            let sign = a.flip ? -1.0 : 1.0
            if let ang = a.handAngle {
                let lin = CGAffineTransform(a: tf.a, b: tf.b, c: tf.c, d: tf.d, tx: 0, ty: 0).inverted()
                let d = unit(CGPoint(x: cos(ang * .pi / 180), y: sin(ang * .pi / 180)).applying(lin))
                let wT = CGPoint(x: t.x - d.x * half, y: t.y - d.y * half)
                let (e, w) = twoBone(s, wT, U, F, sign)
                return (s, e, w, CGPoint(x: w.x + d.x * half, y: w.y + d.y * half), d)
            }
            let (e, end) = twoBone(s, t, U, F + half, sign)
            let d = unit(CGPoint(x: end.x - e.x, y: end.y - e.y))
            let w = CGPoint(x: e.x + d.x * F, y: e.y + d.y * F)
            return (s, e, w, end, d)
        }
        let a1 = (a.shoulder + lean) * .pi / 180, a2 = (a.shoulder + lean + a.elbow) * .pi / 180
        let e = CGPoint(x: s.x + sin(a1) * U, y: s.y + cos(a1) * U)
        let d = CGPoint(x: sin(a2), y: cos(a2))
        let w = CGPoint(x: e.x + d.x * F, y: e.y + d.y * F)
        return (s, e, w, CGPoint(x: w.x + d.x * half, y: w.y + d.y * half), d)
    }

    // MARK: drawing (body frame)

    private func arm(_ g: inout Sketch, _ a: Arm, shade: Bool) {
        let (s, e, w, palm, d) = armPoints(a)
        let aw = build.armW * h
        let cuff = look.longSleeves ? lerp(e, w, 0.85) : lerp(s, e, 0.75)
        let skin = look.longSleeves ? [e, w] : [s, e, w]
        g.limb(skin, w: aw * 0.8, fill: look.skin, line: look.skinLine)
        g.limb(look.longSleeves ? [s, e, cuff] : [s, cuff], w: aw, fill: look.top, line: look.topLine)
        drawHand(&g, at: palm, dir: d, len: build.hand * h, shape: a.hand, look: look)
        if shade { g.limb([s, e, w, palm], w: aw * 0.9, fill: .black.opacity(0.12), line: nil) }
    }

    private func leg(_ g: inout Sketch, _ l: Leg, shade: Bool) {
        let T = build.thigh * h, S = build.shin * h, lw = build.legW * h
        let a1 = l.hip * .pi / 180, a2 = (l.hip - l.knee) * .pi / 180, p = l.point * .pi / 180
        let k = CGPoint(x: sin(a1) * T, y: cos(a1) * T)
        let an = CGPoint(x: k.x + sin(a2) * S, y: k.y + cos(a2) * S)
        let fd = CGPoint(x: cos(a2) * cos(p) + sin(a2) * sin(p), y: -sin(a2) * cos(p) + cos(a2) * sin(p))
        let toe = CGPoint(x: an.x + fd.x * build.foot * h, y: an.y + fd.y * build.foot * h)
        let heel = CGPoint(x: an.x - fd.x * lw * 0.15, y: an.y - fd.y * lw * 0.15)
        g.limb([.zero, k, an], w: lw, fill: look.bottom, line: look.onePiece ? look.topLine : darker(look.bottom))
        g.limb([heel, lerp(heel, toe, 0.55)], w: lw * 0.55, fill: look.shoes, line: look.bareFeet ? look.skinLine : hex("#1E1E24"))
        g.limb([lerp(heel, toe, 0.4), toe], w: lw * 0.42, fill: look.shoes, line: look.bareFeet ? look.skinLine : hex("#1E1E24"))
        if shade { g.limb([.zero, k, an, toe], w: lw * 0.9, fill: .black.opacity(0.12), line: nil) }
    }

    private func trunk(_ g: inout Sketch) {
        let back = [CGPoint(x: -0.5, y: -0.06), CGPoint(x: -0.55, y: 0.08), CGPoint(x: -0.42, y: 0.38),
                    CGPoint(x: -0.52, y: 0.74), CGPoint(x: -0.4, y: 0.97), CGPoint(x: -0.2, y: 1.03), CGPoint(x: 0.02, y: 1.05)]
        let outline = (back + frontPoints).map { bodyTorso($0.x, $0.y) }
        // neck under the collar
        let nb = bodyTorso(0.0, 0.98), nt = bodyTorso(0.05, 1 + build.neck / build.torso + 0.08)
        g.limb([nb, nt], w: build.headR * h * 0.95, fill: look.skin, line: look.skinLine)
        g.shape(smoothPath(outline), fill: look.top, stroke: look.topLine, lw: 1.3)
        if !look.onePiece {
            let pants = [CGPoint(x: 0.44 + 0.3 * bump, y: 0.14), CGPoint(x: 0.47, y: 0.0), CGPoint(x: 0.24, y: -0.13),
                         CGPoint(x: -0.5, y: -0.07), CGPoint(x: -0.57, y: 0.06), CGPoint(x: -0.46, y: 0.16)].map { bodyTorso($0.x, $0.y) }
            g.shape(smoothPath(pants), fill: look.bottom, stroke: darker(look.bottom), lw: 1.2)
        }
        // collar
        let c1 = bodyTorso(0.25, 1.0), c2 = bodyTorso(0.05, 0.93), c3 = bodyTorso(-0.15, 1.02)
        g.shape(openPath([c1, c2, c3]), stroke: look.topLine, lw: 1.1)
    }
}

// MARK: - Front view

/// Person facing us from behind the casualty (kneeling or standing), upper body only matters.
struct FrontFigure {
    enum Hands: Sendable { case open, interlocked, thumbs, twoFingers, raised }
    var h: Double
    var build = Build.adult
    var look = Look.rescuer
    /// base of the neck
    var neck: CGPoint
    /// 0 upright … 1 bent right over toward us
    var bow = 0.0
    var face = Face.calm
    /// viewer's left / right palm centres
    var left: CGPoint
    var right: CGPoint
    var hands = Hands.open
    /// trousers reach down to here (hidden behind the casualty anyway)
    var floor: Double? = nil

    /// neck position that puts straight arms onto `hands` (locked-elbow compressions)
    static func neckAbove(_ hands: CGPoint, h: Double, build: Build = .adult) -> CGPoint {
        let sx = build.shoulderW * 0.85 * h, L = (build.upperArm + build.foreArm + build.hand * 0.3) * h
        return CGPoint(x: hands.x, y: hands.y - (L * L - sx * sx).squareRoot() - 0.035 * h)
    }

    var headCentre: CGPoint {
        let r = build.headR * h
        return CGPoint(x: neck.x, y: neck.y - (build.neck * h + 0.95 * r) * (1 - 1.3 * bow))
    }

    /// torso and head
    func draw(_ s: inout Sketch) {
        let sw = build.shoulderW * h, r = build.headR * h
        let tl = build.torso * h * (1 - 0.4 * bow)
        let n = neck
        let head = headCentre
        if look.style == .long {
            s.rect(head.x - 0.95 * r, head.y - 0.6 * r, 1.9 * r, 2.1 * r, r: 0.8 * r, fill: look.hair)
        }
        if let floor, bow <= 0.5 {
            s.rect(n.x - sw * 0.82, n.y + tl - 4, sw * 1.64, floor - n.y - tl + 4, r: 4, fill: look.bottom, stroke: darker(look.bottom))
        }
        let body = [CGPoint(x: -0.3, y: -0.01), CGPoint(x: -0.9, y: 0.03), CGPoint(x: -1.04, y: 0.2), CGPoint(x: -0.9, y: 0.55),
                    CGPoint(x: -0.82, y: 1.0), CGPoint(x: 0.82, y: 1.0), CGPoint(x: 0.9, y: 0.55), CGPoint(x: 1.04, y: 0.2),
                    CGPoint(x: 0.9, y: 0.03), CGPoint(x: 0.3, y: -0.01)]
            .map { CGPoint(x: n.x + $0.x * sw, y: n.y + ($0.y < 0.3 ? $0.y * 0.35 * build.torso * h : $0.y * tl) * (bow > 0.5 ? -0.9 : 1)) }
        s.limb([CGPoint(x: n.x, y: n.y + 2), CGPoint(x: n.x, y: head.y + r * 0.6)], w: r * 0.85, fill: look.skin, line: look.skinLine)
        s.shape(smoothPath(body), fill: look.top, stroke: look.topLine, lw: 1.3)
        s.shape(openPath([CGPoint(x: n.x - r * 0.45, y: n.y - 1), CGPoint(x: n.x, y: n.y + r * 0.55), CGPoint(x: n.x + r * 0.45, y: n.y - 1)]),
                stroke: look.topLine, lw: 1.1)
        drawFrontHead(&s, at: head, r: r, look: look, face: face, bow: bow)
    }

    /// arms and hands, drawn after whatever they rest on
    func drawArms(_ s: inout Sketch) {
        for side in [-1.0, 1.0] { arm(&s, side) }
        if hands == .interlocked {
            // top hand's fingers laced over the bottom hand
            let c = lerp(left, right, 0.5), L = build.hand * h
            for i in 0..<4 {
                let x = c.x - L * 0.3 + Double(i) * L * 0.2
                s.line(x, c.y - L * 0.05, x - L * 0.05, c.y + L * 0.28, stroke: look.skinLine, lw: 0.8)
            }
        }
    }

    private func arm(_ s: inout Sketch, _ side: Double) {
        let sw = build.shoulderW * h
        let sh = CGPoint(x: neck.x + side * sw * 0.85, y: neck.y + 0.035 * h)
        let target = side < 0 ? left : right
        let U = build.upperArm * h, F = build.foreArm * h, half = build.hand * h * 0.35
        let (e1, _) = twoBone(sh, target, U, F + half, 1), (e2, _) = twoBone(sh, target, U, F + half, -1)
        let e = (e1.x - neck.x) * side > (e2.x - neck.x) * side ? e1 : e2
        let d = unit(CGPoint(x: target.x - e.x, y: target.y - e.y))
        let w = CGPoint(x: target.x - d.x * half, y: target.y - d.y * half)
        let aw = build.armW * h
        if look.longSleeves {
            s.limb([e, w], w: aw * 0.8, fill: look.skin, line: look.skinLine)
            s.limb([sh, e, lerp(e, w, 0.85)], w: aw, fill: look.top, line: look.topLine)
        } else {
            s.limb([sh, e, w], w: aw * 0.8, fill: look.skin, line: look.skinLine)
            s.limb([sh, lerp(sh, e, 0.75)], w: aw, fill: look.top, line: look.topLine)
        }
        var shape = SideFigure.Hand.open
        if hands == .twoFingers && side > 0 { shape = .twoFingers }
        drawHand(&s, at: target, dir: d, len: build.hand * h, shape: shape, look: look, thumb: -side)
    }
}

// MARK: - Parts

/// Profile head in its own frame: `up` = unit vector to the crown; the face is on its clockwise side.
func drawSideHead(_ s: inout Sketch, at c: CGPoint, up: CGPoint, side: Double = 1, r: Double, look: Look, face: Face, baby: Bool = false) {
    var g = s
    let f = CGPoint(x: -up.y * side, y: up.x * side)
    g.ctx.concatenate(CGAffineTransform(a: f.x * r, b: f.y * r, c: -up.x * r, d: -up.y * r, tx: c.x, ty: c.y))
    let lw = 1.2 / r
    func P(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }
    if look.style == .long {
        var hair = Path()
        hair.move(to: P(-0.3, -0.9))
        hair.addCurve(to: P(-0.75, 1.6), control1: P(-1.2, -0.5), control2: P(-1.15, 1.2))
        hair.addLine(to: P(-0.1, 1.45))
        hair.addCurve(to: P(0, -0.2), control1: P(-0.35, 0.9), control2: P(-0.3, 0.2))
        g.shape(hair, fill: look.hair)
    }
    var p = Path()
    p.move(to: P(-0.25, 0.95))
    p.addCurve(to: P(-0.98, -0.05), control1: P(-0.75, 0.85), control2: P(-1.0, 0.4))
    p.addCurve(to: P(0.12, -1.08), control1: P(-0.96, -0.75), control2: P(-0.45, -1.1))
    p.addCurve(to: P(0.9, -0.3), control1: P(0.62, -1.05), control2: P(0.9, -0.72))
    p.addLine(to: P(0.93, -0.1))
    if baby {
        p.addCurve(to: P(1.04, 0.3), control1: P(0.96, 0.05), control2: P(1.06, 0.2))
        p.addLine(to: P(0.96, 0.4))
    } else {
        p.addCurve(to: P(1.14, 0.3), control1: P(0.97, 0.02), control2: P(1.12, 0.22))
        p.addLine(to: P(0.97, 0.37))
    }
    p.addLine(to: P(1.0, 0.5))
    p.addLine(to: P(0.94, 0.57))
    p.addLine(to: P(0.98, 0.64))
    p.addCurve(to: P(0.78, 0.93), control1: P(0.96, 0.78), control2: P(0.9, 0.88))
    p.addCurve(to: P(0.1, 0.92), control1: P(0.55, 1.02), control2: P(0.3, 1.0))
    p.closeSubpath()
    g.shape(p, fill: look.skin, stroke: look.skinLine, lw: lw)
    // hair
    var hr = Path()
    switch look.style {
    case .baby:
        hr.move(to: P(-0.35, -1.02)); hr.addQuadCurve(to: P(0.15, -1.06), control: P(-0.1, -1.3))
        hr.move(to: P(0.05, -1.05)); hr.addQuadCurve(to: P(0.5, -0.9), control: P(0.35, -1.25))
        g.shape(hr, stroke: look.hair, lw: 0.09, cap: .round)
    default:
        let front = look.style == .thin ? P(0.3, -1.02) : P(0.8, -0.6)
        hr.move(to: front)
        hr.addCurve(to: P(-0.95, -0.35), control1: look.style == .thin ? P(-0.2, -1.2) : P(0.72, -1.3), control2: P(-0.62, -1.3))
        hr.addCurve(to: P(-0.62, 0.55), control1: P(-1.07, 0.05), control2: P(-0.9, 0.4))
        hr.addCurve(to: P(0.05, -0.15), control1: P(-0.35, 0.45), control2: P(-0.35, -0.1))
        hr.addCurve(to: front, control1: P(0.3, -0.35), control2: P(0.55, -0.45))
        hr.closeSubpath()
        g.shape(hr, fill: look.hair, stroke: darker(look.hair), lw: lw * 0.6)
        if look.style == .bun { g.circle(-0.82, -0.72, 0.3, fill: look.hair, stroke: darker(look.hair), lw: lw * 0.6) }
    }
    // ear
    g.ellipse(-0.1, 0.1, 0.17, 0.25, fill: look.skin, stroke: look.skinLine, lw: lw)
    g.path("M -0.05 0 Q -0.16 0.1 -0.06 0.22", stroke: look.skinLine, lw: lw * 0.8)
    // eye, brow, mouth
    let ink = hex("#3A3038")
    switch face {
    case .closed:
        g.path("M 0.5 0.0 Q 0.6 0.08 0.72 0.0", stroke: ink, lw: lw * 1.1, cap: .round)
    default:
        g.ellipse(0.62, -0.02, 0.07, face == .distress ? 0.12 : 0.1, fill: ink)
    }
    g.path(face == .distress ? "M 0.46 -0.22 L 0.78 -0.32" : "M 0.46 -0.24 Q 0.62 -0.3 0.8 -0.22",
           stroke: look.style == .thin ? hex("#A0A0A0") : look.hair, lw: 0.07, cap: .round)
    if face == .distress || face == .open {
        g.ellipse(0.9, 0.6, 0.1, 0.12, fill: hex("#7A2E34"))
    } else {
        g.path("M 0.95 0.57 L 0.83 0.6", stroke: look.skinLine, lw: lw, cap: .round)
    }
    if baby { g.circle(0.55, 0.35, 0.14, fill: hex("#F2A0A0"), opacity: 0.35) }
}

/// Face-on head; `bow` tips it toward us so we see more hair and the face drops.
func drawFrontHead(_ s: inout Sketch, at c: CGPoint, r: Double, look: Look, face: Face, bow: Double = 0) {
    let ink = hex("#3A3038"), sh = bow * 0.35 * r
    for side in [-1.0, 1.0] { s.ellipse(c.x + side * 0.84 * r, c.y + 0.12 * r + sh * 0.5, 0.16 * r, 0.24 * r, fill: look.skin, stroke: look.skinLine) }
    s.ellipse(c.x, c.y, 0.84 * r, r, fill: look.skin, stroke: look.skinLine, lw: 1.2)
    let fr = c.y + (-0.42 + bow * 0.55) * r
    var hair = Path()
    hair.move(to: CGPoint(x: c.x - 0.88 * r, y: c.y + 0.05 * r))
    hair.addCurve(to: CGPoint(x: c.x + 0.88 * r, y: c.y + 0.05 * r), control1: CGPoint(x: c.x - 0.98 * r, y: c.y - 1.38 * r),
                  control2: CGPoint(x: c.x + 0.98 * r, y: c.y - 1.38 * r))
    hair.addCurve(to: CGPoint(x: c.x - 0.88 * r, y: c.y + 0.05 * r), control1: CGPoint(x: c.x + 0.6 * r, y: fr),
                  control2: CGPoint(x: c.x - 0.6 * r, y: fr))
    if look.style != .baby { s.shape(hair, fill: look.hair, stroke: darker(look.hair), lw: 0.8) }
    if look.style == .bun { s.circle(c.x, c.y - 1.05 * r, 0.3 * r, fill: look.hair) }
    guard bow < 0.85 else { return }
    let ey = c.y + 0.08 * r + sh
    for side in [-1.0, 1.0] {
        let ex = c.x + side * 0.32 * r
        if face == .closed || bow > 0.5 {
            s.path("M \(ex - 0.1 * r) \(ey) Q \(ex) \(ey + 0.07 * r) \(ex + 0.1 * r) \(ey)", stroke: ink, lw: 1, cap: .round)
        } else {
            s.ellipse(ex, ey, 0.075 * r, 0.1 * r, fill: ink)
        }
        s.line(ex - side * 0.06 * r, ey - 0.2 * r, ex + side * 0.14 * r, ey - 0.23 * r, stroke: darker(look.hair), lw: 1.2, cap: .round)
    }
    s.path("M \(c.x - 0.03 * r) \(ey + 0.12 * r) Q \(c.x - 0.1 * r) \(ey + 0.3 * r) \(c.x + 0.04 * r) \(ey + 0.33 * r)", stroke: look.skinLine, lw: 1)
    let my = ey + 0.52 * r - sh * 0.3
    if face == .open || face == .distress {
        s.ellipse(c.x, my, 0.14 * r, 0.1 * r, fill: hex("#7A2E34"))
    } else if bow < 0.4 {
        s.path("M \(c.x - 0.16 * r) \(my) Q \(c.x) \(my + 0.07 * r) \(c.x + 0.16 * r) \(my)", stroke: hex("#B5655E"), lw: 1.1, cap: .round)
    }
}

/// Hand with fingers, palm centre at `c`, fingers along `dir`; `thumb` picks the side.
func drawHand(_ s: inout Sketch, at c: CGPoint, dir: CGPoint, len L: Double, shape: SideFigure.Hand, look: Look, thumb: Double = -1) {
    var g = s
    g.ctx.concatenate(CGAffineTransform(a: dir.x, b: dir.y, c: -dir.y, d: dir.x, tx: c.x, ty: c.y))
    var look = look
    if let gl = look.gloves { (look.skin, look.skinLine) = (gl, darker(gl)) }
    let W = L * 0.44
    if shape == .fist {
        g.circle(-0.05 * L, 0, 0.3 * L, fill: look.skin, stroke: look.skinLine, lw: 1.2)
        g.line(0.02 * L, thumb * 0.22 * L, 0.2 * L, thumb * 0.02 * L, stroke: look.skinLine, lw: 1, cap: .round)
        return
    }
    let palm = Path(roundedRect: CGRect(x: -0.5 * L, y: -W / 2, width: 0.6 * L, height: W), cornerRadius: W * 0.45)
    let fingers: Path
    if shape == .twoFingers {
        fingers = Path(roundedRect: CGRect(x: 0, y: -thumb * W * 0.05 - W * 0.22, width: 0.55 * L, height: W * 0.44), cornerRadius: W * 0.2)
    } else {
        fingers = Path(roundedRect: CGRect(x: 0, y: -W * 0.42, width: 0.5 * L, height: W * 0.84), cornerRadius: W * 0.38)
    }
    var th = Path()
    th.move(to: CGPoint(x: -0.25 * L, y: thumb * 0.3 * W))
    th.addLine(to: CGPoint(x: 0.08 * L, y: thumb * 0.62 * W))
    let tw = W * 0.34
    g.ctx.stroke(palm, with: .color(look.skinLine), lineWidth: 2)
    g.ctx.stroke(fingers, with: .color(look.skinLine), lineWidth: 2)
    g.ctx.stroke(th, with: .color(look.skinLine), style: StrokeStyle(lineWidth: tw + 2, lineCap: .round))
    g.ctx.fill(palm, with: .color(look.skin))
    g.ctx.fill(fingers, with: .color(look.skin))
    g.ctx.stroke(th, with: .color(look.skin), style: StrokeStyle(lineWidth: tw, lineCap: .round))
    let splits: [Double] = shape == .twoFingers ? [-thumb * W * 0.05] : [-0.2, 0.02, 0.22].map { $0 * W }
    for y in splits { g.line(0.12 * L, y, 0.44 * L, y, stroke: look.skinLine, lw: 0.6) }
    if shape == .twoFingers { g.circle(0.02 * L, thumb * W * 0.3, W * 0.22, fill: look.skin, stroke: look.skinLine, lw: 0.8) }
}

// MARK: - Helpers

/// point in a profile head's frame (units of r, x toward the face, y down) → scene
func headSpot(_ c: CGPoint, up: CGPoint, r: Double, _ x: Double, _ y: Double, side: Double = 1) -> CGPoint {
    let f = CGPoint(x: -up.y * side, y: up.x * side)
    return CGPoint(x: c.x + (f.x * x - up.x * y) * r, y: c.y + (f.y * x - up.y * y) * r)
}

extension Sketch {
    /// round-capped polyline with an outline, for limbs
    mutating func limb(_ pts: [CGPoint], w: Double, fill: Color, line: Color?) {
        guard pts.count > 1 else { return }
        let p = openPath(pts)
        if let line { ctx.stroke(p, with: .color(line), style: StrokeStyle(lineWidth: w + 2.2, lineCap: .round, lineJoin: .round)) }
        ctx.stroke(p, with: .color(fill), style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
    }
}

func openPath(_ pts: [CGPoint]) -> Path {
    var p = Path()
    p.addLines(pts)
    return p
}

/// closed Catmull-Rom curve through the points
func smoothPath(_ p: [CGPoint]) -> Path {
    var path = Path()
    let n = p.count
    guard n > 2 else { return openPath(p) }
    path.move(to: p[0])
    for i in 0..<n {
        let p0 = p[(i - 1 + n) % n], p1 = p[i], p2 = p[(i + 1) % n], p3 = p[(i + 2) % n]
        path.addCurve(to: p2, control1: CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6),
                      control2: CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6))
    }
    path.closeSubpath()
    return path
}

func lerp(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint { CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t) }

func unit(_ p: CGPoint) -> CGPoint {
    let l = max(1e-6, (p.x * p.x + p.y * p.y).squareRoot())
    return CGPoint(x: p.x / l, y: p.y / l)
}

/// two-bone reach from `s` toward `t`: elbow on the `sign` side; returns elbow and end (clamped to reach)
func twoBone(_ s: CGPoint, _ t: CGPoint, _ l1: Double, _ l2: Double, _ sign: Double) -> (CGPoint, CGPoint) {
    let dx = t.x - s.x, dy = t.y - s.y
    let dist = max(1e-6, (dx * dx + dy * dy).squareRoot())
    let d = min(max(dist, abs(l1 - l2) + 0.01), l1 + l2 - 0.01)
    let u = CGPoint(x: dx / dist, y: dy / dist)
    let a = (l1 * l1 - l2 * l2 + d * d) / (2 * d), k = max(0, l1 * l1 - a * a).squareRoot()
    let e = CGPoint(x: s.x + u.x * a - u.y * k * sign, y: s.y + u.y * a + u.x * k * sign)
    return (e, CGPoint(x: s.x + u.x * d, y: s.y + u.y * d))
}

/// a darker outline colour for a fill
func darker(_ c: Color) -> Color {
    let r = c.resolve(in: EnvironmentValues())
    return Color(red: Double(r.red) * 0.72, green: Double(r.green) * 0.72, blue: Double(r.blue) * 0.72)
}
