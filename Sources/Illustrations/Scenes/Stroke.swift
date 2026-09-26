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
        case .infant, .toddler, .child:
            s.profileNote = Bilingual("Rare in children, but real: sudden weakness on one side, a seizure, or the worst headache — call 120, don't wait.",
                                      "儿童少见但会发生：突然一侧无力、抽搐或剧烈头痛——立即拨打 120，不要等待。")
            return s.rebased(["kid": 1])
        case .adult where p.isPregnant:
            s.profileNote = Bilingual("Pregnancy and the 6 weeks after birth raise stroke risk. Severe headache, vision changes or very high blood pressure → call 120.",
                                      "孕期及产后 6 周中风风险升高。剧烈头痛、视物异常或血压很高 → 拨打 120。")
            return s.rebased(["pregnant": 1])
        case .adult: break
        }
        return s
    }

    /// round letter badge for F.A.S.T. / 中风120
    @MainActor static func badge(_ s: inout Sketch, _ x: Double, _ y: Double, _ letter: String, _ color: Color) {
        s.circle(x, y + 1, 8.5, fill: .black, opacity: 0.12)
        s.circle(x, y, 8.5, fill: color, stroke: .white, lw: 1.5)
        s.text(letter, x, y + 3.8, size: 10, color: .white, anchor: .middle, bold: true)
    }

    /// the person for the stroke and heart-attack scenes (adult men in a blue shirt)
    static func patient(_ p: Params, female: Bool = false, h: Double = 240) -> Bust {
        let kid = p[v: "kid"] > 0.5, senior = p[v: "senior"] > 0.5, pregnant = p[v: "pregnant"] > 0.5
        let c = Casualty(Profile(age: kid ? .child : senior ? .senior : .adult, female: female || pregnant, pregnant: pregnant), adult: h)
        var b = Bust(c)
        b.h = kid ? h * 0.94 : h
        b.head *= 1.15
        if !kid && !senior && !female && !pregnant { b.look.top = hex("#8FB3E0"); b.look.topLine = hex("#5F87B8") }
        b.waist = 0.62
        return b
    }

    /// person in a round backdrop: body cut off by the circle, arms free; `between` draws over the body, under the arms
    @MainActor static func portrait(_ s: inout Sketch, _ person: Bust, at o: CGPoint, between: (inout Sketch) -> Void = { _ in }) {
        let c = CGPoint(x: o.x, y: o.y + 0.22 * person.h), r = 0.35 * person.h
        s.circle(c.x, c.y, r, fill: hex("#F2ECE3"))
        var clip = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        clip.addRect(CGRect(x: c.x - r, y: 0, width: 2 * r, height: c.y))
        var inside = s.clipped(to: clip)
        person.drawBody(&inside, at: o)
        between(&s)
        person.drawArms(&s, at: o)
    }

    /// status strip across the top: stopwatch, headline, detail
    @MainActor static func timeCard(_ s: inout Sketch, minutes: Double, alarm: Bool, _ head: (String, String), _ sub: (String, String), color: Color) {
        s.card(8, 6, 344, 42, accent: alarm ? color : nil)
        s.stopwatch(CGPoint(x: 30, y: 28), 12, minutes: alarm ? minutes : 0, color: alarm ? color : Tone.faint)
        s.label(head.0, head.1, 50, 24, size: 10.5, color: alarm ? color : Tone.ink, bold: true)
        s.label(sub.0, sub.1, 50, 38, size: 8, color: Tone.sub)
    }

    @MainActor private static func drawStroke(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let core = strokeCore(p), blocked = p[v: "clot"] > 0.5, treated = p[v: "treated"] > 0.5, fast = p[v: "fast"]
        let minutes = min(p[v: "minutes"], treated ? 60 : 360)
        let weak = blocked ? (treated ? 0.2 : min(1, 0.6 + p[v: "minutes"] / 60)) : 0

        // status
        if blocked {
            let lost = minutes * 1.9
            let head = (lost >= 1000 ? String(format: "%.0f min without blood · ≈ %.1f billion brain cells lost", minutes, lost / 1000)
                            : String(format: "%.0f min without blood · ≈ %.0f million brain cells lost", minutes, lost),
                        lost >= 100 ? String(format: "缺血 %.0f 分钟 · 约 %.1f 亿脑细胞死亡", minutes, lost / 100)
                            : String(format: "缺血 %.0f 分钟 · 约 %.0f 万脑细胞死亡", minutes, lost * 100))
            timeCard(&s, minutes: minutes, alarm: true, head,
                     treated ? ("Clot cleared within the hour — the at-risk area is saved", "1 小时内开通血管——半暗带得救")
                         : ("Every minute counts — call 120 and note the time it started", "分秒必争——拨打 120，记下发病时间"), color: Tone.red)
        } else {
            timeCard(&s, minutes: 0, alarm: false, ("Normal blood supply", "供血正常"),
                     ("Arteries feed every part of the brain with oxygen", "动脉为大脑各处输送氧气"), color: Tone.red)
        }

        // the person: right side of the face droops, right arm drifts down (image left = the person's right)
        var person = patient(p)
        person.face = blocked && !treated ? .worried : .calm
        person.droop = weak
        let o = CGPoint(x: 92, y: 136)
        let armY = 0.2 * person.h, reach = 0.35 * person.h
        person.leftHand = CGPoint(x: reach, y: armY)
        person.rightHand = CGPoint(x: -reach + weak * 0.12 * person.h, y: armY + weak * 0.12 * person.h)
        portrait(&s, person, at: o)
        let head = CGPoint(x: o.x, y: o.y + person.headCenter.y)
        let hand = CGPoint(x: o.x + person.rightHand!.x, y: o.y + person.rightHand!.y)
        if blocked {
            s.bubble(treated ? "I feel better now" : "I… c-can’t… say it", treated ? "我好多了" : "我…说…不…清", 96, 70, tip: CGPoint(x: o.x + 6, y: head.y - person.headRy - 2),
                     size: 8.5, color: treated ? Tone.ink : Tone.red, border: treated ? Tone.faint : Tone.red)
            if weak > 0.5 {
                s.pointer(CGPoint(x: hand.x - 2, y: hand.y - 44), CGPoint(x: hand.x - 2, y: hand.y - 16), color: Tone.red, lw: 1.5)
            }
        }
        if fast > 0.05 {
            s.group(opacity: fast) { g in
                let en = ["F", "A", "S", "T"], zh = ["1", "2", "0", "☎"]
                let spots = [CGPoint(x: head.x - person.headRx - 14, y: head.y + 4), CGPoint(x: hand.x + 2, y: hand.y + 18),
                             CGPoint(x: 160, y: 70), CGPoint(x: 18, y: 280)]
                for i in 0..<4 { badge(&g, spots[i].x, spots[i].y, g.zh ? zh[i] : en[i], Tone.red) }
                g.label("face", "看脸", spots[0].x - 10, spots[0].y + 3, size: 7.5, color: Tone.red, anchor: .end, bold: true)
                g.label("arm", "查臂", spots[1].x + 12, spots[1].y + 3, size: 7.5, color: Tone.red, bold: true)
                g.label("speech", "听语言", spots[2].x + 12, spots[2].y + 3, size: 7.5, color: Tone.red, bold: true)
                g.callChip(30, 270)
            }
        }

        // brain, left side view (front to the left): the left brain runs the right body
        let k = 0.74, bo = CGPoint(x: 186, y: 66)
        func bp(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: bo.x + x * k, y: bo.y + y * k) }
        s.group(translate: bo, scale: k) { g in
            g.brainSide(penumbra: blocked ? (treated ? 0.55 : 1) : 0, core: blocked ? core : 0, clot: blocked, cleared: treated, t: t)
        }
        s.caption("Left side of the brain", "大脑左侧面", bp(110, 0).x, 60, anchor: .middle)
        if !blocked {
            s.tag("frontal", "额叶", bp(40, 44).x, bp(40, 44).y, size: 7, color: Tone.label, bold: true)
            s.tag("parietal", "顶叶", bp(150, 30).x, bp(150, 30).y, size: 7, color: Tone.label, bold: true)
            s.tag("temporal", "颞叶", bp(104, 124).x, bp(104, 124).y, size: 7, color: Tone.label, bold: true)
            s.tag("occipital", "枕叶", bp(196, 96).x, bp(196, 96).y, size: 7, color: Tone.label, bold: true)
        }
        s.callout("cerebellum", "小脑", at: bp(186, 138), 352, bp(186, 138).y + 18, anchor: .end, color: Tone.label, size: 7.5)
        s.callout(blocked ? (treated ? "artery reopened" : "clot") : "carotid → middle cerebral artery",
                  blocked ? (treated ? "血管已开通" : "血栓") : "颈动脉 → 大脑中动脉",
                  at: blocked ? bp(66, 116) : bp(57, 160), 190, bp(58, 176).y + 12, color: blocked && !treated ? hex("#5A1420") : Tone.artery, size: 8)

        // legend
        if blocked {
            s.rect(190, 256, 9, 9, r: 2, fill: hex("#7C7480")); s.label("dead core", "坏死区", 203, 264, size: 8, color: Tone.sub)
            s.rect(262, 256, 9, 9, r: 2, fill: hex("#E26A78"), opacity: 0.7); s.label("at risk, savable", "半暗带（可挽救）", 275, 264, size: 8, color: Tone.sub)
        }
        s.label("Left brain → right body & speech", "左脑 → 右侧身体与语言", 190, 284, size: 8, color: Tone.sub, bold: true)
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
        let blocked = clot && !opened, pain = blocked ? 1.0 : 0
        let female = p[v: "female"] > 0.5, silent = p[v: "senior"] > 0.5 && !female
        let signs = p[v: "signs"]

        // status
        if clot {
            let m = opened ? min(p[v: "minutes"], 90) : p[v: "minutes"]
            timeCard(&s, minutes: m, alarm: true,
                     dead < 0.005 ? (String(format: "%.0f min blocked · the muscle is starving", m), String(format: "堵塞 %.0f 分钟 · 心肌缺血中", m))
                         : (String(format: "%.0f min blocked · %.0f%% of the starved muscle lost", m, dead * 100), String(format: "堵塞 %.0f 分钟 · 缺血心肌坏死 %.0f%%", m, dead * 100)),
                     opened ? ("Stent opened the artery — blood flows again", "支架开通血管——恢复供血") : ("Time is muscle — call 120 now", "时间就是心肌——立即拨打 120"), color: Tone.red)
        } else {
            timeCard(&s, minutes: 0, alarm: false, ("Normal supply", "供血正常"), ("Coronary arteries on its surface feed the heart muscle", "心脏表面的冠状动脉滋养心肌"), color: Tone.red)
        }

        // the person: fist pressed to the chest, pain spreading to the left arm and jaw
        var person = patient(p, female: female)
        person.face = pain > 0.5 ? (silent ? .worried : .pain) : .calm
        person.sweat = pain > 0.5 && signs > 0.5
        let o = CGPoint(x: 88, y: 136)
        if pain > 0.5 && !silent {
            person.rightHand = CGPoint(x: 0.015 * person.h, y: 0.12 * person.h)
            person.rightFist = true
            person.leftHand = CGPoint(x: 0.1 * person.h, y: 0.33 * person.h)
        }

        let throb = 0.75 + 0.25 * sin(t * 5)
        portrait(&s, person, at: o) { g in
            guard pain > 0.5 else { return }
            let chest = CGPoint(x: o.x + 0.01 * person.h, y: o.y + 0.13 * person.h)
            if !silent { g.glow(chest.x, chest.y, (female ? 22 : 30) * (0.9 + 0.1 * throb), Tone.red, opacity: 0.6) }
            if !silent || signs > 0.5 {
                let sh = person.shoulder(1), el = person.arm(1).elbow
                g.line(o.x + sh.x, o.y + sh.y, o.x + el.x, o.y + el.y, stroke: Tone.red, lw: 14, cap: .round, opacity: 0.2 * throb)
                g.glow(o.x, o.y + person.chin.y - 2, 16, Tone.red, opacity: 0.45 * throb)
            }
        }
        let head = CGPoint(x: o.x, y: o.y + person.headCenter.y)
        if signs > 0.05 {
            s.group(opacity: signs) { g in
                var rows: [(String, String, CGPoint, Double, Bool)] = []
                if silent {
                    rows = [("confused", "意识混乱", CGPoint(x: head.x - person.headRx * 0.7, y: head.y - 6), 92, true),
                            ("breathless", "气短", CGPoint(x: o.x + 4, y: o.y + person.mouth.y), 104, false),
                            ("little or no pain", "可能不痛", CGPoint(x: o.x + 14, y: o.y + 0.13 * person.h), 150, false)]
                } else {
                    rows = [("cold sweat", "冷汗", CGPoint(x: head.x - person.headRx * 0.8, y: head.y - 4), 92, true),
                            ("jaw", "下颌", CGPoint(x: o.x + 6, y: o.y + person.chin.y - 2), 104, false),
                            ("crushing chest", "胸口压榨感", CGPoint(x: o.x + 16, y: o.y + 0.12 * person.h), 150, false),
                            ("left arm", "左臂", CGPoint(x: o.x + person.arm(1).elbow.x, y: o.y + person.arm(1).elbow.y), 186, false)]
                    if female { rows += [("breathless, sick", "气短、恶心", .zero, 204, false), ("back pain", "背痛", .zero, 216, false)] }
                }
                for r in rows {
                    let x = r.4 ? 6.0 : 144
                    if r.2 != .zero {
                        g.callout(r.0, r.1, at: r.2, x, r.3, anchor: .start, color: Tone.red, size: 8)
                    } else {
                        g.label(r.0, r.1, x, r.3, size: 8, color: Tone.red, bold: true)
                    }
                }
                g.callChip(8, 268)
                g.label("don’t drive yourself", "不要自己开车", 72, 282, size: 7.5, color: Tone.red, bold: true)
            }
        }

        // the heart, front view
        let beat = 1 + 0.02 * pow(max(0, sin(t * 7.5)), 4)
        let k = 0.68 * beat, ho = CGPoint(x: 192, y: 66)
        func hp(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: ho.x + x * k, y: ho.y + y * k) }
        s.group(translate: ho, scale: k) { g in
            g.heartFront(zone: clot ? 1 : 0, dead: dead, clot: clot, stent: opened, flow: 1, t: t)
        }
        s.caption("Heart, front view", "心脏正面", 196, 57)
        if !clot {
            s.callout("aorta", "主动脉", at: hp(150, 30), 352, hp(150, 30).y - 4, anchor: .end, color: Tone.label, size: 7.5)
            s.callout("right coronary", "右冠状动脉", at: hp(62, 172), 198, 228, color: hex("#9A6A1B"), size: 7.5)
            s.callout("LAD artery", "前降支", at: hp(140, 190), 234, 248, color: hex("#9A6A1B"), size: 7.5)
            s.label("right\nventricle", "右心室", hp(98, 150).x, hp(98, 150).y, size: 7, color: .white, anchor: .middle, bold: true)
            s.callout("left ventricle", "左心室", at: hp(170, 150), 352, 222, anchor: .end, color: Tone.organLine, size: 7.5)
        } else {
            let c = hp(123, 106)
            s.line(c.x + 5, c.y - 3, c.x + 14, c.y - 12, stroke: hex("#5A1420"), lw: 0.8)
            s.pill(opened ? "stent" : "clot", opened ? "支架" : "血栓", c.x + 12, c.y - 16, color: hex("#5A1420"), size: 8)
            let zoneText: (String, String) = opened ? ("part saved, part scarred", "部分挽救，部分坏死") : dead > 0.2 ? ("dying muscle", "心肌坏死") : ("starved muscle", "心肌缺血")
            s.callout(zoneText.0, zoneText.1, at: hp(160, 170), 352, 250, anchor: .end, color: opened ? Tone.amber : Tone.red, size: 8)
        }
    }
}
