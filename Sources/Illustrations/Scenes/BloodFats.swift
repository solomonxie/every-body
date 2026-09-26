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
            .watch("Too much LDL (“bad” cholesterol) in the blood seeps under the artery lining, gets stuck and inflames it.",
                   "血液中低密度脂蛋白（“坏”胆固醇）过多，渗入动脉内膜下，滞留并引发炎症。", set: ["ldl": 0.9, "years": 8]),
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
                   "斑块帽破裂，几分钟内形成血栓，完全堵塞血管——心梗或中风。立即拨打 120。", set: ["ldl": 1, "years": 30, "rupture": 1]),
        ],
        draw: { s, p, t in drawBloodFats(&s, p, t) },
        sources: ["WHO cardiovascular diseases fact sheet; 2023 Chinese lipid management guideline (LDL-C < 3.4 mmol/L); Poiseuille’s law"]
    )

    static func bloodFats(for p: Profile) -> Scenario {
        var s = bloodFats
        switch p.age {
        case .infant, .toddler, .child:
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
        let pl = plaque(p), flow = fatsFlow(p), ldl = ldlLevel(p), ruptured = p[v: "rupture"] > 0.5, ldlP = p[v: "ldl"]
        let lipo = hex("#E8A21B")

        // top left: the lab report
        s.card(8, 6, 150, 100)
        s.caption("Lipid panel · mmol/L", "血脂化验 · mmol/L", 16, 19)
        let tg = 1.0 + 1.2 * ldlP, hdl = 1.3, tc = ldl + hdl + tg / 2.2
        let rows: [(String, String, Double, String, Bool)] = [
            ("LDL-C", "低密度脂蛋白", ldl, "< 3.4", ldl >= 3.4), ("Total", "总胆固醇", tc, "< 5.2", tc >= 5.2),
            ("HDL-C", "高密度脂蛋白", hdl, "≥ 1.0", false), ("TG", "甘油三酯", tg, "< 1.7", tg >= 1.7),
        ]
        for (i, row) in rows.enumerated() {
            let y = 36 + Double(i) * 17
            if i > 0 { s.line(16, y - 12, 150, y - 12, stroke: Tone.rule, lw: 0.6) }
            s.label(row.0, row.1, 16, y, size: 8, color: Tone.ink, bold: i == 0)
            s.text(String(format: "%.1f", row.2), 112, y, size: 9.5, color: row.4 ? Tone.red : Tone.ink, anchor: .end, bold: true)
            if row.4 { s.text("↑", 118, y, size: 8.5, color: Tone.red, bold: true) }
            s.text(row.3, 150, y, size: 6.5, color: Tone.faint, anchor: .end)
        }

        // top middle: age, narrowing, flow
        s.card(164, 6, 88, 100)
        let age = p[v: "age0"] + p[v: "years"]
        s.caption("Age", "年龄", 172, 19)
        s.text("\(Int(age.rounded()))", 172, 42, size: 20, color: Tone.ink, bold: true)
        let narrowColor = pl > 0.5 ? Tone.red : pl > 0.2 ? Tone.amber : Tone.green
        s.label("narrowed", "狭窄", 172, 60, size: 7.5, color: Tone.sub)
        s.text("\(Int((pl * 100).rounded()))%", 244, 60, size: 8.5, color: narrowColor, anchor: .end, bold: true)
        s.meterBar(172, 64, 72, pl, color: narrowColor, h: 5)
        let flowColor = flow < 0.3 ? Tone.red : flow < 0.7 ? Tone.amber : Tone.green
        s.label("blood flow", "血流", 172, 84, size: 7.5, color: Tone.sub)
        s.text("\(Int((flow * 100).rounded()))%", 244, 84, size: 8.5, color: flowColor, anchor: .end, bold: true)
        s.meterBar(172, 88, 72, flow, color: flowColor, h: 5)

        // top right: the heart, and which artery we are looking into
        let hk = 0.42, ho = CGPoint(x: 268, y: 10)
        s.group(translate: ho, scale: hk) { g in
            g.heartFront(zone: ruptured ? 1 : 0, dead: 0, clot: ruptured, t: t)
        }
        let spot = CGPoint(x: ho.x + 124 * hk, y: ho.y + 130 * hk)
        let mid = 184.0, r = 38.0, lumenTop = mid - r, lumenBottom = mid + r
        s.circle(spot.x, spot.y, 6, stroke: Tone.ink, lw: 1.4)
        s.circle(spot.x, spot.y, 6, stroke: .white, lw: 0.6)

        // the artery, cut lengthwise: outer coat · muscle · lining; plaque grows under the lining of the upper wall
        func edge(_ x: Double) -> Double { let d = (x - 180) / 78; return lumenTop + 2 * r * pl * exp(-d * d * 2.2) }
        var sec = s.clipped(8, lumenTop - 28, 344, 2 * r + 56)
        sec.rect(8, lumenTop - 28, 344, 2 * r + 56, fill: hex("#F3DCC8"))
        for (y0, dir) in [(lumenTop, -1.0), (lumenBottom, 1.0)] {
            let media = dir < 0 ? y0 - 16 : y0 + 4
            sec.shade(Path(CGRect(x: 8, y: media, width: 344, height: 12)), hex("#D86A74"), hex("#B84B56"), vertical: true)
            for k in 0..<30 { sec.path("M \(10 + Double(k) * 12) \(media + 3) q 5 3 10 0 M \(14 + Double(k) * 12) \(media + 8) q 5 3 10 0", stroke: hex("#E99AA2"), lw: 0.6) }
            sec.rect(8, dir < 0 ? y0 - 4 : y0, 344, 4, fill: hex("#F6D0D5"))
            for k in 0..<22 { sec.path("M \(12 + Double(k) * 16) \(dir < 0 ? y0 - 20 : y0 + 20) q 4 -2 8 0", stroke: hex("#E2BFA4"), lw: 0.7) }
        }
        var channel = Path(), core = Path(), cap = Path()
        channel.move(to: CGPoint(x: 8, y: edge(8)))
        core.move(to: CGPoint(x: 8, y: lumenTop))
        for i in 0...86 {
            let x = 8 + Double(i) * 4, pt = CGPoint(x: x, y: edge(x))
            channel.addLine(to: pt); core.addLine(to: pt)
            if i == 0 { cap.move(to: pt) } else { cap.addLine(to: pt) }
        }
        channel.addLine(to: CGPoint(x: 352, y: lumenBottom)); channel.addLine(to: CGPoint(x: 8, y: lumenBottom)); channel.closeSubpath()
        core.addLine(to: CGPoint(x: 352, y: lumenTop)); core.closeSubpath()
        sec.shade(channel, hex("#F8E0E0"), hex("#F0C8CA"), vertical: true)
        if pl > 0.01 {
            sec.shade(core, hex("#F6D77A"), hex("#E7B548"), vertical: true)
            // cholesterol crystals and foam cells (immune cells stuffed with fat)
            for i in 0..<Int((pl * 18).rounded()) {
                let x = 180 + ((Double(i) * 0.618).wrap(1) - 0.5) * 120, top = lumenTop + 2
                let room = edge(x) - top
                guard room > 9 else { continue }
                let y = top + 3 + (Double(i) * 0.37).wrap(1) * (room - 9)
                if i % 3 == 0 {
                    sec.path("M \(x - 4) \(y) L \(x + 4) \(y - 2) L \(x + 3) \(y + 1) Z", fill: hex("#FFF6D8"), stroke: hex("#D9B25A"), lw: 0.5)
                } else {
                    sec.circle(x, y, 3.4, fill: hex("#FBEBB5"), stroke: hex("#D9A441"), lw: 0.7)
                    for k in 0..<3 { sec.circle(x - 1.2 + Double(k), y - 0.6 + Double(k % 2), 0.7, fill: hex("#E7B548")) }
                }
            }
            sec.shape(cap, stroke: hex("#F4E8E0"), lw: 3.2 - 1.2 * pl)
            sec.shape(cap, stroke: hex("#E2C7BE"), lw: 0.6)
        } else {
            sec.shape(cap, stroke: hex("#F6D0D5"), lw: 1)
        }
        // blood: red cells, and LDL particles; some slip under the lining
        let speed = ruptured ? 0 : 0.15 + flow
        for i in 0..<18 {
            let x = (Double(i) * 41 + t * 60 * speed).wrap(370) - 5
            let u = (Double(i) * 0.37).wrap(1) * 0.8 + 0.1
            let y = edge(x) + u * (lumenBottom - edge(x))
            sec.ellipse(x, y, 5.5, 3.2, fill: hex("#C8323C"))
            sec.ellipse(x, y, 2.4, 1.2, fill: hex("#A82834"))
        }
        let n = Int((ldlP * 12).rounded())
        for i in 0..<n {
            let x = (Double(i) * 67 + t * 40 * speed).wrap(370) - 5
            let u = (Double(i) * 0.53).wrap(1) * 0.8 + 0.1
            sec.circle(x, edge(x) + u * (lumenBottom - edge(x)), 2.6, fill: lipo, stroke: .white, lw: 0.5)
        }
        if ldlP > 0.5 && !ruptured {
            for i in 0..<3 {
                let u = (t * 0.35 + Double(i) / 3).wrap(1), x = 140 + Double(i) * 38
                sec.circle(x, edge(x) + 14 - u * 22, 2.6, fill: lipo, stroke: .white, lw: 0.5, opacity: 1 - u * 0.5)
            }
        }
        if ruptured {
            // cracked cap, clot (fibrin mesh, platelets, trapped red cells) filling the channel
            let cy = lumenBottom - 8.0
            sec.path("M 168 \(edge(168) - 2) L 175 \(edge(175) + 5) L 181 \(edge(181) - 3) L 187 \(edge(187) + 4)", stroke: hex("#7A1F2B"), lw: 2)
            var clot = Path()
            clot.move(to: CGPoint(x: 160, y: edge(160) + 1))
            for i in 1...30 { let x = 160 + Double(i) * 3; clot.addLine(to: CGPoint(x: x, y: edge(x) + 1)) }
            clot.addCurve(to: CGPoint(x: 246, y: lumenBottom), control1: CGPoint(x: 268, y: edge(250) + 10), control2: CGPoint(x: 266, y: lumenBottom - 2))
            clot.addLine(to: CGPoint(x: 172, y: lumenBottom))
            clot.addCurve(to: CGPoint(x: 160, y: edge(160) + 1), control1: CGPoint(x: 150, y: lumenBottom - 4), control2: CGPoint(x: 150, y: edge(160) + 12))
            clot.closeSubpath()
            sec.shade(clot, hex("#A42E3C"), hex("#6A1622"), vertical: true)
            var mesh = sec.clipped(to: clot)
            for k in 0..<8 { mesh.ellipse(166 + Double(k) * 11, lumenBottom - 8 - Double(k % 3) * 7, 5, 3, fill: hex("#C23A4A")) }
            for k in 0..<9 { mesh.line(150 + Double(k) * 13, lumenBottom, 170 + Double(k) * 13, lumenTop, stroke: hex("#E9D8C0"), lw: 0.6) }
            for k in 0..<9 { mesh.line(150 + Double(k) * 13, lumenTop, 170 + Double(k) * 13, lumenBottom, stroke: hex("#E9D8C0"), lw: 0.5) }
            for k in 0..<5 { mesh.circle(172 + Double(k) * 15, lumenBottom - 6 - Double(k % 2) * 8, 1.6, fill: hex("#E6C8D8")) }
            s.callout("clot blocks the artery", "血栓堵塞血管", at: CGPoint(x: 220, y: cy + 2), 262, lumenBottom + 40, color: hex("#7A1F2B"), size: 8)
        }
        s.pointer(CGPoint(x: 18, y: lumenBottom - 12), CGPoint(x: 42, y: lumenBottom - 12), color: hex("#8A3B45"), lw: 1.6)
        s.label("blood flow", "血流", 46, lumenBottom - 9, size: 7.5, color: hex("#8A3B45"))

        s.caption("Heart artery, cut lengthwise", "冠状动脉纵切面", 16, lumenTop - 19, color: hex("#9A6A5A"))
        // wall layer names under the lower wall, plaque parts beside it
        let lb = lumenBottom
        s.callout("lining", "内膜", at: CGPoint(x: 40, y: lb + 2), 14, lb + 40, color: Tone.label, size: 7.5)
        s.callout("muscle layer", "中膜（平滑肌）", at: CGPoint(x: 80, y: lb + 10), 58, lb + 40, color: Tone.label, size: 7.5)
        s.callout("outer coat", "外膜", at: CGPoint(x: 140, y: lb + 22), 148, lb + 40, color: Tone.label, size: 7.5)
        if pl > 0.15 && !ruptured {
            let py = (lumenTop + edge(180)) / 2
            if edge(180) - lumenTop > 26 {
                s.label("fatty core", "脂质核心", 180, py + 3, size: 8, color: hex("#7A5A12"), anchor: .middle, bold: true)
                s.callout("thin cap", "薄纤维帽", at: CGPoint(x: 236, y: edge(236) - 1), 258, edge(236) + 14, color: hex("#8A6A1B"), size: 8)
            } else {
                s.callout("fatty plaque", "粥样斑块", at: CGPoint(x: 196, y: lumenTop + 3), 236, lumenTop + 16, color: hex("#8A6A1B"), size: 8)
            }
        }

        // legend
        let lg = 292.0
        s.circle(14, lg - 3, 2.6, fill: lipo, stroke: .white, lw: 0.5); s.label("LDL cholesterol", "低密度脂蛋白", 20, lg, size: 8, color: Tone.sub)
        s.ellipse(104, lg - 3, 5, 3, fill: hex("#C8323C")); s.label("red cell", "红细胞", 112, lg, size: 8, color: Tone.sub)
        s.circle(166, lg - 3, 3.4, fill: hex("#FBEBB5"), stroke: hex("#D9A441"), lw: 0.7); s.label("foam cell", "泡沫细胞", 173, lg, size: 8, color: Tone.sub)
    }
}
