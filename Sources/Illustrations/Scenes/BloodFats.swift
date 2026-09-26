import SwiftUI

extension Illustrations {
    /// fraction of the radius blocked
    static func plaque(_ p: Params) -> Double { min(0.85, p[v: "ldl"] * p[v: "years"] / 40) }
    /// Poiseuille: at the same pressure, flow ∝ r⁴
    static func fatsFlow(_ p: Params) -> Double { p[v: "rupture"] > 0.5 ? 0 : pow(1 - plaque(p), 4) }

    static let bloodFats = Scenario(
        id: "blood-fats", group: .blood, title: Bilingual("Blood fats & plaque", "血脂与斑块"),
        params: ["ldl": 0.2, "years": 0, "rupture": 0],
        steps: [
            .watch("A healthy artery: smooth wall, blood flows freely.", "健康动脉：管壁光滑，血流通畅。", set: ["ldl": 0.2, "years": 0, "rupture": 0]),
            .watch("Too much LDL (“bad” cholesterol) in the blood seeps into the artery wall.", "血液中低密度脂蛋白（“坏”胆固醇）过多，渗入动脉壁。", set: ["ldl": 0.9, "years": 8]),
            .watch("Over years it builds a fatty plaque that narrows the channel.", "日积月累，形成粥样斑块，使管腔变窄。", set: ["years": 28]),
            .tryIt("Drag the years. Halve the radius and flow drops to 1/16 — flow ∝ r⁴.", "拖动年数。半径减半，血流降为 1/16——血流与半径的四次方成正比。",
                   TryStep(mode: .scrub([Scrub(param: "years", label: "Years 年", min: 0, max: 40, digits: 0)]), success: { plaque($0) >= 0.5 },
                           ok: Bilingual("Half-blocked: only ~6% of the flow at the same pressure.", "堵塞一半：同样压力下仅约 6% 的血流。"), demo: ["years": 30])),
            .tryIt("Lower LDL (diet, exercise, statins) and the plaque stops growing.", "降低 LDL（饮食、运动、他汀类药物），斑块停止增长。",
                   TryStep(mode: .scrub([Scrub(param: "ldl", label: "LDL 低密度脂蛋白", min: 0, max: 1)]), success: { $0[v: "ldl"] < 0.4 },
                           ok: Bilingual("Lower LDL, slower build-up.", "LDL 降低，斑块增长减慢。"), demo: ["ldl": 0.25])),
            .watch("If a plaque ruptures, a clot forms and can block the artery — a heart attack or stroke. Call 120/911.",
                   "斑块破裂可形成血栓，完全堵塞血管——心梗或中风。立即拨打 120。", set: ["ldl": 1, "years": 36, "rupture": 1]),
        ],
        draw: { s, p, t in
            let top = 90.0, bottom = 190.0, r = 50.0, mid = 140.0
            let pl = plaque(p), flow = fatsFlow(p)
            func lumen(_ x: Double) -> Double { let d = (x - 180) / 70; return r * (1 - pl * exp(-d * d * 2.5)) }
            s.rect(0, top - 14, 360, 14, fill: hex("#E8B4B8"))
            s.rect(0, bottom, 360, 14, fill: hex("#E8B4B8"))
            var channel = Path(), upper = Path(), lower = Path()
            upper.move(to: CGPoint(x: 0, y: top)); lower.move(to: CGPoint(x: 0, y: bottom))
            for i in 0...36 {
                let x = Double(i) * 10
                let pt = CGPoint(x: x, y: mid - lumen(x))
                if i == 0 { channel.move(to: pt) } else { channel.addLine(to: pt) }
                upper.addLine(to: pt)
                lower.addLine(to: CGPoint(x: x, y: mid + lumen(x)))
            }
            for i in 0...36 { let x = 360 - Double(i) * 10; channel.addLine(to: CGPoint(x: x, y: mid + lumen(x))) }
            channel.closeSubpath()
            upper.addLine(to: CGPoint(x: 360, y: top)); upper.closeSubpath()
            lower.addLine(to: CGPoint(x: 360, y: bottom)); lower.closeSubpath()
            s.shape(channel, fill: hex("#F7DADA"))
            if pl > 0.01 {
                s.shape(upper, fill: hex("#F2C94C"), opacity: 0.95)
                s.shape(lower, fill: hex("#F2C94C"), opacity: 0.95)
            }
            for i in 0..<22 {
                let x = (Double(i) * 41 + t * 60 * (0.15 + flow)).wrap(380) - 10
                let lane = (Double(i) * 0.37).wrap(1) * 1.6 - 0.8
                s.ellipse(x, mid + lane * lumen(x), 6, 3.5, fill: hex("#C8323C"))
            }
            for i in 0..<Int((p[v: "ldl"] * 14).rounded()) {
                let x = (Double(i) * 67 + t * 40 * (0.15 + flow)).wrap(380) - 10
                let lane = (Double(i) * 0.53).wrap(1) * 1.6 - 0.8
                s.circle(x, mid + lane * lumen(x), 3, fill: hex("#E8A21B"))
            }
            if p[v: "rupture"] > 0.5 { s.ellipse(190, mid, 34, lumen(180) + 2, fill: hex("#7A1F2B")) }
            s.line(10, mid, 40, mid, stroke: hex("#8A3B45"), lw: 2)
            s.path("M 40 \(mid - 5) L 48 \(mid) L 40 \(mid + 5) Z", fill: hex("#8A3B45"))
            s.rect(8, 6, 344, 52, r: 8, fill: .white, stroke: hex("#DDDDDD"))
            s.text("Plaque 斑块  \(Int((pl * 100).rounded()))% of radius", 20, 26, size: 12, color: hex("#8A6A1B"))
            s.text("Flow 血流  \(Int((flow * 100).rounded()))%   (∝ r⁴)", 20, 46, size: 12, color: flow < 0.3 ? hex("#D8434B") : hex("#2E9E5B"), bold: true)
            s.text("\(Int(p[v: "years"].rounded())) yrs 年", 340, 36, size: 11, anchor: .end)
            s.circle(20, 236, 4, fill: hex("#E8A21B")); s.text("LDL 低密度脂蛋白 (“bad” cholesterol)", 28, 240)
            s.ellipse(20, 256, 6, 3.5, fill: hex("#C8323C")); s.text("red blood cells 红细胞", 28, 260)
            s.rect(14, 270, 12, 8, fill: hex("#F2C94C")); s.text("fatty plaque 粥样斑块", 28, 278)
        },
        sources: ["WHO cardiovascular diseases fact sheet; Poiseuille’s law for flow vs radius"]
    )
}
