import SwiftUI

extension Illustrations {
    /// how much of the insulin actually works, after resistance (brisk walking eases resistance for a while)
    static func insulinAction(_ p: Params) -> Double {
        let res = p[v: "resistance"] * (1 - 0.5 * p[v: "exercise"])
        return p[v: "insulin"] * pow(1 - res, 1.5)
    }

    /// mmol/L — the liver's output plus what the meal adds, minus what insulin-opened and working muscle take in
    static func glucose(_ p: Params) -> Double {
        let meal = p[v: "meal"], ex = p[v: "exercise"], res = p[v: "resistance"] * (1 - 0.5 * ex), works = insulinAction(p)
        let base = 5 + 3 * res + 4 * p[v: "type1"] * max(0, 1 - p[v: "insulin"])
        let cleared = min(1, 0.85 * works + 0.75 * ex * (1 - 0.2 * res))
        let tooMuch = 4 * max(0, works - 0.9 * meal - 0.3)
        return (base + 5 * meal * (1 - cleared) - tooMuch).clamped(2.6, 20)
    }

    /// reading → (en, zh, colour), by the fasting or after-meal limits (tighter in pregnancy)
    static func glucoseStatus(_ p: Params) -> (String, String, Color) {
        let g = glucose(p), fasting = p[v: "meal"] < 0.3, pregnant = p[v: "pregnant"] > 0.5
        if g < 3.9 { return ("Low — eat sugar", "偏低——吃糖", Tone.blue) }
        if fasting {
            let (ok, bad) = pregnant ? (5.1, 5.1) : (6.1, 7.0)
            return g < ok ? ("Normal", "正常", Tone.green) : g < bad ? ("Borderline", "偏高", Tone.amber) : ("Diabetes range", "糖尿病范围", Tone.red)
        }
        if p[v: "insulin"] < 0.15 && p[v: "type1"] < 0.5 && p[v: "resistance"] < 0.1 && p[v: "exercise"] < 0.1 {
            return ("Rising", "正在上升", Tone.amber)
        }
        if pregnant { return g < 8.5 ? ("Normal", "正常", Tone.green) : ("Too high", "超标", Tone.red) }
        return g < 7.8 ? ("Normal", "正常", Tone.green) : g < 11.1 ? ("High", "偏高", Tone.amber) : ("Diabetes range", "糖尿病范围", Tone.red)
    }

    static let bloodSugar = Scenario(
        id: "blood-sugar", group: .blood, title: Bilingual("Blood sugar", "血糖"),
        params: ["meal": 0, "insulin": 0.3, "resistance": 0, "exercise": 0, "type1": 0, "pregnant": 0, "senior": 0, "kid": 0],
        steps: [
            .watch("Morning, before breakfast: a finger-prick meter reads about 4–6 mmol/L. The liver keeps it steady overnight.",
                   "早上空腹：指尖血糖仪读数约 4–6 mmol/L，夜间靠肝脏维持稳定。", set: ["meal": 0, "insulin": 0.3, "resistance": 0, "exercise": 0, "type1": 0]),
            .watch("A bowl of rice or bread is digested into glucose. The gut absorbs it into the blood and the reading climbs.",
                   "吃一碗米饭或面包，淀粉在肠道被分解为葡萄糖，吸收入血，读数上升。", set: ["meal": 1, "insulin": 0]),
            .watch("The pancreas senses the rise and releases insulin. Insulin unlocks sugar doors on muscle and liver cells; glucose moves in and the reading falls.",
                   "胰腺感知血糖升高，分泌胰岛素。胰岛素打开肌肉和肝细胞上的“糖门”，葡萄糖进入细胞，读数回落。", set: ["insulin": 1]),
            .watch("Type 2 diabetes: the cells resist insulin. The doors barely open, so sugar stays high — 11.1 or more two hours after a meal.",
                   "2型糖尿病：细胞对胰岛素抵抗，门几乎打不开，血糖居高不下——餐后 2 小时 ≥ 11.1。", set: ["resistance": 0.7]),
            .tryIt("Your turn: take a brisk walk after the meal — working muscles open their own sugar doors, even with weak insulin. Get the meter under 7.8.",
                   "试一试：饭后快走——运动中的肌肉自己打开糖门，胰岛素作用弱也能摄取葡萄糖。让读数低于 7.8。", set: ["exercise": 0],
                   TryStep(mode: .scrub([Scrub(param: "exercise", label: "Walking 快走", min: 0, max: 1)]),
                           success: { glucose($0) < 7.8 },
                           ok: Bilingual("Under 7.8 — 15–30 min of walking after meals works alongside insulin.", "低于 7.8——饭后走 15–30 分钟，与胰岛素协同降糖。"),
                           demo: ["exercise": 1])),
            .tryIt("Free play: change the meal, insulin, resistance and exercise.", "自由探索：调节进食、胰岛素、抵抗和运动。",
                   TryStep(mode: .scrub([
                       Scrub(param: "meal", label: "Meal 进食", min: 0, max: 1),
                       Scrub(param: "insulin", label: "Insulin 胰岛素", min: 0, max: 1),
                       Scrub(param: "resistance", label: "Resistance 抵抗", min: 0, max: 1),
                       Scrub(param: "exercise", label: "Exercise 运动", min: 0, max: 1),
                   ]), success: { _ in true }, ok: Bilingual("Normal: fasting under 6.1, 2 h after a meal under 7.8 mmol/L.", "正常：空腹低于 6.1，餐后 2 小时低于 7.8 mmol/L。"))),
        ],
        draw: { s, p, t in drawBloodSugar(&s, p, t) },
        sources: ["WHO diabetes fact sheet; ADA Standards of Care (glucose targets); IADPSG 2010 (pregnancy OGTT limits)"]
    )

    static func bloodSugar(for p: Profile) -> Scenario {
        var s = bloodSugar
        var steps = s.steps
        var base = s.params
        base["female"] = p.female ? 1 : 0
        switch p.age {
        case .infant, .toddler, .child:
            base["kid"] = 1
            s.profileNote = Bilingual("Children more often get type 1: thirst, peeing a lot, bedwetting, weight loss, tiredness — see a doctor the same day.",
                                      "儿童更常见 1 型糖尿病：口渴、多尿、尿床、消瘦、乏力——当天就医。")
            steps[3] = .watch("Type 1 diabetes: the immune system has destroyed the pancreas's insulin-making cells. No insulin, no open doors — sugar keeps rising.",
                              "1型糖尿病：免疫系统破坏了胰腺中分泌胰岛素的细胞。没有胰岛素，糖门打不开——血糖持续升高。", set: ["insulin": 0, "type1": 1])
            steps[4] = .tryIt("Your turn: give insulin with a pen before the meal. Get the meter under 7.8.",
                              "试一试：餐前用胰岛素笔补充胰岛素，让读数低于 7.8。",
                              TryStep(mode: .scrub([Scrub(param: "insulin", label: "Insulin dose 胰岛素剂量", min: 0, max: 1)]),
                                      success: { glucose($0) < 7.8 },
                                      ok: Bilingual("Under 7.8 — the dose matches the meal. Too much drops it under 3.9: eat sugar.", "低于 7.8——剂量与饮食匹配。过量会低于 3.9：立即吃糖。"),
                                      demo: ["insulin": 0.8]))
        case .senior:
            base["senior"] = 1
            s.profileNote = Bilingual("65+: diabetes pills or insulin can drop sugar under 3.9 — confusion, sweating, falls. Keep a sweet drink handy.",
                                      "65 岁以上：降糖药或胰岛素可使血糖低于 3.9——意识混乱、出汗、跌倒。随身带含糖饮料。")
        case .adult where p.isPregnant:
            base["pregnant"] = 1
            s.profileNote = Bilingual("Pregnant: test at 24–28 weeks (OGTT). Tighter limits: fasting < 5.1, 1 h < 10.0, 2 h < 8.5 mmol/L.",
                                      "孕妇：孕 24–28 周做糖耐量试验。标准更严：空腹 < 5.1，1 小时 < 10.0，2 小时 < 8.5 mmol/L。")
            steps[3] = .watch("Gestational diabetes: placenta hormones make cells resist insulin in mid-to-late pregnancy. Sugar stays above the pregnancy limit of 8.5.",
                              "妊娠糖尿病：孕中晚期胎盘激素使细胞抵抗胰岛素，血糖超过孕期标准 8.5。", set: ["resistance": 0.6])
            steps[4] = .tryIt("Your turn: a 15–30 minute walk after meals is safe in pregnancy. Get the meter under 7.8.",
                              "试一试：孕期饭后散步 15–30 分钟是安全的。让读数低于 7.8。", set: ["exercise": 0],
                              TryStep(mode: .scrub([Scrub(param: "exercise", label: "Walking 散步", min: 0, max: 1)]),
                                      success: { glucose($0) < 7.8 },
                                      ok: Bilingual("Under 7.8 — walking plus diet control is the first treatment; insulin if needed.", "低于 7.8——运动加饮食控制是首选，必要时用胰岛素。"),
                                      demo: ["exercise": 1]))
        case .adult: break
        }
        return s.rebased(base, steps: steps)
    }

    @MainActor private static func drawBloodSugar(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let g = glucose(p), meal = p[v: "meal"], ins = p[v: "insulin"], ex = p[v: "exercise"].clamped(0, 1)
        let type1 = p[v: "type1"] > 0.5, kid = p[v: "kid"] > 0.5, res = p[v: "resistance"]
        let works = insulinAction(p), door = min(1, works + ex * 0.8)
        let status = glucoseStatus(p)

        // left: the person at the table, organs seen through the body; or out for a walk
        let seat = 1 - ex
        s.circle(92, 160, 86, fill: seat > 0.5 ? Palette.blob : hex("#EAF2E4"))
        if seat > 0.01 {
            s.group(opacity: seat) { w in drawMealTable(&w, p, t, meal: meal, ins: ins, type1: type1, kid: kid, sugarHigh: g > 11) }
        }
        if ex > 0.01 {
            s.group(opacity: ex) { w in drawWalk(&w, p, t) }
        }

        // right, top: finger-prick meter with its reading on a range scale
        s.card(188, 6, 164, 100)
        let dev = CGRect(x: 196, y: 12, width: 56, height: 60)
        s.shade(Path(roundedRect: dev, cornerRadius: 11), hex("#4A5870"), hex("#2E3848"))
        s.rect(dev.minX + 5, dev.minY + 6, dev.width - 10, 32, r: 4, fill: hex("#D9E6D3"))
        s.text(String(format: "%.1f", g), dev.maxX - 9, dev.minY + 28, size: 17, color: hex("#1E2A22"), anchor: .end, bold: true)
        s.text("mmol/L", dev.maxX - 9, dev.minY + 35, size: 5.5, color: hex("#3E4A42"), anchor: .end)
        s.circle(dev.midX - 8, dev.minY + 48, 3.5, fill: hex("#5E6C84"))
        s.circle(dev.midX + 8, dev.minY + 48, 3.5, fill: hex("#5E6C84"))
        s.rect(dev.midX - 5, dev.maxY - 2, 10, 11, r: 1, fill: hex("#F3F1EC"), stroke: hex("#B8B2A8"), lw: 0.6)
        s.path("M \(dev.midX) \(dev.maxY + 2) q 2.6 3.5 0 5.5 q -2.6 -2 0 -5.5 Z", fill: Tone.red)
        s.caption("Blood glucose", "血糖", 260, 24)
        s.pill(status.0, status.1, 260, 40, color: status.2, size: 8.5)
        let fasting = meal < 0.3
        let rising = status.0 == "Rising"
        s.label(fasting ? "before breakfast" : rising ? "after the meal" : "2 h after the meal",
                fasting ? "空腹 · 早餐前" : rising ? "餐后" : "餐后 2 小时", 260, 58, size: 7.5, color: Tone.sub)
        let pregnant = p[v: "pregnant"] > 0.5
        let bands: [(Double, Color, String, String)] = pregnant
            ? [(3.9, Tone.blue, "", ""), (fasting ? 5.1 : 8.5, Tone.green, "", ""), (15, Tone.red, "", "")]
            : fasting ? [(3.9, Tone.blue, "", ""), (6.1, Tone.green, "", ""), (7.0, Tone.amber, "", ""), (15, Tone.red, "", "")]
            : [(3.9, Tone.blue, "", ""), (7.8, Tone.green, "", ""), (11.1, Tone.amber, "", ""), (15, Tone.red, "", "")]
        let ticks = pregnant ? [3.9, fasting ? 5.1 : 8.5] : fasting ? [3.9, 7.0] : [3.9, 7.8, 11.1]
        s.bandScale(210, 86, 134, lo: 2.5, hi: 15, value: g, bands: bands, ticks: ticks, format: "%.1f", h: 5)

        // right, middle: blood vessel over a muscle cell — insulin keys, sugar doors
        s.card(188, 112, 164, 158)
        s.caption("In the blood → into a muscle cell", "血液中 → 进入肌肉细胞", 196, 125)
        let vy0 = 132.0, vy1 = 156.0
        s.rect(196, vy0, 148, vy1 - vy0, r: 6, fill: Tone.blood)
        s.line(196, vy0, 344, vy0, stroke: hex("#D98C94"), lw: 1.5)
        s.line(196, vy1, 344, vy1, stroke: hex("#D98C94"), lw: 1.5)
        var vessel = s.clipped(196, vy0, 148, vy1 - vy0)
        for i in 0..<4 {
            let x = 196 + (Double(i) * 41 + t * 18).wrap(170) - 10
            vessel.ellipse(x, vy0 + 8 + Double(i % 2) * 8, 6, 3.2, fill: hex("#E07A82"))
        }
        let n = Int((g * 2.2).rounded())
        for i in 0..<n {
            let d = Double(i)
            vessel.circle(196 + (d * 37.3 + t * 22 * (0.7 + Double(i % 4) * 0.12)).wrap(160) - 6, vy0 + 5 + (d * 5.3).wrap(vy1 - vy0 - 10), 2.2, fill: Tone.sugar)
        }
        for i in 0..<Int((ins * 4).rounded()) {
            insulinKey(&vessel, 200 + (Double(i) * 43 + t * 14).wrap(150), vy0 + 7 + Double(i % 2) * 10, scale: 0.9)
        }
        // the cell
        let cx0 = 196.0, cy0 = 172.0, cw = 148.0, ch = 90.0
        s.rect(cx0, cy0, cw, ch, r: 14, fill: hex("#F6DCD6"), stroke: hex("#D08A7E"), lw: 3)
        s.rect(cx0 + 2.5, cy0 + 2.5, cw - 5, ch - 5, r: 12, stroke: hex("#F9ECE8"), lw: 1)
        for j in 0..<8 { s.line(cx0 + 16 + Double(j) * 16.5, cy0 + 12, cx0 + 16 + Double(j) * 16.5, cy0 + ch - 10, stroke: hex("#EDC3BA"), lw: 1.4) }
        // receptors (Y) with a docked key, and sugar doors between them
        for rx in [214.0, 290] {
            let bound = ins > 0.2
            let rc = res > 0.4 && ex < 0.5 ? hex("#A59FA8") : Tone.insulin
            s.path("M \(rx) \(cy0 + 8) L \(rx) \(cy0 - 3) M \(rx) \(cy0 - 3) L \(rx - 5) \(cy0 - 9) M \(rx) \(cy0 - 3) L \(rx + 5) \(cy0 - 9)", stroke: rc, lw: 2, cap: .round)
            if bound { insulinKey(&s, rx - 2, cy0 - 11, scale: 0.9) }
            if bound && works < 0.3 && res > 0.4 { s.text("✕", rx + 9, cy0 + 2, size: 7, color: Tone.red, bold: true) }
        }
        for dx in [252.0, 324] {
            let gap = 1.2 + door * 5.5
            s.rect(dx - gap - 4, cy0 - 5, 4, 10, r: 1.5, fill: hex("#4E9A5E"))
            s.rect(dx + gap, cy0 - 5, 4, 10, r: 1.5, fill: hex("#4E9A5E"))
            s.line(dx - gap, cy0, dx + gap, cy0, stroke: hex("#F6DCD6"), lw: 3.2)
            if door > 0.15 && g > 4.2 {
                for j in 0..<3 {
                    let u = (t * 0.8 + Double(j) / 3).wrap(1)
                    s.circle(dx, vy1 + 2 + u * 26, 2.2, fill: Tone.sugar, opacity: u < 0.85 ? 1 : (1 - u) * 6)
                }
            }
        }
        let inside = Int((door * 10 * min(1, meal + 0.35) + ex * 4).rounded())
        for j in 0..<min(14, inside) {
            s.circle(cx0 + 20 + Double(j % 7) * 17 + (j / 7 == 1 ? 8 : 0), cy0 + 32 + Double(j / 7) * 16, 2.4, fill: Tone.sugar)
        }
        if ex > 0.3 {
            for (bx, by) in [(cx0 + 20, cy0 + 56), (cx0 + cw - 26, cy0 + 56)] {
                s.path("M \(bx + 3) \(by - 7) L \(bx - 2) \(by + 1) L \(bx + 2) \(by + 1) L \(bx - 2) \(by + 8)", stroke: Tone.amber, lw: 1.5, cap: .round)
            }
        }
        let doorText: (String, String, Color) = type1 && ins < 0.2 ? ("no insulin — doors shut", "没有胰岛素——门关闭", Tone.red)
            : ex > 0.3 ? ("exercise opens more doors", "运动打开更多糖门", Tone.green)
            : door > 0.6 ? ("insulin opens the doors", "胰岛素打开糖门", Tone.green)
            : ins > 0.2 && res > 0.4 ? ("resistance: doors stuck", "抵抗：门打不开", Tone.red)
            : door > 0.25 ? ("doors half open", "门半开", Tone.amber) : ("doors shut", "门关闭", Tone.sub)
        s.label(doorText.0, doorText.1, cx0 + cw / 2, cy0 + ch - 7, size: 8.5, color: doorText.2, anchor: .middle, bold: true)
        s.label("muscle cell", "肌肉细胞", cx0 + cw - 10, cy0 + 16, size: 7.5, color: hex("#A0503F"), anchor: .end, bold: true)

        // legend
        let ly = 289.0
        s.circle(192, ly - 3, 2.6, fill: Tone.sugar); s.label("glucose", "葡萄糖", 198, ly, size: 8, color: Tone.sub)
        insulinKey(&s, 244, ly - 3, scale: 0.9); s.label("insulin", "胰岛素", 252, ly, size: 8, color: Tone.sub)
        s.rect(296, ly - 7, 3, 8, r: 1, fill: hex("#4E9A5E")); s.rect(301, ly - 7, 3, 8, r: 1, fill: hex("#4E9A5E"))
        s.label("sugar door", "糖门", 308, ly, size: 8, color: Tone.sub)
    }

    @MainActor static func insulinKey(_ s: inout Sketch, _ x: Double, _ y: Double, scale k: Double = 1, opacity o: Double = 1) {
        s.circle(x - 3 * k, y, 2.6 * k, stroke: Tone.insulin, lw: 1.6 * k, opacity: o)
        s.path("M \(x - 0.4 * k) \(y) L \(x + 5.5 * k) \(y) M \(x + 3.8 * k) \(y) L \(x + 3.8 * k) \(y + 2.6 * k) M \(x + 5.5 * k) \(y) L \(x + 5.5 * k) \(y + 2 * k)",
               stroke: Tone.insulin, lw: 1.6 * k, opacity: o)
    }

    @MainActor private static func drawMealTable(_ w: inout Sketch, _ p: Params, _ t: Double, meal: Double, ins: Double, type1: Bool, kid: Bool, sugarHigh: Bool) {
        let o = CGPoint(x: 86, y: kid ? 112 : 94)
        var person = patient(p, h: 330)
        if kid { person.h = 300 }
        person.face = sugarHigh ? .worried : .calm
        person.waist = 0.4
        let tableY = o.y + (kid ? 0.36 : 0.37) * person.h
        let bite = meal > 0.5 ? (sin(t * 2.2) * 3 + 0.5).clamped(0, 1) : 0
        let bowl = CGPoint(x: -26, y: tableY - o.y - 6)
        person.rightHand = CGPoint(x: bowl.x + (person.mouth.x - 10 - bowl.x) * bite, y: bowl.y - 4 + (person.mouth.y + 10 - bowl.y + 4) * bite)
        let injecting = type1 && ins > 0.3
        person.leftHand = injecting ? CGPoint(x: 0.03 * person.h, y: 0.28 * person.h) : CGPoint(x: 0.075 * person.h, y: tableY - o.y - 5)
        person.drawBody(&w, at: o)
        // organs through the body
        let k = person.h * 0.0018, org = CGPoint(x: o.x - 2, y: o.y + 0.1 * person.h)
        w.group(translate: org, scale: k) { q in
            q.abdomen(pancreasOff: type1, pancreasGlow: !type1 && ins > 0.5 && meal > 0.5 ? 1 : 0)
            // glucose from the gut up the portal vein to the liver; insulin from the pancreas into the blood
            q.path("M 2 104 C 0 88 -6 70 -14 48", stroke: hex("#8C7BB8"), lw: 2.2, opacity: 0.7, cap: .round)
            for i in 0..<Int((meal * 6).rounded()) {
                let u = (t * 0.45 + Double(i) / 6).wrap(1)
                q.circle(2 - u * 16 + sin(u * 3) * 2, 104 - u * 56, 3, fill: Tone.sugar, stroke: .white, lw: 0.6)
            }
            if !type1 {
                for i in 0..<Int((ins * 4).rounded()) {
                    let u = (t * 0.5 + Double(i) / 4).wrap(1)
                    insulinKey(&q, 14 + u * 26, 64 - u * 24, scale: 1.6, opacity: 1 - u * 0.8)
                }
            }
        }
        func at(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: org.x + x * k, y: org.y + y * k) }
        // table, bowl and spoon
        w.shade(Path(roundedRect: CGRect(x: 0, y: tableY, width: 186, height: 10), cornerRadius: 3), hex("#E6CFB2"), hex("#D8BC9A"))
        w.shade(Path(CGRect(x: 0, y: tableY + 10, width: 186, height: 300 - tableY - 10)), hex("#F0E6DA"), hex("#E8DCCC"), vertical: true)
        w.line(0, tableY + 10, 186, tableY + 10, stroke: hex("#D8BC9A"), lw: 1)
        if meal > 0.5 {
            w.card(40, tableY + 26, 104, 26, r: 7)
            w.label("rice bowl ≈ 50 g carbs", "一碗米饭 ≈ 50 克碳水", 92, tableY + 43, size: 8, color: Tone.sub, anchor: .middle, bold: true)
        }
        if meal > 0.05 {
            let bx = o.x + bowl.x
            w.path("M \(bx - 20) \(tableY - 12) L \(bx + 20) \(tableY - 12) C \(bx + 18) \(tableY + 1) \(bx - 18) \(tableY + 1) \(bx - 20) \(tableY - 12) Z",
                   fill: .white, stroke: hex("#9FB3CC"), lw: 1.2)
            w.path("M \(bx - 16) \(tableY - 6) L \(bx + 16) \(tableY - 6)", stroke: hex("#9FB3CC"), lw: 1)
            w.ellipse(bx, tableY - 12, 18, 4.5 * meal, fill: hex("#FBF7EE"), stroke: hex("#DCCFB8"), lw: 0.8)
            for i in 0..<5 { w.ellipse(bx - 10 + Double(i) * 5, tableY - 13 - Double(i % 2), 1.6, 1, fill: hex("#E6DCC8")) }
        }
        person.drawArms(&w, at: o)
        if meal > 0.05 {
            let hd = person.arm(-1).hand
            w.line(o.x + hd.x - 4, o.y + hd.y + 2, o.x + hd.x + 10, o.y + hd.y - 7, stroke: hex("#9AA3AE"), lw: 2, cap: .round)
            w.ellipse(o.x + hd.x + 11, o.y + hd.y - 8, 3.5, 2, fill: hex("#B8C0CA"))
        }
        if injecting {
            let hd = person.arm(1).hand
            w.group(translate: CGPoint(x: o.x + hd.x - 2, y: o.y + hd.y), rotate: -60) { pen in
                pen.rect(-4, -26, 8, 30, r: 2.5, fill: hex("#E6ECF5"), stroke: Tone.insulin, lw: 1.2)
                pen.rect(-4, -26, 8, 8, r: 2.5, fill: Tone.insulin)
                pen.line(0, 4, 0, 10, stroke: hex("#7E8794"), lw: 1)
            }
            w.callout("insulin pen", "胰岛素笔", at: CGPoint(x: o.x + hd.x + 12, y: o.y + hd.y - 14), 136, o.y + hd.y + 16, anchor: .start, color: Tone.insulin)
        }
        // labels
        w.callout("liver", "肝", at: at(-30, 26), 6, at(-30, 26).y - 24, anchor: .start, color: Tone.organLine)
        w.callout("stomach", "胃", at: at(30, 32), 136, at(30, 32).y - 22, color: Tone.organLine)
        w.callout("pancreas", "胰腺", at: at(34, 62), 136, at(34, 62).y + 4, color: hex("#9A6A1B"))
        if type1 { w.label("no insulin", "不分泌胰岛素", 136, at(34, 62).y + 14, size: 7.5, color: Tone.red, bold: true) }
        w.callout("gut", "肠", at: at(-30, 110), 6, min(tableY - 6, at(-30, 110).y + 6), color: Tone.organLine)
    }

    @MainActor private static func drawWalk(_ w: inout Sketch, _ p: Params, _ t: Double) {
        let floor = 252.0, ph = t * 4, sw = sin(ph)
        w.rect(6, floor, 176, 4, r: 2, fill: hex("#CFE0C4"))
        // tree
        w.rect(26, 130, 6, floor - 130, fill: hex("#A88462"))
        w.circle(29, 118, 22, fill: hex("#A9CF9A"))
        w.circle(42, 134, 14, fill: hex("#BCDDB0"))
        var walker = SideFigure(Casualty(p, adult: 196), lean: 4)
        if walker.bump == 0 && p[v: "kid"] < 0.5 && p[v: "senior"] < 0.5 { walker.look.top = hex("#7DBF9A"); walker.look.topLine = Look.edge(walker.look.top) }
        walker.look.longSleeves = false
        func leg(_ a: Double, _ bend: Double) -> SideFigure.Leg {
            let knee = 4 + 26 * max(0, bend)
            return .init(hip: a, knee: knee, point: a - knee + (a < 0 ? 28 * min(1, -a / 12) : 0))
        }
        walker.nearLeg = leg(18 * sw, -sin(ph + 0.8))
        walker.farLeg = leg(-18 * sw, sin(ph + 0.8))
        walker.near = .init(shoulder: -20 * sw, elbow: 35)
        walker.far = .init(shoulder: 20 * sw, elbow: 35)
        walker.hip = CGPoint(x: 86, y: walker.hipY(onFloor: floor))
        walker.draw(&w)
        let thigh = walker.legPoint(near: true, 0.5), calf = walker.legPoint(near: true, 1.4)
        w.glow(thigh.x, thigh.y, 16, Tone.amber, opacity: 0.55)
        w.glow(calf.x, calf.y, 12, Tone.amber, opacity: 0.45)
        w.callout("leg muscles", "腿部肌肉", at: thigh, 126, thigh.y + 30, anchor: .start, color: hex("#3F7F53"))
        w.label("take in sugar", "摄取葡萄糖", 126, thigh.y + 41, size: 8.5, color: hex("#3F7F53"), bold: true)
        w.label("brisk walk, 15–30 min", "快走 15–30 分钟", 92, 274, size: 8.5, color: Tone.sub, anchor: .middle)
    }
}
