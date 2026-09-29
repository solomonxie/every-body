import SwiftUI

extension Illustrations {
    static let pregnancyWarningSigns = Scenario(
        id: "pregnancy-warning-signs", group: .pregnancy, title: Bilingual("Warning signs in pregnancy", "孕期危险信号"),
        params: ["focus": 0, "mode": 0, "taps": 0, "press": 0, "sort": 0.5, "call": 0],
        steps: [
            .watch("Most aches in pregnancy are normal. These signs are not — they need a midwife or doctor now, not at the next check-up.",
                   "孕期的大多数不适是正常的，但以下信号不是——需要立即联系助产士或医生，不能等到下次产检。",
                   set: ["focus": 0, "mode": 0, "sort": 0.5, "call": 0]),
            .watch("Bleeding from the vagina, or waters breaking — a gush or a steady trickle of clear fluid — at any stage: call the maternity unit now.",
                   "任何孕周出现阴道出血，或破水（突然涌出或持续流出清亮液体）：立即联系产科。", set: ["focus": 1]),
            .watch("Pre-eclampsia, after 20 weeks: a severe headache, blurred vision or flashing lights, sudden swelling of the face, hands or feet, pain under the ribs. Get your blood pressure checked today.",
                   "子痫前期（孕 20 周后）：剧烈头痛、视物模糊或眼前闪光、面部和手脚突然水肿、肋下疼痛。当天测血压就医。", set: ["focus": 2]),
            .watch("A fever of 38 °C or more, or belly pain that is severe or doesn’t ease between tightenings: call now — infection or a placenta problem needs quick care.",
                   "发热 ≥ 38 °C，或腹痛剧烈、宫缩间歇也不缓解：立即联系——感染或胎盘问题需要尽快处理。", set: ["focus": 3]),
            .tryIt("From 28 weeks, get to know your baby’s pattern. Lie on your left side, hand on the bump, and tap each movement you feel.",
                   "试一试：孕 28 周起，熟悉宝宝的胎动规律。左侧卧，手放在肚子上，每感到一次胎动就点一下。",
                   set: ["mode": 1, "focus": 4, "taps": 0],
                   TryStep(mode: .rhythm(target: 10, minRate: 0, maxRate: 9999, label: "KICK 胎动"), success: { $0[v: "taps"] >= 10 },
                           ok: Bilingual("10 movements — reassuring. Fewer than usual, or a change in pattern? Call today; don’t wait until tomorrow.",
                                         "10 次胎动——令人安心。比平时少或规律改变？当天联系医院，不要等到第二天。"))),
            .tryIt("Sort them: which need a call now, and which can wait for your next check-up? Not sure? Call anyway — maternity units answer day and night.",
                   "试一试：分一分——哪些要立即联系，哪些可以等到下次产检？拿不准也要打电话——产科急诊 24 小时有人接听。",
                   set: ["mode": 2, "sort": 0.5],
                   TryStep(mode: .compare(param: "sort", options: [("Can wait 可等产检", 0), ("Call now 立即联系", 1)]), success: { abs($0[v: "sort"] - 0.5) > 0.4 },
                           ok: Bilingual("Red list: call now, day or night. Green list: mention it at your next check-up. Very heavy bleeding, a fit, collapse or chest pain: call 911.",
                                         "红色：立即联系，不分昼夜。绿色：下次产检时告诉医生。大出血、抽搐、晕倒或胸痛：立即拨打 120。"),
                           demo: ["sort": 1])),
        ],
        draw: { s, p, t in drawWarningSigns(&s, p, t) },
        sources: ["NHS: Symptoms you should not ignore in pregnancy", "CDC Hear Her: urgent maternal warning signs",
                  "RCOG Green-top 57 (reduced fetal movements); ACOG: counting movements, ~10 within 2 hours",
                  "NICE NG133 (pre-eclampsia symptoms)"],
        keywords: ["bleeding", "waters breaking", "pre-eclampsia", "baby not moving", "kick count", "fever", "阴道出血", "破水", "子痫前期", "胎动减少", "数胎动"]
    )

    /// the six call-now signs: symbol kind, text, and which focus step shows it
    private static let warnings: [(icon: Int, en: String, zh: String, focus: Int)] = [
        (0, "Bleeding from the vagina", "阴道出血", 1),
        (1, "Waters breaking", "破水（流液）", 1),
        (2, "Bad headache, blurred vision, sudden swelling", "剧烈头痛、视物模糊、\n突然水肿", 2),
        (3, "Fever 38 °C or more", "发热 ≥ 38 °C", 3),
        (4, "Severe or constant belly pain", "剧烈或持续腹痛", 3),
        (5, "Baby moving less", "胎动减少", 4),
    ]

    @MainActor private static func drawWarningSigns(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let mode = p[v: "mode"]
        let map = max(0, 1 - abs(mode)), kicks = max(0, 1 - abs(mode - 1)), sort = max(0, 1 - abs(mode - 2))
        if map > 0.01 { s.group(opacity: map) { g in drawSignMap(&g, p, t) } }
        if kicks > 0.01 { s.group(opacity: kicks) { g in drawKickCount(&g, p, t) } }
        if sort > 0.01 { s.group(opacity: sort) { g in drawSortBoard(&g, p, t) } }
    }

    /// how strongly a focus group is shown: every group at focus 0, then one at a time
    private static func weight(_ focus: Double, _ g: Int) -> Double {
        max(max(0, 1 - focus), max(0, 1 - abs(focus - Double(g))))
    }

    /// small round symbol for each warning
    @MainActor private static func signIcon(_ s: inout Sketch, _ i: Int, at c: CGPoint, r: Double, on: Double) {
        let col = on > 0.5 ? Anat.red : Anat.muted
        s.circle(c.x, c.y, r, fill: on > 0.5 ? hex("#FDECEC") : hex("#F2EFEA"), stroke: col, lw: 1.2)
        let k = r / 10
        switch i {
        case 0:
            s.path("M \(c.x) \(c.y - 6 * k) Q \(c.x + 5 * k) \(c.y + 1 * k) \(c.x) \(c.y + 5 * k) Q \(c.x - 5 * k) \(c.y + 1 * k) \(c.x) \(c.y - 6 * k) Z", fill: col)
        case 1:
            for (dx, dy) in [(-3.0, -2.0), (3, 1)] {
                let x = c.x + dx * k, y = c.y + dy * k
                s.path("M \(x) \(y - 4 * k) Q \(x + 3.2 * k) \(y + 1 * k) \(x) \(y + 3 * k) Q \(x - 3.2 * k) \(y + 1 * k) \(x) \(y - 4 * k) Z", fill: on > 0.5 ? Tone.blue : Anat.muted)
            }
        case 2:
            s.path("M \(c.x - 5 * k) \(c.y - 4 * k) L \(c.x - 1 * k) \(c.y) L \(c.x - 3 * k) \(c.y + 1 * k) L \(c.x + 1 * k) \(c.y + 6 * k) L \(c.x) \(c.y + 1.5 * k) L \(c.x + 2 * k) \(c.y + 0.5 * k) L \(c.x - 1 * k) \(c.y - 5 * k) Z",
                   fill: col)
            s.circle(c.x + 4.5 * k, c.y - 3 * k, 1.6 * k, fill: col)
        case 3:
            s.rect(c.x - 1.6 * k, c.y - 6 * k, 3.2 * k, 9 * k, r: 1.6 * k, stroke: col, lw: 1.1)
            s.circle(c.x, c.y + 4 * k, 2.6 * k, fill: col)
            s.line(c.x, c.y - 1 * k, c.x, c.y + 3 * k, stroke: col, lw: 1.4)
        case 4:
            s.path("M \(c.x - 5 * k) \(c.y - 2 * k) L \(c.x - 1 * k) \(c.y + 1 * k) L \(c.x + 1 * k) \(c.y - 3 * k) L \(c.x + 5 * k) \(c.y + 2 * k)", stroke: col, lw: 1.6, cap: .round)
            s.path("M \(c.x - 5 * k) \(c.y + 3 * k) L \(c.x - 1 * k) \(c.y + 6 * k) L \(c.x + 1 * k) \(c.y + 2 * k) L \(c.x + 5 * k) \(c.y + 7 * k)", stroke: col, lw: 1.1, opacity: 0.6, cap: .round)
        default:
            s.path("M \(c.x - 2 * k) \(c.y + 6 * k) C \(c.x - 5 * k) \(c.y + 2 * k), \(c.x - 5 * k) \(c.y - 4 * k), \(c.x) \(c.y - 5 * k) "
                   + "C \(c.x + 4 * k) \(c.y - 5 * k), \(c.x + 5 * k) \(c.y - 1 * k), \(c.x + 3 * k) \(c.y + 2 * k) L \(c.x + 5 * k) \(c.y + 5 * k)", stroke: col, lw: 1.5, cap: .round)
            s.circle(c.x + 0.5 * k, c.y - 1.5 * k, 2 * k, fill: col)
        }
    }

    // MARK: body map

    @MainActor private static func drawSignMap(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let focus = p[v: "focus"]
        let floor = 290.0, pulse = 0.5 + 0.5 * sin(t * 3)
        s.stage(94, floor: floor, r: 92, width: 206)
        var f = SideFigure(h: 250, look: .woman, hip: .zero, face: focus > 1.5 && focus < 2.5 ? .distress : .calm, bump: 1)
        f.hip = CGPoint(x: 88, y: floor - SideFigure.hipHeight(250, .adult))
        // weight on the back leg, the front knee soft; one hand on the small of her back
        f.nearLeg = .init(hip: 8, knee: 10, point: 4)
        f.farLeg = .init(hip: -5, knee: 2)
        let pain = weight(focus, 3) * (focus > 0.5 ? 1 : 0.6)
        f.far = .init(reach: f.back(0.3), hand: .open, handAngle: 70, flip: true)
        if focus > 1.5 && focus < 2.5 {
            f.near = .init(reach: f.headPoint(-0.02, -0.52), hand: .open, handAngle: -100, flip: true)
        } else if focus > 2.5 {
            // cradling the bump from below
            let low = f.front(0.28)
            f.near = .init(reach: CGPoint(x: low.x - 4, y: low.y), hand: .open, handAngle: 80)
        } else {
            let top = f.front(0.5)
            f.near = .init(reach: CGPoint(x: top.x - 2, y: top.y - 3), hand: .open, handAngle: 60)
        }
        var head = f.headCentre, eye = f.headPoint(0.62, -0.05), crotch = f.torso(0.25, -0.08)
        var bump = f.front(0.3), ribs = f.torso(0.25, 0.62), ankle = f.legPoint(near: true, 1.95), hand = f.palm(near: false)
        if SceneArt.image("signs-pregnant-0") != nil {
            // rendered woman: hand on the bump (0, 1), to the forehead (2), under the bump (3+)
            let key = { (x: Int) in x <= 1 ? "0" : x == 2 ? "2" : "3" }
            let lo = Int(focus.clamped(0, 4).rounded(.down)), fr = focus.clamped(0, 4) - Double(lo)
            let a = key(lo), b = key(min(4, lo + 1)), k = a == b ? 0 : fr * fr * (3 - 2 * fr)
            s.art([("signs-pregnant-\(a)", 1 - k), ("signs-pregnant-\(b)", k)])
            let m = SceneMarks.at("signs-pregnant-\(k > 0.5 ? b : a)")
            head = m["head"] ?? head; eye = m["eye"] ?? eye; crotch = m["crotch"] ?? crotch
            bump = m["bump"] ?? bump; ribs = m["ribs"] ?? ribs; ankle = m["ankle"] ?? ankle; hand = m["hand"] ?? hand
        } else {
            f.draw(&s)
        }

        // what each sign looks like on her
        let w1 = weight(focus, 1), w2 = weight(focus, 2), w3 = weight(focus, 3)
        if w1 > 0.05 {
            let drip = (t * 0.6).wrap(1)
            s.path("M \(crotch.x) \(crotch.y + 6) q 3 5 0 7 q -3 -2 0 -7 Z", fill: Anat.red, opacity: w1)
            s.path("M \(crotch.x - 4) \(crotch.y + 10 + drip * 30) q 2.5 4 0 5.5 q -2.5 -1.5 0 -5.5 Z", fill: Tone.blue, opacity: w1 * (1 - drip))
        }
        if w2 > 0.05 {
            s.softGlow(head, 30, 26, Anat.red, 0.3 * w2 * (0.6 + 0.4 * pulse))
            for i in 0..<3 {
                let a = -0.9 + Double(i) * 0.45
                let x = eye.x + 10 + cos(a) * 12, y = eye.y + sin(a) * 12
                s.path("M \(x) \(y) l 4 -2 l -1 4 l 4 -1", stroke: hex("#E0A21B"), lw: 1.3, opacity: w2 * pulse, cap: .round)
            }
            s.softGlow(ankle, 12, 8, hex("#E0A21B"), 0.45 * w2)
            s.softGlow(hand, 10, 10, hex("#E0A21B"), 0.45 * w2)
            s.softGlow(ribs, 14, 12, Anat.red, 0.3 * w2)
        }
        if w3 > 0.05 {
            s.softGlow(bump, 26, 30, Anat.red, 0.35 * pain * (0.6 + 0.4 * pulse))
            s.softGlow(head, 26, 24, hex("#E0892B"), 0.25 * w3)
        }

        // numbered markers around her, linked to the spot
        let marks: [(Int, CGPoint, CGPoint)] = [
            (0, crotch, CGPoint(x: 20, y: 210)), (1, CGPoint(x: crotch.x - 2, y: crotch.y + 16), CGPoint(x: 20, y: 246)),
            (2, CGPoint(x: head.x + 4, y: head.y - 8), CGPoint(x: 26, y: 40)), (3, CGPoint(x: head.x - 10, y: head.y + 2), CGPoint(x: 20, y: 96)),
            (4, bump, CGPoint(x: 186, y: 190)), (5, CGPoint(x: bump.x - 10, y: bump.y + 6), CGPoint(x: 186, y: 150)),
        ]
        for m in marks {
            let w = weight(focus, warnings[m.0].focus)
            let on = focus < 0.5 || abs(focus - Double(warnings[m.0].focus)) < 0.5
            s.line(m.1.x, m.1.y, m.2.x, m.2.y, stroke: on ? Anat.red : Anat.muted, lw: 0.8, dash: [2, 2], opacity: 0.4 + 0.5 * w)
            s.circle(m.1.x, m.1.y, 1.8, fill: on ? Anat.red : Anat.muted, opacity: 0.4 + 0.6 * w)
            s.group(opacity: 0.35 + 0.65 * w) { g in signIcon(&g, m.0, at: m.2, r: 11, on: on ? 1 : 0) }
        }

        // right: the call-now list
        let px = 212.0, pw = 142.0
        s.stateChip("Call now", "立即联系", px + pw, 8, color: Anat.red, anchor: .end)
        s.card(px, 40, pw, 214, accent: Anat.red)
        for (i, w) in warnings.enumerated() {
            let y = 64 + Double(i) * 32
            let on = focus < 0.5 || abs(focus - Double(w.focus)) < 0.5
            let wt = weight(focus, w.focus)
            s.group(opacity: 0.35 + 0.65 * wt) { g in
                signIcon(&g, w.icon, at: CGPoint(x: px + 20, y: y), r: 9, on: on ? 1 : 0)
                g.leftNote(w.en, w.zh, px + 34, y, width: pw - 40, size: 8.5, color: on ? Tone.ink : Tone.sub, bold: on)
            }
        }
        s.rect(px, 262, pw, 30, r: 9, fill: hex("#FFF1F1"), stroke: Anat.red, lw: 1.2)
        s.cardNote("Maternity unit · day or night", "产科急诊 · 24 小时", px + pw / 2, 277, width: pw - 10, size: 9, color: Anat.red, bold: true)
    }

    // MARK: kick count

    @MainActor private static func drawKickCount(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let taps = Int(p[v: "taps"].rounded()), press = p[v: "press"].clamped(0, 1)
        // mother curled on her left side, bed seen from above; a window into the womb
        let bed = CGRect(x: 6, y: 108, width: 200, height: 184)
        s.rect(bed.minX, bed.minY + 2, bed.width, bed.height, r: 10, fill: .black.opacity(0.07))
        s.rect(bed.minX, bed.minY, bed.width, bed.height, r: 10, fill: hex("#EAF1F8"), stroke: hex("#B9C9DC"), lw: 1)
        var f = SideFigure(h: 250, look: .woman, hip: CGPoint(x: 138, y: 250), rotation: -82, face: .calm, bump: 1)
        f.headTilt = 10
        // pillow under her head
        let hc = f.headCentre, py = min(max(hc.y - 44, bed.minY + 8), bed.maxY - 96)
        s.shade(Path(roundedRect: CGRect(x: bed.minX + 8, y: py, width: 40, height: 88), cornerRadius: 14), .white, hex("#E1E7EF"), stroke: hex("#C3CEDB"), lw: 1)
        f.nearLeg = .init(hip: 84, knee: 118, point: 20)
        f.farLeg = .init(hip: 66, knee: 106, point: 20)
        let bump = f.front(0.3)
        f.near = .init(reach: CGPoint(x: bump.x - 14, y: bump.y - 4), hand: .open, handAngle: 5)
        f.drawBack(&s, farArm: false)
        f.drawBody(&s)
        let wc = CGPoint(x: bump.x - 2, y: bump.y + 20)
        s.gradFill(Path(ellipseIn: CGRect(x: wc.x - 40, y: wc.y - 28, width: 80, height: 56)), [hex("#E7A0AE"), hex("#CF7C8E")],
                   from: CGPoint(x: wc.x, y: wc.y - 28), to: CGPoint(x: wc.x, y: wc.y + 28), stroke: hex("#B5627A"), lw: 1)
        s.gradFill(Path(ellipseIn: CGRect(x: wc.x - 35, y: wc.y - 23, width: 70, height: 46)), [hex("#FDEDEF"), hex("#F7D6DC")],
                   from: CGPoint(x: wc.x, y: wc.y - 23), to: CGPoint(x: wc.x, y: wc.y + 23))
        // head down toward her pelvis (picture right), feet up under her ribs
        drawFetus(&s, at: CGPoint(x: wc.x + 2, y: wc.y + 1), length: 58, week: 32, rotate: 95, kick: press * 9)
        if press > 0.05 {
            let kp = CGPoint(x: wc.x - 24, y: wc.y - 22)
            for r in [8.0, 14, 20] { s.circle(kp.x, kp.y, r * (1.4 - press * 0.4), stroke: Anat.purple, lw: 1.4, opacity: press * (1 - r / 26)) }
            s.label("kick!", "动了！", kp.x - 6, kp.y - 20, size: 10, color: Anat.purple, anchor: .middle, bold: true)
        }
        drawBlanket(&s, x0: 176, bed: bed)
        f.drawArm(&s, near: true)
        s.card(6, 8, 200, 90, accent: Anat.purple)
        s.caption("How to count", "怎么数", 18, 24)
        let how: [(String, String)] = [("from 28 weeks, once a day", "孕 28 周起，每天一次"), ("when baby is usually active", "在宝宝平时活跃的时段"),
                                       ("lie on your left side, hand on the bump", "左侧卧，手放在肚子上"), ("kicks, rolls, swishes all count", "踢、翻身、蠕动都算")]
        for (i, h) in how.enumerated() {
            let y = 42 + Double(i) * 15
            s.circle(20, y - 3, 2, fill: Anat.purple)
            s.label(h.0, h.1, 27, y, size: 8.5, color: Tone.ink)
        }

        // right: tally of ten
        let px = 212.0, pw = 142.0
        s.stateChip(taps >= 10 ? "10 movements ✓" : "Counting…", taps >= 10 ? "10 次胎动 ✓" : "正在计数…", px + pw, 8,
                    color: taps >= 10 ? Anat.green : Anat.purple, anchor: .end)
        s.card(px, 40, pw, 128)
        s.caption("Movements felt", "感到的胎动", px + 10, 56)
        for i in 0..<10 {
            let c = CGPoint(x: px + 20 + Double(i % 5) * 25, y: 78 + Double(i / 5) * 26)
            let done = i < taps
            s.circle(c.x, c.y, 9, fill: done ? Anat.purple : hex("#F2EFF7"), stroke: Anat.purple.opacity(0.6), lw: 1)
            if done { s.text("\(i + 1)", c.x, c.y + 3.5, size: 9, color: .white, anchor: .middle, bold: true) }
        }
        s.label("\(min(taps, 10)) / 10", "\(min(taps, 10)) / 10", px + 12, 150, size: 18, color: Anat.purple, bold: true)
        s.label("usually within", "通常在", px + pw - 10, 141, size: 7.5, color: Tone.sub, anchor: .end)
        s.label("2 hours", "2 小时内", px + pw - 10, 152, size: 7.5, color: Tone.sub, anchor: .end, bold: true)
        s.rect(px, 178, pw, 114, r: 10, fill: hex("#FFF1F1"), stroke: Anat.red, lw: 1.2)
        s.label("Call the same day if", "出现以下情况当天联系", px + pw / 2, 196, size: 9.5, color: Anat.red, anchor: .middle, bold: true)
        let rows: [(String, String)] = [("fewer than usual", "胎动比平时少"), ("the pattern changes", "胎动规律改变"),
                                        ("no movement at all", "完全感觉不到胎动")]
        for (i, r) in rows.enumerated() {
            let y = 216 + Double(i) * 18
            s.circle(px + 12, y - 3, 2.2, fill: Anat.red)
            s.label(r.0, r.1, px + 20, y, size: 8.5, color: Tone.ink)
        }
        s.cardNote("Don’t wait until tomorrow", "不要等到第二天", px + pw / 2, 278, width: pw - 12, size: 8.5, color: Anat.red, bold: true)
    }

    // MARK: sort board

    @MainActor private static func drawSortBoard(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let v = p[v: "sort"], call = p[v: "call"].clamped(0, 1)
        let apart = Anat.ease(abs(v - 0.5) * 2 + call)
        let pickUrgent = v > 0.5
        let routine: [(String, String)] = [
            ("Morning sickness", "孕吐"), ("Heartburn", "烧心"), ("Mild ankle swelling by evening", "傍晚脚踝轻度水肿"),
            ("Backache", "腰背痛"), ("Tightenings that come and go", "偶尔发紧、能缓解"), ("Leg cramps at night", "夜间腿抽筋"),
        ]
        let colW = 170.0, gap = 8.0
        let left = CGRect(x: 6, y: 34, width: colW, height: 234), right = CGRect(x: 6 + colW + gap, y: 34, width: colW, height: 234)
        let green = Anat.green, red = Anat.red
        func header(_ r: CGRect, _ en: String, _ zh: String, _ col: Color, lit: Bool) {
            s.rect(r.minX, r.minY, r.width, r.height, r: 12, fill: col.opacity(lit ? 0.09 : 0.04), stroke: col.opacity(lit ? 0.8 : 0.3), lw: lit ? 1.5 : 1)
            s.label(en, zh, r.midX, r.minY + 16, size: 10, color: col, anchor: .middle, bold: true)
        }
        header(left, "Can wait for the check-up", "可等下次产检", green, lit: apart > 0.5 && !pickUrgent)
        header(right, "Call now", "立即联系", red, lit: apart > 0.5 && pickUrgent || call > 0.5)
        s.label("Call now, or wait?", "立即联系，还是等产检？", 180, 18, size: 11, color: Tone.ink, anchor: .middle, bold: true)
        // cards start in one shuffled pile down the middle and slide into their column
        let order = [0, 6, 1, 7, 2, 8, 3, 9, 4, 10, 5, 11]
        for (slot, idx) in order.enumerated() {
            let urgent = idx >= 6, i = urgent ? idx - 6 : idx
            let pile = CGPoint(x: 180 - 76, y: 56 + Double(slot) * 17.5)
            let home = CGPoint(x: (urgent ? right : left).minX + 6, y: 58 + Double(i) * 34)
            let pos = lerp(pile, home, apart)
            let lit = apart > 0.5 && (urgent == pickUrgent || (call > 0.5 && urgent))
            let col = urgent ? red : green
            let h = 15 + 14 * apart
            s.rect(pos.x + 1, pos.y + 1.5, colW - 12, h, r: 7, fill: .black.opacity(0.06))
            s.rect(pos.x, pos.y, colW - 12, h, r: 7, fill: .white, stroke: apart > 0.3 ? col.opacity(lit ? 0.9 : 0.35) : Tone.rule, lw: 1)
            let label: (String, String) = urgent ? (warnings[i].en, warnings[i].zh) : routine[i]
            if urgent {
                signIcon(&s, warnings[i].icon, at: CGPoint(x: pos.x + 13, y: pos.y + h / 2), r: 7 + 2 * apart, on: apart > 0.3 ? 1 : 0)
            } else {
                s.circle(pos.x + 13, pos.y + h / 2, 7 + 2 * apart, fill: apart > 0.3 ? hex("#EAF6EE") : hex("#F2EFEA"), stroke: apart > 0.3 ? green : Anat.muted, lw: 1.2)
                s.path("M \(pos.x + 9) \(pos.y + h / 2) l 3 3 l 5 -6", stroke: apart > 0.3 ? green : Anat.muted, lw: 1.4, cap: .round)
            }
            s.group(opacity: lit || apart < 0.5 ? 1 : 0.55) { g in
                g.leftNote(label.0, label.1, pos.x + 27, pos.y + h / 2, width: colW - 44, size: 8, color: Tone.ink, bold: lit)
            }
        }
        if call > 0.02 {
            s.group(opacity: call) { g in
                g.rect(6, 274, 348, 22, r: 12, fill: hex("#FFF1F1"), stroke: red, lw: 1.2)
                g.label("Unsure? Call anyway · heavy bleeding, fit, collapse →", "拿不准也要打电话 · 大出血、抽搐、晕倒 →", 16, 289, size: 8.5, color: red, bold: true)
                g.pill(g.t("911", "120"), g.t("911", "120"), 346, 285, color: red, size: 9, anchor: .end)
            }
        }
    }
}

extension Sketch {
    /// Left-aligned wrapped text, vertically centred on `midY`.
    fileprivate mutating func leftNote(_ en: String, _ zh: String, _ x: Double, _ midY: Double, width: Double, size: Double = 9,
                                       color: Color = Anat.text, bold: Bool = false) {
        let txt = ctx.resolve(Text(t(en, zh)).font(.system(size: size, weight: bold ? .semibold : .medium)).foregroundStyle(color))
        let m = txt.measure(in: CGSize(width: width, height: 200))
        ctx.draw(txt, in: CGRect(x: x, y: midY - m.height / 2, width: width, height: m.height + 1))
    }
}

/// Blanket over the lower legs on a bed seen from above.
@MainActor private func drawBlanket(_ g: inout Sketch, x0: Double, bed: CGRect) {
    g.shade("M \(x0) \(bed.minY) L \(bed.maxX - 10) \(bed.minY) Q \(bed.maxX) \(bed.minY) \(bed.maxX) \(bed.minY + 10) L \(bed.maxX) \(bed.maxY - 10) "
            + "Q \(bed.maxX) \(bed.maxY) \(bed.maxX - 10) \(bed.maxY) L \(x0) \(bed.maxY) C \(x0 - 8) \(bed.midY + 40), \(x0 + 8) \(bed.midY - 40), \(x0) \(bed.minY) Z",
            hex("#C9D8EC"), hex("#A9BEDB"), stroke: hex("#8FA6C6"), lw: 1)
}
