import SwiftUI

extension Illustrations {
    static let morningSickness = Scenario(
        id: "morning-sickness", group: .pregnancy, title: Bilingual("Morning sickness", "孕吐"),
        params: ["scene": 0, "fingers": 0, "press": 0, "relief": 0],
        steps: [
            .watch("Nausea and vomiting affect up to 8 in 10 pregnant women. It usually starts around week 6, is worst at 9–12 and eases by 16–20 — at any time of day, not just mornings.",
                   "多达八成孕妇会恶心、呕吐。通常从第 6 周左右开始，第 9–12 周最重，第 16–20 周缓解——全天都可能发生，不只在早上。",
                   set: ["scene": 0, "fingers": 0, "press": 0, "relief": 0]),
            .watch("What helps: small, bland meals every 2–3 hours so the stomach is never empty, a dry cracker before getting up, ginger, sipping fluids, rest, and avoiding smells that set it off.",
                   "有帮助的做法：每 2–3 小时吃少量清淡食物，别让胃空着；起床前吃块苏打饼干；姜；小口慢慢喝水；多休息；避开诱发恶心的气味。",
                   set: ["scene": 1]),
            .watch("Neiguan (P6): palm up, lay three fingers across the inner wrist from the crease. The point is just above them, between the two tendons.",
                   "内关穴（P6）：掌心向上，三指并拢横放在腕横纹上方。穴位就在三指上缘、两条肌腱之间。", set: ["scene": 2, "fingers": 1]),
            .tryIt("Press the point firmly with your thumb and keep holding. Aim for 2–3 minutes on each wrist, a few times a day.",
                   "试一试：用拇指用力按住穴位并保持。每侧手腕按 2–3 分钟，每天数次。", set: ["scene": 2, "fingers": 0, "relief": 0],
                   TryStep(mode: .hold(param: "press", progress: "relief", seconds: 8, label: "PRESS 按压"), success: { $0[v: "relief"] >= 1 },
                           ok: Bilingual("Some women find it eases the nausea — the evidence is mixed, but it’s safe. Acupressure wristbands press the same spot.",
                                         "部分孕妇觉得能缓解恶心——证据不一，但很安全。止吐腕带按压的也是这个穴位。"))),
            .watch("Hyperemesis: no fluids kept down for 24 hours, dark or no urine, losing weight, dizzy or fainting, or blood in the vomit → see a doctor today. IV fluids and safe anti-sickness medicines work.",
                   "妊娠剧吐：24 小时喝不进、留不住任何液体，尿色深或无尿，体重下降，头晕晕倒，或呕吐物带血 → 当天就医。输液和孕期安全的止吐药有效。",
                   set: ["scene": 3, "press": 0]),
        ],
        draw: { s, p, t in drawSickness(&s, p, t) },
        sources: ["RCOG Green-top 69: nausea, vomiting and hyperemesis gravidarum (2016)", "ACOG Practice Bulletin 189 (2018): ginger, P6 acupressure",
                  "NHS: vomiting and morning sickness in pregnancy", "Cochrane review, Matthews et al. 2015 (P6 acupressure: limited, mixed evidence)"],
        keywords: ["nausea", "vomiting", "hyperemesis", "ginger", "P6", "acupressure", "恶心", "呕吐", "妊娠剧吐", "内关", "姜"]
    )

    @MainActor private static func drawSickness(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let scene = p[v: "scene"]
        let why = max(0, 1 - abs(scene)), helps = max(0, 1 - abs(scene - 1)), wrist = max(0, 1 - abs(scene - 2)), hyper = max(0, 1 - abs(scene - 3))
        if why + helps > 0.01 { s.group(opacity: why + helps) { g in drawQueasy(&g, calm: helps, t: t) } }
        if why > 0.01 { s.group(opacity: why) { g in drawNauseaCurve(&g, t: t) } }
        if helps > 0.01 { s.group(opacity: helps) { g in drawHelps(&g) } }
        if wrist > 0.01 { s.group(opacity: wrist) { g in drawNeiguan(&g, p, t) } }
        if hyper > 0.01 { s.group(opacity: hyper) { g in drawHyperemesis(&g, t: t) } }
    }

    /// her at the table: queasy, or calmer with ginger tea and crackers
    @MainActor private static func drawQueasy(_ s: inout Sketch, calm: Double, t: Double) {
        let o = CGPoint(x: 84, y: 118), table = 232.0
        s.circle(84, 150, 78, fill: calm > 0.5 ? hex("#EEF5EA") : hex("#F1F3E6"))
        if SceneArt.image("sickness-woman-0") != nil {
            // rendered woman behind the table: queasy, or better with a cracker and ginger tea
            s.art([("sickness-woman-0", 1 - calm), ("sickness-woman-1", calm)])
            if calm < 0.5, let c = SceneMarks.at("sickness-woman-0")["head"] {
                s.softGlow(CGPoint(x: c.x, y: c.y + 6), 16, 11, hex("#9BC46A"), 0.3)
                for i in 0..<2 {
                    let r = 7.0 + Double(i) * 5, a = t * 2 + Double(i)
                    s.path("M \(c.x + 40 + cos(a) * r) \(c.y - 20 + sin(a) * r) A \(r) \(r) 0 1 1 \(c.x + 40 + cos(a + 4) * r) \(c.y - 20 + sin(a + 4) * r)",
                           stroke: hex("#7FA84E"), lw: 1.6, cap: .round)
                }
            }
            return
        }
        let woman = Look.woman
        var f = FacingPerson(h: 300)
        f.skin = woman.skin; f.line = woman.skinLine; f.shirt = woman.top; f.shirtLine = woman.topLine
        f.hair = woman.hair; f.longHair = true
        f.face = calm > 0.5 ? .calm : .worried
        f.drawBody(&s, at: o)
        if calm < 0.5 {
            // queasy: greenish cheeks and a swirl beside the head
            let c = CGPoint(x: o.x + f.headCenter.x, y: o.y + f.headCenter.y)
            s.softGlow(CGPoint(x: c.x, y: c.y + 6), f.headRx * 1.1, f.headRy * 0.7, hex("#9BC46A"), 0.35)
            for i in 0..<2 {
                let r = 7.0 + Double(i) * 5, a = t * 2 + Double(i)
                s.path("M \(c.x + 40 + cos(a) * r) \(c.y - 20 + sin(a) * r) A \(r) \(r) 0 1 1 \(c.x + 40 + cos(a + 4) * r) \(c.y - 20 + sin(a + 4) * r)",
                       stroke: hex("#7FA84E"), lw: 1.6, cap: .round)
            }
        }
        // table
        s.shade(Path(roundedRect: CGRect(x: 0, y: table, width: 200, height: 10), cornerRadius: 3), hex("#E6CFB2"), hex("#D8BC9A"))
        s.shade(Path(CGRect(x: 0, y: table + 10, width: 200, height: 58)), hex("#F0E6DA"), hex("#E8DCCC"), vertical: true)
        // queasy: hand over the mouth, elbow tucked in front of the chest, other hand on the tummy
        // calm: a cracker in one hand, a mug of ginger tea held in the other
        let queasy: [(Double, CGPoint, CGPoint)] = [(-1, CGPoint(x: -0.02 * f.h, y: f.mouth.y + 5), CGPoint(x: -0.5, y: 1)),
                                                     (1, CGPoint(x: 0.03 * f.h, y: 0.29 * f.h), CGPoint(x: 1, y: 0.6))]
        let relaxed: [(Double, CGPoint, CGPoint)] = [(-1, CGPoint(x: -0.075 * f.h, y: 0.1 * f.h), CGPoint(x: -0.6, y: 1)),
                                                      (1, CGPoint(x: 0.075 * f.h, y: 0.2 * f.h), CGPoint(x: 0.6, y: 1))]
        let crackers = { (g: inout Sketch) in
            g.ellipse(46, table - 3, 24, 5, fill: .white, stroke: hex("#B8AFA2"), lw: 1)
            for (dx, dy) in [(-10.0, -8.0), (4, -10)] {
                g.rect(46 + dx - 8, table + dy - 3, 16, 10, r: 1.5, fill: hex("#EAC98A"), stroke: hex("#C9A262"), lw: 0.8)
            }
        }
        if calm > 0.02 { s.group(opacity: calm) { g in crackers(&g) } }
        for (pose, alpha) in [(queasy, 1 - calm), (relaxed, calm)] where alpha > 0.02 {
            s.group(translate: o, opacity: alpha) { g in
                for (side, target, bend) in pose {
                    // raised forearms come toward us: the upper arm reads shorter
                    let raised = target.y < 0.22 * f.h
                    let (e, hd) = twoBone(f.shoulderPoint(side), target, raised ? 0.135 * f.h : 0.17 * f.h, raised ? 0.13 * f.h : 0.15 * f.h, bend: bend)
                    f.limb(&g, side, elbow: e, hand: hd)
                }
                guard pose.first?.1 == relaxed.first?.1 else { return }
                // cracker between the fingers
                let c = relaxed[0].1
                g.group(rotate: -20, about: CGPoint(x: c.x + 2, y: c.y - 10)) { k in
                    k.rect(c.x - 6, c.y - 17, 14, 10, r: 1.5, fill: hex("#EAC98A"), stroke: hex("#C9A262"), lw: 0.8)
                    for dx in [-2.0, 2, 6] { k.circle(c.x + dx - 1, c.y - 12, 0.7, fill: hex("#C9A262")) }
                }
                // ginger tea, held in front of the hand
                let m = CGPoint(x: relaxed[1].1.x + 2, y: relaxed[1].1.y + 2)
                g.path("M \(m.x - 11) \(m.y - 12) L \(m.x + 11) \(m.y - 12) L \(m.x + 8.5) \(m.y + 12) L \(m.x - 8.5) \(m.y + 12) Z", fill: .white, stroke: hex("#B8AFA2"), lw: 1)
                g.ellipse(m.x, m.y - 11.5, 10, 2.2, fill: hex("#E8C77A"))
                for i in 0..<2 {
                    let x = m.x - 4 + Double(i) * 8, w = sin(t * 1.5 + Double(i)) * 2
                    g.path("M \(x) \(m.y - 17) q \(w + 3) -6 0 -12", stroke: hex("#C9C2B8"), lw: 1.2, cap: .round)
                }
            }
        }
    }

    @MainActor private static func drawNauseaCurve(_ s: inout Sketch, t: Double) {
        let px = 206.0, pw = 148.0
        s.stateChip("Up to 8 in 10", "多达八成孕妇", px + pw, 8, color: Tone.green, anchor: .end)
        s.card(px, 42, pw, 170)
        s.caption("Nausea by week of pregnancy", "各孕周的恶心程度", px + 10, 58)
        let x0 = px + 14, x1 = px + pw - 10, yb = 180.0, top = 76.0
        func X(_ w: Double) -> Double { x0 + (w - 4) / 18 * (x1 - x0) }
        // typical course: rises from week 5–6, worst at 9–12, mostly gone by 16–20
        func level(_ w: Double) -> Double { w < 5 ? 0 : w < 9 ? pow((w - 5) / 4, 1.4) : w < 12 ? 1 : max(0, 1 - pow((w - 12) / 8, 1.2)) }
        var area = Path(), line = Path()
        area.move(to: CGPoint(x: X(4), y: yb))
        for i in 0...60 {
            let w = 4 + Double(i) / 60 * 18, q = CGPoint(x: X(w), y: yb - level(w) * (yb - top))
            area.addLine(to: q)
            if i == 0 { line.move(to: q) } else { line.addLine(to: q) }
        }
        area.addLine(to: CGPoint(x: X(22), y: yb))
        area.closeSubpath()
        s.rect(X(9), top - 4, X(12) - X(9), yb - top + 4, fill: hex("#F4E4C8"), opacity: 0.7)
        s.shade(area, hex("#B7D69A"), hex("#DDEBCF"), vertical: true)
        s.shape(line, stroke: hex("#5E8F3A"), lw: 2)
        s.line(x0, yb, x1, yb, stroke: Tone.rule, lw: 1)
        for w in [6.0, 9, 12, 16, 20] {
            s.line(X(w), yb, X(w), yb + 3, stroke: Tone.faint, lw: 0.8)
            s.text("\(Int(w))", X(w), yb + 12, size: 7.5, color: Tone.sub, anchor: .middle)
        }
        s.label("worst", "最重", (X(9) + X(12)) / 2, top + 22, size: 7.5, color: hex("#4E7A30"), anchor: .middle, bold: true)
        s.cardNote("Usually eases by 16–20 weeks", "多在 16–20 周缓解", px + pw / 2, 202, width: pw - 16, size: 8.5, color: hex("#4E7A30"), bold: true)
        s.card(px, 222, pw, 70, accent: Tone.amber)
        s.cardNote("Linked to the pregnancy hormone hCG, which peaks at the same time", "与妊娠激素 hCG 有关，它也在这一时期达到高峰",
                   px + pw / 2 + 2, 246, width: pw - 20, size: 8, color: Tone.ink)
        s.cardNote("Any time of day", "全天都可能发生", px + pw / 2 + 2, 276, width: pw - 20, size: 8.5, color: hex("#A0762E"), bold: true)
    }

    @MainActor private static func drawHelps(_ s: inout Sketch) {
        let items: [(String, String, String, String)] = [
            ("Small, often", "少食多餐", "bland, every 2–3 h", "清淡，每 2–3 小时"),
            ("Cracker first", "起床先吃饼干", "before getting up", "起床前吃几块"),
            ("Ginger", "姜", "tea, candies, cookies", "姜茶、姜糖、姜饼"),
            ("Sip fluids", "小口喝水", "little and often", "少量多次"),
            ("Rest", "多休息", "tiredness makes it worse", "疲劳会加重"),
            ("Avoid triggers", "避开诱因", "strong smells, fatty food", "浓烈气味、油腻食物"),
        ]
        let x0 = 206.0, w = 72.0, h = 82.0
        s.label("What helps", "有帮助的做法", 354, 22, size: 12, color: Tone.green, anchor: .end, bold: true)
        for (i, it) in items.enumerated() {
            let x = x0 + Double(i % 2) * (w + 4), y = 36 + Double(i / 2) * (h + 3)
            s.card(x, y, w, h, r: 9)
            let c = CGPoint(x: x + w / 2, y: y + 22)
            s.circle(c.x, c.y, 16, fill: hex("#EEF5EA"))
            helpIcon(&s, i, c)
            s.cardNote(it.0, it.1, x + w / 2, y + 50, width: w - 4, size: 8.5, color: Tone.ink, bold: true)
            s.cardNote(it.2, it.3, x + w / 2, y + 67, width: w - 4, size: 7, color: Tone.sub)
        }
    }

    @MainActor private static func helpIcon(_ s: inout Sketch, _ i: Int, _ c: CGPoint) {
        let g = hex("#4E8A3A")
        switch i {
        case 0:
            s.ellipse(c.x, c.y + 5, 11, 3, fill: .white, stroke: g, lw: 1.1)
            s.circle(c.x, c.y + 1, 4.5, fill: hex("#F2E6C8"), stroke: g, lw: 1)
            for k in 0..<3 { s.circle(c.x - 6 + Double(k) * 6, c.y - 9, 1.6, fill: g) }
        case 1:
            s.rect(c.x - 8, c.y - 6, 16, 12, r: 1.5, fill: hex("#EAC98A"), stroke: hex("#B98C45"), lw: 1)
            for (dx, dy) in [(-4.0, -2.0), (0, -2), (4, -2), (-2, 2), (2, 2)] { s.circle(c.x + dx, c.y + dy, 0.8, fill: hex("#B98C45")) }
        case 2:
            s.path("M \(c.x - 10) \(c.y + 4) C \(c.x - 12) \(c.y - 2), \(c.x - 4) \(c.y - 4), \(c.x - 2) \(c.y - 1) C \(c.x) \(c.y - 8), \(c.x + 8) \(c.y - 9), \(c.x + 9) \(c.y - 3) "
                   + "C \(c.x + 12) \(c.y - 2), \(c.x + 11) \(c.y + 5), \(c.x + 6) \(c.y + 5) C \(c.x + 2) \(c.y + 8), \(c.x - 6) \(c.y + 9), \(c.x - 10) \(c.y + 4) Z",
                   fill: hex("#E3B866"), stroke: hex("#A77A2E"), lw: 1)
            s.path("M \(c.x - 4) \(c.y + 2) q 2 -1 4 0 M \(c.x + 3) \(c.y - 3) q 2 1 3 0", stroke: hex("#A77A2E"), lw: 0.8)
        case 3:
            s.path("M \(c.x - 6) \(c.y - 9) L \(c.x + 6) \(c.y - 9) L \(c.x + 5) \(c.y + 9) L \(c.x - 5) \(c.y + 9) Z", fill: hex("#EEF6FC"), stroke: Tone.blue, lw: 1.1)
            s.path("M \(c.x - 5.4) \(c.y - 2) L \(c.x + 5.4) \(c.y - 2) L \(c.x + 5) \(c.y + 9) L \(c.x - 5) \(c.y + 9) Z", fill: hex("#9CCBEE"))
        case 4:
            s.path("M \(c.x + 3) \(c.y - 9) A 9 9 0 1 0 \(c.x + 9) \(c.y + 4) A 7 7 0 1 1 \(c.x + 3) \(c.y - 9) Z", fill: hex("#F2C94C"), stroke: hex("#C99A2A"), lw: 1)
            s.text("z", c.x + 9, c.y - 4, size: 7, color: g, bold: true)
        default:
            for k in 0..<3 {
                let x = c.x - 6 + Double(k) * 6
                s.path("M \(x) \(c.y + 8) q -3 -4 0 -8 q 3 -4 0 -8", stroke: Tone.faint, lw: 1.3, cap: .round)
            }
            s.line(c.x - 10, c.y + 9, c.x + 10, c.y - 9, stroke: Anat.red, lw: 1.8, cap: .round)
        }
    }

    // MARK: Neiguan (P6)

    /// Right forearm, palm up, from above: elbow off the left edge, fingers to the right, thumb at the bottom.
    @MainActor private static func drawNeiguan(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let fingers = p[v: "fingers"].clamped(0, 1), press = p[v: "press"].clamped(0, 1), relief = p[v: "relief"].clamped(0, 1)
        let crease = 226.0, cy = 188.0, fw = 16.0
        let point = CGPoint(x: crease - 3 * fw - 2, y: cy + 5)
        let skin = Anat.skin, edge = Anat.skinEdge
        s.rect(0, 108, 360, 192, fill: hex("#F6F1EA"))
        // forearm: wider toward the elbow
        s.gradFill("M -10 142 C 60 144, 150 150, \(crease) 158 L \(crease + 4) 158 L \(crease + 4) 218 L \(crease) 218 C 150 228, 60 236, -10 240 Z",
                   [Anat.skinShade, skin, skin, Anat.skinShade], from: CGPoint(x: 0, y: 142), to: CGPoint(x: 0, y: 240), stroke: edge, lw: 1.4)
        // hand, palm up: palm, four fingers to the right, thumb along the bottom
        let fingerYs: [(Double, Double)] = [(164, 48), (177, 56), (190, 54), (203, 44)]
        for (y, len) in fingerYs {
            s.limb([CGPoint(x: crease + 60, y: y), CGPoint(x: crease + 60 + len, y: y + (y - 184) * 0.08)], w: 12, fill: skin, line: edge)
            s.path("M \(crease + 72) \(y - 4) l 0 8 M \(crease + 60 + len * 0.62) \(y - 4) l 0 8", stroke: edge, lw: 0.6, opacity: 0.6)
        }
        s.limb([CGPoint(x: crease + 14, y: 214), CGPoint(x: crease + 40, y: 232), CGPoint(x: crease + 62, y: 238)], w: 14, fill: skin, line: edge)
        s.gradFill("M \(crease) 158 C \(crease + 20) 154, \(crease + 50) 154, \(crease + 64) 158 L \(crease + 66) 210 C \(crease + 50) 222, \(crease + 22) 224, \(crease) 218 Z",
                   [skin, Anat.skinShade], from: CGPoint(x: crease + 30, y: 160), to: CGPoint(x: crease + 30, y: 222), stroke: edge, lw: 1.2)
        // palm creases and the thumb's fleshy base
        s.path("M \(crease + 60) 170 C \(crease + 44) 172, \(crease + 30) 180, \(crease + 22) 188 M \(crease + 62) 182 C \(crease + 46) 184, \(crease + 34) 190, \(crease + 28) 196 "
               + "M \(crease + 6) 206 C \(crease + 20) 196, \(crease + 30) 190, \(crease + 44) 186", stroke: edge, lw: 0.9, opacity: 0.7)
        s.ellipse(crease + 18, 206, 14, 9, fill: .white, opacity: 0.18)
        // wrist creases
        for dx in [-2.0, 4] { s.path("M \(crease + dx) 162 C \(crease + dx - 3) 178, \(crease + dx - 3) 198, \(crease + dx) 214", stroke: edge, lw: 1, opacity: 0.8) }
        // the two tendons, standing out when the fist is clenched: palmaris longus (middle) and flexor carpi radialis (thumb side)
        for (y, name) in [(cy - 4, 0), (cy + 13, 1)] {
            s.path("M 110 \(y + (name == 0 ? -4 : 6)) C 150 \(y - 1), 190 \(y), \(crease - 2) \(y)", stroke: hex("#E8C3A8"), lw: 5, cap: .round)
            s.path("M 110 \(y + (name == 0 ? -4 : 6)) C 150 \(y - 1), 190 \(y), \(crease - 2) \(y)", stroke: hex("#F7DECB"), lw: 2, cap: .round)
        }

        // three fingers laid across the wrist from the crease
        if fingers > 0.02 {
            s.group(opacity: fingers) { g in
                for k in 0..<3 {
                    let x = crease - fw * (Double(k) + 0.5) - 1
                    g.limb([CGPoint(x: x, y: 112), CGPoint(x: x, y: 200)], w: fw - 2, fill: hex("#F5D7C2"), line: edge)
                    g.rect(x - 5, 190, 10, 9, r: 4, fill: hex("#FBEDE4"), stroke: edge, lw: 0.6)
                }
                g.line(crease, 132, point.x, 132, stroke: Anat.purple, lw: 1.2)
                for x in [crease, point.x] { g.line(x, 127, x, 137, stroke: Anat.purple, lw: 1.2) }
                g.pill("3 finger-widths", "三横指", (crease + point.x) / 2, 120, color: Anat.purple, size: 8)
            }
        }
        // the point, then the pressing thumb
        let glow = press * (0.6 + 0.4 * sin(t * 6))
        s.softGlow(point, 16 + 8 * press, 16 + 8 * press, Anat.purple, 0.25 + 0.3 * glow)
        s.circle(point.x, point.y, 4.5, fill: Anat.purple, stroke: .white, lw: 1.5)
        if fingers < 0.98 {
            s.group(opacity: 1 - fingers) { g in
                let dip = 3 * press
                let tip = CGPoint(x: point.x + 1, y: point.y - 4 + dip)
                for r in [10.0, 16] where press > 0.05 { g.circle(point.x, point.y, r, stroke: Anat.purple, lw: 1.2, opacity: press * 0.6) }
                g.limb([CGPoint(x: point.x - 70, y: 112), CGPoint(x: point.x - 26, y: tip.y - 30), tip], w: 22, fill: hex("#F5D7C2"), line: edge)
                g.group(translate: CGPoint(x: tip.x - 4, y: tip.y - 11), rotate: 48, about: .zero) { n in
                    n.rect(-5, -7, 10, 13, r: 4.5, fill: hex("#FBEDE4"), stroke: edge, lw: 0.7)
                }
            }
        }
        // labels
        s.leader("wrist crease", "腕横纹", at: CGPoint(x: crease + 1, y: 164), 300, 146, anchor: .middle, color: Anat.text, size: 8)
        s.leader("two tendons", "两条肌腱", at: CGPoint(x: 140, y: cy + 11), 70, 262, anchor: .middle, color: Anat.text, size: 8)
        s.leader("Neiguan (P6)", "内关穴", at: point, point.x - 10, 282, anchor: .middle, color: Anat.purple, size: 9.5, bold: true)
        s.label("thumb side", "拇指侧", crease + 70, 262, size: 7.5, color: Anat.muted)

        // top: how to press, and a relief meter while holding
        s.card(6, 8, 200, 92, accent: Anat.purple)
        s.caption("Acupressure", "穴位按压", 18, 24)
        let how: [(String, String)] = [("palm up, 3 fingers from the crease", "掌心向上，腕横纹上三横指"), ("between the two tendons", "两条肌腱之间"),
                                       ("press firmly 2–3 min, each wrist", "用力按 2–3 分钟，两侧都按"), ("safe any time in pregnancy", "孕期任何时候都安全")]
        for (i, h) in how.enumerated() {
            let y = 42 + Double(i) * 15
            s.circle(20, y - 3, 2, fill: Anat.purple)
            s.label(h.0, h.1, 27, y, size: 8.5, color: Tone.ink)
        }
        s.card(214, 8, 140, 92)
        s.caption("Nausea", "恶心感", 224, 24)
        let level = 1 - 0.6 * relief
        s.meterBar(224, 34, 120, level, color: level > 0.7 ? hex("#7FA84E") : hex("#A9C98A"), h: 8)
        s.stopwatch(CGPoint(x: 246, y: 72), 15, minutes: relief * 60, color: Anat.purple)
        s.label(press > 0.5 ? "holding…" : relief >= 1 ? "done ✓" : "hold", press > 0.5 ? "按住中…" : relief >= 1 ? "完成 ✓" : "按住",
                270, 70, size: 10, color: Anat.purple, bold: true)
        s.label("\(Int((relief * 3).rounded(.down))) / 3 min", "\(Int((relief * 3).rounded(.down))) / 3 分钟", 270, 84, size: 8, color: Tone.sub)
    }

    // MARK: hyperemesis

    @MainActor private static func drawHyperemesis(_ s: inout Sketch, t: Double) {
        s.stateChip("See a doctor today", "当天就医", 180, 8, color: Anat.red, anchor: .middle)
        let tiles: [(String, String)] = [
            ("No fluids kept down for 24 h", "24 小时喝不进、留不住水"), ("Dark pee, or none for 8 h", "尿色深，或 8 小时无尿"),
            ("Losing weight", "体重下降"), ("Dizzy, faint, or blood in the vomit", "头晕、晕倒，或呕吐物带血"),
        ]
        let w = 84.0, h = 118.0, y0 = 42.0
        for (i, tile) in tiles.enumerated() {
            let x = 6 + Double(i) * (w + 4)
            s.card(x, y0, w, h, r: 10, accent: nil)
            s.rect(x, y0, w, 4, r: 2, fill: Anat.red)
            let c = CGPoint(x: x + w / 2, y: y0 + 42)
            switch i {
            case 0:
                s.stopwatch(CGPoint(x: c.x - 12, y: c.y), 16, minutes: 60, color: Anat.red)
                s.text("24 h", c.x - 12, c.y + 30, size: 8, color: Anat.red, anchor: .middle, bold: true)
                s.path("M \(c.x + 12) \(c.y - 12) L \(c.x + 28) \(c.y - 12) L \(c.x + 26) \(c.y + 14) L \(c.x + 14) \(c.y + 14) Z", fill: hex("#EEF6FC"), stroke: Tone.blue, lw: 1.1)
                s.path("M \(c.x + 14) \(c.y + 2) l 12 12 M \(c.x + 26) \(c.y + 2) l -12 12", stroke: Anat.red, lw: 1.6, cap: .round)
            case 1:
                let shades = ["#FBF3C4", "#F6E38A", "#EFC94E", "#D9A233", "#B5761E"]
                for (k, hx) in shades.enumerated() { s.rect(c.x - 30 + Double(k) * 12, c.y - 14, 11, 26, r: 3, fill: hex(hx)) }
                s.path("M \(c.x + 24) \(c.y + 16) l -4 7 l 8 0 Z", fill: Anat.red)
                s.label("ok", "正常", c.x - 24, c.y + 32, size: 7, color: Tone.green, anchor: .middle, bold: true)
                s.label("dry", "脱水", c.x + 24, c.y + 32, size: 7, color: Anat.red, anchor: .middle, bold: true)
            case 2:
                s.rect(c.x - 20, c.y - 12, 40, 30, r: 7, fill: hex("#F2EFEA"), stroke: Tone.sub, lw: 1.1)
                s.rect(c.x - 12, c.y - 7, 24, 10, r: 2, fill: .white, stroke: Tone.faint, lw: 0.8)
                s.text("−5%", c.x, c.y + 1, size: 8, color: Anat.red, anchor: .middle, bold: true)
                s.pointer(CGPoint(x: c.x + 26, y: c.y - 14), CGPoint(x: c.x + 26, y: c.y + 12), color: Anat.red, lw: 1.6)
            default:
                s.path("M \(c.x - 14) \(c.y) q 7 -10 14 0 q 7 10 14 0", stroke: Tone.purple, lw: 1.6, cap: .round)
                for k in 0..<3 {
                    let a = t * 2 + Double(k) * 2.1
                    s.circle(c.x + cos(a) * 18, c.y - 10 + sin(a) * 5, 2, fill: Tone.purple, opacity: 0.7)
                }
                s.path("M \(c.x) \(c.y + 10) q 4 6 0 9 q -4 -3 0 -9 Z", fill: Anat.red)
            }
            s.cardNote(tile.0, tile.1, x + w / 2, y0 + h - 22, width: w - 10, size: 8, color: Tone.ink, bold: true)
        }
        s.card(6, 172, 348, 120, accent: Tone.purple)
        s.label("Hyperemesis gravidarum", "妊娠剧吐", 20, 192, size: 11, color: Tone.purple, bold: true)
        s.label("about 1–3 in 100 pregnancies", "约 1–3% 的孕妇", 20, 207, size: 8.5, color: Tone.sub)
        let care: [(String, String)] = [("fluids through a drip", "静脉补液"), ("anti-sickness medicines safe in pregnancy", "孕期安全的止吐药"),
                                        ("vitamin B1 (thiamine) if vomiting a lot", "频繁呕吐时补充维生素 B1"), ("it is not your fault — ask for help early", "这不是你的错——尽早求助")]
        for (i, c) in care.enumerated() {
            let y = 228 + Double(i) * 16
            s.path("M \(18) \(y - 4) l 3 3 l 5 -6", stroke: Tone.green, lw: 1.5, cap: .round)
            s.label(c.0, c.1, 32, y, size: 9, color: Tone.ink)
        }
    }
}
