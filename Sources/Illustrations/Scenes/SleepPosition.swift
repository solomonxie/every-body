import SwiftUI

extension Illustrations {
    static let sleepPosition = Scenario(
        id: "pregnancy-sleep-position", group: .pregnancy, title: Bilingual("Sleeping position", "孕期睡姿"),
        params: ["side": 1, "pillows": 0, "names": 1, "advice": 0],
        steps: [
            .watch("Seen from her feet: behind the womb, along the spine, run the body’s two biggest vessels — the aorta (out to the body and womb) and the vena cava (back to the heart).",
                   "从脚侧看：子宫后方、紧贴脊柱，是人体最大的两条血管——主动脉（把血送往全身和子宫）和下腔静脉（把血送回心脏）。",
                   set: ["side": 1, "pillows": 0, "names": 1, "advice": 0]),
            .watch("From about 28 weeks, lying flat on her back, the womb (≈ 5–6 kg at term) squashes the vena cava and presses on the aorta. Less blood gets back to her heart, so less reaches the baby.",
                   "约 28 周后平躺时，子宫（足月约 5–6 公斤）压扁下腔静脉、压迫主动脉。回心血量减少，流向胎儿的血也随之减少。",
                   set: ["side": 0, "names": 0]),
            .watch("On her side — left is best — the womb rolls off the vessels and the flow comes back. A pillow between the knees and one under the bump keep her there.",
                   "侧卧（左侧最好）时，子宫离开血管，血流恢复。两膝之间夹一个枕头、肚子下垫一个，更容易保持侧睡。",
                   set: ["side": 1, "pillows": 1]),
            .tryIt("Compare lying on her back with lying on her left side. Watch the vessels and the flow meters.", "试一试：比较平躺与左侧卧，看血管和血流表的变化。",
                   set: ["side": 0],
                   TryStep(mode: .compare(param: "side", options: [("On her back 平躺", 0), ("Left side 左侧卧", 1)]), success: { $0[v: "side"] > 0.5 },
                           ok: Bilingual("Left side: the vena cava is open — full flow back to her heart and on to the baby.", "左侧卧：下腔静脉通畅——血液顺利回心，再流向胎儿。"),
                           demo: ["side": 1])),
            .watch("After 28 weeks, go to sleep on your side, for naps too. Woke up on your back? That’s fine — just turn over. Dizzy or sick lying flat: roll onto your left side.",
                   "孕 28 周后，入睡时（包括午睡）都要侧卧。醒来发现自己平躺也没关系——翻个身就好。平躺时头晕、恶心：立即转向左侧。",
                   set: ["side": 1, "pillows": 1, "advice": 1]),
        ],
        draw: { s, p, t in drawSleep(&s, p, t) },
        sources: ["Cronin et al., EClinicalMedicine 2019 (going to sleep on the back after 28 weeks: ≈ 2.6× late stillbirth)",
                  "RCOG / Tommy’s “Sleep on Side” guidance (from 28 weeks)",
                  "Humphries et al., J Physiol 2019 (MRI: supine compression of the vena cava and aorta in late pregnancy)"],
        keywords: ["sleep on side", "left side", "supine", "vena cava", "睡姿", "左侧卧", "仰卧"]
    )

    /// blood returning to the heart and reaching the womb, 0…1 (side 0 = on her back)
    static func sleepFlow(_ side: Double) -> (heart: Double, baby: Double) {
        let s = side.clamped(0, 1)
        return (0.55 + 0.45 * s, 0.68 + 0.32 * s)
    }

    @MainActor private static func drawSleep(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let side = p[v: "side"].clamped(0, 1), pillows = p[v: "pillows"].clamped(0, 1)
        let flow = sleepFlow(side)
        drawBedView(&s, side: side, pillows: pillows, t: t)
        drawSection(&s, side: side, names: p[v: "names"], t: t)

        // right panel
        let px = 216.0, pw = 138.0
        let good = side > 0.5
        if good {
            s.stateChip("Left side", "左侧卧", px + pw, 8, color: Anat.green, anchor: .end)
        } else {
            s.stateChip("On her back", "平躺", px + pw, 8, color: Anat.red, anchor: .end)
        }
        s.card(px, 42, pw, 112)
        s.caption("Blood flow", "血流", px + 10, 58)
        func meter(_ y: Double, _ en: String, _ zh: String, _ v: Double) {
            let col = v > 0.9 ? Tone.green : v > 0.75 ? Tone.amber : Tone.red
            s.label(en, zh, px + 10, y, size: 8.5, color: Tone.ink, bold: true)
            s.meterBar(px + 10, y + 6, pw - 20, v, color: col, h: 8)
            // dots running along the bar, slower when squeezed
            var bar = s.clipped(to: Path(roundedRect: CGRect(x: px + 10, y: y + 6, width: (pw - 20) * v, height: 8), cornerRadius: 4))
            for i in 0..<6 {
                let x = px + 10 + (Double(i) * 22 + t * 30 * v * v).wrap(132) - 6
                bar.circle(x, y + 10, 1.6, fill: .white, opacity: 0.7)
            }
            s.label(v > 0.9 ? "full" : "reduced", v > 0.9 ? "充足" : "减少", px + pw - 10, y, size: 8, color: col, anchor: .end, bold: true)
        }
        meter(78, "back to her heart", "回流心脏", flow.heart)
        meter(110, "to the baby", "流向胎儿", flow.baby)
        s.cardNote(good ? "vena cava open" : "she may feel dizzy, sick, faint", good ? "下腔静脉通畅" : "可能头晕、恶心、眼前发黑",
                   px + pw / 2, 140, width: pw - 16, size: 8, color: good ? Tone.green : Tone.red, bold: true)

        if p[v: "advice"] > 0.5 {
            s.tonal(px, 164, pw, 130, color: Anat.green)
            s.label("From 28 weeks", "孕 28 周起", px + pw / 2, 182, size: 10, color: Anat.green, anchor: .middle, bold: true)
            let tips: [(String, String)] = [("go to sleep on your side", "入睡时侧卧"), ("naps too", "午睡也一样"),
                                            ("woke on your back? roll over", "醒来平躺？翻身即可"), ("pillows: knees + bump", "枕头：夹膝 + 托腹")]
            for (i, tip) in tips.enumerated() {
                let y = 202 + Double(i) * 16
                s.circle(px + 12, y - 3, 2.2, fill: Anat.green)
                s.label(tip.0, tip.1, px + 19, y, size: 8, color: Tone.ink)
            }
            s.cardNote("Going to sleep on the back late in pregnancy is linked to a 2–3× higher stillbirth risk",
                       "孕晚期仰卧入睡与死产风险升高 2–3 倍相关", px + pw / 2, 276, width: pw - 14, size: 7.5, color: Tone.sub)
        } else {
            s.card(px, 164, pw, 130)
            s.caption("Which way to lie", "怎么躺", px + 10, 180)
            let rows: [(String, String, Color, String, String)] = [
                ("Left side", "左侧卧", Tone.green, "best flow", "血流最好"),
                ("Right side", "右侧卧", Tone.green, "also fine", "也可以"),
                ("Flat on the back", "平躺", Tone.red, "avoid from 28 weeks", "28 周后避免"),
            ]
            for (i, r) in rows.enumerated() {
                let y = 200 + Double(i) * 27
                s.circle(px + 14, y - 3, 4, fill: r.2)
                s.label(r.0, r.1, px + 24, y, size: 9, color: Tone.ink, bold: true)
                s.label(r.3, r.4, px + 24, y + 11, size: 7.5, color: r.2)
            }
            s.cardNote("The heavier the womb, the more it matters", "子宫越重，越要注意",
                       px + pw / 2, 282, width: pw - 14, size: 7.5, color: Tone.sub)
        }
    }

    /// Bed from above: on her back (front view) or curled on her left side with pillows; a blanket over the lower legs.
    @MainActor private static func drawBedView(_ s: inout Sketch, side: Double, pillows: Double, t: Double) {
        let bed = CGRect(x: 6, y: 8, width: 202, height: 104)
        s.rect(bed.minX, bed.minY + 2, bed.width, bed.height, r: 10, fill: .black.opacity(0.07))
        s.rect(bed.minX, bed.minY, bed.width, bed.height, r: 10, fill: hex("#EAF1F8"), stroke: hex("#B9C9DC"), lw: 1)
        s.shade(Path(roundedRect: CGRect(x: bed.minX + 8, y: bed.minY + 14, width: 40, height: 76), cornerRadius: 14), .white, hex("#E1E7EF"),
                stroke: hex("#C3CEDB"), lw: 1)
        let woman = Look.woman
        let breath = sin(t * 1.2) * 0.5
        func blanket(_ g: inout Sketch, _ x0: Double) {
            g.shade("M \(x0) \(bed.minY) L \(bed.maxX - 10) \(bed.minY) Q \(bed.maxX) \(bed.minY) \(bed.maxX) \(bed.minY + 10) L \(bed.maxX) \(bed.maxY - 10) "
                    + "Q \(bed.maxX) \(bed.maxY) \(bed.maxX - 10) \(bed.maxY) L \(x0) \(bed.maxY) C \(x0 - 6) 80, \(x0 + 6) 40, \(x0) \(bed.minY) Z",
                    hex("#C9D8EC"), hex("#A9BEDB"), stroke: hex("#8FA6C6"), lw: 1)
            for k in 0..<3 {
                let x = x0 + 14 + Double(k) * 13
                g.path("M \(x) \(bed.minY + 6) C \(x - 4) 50, \(x + 4) 70, \(x - 2) \(bed.maxY - 6)", stroke: hex("#8FA6C6"), lw: 0.8, opacity: 0.6)
            }
        }
        if side < 0.99 {
            s.group(opacity: 1 - side) { g in
                // on her back, seen from above: head on the pillow, bump rising toward us
                g.group(translate: CGPoint(x: 58, y: 60), rotate: -90, about: .zero) { b in
                    var f = FacingPerson(h: 164)
                    f.skin = woman.skin; f.line = woman.skinLine
                    f.shirt = woman.top; f.shirtLine = woman.topLine
                    f.hair = woman.hair; f.longHair = true; f.face = .worried
                    f.rightHand = CGPoint(x: -0.075 * f.h, y: 0.3 * f.h); f.leftHand = CGPoint(x: 0.075 * f.h, y: 0.3 * f.h)
                    let h = f.h
                    for sx in [-1.0, 1.0] {
                        b.taper([CGPoint(x: sx * 0.055 * h, y: 0.34 * h), CGPoint(x: sx * 0.05 * h, y: 0.62 * h)], [0.085 * h, 0.06 * h],
                                fill: woman.bottom, line: woman.topLine)
                    }
                    f.drawBody(&b, at: .zero)
                    let c = CGPoint(x: 0, y: 0.27 * h + breath)
                    b.gradFill(Path(ellipseIn: CGRect(x: c.x - 0.1 * h, y: c.y - 0.09 * h, width: 0.2 * h, height: 0.18 * h)),
                               [dim(woman.top, 1.12), woman.top, darker(woman.top)], from: CGPoint(x: c.x - 10, y: c.y - 16), to: CGPoint(x: c.x + 12, y: c.y + 18),
                               stroke: woman.topLine, lw: 1.1)
                    b.ellipse(c.x - 0.03 * h, c.y - 0.03 * h, 0.035 * h, 0.025 * h, fill: .white, opacity: 0.25)
                    f.drawArms(&b, at: .zero)
                }
                blanket(&g, 152)
            }
        }
        if side > 0.01 {
            s.group(opacity: side) { g in
                // curled on her left side, seen from above: her front toward the top of the picture
                var f = SideFigure(h: 166, look: woman, hip: CGPoint(x: 110, y: 86), rotation: -82, face: .closed, bump: 1)
                f.headTilt = 14
                f.nearLeg = .init(hip: 78, knee: 104, point: 20)
                f.farLeg = .init(hip: 58, knee: 92, point: 20)
                let bump = f.front(0.28)
                let rest = f.front(0.16)
                f.near = .init(reach: CGPoint(x: rest.x + 2, y: rest.y - 4), hand: .open, handAngle: 10)
                let o = pillows
                if o > 0.01 {
                    // pillow under the bump, peeking out in front of it
                    g.group(translate: CGPoint(x: bump.x - 6, y: bump.y - 4), rotate: -8, about: .zero, opacity: o) { w in
                        w.shade(Path(roundedRect: CGRect(x: -30, y: -18, width: 56, height: 30), cornerRadius: 12), .white, hex("#D6E0EC"),
                                stroke: hex("#AFC0D3"), lw: 1)
                    }
                }
                f.drawBack(&g, farArm: false)
                if o > 0.01 {
                    let k1 = f.legPoint(near: true, 1), k2 = f.legPoint(near: false, 1)
                    let c = lerp(k1, f.hip, 0.2), a = atan2(k1.y - f.hip.y, k1.x - f.hip.x) * 180 / .pi
                    g.group(translate: CGPoint(x: c.x + 2, y: c.y - 9), rotate: a, about: .zero, opacity: o) { w in
                        w.shade(Path(roundedRect: CGRect(x: -30, y: -11, width: 54, height: 22), cornerRadius: 9), .white, hex("#D6E0EC"),
                                stroke: hex("#AFC0D3"), lw: 1)
                    }
                }
                f.drawBody(&g)
                f.drawArm(&g, near: true)
                blanket(&g, 164)
                if o > 0.5 {
                    let k = lerp(f.legPoint(near: true, 1), f.hip, 0.2)
                    g.leader("pillow between knees", "两膝夹枕", at: CGPoint(x: k.x + 10, y: k.y - 16), 160, 106, anchor: .end, color: hex("#4E6E96"), size: 7.5)
                    g.leader("pillow under bump", "枕头托腹", at: CGPoint(x: bump.x - 22, y: bump.y - 14), 84, 22, color: hex("#4E6E96"), size: 7.5)
                }
            }
        }
        s.label("seen from above", "俯视", bed.minX + 8, bed.minY + 11, size: 7, color: hex("#4E6E96"))
    }

    /// Cross-section of the belly seen from her feet (her right on the left of the picture), turning as she rolls onto her left side.
    @MainActor private static func drawSection(_ s: inout Sketch, side: Double, names: Double, t: Double) {
        let c = CGPoint(x: 106, y: 206), k = 0.86
        let bedY = c.y + (50 + 30 * side) * k
        let beat = pow(max(0, sin(t * 2 * .pi * 1.3)), 6)
        // 1 = flat on her back: the womb rests on the vessels
        let squeeze = 1 - Anat.ease(side * 1.25)
        let wr = CGSize(width: 50, height: 40)
        let womb = CGPoint(x: 16 * side, y: -30 + 4 * squeeze - 6 * side)

        s.rect(6, bedY, 202, 298 - bedY, r: 6, fill: hex("#EAF1F8"), stroke: hex("#B9C9DC"), lw: 1)
        if side > 0.3 {
            let o = ((side - 0.3) / 0.5).clamped(0, 1)
            s.path("M \(c.x + 30) \(bedY) L \(c.x + 100) \(bedY) L \(c.x + 100) \(bedY - 30) C \(c.x + 84) \(bedY - 40), \(c.x + 58) \(bedY - 30), \(c.x + 30) \(bedY) Z",
                   fill: hex("#F7FAFD"), stroke: hex("#AFC0D3"), lw: 1, opacity: o)
        }
        s.group(translate: c, rotate: 90 * side, about: .zero, scale: k) { g in
            let body = SVGPath.parse("M -30 50 C -58 50, -80 36, -82 10 C -84 -22, -74 -52, -48 -70 C -26 -84, 26 -84, 48 -70 C 74 -52, 84 -22, 82 10 C 80 36, 58 50, 30 50 Z")
            g.gradFill(body, [Anat.skin, Anat.skinShade], from: CGPoint(x: 0, y: -80), to: CGPoint(x: 0, y: 50), stroke: Anat.skinEdge, lw: 1.6)
            var inside = g.clipped(to: body)
            // fat under the skin, then the gut filling the space around the womb
            inside.shape(body.applying(CGAffineTransform(scaleX: 0.93, y: 0.93).translatedBy(x: 0, y: -1)), fill: hex("#F3D9C4"))
            for (x, y) in [(-60.0, -18.0), (-62, 6), (-52, -40), (60, -18), (62, 6), (52, -40), (-40, 22), (40, 22)] {
                inside.circle(x, y, 9, fill: hex("#EBC6AE"), stroke: hex("#D9A98E"), lw: 0.8)
            }
            for sx in [-1.0, 1.0] {
                // back muscles beside the spine, psoas at its sides, kidneys further out
                inside.ellipse(sx * 17, 40, 14, 9, fill: Tone.muscle)
                inside.ellipse(sx * 24, 20, 8, 9, fill: Tone.muscleHi)
                inside.group(translate: CGPoint(x: sx * 46, y: 30), rotate: sx * 28, about: .zero) { kd in
                    kd.ellipse(0, 0, 11, 7, fill: hex("#B6505C"), stroke: hex("#6E2632"), lw: 0.8)
                }
            }
            // lumbar vertebra: arch and spinous process behind, body in front
            g.boneFill("M -10 32 L -16 40 L -4 44 L -3 52 L 3 52 L 4 44 L 16 40 L 10 32 Z", light: CGPoint(x: 0, y: 32), dark: CGPoint(x: 0, y: 52))
            g.circle(0, 36, 3.2, fill: hex("#F5E6B8"), stroke: Anat.boneEdge, lw: 0.8)
            g.boneFill(Path(ellipseIn: CGRect(x: -12, y: 16, width: 24, height: 18)), light: CGPoint(x: 0, y: 16), dark: CGPoint(x: 0, y: 34))
            // womb: muscular wall, fluid, placenta on the front wall, the baby
            g.gradFill(Path(ellipseIn: CGRect(x: womb.x - wr.width, y: womb.y - wr.height, width: 2 * wr.width, height: 2 * wr.height)),
                       [hex("#E7A0AE"), hex("#CF7C8E")], from: CGPoint(x: womb.x, y: womb.y - wr.height), to: CGPoint(x: womb.x, y: womb.y + wr.height),
                       stroke: hex("#B5627A"), lw: 1.2)
            g.gradFill(Path(ellipseIn: CGRect(x: womb.x - wr.width + 5, y: womb.y - wr.height + 5, width: 2 * wr.width - 10, height: 2 * wr.height - 10)),
                       [hex("#FDEDEF"), hex("#F7D6DC")], from: CGPoint(x: womb.x, y: womb.y - wr.height), to: CGPoint(x: womb.x, y: womb.y + wr.height))
            g.path("M \(womb.x - 28) \(womb.y - 30) C \(womb.x - 12) \(womb.y - 38), \(womb.x + 12) \(womb.y - 38), \(womb.x + 28) \(womb.y - 30) "
                   + "C \(womb.x + 14) \(womb.y - 26), \(womb.x - 14) \(womb.y - 26), \(womb.x - 28) \(womb.y - 30) Z", fill: hex("#A83E58"))
            drawFetus(&g, at: CGPoint(x: womb.x + 2, y: womb.y + 4), length: 50, week: 32, rotate: 100 - 90 * side, cord: nil)
            // vessels on the front of the spine: vena cava on her right (picture left), aorta on her left
            let floor = 16.0
            let ivcRy = 8 * (1 - 0.72 * squeeze), ivcRx = 9 * (1 + 0.45 * squeeze)
            let aoRy = 7 * (1 - 0.2 * squeeze) + beat * 0.7, aoRx = 7 * (1 + 0.08 * squeeze) + beat * 0.7
            g.ellipse(-16, floor - ivcRy, ivcRx, ivcRy, fill: Tone.vein, stroke: darker(Tone.vein), lw: 1)
            if ivcRy > 3 { g.ellipse(-18, floor - ivcRy * 1.4, ivcRx * 0.35, ivcRy * 0.28, fill: Tone.veinHi, opacity: 0.8) }
            g.ellipse(11, floor - aoRy, aoRx, aoRy, fill: Tone.artery, stroke: darker(Tone.artery), lw: 1)
            g.ellipse(9, floor - aoRy * 1.4, 2.4, 1.6, fill: Tone.arteryHi, opacity: 0.8)
            if squeeze > 0.3 {
                for x in [-16.0, 0, 16] {
                    g.pointer(CGPoint(x: womb.x + x, y: womb.y + 22), CGPoint(x: womb.x + x, y: womb.y + 36), color: Anat.red.opacity(squeeze), lw: 1.6, head: 5)
                }
            }
        }
        func q(_ x: Double, _ y: Double) -> CGPoint {
            let a = 90 * side * .pi / 180
            return CGPoint(x: c.x + k * (x * cos(a) - y * sin(a)), y: c.y + k * (x * sin(a) + y * cos(a)))
        }
        for (pnt, en, zh) in [(q(-74, -56), "R", "右"), (q(74, -56), "L", "左")] {
            s.circle(pnt.x, pnt.y, 7, fill: .white, stroke: Anat.muted, lw: 0.8)
            s.label(en, zh, pnt.x, pnt.y + 3, size: 8, color: Anat.text, anchor: .middle, bold: true)
        }
        s.caption("Seen from her feet", "从脚侧看的横截面", 10, 128)
        let open = side > 0.5
        s.leader(open ? "vena cava" : "vena cava squashed", open ? "下腔静脉" : "下腔静脉被压扁", at: q(-16, open ? 8 : 14), 10, open ? 150 : 274,
                 color: open ? Tone.vein : Anat.red, size: 8, bold: true)
        s.leader("aorta", "主动脉", at: q(11, 10), open ? 10 : 204, open ? 214 : 290, anchor: open ? .start : .end, color: Tone.artery, size: 8, bold: true)
        if names > 0.5 {
            s.leader("spine", "脊柱", at: q(0, 44), 10, 262, color: Anat.text, size: 8)
            s.leader("womb", "子宫", at: q(womb.x - 35, womb.y - 27), 204, 150, anchor: .end, color: hex("#A0506A"), size: 8)
        }
    }
}
