import SwiftUI

/// Front-view person, waist up, for injury insets. Units are fractions of standing height `h`, origin at the neck base.
/// `right` / `left` are the person's arms (right shows on the picture's left): elbow and hand points.
struct InjuryFigure {
    var h: Double = 150
    var skin = hex("#F2C9A5")
    var line = hex("#C9A58A")
    var shirt = hex("#8FB3E0")
    var shirtLine = hex("#5F87B8")
    var trousers = hex("#5B6B8C")
    var right = (elbow: CGPoint(x: -0.13, y: 0.19), hand: CGPoint(x: -0.14, y: 0.34))
    var left = (elbow: CGPoint(x: 0.13, y: 0.19), hand: CGPoint(x: 0.14, y: 0.34))
    var sling = false
    var cast = false
    /// draw the left arm after the right, so it can hold the injured one
    var leftOnTop = true

    func draw(_ s: inout Sketch, at o: CGPoint) {
        func p(_ x: Double, _ y: Double) -> String { "\(o.x + x * h) \(o.y + y * h)" }
        func q(_ c: CGPoint) -> CGPoint { CGPoint(x: o.x + c.x * h, y: o.y + c.y * h) }
        for side in [-1.0, 1.0] { s.rect(o.x + (side < 0 ? -0.1 : 0.005) * h, o.y + 0.38 * h, 0.095 * h, 0.22 * h, r: 0.02 * h, fill: trousers) }
        s.path("M \(p(-0.03, 0)) L \(p(-0.1, 0.015)) C \(p(-0.125, 0.02)) \(p(-0.125, 0.06)) \(p(-0.115, 0.09)) L \(p(-0.09, 0.3)) L \(p(-0.1, 0.4)) "
               + "L \(p(0.1, 0.4)) L \(p(0.09, 0.3)) L \(p(0.115, 0.09)) C \(p(0.125, 0.06)) \(p(0.125, 0.02)) \(p(0.1, 0.015)) L \(p(0.03, 0)) Z",
               fill: shirt, stroke: shirtLine, lw: 1.2)
        s.rect(o.x - 0.022 * h, o.y - 0.04 * h, 0.044 * h, 0.05 * h, fill: skin, stroke: line, lw: 0.8)
        s.ellipse(o.x, o.y - 0.09 * h, 0.05 * h, 0.064 * h, fill: skin, stroke: line, lw: 1.2)
        s.path("M \(p(-0.052, -0.09)) C \(p(-0.056, -0.17)) \(p(0.056, -0.17)) \(p(0.052, -0.09)) C \(p(0.03, -0.13)) \(p(-0.03, -0.13)) \(p(-0.052, -0.09)) Z", fill: hex("#6B5344"))
        func arm(_ side: Double, _ a: (elbow: CGPoint, hand: CGPoint), injured: Bool) {
            let sh = q(CGPoint(x: side * 0.1, y: 0.04)), e = q(a.elbow), w = q(a.hand)
            s.line(sh.x, sh.y, e.x, e.y, stroke: shirt, lw: 0.05 * h, cap: .round)
            s.line(e.x, e.y, w.x, w.y, stroke: skin, lw: 0.038 * h, cap: .round)
            s.circle(w.x, w.y, 0.024 * h, fill: skin, stroke: line, lw: 0.8)
            guard injured else { return }
            if cast {
                let k = 0.15
                s.line(e.x + (w.x - e.x) * k, e.y + (w.y - e.y) * k, w.x - (w.x - e.x) * 0.05, w.y - (w.y - e.y) * 0.05, stroke: .white, lw: 0.052 * h, cap: .round)
                s.line(e.x + (w.x - e.x) * k, e.y + (w.y - e.y) * k, w.x - (w.x - e.x) * 0.05, w.y - (w.y - e.y) * 0.05, stroke: hex("#AAAAAA"), lw: 0.8, dash: [3, 3])
            }
            if sling {
                let blue = hex("#3F95D6")
                s.path("M \(e.x - 0.02 * h) \(e.y - 0.02 * h) L \(w.x + 0.035 * h) \(w.y - 0.03 * h) L \(w.x + 0.03 * h) \(w.y + 0.035 * h) L \(e.x) \(e.y + 0.05 * h) Z",
                       fill: blue, stroke: hex("#2D6FA3"), lw: 1, opacity: 0.85)
                let knot = q(CGPoint(x: 0.045, y: 0.005))
                s.line(w.x + 0.03 * h, w.y - 0.02 * h, knot.x, knot.y, stroke: blue, lw: 0.028 * h, cap: .round)
                s.line(e.x - 0.01 * h, e.y - 0.01 * h, o.x - 0.035 * h, o.y - 0.005 * h, stroke: blue, lw: 0.028 * h, cap: .round)
                s.path("M \(o.x - 0.035 * h) \(o.y - 0.005 * h) Q \(o.x) \(o.y + 0.02 * h) \(knot.x) \(knot.y)", stroke: blue, lw: 0.02 * h)
                s.circle(knot.x, knot.y, 0.018 * h, fill: hex("#2D6FA3"))
            }
        }
        if leftOnTop {
            arm(-1, right, injured: true)
            arm(1, left, injured: false)
        } else {
            arm(1, left, injured: false)
            arm(-1, right, injured: true)
        }
    }

    /// injured right forearm across the belly, the other hand holding it from below
    static let guarding = (right: (elbow: CGPoint(x: -0.125, y: 0.19), hand: CGPoint(x: 0.03, y: 0.2)),
                           left: (elbow: CGPoint(x: 0.12, y: 0.21), hand: CGPoint(x: -0.1, y: 0.215)))
}

extension Illustrations {
    /// reduction path: quadratic curve from in-place (u = 0) to dislocated (u = 1)
    static func humeralHead(_ u: Double) -> CGPoint {
        let a = (1 - u) * (1 - u), b = 2 * u * (1 - u), c = u * u
        return CGPoint(x: a * 140 + b * 132 + c * 180, y: a * 128 + b * 200 + c * 160)
    }

    static let shoulder = Scenario(
        id: "shoulder-dislocation", group: .bones, title: Bilingual("Shoulder dislocation", "肩关节脱位与复位"),
        warning: Bilingual("This shows what a clinician does — don’t try it on someone yourself.", "此演示为医生操作——请勿自行复位。"),
        params: ["disloc": 0, "showPath": 0, "sling": 0, "scene": 0],
        steps: [
            .watch("The shoulder is a ball (top of the arm bone) on a shallow socket — like a golf ball on a tee. Huge range of motion, but easy to pop out.",
                   "肩关节是肱骨头（球）坐在很浅的关节盂（窝）上——像高尔夫球放在球托上。活动范围大，但容易脱出。",
                   set: ["disloc": 0, "showPath": 0, "sling": 0, "scene": 0]),
            .watch("A fall on an outstretched hand, or a hard twist with the arm raised, levers the ball forward and down — under the coracoid. 95% go this way.",
                   "跌倒时手撑地，或手臂上举时被猛力扭转，肱骨头被撬向前下方，滑到喙突下。95% 的脱位是这种。",
                   set: ["disloc": 1, "scene": 1]),
            .watch("Signs: the shoulder looks squared off with a hollow under the bony tip; the arm is held a little out and can’t move. Support it as it is, ice it, go to A&E. Don’t pull it back.",
                   "表现：肩部变“方”，肩峰下凹陷；手臂略外展，不能活动。保持现有姿势托住，冷敷，尽快就医。不要强行拉回。",
                   set: ["scene": 2]),
            .tryIt("How a clinician reduces it, after an X-ray and pain relief: drag the ball back along the path into the socket.",
                   "医生如何复位（先拍 X 光、止痛）：沿路径拖动肱骨头，使其回到关节盂内。", set: ["showPath": 1, "scene": 3],
                   TryStep(mode: .drag, success: { $0[v: "disloc"] < 0.08 },
                           ok: Bilingual("Back in the socket — reduced. A second X-ray checks it.", "回到关节盂——复位成功。复查 X 光确认。"), demo: ["disloc": 0])),
            .watch("A sling rests it for 1–3 weeks, then physio. Under 30, it often dislocates again — keep up the strengthening exercises.",
                   "用吊带休息 1–3 周，之后康复训练。30 岁以下复发很常见——坚持力量训练。", set: ["disloc": 0, "showPath": 0, "sling": 1, "scene": 4]),
        ],
        draw: { s, p, _ in
            // right shoulder from the front: arm on the picture's left, chest on the right
            let d = p[v: "disloc"], scene = Int(p[v: "scene"].rounded())
            let head = humeralHead(d)
            let inPlace = d < 0.08
            let elbow = CGPoint(x: 104 + d * 18, y: 292 + d * 8)
            let bone = hex("#E9E2CF"), edge = hex("#B8A58A"), label = hex("#8F7E63"), red = hex("#D8434B")
            func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * d }
            // skin: round deltoid when in place, squared-off with a step under the acromion when out
            s.path("M 334 0 C 334 30, 326 52, 300 58 C 250 64, 170 58, 132 64 "
                   + "C \(mix(104, 124)) \(mix(70, 68)) \(mix(92, 120)) \(mix(100, 88)) \(mix(94, 120)) \(mix(136, 132)) "
                   + "C \(mix(92, 118)) \(mix(170, 172)) \(mix(70, 94)) 240 \(mix(56, 76)) 300 L \(mix(150, 170)) 300 "
                   + "C \(mix(160, 176)) 260 \(mix(168, 182)) 230 \(mix(176, 188)) 206 C 186 230, 190 270, 192 300 L 360 300 L 360 0 Z",
                   fill: hex("#F7E6DA"), stroke: hex("#DDBFA8"), lw: 2)
            for k in 0..<4 { let y = 132 + Double(k) * 36; s.path("M \(214 + Double(k) * 6) \(y) C 250 \(y - 10), 300 \(y - 8), 350 \(y + 10)", stroke: hex("#EADFD2"), lw: 7, cap: .round) }
            // scapula: glenoid at its outer corner, body behind the ribs
            s.path("M 160 108 L 176 100 C 200 96, 230 92, 252 88 C 250 140, 240 200, 226 250 C 205 215, 185 175, 164 150 Z", fill: hex("#EFE9DA"), stroke: edge, lw: 1.5)
            s.path("M 162 104 C 151 116, 151 140, 164 152", stroke: hex("#9C8A6A"), lw: 6, cap: .round)
            s.path("M 190 100 C 180 92, 164 100, 160 116 C 168 120, 174 110, 182 110 Z", fill: bone, stroke: edge, lw: 1.5)
            s.path("M 320 100 C 280 90, 232 70, 192 78 C 168 82, 150 78, 136 74", stroke: bone, lw: 13, cap: .round)
            s.path("M 320 100 C 280 90, 232 70, 192 78 C 168 82, 150 78, 136 74", stroke: edge, lw: 1)
            s.path("M 186 82 C 168 72, 146 70, 124 80 C 120 91, 136 95, 150 90", fill: bone, stroke: edge, lw: 1.5)
            if p[v: "showPath"] > 0.5 {
                var guide = Path()
                for i in 0...20 {
                    let pt = humeralHead(Double(i) / 20)
                    if i == 0 { guide.move(to: pt) } else { guide.addLine(to: pt) }
                }
                s.shape(guide, stroke: hex("#3F95D6"), lw: 2, dash: [5, 4])
                s.shape(Path(ellipseIn: CGRect(x: 117, y: 105, width: 46, height: 46)), stroke: hex("#2E9E5B"), lw: 2, dash: [4, 4])
            }
            // humerus with a real outline: head, greater tubercle, surgical neck, shaft
            let ang = atan2(-(elbow.x - head.x), elbow.y - head.y) * 180 / .pi
            let len = hypot(elbow.x - head.x, elbow.y - head.y)
            s.group(translate: head, rotate: ang, about: .zero) { g in
                g.path("M -30 4 C -32 30, -20 44, -17 62 L -15 \(len) L 5 \(len) L 6 62 C 8 44, 16 32, 20 14 Z", fill: bone, stroke: edge, lw: 1.5)
                g.line(-5, 70, -5, len, stroke: edge, lw: 0.6)
                g.circle(-20, 6, 12, fill: bone, stroke: edge, lw: 1.2)
                g.circle(0, 0, 23, fill: inPlace ? bone : hex("#F1D08A"), stroke: inPlace ? edge : red, lw: inPlace ? 1.5 : 2.5)
                g.path("M -14 18 C -4 26, 12 22, 20 12", stroke: edge, lw: 1)
            }
            if !inPlace && d > 0.9 {
                s.path("M 118 94 C 112 106, 112 122, 118 134", stroke: hex("#A08070"), lw: 3, opacity: 0.6, cap: .round)
                s.label("hollow", "凹陷", 88, 116, size: 9, color: red)
                s.label("under the coracoid", "喙突下", 196, 196, size: 9, color: red, anchor: .middle)
            }
            s.label("clavicle", "锁骨", 252, 72, size: 9, color: label)
            s.label("acromion", "肩峰", 86, 62, size: 9, color: label)
            s.label("coracoid", "喙突", 190, 116, size: 9, color: label)
            if inPlace || d < 0.9 { s.label("socket", "关节盂", 170, 138, size: 9, color: label) }
            s.label("humerus", "肱骨", elbow.x + 18, 272, size: 9, color: label)
            let status = inPlace ? hex("#2E9E5B") : red
            s.rect(220, 6, 132, 30, r: 8, fill: .white, stroke: status, lw: 2)
            s.text(inPlace ? s.t("In place", "复位") : s.t("Dislocated", "脱位"), 286, 26, size: 12, color: status, anchor: .middle, bold: true)

            // inset: the situation in real life
            let box = CGRect(x: 248, y: 142, width: 106, height: 152)
            s.rect(box.minX, box.minY, box.width, box.height, r: 10, fill: .white, stroke: hex("#DDDDDD"), lw: 1.5)
            let cx = box.midX
            switch scene {
            case 0:
                // golf ball on a tee vs the shoulder
                s.path("M \(cx - 16) 220 L \(cx + 16) 220 L \(cx + 4) 232 L \(cx + 3) 270 L \(cx - 3) 270 L \(cx - 4) 232 Z", fill: hex("#D9B98A"), stroke: hex("#A8875A"))
                s.circle(cx, 200, 22, fill: .white, stroke: hex("#999999"), lw: 1.5)
                for (x, y) in [(-8.0, -8.0), (4, -12), (10, 0), (-2, 4), (-12, 6), (6, 12)] { s.circle(cx + x, 200 + y, 2, fill: hex("#DDDDDD")) }
                s.label("golf ball on a tee", "球托上的高尔夫球", cx, 164, size: 9, anchor: .middle)
                s.label("= ball & socket", "＝ 肱骨头与关节盂", cx, 288, size: 9, color: label, anchor: .middle)
            case 1:
                // falling onto an outstretched hand
                let ground = 272.0
                s.line(box.minX + 6, ground, box.maxX - 6, ground, stroke: hex("#BBBBBB"), lw: 2)
                let fall = Person(h: 96, lean: 0, shoulder: 80, elbow: 0, hip: 10, knee: 20)
                let hl = fall.hand(), r = 58.0 * .pi / 180
                let hw = CGPoint(x: hl.x * cos(r) - hl.y * sin(r), y: hl.x * sin(r) + hl.y * cos(r))
                let origin = CGPoint(x: cx + 26 - hw.x, y: ground - 3 - hw.y)
                fall.draw(&s, at: origin, rotation: 58, farArm: false)
                s.path("M \(cx + 18) \(ground - 8) l -6 -6 M \(cx + 26) \(ground - 12) l 0 -8 M \(cx + 34) \(ground - 8) l 6 -6", stroke: red, lw: 1.5)
                s.label("fall on the hand", "手撑地跌倒", cx, 164, size: 9, color: red, anchor: .middle)
            case 2:
                var fig = InjuryFigure(h: 150)
                (fig.right, fig.left) = (InjuryFigure.guarding.right, InjuryFigure.guarding.left)
                fig.right.elbow = CGPoint(x: -0.15, y: 0.18)
                fig.draw(&s, at: CGPoint(x: cx, y: 200))
                s.rect(cx - 30, 196, 14, 12, r: 3, fill: hex("#BFE3F5"), stroke: hex("#3F95D6"))
                s.label("hold it, ice, go", "托住·冷敷·就医", cx, 164, size: 9, color: red, anchor: .middle)
            case 3:
                let fig = InjuryFigure(h: 150, right: (CGPoint(x: -0.17, y: 0.17), CGPoint(x: -0.27, y: 0.28)))
                fig.draw(&s, at: CGPoint(x: cx + 10, y: 200))
                s.path("M \(cx - 34) 246 l 0 18 m -5 -6 l 5 6 l 5 -6", stroke: hex("#3F95D6"), lw: 2)
                s.path("M \(cx - 22) 238 C \(cx - 8) 248, \(cx - 10) 262, \(cx - 26) 268", stroke: hex("#3F95D6"), lw: 2)
                s.label("gentle pull + turn out", "轻牵引＋外旋", cx, 164, size: 9, color: hex("#3F95D6"), anchor: .middle)
            default:
                let fig = InjuryFigure(h: 150, right: (CGPoint(x: -0.125, y: 0.19), CGPoint(x: 0.03, y: 0.16)), sling: true)
                fig.draw(&s, at: CGPoint(x: cx, y: 200))
                s.label("sling 1–3 weeks", "吊带 1–3 周", cx, 164, size: 9, color: hex("#3F95D6"), anchor: .middle)
            }
        },
        onDrag: { point, _ in
            let best = (0...60).map { Double($0) / 60 }.min { a, b in
                let pa = humeralHead(a), pb = humeralHead(b)
                return hypot(pa.x - point.x, pa.y - point.y) < hypot(pb.x - point.x, pb.y - point.y)
            } ?? 0
            return ["disloc": best]
        },
        sources: ["Anterior (subcoracoid) dislocation ≈ 95% of shoulder dislocations; reduction by traction–external rotation"]
    )
}
