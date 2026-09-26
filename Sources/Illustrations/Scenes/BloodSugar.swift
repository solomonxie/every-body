import SwiftUI

extension Illustrations {
    /// mmol/L — absorbed from the meal, cleared by insulin-opened cells and by exercising muscle
    static func glucose(_ p: Params) -> Double {
        let absorbed = p[v: "meal"] * 6
        let cleared = absorbed * p[v: "insulin"] * (1 - p[v: "resistance"]) * 0.85 + p[v: "exercise"] * 2.5 * (1 - 0.3 * p[v: "resistance"])
        return (5 + absorbed - cleared).clamped(3.2, 20)
    }

    static let bloodSugar = Scenario(
        id: "blood-sugar", group: .blood, title: Bilingual("Blood sugar", "血糖"),
        params: ["meal": 0, "insulin": 0.3, "resistance": 0, "exercise": 0, "type1": 0, "pregnant": 0, "senior": 0],
        steps: [
            .watch("Morning, before breakfast: a finger-prick meter reads about 4–6 mmol/L (fasting).",
                   "早上空腹：指尖血糖仪读数约 4–6 mmol/L。", set: ["meal": 0, "insulin": 0.3, "resistance": 0, "exercise": 0]),
            .watch("A bowl of rice or bread is digested into glucose. The gut absorbs it into the blood and the reading climbs.",
                   "吃一碗米饭或面包，淀粉在肠道被分解为葡萄糖，吸收入血，读数上升。", set: ["meal": 1, "insulin": 0]),
            .watch("The pancreas senses the rise and releases insulin — keys that open muscle and liver cells. Glucose moves in; the reading falls back.",
                   "胰腺感知血糖升高，分泌胰岛素——像钥匙打开肌肉和肝细胞，葡萄糖进入细胞，读数回落。", set: ["insulin": 1]),
            .watch("Type 2 diabetes: the cells resist insulin. The doors barely open, so sugar stays high — 11.1 or more two hours after a meal.",
                   "2型糖尿病：细胞对胰岛素抵抗，门几乎打不开，血糖居高不下——餐后 2 小时 ≥ 11.1。", set: ["resistance": 0.7]),
            .tryIt("Your turn: take a brisk walk after the meal — working muscles pull in glucose even with little insulin. Get the meter under 7.8.",
                   "试一试：饭后快走——运动中的肌肉即使胰岛素不足也能摄取葡萄糖。让血糖仪读数低于 7.8。", set: ["exercise": 0],
                   TryStep(mode: .scrub([Scrub(param: "exercise", label: "Walking 快走", min: 0, max: 1)]),
                           success: { glucose($0) < 7.8 },
                           ok: Bilingual("Under 7.8 — a walk after meals works alongside insulin.", "低于 7.8——饭后走一走，与胰岛素协同降糖。"), demo: ["exercise": 1])),
            .tryIt("Free play: change the meal, insulin, resistance and exercise.", "自由探索：调节进食、胰岛素、抵抗和运动。",
                   TryStep(mode: .scrub([
                       Scrub(param: "meal", label: "Meal 进食", min: 0, max: 1),
                       Scrub(param: "insulin", label: "Insulin 胰岛素", min: 0, max: 1),
                       Scrub(param: "resistance", label: "Resistance 抵抗", min: 0, max: 1),
                       Scrub(param: "exercise", label: "Exercise 运动", min: 0, max: 1),
                   ]), success: { _ in true }, ok: Bilingual("Normal: fasting under 6.1, 2 h after a meal under 7.8 mmol/L.", "正常：空腹低于 6.1，餐后 2 小时低于 7.8 mmol/L。"))),
        ],
        draw: { s, p, t in drawBloodSugar(&s, p, t) },
        sources: ["WHO diabetes fact sheet; ADA Standards of Care (glucose targets)"]
    )

    static func bloodSugar(for p: Profile) -> Scenario {
        var s = bloodSugar
        var steps = s.steps
        var base = s.params
        switch p.age {
        case .infant, .child:
            base["type1"] = 1
            s.profileNote = Bilingual("Children more often get type 1: thirst, peeing a lot, bedwetting, weight loss, tiredness — see a doctor the same day.",
                                      "儿童更常见 1 型糖尿病：口渴、多尿、尿床、消瘦、乏力——当天就医。")
            steps[3] = .watch("Type 1 diabetes: the immune system has destroyed the insulin-making cells. No keys, so sugar keeps rising.",
                              "1型糖尿病：免疫系统破坏了分泌胰岛素的细胞。没有钥匙，血糖持续升高。", set: ["insulin": 0])
            steps[4] = .tryIt("Your turn: give insulin with a pen or pump before the meal. Get the meter under 7.8.",
                              "试一试：餐前用胰岛素笔或泵补充胰岛素，让读数低于 7.8。",
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
            steps[3] = .watch("Gestational diabetes: placenta hormones make cells resist insulin in mid-to-late pregnancy. Sugar stays high.",
                              "妊娠糖尿病：孕中晚期胎盘激素使细胞抵抗胰岛素，血糖居高不下。", set: ["resistance": 0.6])
        case .adult: break
        }
        return s.rebased(base, steps: steps)
    }

    @MainActor private static func drawBloodSugar(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let g = glucose(p), meal = p[v: "meal"], ins = p[v: "insulin"], ex = p[v: "exercise"], type1 = p[v: "type1"] > 0.5
        let level = g < 3.9 ? hex("#3F95D6") : g <= 7.8 ? hex("#2E9E5B") : g <= 11 ? hex("#E39B4B") : hex("#D8434B")
        let doorOpen = min(1, ins * (1 - p[v: "resistance"]) + ex * 0.6)
        let sugar = hex("#E8A21B"), key = hex("#3F7FD6"), ink = hex("#555555")
        func insulinKey(_ s: inout Sketch, _ x: Double, _ y: Double, _ o: Double = 1) {
            s.circle(x - 3, y, 3, stroke: key, lw: 1.8, opacity: o)
            s.path("M \(x) \(y) L \(x + 6) \(y) M \(x + 4) \(y) L \(x + 4) \(y + 3)", stroke: key, lw: 1.8, opacity: o)
        }

        // person at the table, organs seen through the body
        let o = CGPoint(x: 84, y: 86)
        let seat = 1 - ex.clamped(0, 1)
        s.group(opacity: seat) { w in
            var person = FacingPerson(h: 270, face: g > 11 ? .worried : .calm)
            if type1 { person.head = 1.25; person.h = 230 }
            if p[v: "pregnant"] > 0.5 { person.longHair = true; person.bump = true; person.shirt = hex("#E8B4C8"); person.shirtLine = hex("#B77A95") }
            if p[v: "senior"] > 0.5 { person.hair = hex("#B8B8B8") }
            let bite = meal > 0.5 ? (sin(t * 2.2) + 1) / 2 : 0
            let bowl = CGPoint(x: -14, y: 86)
            person.rightHand = CGPoint(x: bowl.x + (person.mouth.x - 8 - bowl.x) * bite, y: bowl.y - 6 + (person.mouth.y + 4 - bowl.y + 6) * bite)
            let injecting = type1 && ins > 0.3
            person.leftHand = injecting ? CGPoint(x: 30, y: 62) : CGPoint(x: 26, y: 84)
            person.drawBody(&w, at: o)
            w.group(translate: o) { b in
                let k = person.h / 270
                b.group(scale: k * 1.1) { q in
                    q.path("M -27 40 C -15 32 0 33 12 38 C 8 44 -2 48 -12 54 C -20 58 -26 54 -27 40 Z", fill: hex("#A8504C"), opacity: 0.85)       // liver
                    q.path("M -10 64 C -4 60 12 60 24 56 C 26 58 25 61 22 62 C 12 66 0 68 -10 68 Z",
                           fill: type1 ? hex("#C9C2B6") : hex("#E9B25A"))                                                                           // pancreas
                    q.path("M 4 38 C 10 32 20 34 22 44 C 24 56 16 64 6 62 C 0 61 -4 57 -6 54 C 0 54 6 52 8 46 C 9 42 6 40 4 38 Z",
                           fill: hex("#E8A0A8"), opacity: 0.9)                                                                                     // stomach
                    for r in 0..<3 {
                        q.path("M -18 \(72 + Double(r) * 6) q 6 -4 12 0 t 12 0 t 12 0", stroke: hex("#D98C7A"), lw: 3, opacity: 0.85, cap: .round)
                    }
                    // glucose rising from the gut, into the blood and the liver
                    for i in 0..<Int((meal * 8).rounded()) {
                        let u = (t * 0.45 + Double(i) / 8).wrap(1)
                        q.circle(-4 + sin(Double(i) * 1.7) * 12, 84 - u * 42, 2.2, fill: sugar, opacity: 1 - u * 0.6)
                    }
                    for i in 0..<Int((ins * 5).rounded()) {
                        let u = (t * 0.5 + Double(i) / 5).wrap(1)
                        if type1 { insulinKey(&q, 14 - u * 20, 68 - u * 26, 1 - u) } else { insulinKey(&q, 8 + Double(i) * 3, 63 - u * 30, 1 - u) }
                    }
                }
            }
            // table, bowl and spoon
            w.line(0, 292, 180, 292, stroke: hex("#BBBBBB"), lw: 2)
            w.rect(12, 190, 8, 102, fill: hex("#B08A64"))
            w.rect(160, 190, 8, 102, fill: hex("#B08A64"))
            w.rect(0, 178, 180, 12, r: 3, fill: hex("#C9A27A"), stroke: hex("#9B7550"))
            if meal > 0.05 {
                w.path("M \(o.x - 32) 170 L \(o.x + 4) 170 C \(o.x + 2) 182 \(o.x - 30) 182 \(o.x - 32) 170 Z", fill: .white, stroke: hex("#9FB3CC"), lw: 1.5)
                w.ellipse(o.x - 14, 170, 17, 4 * meal, fill: hex("#F5F0E6"), stroke: hex("#D8CCB4"))
            }
            person.drawArms(&w, at: o)
            if injecting {
                // insulin pen pressed into the belly
                w.group(translate: CGPoint(x: o.x + 30, y: o.y + 62), rotate: 50) { pen in
                    pen.rect(-4, -22, 8, 30, r: 2, fill: hex("#E6ECF5"), stroke: key, lw: 1.5)
                    pen.rect(-4, -22, 8, 7, r: 2, fill: key)
                    pen.line(0, 8, 0, 14, stroke: hex("#9AA3AE"), lw: 1)
                }
            }
            if meal > 0.05 {
                let hand = person.arm(-1).hand
                w.line(o.x + hand.x - 2, o.y + hand.y - 2, o.x + hand.x + 9, o.y + hand.y - 8, stroke: hex("#9AA3AE"), lw: 2, cap: .round)
            }
        }
        // after the meal: a brisk walk
        if ex > 0.02 {
            s.group(opacity: ex.clamped(0, 1)) { w in
                let hip = CGPoint(x: 80, y: 190), h = 200.0, ph = t * 4
                var walker = Person(h: h, shirt: hex("#8FC8A0"), shirtLine: hex("#4F8F63"), shoulder: 25 * sin(ph), elbow: 40, hip: 25 * sin(ph), knee: 25 * max(0, -sin(ph)) + 5)
                if p[v: "pregnant"] > 0.5 { walker.shirt = hex("#E8B4C8"); walker.shirtLine = hex("#B77A95") }
                let thigh = 0.245 * h, a1 = -25 * sin(ph) * .pi / 180, a2 = a1 - (25 * max(0, sin(ph)) + 5) * .pi / 180
                let k = CGPoint(x: hip.x + sin(a1) * thigh, y: hip.y + cos(a1) * thigh), f = CGPoint(x: k.x + sin(a2) * thigh, y: k.y + cos(a2) * thigh)
                w.line(hip.x, hip.y, k.x, k.y, stroke: hex("#46546F"), lw: 0.075 * h, cap: .round)
                w.line(k.x, k.y, f.x, f.y, stroke: hex("#46546F"), lw: 0.06 * h, cap: .round)
                w.line(f.x, f.y, f.x + 0.1 * h, f.y + 2, stroke: hex("#3E3E4A"), lw: 0.035 * h, cap: .round)
                walker.draw(&w, at: hip)
                w.line(0, 292, 180, 292, stroke: hex("#BBBBBB"), lw: 2)
                w.label("thigh & calf muscles burn glucose", "腿部肌肉消耗葡萄糖", 90, 70, size: 9, color: hex("#4F8F63"), anchor: .middle, bold: true)
            }
        }
        if seat > 0.3 {
            s.label("liver", "肝", 26, 132, size: 9, color: hex("#8A3B45"), anchor: .end)
            s.line(28, 130, 62, 134, stroke: hex("#C9A58A"), lw: 0.8)
            s.label("stomach", "胃", 132, 124, size: 9, color: hex("#8A3B45"))
            s.line(130, 122, 104, 136, stroke: hex("#C9A58A"), lw: 0.8)
            s.label("pancreas", "胰腺", 132, 154, size: 9, color: hex("#9A6A1B"))
            if type1 { s.label("no insulin", "不分泌胰岛素", 132, 164, size: 8, color: hex("#D8434B")) }
            s.line(130, 152, 110, 155, stroke: hex("#C9A58A"), lw: 0.8)
            s.label("gut", "肠", 132, 176, size: 9, color: hex("#8A3B45"))
            s.line(130, 174, 104, 172, stroke: hex("#C9A58A"), lw: 0.8)
        }

        // zoom: blood and the cells it feeds
        let x0 = 186.0, top = 82.0, bottom = 122.0
        s.rect(x0, top, 352 - x0, bottom - top, fill: hex("#F7DADA"))
        s.line(x0, top, 352, top, stroke: hex("#C0555F"), lw: 2.5)
        s.line(x0, bottom, 352, bottom, stroke: hex("#C0555F"), lw: 2.5)
        s.label("in the blood →", "血液中 →", x0, top - 5, size: 9, color: hex("#8A3B45"), bold: true)
        for i in 0..<Int((g * 3).rounded()) {
            let d = Double(i)
            s.circle(x0 + (d * 53.3 + t * 26 * (0.7 + Double(i % 5) * 0.1)).wrap(166), top + 6 + (d * 37.7).wrap(bottom - top - 12), 3, fill: sugar)
        }
        for i in 0..<Int((ins * 6).rounded()) {
            insulinKey(&s, x0 + 6 + (Double(i) * 47 + t * 20).wrap(150), top + 10 + (Double(i) * 29).wrap(bottom - top - 20))
        }
        let cells: [(String, String, Double, Bool)] = [("muscle cell", "肌肉细胞", 190, true), ("liver cell", "肝细胞", 274, false)]
        for (en, zh, cx, muscle) in cells {
            let cy = 134.0, w = 76.0, hgt = 80.0, gap = 3 + doorOpen * 12, mid = cx + w / 2
            s.rect(cx, cy, w, hgt, r: muscle ? 22 : 10, fill: muscle ? hex("#F4D6D0") : hex("#EBD9C6"),
                   stroke: muscle ? hex("#C77B6E") : hex("#A8804F"), lw: 2)
            if muscle { for j in 0..<5 { s.line(cx + 12 + Double(j) * 13, cy + 18, cx + 12 + Double(j) * 13, cy + hgt - 10, stroke: hex("#E3B5AC"), lw: 2) } }
            else { s.circle(cx + w - 20, cy + hgt - 22, 10, fill: hex("#D2B48C"), stroke: hex("#A8804F")) }
            // door in the top wall (GLUT4)
            s.rect(mid - gap - 5, cy - 4, 5, 9, r: 1.5, fill: hex("#6E9E4F"))
            s.rect(mid + gap, cy - 4, 5, 9, r: 1.5, fill: hex("#6E9E4F"))
            s.line(mid - gap, cy, mid + gap, cy, stroke: muscle ? hex("#F4D6D0") : hex("#EBD9C6"), lw: 3)
            if doorOpen > 0.15 && g > 4.5 {
                for j in 0..<3 { s.circle(mid, bottom + (t * 26 + Double(j) * 10).wrap(30), 2.6, fill: sugar) }
            }
            let inside = Int((doorOpen * 9 * min(1, meal + 0.3) + (muscle ? ex * 3 : 0)).rounded())
            for j in 0..<min(12, inside) { s.circle(cx + 14 + Double(j % 4) * 13, cy + 26 + Double(j / 4) * 14, 3, fill: sugar) }
            s.label(en, zh, mid, cy + hgt + 13, size: 9, color: muscle ? hex("#A0503F") : hex("#7A5A2F"), anchor: .middle, bold: true)
        }
        s.label(doorOpen > 0.5 ? "insulin opens the door" : doorOpen > 0.2 ? "door half open" : "door shut",
                doorOpen > 0.5 ? "胰岛素打开细胞门" : doorOpen > 0.2 ? "门半开" : "门关闭", 269, 244, size: 9, color: hex("#4F7A38"), anchor: .middle)

        // glucose meter with a test strip
        s.rect(262, 6, 90, 52, r: 10, fill: hex("#3A4A5C"))
        s.rect(270, 12, 74, 32, r: 4, fill: hex("#DDE8DA"))
        s.text(String(format: "%.1f", g), 332, 38, size: 20, color: level, anchor: .end, bold: true)
        s.text("mmol/L", 307, 53, size: 7, color: .white, anchor: .middle)
        s.rect(236, 27, 26, 7, fill: hex("#F2F2F2"), stroke: hex("#AAAAAA"), lw: 0.8)
        s.circle(240, 30.5, 3, fill: hex("#C8323C"))
        let status = g < 3.9 ? s.t("LOW", "偏低") : g <= 7.8 ? s.t("normal", "正常") : g < 11.1 ? s.t("high", "偏高") : s.t("diabetes range", "糖尿病范围")
        s.label("glucose meter", "血糖仪", 232, 14, size: 8, color: ink, anchor: .end)
        s.text(status, 232, 50, size: 11, color: level, anchor: .end, bold: true)
        s.label(meal > 0.3 ? "after meal" : "fasting", meal > 0.3 ? "餐后" : "空腹", 232, 30, size: 8, color: ink, anchor: .end)

        // legend
        s.circle(196, 272, 3, fill: sugar); s.label("glucose", "葡萄糖", 203, 275, size: 9, color: ink)
        insulinKey(&s, 272, 272); s.label("insulin", "胰岛素", 282, 275, size: 9, color: ink)
        s.label("normal after meals: under 7.8", "餐后正常：低于 7.8", 196, 292, size: 9, color: hex("#2E9E5B"))
    }
}
