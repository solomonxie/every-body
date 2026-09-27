import SwiftUI

/// Body proportions as fractions of standing height.
struct Build: Sendable {
    var headR: Double, neck: Double, torso: Double, depth: Double, shoulderW: Double
    var upperArm: Double, foreArm: Double, hand: Double, armW: Double
    var thigh: Double, shin: Double, foot: Double, legW: Double

    static let adult = Build(headR: 0.077, neck: 0.034, torso: 0.3, depth: 0.12, shoulderW: 0.105,
                             upperArm: 0.18, foreArm: 0.155, hand: 0.1, armW: 0.05, thigh: 0.245, shin: 0.24, foot: 0.12, legW: 0.075)
    static let child = Build(headR: 0.1, neck: 0.026, torso: 0.29, depth: 0.13, shoulderW: 0.1,
                             upperArm: 0.165, foreArm: 0.14, hand: 0.1, armW: 0.055, thigh: 0.22, shin: 0.2, foot: 0.12, legW: 0.08)
    /// ~2 years: big head, short legs
    static let toddler = Build(headR: 0.112, neck: 0.018, torso: 0.3, depth: 0.15, shoulderW: 0.115,
                               upperArm: 0.15, foreArm: 0.13, hand: 0.09, armW: 0.068, thigh: 0.19, shin: 0.165, foot: 0.12, legW: 0.095)
    static let infant = Build(headR: 0.128, neck: 0.012, torso: 0.32, depth: 0.17, shoulderW: 0.13,
                              upperArm: 0.13, foreArm: 0.12, hand: 0.085, armW: 0.075, thigh: 0.16, shin: 0.14, foot: 0.11, legW: 0.1)
}

/// Colours, hair and clothes of one person.
struct Look: Sendable {
    enum Hair: Sendable { case short, long, bun, baby, thin, curly, ponytail }
    var skin = Skin.light, skinLine = edge(Skin.light)
    var hair = hex("#2E2A2E"), style = Hair.short
    var top = hex("#5B7BD5"), topLine = edge(hex("#5B7BD5"))
    var bottom = hex("#2F3A58"), shoes = hex("#2A2D3A")
    var longSleeves = true
    /// dress or onesie: no separate trousers
    var onePiece = false
    var female = false
    /// disposable gloves
    var gloves: Color? = nil
    var glasses = false
    /// drawn with character-art parts (`PeopleArt`) in this head style; nil = the hand-built figure
    var art: PeopleArt.Head? = nil
    var sneakers = false

    /// flat skin tones for a diverse cast
    enum Skin {
        static let fair = hex("#F6D5BF"), light = hex("#EFC3A2"), tan = hex("#D9A07A"), brown = hex("#A9704F"), deep = hex("#7C4C35")
    }

    /// soft, low-contrast edge for a flat fill
    static func edge(_ c: Color) -> Color { dim(c, 0.84) }

    init(skin: Color = Skin.light, hair: Color = hex("#2E2A2E"), style: Hair = .short, top: Color = hex("#5B7BD5"), bottom: Color = hex("#2F3A58"),
         shoes: Color = hex("#2A2D3A"), longSleeves: Bool = true, onePiece: Bool = false, female: Bool = false, glasses: Bool = false) {
        (self.skin, skinLine, self.hair, self.style, self.top, topLine) = (skin, Look.edge(skin), hair, style, top, Look.edge(top))
        (self.bottom, self.shoes, self.longSleeves, self.onePiece, self.female, self.glasses) = (bottom, shoes, longSleeves, onePiece, female, glasses)
    }

    static let rescuer = Look(skin: Skin.light, hair: hex("#3A2C28"))
    static let helper = Look(skin: Skin.deep, hair: hex("#1F1A1C"), style: .curly, top: hex("#3FA59A"), bottom: hex("#34405E"), female: true)
    static let man = Look(skin: Skin.fair, hair: hex("#6A4A36"), top: hex("#DCE5F0"), bottom: hex("#56657F"))
    static let woman = Look(skin: Skin.tan, hair: hex("#2B2024"), style: .long, top: hex("#E58A9C"), bottom: hex("#4A4466"), female: true)
    static let senior = Look(skin: Skin.fair, hair: hex("#E4E1DC"), style: .thin, top: hex("#8FB39D"), bottom: hex("#555A68"), glasses: true)
    static let kid = Look(skin: Skin.brown, hair: hex("#231A17"), style: .curly, top: hex("#F2B544"), bottom: hex("#4A78BE"), longSleeves: false)
    static let toddler = Look(skin: Skin.light, hair: hex("#8A6240"), top: hex("#F0977C"), bottom: hex("#6FA3C8"), longSleeves: false)
    static let baby = Look(skin: hex("#E7B48F"), hair: hex("#7A5A40"), style: .baby, top: hex("#BFE3D0"), bottom: hex("#BFE3D0"),
                           shoes: hex("#E7B48F"), onePiece: true)

    var bareFeet: Bool { style == .baby }
    var brow: Color { style == .thin ? hex("#A8A4A0") : hair }

    /// the same person in shadow: far limbs, the side turned away
    func shaded(_ k: Double = 0.88) -> Look {
        var l = self
        (l.skin, l.skinLine, l.top, l.topLine) = (dim(skin, k), dim(skinLine, k), dim(top, k), dim(topLine, k))
        (l.bottom, l.shoes, l.hair) = (dim(bottom, k), dim(shoes, k), dim(hair, k))
        if let g = gloves { l.gloves = dim(g, k) }
        return l
    }
}

enum Face: Sendable { case calm, closed, distress, open }

/// The person a first-aid scene is about, sized relative to an adult of height `h`.
struct Casualty {
    var look: Look, build: Build, h: Double, bump: Double = 0

    init(_ p: Profile, adult h: Double, adultLook: Look = .man) {
        switch p.age {
        case .infant: (look, build, self.h) = (.baby, .infant, h * 0.4)
        case .child: (look, build, self.h) = (.kid, .child, h * 0.68)
        case .toddler: (look, build, self.h) = (.toddler, .toddler, h * 0.5)
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
    enum Hand: Sendable { case open, fist, twoFingers, laced, thumb, encircle }
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
    /// soft contact shadow under the feet when upright
    var shadow = true

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
    /// along the leg: 0 hip, 1 knee, 2 ankle
    func legPoint(near isNear: Bool = true, _ f: Double) -> CGPoint {
        let l = isNear ? nearLeg : farLeg
        let a1 = l.hip * .pi / 180, a2 = (l.hip - l.knee) * .pi / 180
        let k = CGPoint(x: sin(a1) * build.thigh * h, y: cos(a1) * build.thigh * h)
        let an = CGPoint(x: k.x + sin(a2) * build.shin * h, y: k.y + cos(a2) * build.shin * h)
        return scene(f <= 1 ? lerp(.zero, k, f) : lerp(k, an, f - 1))
    }

    func draw(_ s: inout Sketch) {
        drawBack(&s)
        drawBody(&s)
        drawArm(&s, near: true)
    }

    /// far leg and far arm (and the floor shadow)
    func drawBack(_ s: inout Sketch, farArm: Bool = true) {
        if shadow { floorShadow(&s) }
        var g = framed(s)
        let dark = look.shaded()
        leg(&g, farLeg, look: dark)
        if farArm { arm(&g, far, look: dark) }
    }

    /// near leg, torso and head
    func drawBody(_ s: inout Sketch) {
        var g = framed(s)
        leg(&g, nearLeg, look: look)
        let (c, up) = headFrame()
        let baby = build.headR > 0.1
        if look.art != nil {
            // library heads carry their own neck: it tucks in behind the collar
            drawSideHead(&g, at: c, up: up, r: headR, look: look, face: face, baby: baby, only: [.back, .skin])
            trunk(&g)
            drawSideHead(&g, at: c, up: up, r: headR, look: look, face: face, baby: baby, only: [.front])
            return
        }
        trunk(&g)
        drawSideHead(&g, at: c, up: up, r: headR, look: look, face: face, baby: baby)
    }

    func drawArm(_ s: inout Sketch, near isNear: Bool, shade: Bool = false) {
        var g = framed(s)
        arm(&g, isNear ? near : far, look: shade ? look.shaded() : look)
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
        var p = [CGPoint(x: 0.22, y: 1.02), CGPoint(x: 0.48, y: 0.84)]
        if look.female { p.append(CGPoint(x: 0.64, y: 0.68)) } else { p.append(CGPoint(x: 0.52, y: 0.7)) }
        if b > 0 {
            p += [CGPoint(x: 0.46 + 0.15 * b, y: 0.55), CGPoint(x: 0.44 + 0.75 * b, y: 0.42), CGPoint(x: 0.42 + 0.95 * b, y: 0.26),
                  CGPoint(x: 0.45 + 0.6 * b, y: 0.1), CGPoint(x: 0.38, y: -0.04), CGPoint(x: 0.22, y: -0.12)]
        } else {
            p += [CGPoint(x: 0.44, y: 0.52), CGPoint(x: 0.38, y: 0.32), CGPoint(x: 0.44, y: 0.06), CGPoint(x: 0.22, y: -0.12)]
        }
        return p
    }

    private var bodyShoulder: CGPoint { bodyTorso(-0.12, 0.93) }

    private func headFrame() -> (c: CGPoint, up: CGPoint) {
        let neckTop = bodyTorso(0.05, 1 + build.neck / build.torso)
        let a = (lean + headTilt) * .pi / 180
        let up = CGPoint(x: sin(a), y: -cos(a)), f = CGPoint(x: -up.y, y: up.x), r = headR
        if look.art != nil {
            // library neck runs down-back from the skull: put its middle on the collar
            let (fx, uy) = build.headR > 0.1 ? (0.2, 1.05) : (0.36, 1.18)
            return (CGPoint(x: neckTop.x + f.x * fx * r + up.x * uy * r, y: neckTop.y + f.y * fx * r + up.y * uy * r), up)
        }
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

    /// soft ellipse on the floor under whatever touches it, only while upright
    private func floorShadow(_ s: inout Sketch) {
        guard abs(rotation) < 25 else { return }
        let lw = build.legW * h
        var pts: [CGPoint] = []
        for n in [true, false] {
            let f = foot(near: n)
            pts += [CGPoint(x: f.ankle.x, y: f.ankle.y + lw * 0.3), CGPoint(x: f.toe.x, y: f.toe.y + lw * 0.2), legPoint(near: n, 1)]
        }
        guard let low = pts.map(\.y).max() else { return }
        let touching = pts.filter { $0.y > low - 0.03 * h }
        guard let x0 = touching.map(\.x).min(), let x1 = touching.map(\.x).max() else { return }
        let w = x1 - x0 + 0.16 * h
        s.ellipse((x0 + x1) / 2, low + 0.004 * h, w / 2, max(2, 0.016 * h), fill: Color(red: 0.2, green: 0.17, blue: 0.3).opacity(0.1))
    }

    private func arm(_ g: inout Sketch, _ a: Arm, look: Look) {
        let (s, e, w, palm, d) = armPoints(a)
        dressedArm(&g, s, e, w, aw: build.armW * h, look: look)
        drawHand(&g, at: palm, dir: d, len: build.hand * h, shape: a.hand, look: look)
    }

    private func leg(_ g: inout Sketch, _ l: Leg, look: Look) {
        let T = build.thigh * h, S = build.shin * h, lw = build.legW * h
        let a1 = l.hip * .pi / 180, a2 = (l.hip - l.knee) * .pi / 180, p = l.point * .pi / 180
        let k = CGPoint(x: sin(a1) * T, y: cos(a1) * T)
        let an = CGPoint(x: k.x + sin(a2) * S, y: k.y + cos(a2) * S)
        let fd = CGPoint(x: cos(a2) * cos(p) + sin(a2) * sin(p), y: -sin(a2) * cos(p) + cos(a2) * sin(p))
        let shin = CGPoint(x: sin(a2), y: cos(a2))
        drawShoe(&g, ankle: an, dir: fd, shin: shin, len: build.foot * h, w: lw, look: look)
        organicLeg(&g, hip: .zero, knee: k, ankle: an, lw: lw, look: look)
    }

    private func trunk(_ g: inout Sketch) {
        let back = [CGPoint(x: -0.46, y: -0.08), CGPoint(x: -0.56, y: 0.08), CGPoint(x: -0.4, y: 0.36),
                    CGPoint(x: -0.5, y: 0.72), CGPoint(x: -0.42, y: 0.94), CGPoint(x: -0.2, y: 1.03), CGPoint(x: 0.02, y: 1.05)]
        let outline = (back + frontPoints).map { bodyTorso($0.x, $0.y) }
        let d = build.depth * h
        // neck, shadowed under the jaw
        let nb = bodyTorso(0.02, 0.96), nt = bodyTorso(0.06, 1 + build.neck / build.torso + 0.1)
        let nr = headR * 0.36
        let art = look.art != nil
        if !art {
            g.shape(segmentPath(nb, nr * 1.05, nt, nr), fill: look.skin)
            g.shape(segmentPath(nb, nr * 1.05, lerp(nb, nt, 0.75), nr), fill: .black.opacity(0.08))
        }
        let body = smoothPath(outline)
        g.shape(body, fill: look.top)
        var sh = g
        sh.ctx.clip(to: body)
        // one flat shade tone down the back, light from the front
        sh.shape(openPath(back.map { bodyTorso($0.x - 0.08, $0.y) }), stroke: .black.opacity(0.07), lw: d * 0.5)
        if bump > 0 {
            let c = bodyTorso(0.62 + 0.3 * bump, 0.36)
            sh.ellipse(c.x - d * 0.05, c.y - d * 0.12, d * 0.2, d * 0.24, fill: .white, opacity: 0.16)
        }
        if !look.onePiece {
            // waistband sits under a bump
            let py = bump > 0 ? -0.02 : 0.12
            let pants = [CGPoint(x: frontX(py) + 0.02, y: py), CGPoint(x: bump > 0 ? frontX(-0.06) : 0.47, y: bump > 0 ? -0.06 : 0.0), CGPoint(x: 0.3, y: -0.14),
                         CGPoint(x: -0.1, y: -0.18), CGPoint(x: -0.5, y: -0.08), CGPoint(x: -0.56, y: 0.05), CGPoint(x: -0.5, y: 0.13)]
                .map { bodyTorso($0.x, $0.y) }
            let p = smoothPath(pants)
            g.shape(p, fill: look.bottom)
            var ps = g
            ps.ctx.clip(to: p)
            let b1 = bodyTorso(-0.6, py - 0.03), b2 = bodyTorso(1.2, py - 0.03)
            if !art { ps.line(b1.x, b1.y, b2.x, b2.y, stroke: .black, lw: max(0.8, d * 0.05), opacity: 0.1) }
            ps.shape(openPath([bodyTorso(-0.6, 0.12), bodyTorso(-0.56, -0.1)]), stroke: .black.opacity(0.08), lw: d * 0.4)
        }
        if art { return }
        // neckline
        let c1 = bodyTorso(0.24, 1.0), c2 = bodyTorso(0.06, 0.94), c3 = bodyTorso(-0.14, 1.02)
        g.shape(curvePath([c1, c2, c3]), stroke: dim(look.top, 0.8), lw: max(0.8, d * 0.05), cap: .round)
    }
}

/// flat shade laid over far limbs
let farShade = Color(red: 0.12, green: 0.1, blue: 0.2).opacity(0.12)

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
        let rx = r * 0.86
        let art = look.art != nil
        faceOnHairBack(&s, c: head, rx: rx, ry: r, look: look)
        if art && bow < 0.3 { PeopleArt.frontHead(&s, c: head, r: r, look: look, bow: bow, only: [.neck]) }
        if let floor, bow <= 0.5 {
            // kneeling: hips and two thighs coming toward us, knees on the floor
            let hy = n.y + tl - 6, pants = look.onePiece ? look.top : look.bottom
            for side in [-1.0, 1.0] {
                s.shape(segmentPath(CGPoint(x: n.x + side * sw * 0.42, y: hy), sw * 0.5, CGPoint(x: n.x + side * sw * 0.54, y: floor - sw * 0.35), sw * 0.42,
                                    bulge: sw * 0.05, sw * 0.05), fill: side > 0 ? dim(pants, 0.9) : pants)
            }
            s.rect(n.x - sw * 0.86, hy - 4, sw * 1.72, sw * 0.52, r: sw * 0.24, fill: pants)
            if !art { s.line(n.x, hy + sw * 0.3, n.x, hy + sw * 0.9, stroke: .black, lw: 1, opacity: 0.1) }
        }
        let flip = bow > 0.5 ? -0.9 : 1
        let body = art ? [(-0.24, -0.02), (-0.78, 0.0), (-1.0, 0.1), (-0.98, 0.36), (-0.84, 0.66), (-0.8, 1.0), (0.8, 1.0), (0.84, 0.66),
                          (0.98, 0.36), (1.0, 0.1), (0.78, 0.0), (0.24, -0.02)].map { CGPoint(x: $0.0, y: $0.1) }
            : [CGPoint(x: -0.3, y: -0.01), CGPoint(x: -0.8, y: 0.03), CGPoint(x: -1.02, y: 0.18), CGPoint(x: -0.94, y: 0.42),
                    CGPoint(x: -0.74, y: 0.7), CGPoint(x: -0.8, y: 0.98), CGPoint(x: -0.4, y: 1.02), CGPoint(x: 0.4, y: 1.02), CGPoint(x: 0.8, y: 0.98),
                    CGPoint(x: 0.74, y: 0.7), CGPoint(x: 0.94, y: 0.42), CGPoint(x: 1.02, y: 0.18), CGPoint(x: 0.8, y: 0.03), CGPoint(x: 0.3, y: -0.01)]
        func P(_ q: CGPoint) -> CGPoint { CGPoint(x: n.x + q.x * sw, y: n.y + (q.y < 0.3 ? q.y * 0.35 * build.torso * h : q.y * tl) * flip) }
        let nr = r * 0.36
        if !art { s.shape(segmentPath(CGPoint(x: n.x, y: n.y + 2), nr * 1.05, CGPoint(x: n.x, y: head.y + r * 0.55), nr), fill: look.skin) }
        if bow < 0.5 && !art { s.shape(segmentPath(CGPoint(x: n.x, y: n.y + 1), nr * 1.05, CGPoint(x: n.x, y: n.y - r * 0.3), nr), fill: .black.opacity(0.08)) }
        let torso = smoothPath(body.map(P))
        s.shape(torso, fill: look.top)
        var sh = s
        sh.ctx.clip(to: torso)
        // light from the upper left: one flat shade on the right flank
        if art {
            // library-style flat shade: one soft wedge down the far flank, open collar over a light undershirt
            sh.shape(smoothPath([(0.5, 0.05), (1.1, 0.0), (1.1, 1.1), (0.46, 1.1), (0.62, 0.6)].map { P(CGPoint(x: $0.0, y: $0.1)) }), fill: .black.opacity(0.1))
            if bow < 0.5 {
                sh.shape(openPath([(-0.26, -0.1), (0.26, -0.1), (0, 0.5)].map { P(CGPoint(x: $0.0, y: $0.1)) }), fill: Look.Tone.white)
                sh.shape(openPath([(-0.26, -0.1), (0.26, -0.1), (0, 0.3)].map { P(CGPoint(x: $0.0, y: $0.1)) }), fill: look.skin)
            }
        } else {
            sh.shape(openPath([CGPoint(x: 1.1, y: 0.1), CGPoint(x: 0.98, y: 0.5), CGPoint(x: 0.98, y: 1.05)].map(P)), stroke: .black.opacity(0.07), lw: sw * 0.6)
        }
        if !look.onePiece && bow < 0.5 && !art {
            let a = P(CGPoint(x: -0.9, y: 0.97)), b = P(CGPoint(x: 0.9, y: 0.97))
            sh.line(a.x, a.y, b.x, b.y, stroke: .black, lw: max(2, sw * 0.1), opacity: 0.06)
        }
        if bow < 0.6 && !art {
            s.shape(curvePath([CGPoint(x: n.x - r * 0.42, y: n.y - 1), CGPoint(x: n.x, y: n.y + r * 0.42), CGPoint(x: n.x + r * 0.42, y: n.y - 1)]),
                    stroke: dim(look.top, 0.8), lw: 1, cap: .round)
        }
        drawFrontHead(&s, at: head, r: r, look: look, face: face, bow: bow, backHair: false)
    }

    /// arms and hands, drawn after whatever they rest on
    func drawArms(_ s: inout Sketch) {
        for side in [-1.0, 1.0] { arm(&s, side) }
    }

    /// one arm: −1 = viewer's left, +1 = viewer's right (to layer an arm behind something)
    func drawArm(_ s: inout Sketch, side: Double) { arm(&s, side) }

    private func arm(_ s: inout Sketch, _ side: Double) {
        let sw = build.shoulderW * h
        let sh = CGPoint(x: neck.x + side * sw * 0.85, y: neck.y + 0.035 * h)
        let target = side < 0 ? left : right
        let U = build.upperArm * h, F = build.foreArm * h, half = build.hand * h * 0.35
        let (e1, _) = twoBone(sh, target, U, F + half, 1), (e2, _) = twoBone(sh, target, U, F + half, -1)
        let e = (e1.x - neck.x) * side > (e2.x - neck.x) * side ? e1 : e2
        let d = unit(CGPoint(x: target.x - e.x, y: target.y - e.y))
        let w = CGPoint(x: target.x - d.x * half, y: target.y - d.y * half)
        var armLook = look
        if look.art != nil { armLook.top = dim(look.top, side > 0 ? 0.84 : 0.92) }
        dressedArm(&s, sh, e, w, aw: build.armW * h, look: armLook)
        var shape = SideFigure.Hand.open
        if hands == .twoFingers && side > 0 { shape = .twoFingers }
        // interlocked: the right hand lies on top with its fingers laced down between the lower ones
        if hands == .interlocked && side > 0 { shape = .laced }
        if hands == .thumbs { shape = .encircle }
        drawHand(&s, at: target, dir: d, len: build.hand * h, shape: shape, look: look, thumb: -side)
    }
}

// MARK: - Heads

/// Profile head in its own frame: `up` = unit vector to the crown; the face is on its clockwise side.
func drawSideHead(_ s: inout Sketch, at c: CGPoint, up: CGPoint, side: Double = 1, r: Double, look: Look, face: Face, baby: Bool = false,
                  only: Set<PeopleArt.Layer>? = nil) {
    var g = s
    let f = CGPoint(x: -up.y * side, y: up.x * side)
    let tf = CGAffineTransform(a: f.x * r, b: f.y * r, c: -up.x * r, d: -up.y * r, tx: c.x, ty: c.y)
    if look.art != nil {
        PeopleArt.sideHead(&s, tf, look: look, face: face, baby: baby, only: only)
        return
    }
    g.ctx.concatenate(tf)
    func P(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }
    let hc = look.hair
    // hair that falls behind the head and neck
    switch look.style {
    case .long:
        var p = Path()
        p.move(to: P(-0.2, -1.0))
        p.addCurve(to: P(-0.9, 1.75), control1: P(-1.3, -0.8), control2: P(-1.25, 1.3))
        p.addQuadCurve(to: P(-0.05, 1.5), control: P(-0.45, 1.85))
        p.addCurve(to: P(0.05, -0.2), control1: P(-0.3, 0.9), control2: P(-0.2, 0.2))
        p.closeSubpath()
        g.shape(p, fill: dim(hc, 0.9))
    case .ponytail:
        var p = Path()
        p.move(to: P(-0.8, -0.55))
        p.addCurve(to: P(-1.25, 1.2), control1: P(-1.5, -0.3), control2: P(-1.5, 0.8))
        p.addCurve(to: P(-0.9, -0.2), control1: P(-1.05, 0.7), control2: P(-1.0, 0.1))
        p.closeSubpath()
        g.shape(p, fill: dim(hc, 0.9))
    case .curly:
        for (x, y, rr) in [(-0.35, -0.8, 0.52), (0.25, -0.9, 0.44), (-0.72, -0.4, 0.46), (-0.74, 0.2, 0.38), (0.62, -0.7, 0.3)] {
            g.circle(x, y, rr, fill: hc)
        }
    default: break
    }
    // skull, forehead, a small soft nose, round chin
    var p = Path()
    p.move(to: P(-0.22, 0.9))
    p.addCurve(to: P(-1.0, -0.05), control1: P(-0.74, 0.84), control2: P(-1.02, 0.42))
    p.addCurve(to: P(0.08, -1.08), control1: P(-0.98, -0.74), control2: P(-0.52, -1.1))
    p.addCurve(to: P(0.9, -0.3), control1: P(0.6, -1.06), control2: P(0.9, -0.72))
    if baby {
        p.addCurve(to: P(0.98, 0.2), control1: P(0.92, -0.05), control2: P(0.98, 0.08))
        p.addCurve(to: P(0.95, 0.4), control1: P(1.06, 0.26), control2: P(1.04, 0.38))
        p.addCurve(to: P(0.72, 0.9), control1: P(1.0, 0.6), control2: P(0.92, 0.84))
    } else {
        p.addCurve(to: P(0.98, 0.14), control1: P(0.92, -0.08), control2: P(0.92, 0.04))
        p.addCurve(to: P(0.97, 0.42), control1: P(1.1, 0.26), control2: P(1.1, 0.4))
        p.addCurve(to: P(0.78, 0.9), control1: P(0.98, 0.62), control2: P(0.94, 0.82))
    }
    p.addCurve(to: P(0.0, 0.84), control1: P(0.56, 1.02), control2: P(0.2, 0.96))
    p.closeSubpath()
    g.shape(p, fill: look.skin)
    // hair on top
    var hr = Path()
    switch look.style {
    case .curly:
        hr.move(to: P(0.72, -0.58))
        hr.addCurve(to: P(-0.25, -0.2), control1: P(0.4, -0.4), control2: P(0.05, -0.28))
        hr.addCurve(to: P(-0.62, 0.36), control1: P(-0.5, -0.1), control2: P(-0.55, 0.2))
        hr.addLine(to: P(-1.1, 0.2))
        hr.addLine(to: P(-0.6, -1.2))
        hr.closeSubpath()
        g.shape(hr, fill: hc)
        for (x, y, rr) in [(0.3, -0.92, 0.32), (0.62, -0.7, 0.25), (-0.2, -1.0, 0.36)] { g.circle(x, y, rr, fill: hc) }
    case .baby:
        // soft fuzz on the crown and one curl
        hr.move(to: P(0.46, -0.9))
        hr.addCurve(to: P(-0.9, -0.42), control1: P(0.1, -1.2), control2: P(-0.7, -1.1))
        hr.addCurve(to: P(0.46, -0.9), control1: P(-0.6, -0.8), control2: P(0.0, -0.98))
        g.shape(hr, fill: hc, opacity: 0.8)
        g.path("M 0.2 -1.0 Q 0.34 -1.24 0.08 -1.22", stroke: hc, lw: 0.07, opacity: 0.8, cap: .round)
    case .thin:
        // bald crown, a grey fringe round the back above the ear
        hr.move(to: P(0.05, -0.62))
        hr.addCurve(to: P(-1.02, -0.2), control1: P(-0.35, -0.95), control2: P(-0.9, -0.75))
        hr.addCurve(to: P(-0.78, 0.36), control1: P(-1.08, 0.05), control2: P(-0.98, 0.26))
        hr.addCurve(to: P(-0.3, -0.16), control1: P(-0.52, 0.2), control2: P(-0.4, 0.0))
        hr.addCurve(to: P(0.05, -0.62), control1: P(-0.2, -0.36), control2: P(-0.06, -0.5))
        hr.closeSubpath()
        g.shape(hr, fill: hc)
    default:
        // bold shape with volume above the skull: a quiff over the forehead, trimmed round the ear
        let tight = look.style == .bun || look.style == .ponytail
        hr.move(to: P(0.86, -0.44))
        if tight {
            hr.addCurve(to: P(-1.04, -0.3), control1: P(0.92, -1.3), control2: P(-0.72, -1.38))
        } else {
            hr.addCurve(to: P(0.42, -1.26), control1: P(1.02, -0.8), control2: P(0.84, -1.24))
            hr.addCurve(to: P(-1.06, -0.36), control1: P(-0.2, -1.34), control2: P(-0.98, -1.1))
        }
        if look.style == .long {
            hr.addCurve(to: P(-0.62, 0.62), control1: P(-1.16, 0.1), control2: P(-0.95, 0.5))
            hr.addCurve(to: P(-0.02, -0.16), control1: P(-0.3, 0.4), control2: P(-0.32, -0.08))
        } else {
            hr.addCurve(to: P(-0.74, 0.42), control1: P(-1.12, 0.02), control2: P(-0.98, 0.32))
            hr.addCurve(to: P(-0.3, 0.0), control1: P(-0.5, 0.3), control2: P(-0.32, 0.18))
            hr.addCurve(to: P(0.08, -0.08), control1: P(-0.26, -0.22), control2: P(0.02, -0.24))
        }
        hr.addCurve(to: P(0.86, -0.44), control1: P(0.24, -0.4), control2: P(0.6, -0.42))
        hr.closeSubpath()
        g.shape(hr, fill: hc)
        if look.style == .bun { g.circle(-0.86, -0.78, 0.32, fill: hc) }
        if look.style == .ponytail { g.circle(-0.95, -0.5, 0.18, fill: hc) }
    }
    // ear
    g.ellipse(-0.1, 0.14, 0.15, 0.21, fill: look.skin)
    g.ellipse(-0.08, 0.15, 0.07, 0.11, fill: dim(look.skin, 0.9))
    // face: small eye with a glint, brow, blush, short mouth
    let ink = Ink.ink
    g.ellipse(0.52, 0.34, 0.13, 0.09, fill: Ink.blush, opacity: baby ? 0.32 : 0.2)
    switch face {
    case .closed:
        g.path("M 0.5 0.0 Q 0.6 0.08 0.7 0.0", stroke: ink, lw: 0.06, cap: .round)
    default:
        g.ellipse(0.62, -0.01, 0.07, face == .distress ? 0.11 : 0.095, fill: ink)
        g.circle(0.64, -0.04, 0.025, fill: .white, opacity: 0.8)
    }
    g.path(face == .distress ? "M 0.48 -0.2 L 0.76 -0.28" : "M 0.48 -0.22 Q 0.62 -0.3 0.76 -0.24",
           stroke: look.brow, lw: baby ? 0.035 : 0.065, opacity: baby ? 0.5 : 0.9, cap: .round)
    if face == .distress || face == .open {
        g.ellipse(0.88, 0.6, 0.08, 0.1, fill: Ink.mouth)
    } else {
        g.path("M 0.95 0.58 Q 0.9 0.63 0.8 0.6", stroke: Ink.lip, lw: 0.055, cap: .round)
    }
    if look.glasses {
        g.circle(0.72, -0.02, 0.2, stroke: hex("#5A5560"), lw: 0.06)
        g.path("M 0.52 -0.06 L -0.02 -0.02", stroke: hex("#5A5560"), lw: 0.05)
    }
}

enum Ink {
    static let ink = hex("#2F2A36"), blush = hex("#F08C8C"), lip = hex("#B8606A"), mouth = hex("#6E2C38")
}

/// Face-on expressions shared by every front-facing person.
enum Expr: Sendable { case calm, smile, closed, worried, pain, distress, open, sneeze }

/// hair that falls behind a face-on head (long hair, curls); draw before the body
func faceOnHairBack(_ s: inout Sketch, c: CGPoint, rx: Double, ry: Double, look: Look) {
    if look.art != nil { PeopleArt.frontHead(&s, c: c, r: ry, look: look, only: [.back]); return }
    let hc = look.hair
    switch look.style {
    case .long:
        s.path("M \(c.x - rx * 1.02) \(c.y - ry * 0.3) C \(c.x - rx * 1.4) \(c.y + ry * 0.9) \(c.x - rx * 1.3) \(c.y + ry * 1.6) \(c.x - rx * 0.7) \(c.y + ry * 1.72) "
               + "L \(c.x + rx * 0.7) \(c.y + ry * 1.72) C \(c.x + rx * 1.3) \(c.y + ry * 1.6) \(c.x + rx * 1.4) \(c.y + ry * 0.9) \(c.x + rx * 1.02) \(c.y - ry * 0.3) Z",
               fill: dim(hc, 0.88))
    case .curly:
        for (x, y, rr) in [(-0.7, -0.62, 0.5), (0.7, -0.62, 0.5), (-0.25, -0.98, 0.5), (0.3, -0.98, 0.5), (-1.0, -0.05, 0.38), (1.0, -0.05, 0.38)] {
            s.ellipse(c.x + x * rx, c.y + y * ry, rr * rx, rr * ry * 0.95, fill: hc)
        }
    case .ponytail:
        s.ellipse(c.x + rx * 0.95, c.y - ry * 0.5, rx * 0.32, ry * 0.45, fill: dim(hc, 0.9))
    default: break
    }
}

/// Face-on head: ears, head, front hair and a simple characterful face. `bow` tips the face down toward us.
func faceOnHead(_ s: inout Sketch, c: CGPoint, rx: Double, ry: Double, look: Look, expr: Expr, droop: Double = 0, bow: Double = 0) {
    if look.art != nil { PeopleArt.frontHead(&s, c: c, r: ry, look: look, bow: bow, only: [.skin, .front]); return }
    let skin = look.skin, hc = look.hair, sh = bow * 0.35 * ry
    for side in [-1.0, 1.0] {
        s.ellipse(c.x + side * rx * 0.98, c.y + ry * 0.1 + sh * 0.5, rx * 0.17, ry * 0.2, fill: skin)
        s.ellipse(c.x + side * rx * 0.99, c.y + ry * 0.11 + sh * 0.5, rx * 0.08, ry * 0.11, fill: dim(skin, 0.9))
    }
    // head: wide cheekbones, softer chin
    let outline = [(0.0, -1.0), (0.72, -0.84), (1.0, -0.2), (0.93, 0.34), (0.66, 0.78), (0.24, 0.99), (-0.24, 0.99), (-0.66, 0.78), (-0.93, 0.34),
                   (-1.0, -0.2), (-0.72, -0.84)].map { CGPoint(x: c.x + $0.0 * rx, y: c.y + $0.1 * ry) }
    s.shape(smoothPath(outline), fill: skin)
    func P(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: c.x + x * rx, y: c.y + y * ry) }
    let fr = -0.44 + bow * 0.55
    switch look.style {
    case .baby:
        s.path("M \(c.x - 0.6 * rx) \(c.y - 0.8 * ry) Q \(c.x) \(c.y - 1.12 * ry) \(c.x + 0.6 * rx) \(c.y - 0.8 * ry) Q \(c.x) \(c.y - 0.92 * ry) \(c.x - 0.6 * rx) \(c.y - 0.8 * ry) Z",
               fill: hc, opacity: 0.8)
        s.path("M \(c.x - 0.05 * rx) \(c.y - 0.96 * ry) Q \(c.x + 0.1 * rx) \(c.y - 1.2 * ry) \(c.x - 0.12 * rx) \(c.y - 1.16 * ry)", stroke: hc, lw: max(1, rx * 0.07), opacity: 0.8, cap: .round)
    case .thin:
        for side in [-1.0, 1.0] {
            var p = Path()
            p.move(to: P(side * 1.02, 0.08))
            p.addCurve(to: P(side * 0.45, -0.9), control1: P(side * 1.12, -0.5), control2: P(side * 0.85, -0.85))
            p.addCurve(to: P(side * 0.86, 0.02), control1: P(side * 0.72, -0.72), control2: P(side * 0.86, -0.4))
            p.closeSubpath()
            s.shape(p, fill: hc)
        }
    case .curly:
        var p = Path()
        p.move(to: P(-0.98, -0.1))
        p.addCurve(to: P(0.98, -0.1), control1: P(-1.0, -1.3), control2: P(1.0, -1.3))
        p.addCurve(to: P(0.0, fr + 0.02), control1: P(0.9, fr - 0.05), control2: P(0.4, fr - 0.12))
        p.addCurve(to: P(-0.98, -0.1), control1: P(-0.4, fr - 0.12), control2: P(-0.9, fr - 0.05))
        s.shape(p, fill: hc)
        for x in [-0.5, 0.0, 0.5] { s.ellipse(c.x + x * rx, c.y + (fr - 0.08) * ry, rx * 0.28, ry * 0.2, fill: hc) }
    case .long:
        // centre parting, two curtains past the cheeks
        for side in [-1.0, 1.0] {
            var p = Path()
            p.move(to: P(side * 0.06, -1.04))
            p.addCurve(to: P(side * 1.1, 0.1), control1: P(side * 0.8, -1.22), control2: P(side * 1.2, -0.62))
            p.addCurve(to: P(side * 1.0, 0.95), control1: P(side * 1.08, 0.5), control2: P(side * 1.08, 0.8))
            p.addCurve(to: P(side * 0.78, fr + 0.3), control1: P(side * 0.86, 0.6), control2: P(side * 0.8, 0.2))
            p.addCurve(to: P(side * 0.06, -1.04), control1: P(side * 0.7, fr - 0.1), control2: P(side * 0.3, fr - 0.3))
            s.shape(p, fill: hc)
        }
    default:
        // bold cap with volume on top; the fringe lifts off the forehead from a side parting
        var p = Path()
        p.move(to: P(-1.0, -0.12))
        p.addCurve(to: P(0.15, -1.32), control1: P(-1.14, -1.0), control2: P(-0.62, -1.36))
        p.addCurve(to: P(1.0, -0.12), control1: P(0.96, -1.3), control2: P(1.14, -0.7))
        p.addCurve(to: P(0.42, fr - 0.3 + bow * 0.1), control1: P(0.92, fr - 0.06), control2: P(0.7, fr - 0.3))
        p.addCurve(to: P(-0.62, fr - 0.06), control1: P(0.1, fr - 0.22), control2: P(-0.3, fr - 0.1))
        p.addCurve(to: P(-1.0, -0.12), control1: P(-0.84, fr - 0.02), control2: P(-0.94, -0.24))
        s.shape(p, fill: hc)
        if look.style == .bun { s.circle(c.x, c.y - 1.12 * ry, 0.36 * rx, fill: hc) }
    }
    guard bow < 0.85 else { return }
    let ink = Ink.ink, ey = c.y + 0.1 * ry + sh
    let squint = expr == .closed || expr == .pain || expr == .sneeze || bow > 0.5
    let worried = expr == .worried || expr == .pain || expr == .distress
    for side in [-1.0, 1.0] {
        let sag = side < 0 ? droop : 0
        let x = c.x + side * 0.36 * rx, y = ey + sag * ry * 0.06
        s.ellipse(c.x + side * 0.58 * rx, ey + 0.3 * ry, 0.15 * rx, 0.1 * ry, fill: Ink.blush, opacity: look.style == .baby ? 0.34 : 0.2)
        if squint {
            s.path("M \(x - 0.12 * rx) \(y) Q \(x) \(y + 0.08 * ry) \(x + 0.12 * rx) \(y)", stroke: ink, lw: max(1, rx * 0.06), cap: .round)
        } else {
            s.ellipse(x, y, 0.085 * rx, 0.1 * ry * (1 - 0.45 * sag), fill: ink)
            if sag < 0.3 { s.circle(x + 0.03 * rx, y - 0.035 * ry, 0.028 * rx, fill: .white, opacity: 0.8) }
            if sag > 0.1 { s.path("M \(x - 0.16 * rx) \(y - 0.08 * ry) Q \(x) \(y - 0.03 * ry) \(x + 0.16 * rx) \(y - 0.06 * ry)", stroke: skin, lw: ry * 0.09 * sag) }
        }
        // soft arched brows; worried ones lift at the inner end
        let inner = worried ? -0.36 : -0.26, outer = worried ? -0.22 : -0.26, bx0 = x - side * 0.1 * rx, bx1 = x + side * 0.13 * rx
        s.path("M \(bx0) \(ey + (inner + sag * 0.06) * ry) Q \((bx0 + bx1) / 2) \(ey + (min(inner, outer) - 0.06 + sag * 0.08) * ry) \(bx1) \(ey + (outer + sag * 0.1) * ry)",
               stroke: look.brow, lw: max(1, rx * 0.075), opacity: 0.9, cap: .round)
    }
    if look.glasses {
        for side in [-1.0, 1.0] { s.circle(c.x + side * 0.36 * rx, ey, 0.25 * rx, stroke: hex("#5A5560"), lw: max(0.9, rx * 0.05)) }
        s.line(c.x - 0.11 * rx, ey - 0.02 * ry, c.x + 0.11 * rx, ey - 0.02 * ry, stroke: hex("#5A5560"), lw: max(0.9, rx * 0.05))
    }
    // nose: a small soft hook
    s.path("M \(c.x + 0.02 * rx) \(ey + 0.16 * ry) Q \(c.x + 0.1 * rx) \(ey + 0.3 * ry) \(c.x - 0.04 * rx) \(ey + 0.31 * ry)",
           stroke: dim(skin, 0.78), lw: max(0.9, rx * 0.06), cap: .round)
    let my = c.y + 0.58 * ry - sh * 0.3, mw = 0.24 * rx, ly = my + droop * ry * 0.2, lw = max(1.1, rx * 0.07)
    switch expr {
    case .smile:
        s.path("M \(c.x - mw) \(ly - 0.03 * ry) Q \(c.x) \(my + 0.2 * ry) \(c.x + mw) \(my - 0.03 * ry) Z", fill: Ink.mouth)
        s.path("M \(c.x - mw * 0.7) \(ly) Q \(c.x) \(my + 0.05 * ry) \(c.x + mw * 0.7) \(my) Z", fill: .white, opacity: 0.9)
    case .calm, .closed:
        if bow < 0.4 { s.path("M \(c.x - mw * 0.8) \(ly) Q \(c.x) \(my + 0.08 * ry) \(c.x + mw * 0.8) \(my)", stroke: Ink.lip, lw: lw, cap: .round) }
    case .worried:
        s.path("M \(c.x - mw * 0.8) \(ly + 0.03 * ry) Q \(c.x) \(my - 0.06 * ry) \(c.x + mw * 0.8) \(my + 0.03 * ry)", stroke: Ink.lip, lw: lw, cap: .round)
    case .pain:
        s.path("M \(c.x - mw) \(ly + 0.05 * ry) Q \(c.x) \(my - 0.1 * ry) \(c.x + mw) \(my + 0.05 * ry) Q \(c.x) \(my + 0.06 * ry) \(c.x - mw) \(ly + 0.05 * ry) Z",
               fill: .white, stroke: Ink.lip, lw: lw * 0.9)
    case .distress, .open, .sneeze:
        s.ellipse(c.x, my + 0.02 * ry, mw * (expr == .sneeze ? 0.7 : 0.55), 0.12 * ry, fill: Ink.mouth)
    }
}

/// Face-on head of radius `r`; `bow` tips it toward us so we see more hair and the face drops.
func drawFrontHead(_ s: inout Sketch, at c: CGPoint, r: Double, look: Look, face: Face, bow: Double = 0, backHair: Bool = true) {
    let rx = r * 0.86
    if backHair && look.style != .long { faceOnHairBack(&s, c: c, rx: rx, ry: r, look: look) }
    let e: Expr = switch face { case .calm: .calm; case .closed: .closed; case .distress: .distress; case .open: .open }
    faceOnHead(&s, c: c, rx: rx, ry: r, look: look, expr: e, bow: bow)
}

// MARK: - Hands, limbs, shoes

/// Mitten-style hand, palm centre at `c`, fingers along `dir`; `thumb` picks the side.
func drawHand(_ s: inout Sketch, at c: CGPoint, dir: CGPoint, len L0: Double, shape: SideFigure.Hand, look: Look, thumb: Double = -1) {
    if look.art != nil { PeopleArt.hand(&s, at: c, dir: dir, len: L0, shape: shape, look: look, thumb: thumb); return }
    var g = s
    // drawn a little smaller than its reach length, wrist end kept in place
    let L = L0 * 0.86, back = L0 * 0.45 - L * 0.45
    g.ctx.concatenate(CGAffineTransform(a: dir.x, b: dir.y, c: -dir.y, d: dir.x, tx: c.x - dir.x * back, ty: c.y - dir.y * back))
    var skin = look.skin, line = dim(look.skin, 0.84)
    if let gl = look.gloves { (skin, line) = (gl, darker(gl)) }
    let W = L * 0.46, t = thumb, lw = (L * 0.045).clamped(0.4, 0.9)
    func P(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * L, y: y * W) }
    func blob(_ pts: [(Double, Double)]) -> Path { smoothPath(pts.map { P($0.0, $0.1) }) }
    func put(_ p: Path) {
        g.ctx.stroke(p, with: .color(line), lineWidth: lw * 2)
        g.ctx.fill(p, with: .color(skin))
    }
    func crease(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) {
        g.line(x0 * L, y0 * W, x1 * L, y1 * W, stroke: line, lw: lw, cap: .round, opacity: 0.75)
    }
    func finger(_ y: Double, _ len: Double, _ r: Double = 0.15) -> Path { capsulePath(P(-0.05, y), r * W, P(len, y), r * W * 0.92) }
    let fist = blob([(-0.5, -0.4), (-0.12, -0.52), (0.14, -0.46), (0.24, -0.18), (0.24, 0.18), (0.14, 0.46), (-0.12, 0.52), (-0.5, 0.4)])
    switch shape {
    case .open:
        put(capsulePath(P(-0.3, t * 0.3), 0.19 * W, P(0.0, t * 0.78), 0.15 * W))
        put(blob([(-0.56, -0.36), (-0.24, -0.5), (0.12, -0.48), (0.4, -0.38), (0.52, -0.12), (0.52, 0.12), (0.4, 0.38), (0.12, 0.48), (-0.24, 0.5), (-0.56, 0.36)]))
        crease(0.32, -0.15, 0.48, -0.16)
        crease(0.32, 0.15, 0.48, 0.16)
    case .laced:
        // fingers curled down over the other hand: short, knuckles showing
        put(blob([(-0.56, -0.36), (-0.2, -0.5), (0.14, -0.48), (0.3, -0.3), (0.34, 0), (0.3, 0.3), (0.14, 0.48), (-0.2, 0.5), (-0.56, 0.36)]))
        for y in [-0.2, 0.0, 0.2] { crease(0.16, y, 0.3, y) }
        put(capsulePath(P(-0.3, t * 0.36), 0.16 * W, P(-0.02, t * 0.62), 0.13 * W))
    case .fist:
        put(fist)
        crease(0.08, -0.16, 0.2, -0.16)
        crease(0.08, 0.08, 0.2, 0.08)
        put(capsulePath(P(-0.3, t * 0.46), 0.16 * W, P(0.08, t * 0.2), 0.13 * W))
    case .twoFingers:
        put(fist)
        put(finger(t * 0.3, 0.5))
        put(finger(t * 0.06, 0.56))
        put(capsulePath(P(-0.28, t * 0.4), 0.15 * W, P(-0.02, t * 0.62), 0.12 * W))
    case .encircle:
        // hand wrapped round a small chest: fingers curl away round the side, thumb tip on the breastbone by the wrist
        put(blob([(-0.52, -0.38), (-0.2, -0.5), (0.1, -0.48), (0.34, -0.36), (0.44, 0), (0.34, 0.36), (0.1, 0.48), (-0.2, 0.5), (-0.52, 0.38)]))
        crease(0.24, -0.15, 0.4, -0.16)
        crease(0.24, 0.15, 0.4, 0.16)
        put(capsulePath(P(-0.34, t * 0.1), 0.2 * W, P(-0.56, -t * 0.02), 0.17 * W))
    case .thumb:
        // thumb pointing forward and pressing, fingers wrapped round out of sight
        put(fist)
        for y in [-0.2, 0.05] { crease(0.06, y, 0.18, y) }
        put(capsulePath(P(-0.2, t * 0.2), 0.2 * W, P(0.42, t * 0.12), 0.17 * W))
    }
}

/// Organic limb segment: round ends of radius `ra`/`rb` joined by gently bulging sides.
/// `bulge l` bows out the side left of a→b (the back of a leg pointing down, facing +x), `r` the other side; `peak` = where along.
func segmentPath(_ a: CGPoint, _ ra: Double, _ b: CGPoint, _ rb: Double, bulge l: Double = 0, _ r: Double = 0, peak: Double = 0.45) -> Path {
    let dx = b.x - a.x, dy = b.y - a.y, L = max(1e-6, (dx * dx + dy * dy).squareRoot())
    let d = CGPoint(x: dx / L, y: dy / L), n = CGPoint(x: -d.y, y: d.x), k = 0.5523
    func P(_ o: CGPoint, _ along: Double, _ side: Double) -> CGPoint { CGPoint(x: o.x + d.x * along + n.x * side, y: o.y + d.y * along + n.y * side) }
    let t1 = peak * 0.66, t2 = peak + (1 - peak) * 0.34
    func ctl(_ sgn: Double, _ bulge: Double) -> (CGPoint, CGPoint) {
        (P(a, L * t1, sgn * (ra + (rb - ra) * t1 + bulge * 1.33)), P(a, L * t2, sgn * (ra + (rb - ra) * t2 + bulge * 1.33)))
    }
    var p = Path()
    p.move(to: P(a, 0, ra))
    let (l1, l2) = ctl(1, l), (r1, r2) = ctl(-1, r)
    p.addCurve(to: P(b, 0, rb), control1: l1, control2: l2)
    p.addCurve(to: P(b, rb, 0), control1: P(b, rb * k, rb), control2: P(b, rb, rb * k))
    p.addCurve(to: P(b, 0, -rb), control1: P(b, rb, -rb * k), control2: P(b, rb * k, -rb))
    p.addCurve(to: P(a, 0, -ra), control1: r2, control2: r1)
    p.addCurve(to: P(a, -ra, 0), control1: P(a, -ra * k, -ra), control2: P(a, -ra, -ra * k))
    p.addCurve(to: P(a, 0, ra), control1: P(a, -ra, ra * k), control2: P(a, -ra * k, ra))
    p.closeSubpath()
    return p
}

/// One smooth outline down a jointed limb: radius `rs` at each joint, `bulge` (left, right) at each segment's middle.
/// Left = left of the travel direction (the back of a leg pointing down, facing +x).
func smoothLimb(_ p: [CGPoint], _ rs: [Double], bulge: [(Double, Double)] = []) -> Path {
    let n = p.count
    guard n > 1 else { return Path() }
    func tangent(_ i: Int) -> CGPoint { unit(CGPoint(x: p[min(n - 1, i + 1)].x - p[max(0, i - 1)].x, y: p[min(n - 1, i + 1)].y - p[max(0, i - 1)].y)) }
    func off(_ q: CGPoint, _ t: CGPoint, _ r: Double) -> CGPoint { CGPoint(x: q.x - t.y * r, y: q.y + t.x * r) }
    var left: [CGPoint] = [], right: [CGPoint] = []
    for i in 0..<n {
        let t = tangent(i)
        left.append(off(p[i], t, rs[i]))
        right.append(off(p[i], t, -rs[i]))
        if i < n - 1 {
            let m = lerp(p[i], p[i + 1], 0.5), ts = unit(CGPoint(x: p[i + 1].x - p[i].x, y: p[i + 1].y - p[i].y)), rm = (rs[i] + rs[i + 1]) / 2
            let b = i < bulge.count ? bulge[i] : (0, 0)
            left.append(off(m, ts, rm + b.0))
            right.append(off(m, ts, -(rm + b.1)))
        }
    }
    let t0 = tangent(0), t1 = tangent(n - 1)
    let tip = CGPoint(x: p[n - 1].x + t1.x * rs[n - 1], y: p[n - 1].y + t1.y * rs[n - 1])
    let tail = CGPoint(x: p[0].x - t0.x * rs[0], y: p[0].y - t0.y * rs[0])
    return smoothPath(left + [tip] + right.reversed() + [tail])
}

/// Leg from hip via knee to ankle: thigh, calf curve, slim ankle; trousers (or onesie) to the ankle.
func organicLeg(_ g: inout Sketch, hip: CGPoint, knee k: CGPoint, ankle an: CGPoint, lw: Double, look: Look) {
    if look.art != nil { PeopleArt.leg(&g, hip: hip, knee: k, ankle: an, lw: lw, look: look); return }
    let shin = unit(CGPoint(x: an.x - k.x, y: an.y - k.y))
    // hem stops above the ankle, so its round end can't poke out under the shoe
    let hem = look.bareFeet ? an : CGPoint(x: an.x - shin.x * lw * 0.26, y: an.y - shin.y * lw * 0.26)
    let p = smoothLimb([hip, k, hem], [lw * 0.6, lw * 0.4, look.bareFeet ? lw * 0.27 : lw * 0.33], bulge: [(lw * 0.02, lw * 0.06), (lw * 0.1, 0)])
    g.shape(p, fill: look.bottom)
}

/// Sleeve (long or short) and bare skin from shoulder `s` via elbow `e` to wrist `w`, tapered, with a soft tonal edge.
func dressedArm(_ g: inout Sketch, _ s: CGPoint, _ e: CGPoint, _ w: CGPoint, aw: Double, look: Look) {
    if look.art != nil { PeopleArt.arm(&g, s, e, w, aw: aw, look: look); return }
    let skinEdge = dim(look.skin, 0.86), clothEdge = dim(look.top, 0.82)
    func put(_ p: Path, _ fill: Color, _ edge: Color) {
        g.ctx.stroke(p, with: .color(edge), lineWidth: 1.1)
        g.ctx.fill(p, with: .color(fill))
    }
    if look.longSleeves {
        let cuff = lerp(e, w, 0.8)
        put(smoothLimb([lerp(e, w, 0.3), w], [aw * 0.33, aw * 0.23]), look.skin, skinEdge)
        put(smoothLimb([s, e, cuff], [aw * 0.5, aw * 0.4, aw * 0.36], bulge: [(aw * 0.04, aw * 0.04), (aw * 0.02, aw * 0.02)]), look.top, clothEdge)
    } else {
        put(smoothLimb([s, e, w], [aw * 0.42, aw * 0.33, aw * 0.23], bulge: [(aw * 0.04, aw * 0.04), (aw * 0.05, aw * 0.05)]), look.skin, skinEdge)
        shortSleeve(&g, s, e, aw: aw, look: look)
    }
}

/// short sleeve: round over the shoulder, slightly flared, cut straight at the hem
func shortSleeve(_ g: inout Sketch, _ s: CGPoint, _ e: CGPoint, aw: Double, look: Look) {
    let hem = lerp(s, e, 0.48), d = unit(CGPoint(x: e.x - s.x, y: e.y - s.y)), n = CGPoint(x: -d.y, y: d.x)
    let r0 = aw * 0.54, r1 = aw * 0.52, k = 0.5523
    func P(_ o: CGPoint, _ along: Double, _ side: Double) -> CGPoint { CGPoint(x: o.x + d.x * along + n.x * side, y: o.y + d.y * along + n.y * side) }
    var p = Path()
    p.move(to: P(hem, 0, r1))
    p.addLine(to: P(hem, 0, -r1))
    p.addLine(to: P(s, 0, -r0))
    p.addCurve(to: P(s, -r0, 0), control1: P(s, -r0 * k, -r0), control2: P(s, -r0, -r0 * k))
    p.addCurve(to: P(s, 0, r0), control1: P(s, -r0, r0 * k), control2: P(s, -r0 * k, r0))
    p.closeSubpath()
    g.ctx.stroke(p, with: .color(dim(look.top, 0.8)), style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))
    g.ctx.fill(p, with: .color(look.top))
}

/// Side-view shoe (or bare foot) from the ankle along `dir`; `shin` points down the lower leg.
func drawShoe(_ g: inout Sketch, ankle a: CGPoint, dir fd: CGPoint, shin: CGPoint, len F: Double, w: Double, look: Look) {
    var n = CGPoint(x: -fd.y, y: fd.x)
    if n.x * shin.x + n.y * shin.y < 0 { n = CGPoint(x: -n.x, y: -n.y) }
    if look.art != nil { PeopleArt.shoe(&g, ankle: a, dir: fd, n: n, len: F, w: w, look: look); return }
    func P(_ along: Double, _ down: Double) -> CGPoint { CGPoint(x: a.x + fd.x * along + n.x * down, y: a.y + fd.y * along + n.y * down) }
    if look.bareFeet {
        g.shape(smoothPath([P(-w * 0.3, -w * 0.12), P(F * 0.4, -w * 0.12), P(F * 0.88, w * 0.02), P(F * 0.84, w * 0.3), P(F * 0.2, w * 0.34),
                            P(-w * 0.32, w * 0.26)]), fill: look.skin)
        return
    }
    let shoe = smoothPath([P(-w * 0.36, -w * 0.2), P(F * 0.2, -w * 0.3), P(F * 0.62, -w * 0.1), P(F * 0.98, w * 0.1), P(F * 0.96, w * 0.34),
                           P(F * 0.3, w * 0.38), P(-w * 0.38, w * 0.34)])
    g.shape(shoe, fill: look.shoes)
    // light sole: one flat tone
    var sole = g
    sole.ctx.clip(to: shoe)
    let s0 = P(-w * 0.5, w * 0.37), s1 = P(F * 1.1, w * 0.37)
    sole.line(s0.x, s0.y, s1.x, s1.y, stroke: hex("#E4E1EA"), lw: max(1.2, w * 0.2))
}

// MARK: - Helpers

/// point in a profile head's frame (units of r, x toward the face, y down) → scene
func headSpot(_ c: CGPoint, up: CGPoint, r: Double, _ x: Double, _ y: Double, side: Double = 1) -> CGPoint {
    let f = CGPoint(x: -up.y * side, y: up.x * side)
    return CGPoint(x: c.x + (f.x * x - up.x * y) * r, y: c.y + (f.y * x - up.y * y) * r)
}

extension Sketch {
    /// organic limb whose width changes joint to joint (`ws` = diameters per point), with a faint tonal edge
    mutating func taper(_ pts: [CGPoint], _ ws: [Double], fill: Color, line: Color?, lw: Double = 0.5) {
        guard pts.count > 1 else { return }
        let big = ws.max() ?? 0
        var all = Path()
        for i in 1..<pts.count { all.addPath(segmentPath(pts[i - 1], ws[i - 1] / 2, pts[i], ws[i] / 2, bulge: big * 0.04, big * 0.04)) }
        if line != nil { ctx.stroke(all, with: .color(dim(fill, 0.84)), lineWidth: 2 * lw) }
        ctx.fill(all, with: .color(fill))
    }

    /// round-capped polyline with an outline, for limbs
    mutating func limb(_ pts: [CGPoint], w: Double, fill: Color, line: Color?) {
        guard pts.count > 1 else { return }
        let p = openPath(pts)
        if let line { ctx.stroke(p, with: .color(line), style: StrokeStyle(lineWidth: w + 1.4, lineCap: .round, lineJoin: .round)) }
        ctx.stroke(p, with: .color(fill), style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
    }
}

/// convex hull of two circles: a limb segment that tapers from `ra` to `rb`
func capsulePath(_ a: CGPoint, _ ra: Double, _ b: CGPoint, _ rb: Double) -> Path {
    let dx = b.x - a.x, dy = b.y - a.y, L = max(1e-6, (dx * dx + dy * dy).squareRoot())
    let base = atan2(dy, dx), al = acos(((ra - rb) / L).clamped(-1, 1))
    var p = Path()
    let n = 10
    for i in 0...n {
        let t = base + al + (2 * .pi - 2 * al) * Double(i) / Double(n)
        let q = CGPoint(x: a.x + ra * cos(t), y: a.y + ra * sin(t))
        if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
    }
    for i in 0...n {
        let t = base - al + 2 * al * Double(i) / Double(n)
        p.addLine(to: CGPoint(x: b.x + rb * cos(t), y: b.y + rb * sin(t)))
    }
    p.closeSubpath()
    return p
}

func openPath(_ pts: [CGPoint]) -> Path {
    var p = Path()
    p.addLines(pts)
    return p
}

/// open Catmull-Rom curve through the points
func curvePath(_ p: [CGPoint]) -> Path {
    var path = Path()
    let n = p.count
    guard n > 2 else { return openPath(p) }
    path.move(to: p[0])
    for i in 0..<(n - 1) {
        let p0 = p[max(0, i - 1)], p1 = p[i], p2 = p[i + 1], p3 = p[min(n - 1, i + 2)]
        path.addCurve(to: p2, control1: CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6),
                      control2: CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6))
    }
    return path
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
    return Color(red: Double(r.red) * 0.8, green: Double(r.green) * 0.8, blue: Double(r.blue) * 0.8)
}

extension Sketch {
    /// flat fill with a gentle two-tone gradient (lit at `from`) and a soft edge
    mutating func flat(_ p: Path, _ c: Color, from a: CGPoint, to b: CGPoint, stroke: Color? = nil, lw: Double = 0.9) {
        ctx.fill(p, with: .linearGradient(Gradient(colors: [dim(c, 1.03), c, dim(c, 0.93)]), startPoint: a, endPoint: b))
        if let stroke { ctx.stroke(p, with: .color(stroke), style: StrokeStyle(lineWidth: lw, lineJoin: .round)) }
    }
}
