import SwiftUI

extension Illustrations {
    /// systolic / diastolic mmHg from heart rate, arterial stiffness and blood volume
    static func pressures(_ p: Params) -> (systolic: Double, diastolic: Double) {
        let hr = p[v: "hr"], st = p[v: "stiffness"], vol = p[v: "volume"]
        return (100 + 0.25 * (hr - 70) + 45 * st + 20 * vol, 65 + 0.2 * (hr - 70) + 15 * st + 10 * vol)
    }

    static let bloodPressure = Scenario(
        id: "blood-pressure", group: .blood, title: Bilingual("Blood pressure", "血压"),
        params: ["hr": 70, "stiffness": 0, "volume": 0.1, "tips": 1, "kid": 0, "pregnant": 0, "senior": 0],
        steps: [
            .watch("Measure it right: sit quietly 5 min, back supported, feet flat, cuff on the bare upper arm at heart level.",
                   "正确测量：安静坐 5 分钟，背有依靠，双脚平放，袖带绑在裸露的上臂、与心脏同高。", set: ["hr": 70, "stiffness": 0, "volume": 0.1, "tips": 1]),
            .watch("Each heartbeat pushes blood into the arteries and stretches their walls: the peak is the top number (systolic), the low between beats the bottom (diastolic).",
                   "每次心跳把血液泵入动脉、撑开管壁：峰值是上面的数（收缩压），两次心跳间的低谷是下面的数（舒张压）。", set: ["tips": 0]),
            .watch("Rushing, coffee or stress speed the heart and raise the reading a little — that's why you rest first.",
                   "赶路、喝咖啡或紧张会让心跳加快、读数略升——所以测量前要先休息。", set: ["hr": 110]),
            .watch("With age and years of high pressure, arteries stiffen. They can't stretch, so the top number shoots up.",
                   "随年龄增长和长期高压，动脉变硬，无法扩张，收缩压明显升高。", set: ["hr": 70, "stiffness": 0.8]),
            .watch("Salty food holds extra fluid in the blood — more volume, higher still.", "高盐饮食使体内水分增多——血容量增加，血压更高。", set: ["volume": 0.9]),
            .tryIt("Your turn: bring it below 130/80 — less salt (volume) and softer arteries (exercise, medicine).",
                   "试一试：降到 130/80 以下——少盐（容量）、改善血管弹性（运动、药物）。",
                   TryStep(mode: .scrub([Scrub(param: "volume", label: "Salt & fluid 盐与血容量", min: 0, max: 1),
                                         Scrub(param: "stiffness", label: "Stiffness 血管硬化", min: 0, max: 1)]),
                           success: { let b = pressures($0); return b.systolic < 130 && b.diastolic < 80 },
                           ok: Bilingual("Below 130/80 — the healthy range.", "低于 130/80——健康范围。"), demo: ["volume": 0.2, "stiffness": 0.3])),
            .tryIt("Free play: heart rate, stiffness, volume.", "自由探索：心率、血管硬化、血容量。",
                   TryStep(mode: .scrub([Scrub(param: "hr", label: "Heart rate 心率", min: 40, max: 180, unit: "bpm", digits: 0),
                                         Scrub(param: "stiffness", label: "Stiffness 血管硬化", min: 0, max: 1),
                                         Scrub(param: "volume", label: "Volume 血容量", min: 0, max: 1)]),
                           success: { _ in true }, ok: Bilingual("Normal: under 120/80. High: 140/90 or more.", "正常：低于 120/80；高血压：≥ 140/90。"))),
        ],
        draw: { s, p, t in drawBloodPressure(&s, p, t) },
        sources: ["2017 ACC/AHA and 2018 Chinese hypertension guideline categories; AHA home-measurement technique"]
    )

    @MainActor private static func drawBloodPressure(_ s: inout Sketch, _ p: Params, _ t: Double) {
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
        // 2017 ACC/AHA categories
        let cat: (String, String, Color) = sys >= 140 || dia >= 90 ? ("High · stage 2", "高血压 2 级", hex("#D8434B"))
            : sys >= 130 || dia >= 80 ? ("High · stage 1", "高血压 1 级", hex("#E0603C"))
            : sys >= 120 ? ("Elevated", "血压偏高", hex("#E39B4B")) : ("Normal", "正常", hex("#2E9E5B"))
        let ink = hex("#555555"), kid = p[v: "kid"] > 0.5

        // seated person, arm resting on the table, cuff on the upper arm
        let h = kid ? 170.0 : 210.0, floor = 276.0
        let hip = CGPoint(x: 62, y: floor - 0.245 * h * cos(32 * .pi / 180) - 5)
        var person = Person(h: h, shirt: p[v: "pregnant"] > 0.5 ? hex("#E8B4C8") : hex("#8FB3E0"),
                            shirtLine: p[v: "pregnant"] > 0.5 ? hex("#B77A95") : hex("#5F87B8"), hip: 90, knee: 58)
        let table = hip.y - 0.1 * h
        person.aimHand(at: CGPoint(x: 0.24 * h, y: table - hip.y - 0.03 * h))
        s.line(0, floor, 360, floor, stroke: hex("#BBBBBB"), lw: 2)
        // chair
        s.rect(hip.x - 22, hip.y + 0.035 * h, 60, 6, r: 2, fill: hex("#B08A64"))
        s.rect(hip.x - 24, hip.y - 0.3 * h, 7, 0.3 * h + 10, r: 2, fill: hex("#B08A64"))
        s.line(hip.x - 18, hip.y + 0.035 * h + 6, hip.x - 18, floor, stroke: hex("#9B7550"), lw: 4)
        s.line(hip.x + 32, hip.y + 0.035 * h + 6, hip.x + 32, floor, stroke: hex("#9B7550"), lw: 4)
        person.draw(&s, at: hip, farArm: false)
        if p[v: "senior"] > 0.5 {
            s.path("M \(hip.x - 0.045 * h) \(hip.y - 0.47 * h) C \(hip.x - 0.02 * h) \(hip.y - 0.5 * h) \(hip.x + 0.04 * h) \(hip.y - 0.5 * h) \(hip.x + 0.07 * h) \(hip.y - 0.465 * h)",
                   stroke: hex("#BDBDBD"), lw: 0.02 * h, cap: .round)
        }
        if p[v: "pregnant"] > 0.5 { s.ellipse(hip.x + 0.06 * h, hip.y - 0.07 * h, 0.05 * h, 0.075 * h, fill: person.shirt, stroke: person.shirtLine, lw: 1.5) }
        // upper arm cuff with its tube
        let sa = person.shoulder * .pi / 180, sh = CGPoint(x: hip.x, y: hip.y - 0.29 * h)
        let e = CGPoint(x: sh.x + sin(sa) * 0.17 * h, y: sh.y + cos(sa) * 0.17 * h)
        let c0 = CGPoint(x: sh.x + (e.x - sh.x) * 0.25, y: sh.y + (e.y - sh.y) * 0.25), c1 = CGPoint(x: sh.x + (e.x - sh.x) * 0.8, y: sh.y + (e.y - sh.y) * 0.8)
        let squeeze = 0.07 * h + 1.5 * stretch
        s.line(c0.x, c0.y, c1.x, c1.y, stroke: hex("#46546F"), lw: squeeze, cap: .round)
        s.line(c0.x, c0.y, c1.x, c1.y, stroke: hex("#5B6B8C"), lw: squeeze - 3, cap: .round)
        let monitor = CGRect(x: 128, y: table - 50, width: 86, height: 50)
        s.path("M \(c1.x + 2) \(c1.y) C \(c1.x + 30) \(c1.y + 30) \(monitor.minX - 20) \(monitor.midY + 20) \(monitor.minX) \(monitor.midY + 6)",
               stroke: hex("#46546F"), lw: 2)
        // table and monitor
        s.rect(100, table, 118, 8, r: 2, fill: hex("#C9A27A"), stroke: hex("#9B7550"))
        s.line(206, table + 8, 206, floor, stroke: hex("#9B7550"), lw: 5)
        s.rect(monitor.minX, monitor.minY, monitor.width, monitor.height, r: 8, fill: hex("#F2F4F7"), stroke: hex("#9AA3AE"), lw: 1.5)
        s.rect(monitor.minX + 6, monitor.minY + 5, monitor.width - 12, monitor.height - 10, r: 3, fill: hex("#DDE8DA"))
        let lx = monitor.minX + 10, rx = monitor.maxX - 10
        s.text("SYS", lx, monitor.minY + 17, size: 7, color: ink)
        s.text("\(Int(sys.rounded()))", rx, monitor.minY + 20, size: 15, color: cat.2, anchor: .end, bold: true)
        s.text("DIA", lx, monitor.minY + 34, size: 7, color: ink)
        s.text("\(Int(dia.rounded()))", rx, monitor.minY + 37, size: 15, color: cat.2, anchor: .end, bold: true)
        s.text("♥ \(Int(hr.rounded()))", lx, monitor.minY + 41, size: 7, color: hex("#C8323C").opacity(0.4 + 0.6 * stretch))
        s.label("cuff", "袖带", c1.x + 6, c1.y - 26, size: 8, color: hex("#46546F"), bold: true)

        // category banner and measuring tips
        s.rect(8, 6, 206, 40, r: 8, fill: .white, stroke: cat.2, lw: 2)
        s.text("\(Int(sys.rounded()))/\(Int(dia.rounded())) mmHg", 111, 24, size: 15, color: cat.2, anchor: .middle, bold: true)
        s.label(cat.0, cat.1, 111, 39, size: 10, color: cat.2, anchor: .middle)
        let tips = p[v: "tips"]
        if tips > 0.05 {
            s.group(opacity: tips) { g in
                let lines: [(String, String)] = [("rest 5 min, no talking", "静坐 5 分钟，不说话"), ("back supported, feet flat", "背有依靠，双脚平放"),
                                                ("cuff at heart level", "袖带与心脏同高")]
                for (i, l) in lines.enumerated() { g.label("✓ " + l.0, "✓ " + l.1, 110, 62 + Double(i) * 14, size: 9, color: hex("#2E9E5B")) }
            }
        }
        var causes: [(String, String)] = []
        if hr > 90 { causes.append(("coffee · rushing · stress", "咖啡 · 赶路 · 紧张")) }
        if stiff > 0.4 { causes.append(("age · years of high pressure", "年龄 · 长期高血压")) }
        if p[v: "volume"] > 0.5 { causes.append(("salty food holds water", "高盐饮食 · 水钠潴留")) }
        for (i, c) in causes.enumerated() { s.label("↑ " + c.0, "↑ " + c.1, 110, 62 + Double(i) * 14, size: 9, color: hex("#E0603C")) }

        // artery cross-section: the wall stretches with every beat
        let ac = CGPoint(x: 290, y: 72)
        let radius = 28 + stretch * (9 * (1 - stiff) + 1.5), wall = 4 + 6 * stiff
        s.circle(ac.x, ac.y, radius + wall / 2 + 4, fill: hex("#F3DCC8"))                 // adventitia
        s.circle(ac.x, ac.y, radius + wall / 2, fill: hex("#D9707A"))                     // media: smooth muscle
        s.circle(ac.x, ac.y, radius - wall / 2 + 1.2, fill: hex("#F2C4CC"))               // intima
        s.circle(ac.x, ac.y, radius - wall / 2, fill: hex("#C8323C"))
        let push = (at(t) - 60) / 140
        for i in 0..<8 {
            let a = Double(i) / 8 * 2 * .pi, r0 = 6.0, r1 = r0 + (radius - wall / 2 - 10) * push.clamped(0.2, 1)
            let c = cos(a), sn = sin(a)
            s.line(ac.x + c * r0, ac.y + sn * r0, ac.x + c * r1, ac.y + sn * r1, stroke: .white, lw: 1.5, opacity: 0.8)
            s.circle(ac.x + c * r1, ac.y + sn * r1, 1.8, fill: .white, opacity: 0.8)
        }
        s.label(stiff > 0.5 ? "stiff artery wall" : "artery wall stretches", stiff > 0.5 ? "动脉壁变硬" : "动脉壁随心跳扩张",
                ac.x, 134, size: 9, color: hex("#8A3B45"), anchor: .middle, bold: true)

        // pressure trace
        let x0 = 236.0, x1 = 354.0, y0 = 150.0, y1 = 256.0
        func yOf(_ mm: Double) -> Double { y1 - (mm - 40) / 160 * (y1 - y0) }
        s.rect(x0, y0, x1 - x0, y1 - y0, fill: hex("#FAFAFC"), stroke: hex("#DDDDDD"))
        for mm in [80.0, 120, 140] {
            s.line(x0, yOf(mm), x1, yOf(mm), stroke: mm == 140 ? hex("#E8A7A7") : hex("#9CC9A8"), dash: [4, 3])
            s.text("\(Int(mm))", x0 - 3, yOf(mm) + 3, size: 8, color: hex("#777777"), anchor: .end)
        }
        var trace = Path()
        for i in 0...70 {
            let pt = CGPoint(x: x0 + Double(i) / 70 * (x1 - x0), y: yOf(at(t - 3 + Double(i) / 70 * 3)))
            if i == 0 { trace.move(to: pt) } else { trace.addLine(to: pt) }
        }
        s.shape(trace, stroke: hex("#C8323C"), lw: 2)
        s.label("top = systolic (peak)", "上 = 收缩压（峰）", x0, y1 + 14, size: 8, color: ink)
        s.label("bottom = diastolic (low)", "下 = 舒张压（谷）", x0, y1 + 26, size: 8, color: ink)
        s.label("last 3 s · mmHg", "近 3 秒 · mmHg", x1, y0 - 4, size: 8, color: hex("#777777"), anchor: .end)
    }
}
