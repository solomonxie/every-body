import SwiftUI

extension Illustrations {
    /// systolic / diastolic mmHg from heart rate, arterial stiffness and blood volume
    static func pressures(_ p: Params) -> (systolic: Double, diastolic: Double) {
        let hr = p[v: "hr"], st = p[v: "stiffness"], vol = p[v: "volume"]
        return (100 + 0.25 * (hr - 70) + 45 * st + 20 * vol, 65 + 0.2 * (hr - 70) + 15 * st + 10 * vol)
    }

    static let bloodPressure = Scenario(
        id: "blood-pressure", group: .blood, title: Bilingual("Blood pressure", "血压"),
        params: ["hr": 70, "stiffness": 0, "volume": 0.1],
        steps: [
            .watch("Each heartbeat pushes blood into the artery: pressure peaks (systolic), then falls (diastolic).",
                   "每次心跳把血液泵入动脉：压力先达峰值（收缩压），再回落（舒张压）。", set: ["hr": 70, "stiffness": 0, "volume": 0.1]),
            .watch("A faster heart raises pressure a little.", "心率加快，血压略升。", set: ["hr": 110]),
            .watch("With age and long-term high pressure, arteries stiffen. They can’t stretch, so the peak shoots up.",
                   "随年龄增长和长期高压，动脉变硬，无法扩张，收缩压明显升高。", set: ["hr": 70, "stiffness": 0.8]),
            .watch("Salt and extra fluid add volume — higher still.", "高盐和体液增多使血容量增加——血压更高。", set: ["volume": 0.9]),
            .tryIt("Bring it below 130/80: less salt (volume) and softer arteries (exercise, medicine).",
                   "试一试：降到 130/80 以下——少盐（容量）、改善血管弹性（运动、药物）。",
                   TryStep(mode: .scrub([Scrub(param: "volume", label: "Volume 血容量", min: 0, max: 1),
                                         Scrub(param: "stiffness", label: "Stiffness 血管硬化", min: 0, max: 1)]),
                           success: { let b = pressures($0); return b.systolic < 130 && b.diastolic < 80 },
                           ok: Bilingual("Below 130/80 — the normal range.", "低于 130/80——正常范围。"), demo: ["volume": 0.2, "stiffness": 0.3])),
            .tryIt("Free play: heart rate, stiffness, volume.", "自由探索：心率、血管硬化、血容量。",
                   TryStep(mode: .scrub([Scrub(param: "hr", label: "Heart rate 心率", min: 40, max: 180, unit: "bpm", digits: 0),
                                         Scrub(param: "stiffness", label: "Stiffness 血管硬化", min: 0, max: 1),
                                         Scrub(param: "volume", label: "Volume 血容量", min: 0, max: 1)]),
                           success: { _ in true }, ok: Bilingual("Normal: under 120/80. High: 140/90 or more.", "正常：低于 120/80；高血压：≥ 140/90。"))),
        ],
        draw: { s, p, t in
            let (sys, dia) = pressures(p)
            // arterial pulse: fast upstroke, systolic peak, dicrotic notch (aortic valve closing), diastolic run-off
            func wave(_ ph: Double) -> Double {
                if ph < 0.12 { return sin(ph / 0.12 * .pi / 2) }
                if ph < 0.34 { return 1 - 0.47 * (ph - 0.12) / 0.22 }
                let bump = ph < 0.46 ? 0.07 * sin((ph - 0.34) / 0.12 * .pi) : 0
                return 0.53 * exp(-(ph - 0.34) * 3) + bump
            }
            let hr = p[v: "hr"], stiff = p[v: "stiffness"]
            func at(_ time: Double) -> Double { dia + (sys - dia) * wave((time * hr / 60).wrap(1)) }
            let stretch = (at(t) - dia) / max(1, sys - dia)
            let radius = 42 + stretch * (12 * (1 - stiff) + 2), wall = 6 + 8 * stiff
            // 2017 ACC/AHA categories
            let cat: (String, Color) = sys >= 140 || dia >= 90 ? ("Stage 2 高血压2级", hex("#D8434B"))
                : sys >= 130 || dia >= 80 ? ("Stage 1 高血压1级", hex("#E0603C"))
                : sys >= 120 ? ("Elevated 血压偏高", hex("#E39B4B")) : ("Normal 正常", hex("#2E9E5B"))
            let x0 = 170.0, x1 = 352.0, y0 = 60.0, y1 = 230.0
            func yOf(_ mm: Double) -> Double { y1 - (mm - 40) / 160 * (y1 - y0) }

            s.circle(85, 145, radius + wall / 2 + 5, fill: hex("#F3DCC8"))                 // adventitia
            s.circle(85, 145, radius + wall / 2, fill: hex("#D9707A"))                     // media: smooth muscle
            s.circle(85, 145, radius - wall / 2 + 1.5, fill: hex("#F2C4CC"))               // intima
            s.circle(85, 145, radius - wall / 2, fill: hex("#C8323C"))
            s.text("blood 血", 85, 150, size: 11, color: .white, anchor: .middle)
            s.text("Artery cross-section", 85, 222, color: hex("#8A3B45"), anchor: .middle)
            s.text("动脉横截面 · intima · media · adventitia", 85, 236, size: 8, color: hex("#8A3B45"), anchor: .middle)
            s.text("dicrotic notch 重搏切迹", 262, yOf(dia + (sys - dia) * 0.5) - 28, size: 7)
            s.rect(x0, y0, x1 - x0, y1 - y0, fill: hex("#FAFAFC"), stroke: hex("#DDDDDD"))
            for mm in [80.0, 120, 140] {
                s.line(x0, yOf(mm), x1, yOf(mm), stroke: mm == 140 ? hex("#E8A7A7") : hex("#9CC9A8"), dash: [4, 3])
                s.text("\(Int(mm))", x0 - 4, yOf(mm) + 3, size: 9, color: hex("#777777"), anchor: .end)
            }
            var trace = Path()
            for i in 0...90 {
                let pt = CGPoint(x: x0 + Double(i) / 90 * (x1 - x0), y: yOf(at(t - 3 + Double(i) / 90 * 3)))
                if i == 0 { trace.move(to: pt) } else { trace.addLine(to: pt) }
            }
            s.shape(trace, stroke: hex("#C8323C"), lw: 2.5)
            s.text("last 3 s · mmHg", x0, y1 + 14, size: 9, color: hex("#777777"))
            s.rect(170, 6, 182, 44, r: 8, fill: .white, stroke: cat.1, lw: 2)
            s.text("\(Int(sys.rounded()))/\(Int(dia.rounded())) mmHg", 261, 26, size: 16, color: cat.1, anchor: .middle, bold: true)
            s.text("\(cat.0) · \(Int(hr.rounded())) bpm", 261, 42, color: cat.1, anchor: .middle)
            s.text("systolic 收缩压 = peak", 8, 20)
            s.text("diastolic 舒张压 = trough", 8, 34)
        },
        sources: ["2017 ACC/AHA and 2018 Chinese hypertension guideline categories"]
    )
}
