import SwiftUI

extension Illustrations {
    /// systolic / diastolic mmHg from heart rate, arterial stiffness and blood volume
    static func pressures(_ p: Params) -> (systolic: Double, diastolic: Double) {
        let hr = p[v: "hr"], st = p[v: "stiffness"], vol = p[v: "volume"]
        return (100 + 0.25 * (hr - 70) + 45 * st + 20 * vol, 65 + 0.2 * (hr - 70) + 15 * st + 10 * vol)
    }

    /// 2017 ACC/AHA category: (index 0…3, en, zh, colour)
    static func bpCategory(_ sys: Double, _ dia: Double) -> (Int, String, String, Color) {
        sys >= 140 || dia >= 90 ? (3, "High · stage 2", "高血压 2 级", Tone.red)
            : sys >= 130 || dia >= 80 ? (2, "High · stage 1", "高血压 1 级", hex("#E0603C"))
            : sys >= 120 ? (1, "Elevated", "血压偏高", Tone.amber) : (0, "Normal", "正常", Tone.green)
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
                           success: { _ in true }, ok: Bilingual("Normal: under 120/80. High: 130/80 or more.", "正常：低于 120/80；≥ 130/80 为高血压。"))),
        ],
        draw: { s, p, t in drawBloodPressure(&s, p, t) },
        sources: ["2017 ACC/AHA blood pressure categories; AHA home-measurement technique; 2018 Chinese hypertension guideline"]
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
        let hr = p[v: "hr"], stiff = p[v: "stiffness"], vol = p[v: "volume"], tips = p[v: "tips"]
        func at(_ time: Double) -> Double { dia + (sys - dia) * wave((time * hr / 60).wrap(1)) }
        let stretch = (at(t) - dia) / max(1, sys - dia)
        let cat = bpCategory(sys, dia)

        // top: the reading and where it sits
        s.card(8, 6, 344, 52)
        s.text("\(Int(sys.rounded()))/\(Int(dia.rounded()))", 18, 32, size: 22, color: Tone.ink, bold: true)
        s.text("mmHg", 18, 47, size: 8, color: Tone.sub)
        s.pill(cat.1, cat.2, 50, 47, color: cat.3, size: 8)
        let bx = 150.0, bw = 194.0 / 4
        let segs: [(String, String, String, Color)] = [("Normal", "正常", "<120/80", Tone.green), ("Elevated", "偏高", "120–129", Tone.amber),
                                                       ("Stage 1", "1 级", "130–139/80–89", hex("#E0603C")), ("Stage 2", "2 级", "≥140/90", Tone.red)]
        for (i, sg) in segs.enumerated() {
            let x = bx + Double(i) * bw, on = i == cat.0
            s.rect(x + 1, 20, bw - 2, 7, r: 3.5, fill: sg.3, opacity: on ? 1 : 0.3)
            s.label(sg.0, sg.1, x + bw / 2, 38, size: 7.5, color: on ? sg.3 : Tone.sub, anchor: .middle, bold: on)
            s.text(sg.2, x + bw / 2, 48, size: 6.5, color: Tone.faint, anchor: .middle)
        }
        let mx = bx + (Double(cat.0) + 0.5) * bw
        s.path("M \(mx - 4.5) 13 L \(mx + 4.5) 13 L \(mx) 19 Z", fill: Tone.ink)

        // left: seated, back against the chair, forearm on the table, cuff on the bare upper arm at heart level
        let floor = 288.0
        var v = SideFigure(Casualty(p, adult: 200), lean: -3)
        let h = v.h, b = v.build
        v.look.longSleeves = false
        v.nearLeg = .init(hip: 90, knee: 90)
        v.farLeg = .init(hip: 86, knee: 84)
        v.hip = CGPoint(x: 52, y: floor - b.shin * h - b.legW * h * 0.3)
        let hip = v.hip, seat = hip.y + b.legW * h * 0.5
        let table = v.front(0.72).y + 0.05 * h
        v.near = .init(reach: CGPoint(x: hip.x + 0.3 * h, y: table - b.hand * h * 0.22), hand: .open, handAngle: 0)
        s.stage(100, floor: floor, r: 92, width: 200)
        // chair
        let back = v.back(0.4).x - 5
        let wood = hex("#CFA97F"), woodLo = hex("#B48D66")
        s.rect(back - 6, hip.y - 0.3 * h, 7, seat - hip.y + 0.3 * h + 6, r: 2.5, fill: wood)
        s.line(back - 2, seat + 6, back - 2, floor, stroke: woodLo, lw: 4)
        s.line(hip.x + 0.16 * h, seat + 6, hip.x + 0.16 * h, floor, stroke: woodLo, lw: 4)
        s.rect(back - 6, seat, hip.x + 0.2 * h - back + 6, 6, r: 2, fill: wood)
        v.drawBack(&s, farArm: false)
        v.drawBody(&s)
        // table with the monitor, and what's on it
        let tx0 = hip.x + 0.2 * h
        s.shade(Path(roundedRect: CGRect(x: tx0, y: table, width: 200 - tx0, height: 8), cornerRadius: 2), hex("#D5B08A"), hex("#B98D62"))
        s.line(192, table + 8, 192, floor, stroke: woodLo, lw: 5)
        v.drawArm(&s, near: true)
        let sh = v.shoulderPoint, e = v.elbow()
        let c0 = lerp(sh, e, 0.25), c1 = lerp(sh, e, 0.8)
        let cuffW = b.armW * h + 7 + 1.2 * stretch
        s.line(c0.x, c0.y, c1.x, c1.y, stroke: hex("#34405A"), lw: cuffW, cap: .round)
        s.line(c0.x, c0.y, c1.x, c1.y, stroke: hex("#4E5E80"), lw: cuffW - 3, cap: .round)
        let mon = CGRect(x: 134, y: table - 42, width: 60, height: 42)
        s.path("M \(c1.x + 1) \(c1.y + 3) C \(c1.x + 16) \(c1.y + 40) \(mon.minX - 18) \(mon.maxY - 2) \(mon.minX) \(mon.maxY - 10)", stroke: hex("#34405A"), lw: 1.8)
        s.shade(Path(roundedRect: mon, cornerRadius: 8), hex("#FFFFFF"), hex("#E1E5EB"), stroke: hex("#A9B1BC"), lw: 1)
        s.rect(mon.minX + 5, mon.minY + 5, 36, mon.height - 10, r: 3, fill: hex("#D9E4D6"))
        let lx = mon.minX + 8, rx = mon.minX + 39
        s.text("SYS", lx, mon.minY + 13, size: 4.5, color: hex("#3E4A42"))
        s.text("\(Int(sys.rounded()))", rx, mon.minY + 18, size: 11, color: hex("#1E2A22"), anchor: .end, bold: true)
        s.text("DIA", lx, mon.minY + 24, size: 4.5, color: hex("#3E4A42"))
        s.text("\(Int(dia.rounded()))", rx, mon.minY + 29, size: 11, color: hex("#1E2A22"), anchor: .end, bold: true)
        s.heart(lx + 1.5, mon.minY + 32.5, 1.8, fill: Tone.red.opacity(0.4 + 0.6 * stretch))
        s.text("\(Int(hr.rounded()))", rx, mon.minY + 35, size: 6, color: hex("#1E2A22"), anchor: .end, bold: true)
        s.circle(mon.maxX - 11, mon.midY + 4, 6, fill: Tone.blue)
        s.path("M \(mon.maxX - 13) \(mon.midY + 1) L \(mon.maxX - 8) \(mon.midY + 4) L \(mon.maxX - 13) \(mon.midY + 7) Z", fill: .white)
        // things that push it up, on the table
        if hr > 90 {
            let cx = vol > 0.5 ? 110.0 : 122.0
            s.path("M \(cx - 7) \(table - 14) L \(cx + 7) \(table - 14) L \(cx + 5.5) \(table) L \(cx - 5.5) \(table) Z", fill: .white, stroke: hex("#8C6B4E"), lw: 1)
            s.path("M \(cx + 6.5) \(table - 11) q 5 1 1.5 7", stroke: hex("#8C6B4E"), lw: 1.2)
            for k in 0..<2 {
                let u = (t * 0.6 + Double(k) * 0.5).wrap(1)
                s.path("M \(cx - 2 + Double(k) * 4) \(table - 17 - u * 10) q 2 -3 0 -6", stroke: hex("#B8A898"), lw: 1, opacity: 1 - u)
            }
        }
        if vol > 0.5 {
            let cx = 118.0
            s.rect(cx + 6, table - 14, 8, 14, r: 2.5, fill: .white, stroke: hex("#9AA3AE"))
            s.rect(cx + 6, table - 16, 8, 4, r: 1.5, fill: hex("#B8C0CA"))
            for k in 0..<3 { s.circle(cx + 8 + Double(k) * 2, table - 15, 0.5, fill: hex("#6B7480")) }
        }
        if tips > 0.05 {
            s.group(opacity: tips) { g in
                let spots: [(CGPoint, String, String)] = [
                    (v.back(0.55), "back supported", "背有依靠"),
                    (lerp(c0, c1, 0.5), "cuff at heart level", "袖带与心脏同高"),
                    (v.palm(), "arm resting on the table", "手臂平放在桌上"),
                    (v.foot(near: true).toe, "feet flat, legs uncrossed", "双脚平放，不跷腿"),
                ]
                g.label("✓ rest 5 min first, no talking", "✓ 先静坐 5 分钟，不说话", 6, 76, size: 8, color: Tone.green, bold: true)
                for (i, sp) in spots.enumerated() {
                    let y = 90 + Double(i) * 12.5
                    for (x, yy) in [(11.0, y - 3), (sp.0.x, sp.0.y)] {
                        g.circle(x, yy, 5, fill: Tone.green, stroke: .white, lw: 1)
                        g.text("\(i + 1)", x, yy + 2.5, size: 6.5, color: .white, anchor: .middle, bold: true)
                    }
                    g.label(sp.1, sp.2, 20, y, size: 8, color: Tone.green)
                }
            }
        }

        // right: the artery under the cuff, cut across
        let ac = CGPoint(x: 296, y: 116), R = 44.0
        var lensG = s.lens(ac, R, from: lerp(c0, c1, 0.55), 8, fill: hex("#FBF1EC"))
        let radius = 20 + stretch * (7 * (1 - stiff) + 1), wall = 5 + 7 * stiff
        lensG.circle(ac.x, ac.y, radius + wall + 9, fill: hex("#F3DCC8"))
        for k in 0..<10 {
            let a = Double(k) * 0.63
            lensG.path("M \(ac.x + cos(a) * (radius + wall + 3)) \(ac.y + sin(a) * (radius + wall + 3)) q 3 2 6 0", stroke: hex("#E2BFA4"), lw: 0.7)
        }
        lensG.circle(ac.x, ac.y, radius + wall, fill: stiff > 0.4 ? hex("#C96A70") : hex("#D9707A"))
        for k in 1..<4 { lensG.circle(ac.x, ac.y, radius + wall * Double(k) / 4, stroke: stiff > 0.4 ? hex("#B5575E") : hex("#EFA1A8"), lw: 0.8) }
        if stiff > 0.4 {
            for k in 0..<Int(stiff * 8) {
                let a = Double(k) * 0.9 + 0.4
                lensG.circle(ac.x + cos(a) * (radius + wall * 0.5), ac.y + sin(a) * (radius + wall * 0.5), 1.6, fill: hex("#F1E6C8"))
            }
        }
        lensG.circle(ac.x, ac.y, radius + 1.2, fill: hex("#F4D2D6"))
        lensG.circle(ac.x, ac.y, radius, fill: hex("#B42C38"))
        for k in 0..<6 {
            let a = Double(k) * 1.05 + t * 0.6, rr = radius * 0.55
            lensG.ellipse(ac.x + cos(a) * rr, ac.y + sin(a) * rr, 4.5, 2.6, fill: hex("#D8505C"))
        }
        let push = ((at(t) - 60) / 140).clamped(0.15, 1)
        for i in 0..<8 {
            let a = Double(i) / 8 * 2 * .pi, r1 = radius * (0.35 + 0.5 * push)
            lensG.pointer(CGPoint(x: ac.x + cos(a) * radius * 0.2, y: ac.y + sin(a) * radius * 0.2),
                          CGPoint(x: ac.x + cos(a) * r1, y: ac.y + sin(a) * r1), color: .white.opacity(0.85), lw: 1.1, head: 3.5)
        }
        s.lensRing(ac, R)
        s.caption("Artery under the cuff", "袖带下的动脉", ac.x, ac.y - R - 6, anchor: .middle)
        s.callout(stiff > 0.4 ? "stiff wall" : "elastic wall", stiff > 0.4 ? "管壁变硬" : "弹性管壁",
                  at: CGPoint(x: ac.x + (radius + wall * 0.5) * 0.5, y: ac.y + (radius + wall * 0.5) * 0.85),
                  ac.x + 22, ac.y + R + 14, anchor: .middle, color: stiff > 0.4 ? Tone.red : Tone.organLine)

        // right, bottom: pressure trace like the monitor's
        let x0 = 232.0, x1 = 346.0, y0 = 204.0, y1 = 266.0
        s.card(206, 186, 146, 110)
        s.caption("Pressure, last 3 s", "近 3 秒压力", 212, 198)
        func yOf(_ mm: Double) -> Double { y1 - (mm - 50) / 150 * (y1 - y0) }
        for mm in [80.0, 120, 140] {
            s.line(x0, yOf(mm), x1, yOf(mm), stroke: mm == 140 ? hex("#F0B4B4") : mm == 120 ? hex("#A9D6B5") : Tone.rule, lw: 0.8, dash: [3, 2])
            s.text("\(Int(mm))", x0 - 3, yOf(mm) + 2.5, size: 6.5, color: Tone.faint, anchor: .end)
        }
        var trace = Path()
        for i in 0...90 {
            let pt = CGPoint(x: x0 + Double(i) / 90 * (x1 - x0), y: yOf(at(t - 3 + Double(i) / 90 * 3)))
            if i == 0 { trace.move(to: pt) } else { trace.addLine(to: pt) }
        }
        s.shape(trace, stroke: Tone.artery, lw: 1.8)
        s.circle(x1, yOf(at(t)), 2.5, fill: Tone.artery)
        s.line(x0, yOf(sys), x1, yOf(sys), stroke: Tone.artery, lw: 0.6, opacity: 0.5)
        s.line(x0, yOf(dia), x1, yOf(dia), stroke: Tone.blue, lw: 0.6, opacity: 0.5)
        s.label("top: systolic \(Int(sys.rounded()))", "收缩压（峰）\(Int(sys.rounded()))", 212, 280, size: 7.5, color: Tone.artery, bold: true)
        s.label("bottom: diastolic \(Int(dia.rounded()))", "舒张压（谷）\(Int(dia.rounded()))", 212, 290, size: 7.5, color: Tone.blue, bold: true)
    }
}
