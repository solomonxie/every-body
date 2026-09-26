import SwiftUI

extension Illustrations {
    /// fraction of the starved zone lost after `minutes` without flow
    static func strokeCore(_ p: Params) -> Double {
        p[v: "clot"] < 0.5 ? 0 : min(1, (min(p[v: "minutes"], p[v: "treated"] > 0.5 ? 60 : 360) / 360).squareRoot())
    }

    static let stroke = Scenario(
        id: "stroke", group: .illness, title: Bilingual("Stroke", "脑卒中（中风）"),
        params: ["clot": 0, "minutes": 0, "treated": 0, "fast": 0, "senior": 0, "kid": 0],
        steps: [
            .watch("Arteries carry oxygen to every part of the brain. The left side of the brain moves the right side of the body and makes speech.",
                   "动脉为大脑各处输送氧气。左脑控制右侧身体，并负责语言。", set: ["clot": 0, "minutes": 0, "treated": 0, "fast": 0]),
            .watch("Ischaemic stroke: a clot blocks a brain artery. Suddenly one side of the face droops, one arm drifts down, speech slurs.",
                   "缺血性卒中：血栓堵塞脑动脉。突然一侧口角歪斜、一侧手臂无力下垂、说话含糊。", set: ["clot": 1, "minutes": 5]),
            .tryIt("Drag the clock. About 1.9 million brain cells die every minute — the dead core spreads.", "试一试：拖动时间。每分钟约 190 万个脑细胞死亡——坏死区不断扩大。",
                   TryStep(mode: .scrub([Scrub(param: "minutes", label: "Minutes 分钟", min: 0, max: 360, digits: 0)]), success: { $0[v: "minutes"] >= 120 },
                           ok: Bilingual("Time is brain.", "时间就是大脑。"), demo: ["minutes": 180])),
            .watch("Spot it — F.A.S.T.: Face uneven, Arm weak, Speech slurred → Time to call 120/911. Note when it started.",
                   "识别“中风120”：1 看脸不对称，2 查两臂一侧无力，0 聆听言语不清 → 立即拨打 120，记下发病时间。", set: ["fast": 1]),
            .tryIt("Compare: clot dissolved or pulled out at hospital within an hour vs. no treatment.", "对比：1 小时内在医院溶栓/取栓 vs. 未治疗。",
                   set: ["minutes": 240, "fast": 0],
                   TryStep(mode: .compare(param: "treated", options: [("No treatment 未治疗", 0), ("Treated at 1 h 1小时内治疗", 1)]),
                           success: { $0[v: "treated"] > 0.5 }, ok: Bilingual("Fast treatment saves the at-risk area — and the arm and speech.", "及时治疗挽救缺血半暗带——也挽救手臂和语言。"),
                           demo: ["treated": 1])),
        ],
        draw: { s, p, t in drawStroke(&s, p, t) },
        sources: ["Saver 2006 “Time is brain” (1.9 million neurons/min); Chinese Stroke Association 中风120; AHA BE-FAST"]
    )

    static func stroke(for p: Profile) -> Scenario {
        var s = stroke
        switch p.age {
        case .senior:
            s.profileNote = Bilingual("65+: risk doubles every decade after 55. An irregular pulse (atrial fibrillation) is a major cause — get it checked. Sudden loss of balance or vision counts too.",
                                      "65 岁以上：55 岁后每 10 年风险翻倍。心律不齐（房颤）是重要原因——要检查。突然失去平衡或视物不清也要警惕。")
            return s.rebased(["senior": 1])
        case .infant, .child:
            s.profileNote = Bilingual("Rare in children, but real: sudden weakness on one side, a seizure, or the worst headache — call 120, don't wait.",
                                      "儿童少见但会发生：突然一侧无力、抽搐或剧烈头痛——立即拨打 120，不要等待。")
            return s.rebased(["kid": 1])
        case .adult where p.isPregnant:
            s.profileNote = Bilingual("Pregnancy and the 6 weeks after birth raise stroke risk. Severe headache, vision changes or very high blood pressure → call 120.",
                                      "孕期及产后 6 周中风风险升高。剧烈头痛、视物异常或血压很高 → 拨打 120。")
        case .adult: break
        }
        return s
    }

    /// clock face with the minute hand at `minutes`
    @MainActor static func minuteClock(_ s: inout Sketch, _ c: CGPoint, _ r: Double, _ minutes: Double, _ color: Color) {
        s.circle(c.x, c.y, r, fill: .white, stroke: color, lw: 2)
        for i in 0..<12 {
            let a = Double(i) / 12 * 2 * .pi
            s.line(c.x + sin(a) * r * 0.78, c.y - cos(a) * r * 0.78, c.x + sin(a) * r * 0.92, c.y - cos(a) * r * 0.92, stroke: color, lw: 1)
        }
        let m = minutes / 60 * 2 * .pi, hr = (minutes / 720 + 10.0 / 12) * 2 * .pi
        s.line(c.x, c.y, c.x + sin(hr) * r * 0.45, c.y - cos(hr) * r * 0.45, stroke: color, lw: 2, cap: .round)
        s.line(c.x, c.y, c.x + sin(m) * r * 0.7, c.y - cos(m) * r * 0.7, stroke: color, lw: 1.5, cap: .round)
    }

    /// round letter badge for F.A.S.T. / 中风120
    @MainActor static func badge(_ s: inout Sketch, _ x: Double, _ y: Double, _ letter: String, _ color: Color) {
        s.circle(x, y, 9, fill: color)
        s.text(letter, x, y + 4, size: 11, color: .white, anchor: .middle, bold: true)
    }

    @MainActor private static func drawStroke(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let core = strokeCore(p), blocked = p[v: "clot"] > 0.5, treated = p[v: "treated"] > 0.5
        let red = hex("#D8434B"), ink = hex("#555555"), fast = p[v: "fast"]
        // symptoms ease back when treated in time
        let weak = blocked ? (treated ? 0.25 : min(1, 0.6 + p[v: "minutes"] / 60)) : 0

        // the person: right side of the face droops, right arm drifts down
        let neck = CGPoint(x: 95, y: 132)
        var person = FacingPerson(h: 200, face: blocked && !treated ? .worried : .calm, droop: weak, legs: true)
        person.head = p[v: "kid"] > 0.5 ? 1.45 : 1.3
        if p[v: "senior"] > 0.5 { person.hair = hex("#BDBDBD") }
        let armY = -0.03 * person.h
        person.leftHand = CGPoint(x: 0.4 * person.h, y: armY)
        person.rightHand = CGPoint(x: -0.4 * person.h + weak * 14, y: armY + weak * 52)
        s.line(0, 298, 180, 298, stroke: hex("#BBBBBB"), lw: 2)
        person.draw(&s, at: neck)
        let head = CGPoint(x: neck.x, y: neck.y + person.headCenter.y)
        if blocked {
            s.path("M 114 64 L 196 64 Q 200 64 200 68 L 200 88 Q 200 92 196 92 L 126 92 L 116 102 L 120 92 Q 110 92 110 88 L 110 68 Q 110 64 114 64 Z",
                   fill: .white, stroke: hex("#AAAAAA"))
            s.label(treated ? "I feel better" : "I… c-can’t… say it", treated ? "我好多了" : "我…说…不…清", 155, 82, size: 8.5, color: treated ? ink : red, anchor: .middle, bold: !treated)
            if weak > 0.5 {
                let hx = neck.x - 0.4 * person.h + weak * 14 - 14, hy = neck.y + armY + weak * 52
                s.path("M \(hx) \(hy - 34) L \(hx) \(hy - 8) M \(hx - 4) \(hy - 13) L \(hx) \(hy - 8) L \(hx + 4) \(hy - 13)", stroke: red, lw: 1.5)
            }
        }
        if fast > 0.05 {
            s.group(opacity: fast) { g in
                let en = ["F", "A", "S", "T"], zh = ["1", "2", "0", "☎"]
                let spots = [CGPoint(x: head.x - 28, y: head.y + 6), CGPoint(x: 18, y: neck.y + 30), CGPoint(x: 100, y: 64), CGPoint(x: 22, y: 58)]
                for i in 0..<4 { badge(&g, spots[i].x, spots[i].y, g.zh ? zh[i] : en[i], red) }
                g.label("face", "看脸", head.x - 28, head.y + 26, size: 8, color: red, anchor: .middle)
                g.label("arm", "查臂", 18, neck.y + 50, size: 8, color: red, anchor: .middle)
                g.label("call 120", "拨打 120", 34, 62, size: 9, color: red, bold: true)
            }
        }

        // brain, left side view, face to the left: the left brain runs the right body
        let k = 0.58, o = CGPoint(x: 200 - 58 * k, y: 62 - 45 * k)
        func bp(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: o.x + x * k, y: o.y + y * k) }
        s.group(translate: o, scale: k) { g in
            let cortex = "M 62 138 C 58 88, 108 48, 178 45 C 248 42, 302 78, 306 132 C 308 160, 296 178, 278 186 C 262 190, 246 188, 232 184 "
                + "C 214 200, 170 210, 128 200 C 104 194, 84 184, 74 170 C 66 160, 63 150, 62 138 Z"
            g.ellipse(262, 204, 40, 21, fill: hex("#E7B3BE"), stroke: hex("#C98A97"), lw: 1.5)                       // cerebellum
            for j in 0..<4 { g.path("M \(228 + Double(j) * 4) \(196 + Double(j) * 5) q 34 -6 68 4", stroke: hex("#C98A97"), lw: 0.8) }
            g.path("M 214 190 C 216 215, 212 240, 206 268", stroke: hex("#E7B3BE"), lw: 18, cap: .round)              // brainstem
            g.path(cortex, fill: hex("#F4C6CF"), stroke: hex("#C98A97"), lw: 2)
            for d in ["M 90 110 C 110 96, 120 120, 140 104", "M 210 70 C 230 84, 240 70, 262 92", "M 120 76 C 140 64, 150 84, 168 66", "M 230 110 C 250 120, 262 112, 282 130"] {
                g.path(d, stroke: hex("#D29AA6"), lw: 1.5)                                                           // gyri
            }
            g.path("M 104 176 C 140 158, 186 146, 236 132", stroke: hex("#B97A88"), lw: 2.5)                           // lateral fissure
            g.path("M 188 47 C 182 80, 176 110, 170 150", stroke: hex("#B97A88"), lw: 2)                               // central sulcus
            if blocked {
                g.ellipse(178, 140, 78, 50, fill: treated ? hex("#F7DDE2") : hex("#E5B0BB"), opacity: 0.9)
                g.ellipse(178, 140, 78 * core, 50 * core, fill: hex("#8C8C94"))
            }
            // internal carotid rising to the middle cerebral artery, fanning over the side of the brain
            let artery = hex("#C8323C")
            g.path("M 120 280 C 118 250, 116 215, 118 188", stroke: artery, lw: 7, cap: .round)
            g.path("M 118 188 C 140 175, 160 168, 178 162", stroke: artery, lw: 6, cap: .round)
            let branches = ["M 178 162 C 170 130, 150 100, 130 78", "M 178 162 C 185 128, 196 100, 205 70", "M 178 162 C 205 145, 240 125, 268 110",
                            "M 178 162 C 210 162, 240 160, 262 168", "M 178 162 C 160 172, 145 182, 132 188"]
            for (i, d) in branches.enumerated() {
                g.path(d, stroke: artery, lw: 4, opacity: blocked && i < 4 && !treated ? 0.3 : 1, cap: .round)
            }
            if blocked { g.circle(150, 171, 9, fill: treated ? hex("#9AA3AE") : hex("#5A1420"), stroke: .white, lw: 1.5) }
            for i in 0..<5 {
                let u = (t * 0.5 + Double(i) / 5).wrap(1)
                if blocked && !treated && u > 0.55 { continue }
                g.circle(120 - 2 * u, 280 - u * 92, 3.5, fill: .white, opacity: 0.9)
            }
        }
        let clotAt = bp(150, 171)
        if blocked {
            s.line(clotAt.x, clotAt.y + 6, clotAt.x - 12, clotAt.y + 34, stroke: ink, lw: 0.8)
            s.label(treated ? "clot removed" : "clot", treated ? "血栓已清除" : "血栓", clotAt.x - 14, clotAt.y + 44, size: 9, color: hex("#5A1420"), anchor: .middle, bold: true)
        }
        s.label("brain, left side", "大脑左侧面", bp(180, 45).x, 58, size: 9, color: hex("#8A3B45"), anchor: .middle, bold: true)
        s.label("artery", "动脉", bp(126, 268).x + 8, bp(126, 268).y + 4, size: 8, color: hex("#C8323C"))
        if blocked {
            s.rect(214, 246, 9, 9, fill: hex("#8C8C94")); s.label("dead", "坏死区", 227, 254, size: 9, color: ink)
            s.rect(270, 246, 9, 9, fill: hex("#E5B0BB")); s.label("at risk", "半暗带", 283, 254, size: 9, color: ink)
            s.label("left brain → right face & arm, speech", "左脑受损 → 右侧面部手臂、语言", 196, 274, size: 8, color: ink)
        }

        // status with a clock
        s.rect(8, 6, 344, 36, r: 8, fill: .white, stroke: core > 0.3 ? red : hex("#DDDDDD"), lw: 2)
        minuteClock(&s, CGPoint(x: 26, y: 24), 13, p[v: "minutes"], blocked ? red : hex("#999999"))
        if blocked {
            let mins = Int(min(p[v: "minutes"], treated ? 60 : 360).rounded()), lost = Double(mins) * 1.9
            s.label("\(mins) min without blood · ≈ \(Int(lost.rounded())) million brain cells lost",
                    "缺血 \(mins) 分钟 · 约 \(Int(lost.rounded())) 百万脑细胞死亡", 46, 21, size: 10, color: red, bold: true)
            s.label(treated ? "Clot cleared at 60 min — the at-risk area is saved" : "every minute counts — call 120, note the time",
                    treated ? "60 分钟内开通——半暗带得救" : "分秒必争——拨打 120，记下发病时间", 46, 35, size: 9, color: ink)
        } else {
            s.label("Normal blood supply — arteries feed every part of the brain", "供血正常——动脉为大脑各处供血", 46, 28, size: 10, color: ink)
        }
    }

    static func necrosis(_ p: Params) -> Double {
        guard p[v: "clot"] >= 0.5 else { return 0 }
        let m = p[v: "opened"] > 0.5 ? min(p[v: "minutes"], 90) : p[v: "minutes"]
        return m < 20 ? 0 : 1 - exp(-(m - 20) / 140)
    }

    static let heartAttack = Scenario(
        id: "heart-attack", group: .illness, title: Bilingual("Heart attack", "心肌梗死"),
        params: ["clot": 0, "minutes": 0, "opened": 0, "signs": 0, "female": 0, "senior": 0],
        steps: [
            .watch("Coronary arteries on the heart’s surface feed the heart muscle itself.", "心脏表面的冠状动脉为心肌自身供血。",
                   set: ["clot": 0, "minutes": 0, "opened": 0, "signs": 0]),
            .watch("A plaque cracks and a clot blocks the artery — the muscle below loses its blood. It hurts: a heavy, crushing chest pain.",
                   "斑块破裂，血栓堵塞冠状动脉——下游心肌失去血供。胸口出现沉重的压榨样疼痛。", set: ["clot": 1, "minutes": 10]),
            .tryIt("Drag the clock: muscle starts dying after ~20 min and keeps dying for hours.", "试一试：拖动时间：约 20 分钟后心肌开始坏死，并持续数小时。",
                   TryStep(mode: .scrub([Scrub(param: "minutes", label: "Minutes 分钟", min: 0, max: 360, digits: 0)]), success: { $0[v: "minutes"] >= 180 },
                           ok: Bilingual("Time is muscle — lost heart muscle doesn’t grow back.", "时间就是心肌——坏死心肌无法再生。"), demo: ["minutes": 240])),
            .watch("Signs: chest pressure over 15 min, spreading to the left arm, jaw or back; cold sweat, breathless, sick. Call 120 — don’t drive yourself. Chew aspirin if told to.",
                   "信号：胸口压迫感超过 15 分钟，放射至左臂、下颌或后背；冷汗、气短、恶心。拨打 120，不要自己开车；遵医嘱嚼服阿司匹林。", set: ["signs": 1]),
            .tryIt("Compare: artery reopened with a stent within 90 min vs. left blocked.", "对比：90 分钟内支架开通血管 vs. 持续堵塞。", set: ["minutes": 300, "signs": 0],
                   TryStep(mode: .compare(param: "opened", options: [("Blocked 未开通", 0), ("Stent at 90 min 支架", 1)]), success: { $0[v: "opened"] > 0.5 },
                           ok: Bilingual("Opening the artery early saves most of the muscle.", "尽早开通血管可挽救大部分心肌。"), demo: ["opened": 1])),
        ],
        draw: { s, p, t in drawHeartAttack(&s, p, t) },
        sources: ["Reimer & Jennings wavefront of necrosis; AHA/ESC STEMI: door-to-balloon ≤ 90 min"]
    )

    @MainActor private static func drawHeartAttack(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let dead = necrosis(p), clot = p[v: "clot"] > 0.5, opened = p[v: "opened"] > 0.5
        let blocked = clot && !opened, pain = blocked ? 1.0 : clot ? 0.3 : 0
        let female = p[v: "female"] > 0.5, silent = p[v: "senior"] > 0.5 && !female
        let red = hex("#D8434B"), ink = hex("#555555"), signs = p[v: "signs"]

        // the person: hand pressed to the chest, pain spreading to the left arm and jaw
        let neck = CGPoint(x: 97, y: 132)
        var person = FacingPerson(h: 200, face: pain > 0.5 ? .pain : .calm, sweat: pain > 0.5, legs: true)
        person.head = 1.25
        if female { person.longHair = true; person.shirt = hex("#E8B4C8"); person.shirtLine = hex("#B77A95") }
        if p[v: "senior"] > 0.5 { person.hair = hex("#BDBDBD") }
        if pain > 0.5 && !silent {
            person.rightHand = CGPoint(x: 2, y: 0.12 * person.h)
            person.leftHand = CGPoint(x: 10, y: 0.16 * person.h)
        } else if pain > 0.5 {
            person.rightHand = CGPoint(x: -0.1 * person.h, y: 0.38 * person.h)
            person.leftHand = CGPoint(x: 0.03 * person.h, y: 0.02 * person.h)
        }
        s.line(0, 298, 184, 298, stroke: hex("#BBBBBB"), lw: 2)
        person.drawBody(&s, at: neck)
        let throb = 0.75 + 0.25 * sin(t * 5)
        if pain > 0.5 {
            // pain map
            let chest = CGPoint(x: neck.x + 2, y: neck.y + 0.13 * person.h)
            let chestR = silent ? 0 : female ? 12.0 : 20
            for k in 0..<3 where chestR > 0 { s.circle(chest.x, chest.y, chestR * (1 - Double(k) * 0.3) * (0.9 + 0.1 * throb), fill: red, opacity: 0.22) }
            if !silent {
                let sh = person.shoulderPoint(1), el = person.arm(1).elbow
                s.line(neck.x + sh.x, neck.y + sh.y, neck.x + el.x, neck.y + el.y, stroke: red, lw: 14, cap: .round, opacity: 0.25 * throb)
            }
            s.ellipse(neck.x, neck.y + person.chin.y - 3, 12, 6, fill: red, opacity: 0.25 * throb)
        }
        person.drawArms(&s, at: neck)
        let head = CGPoint(x: neck.x, y: neck.y + person.headCenter.y)
        if signs > 0.05 {
            s.group(opacity: signs) { g in
                // (en, zh, feature, label y, left column?)
                var rows: [(String, String, CGPoint, Double, Bool)] = []
                if silent {
                    rows = [("confused", "意识混乱", CGPoint(x: head.x - 14, y: head.y - 8), 96, true),
                            ("breathless", "气短", CGPoint(x: head.x + 8, y: head.y + 22), 128, false),
                            ("little or no pain", "可能不痛", CGPoint(x: neck.x + 14, y: neck.y + 26), 156, false)]
                } else {
                    rows = [("cold sweat", "冷汗", CGPoint(x: head.x - 16, y: head.y - 6), 96, true),
                            ("jaw", "下颌", CGPoint(x: head.x + 10, y: head.y + 24), 128, false),
                            ("crushing chest", "胸口压榨感", CGPoint(x: neck.x + 18, y: neck.y + 26), 152, false),
                            ("left arm", "左臂", CGPoint(x: neck.x + 36, y: neck.y + 34), 176, false)]
                    if female { rows += [("breathless,", "气短、恶心", CGPoint(x: neck.x - 16, y: neck.y + 60), 214, true), ("sick, back", "背痛", .zero, 226, true)] }
                }
                for r in rows {
                    let x = r.4 ? 56.0 : 145
                    if r.2 != .zero { g.line(r.2.x, r.2.y, x + (r.4 ? 2 : -2), r.3 - 3, stroke: red, lw: 0.8) }
                    g.label(r.0, r.1, x, r.3, size: 9, color: red, anchor: r.4 ? .end : .start, bold: true)
                }
                g.rect(10, 50, 60, 22, r: 6, fill: red)
                g.text("☎ 120", 40, 65, size: 12, color: .white, anchor: .middle, bold: true)
            }
        }

        // the heart, front view
        let beat = 1 + 0.025 * pow(max(0, sin(t * 7.5)), 4)
        let k = 0.6, o = CGPoint(x: 214 - 84 * k, y: 56 - 7 * k)
        func hp(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: o.x + x * k, y: o.y + y * k) }
        s.group(translate: o, scale: k) { root in
            root.group(translate: CGPoint(x: 185 * (1 - beat), y: 165 * (1 - beat)), scale: beat) { g in
                g.path("M 118 112 L 118 40", stroke: hex("#5A6FB0"), lw: 22, cap: .round)                        // superior vena cava
                g.path("M 150 110 C 148 70, 150 45, 175 38 C 200 32, 222 42, 226 62 L 226 95", stroke: hex("#C8323C"), lw: 24, cap: .round) // aorta
                for (x, y) in [(165.0, 38.0), (183, 33), (201, 35)] { g.line(x, y, x - 4, y - 26, stroke: hex("#C8323C"), lw: 8, cap: .round) }
                g.path("M 188 118 C 190 95, 200 80, 215 72 L 250 66", stroke: hex("#5A6FB0"), lw: 20, cap: .round)   // pulmonary trunk
                g.path("M 112 108 C 88 120, 84 175, 110 205 C 120 214, 132 214, 140 205 C 130 175, 132 135, 142 112 Z", fill: hex("#B8364A"), stroke: hex("#7A1F2B"), lw: 2)
                g.path("M 140 112 C 132 140, 130 180, 140 205 C 170 240, 215 262, 255 258 C 240 225, 222 170, 206 120 C 185 108, 160 106, 140 112 Z",
                       fill: hex("#C8323C"), stroke: hex("#7A1F2B"), lw: 2)
                g.path("M 206 120 C 222 170, 240 225, 255 258 C 285 250, 296 220, 290 185 C 282 145, 258 118, 230 108 C 222 110, 212 114, 206 120 Z",
                       fill: hex("#B02A38"), stroke: hex("#7A1F2B"), lw: 2)
                g.path("M 226 100 C 245 92, 262 100, 262 112 C 250 118, 238 116, 230 110 Z", fill: hex("#A8283A"), stroke: hex("#7A1F2B"), lw: 1.5)
                if clot {
                    // territory of the LAD: front wall of the left ventricle and the apex
                    let zone = "M 208 135 C 222 175, 238 225, 255 258 C 280 250, 290 222, 285 190 C 272 170, 245 150, 208 135 Z"
                    g.path(zone, fill: hex("#E88A94"))
                    g.path(zone, fill: hex("#6E6E78"), opacity: dead)
                }
                let coronary = hex("#F2D060")
                g.path("M 150 118 C 132 128, 124 160, 128 190 C 132 205, 140 214, 150 222", stroke: coronary, lw: 6, cap: .round)
                g.path("M 182 112 C 196 116, 204 118, 208 124", stroke: coronary, lw: 7, cap: .round)
                g.path("M 208 124 C 220 165, 236 215, 252 252", stroke: coronary, lw: 6, cap: .round)
                g.path("M 216 150 C 235 158, 250 172, 262 190", stroke: coronary, lw: 4, cap: .round)
                g.path("M 208 124 C 232 114, 256 122, 276 150", stroke: coronary, lw: 5, cap: .round)
                for i in 0..<4 {
                    let u = (t * 0.4 + Double(i) / 4).wrap(1)
                    if blocked && u > 0.22 { continue }
                    let a = pow(1 - u, 3), b = 3 * u * pow(1 - u, 2), c = 3 * u * u * (1 - u), d = pow(u, 3)
                    g.circle(a * 208 + b * 220 + c * 236 + d * 252, a * 124 + b * 165 + c * 215 + d * 252, 3.5, fill: .white)
                }
                if clot { g.circle(213, 140, 9, fill: opened ? hex("#9AA3AE") : hex("#3D0B12"), stroke: .white, lw: 1.5) }
            }
        }
        let c = hp(213, 140)
        if clot {
            s.line(c.x + 5, c.y - 3, 300, 70, stroke: ink, lw: 0.8)
            s.label(opened ? "stent" : "clot", opened ? "支架" : "血栓", 302, 72, size: 10, color: hex("#5A1420"), bold: true)
            let lv = hp(262, 225)
            s.line(lv.x, lv.y, 330, 214, stroke: ink, lw: 0.8)
            s.label(dead > 0.2 ? "dying muscle" : "starved muscle", dead > 0.2 ? "心肌坏死" : "心肌缺血", 352, 224, size: 9, color: red, anchor: .end, bold: true)
        }
        s.label("LAD", "前降支", hp(222, 200).x, hp(222, 200).y, size: 9, color: .white, anchor: .end, bold: true)
        s.label("heart, front view", "心脏正面", 262, 244, size: 9, color: hex("#8A3B45"), anchor: .middle, bold: true)

        // status with a clock
        s.rect(8, 6, 344, 36, r: 8, fill: .white, stroke: dead > 0.3 ? red : hex("#DDDDDD"), lw: 2)
        minuteClock(&s, CGPoint(x: 26, y: 24), 13, p[v: "minutes"], clot ? red : hex("#999999"))
        if clot {
            s.label("\(Int(p[v: "minutes"].rounded())) min · heart muscle lost \(Int((dead * 100).rounded()))%",
                    "\(Int(p[v: "minutes"].rounded())) 分钟 · 心肌坏死 \(Int((dead * 100).rounded()))%", 46, 21, size: 11, color: red, bold: true)
            s.label(opened ? "artery reopened — blood flows again" : "time is muscle — call 120 now", opened ? "血管已开通——恢复供血" : "时间就是心肌——立即拨打 120",
                    46, 35, size: 9, color: ink)
        } else {
            s.label("Normal supply — coronary arteries feed the heart muscle", "供血正常——冠状动脉滋养心肌", 46, 28, size: 10, color: ink)
        }
    }
}
