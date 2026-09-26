import SwiftUI

extension Illustrations {
    static func recoveryPosition(for who: Profile) -> Scenario {
        if who.age == .infant { return babyRecovery }
        let lay = RecoveryLayout(who)
        var s = Scenario(
            id: "recovery-position", group: .firstAid, title: Bilingual("Recovery position", "复原卧位"),
            params: ["stage": 0, "arm": 0, "hand": 0, "knee": 0, "roll": 0, "tilt": 0],
            steps: [
                .watch("Unresponsive but breathing normally? Lying on the back, the tongue or vomit can block the airway. Tap the shoulders and shout.",
                       "无反应但呼吸正常？仰卧时舌根后坠或呕吐物可能堵住气道。先拍双肩、大声呼唤。",
                       set: ["stage": 0, "arm": 0, "hand": 0, "knee": 0, "roll": 0, "tilt": 0]),
                .watch("Tilt the head back and lift the chin. Look, listen and feel for normal breathing — up to 10 s.",
                       "仰头抬颏，看、听、感觉有无正常呼吸，不超过 10 秒。", set: ["stage": 1, "tilt": 1]),
                .watch("Kneel beside them, glasses off. Put the arm nearest you out at a right angle, elbow bent, palm up.",
                       "跪在其身旁，取下眼镜。把靠近你的手臂向外摆成直角，屈肘，掌心向上。", set: ["stage": 2, "arm": 1, "tilt": 0]),
                .watch("Bring the far arm across the chest. Hold the back of their hand against the cheek nearest you.",
                       "把远侧手臂拉过胸前，将其手背贴在靠近你一侧的脸颊上并按住。", set: ["stage": 3, "hand": 1]),
                .watch("With your other hand, pull the far knee up so the foot is flat on the floor.",
                       "另一只手把远侧膝盖拉起，使脚掌平踩地面。", set: ["stage": 4, "knee": 1]),
                .tryIt("Keep their hand on the cheek. Drag the far knee towards you to roll them onto their side.",
                       "试一试：按住脸颊上的手，把远侧膝盖向你拖过来，让其翻成侧卧。", set: ["stage": 5],
                       TryStep(mode: .drag, success: { $0[v: "roll"] >= 0.95 },
                               ok: Bilingual("On their side — the bent top knee stops them rolling onto their face.", "侧卧了——弯曲的上方膝盖防止其翻成俯卧。"),
                               demo: ["roll": 0.55])),
                .watch("Top leg bent at hip and knee. Tilt the head back to keep the airway open — mouth pointing down so fluid drains out.",
                       "上方腿屈髋屈膝。头稍后仰保持气道通畅——嘴朝下，便于液体流出。", set: ["stage": 6, "roll": 1, "tilt": 1]),
                .watch("Call 120/911. Stay and keep checking breathing. Stops or not normal? Roll onto the back and start CPR.",
                       "拨打 120。守在旁边，持续观察呼吸。呼吸停止或不正常？翻回仰卧，开始心肺复苏。", set: ["stage": 7]),
            ],
            draw: { s, p, t in drawRecovery(&s, p, t, who, lay) },
            onDrag: { point, _ in ["roll": ((point.y - lay.dragFrom) / (lay.dragTo - lay.dragFrom)).clamped(0, 1)] },
            sources: ["ILCOR 2025 CoSTR first aid; ERC 2025 & Red Cross: recovery position for unresponsive, normally breathing people",
                      "Pregnancy: left lateral position to keep the womb off the vena cava"]
        )
        s.profileNote = switch who.age {
        case .infant: nil
        case .toddler, .child: Bilingual("Child: same steps as adults. Stay with them and watch the breathing the whole time.",
                                         "儿童：步骤同成人。守在旁边，全程观察呼吸。")
        case .senior: Bilingual("65+: move stiff or painful joints gently — don’t force an arm or leg into place.",
                                "老人：关节僵硬或疼痛时动作要轻，不要强行摆放手臂或腿。")
        case .adult where who.isPregnant: Bilingual("Pregnant: roll her onto her LEFT side, so the womb doesn’t press on the big vein to the heart.",
                                                    "孕妇：让她向左侧卧，避免子宫压迫回心的大静脉。")
        case .adult: Bilingual("Adult: only for someone breathing normally. Not breathing normally → CPR instead.",
                               "成人：只用于呼吸正常者。呼吸不正常→改做心肺复苏。")
        }
        return s
    }

    private static func drawRecovery(_ s: inout Sketch, _ p: Params, _ t: Double, _ who: Profile, _ lay: RecoveryLayout) {
        let st = Int(p[v: "stage"].rounded())
        // seen from above, you kneel at the bottom edge; pregnant: mirrored so she ends up on her left side
        s.rect(0, 0, 360, 300, fill: hex("#E4D6C3"))
        for i in 0..<8 { s.line(0, Double(i) * 42 + 12, 360, Double(i) * 42 + 12, stroke: hex("#D5C4AD"), lw: 1) }
        let her = who.isPregnant
        func mx(_ q: CGPoint) -> CGPoint { her ? CGPoint(x: 360 - q.x, y: q.y) : q }
        var g = s
        if her { g.ctx.concatenate(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 360, ty: 0)) }
        let body = lay.pose(p)
        drawTopBody(&g, body, lay)

        // your hands
        let red = hex("#D8434B"), green = hex("#2E9E5B")
        var hands: [(CGPoint, SideFigure.Hand)] = []
        switch st {
        case 0: hands = [(body.nearShoulder, .open), (body.farShoulder, .open)]
        case 1, 6: hands = [(body.forehead, .open), (body.chin, .twoFingers)]
        case 2: hands = [(body.nearPalm, .open)]
        case 3: hands = [(body.farPalm, .open)]
        case 4, 5: hands = [(body.farPalm, .open), (body.farKnee, .open)]
        default: break
        }
        for (i, (at, shape)) in hands.enumerated() {
            yourHand(&g, at: at, from: CGPoint(x: at.x + 30 + Double(i) * 16, y: at.y + 90), shape: shape, k: lay.k)
        }
        if st == 5 && p[v: "roll"] < 0.95 {
            let k = body.farKnee, pulse = 1 + 0.25 * sin(t * 5)
            g.circle(k.x, k.y, 14 * pulse, stroke: red, lw: 2, opacity: 0.8)
            g.arrow(CGPoint(x: k.x + 22, y: k.y), CGPoint(x: k.x + 22, y: k.y + 34), color: red, lw: 2)
        }
        if st >= 6 {
            // anything in the mouth drains out
            let m = body.mouth
            for i in 0..<2 {
                let u = (t * 0.9 + Double(i) * 0.5).wrap(1)
                g.circle(m.x + 2, m.y + 4 + u * 14, 2.2 * (1 - u * 0.5), fill: hex("#7FB3D9"), opacity: 1 - u)
            }
        }

        // labels, unmirrored
        switch st {
        case 0:
            s.bubble("Are you OK?", "你还好吗？", 200, 262, tip: CGPoint(x: 214, y: 302))
            s.tag("no response", "无反应", mx(body.head).x, body.head.y - 40, size: 10, color: red, bold: true)
        case 1: s.tag("look · listen · feel ≤ 10 s", "看 · 听 · 感觉 ≤ 10 秒", mx(body.head).x + (her ? -30 : 30), body.head.y - 42, size: 10, bold: true)
        case 2: s.tag("right angle, palm up", "直角，掌心向上", mx(body.nearElbow).x, body.nearElbow.y + 34, size: 10, color: red, bold: true)
        case 3: s.tag("back of hand on the cheek", "手背贴脸颊", mx(body.head).x + (her ? -20 : 20), body.head.y - 42, size: 10, color: red, bold: true)
        case 4: s.tag("far knee up, foot flat", "远侧膝盖立起，脚掌着地", mx(body.farKnee).x, body.farKnee.y - 40, size: 10, color: red, bold: true)
        case 5:
            s.tag("pull the knee towards you", "把膝盖拉向你", 180, 58, size: 10, color: red, bold: true)
            if her { s.tag("onto her LEFT side", "向左侧卧", 180, 80, size: 10, color: hex("#B06C84"), bold: true) }
        case 6:
            s.tag("head tilted back — airway open", "头后仰——气道通畅", mx(body.head).x + (her ? -40 : 40), body.head.y - 44, size: 10, color: green, bold: true)
            s.tag("hip and knee bent", "屈髋屈膝", mx(body.farKnee).x, body.farKnee.y + 30, size: 10, bold: true)
        case 7:
            s.phone(her ? 40 : 320, 250, number: s.t("911", "120"), t: t)
            s.tag("keep checking breathing", "持续观察呼吸", 180, 30, size: 10, color: green, bold: true)
            s.tag("not breathing normally → CPR", "呼吸不正常 → 心肺复苏", 180, 52, size: 10, color: red, bold: true)
        default: break
        }
        if st >= 1 && st <= 6 {
            let x0 = her ? 206.0 : 8
            s.rect(x0, 8, 146, 30, r: 8, fill: .white, stroke: green, lw: 2)
            s.label("Breathing normally ✓", "呼吸正常 ✓", x0 + 73, 27, size: 11, color: green, anchor: .middle, bold: true)
        }
    }

    /// your forearm coming in from the bottom edge, hand at `at`
    private static func yourHand(_ s: inout Sketch, at: CGPoint, from: CGPoint, shape: SideFigure.Hand, k: Double) {
        // forearm and a stub of sleeve, like a manual's drawing: the rest of you is out of the picture
        let look = Look.rescuer, L = 21 * k, aw = 10.5 * k
        let d = unit(CGPoint(x: at.x - from.x, y: at.y - from.y))
        let wrist = CGPoint(x: at.x - d.x * L * 0.45, y: at.y - d.y * L * 0.45)
        let elbow = CGPoint(x: wrist.x - d.x * 44 * k, y: wrist.y - d.y * 44 * k)
        s.ellipse(at.x + 4 * k, at.y + 5 * k, L * 0.5, L * 0.3, fill: .black.opacity(0.08))
        s.taper([elbow, wrist], [aw, aw * 0.7], fill: look.skin, line: look.skinLine)
        let cuff = lerp(elbow, wrist, 0.3), back = CGPoint(x: elbow.x - d.x * 12 * k, y: elbow.y - d.y * 12 * k)
        s.taper([back, cuff], [aw * 1.4, aw * 1.25], fill: look.top, line: look.topLine)
        drawHand(&s, at: at, dir: d, len: L, shape: shape, look: look, thumb: -1)
    }

    /// person seen from above, head left
    private static func drawTopBody(_ s: inout Sketch, _ b: RecoveryLayout.Pose, _ lay: RecoveryLayout) {
        let look = lay.look, h = lay.h, bd = lay.build
        let lw = bd.legW * h, aw = bd.armW * h
        func leg(_ pts: [CGPoint]) {
            let d = unit(CGPoint(x: pts[2].x - pts[1].x, y: pts[2].y - pts[1].y))
            // shoe seen from above: sole outline, toe cap
            let toe = CGPoint(x: pts[2].x + d.x * bd.foot * h * 0.55, y: pts[2].y + d.y * bd.foot * h * 0.55)
            s.taper([lerp(pts[2], toe, 0.1), toe], [lw * 0.62, lw * 0.56], fill: look.shoes, line: look.bareFeet ? look.skinLine : hex("#1E1E24"))
            if !look.bareFeet { s.circle(lerp(pts[2], toe, 0.62).x, lerp(pts[2], toe, 0.62).y, lw * 0.1, fill: .white, opacity: 0.25) }
            s.taper(pts, [lw * 1.12, lw * 0.86, lw * 0.64], fill: look.bottom, line: look.onePiece ? look.topLine : darker(look.bottom))
        }
        func arm(_ sh: CGPoint, _ e: CGPoint, _ palm: CGPoint) {
            let d = unit(CGPoint(x: palm.x - e.x, y: palm.y - e.y))
            let w = CGPoint(x: palm.x - d.x * bd.hand * h * 0.45, y: palm.y - d.y * bd.hand * h * 0.45)
            dressedArm(&s, sh, e, w, aw: aw, look: look)
            drawHand(&s, at: palm, dir: d, len: bd.hand * h, shape: .open, look: look)
        }
        leg(b.nearLeg)
        if b.lift > 0.05 {
            let kn = b.farKnee
            s.ellipse(kn.x + 10 * b.lift, kn.y + 8 * b.lift, lw * 0.9, lw * 0.6, fill: .black, opacity: 0.12 * b.lift)
        }
        if b.roll < 0.5 { leg(b.farLeg) }
        if b.lift > 0.05 { s.circle(b.farKnee.x - 1, b.farKnee.y - 1, lw * 0.3, fill: .white, opacity: 0.3 * b.lift) }
        arm(b.nearShoulder, b.nearElbow, b.nearPalm)
        // neck and trunk
        s.limb([CGPoint(x: b.shoulderX - 2, y: b.yc), b.head], w: bd.headR * h * 0.8, fill: look.skin, line: look.skinLine)
        let half = b.half, xs = b.shoulderX, xh = b.hipX, yc = b.yc
        let outline = [(-0.01, 0.55), (0.02, 1.0), (0.14, 0.98), (0.8, 0.8), (1.0, 0.86), (1.12, 0.3), (1.12, -0.3), (1.0, -0.86), (0.8, -0.8),
                       (0.14, -0.98), (0.02, -1.0), (-0.01, -0.55)]
            .map { CGPoint(x: xs + $0.0 * (xh - xs), y: yc + $0.1 * half) }
        s.shape(smoothPath(outline), fill: look.top, stroke: look.topLine, lw: 1.3)
        if !look.onePiece {
            let pants = [(0.8, 0.8), (1.0, 0.86), (1.12, 0.3), (1.12, -0.3), (1.0, -0.86), (0.8, -0.8)]
                .map { CGPoint(x: xs + $0.0 * (xh - xs), y: yc + $0.1 * half) }
            s.shape(smoothPath(pants), fill: look.bottom, stroke: darker(look.bottom), lw: 1.2)
        }
        if lay.bump > 0 {
            let c = CGPoint(x: xs + 0.72 * (xh - xs), y: yc + b.roll * half * 0.75)
            s.ellipse(c.x, c.y, 0.09 * h, half * 0.72, fill: look.top, stroke: look.topLine, lw: 1.2)
            s.ellipse(c.x - 4, c.y - half * 0.2, 0.04 * h, half * 0.25, fill: .white, opacity: 0.25)
        }
        s.path("M \(xs + 1) \(yc - half * 0.45) Q \(xs + 8) \(yc) \(xs + 1) \(yc + half * 0.45)", stroke: look.topLine, lw: 1.1)
        if b.roll >= 0.5 { leg(b.farLeg) }
        // head: face up, or the side of the head once rolled; the far hand sits on / under the cheek
        let r = bd.headR * h
        if b.roll < 0.5 {
            s.group(translate: b.head, rotate: -90) { g in drawFrontHead(&g, at: .zero, r: r, look: look, face: .closed) }
            arm(b.farShoulder, b.farElbow, b.farPalm)
        } else {
            arm(b.farShoulder, b.farElbow, b.farPalm)
            drawSideHead(&s, at: b.head, up: b.up, side: -1, r: r, look: look, face: .closed, baby: bd.headR > 0.1)
        }
    }
}

/// Top-down geometry of the recovery-position scene for one person type.
struct RecoveryLayout: Sendable {
    let h: Double, build: Build, look: Look, bump: Double
    /// zoom: small people are drawn closer, your hands grow with them
    let k: Double
    let x0: Double, y0 = 140.0

    init(_ p: Profile) {
        let adult = p.age == .toddler ? 420.0 : p.age == .child ? 360 : 290
        k = adult / 290
        let c = Casualty(p, adult: adult)
        (h, build, look, bump) = (c.h, c.build, c.look, c.bump)
        let b = c.build
        let len = (2 * b.headR + b.neck + b.torso + b.thigh + b.shin + b.foot * 0.4) * c.h
        x0 = (360 - len) / 2
    }

    struct Pose {
        /// far knee pointing at the ceiling
        var lift: Double
        var roll: Double, yc: Double, half: Double, shoulderX: Double, hipX: Double
        var head: CGPoint, up: CGPoint
        var nearShoulder: CGPoint, nearElbow: CGPoint, nearPalm: CGPoint
        var farShoulder: CGPoint, farElbow: CGPoint, farPalm: CGPoint
        var nearLeg: [CGPoint], farLeg: [CGPoint]
        var forehead: CGPoint, chin: CGPoint, mouth: CGPoint
        var farKnee: CGPoint { farLeg[1] }
    }

    /// knee y at the start and end of the roll, for dragging
    var dragFrom: Double { pose(["knee": 1, "roll": 0]).farKnee.y }
    var dragTo: Double { pose(["knee": 1, "roll": 1]).farKnee.y }

    func pose(_ p: Params) -> Pose {
        let b = build, roll = p[v: "roll"], arm = p[v: "arm"], hand = p[v: "hand"], knee = p[v: "knee"], tilt = p[v: "tilt"]
        let r = b.headR * h, sw = b.shoulderW * h
        let U = b.upperArm * h, F = b.foreArm * h + b.hand * h * 0.45, T = b.thigh * h, S = b.shin * h
        let yc = y0 + roll * sw * 0.6, half = sw * (1 - 0.45 * roll)
        let xs = x0 + 2 * r + b.neck * h, xh = xs + b.torso * h
        let head = CGPoint(x: x0 + r, y: yc + roll * r * 0.15)
        let a = (8 + 10 * tilt) * .pi / 180
        let up = CGPoint(x: -cos(a), y: -sin(a))
        func P(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }

        let ns = P(xs + 0.02 * h, yc + half * 0.85), fs = P(xs + 0.02 * h, yc - half * 0.85)
        let restE = P(ns.x + U, ns.y + 3), outE = P(ns.x - 0.01 * h, ns.y + U)
        let ne = lerp(restE, outE, arm)
        let np = lerp(P(restE.x + F, restE.y + 2), P(outE.x - F, outE.y), arm)

        let cheek = roll < 0.5 ? P(head.x + 0.2 * r, head.y + 0.75 * r) : headSpot(head, up: up, r: r, 0.55, 0.7, side: -1)
        let fp = lerp(P(fs.x + U + F, fs.y - 3), cheek, hand)
        let (e1, _) = twoBone(fs, fp, U, F, 1), (e2, _) = twoBone(fs, fp, U, F, -1)
        let fe = e1.x > e2.x ? e1 : e2

        let nh = P(xh, yc + half * 0.42)
        let nk = P(nh.x + T, nh.y + roll * 2), na = P(nk.x + S, nk.y)
        let fh = P(xh, yc - half * 0.42 * (1 - roll))
        let flat = [fh, P(fh.x + T, fh.y), P(fh.x + T + S, fh.y)]
        let raised = [fh, P(fh.x + T * 0.55, fh.y - 3), P(fh.x + T * 0.92, fh.y + 1)]
        let rolled = [fh, P(fh.x + T * 0.25, fh.y + T * 0.95), P(fh.x + T * 0.25 + S * 0.95, fh.y + T * 0.95 + 4)]
        let far = (0..<3).map { lerp(lerp(flat[$0], raised[$0], knee), rolled[$0], roll) }

        let front = roll < 0.5
        return Pose(lift: knee * (1 - roll), roll: roll, yc: yc, half: half, shoulderX: xs, hipX: xh, head: head, up: up,
                    nearShoulder: ns, nearElbow: ne, nearPalm: np, farShoulder: fs, farElbow: fe, farPalm: fp,
                    nearLeg: [nh, nk, na], farLeg: far,
                    forehead: front ? P(head.x - 0.35 * r, head.y) : headSpot(head, up: up, r: r, 0.2, -0.75, side: -1),
                    chin: front ? P(head.x + 1.15 * r, head.y + 0.1 * r) : headSpot(head, up: up, r: r, 0.75, 1.1, side: -1),
                    mouth: front ? P(head.x + 0.55 * r, head.y) : headSpot(head, up: up, r: r, 1.0, 0.6, side: -1))
    }
}

// MARK: - Baby

extension Illustrations {
    static let babyRecovery = Scenario(
        id: "recovery-position", group: .firstAid, title: Bilingual("Recovery position (baby)", "婴儿复原体位"),
        profileNote: Bilingual("Baby: don’t lay them on their side — hold them in your arms, face down, head lower than the body.",
                               "婴儿：不要侧放在床上——抱在手臂上，面朝下，头低于身体。"),
        params: ["stage": 0, "tilt": 0],
        steps: [
            .watch("Baby floppy and won’t wake, but breathing normally? Tap the sole of the foot and call them.",
                   "婴儿软绵绵叫不醒，但呼吸正常？轻拍足底并呼唤。", set: ["stage": 0, "tilt": 0]),
            .watch("Keep the head level. Look, listen and feel for normal breathing — up to 10 s.",
                   "头保持水平。看、听、感觉有无正常呼吸，不超过 10 秒。", set: ["stage": 1]),
            .tryIt("Pick the baby up face down along your forearm, your hand supporting the head and jaw. Tilt so the head is lower than the body.",
                   "试一试：把婴儿面朝下抱在你的前臂上，手托住头和下颌。倾斜手臂，使头低于身体。", set: ["stage": 2, "tilt": 0],
                   TryStep(mode: .scrub([Scrub(param: "tilt", label: "Head down 头放低", min: 0, max: 1)]), success: { $0[v: "tilt"] >= 0.6 },
                           ok: Bilingual("Head lower — the tongue falls forward and vomit drains out of the mouth.", "头低了——舌头前移，呕吐物可从口中流出。"),
                           demo: ["tilt": 1])),
            .watch("Call 120/911. Keep holding the baby like this and keep checking breathing. It stops? Start baby CPR.",
                   "拨打 120。保持这样抱着，持续观察呼吸。呼吸停止？开始婴儿心肺复苏。", set: ["stage": 3, "tilt": 1]),
        ],
        draw: { s, p, t in drawBabyRecovery(&s, p, t) },
        sources: ["Red Cross / St John Ambulance baby first aid: hold an unresponsive, breathing baby face down along the forearm, head low",
                  "ILCOR 2025 CoSTR first aid"]
    )

    private static func drawBabyRecovery(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let st = Int(p[v: "stage"].rounded()), tilt = p[v: "tilt"]
        let green = hex("#2E9E5B"), red = hex("#D8434B")
        if st <= 1 {
            // close-up: baby on the bed, your hand and head come in from above
            let top = 250.0, bh = 290.0
            s.rect(0, 0, 360, 300, fill: hex("#F5F2ED"))
            s.rect(0, top, 360, 300 - top, fill: hex("#DCE6F0"))
            s.rect(0, top, 360, 6, fill: hex("#EEF3F8"))
            s.line(0, top + 6, 360, top + 6, stroke: hex("#BCCADA"), lw: 1)
            var b = SideFigure(h: bh, build: .infant, look: .baby, hip: .zero, rotation: -90, face: .closed)
            b.near = .init(shoulder: 20, elbow: 40)
            b.far = .init(shoulder: -8, elbow: 30)
            b.nearLeg = .init(hip: 16, knee: 28, point: 20)
            b.farLeg = .init(hip: 26, knee: 40, point: 20)
            b.hip = CGPoint(x: 0, y: top - Build.infant.depth * bh * 0.5 - 1)
            b.hip.x = 160 - b.front(0.64).x
            s.ellipse(b.hip.x - 30, top + 1, 110, 4, fill: .black.opacity(0.08))
            if st == 1 {
                // your cheek just above the mouth, eyes on the chest; your body is behind the bed
                let look = Look.rescuer, rr = 0.064 * 700
                let up = unit(CGPoint(x: 0.4, y: -1))
                let cheek = headSpot(.zero, up: up, r: rr, 0.5, 0.75)
                let rc = CGPoint(x: b.mouth.x - cheek.x - 4, y: b.mouth.y - cheek.y - 10)
                let rn = headSpot(rc, up: up, r: rr, -0.15, 0.8)
                s.taper([rn, CGPoint(x: rn.x - 14, y: top)], [rr * 0.85, rr * 0.95], fill: look.skin, line: look.skinLine)
                s.shape(smoothPath([CGPoint(x: rn.x - 60, y: rn.y + 18), CGPoint(x: rn.x - 8, y: rn.y + 16), CGPoint(x: rn.x + 40, y: rn.y + 30),
                                    CGPoint(x: rn.x + 50, y: top), CGPoint(x: rn.x - 90, y: top)]), fill: look.top, stroke: look.topLine, lw: 1.3)
                drawSideHead(&s, at: rc, up: up, r: rr, look: look, face: .calm)
            }
            b.draw(&s)
            if st == 0 {
                let toe = b.foot(near: true).toe, tap = sin(t * 9) * 2
                reachIn(&s, from: CGPoint(x: 400, y: 150), palm: CGPoint(x: toe.x + 26 + tap, y: toe.y + 6), dir: unit(CGPoint(x: -1, y: 0.05)), len: 58,
                        shape: .twoFingers, thumb: -1)
                s.bubble("Baby? Baby!", "宝宝？宝宝！", 250, 40, tip: CGPoint(x: 290, y: -2))
                s.callout("tap the sole — don’t shake", "轻拍足底——不要摇晃", 280, 118, to: CGPoint(x: toe.x + 4, y: toe.y - 6), color: red)
                s.callout("floppy, won’t wake", "软绵绵，叫不醒", 90, 120, to: b.headCentre, color: red)
            } else {
                let mouth = b.mouth
                let c = b.front(0.58), rise = max(0, sin(t * 2.2)), blue = hex("#3F95D6")
                s.arrow(CGPoint(x: c.x + 8, y: c.y - 4), CGPoint(x: c.x + 8, y: c.y - 14 - rise * 6), color: blue, lw: 2)
                s.path("M \(mouth.x + 6) \(mouth.y - 6) q 4 -4 0 -8 M \(mouth.x + 11) \(mouth.y - 4) q 6 -6 0 -12", stroke: blue, lw: 1.4, cap: .round)
                s.tag("look · listen · feel ≤ 10 s", "看 · 听 · 感觉 ≤ 10 秒", 270, 110, size: 10, bold: true)
                s.tag("head level", "头保持水平", 100, top + 24, size: 10, bold: true)
                s.rect(210, top + 10, 142, 28, r: 8, fill: .white, stroke: green, lw: 2)
                s.label("Breathing normally ✓", "呼吸正常 ✓", 281, top + 24, size: 11, color: green, anchor: .middle, bold: true)
            }
            return
        }
        // held face down along the forearm, close-up
        s.rect(0, 0, 360, 300, fill: hex("#F5F2ED"))
        let rh = 440.0
        var r = SideFigure(h: rh, look: .helper, hip: CGPoint(x: 84, y: 246), lean: 6, headTilt: 24)
        r.nearLeg = .init(hip: 2, knee: 0)
        r.farLeg = .init(hip: -2, knee: 0)
        let slope = 2 + tilt * 18
        let dir = CGPoint(x: cos(slope * .pi / 180), y: sin(slope * .pi / 180))
        let elbow = CGPoint(x: r.shoulderPoint.x + 16, y: r.shoulderPoint.y + r.build.upperArm * rh * 0.9)
        let palm = CGPoint(x: elbow.x + dir.x * (r.build.foreArm + r.build.hand * 0.45) * rh, y: elbow.y + dir.y * (r.build.foreArm + r.build.hand * 0.45) * rh)
        r.near = .init(reach: palm, hand: .open, handAngle: slope)

        let bh = rh * 0.4
        var b = SideFigure(h: bh, build: .infant, look: .baby, hip: .zero, rotation: 90 + slope, face: .closed)
        b.nearLeg = .init(hip: 50, knee: 60, point: 30)
        b.farLeg = .init(hip: 40, knee: 50, point: 30)
        b.near = .init(shoulder: 70, elbow: 30)
        b.far = .init(shoulder: 60, elbow: 40)
        let up = CGPoint(x: dir.y, y: -dir.x)
        let back = (Build.infant.torso + Build.infant.neck + Build.infant.headR * 0.9) * bh
        let lift = Build.infant.depth * bh * 0.5 + 5
        b.hip = CGPoint(x: palm.x - dir.x * back + up.x * lift + 6, y: palm.y - dir.y * back + up.y * lift)
        r.far = .init(reach: b.back(0.55), hand: .open, handAngle: slope)

        r.drawBack(&s, farArm: false)
        r.drawBody(&s)
        r.drawArm(&s, near: true)
        b.draw(&s)
        r.drawArm(&s, near: false)

        let headLow = tilt >= 0.6
        let hc = b.headCentre, hip = b.torso(0, 0)
        s.line(hip.x - 10, hip.y, hc.x + 30, hip.y, stroke: hex("#999999"), lw: 1, dash: [3, 3])
        s.tag(headLow ? "head lower than the body ✓" : "tilt: head lower", headLow ? "头低于身体 ✓" : "倾斜：让头更低",
              270, 60, size: 10, color: headLow ? green : red, bold: true)
        s.tag("hand supports the jaw", "手托住下颌", 270, 84, size: 9)
        if st == 3 {
            s.phone(320, 250, number: s.t("911", "120"), t: t)
            s.tag("keep checking breathing", "持续观察呼吸", 262, 150, size: 10, color: green, bold: true)
        }
    }
}
