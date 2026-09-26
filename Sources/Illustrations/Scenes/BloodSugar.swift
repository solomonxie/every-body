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
        params: ["meal": 0, "insulin": 0.3, "resistance": 0, "exercise": 0],
        steps: [
            .watch("Fasting: blood sugar sits near 5 mmol/L.", "空腹时，血糖约 5 mmol/L。",
                   set: ["meal": 0, "insulin": 0.3, "resistance": 0, "exercise": 0]),
            .watch("A meal is digested into glucose, which floods the blood.", "进餐后，食物分解为葡萄糖，进入血液，血糖升高。", set: ["meal": 1, "insulin": 0]),
            .watch("The pancreas releases insulin — keys that open the cells. Glucose moves in and blood sugar falls.",
                   "胰腺分泌胰岛素——像钥匙打开细胞，葡萄糖进入细胞，血糖回落。", set: ["insulin": 1]),
            .watch("Type 2 diabetes: cells resist insulin. Doors barely open, so sugar stays high.",
                   "2型糖尿病：细胞对胰岛素抵抗，门几乎打不开，血糖居高不下。", set: ["resistance": 0.7]),
            .tryIt("Your turn: add exercise — working muscles take up sugar even with little insulin. Get it under 7.8.",
                   "试一试：增加运动——肌肉运动时即使胰岛素不足也能摄取葡萄糖。把血糖降到 7.8 以下。", set: ["exercise": 0],
                   TryStep(mode: .scrub([Scrub(param: "exercise", label: "Exercise 运动", min: 0, max: 1)]),
                           success: { glucose($0) < 7.8 },
                           ok: Bilingual("Under 7.8 — exercise works alongside insulin.", "低于 7.8——运动与胰岛素协同降糖。"), demo: ["exercise": 1])),
            .tryIt("Free play: change the meal, insulin, resistance and exercise.", "自由探索：调节进食、胰岛素、抵抗和运动。",
                   TryStep(mode: .scrub([
                       Scrub(param: "meal", label: "Meal 进食", min: 0, max: 1),
                       Scrub(param: "insulin", label: "Insulin 胰岛素", min: 0, max: 1),
                       Scrub(param: "resistance", label: "Resistance 抵抗", min: 0, max: 1),
                       Scrub(param: "exercise", label: "Exercise 运动", min: 0, max: 1),
                   ]), success: { _ in true }, ok: Bilingual("Normal range after meals: under 7.8 mmol/L.", "餐后正常：低于 7.8 mmol/L。"))),
        ],
        draw: { s, p, t in
            let g = glucose(p)
            let level = g < 3.9 ? hex("#3F95D6") : g <= 7.8 ? hex("#2E9E5B") : g <= 11 ? hex("#E39B4B") : hex("#D8434B")
            let doorOpen = p[v: "insulin"] * (1 - p[v: "resistance"]) + p[v: "exercise"] * 0.5
            let flowing = doorOpen > 0.15 && g > 4.5
            let top = 40.0, bottom = 130.0
            s.rect(0, top, 360, bottom - top, fill: hex("#F7DADA"))
            s.line(0, top, 360, top, stroke: hex("#C0555F"), lw: 3)
            s.line(0, bottom, 360, bottom, stroke: hex("#C0555F"), lw: 3)
            s.text("Blood 血液 →", 8, top - 8, size: 11, color: hex("#8A3B45"))
            for i in 0..<Int((g * 4).rounded()) {
                let d = Double(i)
                s.circle((d * 73.3 + t * 28 * (0.7 + Double(i % 5) * 0.1)).wrap(380) - 10, top + 10 + (d * 37.7).wrap(70), 3.5, fill: hex("#F2B233"))
            }
            for i in 0..<Int((p[v: "insulin"] * 8).rounded()) {
                let x = (Double(i) * 47 + t * 22).wrap(380) - 10, y = top + 20 + (Double(i) * 29).wrap(50)
                s.path("M \(x) \(y - 5) L \(x + 5) \(y) L \(x) \(y + 5) L \(x - 5) \(y) Z", fill: hex("#3F7FD6"))
            }
            for cx in [60.0, 140, 220, 300] {
                let gap = 6 + doorOpen * 16
                s.path("M \(cx - gap) 170 A 34 34 0 1 0 \(cx + gap) 170", fill: hex("#E7F2DA"), stroke: hex("#6E9E4F"), lw: 3)
                if flowing {
                    for j in 0..<3 { s.circle(cx, bottom + (t * 30 + Double(j) * 14).wrap(42), 3, fill: hex("#F2B233")) }
                }
                let inside = Int((min(10, (1 - min(1, (g - 4) / 12)) * 10 * min(1, doorOpen + 0.2))).rounded())
                for j in 0..<max(0, inside) { s.circle(cx - 14 + Double(j % 4) * 9, 196 + Double(j / 4) * 9, 3, fill: hex("#F2B233")) }
            }
            s.text("Body cells 细胞 (doors open with insulin 胰岛素)", 8, 262, size: 11, color: hex("#4F7A38"))
            s.rect(214, 4, 142, 30, r: 8, fill: .white, stroke: level, lw: 2)
            s.text(String(format: "血糖 %.1f mmol/L", g), 285, 24, size: 14, color: level, anchor: .middle, bold: true)
            s.circle(20, 284, 4, fill: hex("#F2B233"))
            s.text("glucose 葡萄糖", 28, 288)
            s.path("M 120 279 L 125 284 L 120 289 L 115 284 Z", fill: hex("#3F7FD6"))
            s.text("insulin 胰岛素", 130, 288)
        },
        sources: ["WHO diabetes fact sheet; ADA Standards of Care (glucose targets)"]
    )
}
