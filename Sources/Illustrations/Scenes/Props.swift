import SwiftUI

extension Casualty {
    /// person picked by a topic scene's "kid" / "senior" / "pregnant" params
    init(_ p: Params, adult h: Double, adultLook: Look = .man) {
        let age: AgeGroup = p[v: "kid"] > 0.5 ? .child : p[v: "senior"] > 0.5 ? .senior : .adult
        let pregnant = p[v: "pregnant"] > 0.5
        self.init(Profile(age: age, female: pregnant || p[v: "female"] > 0.5, pregnant: pregnant), adult: h, adultLook: adultLook)
    }
}

extension SideFigure {
    init(_ c: Casualty, hip: CGPoint = .zero, facing: Double = 1, lean: Double = 0, face: Face = .calm) {
        self.init(h: c.h, build: c.build, look: c.look, hip: hip, facing: facing, lean: lean, face: face, bump: c.bump)
    }

    /// ankle and toe tip of a leg, in scene coords
    func foot(near isNear: Bool = true) -> (ankle: CGPoint, toe: CGPoint) {
        let l = isNear ? nearLeg : farLeg, a1 = l.hip * .pi / 180, a2 = (l.hip - l.knee) * .pi / 180, p = l.point * .pi / 180
        let T = build.thigh * h, S = build.shin * h, F = build.foot * h
        let an = CGPoint(x: sin(a1) * T + sin(a2) * S, y: cos(a1) * T + cos(a2) * S)
        return (scene(an), scene(CGPoint(x: an.x + cos(a2 - p) * F, y: an.y - sin(a2 - p) * F)))
    }

    func ankle(near isNear: Bool = true) -> CGPoint { foot(near: isNear).ankle }

    /// hip height that puts the lower foot on `floor` (upright body)
    func hipY(onFloor floor: Double) -> Double {
        var v = self
        v.hip = .zero
        let lw = build.legW * h
        let low = [true, false].map { v.foot(near: $0) }.map { max($0.ankle.y + lw * 0.3, $0.toe.y + lw * 0.2) }.max() ?? 0
        return floor - low
    }
}

/// Shared surfaces and neutrals for every scene.
enum Palette {
    static let wall = hex("#F6F4F1"), blob = hex("#ECE8F3"), floor = hex("#EAE5DE"), floorEdge = hex("#DDD6CC")
    static let shadow = Color(red: 0.2, green: 0.17, blue: 0.3).opacity(0.08)
    static let ink = hex("#2F2B36"), sub = hex("#8A8494"), line = hex("#E6E2EA")
}

/// Everyday objects, rooms and close-up insets shared by the first-aid scenes.
extension Sketch {
    /// Soft backdrop: pale wall, one big background blob, a plain rounded floor. `blob` = its centre x.
    mutating func room(floor: Double, blob: Double = 180, tint: Color = Palette.blob) {
        backdrop()
        ellipse(blob, floor - 40, 150, 120, fill: tint)
        floorBand(floor)
    }

    /// whole-scene pale wash
    mutating func backdrop(_ c: Color = Palette.wall) { rect(0, 0, 360, 300, fill: c) }

    /// plain floor from `y` down, soft top edge
    mutating func floorBand(_ y: Double) {
        rect(-20, y, 400, 320 - y, r: 18, fill: Palette.floor)
        rect(-20, y, 400, 3, r: 1.5, fill: Palette.floorEdge)
    }

    /// soft disc behind a standing figure, sitting on a short floor strip
    mutating func stage(_ cx: Double, floor: Double, r: Double = 90, width: Double? = nil) {
        ellipse(cx, floor - r, r, r, fill: Palette.blob)
        let w = width ?? r * 2.4
        rect(cx - w / 2, floor, w, 5, r: 2.5, fill: Palette.floor)
    }

    /// soft contact shadow on the floor
    mutating func groundShadow(_ x: Double, _ y: Double, _ w: Double) {
        ellipse(x, y, w / 2, max(2, w * 0.07), fill: Palette.shadow)
    }

    /// Text in the chosen language on a white pill, so it reads over a scene.
    mutating func tag(_ en: String, _ zh: String, _ x: Double, _ y: Double, size: Double = 10, color: Color = hex("#444444"),
                      anchor: Anchor = .middle, bold: Bool = false, width: Double = 170) {
        let txt = ctx.resolve(Text(t(en, zh)).font(.system(size: size, weight: bold ? .semibold : .medium)).foregroundStyle(color))
        let m = txt.measure(in: CGSize(width: width, height: 200))
        let x0 = anchor == .start ? x : anchor == .middle ? x - m.width / 2 : x - m.width
        let hh = m.height + 4
        rect(x0 - 5, y - hh / 2 + 1, m.width + 10, hh, r: hh / 2, fill: Palette.shadow)
        rect(x0 - 5, y - hh / 2, m.width + 10, hh, r: hh / 2, fill: .white, opacity: 0.95)
        ctx.draw(txt, in: CGRect(x: x0, y: y - m.height / 2, width: m.width + 1, height: m.height + 1))
    }

    /// Label on a pill with a thin leader line to `to` (dot at the end).
    mutating func callout(_ en: String, _ zh: String, _ x: Double, _ y: Double, to: CGPoint, size: Double = 9,
                          color: Color = hex("#444444"), anchor: Anchor = .middle, bold: Bool = true, width: Double = 170) {
        line(x, y, to.x, to.y, stroke: color, lw: 0.8, opacity: 0.7)
        circle(to.x, to.y, 2.2, fill: color, stroke: .white, lw: 1)
        tag(en, zh, x, y, size: size, color: color, anchor: anchor, bold: bold, width: width)
    }

    /// Speech bubble centred at (x, y) with its tail at `tip`.
    mutating func bubble(_ en: String, _ zh: String, _ x: Double, _ y: Double, tip: CGPoint, size: Double = 11,
                         color: Color = Palette.ink, border: Color = Palette.line) {
        let txt = ctx.resolve(Text(t(en, zh)).font(.system(size: size, weight: .semibold)).foregroundStyle(color))
        let m = txt.measure(in: CGSize(width: 150, height: 200))
        let w = m.width + 16, hh = m.height + 10
        var tail = Path()
        tail.addLines([CGPoint(x: x - 6, y: y), tip, CGPoint(x: x + 6, y: y)])
        tail.closeSubpath()
        rect(x - w / 2, y - hh / 2 + 2, w, hh, r: hh / 2, fill: Palette.shadow)
        shape(tail, fill: .white, stroke: border, lw: 0.8)
        rect(x - w / 2, y - hh / 2, w, hh, r: hh / 2, fill: .white, stroke: border, lw: 0.8)
        shape(tail, fill: .white)
        ctx.draw(txt, in: CGRect(x: x - m.width / 2, y: y - m.height / 2, width: m.width + 1, height: m.height + 1))
    }

    /// White close-up card with a small title.
    mutating func inset(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ en: String, _ zh: String) {
        softCard(x, y, w, h)
        label(en, zh, x + 9, y + 14, size: 9, color: Palette.sub, bold: true)
    }

    /// rounded white card with a soft, layered shadow
    mutating func softCard(_ x: Double, _ y: Double, _ w: Double, _ h: Double, r: Double = 12, fill: Color = .white) {
        rect(x, y + 3, w, h, r: r, fill: Palette.shadow)
        rect(x - 0.5, y + 1, w + 1, h + 0.5, r: r, fill: Palette.shadow)
        rect(x, y, w, h, r: r, fill: fill)
    }

    /// status panel: white card washed with its state colour, hairline edge
    mutating func tonal(_ x: Double, _ y: Double, _ w: Double, _ h: Double, r: Double = 12, color: Color) {
        rect(x, y + 2, w, h, r: r, fill: Palette.shadow)
        rect(x, y, w, h, r: r, fill: .white)
        rect(x, y, w, h, r: r, fill: color.opacity(0.1), stroke: color.opacity(0.4), lw: 1)
    }

    /// copy that only draws inside the rect (for inset contents)
    func clipped(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Sketch {
        var g = self
        g.ctx.clip(to: Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: 12))
        return g
    }

    /// Mobile phone on a call; `number` shown big on the screen.
    mutating func phone(_ x: Double, _ y: Double, number: String, speaker: Bool = true, t: Double = 0) {
        rect(x - 13, y - 21, 26, 46, r: 7, fill: Palette.shadow)
        rect(x - 13, y - 23, 26, 46, r: 7, fill: hex("#2C2F3D"))
        rect(x - 11, y - 20, 22, 40, r: 5, fill: hex("#EEF5F1"))
        text(number, x, y - 3, size: 10, color: hex("#1F2A24"), anchor: .middle, bold: true)
        circle(x, y + 11, 4.5, fill: hex("#D8434B"))
        line(x - 2.5, y + 11, x + 2.5, y + 11, stroke: .white, lw: 1.5, cap: .round)
        if speaker {
            for i in 0..<3 {
                let r = 6 + Double(i) * 5, a = 0.9 - (t * 1.5 + Double(i) * 0.3).wrap(1) * 0.6
                path("M \(x + 14 + r * 0.5) \(y - 20 - r * 0.8) A \(r) \(r) 0 0 1 \(x + 14 + r * 0.95) \(y - 20)", stroke: hex("#2E9E5B"), lw: 1.6,
                     opacity: a, cap: .round)
            }
        }
    }

    /// AED case: green box, handle, heart with a lightning bolt.
    mutating func aed(_ x: Double, _ y: Double, scale k: Double = 1, open: Bool = false) {
        rect(x - 10 * k, y - 25 * k, 20 * k, 8 * k, r: 4 * k, stroke: hex("#1F7A45"), lw: 3 * k)
        rect(x - 24 * k, y - 20 * k, 48 * k, 38 * k, r: 7 * k, fill: hex("#2E9E5B"), stroke: hex("#1F7A45"), lw: 1.2)
        heart(x, y - 5 * k, 8 * k, fill: .white)
        path("M \(x + 1 * k) \(y - 11 * k) L \(x - 3 * k) \(y - 4 * k) L \(x + 1 * k) \(y - 4 * k) L \(x - 1.5 * k) \(y + 2 * k)",
             stroke: hex("#2E9E5B"), lw: 1.6 * k, cap: .round)
        text("AED", x, y + 13 * k, size: 8 * k, color: .white, anchor: .middle, bold: true)
        if open { circle(x + 16 * k, y - 12 * k, 3 * k, fill: hex("#F2C14E")) }
    }

    mutating func heart(_ x: Double, _ y: Double, _ r: Double, fill: Color) {
        path("M \(x) \(y + r) C \(x - 1.6 * r) \(y - 0.1 * r) \(x - 0.7 * r) \(y - 1.1 * r) \(x) \(y - 0.35 * r) "
             + "C \(x + 0.7 * r) \(y - 1.1 * r) \(x + 1.6 * r) \(y - 0.1 * r) \(x) \(y + r) Z", fill: fill)
    }

    /// Sticky AED pad, w × h, with its cable back to `to`.
    mutating func pad(_ c: CGPoint, to: CGPoint, w: Double = 14, h: Double = 9) {
        path("M \(c.x) \(c.y) C \(c.x - 10) \(c.y + 30) \(to.x + 20) \(to.y - 20) \(to.x) \(to.y)", stroke: hex("#555A60"), lw: 1.4)
        rect(c.x - w / 2, c.y - h / 2, w, h, r: 2, fill: .white, stroke: hex("#8A9099"), lw: 1)
        heart(c.x, c.y, 2.2, fill: hex("#D8434B"))
    }

    /// Circular arrow showing a push direction.
    mutating func arrow(_ a: CGPoint, _ b: CGPoint, color: Color = hex("#D8434B"), lw: Double = 2.4) {
        line(a.x, a.y, b.x, b.y, stroke: color, lw: lw, cap: .round)
        let d = unit(CGPoint(x: b.x - a.x, y: b.y - a.y)), n = CGPoint(x: -d.y, y: d.x), k = 3 + lw
        path("M \(b.x + d.x * 2) \(b.y + d.y * 2) L \(b.x - d.x * k + n.x * k * 0.7) \(b.y - d.y * k + n.y * k * 0.7) "
             + "L \(b.x - d.x * k - n.x * k * 0.7) \(b.y - d.y * k - n.y * k * 0.7) Z", fill: color)
    }

    enum ChestMark { case twoHands, oneHand, thumbs, twoFingers, pads, padsFrontBack, fist }

    /// Front view of the chest in a card: ribs, breastbone, nipples, and where hands or pads go.
    mutating func chestMap(_ x: Double, _ y: Double, _ w: Double, _ h: Double, mark: ChestMark, baby: Bool = false, title: Bilingual) {
        inset(x, y, w, h, title.en, title.zh)
        // the trunk stops short of the caption row along the bottom edge
        let cx = x + w / 2, top = y + 32, sw = baby ? w * 0.26 : w * 0.3, len = h - 54
        let skin = hex("#F6D8BF"), edge = hex("#D1A98A"), bone = hex("#E4DAC3")
        circle(cx, top + (baby ? 2 : 0), baby ? 14 : 10, fill: skin, stroke: edge)
        let body = [CGPoint(x: -0.25, y: 0.12), CGPoint(x: -0.95, y: 0.2), CGPoint(x: -1.02, y: 0.5), CGPoint(x: -0.88, y: 1.0),
                    CGPoint(x: 0.88, y: 1.0), CGPoint(x: 1.02, y: 0.5), CGPoint(x: 0.95, y: 0.2), CGPoint(x: 0.25, y: 0.12)]
            .map { CGPoint(x: cx + $0.x * sw, y: top + 8 + $0.y * (len - 8)) }
        shape(smoothPath(body), fill: skin, stroke: edge, lw: 1.2)
        let st = top + 8 + 0.2 * (len - 8), sb = top + 8 + 0.66 * (len - 8)
        for i in 0..<5 {
            let yy = st + Double(i) * (sb - st) / 5 + 4
            for s in [-1.0, 1.0] {
                path("M \(cx + s * 4) \(yy) Q \(cx + s * sw * 0.7) \(yy - 4) \(cx + s * sw * 0.85) \(yy + 10)", stroke: bone, lw: 2.2, cap: .round)
            }
        }
        rect(cx - 3.5, st, 7, sb - st, r: 3, fill: bone, stroke: hex("#C8B994"), lw: 0.8)
        let ny = st + (sb - st) * 0.42
        for s in [-1.0, 1.0] { circle(cx + s * sw * 0.55, ny, 2, fill: hex("#C98C7A")) }
        line(cx - sw * 0.75, ny, cx + sw * 0.75, ny, stroke: hex("#B98C7A"), lw: 0.8, dash: [2, 2])
        let red = hex("#D8434B")
        switch mark {
        case .twoHands, .oneHand:
            let c = CGPoint(x: cx, y: st + (sb - st) * 0.7)
            ellipse(c.x, c.y, mark == .oneHand ? 7 : 9, 6, fill: red.opacity(0.35), stroke: red, lw: 1.4)
            tag("heel of hand", "掌根", cx, y + h - 7, size: 8, color: red)
        case .thumbs, .twoFingers:
            let c = CGPoint(x: cx, y: ny + 5)
            if mark == .thumbs {
                for s in [-1.0, 1.0] { ellipse(c.x + s * 2.5, c.y, 2.3, 4, fill: red.opacity(0.4), stroke: red) }
            } else {
                ellipse(c.x, c.y - 2, 2.2, 3.5, fill: red.opacity(0.4), stroke: red)
                ellipse(c.x, c.y + 5, 2.2, 3.5, fill: red.opacity(0.4), stroke: red)
            }
            tag("just below nipple line", "乳头连线下方", cx, y + h - 7, size: 8, color: red)
        case .pads:
            rect(cx - sw * 0.75, st - 2, 13, 9, r: 2, fill: .white, stroke: hex("#2E9E5B"), lw: 1.4)
            rect(cx + sw * 0.62, sb - 12, 13, 9, r: 2, fill: .white, stroke: hex("#2E9E5B"), lw: 1.4)
            label("R", "右", cx - sw * 0.7, y + h - 5, size: 8, color: hex("#8A8378"), anchor: .middle)
            label("L", "左", cx + sw * 0.7, y + h - 5, size: 8, color: hex("#8A8378"), anchor: .middle)
        case .padsFrontBack:
            rect(cx - 6.5, ny - 4, 13, 9, r: 2, fill: .white, stroke: hex("#2E9E5B"), lw: 1.4)
            label("+ one on the back", "+ 背部一片", cx, y + h - 6, size: 8, color: hex("#2E9E5B"), anchor: .middle)
        case .fist:
            let c = CGPoint(x: cx, y: top + 8 + 0.8 * (len - 8))
            circle(c.x, c.y + 10, 1.8, fill: hex("#C98C7A"))
            circle(c.x, c.y, 6, fill: red.opacity(0.35), stroke: red, lw: 1.4)
        }
    }

    /// Chest cross-section from the side: breastbone squeezes the heart against the spine.
    mutating func compressionSection(_ x: Double, _ y: Double, press: Double, depth: String, baby: Bool = false) {
        inset(x, y, 116, 100, "Inside the chest", "胸腔内部")
        let c = CGPoint(x: x + 58, y: y + 58), d = press * 9
        ellipse(c.x, c.y, 46, 30, fill: hex("#F7E3D6"), stroke: hex("#C9A58A"))
        ellipse(c.x - 25, c.y + 2, 14, 18 - d * 0.3, fill: hex("#F2C4CC"))
        ellipse(c.x + 25, c.y + 2, 14, 18 - d * 0.3, fill: hex("#F2C4CC"))
        ellipse(c.x, c.y + 4 + d * 0.3, 12, 11 - d * 0.45, fill: hex("#C8323C"))
        rect(c.x - 8, c.y - 31 + d, 16, 6, r: 2, fill: hex("#E9E2CF"), stroke: hex("#B8A58A"))
        circle(c.x, c.y + 26, 6, fill: hex("#E9E2CF"), stroke: hex("#B8A58A"))
        arrow(CGPoint(x: c.x, y: c.y - 44 + d), CGPoint(x: c.x, y: c.y - 34 + d), lw: 2)
        label("breastbone", "胸骨", c.x - 12, c.y - 20, size: 8, anchor: .end)
        label("heart", "心脏", c.x + 14, c.y + 8, size: 8, color: hex("#C8323C"))
        label("spine", "脊柱", c.x - 44, c.y + 30, size: 8)
        text(depth, x + 110, y + 94, size: 9, color: hex("#D8434B"), anchor: .end, bold: true)
    }
}
