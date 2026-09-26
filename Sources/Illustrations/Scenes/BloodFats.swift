import SwiftUI

extension Illustrations {
    /// fraction of the channel blocked
    static func plaque(_ p: Params) -> Double { min(0.85, p[v: "ldl"] * p[v: "years"] / 40) }
    /// Poiseuille: at the same pressure, flow ∝ r⁴
    static func fatsFlow(_ p: Params) -> Double { p[v: "rupture"] > 0.5 ? 0 : pow(1 - plaque(p), 4) }
    /// lipid panel, mmol/L
    static func ldlLevel(_ p: Params) -> Double { 1.8 + 3.4 * p[v: "ldl"] }

    static let bloodFats = Scenario(
        id: "blood-fats", group: .blood, title: Bilingual("Blood fats & plaque", "血脂与斑块"),
        params: ["ldl": 0.2, "years": 0, "rupture": 0, "age0": 30],
        steps: [
            .watch("A healthy heart artery: smooth lining, blood flows freely. The blood test (lipid panel) is in range.",
                   "健康的冠状动脉：内壁光滑，血流通畅。血脂化验在正常范围。", set: ["ldl": 0.2, "years": 0, "rupture": 0]),
            .watch("Too much LDL (“bad” cholesterol) in the blood seeps into the artery wall, gets stuck and inflames it.",
                   "血液中低密度脂蛋白（“坏”胆固醇）过多，渗入动脉壁，滞留并引发炎症。", set: ["ldl": 0.9, "years": 8]),
            .watch("Over decades it builds a fatty plaque under a thin cap. The channel narrows — usually with no symptoms.",
                   "几十年间形成粥样斑块，表面只有一层薄帽，管腔变窄——通常没有任何症状。", set: ["years": 28]),
            .tryIt("Drag the years. Halve the radius and flow drops to 1/16 — flow ∝ r⁴.", "拖动年数。半径减半，血流降为 1/16——血流与半径的四次方成正比。",
                   TryStep(mode: .scrub([Scrub(param: "years", label: "Years 年", min: 0, max: 40, digits: 0)]), success: { plaque($0) >= 0.5 },
                           ok: Bilingual("Half-blocked: only ~6% of the flow at the same pressure.", "堵塞一半：同样压力下仅约 6% 的血流。"), demo: ["years": 30])),
            .tryIt("Lower LDL (less saturated fat, exercise, statins) and the plaque stops growing. Get LDL under 3.4.",
                   "降低 LDL（少吃饱和脂肪、运动、他汀类药物），斑块停止增长。把 LDL 降到 3.4 以下。",
                   TryStep(mode: .scrub([Scrub(param: "ldl", label: "LDL 低密度脂蛋白", min: 0, max: 1)]), success: { ldlLevel($0) < 3.4 },
                           ok: Bilingual("LDL in range — slower build-up.", "LDL 达标——斑块增长减慢。"), demo: ["ldl": 0.25])),
            .watch("If the cap cracks, a clot forms on it within minutes and can block the artery — a heart attack or stroke. Call 120/911.",
                   "斑块帽破裂，几分钟内形成血栓，完全堵塞血管——心梗或中风。立即拨打 120。", set: ["ldl": 1, "years": 36, "rupture": 1]),
        ],
        draw: { s, p, t in drawBloodFats(&s, p, t) },
        sources: ["WHO cardiovascular diseases fact sheet; 2023 Chinese lipid management guideline (LDL-C < 3.4 mmol/L); Poiseuille’s law"]
    )

    static func bloodFats(for p: Profile) -> Scenario {
        var s = bloodFats
        switch p.age {
        case .infant, .child:
            s.profileNote = Bilingual("Children: check cholesterol once at 9–11, earlier if a parent has very high cholesterol or had an early heart attack (familial).",
                                      "儿童：9–11 岁查一次血脂；父母胆固醇很高或早发心梗（家族性）应更早检查。")
            return s.rebased(["age0": 10])
        case .senior:
            s.profileNote = Bilingual("65+: plaque reflects decades of LDL. Statins still cut heart attacks and strokes — don't stop them without asking.",
                                      "65 岁以上：斑块是几十年 LDL 累积的结果。他汀仍能减少心梗和中风——不要自行停药。")
            return s.rebased(["age0": 45])
        case .adult where p.isPregnant:
            s.profileNote = Bilingual("Pregnant: cholesterol normally rises in pregnancy — tests aren't read the usual way, and statins are stopped.",
                                      "孕妇：孕期胆固醇生理性升高——化验结果不按常规解读，他汀类药物需停用。")
        case .adult: break
        }
        return s
    }

    @MainActor private static func drawBloodFats(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let pl = plaque(p), flow = fatsFlow(p), ldl = ldlLevel(p), ruptured = p[v: "rupture"] > 0.5
        let ink = hex("#555555"), fat = hex("#F2C94C"), lipo = hex("#E8A21B")
        let mid = 184.0, r = 44.0, lumenTop = mid - r, lumenBottom = mid + r
        /// top edge of the channel: an eccentric plaque grows down from the upper wall
        func edge(_ x: Double) -> Double { let d = (x - 180) / 80; return lumenTop + 2 * r * pl * exp(-d * d * 2.2) }

        // wall layers, top and bottom: intima · media · adventitia
        for (y, dir) in [(lumenTop, -1.0), (lumenBottom, 1.0)] {
            s.rect(0, dir < 0 ? y - 22 : y + 12, 360, 10, fill: hex("#F3DCC8"))
            s.rect(0, dir < 0 ? y - 12 : y + 4, 360, 8, fill: hex("#D9707A"))
            s.rect(0, dir < 0 ? y - 4 : y, 360, 4, fill: hex("#F2C4CC"))
        }
        var channel = Path(), core = Path()
        channel.move(to: CGPoint(x: 0, y: edge(0)))
        core.move(to: CGPoint(x: 0, y: lumenTop))
        for i in 0...36 {
            let x = Double(i) * 10
            channel.addLine(to: CGPoint(x: x, y: edge(x)))
            core.addLine(to: CGPoint(x: x, y: edge(x)))
        }
        channel.addLine(to: CGPoint(x: 360, y: lumenBottom)); channel.addLine(to: CGPoint(x: 0, y: lumenBottom)); channel.closeSubpath()
        core.addLine(to: CGPoint(x: 360, y: lumenTop)); core.closeSubpath()
        s.shape(channel, fill: hex("#F7DADA"))
        if pl > 0.01 {
            s.shape(core, fill: fat)
            // foam cells: immune cells stuffed with cholesterol
            for i in 0..<Int((pl * 14).rounded()) {
                let x = 180 + (Double(i) * 0.61).wrap(1) * 110 - 55, top = lumenTop + 3
                let y = top + ((Double(i) * 0.37).wrap(1) * 0.8 + 0.1) * (edge(x) - top)
                if edge(x) - top > 8 { s.circle(x, y, 3.5, fill: hex("#F7E3A1"), stroke: hex("#D9A441"), lw: 0.8) }
            }
            var cap = Path()
            for i in 0...36 { let x = Double(i) * 10, pt = CGPoint(x: x, y: edge(x)); if i == 0 { cap.move(to: pt) } else { cap.addLine(to: pt) } }
            s.shape(cap, stroke: hex("#F4EDE0"), lw: 3)
        }
        // blood: red cells, and LDL particles — some slip into the wall
        for i in 0..<20 {
            let x = (Double(i) * 41 + t * 60 * (ruptured ? 0 : 0.15 + flow)).wrap(380) - 10
            let u = (Double(i) * 0.37).wrap(1) * 0.8 + 0.1
            s.ellipse(x, edge(x) + u * (lumenBottom - edge(x)), 5.5, 3.2, fill: hex("#C8323C"))
        }
        let n = Int((p[v: "ldl"] * 12).rounded())
        for i in 0..<n {
            let x = (Double(i) * 67 + t * 40 * (ruptured ? 0 : 0.15 + flow)).wrap(380) - 10
            let u = (Double(i) * 0.53).wrap(1) * 0.8 + 0.1
            s.circle(x, edge(x) + u * (lumenBottom - edge(x)), 2.6, fill: lipo)
        }
        if p[v: "ldl"] > 0.5 && !ruptured {
            for i in 0..<3 {
                let u = (t * 0.35 + Double(i) / 3).wrap(1), x = 150 + Double(i) * 28
                s.circle(x, edge(x) + 14 - u * 20, 2.6, fill: lipo, opacity: 1 - u * 0.5)
            }
        }
        if ruptured {
            s.path("M 172 \(edge(172) - 2) L 178 \(edge(178) + 4) L 184 \(edge(184) - 3)", stroke: hex("#7A1F2B"), lw: 2)
            let cy = (edge(180) + lumenBottom) / 2, ry = (lumenBottom - edge(180)) / 2 + 1
            s.ellipse(184, cy, 44, ry, fill: hex("#7A1F2B"))
            for k in 0..<5 { s.ellipse(154 + Double(k) * 15, cy + (k % 2 == 0 ? -2 : 3), 5, 3, fill: hex("#A8283A")) }
            for k in 0..<4 { s.line(146 + Double(k) * 18, cy - ry + 2, 160 + Double(k) * 18, cy + ry - 2, stroke: hex("#E9D8C0"), lw: 0.8) }
            s.label("clot", "血栓", 186, (edge(180) + lumenBottom) / 2 + 4, size: 10, color: .white, anchor: .middle, bold: true)
        }
        s.path("M 10 \(lumenBottom - 10) L 34 \(lumenBottom - 10) M 28 \(lumenBottom - 15) L 34 \(lumenBottom - 10) L 28 \(lumenBottom - 5)", stroke: hex("#8A3B45"), lw: 2)
        s.label("wall: lining · muscle · outer coat", "管壁：内膜 · 中膜 · 外膜", 8, lumenTop - 26, size: 8, color: hex("#8A3B45"))
        if pl > 0.15 { s.label("fatty plaque", "粥样斑块", 250, lumenTop + 12, size: 9, color: hex("#8A6A1B"), bold: true) }
        if pl > 0.3 && !ruptured { s.label("thin cap", "纤维帽", 236, edge(236) + 12, size: 8, color: hex("#8A6A1B")) }

        // lipid panel
        let flag: (Double, Double, Double) -> Color = { v, hi, veryHi in v >= veryHi ? hex("#D8434B") : v >= hi ? hex("#E39B4B") : hex("#2E9E5B") }
        let tg = 1.0 + 1.2 * p[v: "ldl"], hdl = 1.3, tc = ldl + hdl + tg / 2.2
        s.rect(8, 6, 150, 116 - 30, r: 6, fill: .white, stroke: hex("#BBBBBB"))
        s.label("Lipid panel  mmol/L", "血脂化验  mmol/L", 16, 20, size: 9, color: ink, bold: true)
        let rows: [(String, String, Double, Color)] = [
            ("LDL-C", "低密度脂蛋白", ldl, flag(ldl, 3.4, 4.1)), ("TC", "总胆固醇", tc, flag(tc, 5.2, 6.2)),
            ("HDL-C", "高密度脂蛋白", hdl, hex("#2E9E5B")), ("TG", "甘油三酯", tg, flag(tg, 1.7, 2.3)),
        ]
        for (i, row) in rows.enumerated() {
            let y = 36 + Double(i) * 14
            s.label(row.0, row.1, 16, y, size: 9, color: ink, bold: i == 0)
            s.text(String(format: "%.1f", row.2), 150, y, size: 10, color: row.3, anchor: .end, bold: true)
        }

        // age and where this artery is
        let age = p[v: "age0"] + p[v: "years"]
        s.label("Age \(Int(age.rounded()))", "\(Int(age.rounded())) 岁", 212, 34, size: 18, color: hex("#333333"), anchor: .middle, bold: true)
        s.label("narrowed \(Int((pl * 100).rounded()))%", "狭窄 \(Int((pl * 100).rounded()))%", 212, 54, size: 10, color: hex("#8A6A1B"), anchor: .middle)
        s.label("flow \(Int((flow * 100).rounded()))%", "血流 \(Int((flow * 100).rounded()))%", 212, 70, size: 11,
                color: flow < 0.3 ? hex("#D8434B") : hex("#2E9E5B"), anchor: .middle, bold: true)
        let hc = CGPoint(x: 312, y: 50)
        s.path("M \(hc.x) \(hc.y + 38) C \(hc.x - 30) \(hc.y + 18) \(hc.x - 40) \(hc.y - 4) \(hc.x - 28) \(hc.y - 22) C \(hc.x - 18) \(hc.y - 34) \(hc.x - 4) \(hc.y - 30) \(hc.x) \(hc.y - 20) "
               + "C \(hc.x + 4) \(hc.y - 32) \(hc.x + 24) \(hc.y - 36) \(hc.x + 32) \(hc.y - 20) C \(hc.x + 40) \(hc.y - 4) \(hc.x + 28) \(hc.y + 18) \(hc.x) \(hc.y + 38) Z",
               fill: hex("#C8323C"), stroke: hex("#7A1F2B"), lw: 1.5)
        s.path("M \(hc.x - 2) \(hc.y - 18) C \(hc.x + 4) \(hc.y) \(hc.x + 6) \(hc.y + 16) \(hc.x + 2) \(hc.y + 32)", stroke: hex("#F2D060"), lw: 2.5, cap: .round)
        s.circle(hc.x + 5, hc.y + 6, 8, stroke: ink, lw: 1.2)
        s.line(hc.x + 1, hc.y + 13, 290, lumenTop - 24, stroke: ink, lw: 0.8, dash: [3, 2])
        s.label("heart artery", "冠状动脉", hc.x - 34, 98, size: 8, color: ink, anchor: .end)

        // legend
        let ly = 282.0
        s.circle(14, ly - 3, 2.6, fill: lipo); s.label("LDL", "低密度脂蛋白", 20, ly, size: 9, color: ink)
        s.ellipse(122, ly - 3, 5.5, 3.2, fill: hex("#C8323C")); s.label("red cells", "红细胞", 130, ly, size: 9, color: ink)
        s.rect(214, ly - 8, 10, 8, fill: fat); s.label("fatty plaque", "粥样斑块", 228, ly, size: 9, color: ink)
    }
}
