import SwiftUI

extension Illustrations {
    /// humeral-head centre along the reduction path: in the socket (u = 0) … under the coracoid (u = 1),
    /// dipping down and out past the socket rim on the way (traction)
    static func humeralHead(_ u: Double) -> CGPoint {
        let a = (1 - u) * (1 - u), b = 2 * u * (1 - u), c = u * u
        return CGPoint(x: a * 114 + b * 140 + c * 172, y: a * 142 + b * 222 + c * 168)
    }

    static func shoulder(for p: Profile) -> Scenario { shoulder.rebased(["female": p.female ? 1 : 0]) }

    static let shoulder = Scenario(
        id: "shoulder-dislocation", group: .bones, title: Bilingual("Shoulder dislocation", "肩关节脱位与复位"),
        warning: Bilingual("This shows what a clinician does — don’t try it on someone yourself.", "此演示为医生操作——请勿自行复位。"),
        params: ["disloc": 0, "showPath": 0, "sling": 0, "scene": 0],
        steps: [
            .watch("The shoulder is a ball (top of the arm bone) on a small, shallow socket — like a golf ball on a tee. It moves further than any joint, and pops out most easily.",
                   "肩关节是肱骨头（球）搁在又小又浅的关节盂（窝）上——像高尔夫球放在球托上。活动范围最大，也最容易脱出。",
                   set: ["disloc": 0, "showPath": 0, "sling": 0, "scene": 0]),
            .watch("A fall on an outstretched hand, or a hard twist with the arm up and out, levers the ball forward and down, under the coracoid. 95% go this way.",
                   "跌倒时手撑地，或手臂外展上举时被猛力扭转，肱骨头被撬向前下方，滑到喙突下。95% 的脱位是这种。",
                   set: ["disloc": 1, "scene": 1]),
            .watch("Signs: the shoulder looks squared off, with a hollow under the bony tip; the arm is held slightly out and can’t move. Support it as it is, ice it, go to the ER. Don’t pull it back.",
                   "表现：肩部变“方”，肩峰下凹陷；手臂略外展，不能活动。保持现有姿势托住，冷敷，尽快就医。不要强行拉回。",
                   set: ["scene": 2]),
            .tryIt("How a clinician reduces it, after an X-ray and pain relief: slow traction and turning the forearm out. Drag the ball back along the path into the socket.",
                   "医生如何复位（先拍 X 光、止痛）：缓慢牵引并外旋前臂。沿路径拖动肱骨头，使其回到关节盂内。", set: ["showPath": 1, "scene": 3],
                   TryStep(mode: .drag, success: { $0[v: "disloc"] < 0.08 },
                           ok: Bilingual("Back in the socket — reduced. A second X-ray checks it.", "回到关节盂——复位成功。复查 X 光确认。"), demo: ["disloc": 0])),
            .watch("A sling rests it for 1–3 weeks, then physio. Under 30 it often comes out again, because the torn socket rim (labrum) heals loose — keep up the exercises.",
                   "用吊带休息 1–3 周，之后康复训练。30 岁以下常复发，因为撕裂的关节盂唇愈合后较松——坚持康复锻炼。",
                   set: ["disloc": 0, "showPath": 0, "sling": 1, "scene": 4]),
        ],
        draw: { s, p, t in drawShoulder(&s, p, t) },
        onDrag: { point, _ in
            let best = (0...80).map { Double($0) / 80 }.min { a, b in
                let pa = humeralHead(a), pb = humeralHead(b)
                return hypot(pa.x - point.x, pa.y - point.y) < hypot(pb.x - point.x, pb.y - point.y)
            } ?? 0
            return ["disloc": best]
        },
        sources: ["Anterior (subcoracoid) dislocation ≈ 95% of shoulder dislocations; reduction by traction–external rotation",
                  "Recurrence after first dislocation highest under 30 (Bankart lesion of the anterior-inferior labrum)"]
    )

    // Right shoulder seen from the front: arm on the picture's left, neck and chest to the right.
    @MainActor private static func drawShoulder(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let d = p[v: "disloc"], scene = Int(p[v: "scene"].rounded()), showPath = p[v: "showPath"]
        let out = Anat.ease((d - 0.08) / 0.5)
        let head = humeralHead(d), r = 25.0
        // arm hangs at the side when in; held a little out (abducted) when dislocated
        let elbow = CGPoint(x: 100 - 34 * out, y: 360 - 8 * out)
        let ax = CGPoint(x: elbow.x - head.x, y: elbow.y - head.y), len = hypot(ax.x, ax.y)
        let ang = atan2(-ax.x, ax.y) * 180 / .pi
        func local(_ x: Double, _ y: Double) -> CGPoint {
            let a = ang * .pi / 180
            return CGPoint(x: head.x + x * cos(a) - y * sin(a), y: head.y + x * sin(a) + y * cos(a))
        }

        // skin: rounded deltoid over the ball; squared off, with a step under the acromion, once the ball has gone
        func skinPath(_ o: Double) -> String {
            let top = CGPoint(x: Anat.mix(60, 86, o), y: Anat.mix(126, 118, o))
            return "C \(Anat.mix(72, 94, o)) \(Anat.mix(80, 82, o)) \(Anat.mix(56, 88, o)) \(Anat.mix(100, 98, o)) \(top.x) \(top.y) "
        }
        let l1 = local(-44, 60), l2 = local(-40, 220), m1 = local(36, 110), m2 = local(33, 220)
        let skin = "M 360 0 L 318 0 C 314 36, 300 52, 262 62 C 220 72, 150 64, 108 72 " + skinPath(out)
            + "C \(Anat.mix(60, 86, out)) \(Anat.mix(150, 140, out)) \(l1.x) \(l1.y - 10) \(l1.x) \(l1.y) L \(l2.x) \(l2.y) "
            + "L \(m2.x) \(m2.y) L \(m1.x) \(m1.y) C \(m1.x + 4) \(m1.y - 20) \(m1.x + 14) \(m1.y - 30) \(m1.x + 26) \(m1.y - 28) "
            + "C 214 230, 220 270, 222 300 L 360 300 Z"
        s.gradFill(skin, [Anat.skin, Anat.skin, Anat.skinShade], from: pt(240, 150), to: pt(50, 180), stroke: Anat.skinEdge, lw: 1.6)
        if out > 0.05 {
            // ghost of the normal round shoulder
            s.path("M 108 72 " + skinPath(0) + "C 60 150, 58 170, 60 190", stroke: Anat.skinEdge, lw: 1.2, opacity: 0.8 * out, dash: [3, 3])
            s.softGlow(pt(98, 128), 14, 22, hex("#C9A58A"), 0.35 * out)
        }
        // ribs in front of the shoulder blade, faint
        for k in 0..<5 {
            let y = 128 + Double(k) * 34
            s.path("M 360 \(y - 18) C 310 \(y - 22), 258 \(y - 12), 224 \(y + 8)", stroke: hex("#EEDFCE"), lw: 9, cap: .round)
        }

        // shoulder blade (front surface) with the socket on its outer corner
        s.boneFill("M 156 110 C 180 104, 214 100, 238 98 C 236 150, 226 206, 212 262 C 196 232, 172 200, 156 176 "
                   + "C 150 170, 148 162, 148 142 C 148 124, 150 114, 156 110 Z",
                   light: pt(160, 120), dark: pt(230, 240), lw: 1.1)
        s.path("M 172 120 C 190 150, 200 190, 206 238", stroke: Anat.boneShade, lw: 1)
        // glenoid seen edge-on: a shallow, cartilage-lined oval with the labrum around its rim
        
        s.ellipse(145, 142, 7, 28, fill: hex("#A9CBD8"))
        s.ellipse(145, 142, 4.5, 25, fill: Anat.cartilage, stroke: Anat.cartilageEdge, lw: 0.8)
        

        // clavicle, acromion, coracoid
        s.boneFill("M 150 84 C 188 76, 232 74, 272 88 C 296 96, 318 98, 340 104 C 344 110, 342 118, 336 118 "
                   + "C 312 114, 292 110, 268 102 C 230 90, 190 94, 152 98 C 146 96, 145 88, 150 84 Z",
                   light: pt(240, 80), dark: pt(240, 118))
        s.boneFill("M 150 86 C 132 82, 112 82, 98 88 C 90 92, 90 102, 100 104 C 116 104, 134 102, 152 100 C 160 98, 160 88, 150 86 Z",
                   light: pt(120, 84), dark: pt(120, 106))
        s.boneFill("M 176 114 C 174 102, 166 94, 154 96 C 144 98, 136 104, 138 112 C 140 117, 146 117, 148 112 C 151 107, 160 106, 166 116 Z",
                   light: pt(156, 96), dark: pt(160, 118))

        // traction path (drag step)
        if showPath > 0.02 {
            var guide = Path()
            for i in 0...30 {
                let q = humeralHead(Double(i) / 30)
                if i == 0 { guide.move(to: q) } else { guide.addLine(to: q) }
            }
            s.shape(guide, stroke: Anat.blue, lw: 1.8, opacity: showPath, dash: [4, 4])
        }
        if out > 0.05 || showPath > 0.02 {
            // where the ball belongs
            let home = humeralHead(0)
            s.shape(Path(ellipseIn: CGRect(x: home.x - r, y: home.y - r, width: 2 * r, height: 2 * r)),
                    stroke: showPath > 0.02 ? Anat.green : Anat.muted, lw: 1.4, opacity: max(out, showPath) * 0.9, dash: [4, 3])
        }

        // humerus: shaft, surgical neck, greater tubercle, then the cartilage-capped head
        s.group(translate: head, rotate: ang, about: .zero) { g in
            let L = len
            g.boneFill("M -12 -22 C -28 -20, -35 -4, -32 14 C -29 32, -17 46, -12 62 L -11 \(L) L 11 \(L) L 11 62 C 12 50, 14 40, 19 31 "
                       + "C 10 20, -2 -4, -12 -22 Z", light: pt(-30, 0), dark: pt(14, 0))
            g.path("M -5 20 C -7 34, -7 50, -5 64", stroke: Anat.boneShade, lw: 1.1)
            g.line(-2, 78, -2, L, stroke: Anat.boneShade, lw: 0.8)
        }
        let headPath = Path(ellipseIn: CGRect(x: head.x - r, y: head.y - r, width: 2 * r, height: 2 * r))
        s.boneFill(headPath, light: pt(head.x - 10, head.y - 14), dark: pt(head.x + 16, head.y + 18))
        // articular cartilage faces the socket (medially and up); anatomical neck where it ends
        s.group(translate: head, rotate: ang, about: .zero) { g in
            g.path("M -12 -21.9 A 25 25 0 0 1 17.7 17.7", stroke: Anat.cartilageEdge, lw: 4.5)
            g.path("M -12 -21.9 A 25 25 0 0 1 17.7 17.7", stroke: Anat.cartilage, lw: 3)
            g.path("M -12 -21.9 C -2 -8, 8 6, 17.7 17.7", stroke: Anat.boneEdge, lw: 0.8, opacity: 0.55)
        }
        if out > 0.05 { s.shape(headPath, stroke: Anat.red, lw: 2, opacity: out) }

        // labels
        s.leader("clavicle", "锁骨", at: pt(230, 84), 222, 56, anchor: .middle)
        s.leader("acromion", "肩峰", at: pt(104, 94), 14, 60)
        s.leader("coracoid", "喙突", at: pt(160, 102), 196, 128)
        if out < 0.5 {
            s.leader("socket", "关节盂", at: pt(147, 150), 178, 168)
            s.leader("ball (head of humerus)", "肱骨头", at: pt(head.x - 12, head.y + 8), 8, 196)
            s.leader("cartilage", "关节软骨", at: pt(head.x + 18, head.y + 17), 178, 190)
        } else {
            s.leader("empty socket", "关节盂空了", at: pt(143, 136), 8, 104, color: Anat.red, bold: true)
            s.leader("ball under the coracoid", "肱骨头滑到喙突下", at: pt(head.x + 4, head.y + 24), 244, 222, anchor: .end, color: Anat.red, bold: true)
            if scene == 2 { s.leader("squared off", "方肩", at: pt(98, 150), 8, 150, color: Anat.red) }
        }
        s.leader("humerus", "肱骨", at: local(0, 150), 12, 282)

        let inPlace = d < 0.08
        s.stateChip(inPlace ? "In place" : "Dislocated", inPlace ? "关节在位" : "关节脱位", 8, 8, color: inPlace ? Anat.green : Anat.red)

        // real-life card
        let box = CGRect(x: 250, y: 124, width: 104, height: 168)
        drawShoulderCard(&s, scene: scene, box: box, d: d, t: t, look: p[v: "female"] > 0.5 ? .woman : .man)
    }

    private static func person(_ look: Look) -> FacingPerson {
        var f = FacingPerson(h: 150)
        f.wear(look)
        if look.female { (f.shirt, f.shirtLine) = (look.top, look.topLine) }
        return f
    }

    @MainActor private static func drawShoulderCard(_ s: inout Sketch, scene: Int, box: CGRect, d: Double, t: Double, look: Look) {
        let titles: [(String, String)] = [("Ball & socket", "球窝关节"), ("How it happens", "如何发生"),
                                          ("First aid", "现场处理"), ("Reduction", "复位"), ("Recovery", "恢复")]
        let ti = titles[min(scene, titles.count - 1)]
        s.inset(box.minX, box.minY, box.width, box.height, ti.0, ti.1)
        var c = s.clipped(box.minX, box.minY, box.width, box.height)
        let cx = box.midX, top = box.minY
        switch scene {
        case 0:
            // tee and ball, with the matching shoulder parts named underneath
            c.gradFill("M \(cx - 22) \(top + 92) L \(cx + 22) \(top + 92) C \(cx + 18) \(top + 98), \(cx + 6) \(top + 100), \(cx + 4) \(top + 104) "
                       + "L \(cx + 3) \(top + 140) L \(cx - 3) \(top + 140) L \(cx - 4) \(top + 104) C \(cx - 6) \(top + 100), \(cx - 18) \(top + 98), \(cx - 22) \(top + 92) Z",
                       [hex("#E6C79A"), hex("#C49A64")], from: pt(cx - 10, 0), to: pt(cx + 10, 0), stroke: hex("#A8804E"))
            let bc = CGPoint(x: cx, y: top + 66)
            c.gradFill(Path(ellipseIn: CGRect(x: bc.x - 27, y: bc.y - 27, width: 54, height: 54)), [.white, hex("#DADDE2")],
                       from: pt(bc.x - 14, bc.y - 16), to: pt(bc.x + 18, bc.y + 22), stroke: hex("#9AA0A8"), lw: 1.2)
            for (x, y) in [(-10.0, -12.0), (4, -16), (14, -4), (-2, 2), (-15, 4), (8, 12), (-6, 16), (17, 10), (-18, -6)] {
                c.circle(bc.x + x, bc.y + y, 2.1, fill: hex("#C9CDD3"))
            }
            c.leader("ball = humeral head", "球 = 肱骨头", at: pt(bc.x + 22, bc.y - 12), box.minX + 8, top + 30, color: Anat.text, size: 8, dot: false)
            c.cardNote("tee = shallow socket", "球托 = 浅的关节盂", cx, top + 154, width: 96, size: 8)
        case 1:
            let ground = box.maxY - 12
            c.line(box.minX + 6, ground, box.maxX - 6, ground, stroke: hex("#C9C2B6"), lw: 2)
            let (shoulderPt, hand) = c.fallOnHand(x: cx + 3, ground: ground, h: 80, look: look)
            // force travels up the straight arm into the shoulder
            c.arrow(CGPoint(x: hand.x + 12, y: hand.y - 6), CGPoint(x: shoulderPt.x + 12, y: shoulderPt.y + 4), color: Anat.red, lw: 1.8)
            c.softGlow(shoulderPt, 12, 12, Anat.red, 0.35 + 0.15 * sin(t * 4))
            c.cardNote("force runs up the arm", "冲击力沿手臂传到肩", cx, ground - 96, width: 96, size: 8, color: Anat.red)
        case 2:
            var f = person(look)
            f.face = .pain
            let o = CGPoint(x: cx + 6, y: top + 64)
            f.drawBody(&c, at: o)
            // injured arm held slightly out, forearm supported by the good hand
            let e = CGPoint(x: -0.17 * f.h, y: 0.19 * f.h), w = CGPoint(x: -0.02 * f.h, y: 0.25 * f.h)
            f.drawArm(&c, at: o, side: -1, elbow: e, hand: w)
            f.drawArm(&c, at: o, side: 1, elbow: CGPoint(x: 0.12 * f.h, y: 0.21 * f.h), hand: CGPoint(x: -0.1 * f.h, y: 0.235 * f.h))
            // cold pack on the shoulder
            let pack = CGPoint(x: o.x - 0.108 * f.h, y: o.y + 0.04 * f.h)
            c.group(rotate: -24, about: pack) { g in
                g.rect(pack.x - 10, pack.y - 8, 20, 16, r: 4, fill: hex("#CFE8F7"), stroke: Anat.blue, lw: 1.2)
                g.shape(Path(roundedRect: CGRect(x: pack.x - 7, y: pack.y - 5, width: 14, height: 10), cornerRadius: 3), stroke: .white, lw: 1, dash: [2, 2])
            }
            c.cardNote("support it as it is\nice · ER", "原样托住 · 冷敷 · 急诊", cx, box.maxY - 16, width: 96, size: 8, color: Anat.red, bold: true)
        case 3:
            // elbow at the side, forearm slowly swung outward as the ball goes home
            var f = person(look)
            f.face = .calm
            let o = CGPoint(x: cx + 14, y: top + 64)
            f.drawBody(&c, at: o)
            f.drawArm(&c, at: o, side: 1, elbow: CGPoint(x: 0.13 * f.h, y: 0.19 * f.h), hand: CGPoint(x: 0.14 * f.h, y: 0.33 * f.h))
            let turn = Anat.ease(1 - d)
            let e = CGPoint(x: -0.135 * f.h, y: 0.2 * f.h)
            let fore = 0.15 * f.h
            // forearm points at us (short) … out to the side (long)
            let w = CGPoint(x: e.x - fore * sin(turn * .pi / 2), y: e.y + 0.02 * f.h * (1 - turn) + 0.012 * f.h)
            f.drawArm(&c, at: o, side: -1, elbow: e, hand: w)
            let ec = CGPoint(x: o.x + e.x, y: o.y + e.y)
            c.bendArrow(CGPoint(x: ec.x - 6, y: ec.y + 16), via: CGPoint(x: ec.x - 26, y: ec.y + 20), CGPoint(x: ec.x - 30, y: ec.y + 4), color: Anat.blue, lw: 1.6)
            c.cardNote("elbow at the side, turn the forearm out slowly", "肘贴身，缓慢外旋前臂", cx, box.maxY - 18, width: 96, size: 8, color: Anat.blue, bold: true)
        default:
            var f = person(look)
            f.face = .calm
            let o = CGPoint(x: cx, y: top + 64)
            f.drawBody(&c, at: o)
            f.drawArm(&c, at: o, side: 1, elbow: CGPoint(x: 0.13 * f.h, y: 0.19 * f.h), hand: CGPoint(x: 0.14 * f.h, y: 0.33 * f.h))
            let e = CGPoint(x: -0.125 * f.h, y: 0.19 * f.h), w = CGPoint(x: 0.05 * f.h, y: 0.15 * f.h)
            f.drawArm(&c, at: o, side: -1, elbow: e, hand: w)
            f.drawSling(&c, at: o, elbow: e, hand: w)
            c.cardNote("sling 1–3 weeks, then physio", "吊带 1–3 周，再做康复", cx, box.maxY - 16, width: 96, size: 8, color: Anat.blue, bold: true)
        }
    }
}

private func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }
