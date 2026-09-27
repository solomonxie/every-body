import SwiftUI

extension Illustrations {
    /// chance a stone passes on its own, by size in mm (typical clinical figures)
    static func passChance(_ mm: Double) -> Double { mm <= 4 ? 0.9 : mm <= 6 ? 0.6 : mm <= 8 ? 0.3 : 0.1 }

    /// left ureter (picture right): renal pelvis → over the iliac artery at the pelvic brim → through the bladder wall
    static let ureterPath = [CGPoint(x: 136, y: 110), CGPoint(x: 134, y: 136), CGPoint(x: 131, y: 164), CGPoint(x: 129, y: 192),
                             CGPoint(x: 133, y: 214), CGPoint(x: 129, y: 236), CGPoint(x: 121, y: 250)]

    static func kidneyStones(for p: Profile) -> Scenario {
        var s: Scenario = kidneyStones
        if p.isPregnant {
            s.profileNote = Bilingual("Pregnant: checked by ultrasound, not CT. A mildly swollen right kidney is normal in pregnancy; pain with fever → hospital the same day.",
                                      "孕妇：用超声检查，不做 CT。孕期右肾轻度积水常见；疼痛伴发热 → 当天就医。")
        } else if p.isKid {
            s.profileNote = Bilingual("Children: stones are rare and often have a cause (diet, metabolism, urine infection) — see a paediatric doctor. Pain may show as vomiting or crying.",
                                      "儿童：结石少见，常有病因（饮食、代谢、尿路感染）——请看儿科。疼痛可能表现为呕吐、哭闹。")
        }
        return s
    }

    static let kidneyStones = Scenario(
        id: "kidney-stones", group: .illness, title: Bilingual("Kidney stones", "肾结石"),
        params: ["mm": 3, "moving": 0, "scene": 0],
        steps: [
            .watch("Kidneys sit high at the back, tucked under the lowest ribs. Minerals in urine can crystallise into a stone inside them.",
                   "肾脏位于后腰高处、最下面肋骨的下方。尿液中的矿物质可在肾内结晶成结石。", set: ["mm": 3, "moving": 0, "scene": 0]),
            .watch("When it slips into the ureter — a tube only 3–4 mm wide — it causes waves of severe pain from the loin to the groin.",
                   "结石滑入输尿管（仅 3–4 毫米宽）时，会引起从腰部放射到腹股沟的阵发性剧痛。", set: ["moving": 1]),
            .tryIt("Drag the size. The ureter has 3 narrow points; small stones pass, big ones get stuck higher up.",
                   "试一试：拖动大小。输尿管有 3 处狭窄；小结石能排出，大的会卡在更高处。",
                   TryStep(mode: .scrub([Scrub(param: "mm", label: "Size 大小", min: 2, max: 12, unit: "mm", digits: 0)]), success: { $0[v: "mm"] >= 8 },
                           ok: Bilingual("Over ~6 mm often needs shock-wave or laser treatment.", "超过约 6 毫米常需碎石或激光治疗。"), demo: ["mm": 9])),
            .watch("Prevention: 2.5–3 L of water a day (pale urine), less salt. Pain with fever, or no urine → hospital now.",
                   "预防：每天饮水 2.5–3 升（尿色淡），少盐。疼痛伴发热或无尿 → 立即就医。", set: ["scene": 1]),
        ],
        draw: { s, p, t in drawKidneys(&s, p, t) },
        sources: ["AUA / EAU urolithiasis guidelines (spontaneous passage by size)"]
    )

    /// jagged crystal outline
    private static func stonePath(_ c: CGPoint, _ r: Double) -> Path {
        let n = 11
        let pts = (0..<n).map { i -> CGPoint in
            let a = Double(i) / Double(n) * 2 * .pi, k = [1.0, 0.8, 1.05, 0.86, 0.98, 0.78, 1.0, 0.9, 1.06, 0.82, 0.95][i]
            return CGPoint(x: c.x + cos(a) * r * k, y: c.y + sin(a) * r * k)
        }
        return smoothPath(pts)
    }

    @MainActor private static func drawKidneys(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let mm = p[v: "mm"], chance = passChance(mm), moving = p[v: "moving"] > 0.5, prevention = p[v: "scene"] > 0.5
        let ureter = ureterPath
        func along(_ u: Double) -> CGPoint {
            let f = u.clamped(0, 1) * Double(ureter.count - 1), i = min(ureter.count - 2, Int(f)), k = f - Double(i)
            return lerp(ureter[i], ureter[i + 1], k)
        }
        let narrowings: [(Double, String, String)] = [(0.02, "kidney exit", "肾盂出口"), (0.6, "over the iliac artery", "跨髂血管处"), (0.97, "bladder wall", "膀胱壁内")]
        let stuck = mm > 8 ? 0.02 : mm > 6 ? 0.6 : mm > 4 ? 0.97 : 1.2
        let travel = moving ? min(stuck, (t * 0.12).truncatingRemainder(dividingBy: 1.4)) : 0
        let blocked = moving && travel >= stuck - 0.01 && stuck <= 1
        let passed = travel > 1
        let red = Anat.red, urine = hex("#E3C04F"), urineEdge = hex("#B8962E")

        // torso from the front: the person's left is on the picture's right
        s.gradFill("M 34 0 C 38 60, 44 110, 42 142 C 38 180, 22 212, 24 244 C 26 272, 34 292, 36 300 L 100 300 C 104 292, 108 288, 112 286 "
                   + "C 116 288, 120 292, 124 300 L 188 300 C 190 292, 198 272, 200 244 C 202 212, 186 180, 182 142 C 180 110, 186 60, 190 0 Z",
                   [Anat.skinShade, Anat.skin, Anat.skin, Anat.skinShade], from: pt(24, 0), to: pt(200, 0), stroke: Anat.skinEdge, lw: 1.6)
        // lower ribs
        for k in 0..<4 {
            let y = 18 + Double(k) * 20, reach = 64 - Double(k) * 6
            for side in [-1.0, 1.0] {
                s.path("M \(112 + side * 12) \(y) C \(112 + side * 40) \(y + 4), \(112 + side * reach) \(y + 18), \(112 + side * (reach + 4)) \(y + 44 - Double(k) * 4)",
                       stroke: Anat.boneShade.opacity(0.55), lw: 5, cap: .round)
            }
        }
        // pelvis: iliac wings, hip sockets, pubic arch
        for side in [-1.0, 1.0] {
            func x(_ v: Double) -> Double { 112 + side * v }
            s.boneFill("M \(x(14)) 204 C \(x(34)) 186, \(x(62)) 176, \(x(76)) 188 C \(x(80)) 200, \(x(72)) 214, \(x(64)) 222 C \(x(56)) 232, \(x(54)) 244, \(x(50)) 252 "
                       + "C \(x(40)) 262, \(x(20)) 266, \(x(4)) 264 L \(x(4)) 254 C \(x(18)) 254, \(x(32)) 246, \(x(34)) 236 C \(x(30)) 224, \(x(20)) 216, \(x(14)) 214 Z",
                       light: pt(x(40), 190), dark: pt(x(20), 250), fill: hex("#F1EADA"), shade: hex("#E2D6BC"), edge: hex("#C9B99A"), lw: 1)
        }
        s.boneFill("M 98 200 L 126 200 C 126 222, 120 240, 112 250 C 104 240, 98 222, 98 200 Z", light: pt(112, 200), dark: pt(112, 250),
                   fill: hex("#F1EADA"), shade: hex("#E2D6BC"), edge: hex("#C9B99A"), lw: 1)
        // lumbar spine
        for k in 0..<9 {
            let y = 4 + Double(k) * 22
            s.rect(100, y, 24, 17, r: 4, fill: hex("#F1EADA"), stroke: hex("#D6C9AE"), lw: 0.9)
            s.line(94, y + 8, 100, y + 8, stroke: hex("#D6C9AE"), lw: 3, cap: .round)
            s.line(124, y + 8, 130, y + 8, stroke: hex("#D6C9AE"), lw: 3, cap: .round)
        }

        // great vessels: vena cava (picture left) and aorta, splitting into the iliacs
        let vein = hex("#5E7FB8"), artery = hex("#C8404A")
        s.path("M 102 0 L 102 190 C 98 204, 82 222, 70 246", stroke: vein, lw: 6, opacity: 0.8, cap: .round)
        s.path("M 102 190 C 110 206, 132 224, 150 248", stroke: vein, lw: 4, opacity: 0.35, cap: .round)
        s.path("M 120 0 L 120 184 C 112 200, 88 220, 74 246 M 120 184 C 126 200, 140 216, 156 246", stroke: artery, lw: 5, opacity: 0.9, cap: .round)
        s.path("M 102 118 L 90 116 M 120 104 L 132 102", stroke: vein, lw: 4, opacity: 0.8)
        s.path("M 120 112 L 90 112 M 120 98 L 132 98", stroke: artery, lw: 3, opacity: 0.9)

        // pain: the loin glows, pain runs down to the groin
        if moving && !prevention {
            let pulse = 0.5 + 0.5 * sin(t * 3)
            s.softGlow(pt(166, 108), 34, 46, red, 0.25 + 0.15 * pulse)
            s.bendArrow(pt(184, 128), via: pt(192, 214), pt(150, 266), color: red, lw: 1.6, dash: [4, 3])
        }

        // kidneys: cortex, medullary pyramids, renal pelvis funnelling into the ureter; the right one sits a little lower
        func kidney(_ c: CGPoint, side: Double, swollen: Double) {
            s.group(translate: c, rotate: side * 10, about: .zero) { g in
                let sx = side * (1 + 0.12 * swollen), sy = 1 + 0.08 * swollen
                func q(_ x: Double, _ y: Double) -> String { "\(sx * x) \(sy * y)" }
                g.gradFill("M \(q(0, -28)) C \(q(-22, -28)) \(q(-22, 28)) \(q(0, 28)) C \(q(12, 28)) \(q(18, 20)) \(q(14, 8)) C \(q(9, 4)) \(q(9, -4)) \(q(14, -8)) "
                           + "C \(q(18, -20)) \(q(12, -28)) \(q(0, -28)) Z", [hex("#B6505C"), hex("#8E3441")], from: CGPoint(x: -side * 16, y: -20),
                           to: CGPoint(x: side * 14, y: 20), stroke: hex("#6E2632"), lw: 1.2)
                for (a, len) in [(-62.0, 13.0), (-28, 14), (0, 14), (28, 14), (62, 13)] {
                    let r = a * .pi / 180, bx = sx * (-4 - cos(r) * 5), by = sy * sin(r) * 18
                    let tip = CGPoint(x: sx * 5, y: sy * sin(r) * 7)
                    g.path("M \(bx - side * len * 0.1) \(by - 5) L \(tip.x) \(tip.y) L \(bx - side * len * 0.1) \(by + 5) Z", fill: hex("#7A2533"), opacity: 0.8)
                }
                let pelvisW = 1 + 0.5 * swollen
                g.path("M \(q(2, -12)) C \(q(6, -8)) \(q(10, -6 * pelvisW)) \(q(16, -4 * pelvisW)) L \(q(16, 5 * pelvisW)) C \(q(10, 6 * pelvisW)) \(q(6, 8)) \(q(2, 12)) "
                       + "C \(q(5, 4)) \(q(5, -4)) \(q(2, -12)) Z", fill: urine, stroke: urineEdge, lw: 0.8)
                // adrenal gland cap
                g.path("M \(q(-10, -26)) C \(q(-6, -38)) \(q(6, -38)) \(q(8, -26)) C \(q(2, -30)) \(q(-4, -30)) \(q(-10, -26)) Z", fill: hex("#E6B75A"), stroke: hex("#BF9036"), lw: 0.7)
            }
        }
        let swollen = blocked && stuck < 0.9 ? 1.0 : blocked ? 0.5 : 0
        kidney(pt(78, 116), side: 1, swollen: 0)
        kidney(pt(150, 104), side: -1, swollen: swollen)

        // ureters; above a stuck stone the tube balloons with trapped urine
        s.path("M 94 124 C 94 150, 97 176, 96 194 C 92 210, 94 232, 103 250", stroke: urineEdge, lw: 4.2)
        s.path("M 94 124 C 94 150, 97 176, 96 194 C 92 210, 94 232, 103 250", stroke: urine, lw: 2.8)
        var tube = Path()
        tube.move(to: ureter[0])
        for q in ureter.dropFirst() { tube.addLine(to: q) }
        s.shape(tube, stroke: urineEdge, lw: 4.2)
        s.shape(tube, stroke: urine, lw: 2.8)
        if blocked {
            var above = Path()
            above.move(to: ureter[0])
            let n = Int(stuck * Double(ureter.count - 1))
            for i in 1...max(1, n) { above.addLine(to: ureter[i]) }
            above.addLine(to: along(stuck))
            s.shape(above, stroke: urineEdge, lw: 6.5)
            s.shape(above, stroke: urine, lw: 5)
        }
        // bladder behind the pubic bone
        s.gradFill(Path(ellipseIn: CGRect(x: 90, y: 240, width: 44, height: 28)), [hex("#F2DC8C"), urine], from: pt(112, 240), to: pt(112, 268),
                   stroke: urineEdge, lw: 1.2)
        s.ellipse(112, 270, 8, 6, fill: hex("#F1EADA"), stroke: hex("#C9B99A"), lw: 1)

        // narrow points
        for (i, n) in narrowings.enumerated() {
            let q = along(n.0), here = blocked && abs(stuck - n.0) < 0.01
            s.circle(q.x + 11, q.y, 5.5, fill: here ? red : .white, stroke: here ? red : Anat.ink, lw: 0.9)
            s.text("\(i + 1)", q.x + 11, q.y + 3, size: 7.5, color: here ? .white : Anat.ink, anchor: .middle, bold: true)
        }
        // the stone
        let stone = travel <= 0 ? pt(143, 100) : along(min(1, travel))
        if !passed {
            let r = 1.8 + mm * 0.34
            s.gradFill(stonePath(stone, r), [hex("#B79A6A"), hex("#6E5634")], from: pt(stone.x - r, stone.y - r), to: pt(stone.x + r, stone.y + r),
                       stroke: hex("#4A3A22"), lw: 0.9)
        }

        s.leader("kidney", "肾", at: pt(70, 104), 10, 86, color: hex("#8A3B45"), bold: true)
        s.leader("ureter", "输尿管", at: pt(96, 172), 10, 172, color: hex("#8A6A1B"), bold: true)
        s.leader("bladder", "膀胱", at: pt(94, 252), 10, 236, color: hex("#8A6A1B"), bold: true)
        if !moving { s.leader("stone", "结石", at: stone, 150, 148, anchor: .middle, color: Anat.ink, bold: true) }
        if moving && !prevention { s.leader("pain: loin → groin", "疼痛：腰 → 腹股沟", at: pt(198, 290), 204, 292, anchor: .end, color: red, bold: true, dot: false) }

        // right panel
        let px = 216.0, pw = 138.0
        let status = chance >= 0.5 ? Anat.green : red
        s.inset(px, 8, pw, 72, "", "")
        s.rect(px, 8, 5, 72, r: 2.5, fill: status)
        s.label("Stone \(Int(mm.rounded())) mm", "结石 \(Int(mm.rounded())) 毫米", px + 16, 28, size: 11, color: Anat.ink, bold: true)
        s.text("\(Int((chance * 100).rounded()))%", px + 16, 56, size: 24, color: status, bold: true)
        s.label("pass on", "可自行", px + 84, 48, size: 9, color: Anat.text)
        s.label("their own", "排出", px + 84, 60, size: 9, color: Anat.text)
        s.label("typical figures", "常见数据", px + 16, 73, size: 7.5, color: Anat.muted)
        if prevention {
            s.inset(px, 88, pw, 118, "Prevent the next one", "预防复发")
            for i in 0..<3 {
                let x = px + 22 + Double(i) * 36, top = 110.0, fill = Anat.ease((t * 0.5 - Double(i) * 0.3).wrap(3) / 1)
                s.path("M \(x) \(top) L \(x + 24) \(top) L \(x + 21) \(top + 44) L \(x + 3) \(top + 44) Z", fill: hex("#EEF6FC"), stroke: Anat.blue, lw: 1.4)
                let level = top + 44 - 36 * max(0.35, fill)
                s.path("M \(x + 1.5) \(level) L \(x + 22.5) \(level) L \(x + 21) \(top + 44) L \(x + 3) \(top + 44) Z", fill: hex("#8FC4EA"))
            }
            s.label("2.5–3 L water a day", "每天饮水 2.5–3 升", px + pw / 2, 172, size: 10, color: Anat.blue, anchor: .middle, bold: true)
            s.label("pale urine · less salt", "尿色淡 · 少盐", px + pw / 2, 188, size: 9, color: Anat.text, anchor: .middle)
            s.rect(px, 216, pw, 52, r: 9, fill: hex("#FFF1F1"), stroke: red, lw: 1.4)
            s.label("Go to hospital now", "立即就医", px + pw / 2, 234, size: 10, color: red, anchor: .middle, bold: true)
            s.label("pain + fever, or no urine", "疼痛伴发热，或无尿", px + pw / 2, 252, size: 9, color: red, anchor: .middle)
        } else {
            // inside the ureter, to scale: stone against a 3–4 mm tube
            let box = CGRect(x: px, y: 88, width: pw, height: 96), cy = box.midY + 6, k = 4.6
            s.inset(box.minX, box.minY, box.width, box.height, "Inside the ureter, to scale", "输尿管内部（按比例）")
            let sr = min(mm, 12) * k / 2, lumen = 3.5 * k / 2, bulge = max(lumen, sr + 1)
            let tight = sr > lumen + 1.5
            for side in [-1.0, 1.0] {
                let y0 = cy + side * (lumen + 3), yb = cy + side * (bulge + 3)
                s.path("M \(box.minX + 8) \(y0) L \(box.midX - 30) \(y0) C \(box.midX - 14) \(yb), \(box.midX + 14) \(yb), \(box.midX + 30) \(y0) L \(box.maxX - 8) \(y0)",
                       stroke: tight ? red : urineEdge, lw: 4.5)
                s.path("M \(box.minX + 8) \(y0) L \(box.midX - 30) \(y0) C \(box.midX - 14) \(yb), \(box.midX + 14) \(yb), \(box.midX + 30) \(y0) L \(box.maxX - 8) \(y0)",
                       stroke: tight ? hex("#F0A0A0") : urine, lw: 2.5)
            }
            s.gradFill(stonePath(pt(box.midX, cy), sr), [hex("#B79A6A"), hex("#6E5634")], from: pt(box.midX - sr, cy - sr), to: pt(box.midX + sr, cy + sr),
                       stroke: hex("#4A3A22"), lw: 0.9)
            s.line(box.minX + 10, box.maxY - 9, box.minX + 10 + 5 * k, box.maxY - 9, stroke: Anat.ink, lw: 1.5)
            s.text("5 mm", box.minX + 14 + 5 * k, box.maxY - 6, size: 8, color: Anat.text)
            s.text(s.t("tube 3–4 mm", "管径 3–4 毫米"), box.maxX - 8, box.maxY - 6, size: 8, color: Anat.muted, anchor: .end)
            for (i, n) in narrowings.enumerated() {
                let y = 202 + Double(i) * 17
                let here = blocked && abs(stuck - n.0) < 0.01
                s.circle(px + 8, y - 3, 6, fill: here ? red : .white, stroke: here ? red : Anat.ink, lw: 0.9)
                s.text("\(i + 1)", px + 8, y, size: 8, color: here ? .white : Anat.ink, anchor: .middle, bold: true)
                s.label(n.1, n.2, px + 20, y, size: 9, color: here ? red : Anat.text, bold: here)
            }
            if blocked { s.stateChip("Stuck — renal colic", "卡住——肾绞痛", px + pw / 2, 256, color: red, anchor: .middle) }
            if passed { s.stateChip("Passed into the bladder", "已排入膀胱", px + pw / 2, 256, color: Anat.green, anchor: .middle) }
        }
    }

    /// typical size by gestational week (crown–rump before 20 w, crown–heel after)
    static func fetalSize(_ week: Double) -> (cm: Double, g: Double, like: Bilingual, fruit: Int) {
        let table: [(Double, Double, Double, Bilingual)] = [
            (6, 0.6, 0.1, Bilingual("lentil", "扁豆")), (8, 1.6, 1, Bilingual("raspberry", "树莓")), (12, 5.4, 14, Bilingual("lime", "青柠")),
            (16, 11.6, 100, Bilingual("avocado", "牛油果")), (20, 25.6, 300, Bilingual("banana", "香蕉")), (24, 30, 600, Bilingual("ear of corn", "玉米")),
            (28, 37.6, 1000, Bilingual("aubergine", "茄子")), (32, 42.4, 1700, Bilingual("squash", "南瓜")), (36, 47.4, 2600, Bilingual("papaya", "木瓜")),
            (40, 51.2, 3400, Bilingual("watermelon", "西瓜")),
        ]
        let i = max(0, (table.firstIndex { $0.0 >= week } ?? table.count) - 1)
        let a = table[i], b = table[min(table.count - 1, i + 1)]
        let u = b.0 == a.0 ? 0 : ((week - a.0) / (b.0 - a.0)).clamped(0, 1)
        return (a.1 + (b.1 - a.1) * u, a.2 + (b.2 - a.2) * u, u < 0.5 ? a.3 : b.3, u < 0.5 ? i : min(table.count - 1, i + 1))
    }

    /// Curled fetus in its own frame: head up, face toward +x, back toward −x; `rotate` 180 = head down.
    /// `length` is crown to rump in points; `week` sets the proportions (big head and limb buds early, fuller body late).
    static func drawFetus(_ s: inout Sketch, at c: CGPoint, length L: Double, week: Double, rotate: Double, kick: Double = 0, cord: CGPoint? = nil) {
        let skin = hex("#F4C9AE"), shade = hex("#E3A98C"), line = hex("#C98F72")
        let early = ((12 - week) / 6).clamped(0, 1)
        let headFrac = week < 12 ? 0.52 : week < 20 ? 0.52 - (week - 12) / 8 * 0.12 : 0.4 - (week - 20) / 20 * 0.08
        let hr = L * headFrac / 2, top = -L / 2
        let limb = 1 - 0.6 * early
        let fat = ((week - 24) / 16).clamped(0, 1)
        if let cord {
            // cord from the belly to the placenta
            let a = rotate * .pi / 180, b = CGPoint(x: L * 0.16, y: L * 0.12)
            let start = CGPoint(x: c.x + b.x * cos(a) - b.y * sin(a), y: c.y + b.x * sin(a) + b.y * cos(a))
            let d = "M \(start.x) \(start.y) C \(start.x + 10) \(start.y + 18), \(cord.x - 16) \(cord.y + 20), \(cord.x) \(cord.y)"
            s.path(d, stroke: hex("#D9C3D6"), lw: max(1.2, L * 0.05), cap: .round)
            s.path(d, stroke: hex("#B895B6"), lw: 0.6, dash: [2, 2])
        }
        s.group(translate: c, rotate: rotate, about: .zero) { g in
            let head = CGPoint(x: L * 0.06, y: top + hr)
            // far arm and leg, in shade
            if week >= 9 {
                g.limb([pt(-L * 0.02, top + hr * 2.2), pt(L * 0.16 * limb, top + hr * 2.1 + L * 0.1), pt(hr * 0.9, top + hr * 1.5)], w: max(1, L * 0.07), fill: shade, line: nil)
                g.limb([pt(L * 0.02, L * 0.3), pt(L * 0.3 * limb + kick * 0.3, L * 0.02), pt(L * 0.24 * limb, L * 0.36)], w: max(1.2, L * 0.1 * (0.8 + 0.3 * fat)), fill: shade, line: nil)
            }
            // trunk: curved back, rounded rump, belly
            let back = -L * (0.36 + 0.04 * fat), belly = L * (0.24 + 0.08 * fat)
            g.gradFill("M \(-hr * 0.5) \(top + hr * 1.7) C \(back) \(top + L * 0.46), \(back + L * 0.06) \(L * 0.44), \(L * 0.02) \(L * 0.5) "
                       + "C \(belly) \(L * 0.48), \(belly + L * 0.02) \(top + L * 0.56), \(hr * 0.55) \(top + hr * 1.85) Z",
                       [skin, shade], from: CGPoint(x: belly, y: 0), to: CGPoint(x: back, y: 0), stroke: line, lw: 0.8)
            if early > 0.4 {
                // embryo tail
                g.path("M \(L * 0.02) \(L * 0.48) Q \(L * 0.14) \(L * 0.58) \(L * 0.2) \(L * 0.46)", stroke: skin, lw: max(1, L * 0.12), cap: .round)
            }
            // near leg: thigh up toward the chest, shin folded back, foot
            let knee = pt(L * 0.32 * limb + kick, L * 0.06), foot = pt(L * 0.26 * limb + kick * 0.5, L * 0.4)
            g.limb([pt(L * 0.02, L * 0.34), knee, foot], w: max(1.4, L * 0.12 * (0.8 + 0.3 * fat)), fill: skin, line: line)
            if week >= 10 { g.limb([foot, pt(foot.x + L * 0.1 * limb, foot.y + L * 0.02)], w: max(1, L * 0.06), fill: skin, line: line) }
            // near arm, hand up by the face
            g.limb([pt(L * 0.02, top + hr * 2.3), pt(L * 0.2 * limb, top + hr * 2.2 + L * 0.12 * limb), pt(hr * 1.05, top + hr * 1.55)],
                   w: max(1.2, L * 0.075), fill: skin, line: line)
            // head with face
            g.gradFill(Path(ellipseIn: CGRect(x: head.x - hr, y: head.y - hr, width: 2 * hr, height: 2 * hr * 0.97)), [skin, shade],
                       from: CGPoint(x: head.x + hr * 0.6, y: head.y - hr * 0.6), to: CGPoint(x: head.x - hr, y: head.y + hr), stroke: line, lw: 0.9)
            if L > 18 && week >= 11 {
                g.path("M \(head.x + hr * 0.3) \(head.y - hr * 0.05) q \(hr * 0.16) \(hr * 0.1) \(hr * 0.32) 0", stroke: hex("#8A5A48"), lw: max(0.6, hr * 0.06), cap: .round)
                g.path("M \(head.x + hr * 0.92) \(head.y + hr * 0.08) q \(hr * 0.14) \(hr * 0.14) \(hr * 0.02) \(hr * 0.26)", stroke: line, lw: max(0.6, hr * 0.05), cap: .round)
                g.path("M \(head.x + hr * 0.62) \(head.y + hr * 0.62) q \(hr * 0.12) \(hr * 0.04) \(hr * 0.2) -\(hr * 0.02)", stroke: hex("#B5646A"), lw: max(0.6, hr * 0.05), cap: .round)
                g.path("M \(head.x - hr * 0.2) \(head.y + hr * 0.05) c \(-hr * 0.2) 0, \(-hr * 0.22) \(hr * 0.34) 0 \(hr * 0.36)", stroke: line, lw: max(0.6, hr * 0.06))
            } else {
                g.circle(head.x + hr * 0.45, head.y, max(0.6, hr * 0.14), fill: hex("#6B4A4A"))
            }
        }
    }

    /// small everyday-size comparison, drawn in a ~40 pt square centred on c
    @MainActor static func drawFruit(_ s: inout Sketch, _ i: Int, at c: CGPoint) {
        let x = c.x, y = c.y
        switch i {
        case 0: s.ellipse(x, y, 5, 3.5, fill: hex("#C08A4A"), stroke: hex("#8A5E2A"))
        case 1:
            for (dx, dy) in [(-5.0, -4.0), (0, -6), (5, -4), (-6, 1), (0, 0), (6, 1), (-4, 6), (2, 7), (5, 5)] {
                s.circle(x + dx, y + dy + 2, 3.6, fill: hex("#D8436A"), stroke: hex("#A82A4E"), lw: 0.6)
            }
            s.path("M \(x - 4) \(y - 8) L \(x) \(y - 5) L \(x + 4) \(y - 8)", stroke: hex("#5E9A4A"), lw: 1.6)
        case 2:
            s.gradFill(Path(ellipseIn: CGRect(x: x - 14, y: y - 11, width: 28, height: 22)), [hex("#A8D86A"), hex("#5E9E32")], from: pt(x - 8, y - 8), to: pt(x + 10, y + 10), stroke: hex("#4A7E28"))
            s.circle(x - 5, y - 4, 3, fill: .white, opacity: 0.5)
        case 3:
            s.path("M \(x) \(y - 16) C \(x + 9) \(y - 16), \(x + 8) \(y - 4), \(x + 12) \(y + 4) C \(x + 16) \(y + 16), \(x - 16) \(y + 16), \(x - 12) \(y + 4) C \(x - 8) \(y - 4), \(x - 9) \(y - 16), \(x) \(y - 16) Z",
                   fill: hex("#5E8A2E"), stroke: hex("#3E6420"))
            s.path("M \(x) \(y - 10) C \(x + 6) \(y - 10), \(x + 5) \(y), \(x + 8) \(y + 5) C \(x + 10) \(y + 12), \(x - 10) \(y + 12), \(x - 8) \(y + 5) C \(x - 5) \(y), \(x - 6) \(y - 10), \(x) \(y - 10) Z", fill: hex("#E4EDA0"))
            s.circle(x, y + 5, 5, fill: hex("#8A5A30"))
        case 4:
            s.path("M \(x - 20) \(y - 6) C \(x - 12) \(y + 14), \(x + 12) \(y + 14), \(x + 20) \(y - 8) C \(x + 14) \(y + 4), \(x - 12) \(y + 4), \(x - 20) \(y - 6) Z",
                   fill: hex("#F2D04E"), stroke: hex("#C9A42A"))
            s.line(x + 20, y - 8, x + 22, y - 11, stroke: hex("#6B5A2A"), lw: 2, cap: .round)
        case 5:
            s.path("M \(x - 8) \(y + 18) C \(x - 12) \(y), \(x - 8) \(y - 16), \(x) \(y - 20) C \(x + 8) \(y - 16), \(x + 12) \(y), \(x + 8) \(y + 18) Z", fill: hex("#F2C94E"), stroke: hex("#C99A2A"))
            for k in 0..<5 { s.line(x - 6, y - 12 + Double(k) * 6, x + 6, y - 12 + Double(k) * 6, stroke: hex("#D9A838"), lw: 0.6) }
            s.path("M \(x - 8) \(y + 18) C \(x - 16) \(y + 4), \(x - 12) \(y - 8), \(x - 6) \(y - 14) M \(x + 8) \(y + 18) C \(x + 16) \(y + 4), \(x + 12) \(y - 8), \(x + 6) \(y - 14)",
                   stroke: hex("#6FA84A"), lw: 3, cap: .round)
        case 6:
            s.gradFill("M \(x - 18) \(y + 6) C \(x - 20) \(y - 6), \(x - 4) \(y - 12), \(x + 12) \(y - 8) C \(x + 20) \(y - 6), \(x + 20) \(y + 6), \(x + 10) \(y + 10) C \(x) \(y + 13), \(x - 16) \(y + 14), \(x - 18) \(y + 6) Z",
                       [hex("#8E5BB5"), hex("#4E2A70")], from: pt(x, y - 10), to: pt(x, y + 12), stroke: hex("#3E2060"))
            s.path("M \(x + 12) \(y - 8) C \(x + 16) \(y - 14), \(x + 20) \(y - 12), \(x + 22) \(y - 16) M \(x + 10) \(y - 8) L \(x + 18) \(y - 2)", stroke: hex("#5E9A4A"), lw: 2.4, cap: .round)
        case 7:
            s.path("M \(x - 6) \(y - 18) C \(x + 6) \(y - 18), \(x + 6) \(y - 6), \(x + 8) \(y) C \(x + 18) \(y + 6), \(x + 12) \(y + 20), \(x) \(y + 20) C \(x - 12) \(y + 20), \(x - 18) \(y + 6), \(x - 8) \(y) C \(x - 6) \(y - 6), \(x - 16) \(y - 18), \(x - 6) \(y - 18) Z",
                   fill: hex("#F0C27A"), stroke: hex("#C9954A"))
            s.line(x - 1, y - 18, x, y - 22, stroke: hex("#6B5A2A"), lw: 2, cap: .round)
        case 8:
            s.gradFill(Path(ellipseIn: CGRect(x: x - 20, y: y - 13, width: 40, height: 26)), [hex("#F6A04A"), hex("#D96A2A")], from: pt(x, y - 12), to: pt(x, y + 12), stroke: hex("#B5561E"))
            s.ellipse(x + 4, y, 10, 6, fill: hex("#F7C27A"))
            for k in 0..<4 { s.circle(x + Double(k) * 4 - 2, y, 1.4, fill: hex("#3A2A20")) }
        default:
            s.gradFill(Path(ellipseIn: CGRect(x: x - 20, y: y - 18, width: 40, height: 36)), [hex("#7CC45A"), hex("#2E7A3A")], from: pt(x - 10, y - 14), to: pt(x + 12, y + 16), stroke: hex("#245E2C"))
            for k in -2...2 { s.path("M \(x + Double(k) * 7) \(y - 17) C \(x + Double(k) * 9) \(y - 6), \(x + Double(k) * 9) \(y + 6), \(x + Double(k) * 7) \(y + 17)", stroke: hex("#245E2C"), lw: 1.4, opacity: 0.7) }
        }
    }

    static let fetalGrowth = Scenario(
        id: "fetal-growth", group: .pregnancy, title: Bilingual("Pregnancy week by week", "孕期胎儿发育"),
        params: ["week": 8],
        steps: [
            .watch("Week 8: the heart is beating; about the size of a raspberry. Nothing shows outside yet.", "第 8 周：心脏已开始跳动，约树莓大小。外表还看不出怀孕。", set: ["week": 8]),
            .watch("Week 12: all organs formed; the womb rises just above the pubic bone. First-trimester scan.", "第 12 周：器官基本形成；子宫刚超出耻骨。孕早期超声检查。", set: ["week": 12]),
            .watch("Week 20: halfway. The top of the womb reaches the navel; first kicks are felt.", "第 20 周：孕期过半。宫底到达肚脐；开始感到胎动。", set: ["week": 20]),
            .watch("Week 28: eyes open; a baby born now often survives with intensive care.", "第 28 周：眼睛睁开；此时早产经重症监护多可存活。", set: ["week": 28]),
            .watch("Week 40: full term — about 50 cm and 3.4 kg, usually head down, the womb up under the ribs.", "第 40 周：足月——约 50 厘米、3.4 公斤，多为头朝下，子宫顶到肋下。", set: ["week": 40]),
            .tryIt("Drag through the weeks and watch the belly grow.", "试一试：拖动孕周，看肚子长大。",
                   TryStep(mode: .scrub([Scrub(param: "week", label: "Week 孕周", min: 6, max: 40, digits: 0)]), success: { _ in true },
                           ok: Bilingual("From week 20, fundal height (cm above the pubic bone) ≈ weeks — midwives measure it with a tape.",
                                         "约 20 周后，宫高（耻骨上厘米数）≈ 孕周数——产检时用软尺测量。"))),
        ],
        draw: { s, p, t in drawGrowth(&s, p[v: "week"], t) },
        sources: ["Typical fetal length/weight by gestational age (ACOG, Hadlock)", "Fundal height ≈ gestational weeks (cm) from 20 w"]
    )

    // Mother side-on, facing right, womb cut open; 2.85 pt per cm: pubic bone y 236, navel y 176, breastbone tip y 132.
    @MainActor private static func drawGrowth(_ s: inout Sketch, _ week: Double, _ t: Double) {
        let size = fetalSize(week)
        let purple = Anat.purple, label = hex("#8A5A6A")
        let pubis = 236.0, pxPerCm = 2.85
        let marks: [(Double, Double)] = [(6, 238), (12, 226), (20, 176), (28, 154), (36, 130), (40, 136)]
        let i = max(0, (marks.firstIndex { $0.0 >= week } ?? marks.count) - 1)
        let (w0, y0) = marks[i], (w1, y1) = marks[min(marks.count - 1, i + 1)]
        let fundus = w1 == w0 ? y0 : y0 + (y1 - y0) * ((week - w0) / (w1 - w0)).clamped(0, 1)
        let grow = ((236 - fundus) / 106).clamped(0, 1)
        // womb: pear from the cervix up to the fundus, leaning forward as it grows
        let cervix = pt(122, 244)
        let height = max(24, cervix.y - fundus + 6), width = 12 + height * 0.7
        let cx = cervix.x + 6 + grow * 20, top = cervix.y - height
        func wombPoint(_ u: Double, _ side: Double) -> CGPoint {
            // u 0 cervix … 1 fundus along each side
            let a = (1 - u) * (1 - u) * (1 - u), b = 3 * u * (1 - u) * (1 - u), c = 3 * u * u * (1 - u), d = u * u * u
            let x = a * (cervix.x + side * 5) + b * (cx + side * width * 0.5) + c * (cx + side * width * 0.5) + d * cx
            let y = a * cervix.y + b * (cervix.y - height * 0.22) + c * (top + 3) + d * top
            return pt(x, y)
        }
        // belly front: womb front plus the abdominal wall, never inside the resting profile
        var front: [CGPoint] = []
        for k in 0...24 {
            let q = wombPoint(1 - Double(k) / 24, 1)
            guard q.y > 126, q.y < 232 else { continue }
            let rest = q.y < 150 ? 150 - (q.y - 134) * 0.05 : 146
            front.append(pt(max(rest, q.x + 6 + 3 * grow), q.y))
        }
        let bx = front.map(\.x).max() ?? 150
        let navelX = front.min { abs($0.y - 176) < abs($1.y - 176) }?.x ?? 146
        let belly = front.map { "L \($0.x) \($0.y) " }.joined()
        let skin = Anat.skin, edge = Anat.skinEdge

        // far arm, behind the body
        s.limb([pt(114, 80), pt(100, 150), pt(104, 206)], w: 12, fill: Anat.skinShade, line: edge)
        // body
        s.gradFill("M 132 58 C 134 66, 142 74, 152 82 C 166 94, 166 112, 154 122 C 150 126, 149 130, 150 134 " + belly + "L 146 236 "
                   + "C 146 244, 142 250, 138 254 C 140 272, 142 290, 142 300 L 90 300 C 88 280, 84 258, 82 236 C 78 212, 88 186, 92 160 "
                   + "C 94 132, 86 102, 96 78 C 100 70, 106 62, 110 56 Z",
                   [skin, skin, Anat.skinShade], from: pt(bx, 0), to: pt(84, 0), stroke: edge, lw: 1.6)
        s.rect(112, 44, 20, 20, fill: skin)
        s.gradFill(Path(ellipseIn: CGRect(x: 101, y: 9, width: 42, height: 42)), [skin, Anat.skinShade], from: pt(136, 20), to: pt(104, 46), stroke: edge, lw: 1.6)
        s.path("M 141 24 L 147 34 L 141 36 C 142 40, 141 44, 136 48", fill: skin, stroke: edge, lw: 1.2)
        s.path("M 134 25 q 3 -1.5 5 0", stroke: hex("#4A4550"), lw: 1.3, cap: .round)
        s.path("M 102 32 C 96 10, 130 0, 142 18 C 128 14, 114 18, 106 40 Z", fill: hex("#5B4033"))
        s.circle(98, 30, 7, fill: hex("#5B4033"))
        // spine and pubic bone
        s.path("M 104 70 C 96 110, 100 150, 106 186 C 110 206, 106 226, 104 242", stroke: hex("#E9DFCB"), lw: 6, cap: .round)
        s.path("M 104 70 C 96 110, 100 150, 106 186 C 110 206, 106 226, 104 242", stroke: hex("#D6C9AE"), lw: 1, dash: [5, 3])
        s.boneFill(Path(ellipseIn: CGRect(x: 138, y: pubis - 9, width: 10, height: 18)), light: pt(140, pubis - 8), dark: pt(148, pubis + 8))

        // womb wall, fluid, placenta
        var womb = Path()
        womb.move(to: wombPoint(0, -1))
        for k in 1...24 { womb.addLine(to: wombPoint(Double(k) / 24, -1)) }
        for k in (0...24).reversed() { womb.addLine(to: wombPoint(Double(k) / 24, 1)) }
        womb.closeSubpath()
        s.gradFill(womb, [hex("#E7A0AE"), hex("#CF7C8E")], from: pt(cx, top), to: pt(cx, cervix.y), stroke: hex("#B5627A"), lw: 1)
        let wall = 3 + 2 * grow, mid = (top + cervix.y) / 2
        let inner = womb.applying(CGAffineTransform(translationX: cx, y: mid).scaledBy(x: 1 - wall * 2 / max(width, 1), y: 1 - wall * 2 / height)
                                    .translatedBy(x: -cx, y: -mid))
        s.gradFill(inner, [hex("#FDEDEF"), hex("#F7D6DC")], from: pt(cx, top), to: pt(cx, cervix.y))
        let placenta = pt(cx - width * 0.28, top + height * 0.3)
        if week >= 9 {
            s.gradFill(Path(ellipseIn: CGRect(x: placenta.x - max(3, width * 0.13), y: placenta.y - height * 0.2, width: max(6, width * 0.26), height: height * 0.4)),
                       [hex("#B84A62"), hex("#8A2E46")], from: pt(placenta.x, placenta.y - 10), to: pt(placenta.x, placenta.y + 10))
        }
        s.path("M \(cervix.x - 6) \(cervix.y - 2) L \(cervix.x - 4) \(cervix.y + 10) M \(cervix.x + 6) \(cervix.y - 2) L \(cervix.x + 4) \(cervix.y + 10)",
               stroke: hex("#D9A0AE"), lw: 2, cap: .round)

        // fetus: grows, and turns head-down from ~30 weeks
        let length = min((height - 10) * 0.78, max(3, size.cm * pxPerCm * 0.6))
        let turn = ((week - 29) / 5).clamped(0, 1) * 180
        let kick = week >= 18 ? pow(max(0, sin(t * 3)), 8) * length * 0.05 : 0
        let centre = pt(cx + 3, cervix.y - height * (0.5 - 0.04 * turn / 180))
        drawFetus(&s, at: centre, length: length, week: week, rotate: 20 - turn * 1.05, kick: kick, cord: week >= 9 ? placenta : nil)

        // landmarks and the tape measure
        s.circle(navelX - 2, 176, 2, fill: label)
        s.circle(151, 132, 2, fill: label)
        if week >= 16 {
            let x = bx + 12
            s.line(x, pubis, x, fundus, stroke: hex("#E9BE45"), lw: 6, cap: .round)
            var cm = 0.0
            while pubis - cm * pxPerCm >= fundus - 0.5 {
                s.line(x - 3, pubis - cm * pxPerCm, x + (Int(cm) % 10 == 0 ? 3 : 1), pubis - cm * pxPerCm, stroke: hex("#8A6A1B"), lw: 0.8); cm += 5
            }
            s.line(x - 6, fundus, x + 6, fundus, stroke: hex("#8A6A1B"), lw: 1.2)
        }
        s.leader("pubic bone", "耻骨", at: pt(144, pubis + 6), 156, 262, color: Anat.text, size: 8)
        s.leader("womb", "子宫", at: pt(cx - width * 0.4, top + height * 0.55), 18, 150, color: hex("#A0506A"), size: 8)
        if week >= 16 {
            s.leader("placenta", "胎盘", at: placenta, 18, 172, color: hex("#8A2E46"), size: 8)
        }

        // right panel
        let px = 216.0, pw = 138.0
        s.label("Week \(Int(week.rounded()))", "第 \(Int(week.rounded())) 周", px, 22, size: 18, color: purple, bold: true)
        s.inset(px, 34, pw, 58, "", "")
        drawFruit(&s, size.fruit, at: pt(px + 28, 63))
        s.text(s.zh ? "约\(size.like.zh)大小" : "≈ \(size.like.en)", px + 56, 54, size: 10, color: purple, bold: true)
        s.text(String(format: "%.1f cm", size.cm), px + 56, 69, size: 9, color: Anat.text)
        s.text(size.g < 10 ? String(format: "%.1f g", size.g) : size.g < 1000 ? "\(Int(size.g.rounded())) g" : String(format: "%.1f kg", size.g / 1000),
               px + 56, 82, size: 9, color: Anat.text)
        let milestone: (String, String) = week < 10 ? ("Heart beating", "心脏开始跳动") : week < 14 ? ("All organs formed", "器官基本形成")
            : week < 18 ? ("Moves, not felt yet", "会动，还感觉不到") : week < 24 ? ("First kicks felt", "能感到胎动")
            : week < 30 ? ("Can survive in NICU", "早产经监护可存活") : week < 34 ? ("Turning head-down", "转为头朝下")
            : week < 37 ? ("Lungs maturing", "肺部逐渐成熟") : ("Full term", "足月，随时可分娩")
        s.stateChip(milestone.0, milestone.1, px, 102, color: purple)
        if week < 16 {
            // too small to see in the body: magnified view in its fluid sac
            let c = pt(px + pw / 2, 192), r = 50.0
            s.circle(c.x, c.y, r + 2, fill: .black.opacity(0.06))
            s.gradFill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), [hex("#FDEDEF"), hex("#F2C6CF")],
                       from: pt(c.x, c.y - r), to: pt(c.x, c.y + r), stroke: hex("#C97488"), lw: 1.5)
            let scale = week < 10 ? 16.0 : 6.0
            let L = min(66, size.cm * pxPerCm * 0.6 * scale)
            s.path("M \(c.x - r + 6) \(c.y - 18) C \(c.x - 30) \(c.y - 14), \(c.x - 20) \(c.y), \(c.x - 6) \(c.y + 6)", stroke: hex("#D9C3D6"), lw: 2.4, cap: .round)
            s.gradFill(Path(ellipseIn: CGRect(x: c.x - r + 1, y: c.y - 30, width: 12, height: 60)), [hex("#B84A62"), hex("#8A2E46")], from: pt(c.x, c.y - 30), to: pt(c.x, c.y + 30))
            drawFetus(&s, at: pt(c.x + 6, c.y + 2), length: L, week: week, rotate: 20)
            s.cardNote("magnified ×\(Int(scale))", "放大 \(Int(scale)) 倍", c.x, c.y + r - 9, width: 80, size: 7.5, color: Anat.muted)
        }
        if week >= 16 {
            let fh = (pubis - fundus) / pxPerCm
            s.label("fundal height", "宫高", px, 152, size: 9, color: hex("#8A6A1B"))
            s.label("≈ \(Int(fh.rounded())) cm", "≈ \(Int(fh.rounded())) 厘米", px, 172, size: 15, color: hex("#8A6A1B"), bold: true)
            s.label("pubic bone → top of womb", "耻骨上缘 → 宫底", px, 188, size: 8, color: Anat.muted)
        }
        // trimester bar
        let bw = pw
        for (a, b, col) in [(0.0, 13.0, hex("#E8E2F6")), (13, 27, hex("#D3C6EC")), (27, 40, hex("#B7A3DD"))] {
            s.rect(px + a / 40 * bw, 262, (b - a) / 40 * bw - 1, 10, r: 2, fill: col)
        }
        s.label("1st", "孕早期", px + 6.5 / 40 * bw, 286, size: 8, color: purple, anchor: .middle)
        s.label("2nd", "孕中期", px + 20 / 40 * bw, 286, size: 8, color: purple, anchor: .middle)
        s.label("3rd", "孕晚期", px + 33.5 / 40 * bw, 286, size: 8, color: purple, anchor: .middle)
        s.path("M \(px + week / 40 * bw) 260 l -5 -8 l 10 0 Z", fill: purple)
    }

    /// cervix opening compared with everyday things, 0–10 cm
    static let dilationLike: [Bilingual] = [
        Bilingual("closed", "闭合"), Bilingual("fingertip", "指尖"), Bilingual("grape", "葡萄"), Bilingual("banana slice", "香蕉片"),
        Bilingual("cracker", "饼干"), Bilingual("lime slice", "青柠片"), Bilingual("cookie", "曲奇"), Bilingual("tomato slice", "番茄片"),
        Bilingual("orange slice", "橙子片"), Bilingual("doughnut", "甜甜圈"), Bilingual("bagel", "贝果"),
    ]

    static let labor = Scenario(
        id: "labor", group: .pregnancy, title: Bilingual("Labour & birth", "分娩过程"),
        params: ["cm": 1, "descent": 0, "placenta": 0, "hosp": 0],
        steps: [
            .watch("Early labour: irregular contractions slowly thin (efface) and open the cervix — the neck of the womb.",
                   "潜伏期：不规律宫缩使宫颈（子宫下端的“颈”）逐渐变薄、扩张。", set: ["cm": 2, "descent": 0, "placenta": 0, "hosp": 0]),
            .watch("Active labour (from ~6 cm): strong contractions every 2–3 minutes, each about a minute long.",
                   "活跃期（约 6 厘米起）：强宫缩每 2–3 分钟一次，每次约 1 分钟。", set: ["cm": 7]),
            .tryIt("Open the cervix to full dilation — 10 cm, about the size of a bagel.", "试一试：宫口开全——10 厘米，约一个贝果大。",
                   TryStep(mode: .scrub([Scrub(param: "cm", label: "Dilation 宫口", min: 0, max: 10, unit: "cm", digits: 0)]), success: { $0[v: "cm"] >= 9.8 },
                           ok: Bilingual("Fully dilated — time to push.", "宫口开全——开始用力。"), demo: ["cm": 10])),
            .tryIt("Stage 2: with each push the head turns and moves down the birth canal, under the pubic bone and out.",
                   "试一试：第二产程：每次用力，胎头旋转并沿产道下降，从耻骨下方娩出。", set: ["cm": 10],
                   TryStep(mode: .scrub([Scrub(param: "descent", label: "Descent 下降", min: 0, max: 1)]), success: { $0[v: "descent"] >= 0.95 },
                           ok: Bilingual("Born! Straight onto mum’s chest, skin to skin.", "宝宝出生了！马上放到妈妈胸前，肌肤接触。"), demo: ["descent": 1])),
            .watch("Stage 3: the womb clamps down and the placenta follows, usually within 30 minutes.", "第三产程：子宫收缩变硬，胎盘随后娩出，通常在 30 分钟内。",
                   set: ["descent": 1, "placenta": 1]),
            .watch("Go to hospital: first baby — contractions every 5 min, lasting 1 min, for 1 hour; or waters break, bleeding, fewer movements.",
                   "何时去医院：初产妇宫缩每 5 分钟一次、每次 1 分钟、持续 1 小时；或破水、出血、胎动减少。", set: ["cm": 3, "descent": 0, "placenta": 0, "hosp": 1]),
        ],
        draw: { s, p, t in drawLabor(&s, p, t) },
        sources: ["WHO intrapartum care 2018 (active phase from 5–6 cm)", "5-1-1 rule for first labours (ACOG patient guidance)"]
    )

    /// head centre on the way out: engaged at the pelvic inlet … under the pubic arch … out (curve of Carus)
    static func laborHead(_ u: Double) -> CGPoint {
        let a = (1 - u) * (1 - u), b = 2 * u * (1 - u), c = u * u
        return pt(a * 128 + b * 132 + c * 178, a * 196 + b * 276 + c * 292)
    }

    // Sagittal section, mother facing right: womb above the pelvis, birth canal curving down and forward.
    @MainActor private static func drawLabor(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let cm = p[v: "cm"], descent = p[v: "descent"], placenta = p[v: "placenta"]
        let period = cm < 6 ? 6.0 : 2.5
        let sq = pow(max(0, sin(t / period * 2 * .pi)), 3)
        let born = descent > 0.95
        let label = hex("#8A3B45"), purple = Anat.purple
        // body outline
        s.gradFill("M 30 0 C 26 70, 34 150, 48 196 C 36 226, 44 262, 80 282 C 100 292, 120 298, 140 300 L 172 300 C 176 284, 182 272, 190 262 "
                   + "C 212 240, 238 190, 238 120 C 238 60, 224 20, 216 0 Z", [Anat.skinShade, Anat.skin, Anat.skin], from: pt(30, 0), to: pt(238, 0),
                   stroke: Anat.skinEdge, lw: 1.6)
        // lumbar spine, sacrum and coccyx; pubic bone in front
        for k in 0..<5 {
            let y = 4 + Double(k) * 22
            s.rect(34 + Double(k) * 1.5, y, 20, 18, r: 4, fill: hex("#F1EADA"), stroke: hex("#D6C9AE"), lw: 0.9, opacity: 0.7)
        }
        // birth canal
        s.path("M 114 222 C 114 252, 128 278, 148 300 M 146 222 C 150 248, 164 268, 180 294", stroke: hex("#D9A0AE"), lw: 3)

        // womb: wall thickens with each contraction; its lower part is drawn down around the head as it descends; after the birth it shrinks
        // an emptied womb contracts to about half its size, then more once the placenta is out
        let emptied = min(1, max(0, (descent - 0.85) / 0.15))
        let shrink = 1 - 0.38 * emptied - 0.14 * placenta, follow = pt(8 * sin(.pi * descent), 34 * sin(.pi * descent))
        let gap = cm / 10 * 32, lip = 14 * (1 - min(cm, 4) / 4) + 4
        let wall = 7 + sq * 6 + 6 * placenta
        s.group(translate: pt(130 * (1 - shrink) + follow.x, 218 * (1 - shrink) + follow.y), scale: shrink) { g in
            let d = "M \(130 - gap / 2 - 10) 216 C 62 202, 44 112, 76 52 C 98 12, 174 6, 200 40 C 232 90, 218 198, \(130 + gap / 2 + 10) 216"
            g.path(d, fill: hex("#FBE6EA"))
            g.path(d, stroke: hex("#C97488"), lw: wall + 1.5)
            g.path(d, stroke: hex("#E59AAB"), lw: wall - 1)
            g.line(130 - gap / 2 - 12, 214, 130 - gap / 2 - 2, 214 + lip, stroke: label, lw: 6, cap: .round)
            g.line(130 + gap / 2 + 12, 214, 130 + gap / 2 + 2, 214 + lip, stroke: label, lw: 6, cap: .round)
            if placenta < 0.5 && !born {
                g.gradFill("M 66 70 C 58 102, 62 132, 72 148 C 88 134, 96 98, 88 64 Z", [hex("#B84A62"), hex("#8A2E46")], from: pt(70, 70), to: pt(88, 140))
            }
        }
        // sacrum and coccyx behind, pubic bone in front: the bony ring the baby must pass
        s.path("M 58 116 C 48 160, 60 214, 96 252 C 104 260, 112 266, 118 268", stroke: Anat.boneEdge, lw: 15, cap: .round)
        s.path("M 58 116 C 48 160, 60 214, 96 252 C 104 260, 112 266, 118 268", stroke: Anat.bone, lw: 13, cap: .round)
        for k in 0..<4 { let y = 140 + Double(k) * 24; s.line(50 + Double(k) * 3, y, 64 + Double(k) * 6, y - 2, stroke: Anat.boneShade, lw: 1) }
        s.boneFill(Path(ellipseIn: CGRect(x: 180, y: 222, width: 14, height: 32)), light: pt(182, 224), dark: pt(192, 252))
        // ischial spines level = station 0
        s.line(66, 226, 180, 226, stroke: Anat.muted, lw: 0.8, dash: [3, 3])
        if sq > 0.2 && placenta < 0.5 && !born {
            for k in 0..<3 {
                let a = Double(k) * 0.9 + 0.5
                s.path("M \(130 + follow.x + cos(a + 3.6) * 104) \(118 + follow.y + sin(a + 3.6) * 106) l \(cos(a + 3.6) * -8 * sq) \(sin(a + 3.6) * -8 * sq)", stroke: hex("#C97488"), lw: 2, opacity: sq, cap: .round)
            }
        }

        // baby: head leads, chin tucked; it extends under the pubic bone at the end
        if !born {
            let head = laborHead(descent), L = 128.0, rot = 180 - 60 * Anat.ease((descent - 0.45) / 0.55)
            let hr = L * 0.33 / 2
            let local = pt(L * 0.06, -L / 2 + hr), r = rot * .pi / 180
            let centre = pt(head.x - (local.x * cos(r) - local.y * sin(r)), head.y - (local.x * sin(r) + local.y * cos(r)))
            drawFetus(&s, at: centre, length: L, week: 40, rotate: rot, cord: placenta < 0.5 ? pt(80 + follow.x, 104 + follow.y) : nil)
        }
        if placenta > 0.02 {
            let pc = lerp(pt(132, 228), pt(160, 288), Anat.ease(placenta))
            s.gradFill(Path(ellipseIn: CGRect(x: pc.x - 12, y: pc.y - 9, width: 24, height: 18)), [hex("#B84A62"), hex("#8A2E46")], from: pt(pc.x, pc.y - 9), to: pt(pc.x, pc.y + 9))
        }

        // labels
        s.leader("sacrum", "骶骨", at: pt(60, 170), 8, 190, size: 8)
        s.leader("pubic bone", "耻骨", at: pt(190, 246), 196, 270, size: 8)
        s.label("station 0", "0 位", 66, 222, size: 7.5, color: Anat.muted, anchor: .end)
        if placenta < 0.5 && !born { s.leader("placenta", "胎盘", at: pt(76 + follow.x, 90 + follow.y), 8, 60, color: label, size: 8) }
        s.leader("cervix", "宫颈", at: pt(130 + gap / 2 + 8 + follow.x, 220 + follow.y), 206, 208, color: label, size: 8)
        if placenta > 0.5 { s.leader("placenta out", "胎盘娩出", at: pt(160, 288), 196, 292, color: label, size: 8) }
        if sq > 0.3 && placenta < 0.5 && !born { s.label("contraction", "宫缩", 150, 36, size: 10, color: hex("#B5627A"), anchor: .middle, bold: true) }

        // stage chip and right panel
        let stage: (String, String) = placenta > 0.5 ? ("Stage 3 · placenta", "第三产程 · 胎盘") : descent > 0.05 ? ("Stage 2 · birth", "第二产程 · 娩出")
            : cm < 6 ? ("Stage 1 · early", "第一产程 · 潜伏期") : ("Stage 1 · active", "第一产程 · 活跃期")
        s.stateChip(stage.0, stage.1, 354, 8, color: purple, anchor: .end)
        let box = CGRect(x: 244, y: 40, width: 110, height: 128)
        if born {
            s.inset(box.minX, box.minY, box.width, box.height, "Skin to skin", "肌肤接触")
            // mum reclined on a pillow, baby lying on her chest under a blanket
            var c = s.clipped(box.minX, box.minY, box.width, box.height)
            let bed = box.maxY - 26
            c.rect(box.minX + 4, bed, box.width - 8, 8, r: 3, fill: hex("#DCE6F2"), stroke: hex("#9FB3CC"), lw: 0.8)
            c.path("M \(box.minX + 8) \(bed) C \(box.minX + 6) \(bed - 30), \(box.minX + 26) \(bed - 40), \(box.minX + 34) \(bed - 20) L \(box.minX + 34) \(bed) Z",
                   fill: .white, stroke: hex("#C9CFD8"), lw: 0.8)
            var mum = SideFigure(h: 96, look: .woman, hip: pt(box.minX + 58, bed - 8), rotation: -62)
            mum.nearLeg = .init(hip: 36, knee: 6, point: 20)
            mum.farLeg = .init(hip: 40, knee: 14, point: 20)
            let chest = mum.front(0.55)
            mum.near = .init(reach: pt(chest.x + 6, chest.y - 2), hand: .open)
            mum.far = .init(reach: pt(chest.x + 2, chest.y + 4), hand: .open)
            mum.drawBack(&c)
            mum.drawBody(&c)
            // baby: prone, head toward mum's face, knees tucked
            let b = pt(chest.x + 3, chest.y - 7)
            c.ellipse(b.x + 6, b.y + 3, 12, 6.5, fill: hex("#F4C9AE"), stroke: hex("#C98F72"), lw: 0.8)
            c.circle(b.x - 7, b.y - 2, 6.5, fill: hex("#F4C9AE"), stroke: hex("#C98F72"), lw: 0.8)
            c.path("M \(b.x - 9) \(b.y - 2) q 2 1.2 4 0", stroke: hex("#8A5A48"), lw: 0.8, cap: .round)
            c.path("M \(b.x) \(b.y + 2) C \(b.x + 6) \(b.y - 6), \(b.x + 18) \(b.y - 4), \(b.x + 22) \(b.y + 6) L \(b.x + 20) \(b.y + 11) L \(b.x) \(b.y + 9) Z",
                   fill: hex("#F3E3A6"), stroke: hex("#CDB86A"), lw: 0.8)
            mum.drawArm(&c, near: true)
            s.cardNote(placenta > 0.5 ? "placenta within 30 min" : "born!", placenta > 0.5 ? "30 分钟内娩出胎盘" : "出生了！",
                       box.midX, box.maxY - 9, width: 106, size: 8.5, color: Anat.green, bold: true)
        } else {
            // the cervix seen from below, to scale (2.4 pt per mm)
            s.inset(box.minX, box.minY, box.width, box.height, "Cervix from below", "宫颈（仰视）")
            let c = pt(box.midX, box.minY + 62), open = cm * 2.4
            s.shape(Path(ellipseIn: CGRect(x: c.x - 26, y: c.y - 26, width: 52, height: 52)), stroke: Anat.muted, lw: 0.8, dash: [3, 3])
            let rr = open + 5 + lip * 0.8
            s.gradFill(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: 2 * rr, height: 2 * rr)),
                       [hex("#F0B6C3"), hex("#D98398")], from: pt(c.x, c.y - 30), to: pt(c.x, c.y + 30), stroke: hex("#B5627A"))
            s.circle(c.x, c.y, max(1, open), fill: cm > 6 ? hex("#E8B89A") : hex("#7A2E3E"))
            if cm > 6 { s.path("M \(c.x - open * 0.5) \(c.y - open * 0.2) q \(open * 0.5) \(-open * 0.3) \(open) 0", stroke: hex("#8A5A48"), lw: 0.8, opacity: 0.6) }
            s.label("\(Int(cm.rounded())) cm", "\(Int(cm.rounded())) 厘米", box.midX, box.maxY - 22, size: 12, color: label, anchor: .middle, bold: true)
            let like = dilationLike[min(10, max(0, Int(cm.rounded())))]
            s.label("≈ " + like.en, "≈ " + like.zh, box.midX, box.maxY - 8, size: 8.5, color: Anat.text, anchor: .middle)
        }
        // contraction trace
        let tx = 244.0, ty = 222.0, tw = 110.0
        s.label("contractions", "宫缩", tx, 184, size: 9, color: hex("#B5627A"), bold: true)
        var trace = Path()
        for i in 0...60 {
            let x = Double(i) / 60 * tw, time = x / tw * 12
            let y = ty - pow(max(0, sin(time / period * 2 * .pi)), 3) * 28
            if i == 0 { trace.move(to: pt(tx + x, y)) } else { trace.addLine(to: pt(tx + x, y)) }
        }
        s.line(tx, ty, tx + tw, ty, stroke: hex("#DDDDDD"), lw: 1)
        s.shape(trace, stroke: hex("#C97488"), lw: 2)
        s.label(period == 6 ? "every 5–20 min" : "every 2–3 min", period == 6 ? "每 5–20 分钟" : "每 2–3 分钟", tx + tw, 236, size: 8, color: Anat.text, anchor: .end)
        if p[v: "hosp"] > 0.5 {
            s.rect(244, 246, 110, 48, r: 9, fill: hex("#FFF1F1"), stroke: Anat.red, lw: 1.4)
            s.label("Go in: 5-1-1", "去医院：5-1-1", 299, 262, size: 10, color: Anat.red, anchor: .middle, bold: true)
            s.label("every 5 min · 1 min long", "每 5 分钟 · 每次 1 分钟", 299, 276, size: 8, color: Anat.red, anchor: .middle)
            s.label("for 1 hour", "持续 1 小时", 299, 288, size: 8, color: Anat.red, anchor: .middle)
        }
    }
}

private func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }
