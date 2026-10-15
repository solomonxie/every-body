import SwiftUI

extension Illustrations {
    /// Overview of first aid for little ones; each skill links on to its own page, drawn for the chosen age.
    static func childFirstAid(for who: Profile) -> Scenario {
        let child = who.age.isChild ? 1.0 : 0
        var s = Scenario(
            id: "child-first-aid", group: .children, title: Bilingual("Baby & child first aid", "婴幼儿急救"),
            warning: Bilingual("A summary, not a course — it doesn’t replace a doctor or hands-on training.",
                               "这是要点总结，不是急救课程，不能代替医生和实操培训。"),
            params: ["mode": 0, "child": child, "minutes": 20],
            steps: [
                .watch("Call 911 now if a child isn’t breathing normally or won’t wake, is choking and can’t cough or cry, has a fit over 5 minutes, bleeds heavily, is badly burned, swallowed a button battery, magnets or poison, or is drowsy or vomiting after a head injury.",
                       "孩子出现以下情况立即拨打 120：呼吸不正常或叫不醒、噎住且咳不出哭不出、抽搐超过 5 分钟、大出血、严重烧烫伤、吞下纽扣电池、磁铁或毒物、头部受伤后嗜睡或呕吐。",
                       set: ["mode": 0, "child": child]),
                .tryIt("CPR for a baby (under 1) and for a child differs from an adult’s, and from each other. Switch between them.",
                       "试一试：婴儿（1 岁以下）和儿童的心肺复苏与成人不同，两者之间也不同。切换对比。",
                       set: ["mode": 1],
                       TryStep(mode: .compare(param: "child", options: [("Baby 婴儿", 0), ("Child 儿童", 1)]), success: { _ in true },
                               ok: Bilingual("Both: 30 pushes to 2 breaths, 100–120 a minute. Alone? 2 minutes of CPR, then call. (UK and European courses start with 5 rescue breaths.)",
                                             "两者都是：按压 30 次、吹气 2 次，每分钟 100–120 次。独自一人：先做 2 分钟心肺复苏再呼救。（英国和欧洲的课程会先吹气 5 次。）"))),
                .watch("Choking: if they can cough or cry, let them cough. If not — baby: 5 back blows face down, then 5 chest thrusts. Child: 5 back blows, then 5 tummy thrusts. Never tummy thrusts on a baby; no blind finger sweeps.",
                       "气道异物：能咳嗽或哭，就让其用力咳。不能——婴儿：面朝下拍背 5 次，再胸部按压 5 次；儿童：拍背 5 次，再腹部冲击 5 次。婴儿禁做腹部冲击；不要盲目用手指抠。",
                       set: ["mode": 2]),
                .watch("Burns: cool running water for 20 minutes, take off nearby clothes and jewellery, cover loosely with cling film, keep them warm. No ice, butter or creams. Under 5: get any burn checked.",
                       "烧烫伤：流动的凉水冲 20 分钟，脱掉周围的衣物和首饰，用保鲜膜松松覆盖，注意保暖。不要用冰、黄油或药膏。5 岁以下：任何烫伤都要看医生。",
                       set: ["mode": 3, "minutes": 20]),
                .watch("Swallowed a button battery or magnets? Hospital now, even if they seem fine. Poison or medicine: don’t make them sick — call 911 or Poison Help and bring the packet.",
                       "吞下纽扣电池或磁铁？即使看起来没事，也要立即去医院。误服毒物或药物：不要催吐——拨打 120，带上包装。",
                       set: ["mode": 4]),
                .watch("Learn it before you need it: take a baby and child first-aid course, and practise each skill on the pages linked above — drawn for your child’s age.",
                       "提前学会：参加婴幼儿急救课程，并在上方链接的页面逐项练习——按你孩子的年龄绘制。",
                       set: ["mode": 5]),
            ],
            draw: { s, p, t in drawChildFirstAid(&s, p, t) },
            sources: ["AHA 2025 Pediatric BLS: 30:2 single rescuer, 100–120/min, depth about 4 cm (infant) and 5 cm (child), two-thumb technique; alone and unwitnessed: 2 min of CPR, then call",
                      "ERC 2025 Paediatric BLS / Resuscitation Council UK: 5 initial rescue breaths; infant choking: 5 back blows, 5 chest thrusts, no abdominal thrusts under 1; no blind finger sweeps",
                      "NHS & British Burn Association: cool burns under running water for 20 minutes, cover with cling film; medical help for any burn in children under 5",
                      "NHS: Button batteries and magnets — go to A&E straight away; AAP HealthyChildren.org: button battery ingestion is an emergency",
                      "NHS: Head injury and concussion — call 999 or go to A&E signs",
                      "Red Cross / St John Ambulance: baby and child first aid"],
            keywords: ["first aid", "baby cpr", "child cpr", "infant cpr", "choking", "burn", "scald", "button battery", "magnet", "poison", "head injury",
                       "婴儿急救", "儿童急救", "心肺复苏", "噎住", "气道异物", "烫伤", "纽扣电池", "磁铁", "误服", "中毒", "头部受伤"]
        )
        s.related = ["cpr", "choking", "burns", "recovery-position", "severe-bleeding"]
        s.profileNote = switch who.age {
        case .infant: Bilingual("Baby (under 1): two thumbs for CPR, breaths over mouth and nose; for choking, chest thrusts — never tummy thrusts.",
                                "婴儿（1 岁以下）：双拇指按压，吹气包住口鼻；噎住用胸部按压——绝不做腹部冲击。")
        case .toddler, .child: Bilingual("Child (1 to puberty): one hand for CPR (two if big); for choking, tummy thrusts like an adult, but gentler.",
                                         "儿童（1 岁到青春期）：单手按压（大孩子用双手）；噎住用腹部冲击，同成人但力度轻些。")
        default: nil
        }
        return s
    }

    @MainActor private static func drawChildFirstAid(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let mode = p[v: "mode"]
        let panels: [@MainActor (inout Sketch) -> Void] = [
            { aidCallNow(&$0) }, { aidCPR(&$0, p) }, { aidChoking(&$0, p) }, { aidBurns(&$0, p, t) }, { aidSwallowed(&$0) }, { aidPractise(&$0, p) },
        ]
        for (i, draw) in panels.enumerated() {
            let w = panel(mode, i)
            if w > 0.01 { s.group(opacity: w) { g in draw(&g) } }
        }
    }

    // MARK: call now

    @MainActor private static func aidCallNow(_ s: inout Sketch) {
        s.label("Call, or go to hospital, now", "立即呼救或去医院", 8, 22, size: 10, color: Tone.ink, bold: true)
        s.stateChip("Call 911 now", "立即拨打 120", 354, 6, color: Anat.red, anchor: .end)
        let items: [(String, String)] = [
            ("Not breathing normally, or won’t wake → start CPR", "呼吸不正常或叫不醒 → 开始心肺复苏"),
            ("Choking and can’t cough, cry or breathe", "噎住，咳不出、哭不出、无法呼吸"),
            ("Struggling to breathe, or swollen lips and tongue", "呼吸困难，或嘴唇舌头肿胀"),
            ("A fit lasting over 5 minutes", "抽搐超过 5 分钟"),
            ("Bleeding that won’t stop with pressure", "按压也止不住的出血"),
            ("Burn bigger than their palm, or on the face, hands, feet or groin", "烫伤大于孩子手掌，或在脸、手、脚、会阴"),
            ("Swallowed a button battery, magnets or poison", "吞下纽扣电池、磁铁或毒物"),
            ("Drowsy, vomiting or knocked out after a head injury", "头部受伤后嗜睡、呕吐或昏迷"),
        ]
        for (i, it) in items.enumerated() {
            let x = 8 + Double(i % 2) * 176, y = 38 + Double(i / 2) * 64
            s.card(x, y, 168, 56, accent: Anat.red)
            badge(&s, x + 22, y + 28, "\(i + 1)", Anat.red)
            s.noteLeft(it.0, it.1, x + 38, y + 28, width: 124, size: 8.5, color: Tone.ink, bold: true)
        }
    }

    // MARK: CPR, baby vs child

    @MainActor private static func aidCPR(_ s: inout Sketch, _ p: Params) {
        let child = p[v: "child"].clamped(0, 1)
        let rows: [(String, String, String, String)] = [
            ("Tap the foot, call their name", "轻拍足底、呼唤", "Tap the shoulders, shout", "拍双肩、大声呼唤"),
            ("Head level, not tilted back", "头保持水平，不后仰", "Tilt the head, lift the chin", "仰头抬颏"),
            ("Two thumbs, hands round the chest", "双拇指，双手环抱胸廓", "Heel of one hand (two if big)", "单手掌根（大孩子用双手）"),
            ("≈ 4 cm, a third of the chest", "约 4 厘米，胸廓厚度 1/3", "≈ 5 cm, a third of the chest", "约 5 厘米，胸廓厚度 1/3"),
            ("Your mouth over mouth AND nose", "嘴同时包住口鼻", "Pinch the nose, mouth to mouth", "捏鼻，口对口"),
        ]
        for col in 0..<2 {
            let on = col == 0 ? 1 - child : child, x = 8 + Double(col) * 176
            s.group(opacity: 0.4 + 0.6 * on) { g in
                g.chestMap(x, 6, 168, 118, mark: col == 0 ? .thumbs : .oneHand, baby: col == 0,
                           title: col == 0 ? Bilingual("Baby · under 1", "婴儿 · 1 岁以下") : Bilingual("Child · 1 to puberty", "儿童 · 1 岁至青春期"))
                g.card(x, 132, 168, 128, accent: on > 0.5 ? Anat.red : nil)
                for (i, r) in rows.enumerated() {
                    let y = 150 + Double(i) * 23
                    g.circle(x + 14, y, 2.4, fill: Anat.red)
                    g.noteLeft(col == 0 ? r.0 : r.2, col == 0 ? r.1 : r.3, x + 22, y, width: 140, size: 8, color: Tone.ink, bold: on > 0.5)
                }
            }
        }
        s.rect(8, 268, 344, 26, r: 13, fill: hex("#FFF1F1"), stroke: Anat.red, lw: 1)
        s.cardNote("Both: 30 pushes : 2 breaths · 100–120 a minute · alone? 2 min, then call", "都是：按压 30 次 : 吹气 2 次 · 每分钟 100–120 次 · 独自一人先做 2 分钟再呼救",
                   180, 281, width: 336, size: 8, color: Anat.red, bold: true)
    }

    // MARK: choking

    @MainActor private static func aidChoking(_ s: inout Sketch, _ p: Params) {
        let child = p[v: "child"].clamped(0, 1)
        s.rect(8, 6, 344, 26, r: 13, fill: hex("#EAF6EE"), stroke: Anat.green, lw: 1)
        s.cardNote("Can cough or cry? Let them cough — stay close and watch", "能咳嗽或哭？让孩子用力咳——守在旁边观察", 180, 19, width: 336, size: 8.5, color: Anat.green, bold: true)
        let cols: [(String, String, [(String, String)])] = [
            ("Baby · under 1", "婴儿 · 1 岁以下", [("Face down along your forearm, head low", "面朝下趴在你前臂上，头低"), ("Up to 5 back blows", "拍背最多 5 次"),
                                                ("Turn face up: up to 5 chest thrusts", "翻成面朝上：胸部按压最多 5 次"), ("Repeat. Goes limp → 911 + CPR", "重复。失去反应 → 120 + 心肺复苏")]),
            ("Child · 1 and over", "儿童 · 1 岁以上", [("Lean them forward", "让孩子身体前倾"), ("Up to 5 back blows", "拍背最多 5 次"),
                                                ("Up to 5 tummy thrusts, above the navel", "肚脐上方腹部冲击最多 5 次"), ("Repeat. Goes limp → 911 + CPR", "重复。失去反应 → 120 + 心肺复苏")]),
        ]
        for (c, col) in cols.enumerated() {
            let on = c == 0 ? 1 - child : child, x = 8 + Double(c) * 176
            s.group(opacity: 0.4 + 0.6 * on) { g in
                g.card(x, 40, 168, 208, accent: on > 0.5 ? Anat.purple : nil)
                g.label(col.0, col.1, x + 14, 60, size: 10, color: Anat.purple, bold: true)
                for (i, st) in col.2.enumerated() {
                    let y = 90 + Double(i) * 42
                    badge(&g, x + 22, y, "\(i + 1)", Anat.purple)
                    g.noteLeft(st.0, st.1, x + 38, y, width: 124, size: 8.5, color: Tone.ink, bold: on > 0.5)
                }
            }
        }
        callBox(&s, 8, 256, 344, 38, "Never tummy thrusts on a baby · no blind finger sweeps", "婴儿禁做腹部冲击 · 不要盲目用手指抠")
    }

    // MARK: burns

    @MainActor private static func aidBurns(_ s: inout Sketch, _ p: Params, _ t: Double) {
        // tap, running water over a small forearm
        s.card(8, 6, 170, 288)
        let tap = CGPoint(x: 72, y: 46)
        s.rect(tap.x - 40, tap.y - 14, 56, 14, r: 6, fill: hex("#B9C3CC"), stroke: hex("#8C99A6"), lw: 1)
        s.rect(tap.x + 6, tap.y - 4, 16, 18, r: 4, fill: hex("#B9C3CC"), stroke: hex("#8C99A6"), lw: 1)
        let wx = tap.x + 14
        s.rect(wx - 6, tap.y + 14, 12, 100, fill: hex("#9CCBF0"), opacity: 0.6)
        for i in 0..<5 {
            let y = tap.y + 18 + (t * 60 + Double(i) * 20).wrap(100)
            s.line(wx - 2, y, wx - 2, y + 8, stroke: .white, lw: 1.2, cap: .round, opacity: 0.8)
        }
        // forearm under the stream, the burn patch red
        s.path("M 22 168 Q 70 150 132 160 L 138 182 Q 72 178 24 192 Z", fill: hex("#EFC3A2"), stroke: Look.edge(hex("#EFC3A2")), lw: 1)
        s.softGlow(CGPoint(x: wx, y: 166), 18, 9, Anat.red, 0.35)
        for k in 0..<6 {
            let x = wx - 26 + Double(k) * 9
            s.circle(x, 186 + Double(k % 2) * 4, 1.6, fill: hex("#9CCBF0"))
        }
        s.stopwatch(CGPoint(x: 52, y: 236), 22, minutes: p[v: "minutes"], color: Tone.blue)
        s.label("20 min", "20 分钟", 84, 232, size: 14, color: Tone.blue, bold: true)
        s.label("cool running water", "流动凉水", 84, 248, size: 8.5, color: Tone.sub)
        s.label("up to 3 h after", "3 小时内都有效", 84, 262, size: 8, color: Tone.sub)

        let px = 186.0, pw = 168.0
        s.card(px, 6, pw, 130, accent: Anat.green)
        s.caption("Do", "要", px + 14, 22, color: Anat.green)
        let dos: [(String, String)] = [("Cool under running water", "流动凉水冲"), ("Take off clothes and jewellery nearby — not if stuck", "脱掉周围衣物首饰——粘住的不要扯"),
                                       ("Cover loosely with cling film", "保鲜膜松松覆盖"), ("Keep the child warm", "注意给孩子保暖")]
        for (i, d) in dos.enumerated() {
            let y = 42 + Double(i) * 24
            mark(&s, CGPoint(x: px + 20, y: y), ok: true)
            s.noteLeft(d.0, d.1, px + 32, y, width: pw - 38, size: 8, color: Tone.ink)
        }
        s.card(px, 144, pw, 66, accent: Anat.red)
        s.caption("Don’t", "不要", px + 14, 160, color: Anat.red)
        let donts: [(String, String)] = [("Ice, butter, creams, toothpaste", "冰、黄油、药膏、牙膏"), ("Pop blisters", "挑破水疱")]
        for (i, d) in donts.enumerated() {
            let y = 178 + Double(i) * 20
            mark(&s, CGPoint(x: px + 20, y: y), ok: false)
            s.noteLeft(d.0, d.1, px + 32, y, width: pw - 38, size: 8, color: Tone.ink)
        }
        callBox(&s, px, 218, pw, 76, "Hospital: bigger than their palm, on the face, hands, feet or groin, electrical or chemical. Under 5: get any burn checked.",
                "去医院：大于孩子手掌，或在脸、手、脚、会阴，或电击伤、化学伤。5 岁以下：任何烫伤都要看医生。")
    }

    // MARK: swallowed things

    @MainActor private static func aidSwallowed(_ s: inout Sketch) {
        s.stateChip("Hospital now", "立即去医院", 354, 6, color: Anat.red, anchor: .end)
        s.label("Swallowed something", "误吞误服", 8, 22, size: 10, color: Tone.ink, bold: true)
        let rows: [(String, String, String, String)] = [
            ("Button battery", "纽扣电池", "Hospital now, even if they seem fine — it can burn through the food pipe in 2 hours.", "即使看起来没事也立即去医院——2 小时内就可能烧穿食管。"),
            ("Magnets", "磁铁", "More than one, or a magnet and metal: hospital now — they pinch the gut together.", "吞下不止一个，或磁铁加金属：立即去医院——会隔着肠壁吸在一起。"),
            ("Poison or medicine", "毒物或药物", "Don’t make them sick. Call 911 or Poison Help (US 1-800-222-1222). Bring the packet.", "不要催吐。拨打 120，带上包装去医院。"),
        ]
        for (i, r) in rows.enumerated() {
            let y = 38 + Double(i) * 86
            s.card(8, y, 344, 78, accent: Anat.red)
            let c = CGPoint(x: 44, y: y + 39)
            s.circle(c.x, c.y, 24, fill: hex("#FDECEC"))
            swallowIcon(&s, i, c)
            s.label(r.0, r.1, 80, y + 22, size: 10.5, color: Anat.red, bold: true)
            s.noteLeft(r.2, r.3, 80, y + 50, width: 262, size: 8.5, color: Tone.ink)
        }
    }

    @MainActor private static func swallowIcon(_ s: inout Sketch, _ i: Int, _ c: CGPoint) {
        switch i {
        case 0:
            s.circle(c.x, c.y + 2, 14, fill: hex("#9AA3AD"))
            s.circle(c.x, c.y, 14, fill: hex("#C9D0D6"), stroke: hex("#8C96A0"), lw: 1.2)
            s.circle(c.x, c.y, 9, stroke: hex("#AAB3BB"), lw: 1)
            s.text("+", c.x, c.y + 4, size: 12, color: hex("#6E7781"), anchor: .middle, bold: true)
        case 1:
            for dx in [-8.0, 8] {
                s.path("M \(c.x + dx - 6) \(c.y + 10) L \(c.x + dx - 6) \(c.y - 2) A 6 6 0 0 1 \(c.x + dx + 6) \(c.y - 2) L \(c.x + dx + 6) \(c.y + 10) L \(c.x + dx + 2.5) \(c.y + 10) L \(c.x + dx + 2.5) \(c.y - 2) A 2.5 2.5 0 0 0 \(c.x + dx - 2.5) \(c.y - 2) L \(c.x + dx - 2.5) \(c.y + 10) Z",
                       fill: Anat.red)
                s.rect(c.x + dx - 6, c.y + 6, 3.5, 4, fill: hex("#C9D0D6"))
                s.rect(c.x + dx + 2.5, c.y + 6, 3.5, 4, fill: hex("#C9D0D6"))
            }
        default:
            s.rect(c.x - 8, c.y - 8, 16, 22, r: 4, fill: hex("#F2B544"), stroke: hex("#C98E22"), lw: 1)
            s.rect(c.x - 5, c.y - 14, 10, 6, r: 1.5, fill: .white, stroke: hex("#C98E22"), lw: 1)
            s.circle(c.x, c.y + 3, 4.5, fill: .white)
            s.line(c.x - 2.5, c.y + 0.5, c.x + 2.5, c.y + 5.5, stroke: Anat.red, lw: 1.3, cap: .round)
            s.line(c.x + 2.5, c.y + 0.5, c.x - 2.5, c.y + 5.5, stroke: Anat.red, lw: 1.3, cap: .round)
        }
    }

    // MARK: practise

    @MainActor private static func aidPractise(_ s: inout Sketch, _ p: Params) {
        let baby = p[v: "child"] < 0.5
        s.label("Learn it before you need it", "提前学会，用时不慌", 180, 24, size: 12, color: Tone.ink, anchor: .middle, bold: true)
        s.label("Practise each one, drawn for your child’s age", "逐项练习，按孩子年龄绘制", 180, 40, size: 8.5, color: Tone.sub, anchor: .middle)
        let pages: [(String, String, String, String)] = [
            ("CPR", "心肺复苏", baby ? "two thumbs, 4 cm" : "one hand, 5 cm", baby ? "双拇指，4 厘米" : "单手，5 厘米"),
            ("Choking", "气道异物", baby ? "back blows, chest thrusts" : "back blows, tummy thrusts", baby ? "拍背、胸部按压" : "拍背、腹部冲击"),
            ("Burns", "烧烫伤", "20 minutes of cool water", "凉水冲 20 分钟"),
            ("Recovery position", "复原卧位", baby ? "held face down, head low" : "on the side, top knee bent", baby ? "抱成面朝下、头低" : "侧卧，上方膝盖弯曲"),
            ("Severe bleeding", "大出血", "press hard, keep pressing", "用力按住，不要松开"),
        ]
        for (i, pg) in pages.enumerated() {
            let y = 54 + Double(i) * 42
            s.card(40, y, 280, 36, accent: Anat.red)
            s.label(pg.0, pg.1, 56, y + 16, size: 10, color: Tone.ink, bold: true)
            s.label(pg.2, pg.3, 56, y + 29, size: 8, color: Tone.sub)
            s.path("M \(304) \(y + 12) l 6 6 l -6 6", stroke: Tone.faint, lw: 1.6, cap: .round)
        }
        s.label("A hands-on baby and child first-aid course is the best way to learn", "参加有实操的婴幼儿急救课程是最好的学习方式",
                180, 284, size: 8.5, color: Anat.purple, anchor: .middle, bold: true)
    }
}
