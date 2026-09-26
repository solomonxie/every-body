import SwiftUI

extension Illustrations {
    /// chance a stone passes on its own, by size in mm (typical clinical figures)
    static func passChance(_ mm: Double) -> Double { mm <= 4 ? 0.9 : mm <= 6 ? 0.6 : mm <= 8 ? 0.3 : 0.1 }

    /// left ureter (picture right): renal pelvis → pelvic brim over the iliac artery → bladder wall
    static let ureterPath = [CGPoint(x: 128, y: 100), CGPoint(x: 126, y: 130), CGPoint(x: 124, y: 162), CGPoint(x: 122, y: 196),
                             CGPoint(x: 128, y: 220), CGPoint(x: 124, y: 240), CGPoint(x: 117, y: 250)]

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
            .watch("Kidneys sit high at the back, under the lowest ribs. Minerals in urine can crystallise into a stone there.",
                   "肾脏位于后腰高处、最下面肋骨的下方。尿液中的矿物质可在肾内结晶成结石。", set: ["mm": 3, "moving": 0, "scene": 0]),
            .watch("When it slips into the ureter — a tube 3–4 mm wide — it causes waves of severe pain from the loin to the groin.",
                   "结石滑入输尿管（仅 3–4 毫米宽）时，会引起从腰部放射到腹股沟的阵发性剧痛。", set: ["moving": 1]),
            .tryIt("Drag the size. The ureter has 3 narrow points; small stones pass, big ones get stuck higher up.",
                   "试一试：拖动大小。输尿管有 3 处狭窄；小结石能排出，大的会卡在更高处。",
                   TryStep(mode: .scrub([Scrub(param: "mm", label: "Size 大小", min: 2, max: 12, unit: "mm", digits: 0)]), success: { $0[v: "mm"] >= 8 },
                           ok: Bilingual("Over ~6 mm often needs shock-wave or laser treatment.", "超过约 6 毫米常需碎石或激光治疗。"), demo: ["mm": 9])),
            .watch("Prevention: 2.5–3 L of water a day (pale urine), less salt. Pain with fever or no urine → hospital now.",
                   "预防：每天饮水 2.5–3 升（尿色淡），少盐。疼痛伴发热或无尿 → 立即就医。", set: ["scene": 1]),
        ],
        draw: { s, p, t in
            let mm = p[v: "mm"], chance = passChance(mm), moving = p[v: "moving"] > 0.5
            let ureter = ureterPath
            func along(_ u: Double) -> CGPoint {
                let f = u * Double(ureter.count - 1), i = min(ureter.count - 2, Int(f)), k = f - Double(i)
                return CGPoint(x: ureter[i].x + (ureter[i + 1].x - ureter[i].x) * k, y: ureter[i].y + (ureter[i + 1].y - ureter[i].y) * k)
            }
            let narrowings: [(Double, String, String)] = [(0.02, "kidney exit", "肾盂出口"), (0.5, "over the iliac artery", "跨髂血管处"), (0.97, "bladder wall", "膀胱壁内")]
            let stuck = mm > 8 ? 0.02 : mm > 6 ? 0.5 : mm > 4 ? 0.97 : 1.2
            let travel = moving ? min(stuck, (t * 0.12).truncatingRemainder(dividingBy: 1.4)) : 0
            let stone = travel <= 0 ? CGPoint(x: 140, y: 92) : along(min(1, travel))
            let blocked = moving && travel >= stuck - 0.01 && stuck <= 1
            let passed = travel > 1
            let bone = hex("#E9E2CF"), edge = hex("#B8A58A"), kidney = hex("#9E3A4A"), urine = hex("#E0C35A"), red = hex("#D8434B")

            // torso from the front: the person's left side is on the picture's right
            s.path("M 36 0 C 40 60, 44 110, 42 140 C 38 180, 22 210, 24 240 C 26 270, 34 290, 36 300 L 100 300 C 104 290, 108 286, 110 284 "
                   + "C 112 286, 116 290, 120 300 L 184 300 C 186 290, 194 270, 196 240 C 198 210, 182 180, 178 140 C 176 110, 180 60, 184 0 Z",
                   fill: hex("#F7E6DA"), stroke: hex("#DDBFA8"), lw: 2)
            for k in 0..<3 {
                let y = 30 + Double(k) * 22
                s.path("M 106 \(y) C 80 \(y + 10), 56 \(y + 24), 44 \(y + 44) M 114 \(y) C 140 \(y + 10), 164 \(y + 24), 176 \(y + 44)", stroke: hex("#E6DCCB"), lw: 5, cap: .round)
            }
            for k in 0..<9 { s.rect(103, 2 + Double(k) * 22, 14, 18, r: 4, fill: hex("#EFE9DA"), stroke: hex("#DDD3BE")) }
            s.path("M 104 202 C 80 170, 50 162, 40 190 C 40 214, 60 230, 78 246 L 102 268 M 116 202 C 140 170, 170 162, 180 190 C 180 214, 160 230, 142 246 L 118 268",
                   stroke: bone, lw: 7, cap: .round)
            s.ellipse(110, 270, 7, 8, fill: bone, stroke: edge)
            // aorta splitting into the iliac arteries
            s.path("M 100 0 L 100 176 C 94 196, 80 214, 70 240 M 100 176 C 110 190, 130 210, 150 240", stroke: hex("#C8323C"), lw: 5, opacity: 0.7)
            s.circle(110, 150, 2.5, fill: hex("#B89580"))
            if moving {
                s.ellipse(160, 110, 26, 36, fill: red, opacity: 0.14 + 0.08 * sin(t * 3))
                s.path("M 162 150 C 166 190, 160 230, 146 262", stroke: red, lw: 2, opacity: 0.6, dash: [4, 3])
                if p[v: "scene"] < 0.5 { s.label("pain: loin → groin", "疼痛：腰 → 腹股沟", 287, 280, size: 9, color: red, anchor: .middle) }
            }
            // kidneys: bean shape, hilum toward the spine; the left sits a little higher
            func kidneyShape(_ cx: Double, _ cy: Double, _ side: Double) {
                func q(_ x: Double, _ y: Double) -> String { "\(cx + side * x) \(cy + y)" }
                s.path("M \(q(0, -27)) C \(q(-20, -27)) \(q(-18, 27)) \(q(0, 27)) C \(q(10, 27)) \(q(16, 20)) \(q(12, 8)) C \(q(8, 4)) \(q(8, -4)) \(q(12, -8)) C \(q(16, -20)) \(q(10, -27)) \(q(0, -27)) Z",
                       fill: kidney, stroke: hex("#7A2A38"), lw: 1.5)
                s.path("M \(q(-5, -16)) C \(q(2, -8)) \(q(6, -5)) \(q(14, -3)) L \(q(15, 4)) C \(q(6, 6)) \(q(2, 8)) \(q(-5, 16)) C \(q(-1, 6)) \(q(-1, -6)) \(q(-5, -16)) Z", fill: urine, stroke: hex("#C9A94A"), lw: 0.8)
            }
            kidneyShape(80, 104, -1)
            kidneyShape(140, 94, 1)
            s.path("M 90 108 C 94 140, 96 170, 98 196 C 94 214, 96 232, 103 250", stroke: urine, lw: 3)
            var path = Path()
            path.move(to: ureter[0])
            for q in ureter.dropFirst() { path.addLine(to: q) }
            s.shape(path, stroke: blocked ? red : urine, lw: 3.5)
            if blocked {
                // urine backs up and the kidney swells above the stone
                s.shape(Path(ellipseIn: CGRect(x: 118, y: 62, width: 44, height: 64)), stroke: red, lw: 1.5, dash: [3, 3])
            }
            s.ellipse(110, 250, 22, 14, fill: urine, stroke: hex("#C9A94A"))
            for (i, n) in narrowings.enumerated() {
                let q = along(n.0)
                s.circle(q.x, q.y, 5, stroke: hex("#555555"), lw: 1)
                s.text("\(i + 1)", q.x + 7, q.y + 3, size: 8, color: hex("#555555"), bold: true)
            }
            if !passed { s.circle(stone.x, stone.y, 1.6 + mm * 0.32, fill: hex("#8A7A5A"), stroke: hex("#4A3A2A")) }
            s.label("kidney", "肾", 36, 84, size: 9, color: hex("#8A3B45"), anchor: .end)
            s.label("bladder", "膀胱", 80, 262, size: 9, color: hex("#8A6A1B"), anchor: .end)
            s.label("ureter", "输尿管", 26, 172, size: 9, color: hex("#8A6A1B"))
            s.path("M 56 170 L 96 170", stroke: hex("#8A6A1B"), lw: 0.8)

            // right panel
            let status = chance >= 0.5 ? hex("#2E9E5B") : red
            s.rect(222, 8, 130, 72, r: 8, fill: .white, stroke: status, lw: 2)
            s.label("Stone \(Int(mm.rounded())) mm", "结石 \(Int(mm.rounded())) 毫米", 287, 26, size: 11, anchor: .middle)
            s.text("\(Int((chance * 100).rounded()))%", 287, 52, size: 20, color: status, anchor: .middle, bold: true)
            s.label("pass on their own", "可自行排出", 287, 70, size: 9, anchor: .middle)
            if p[v: "scene"] > 0.5 {
                // prevention: water and less salt
                for i in 0..<3 {
                    let x = 236 + Double(i) * 40
                    s.path("M \(x) 104 L \(x + 26) 104 L \(x + 23) 150 L \(x + 3) 150 Z", fill: hex("#E3F1FB"), stroke: hex("#3F95D6"), lw: 1.5)
                    s.path("M \(x + 2) 116 L \(x + 24) 116 L \(x + 23) 150 L \(x + 3) 150 Z", fill: hex("#8FC4EA"))
                }
                s.label("2.5–3 L water a day", "每天饮水 2.5–3 升", 287, 168, size: 10, color: hex("#3F95D6"), anchor: .middle, bold: true)
                s.label("urine pale yellow", "尿色淡黄即足够", 287, 184, size: 9, anchor: .middle)
                s.label("less salt, less cola", "少盐，少喝可乐", 287, 200, size: 9, anchor: .middle)
                s.rect(222, 216, 130, 44, r: 8, fill: hex("#FFF3F3"), stroke: red, lw: 1.5)
                s.label("Pain + fever,", "疼痛＋发热", 287, 234, size: 10, color: red, anchor: .middle, bold: true)
                s.label("or no urine → A&E", "或无尿 → 急诊", 287, 250, size: 10, color: red, anchor: .middle, bold: true)
            } else {
                // inside the ureter, to scale: stone vs a 3–4 mm tube
                let box = CGRect(x: 222, y: 90, width: 130, height: 90), cy = box.midY + 6, px = 5.0
                s.rect(box.minX, box.minY, box.width, box.height, r: 8, fill: .white, stroke: hex("#DDDDDD"))
                s.label("inside the ureter, to scale", "输尿管内部（按比例）", box.midX, box.minY + 14, size: 8, anchor: .middle)
                let sr = min(mm, 12) * px / 2, lumen = 3.5 * px / 2
                let bulge = max(lumen, sr + 1)
                s.path("M \(box.minX + 8) \(cy - lumen - 3) L \(box.midX - 26) \(cy - lumen - 3) C \(box.midX - 12) \(cy - bulge - 3), \(box.midX + 12) \(cy - bulge - 3), \(box.midX + 26) \(cy - lumen - 3) L \(box.maxX - 8) \(cy - lumen - 3) "
                       + "M \(box.minX + 8) \(cy + lumen + 3) L \(box.midX - 26) \(cy + lumen + 3) C \(box.midX - 12) \(cy + bulge + 3), \(box.midX + 12) \(cy + bulge + 3), \(box.midX + 26) \(cy + lumen + 3) L \(box.maxX - 8) \(cy + lumen + 3)",
                       stroke: sr > lumen + 2 ? red : urine, lw: 4)
                s.circle(box.midX, cy, sr, fill: hex("#8A7A5A"), stroke: hex("#4A3A2A"))
                s.line(box.minX + 12, box.maxY - 8, box.minX + 12 + 5 * px, box.maxY - 8, stroke: hex("#555555"), lw: 1.5)
                s.text("5 mm", box.minX + 16 + 5 * px, box.maxY - 5, size: 8)
                // the three narrowings
                for (i, n) in narrowings.enumerated() {
                    let y = 198 + Double(i) * 16
                    let here = blocked && abs(stuck - n.0) < 0.01
                    s.circle(228, y - 3, 6, fill: here ? red : .white, stroke: hex("#555555"))
                    s.text("\(i + 1)", 228, y, size: 8, color: here ? .white : hex("#555555"), anchor: .middle, bold: true)
                    s.label(n.1, n.2, 238, y, size: 9, color: here ? red : hex("#555555"), bold: here)
                }
                if blocked { s.label("stuck — renal colic", "卡住——肾绞痛", 287, 262, size: 10, color: red, anchor: .middle, bold: true) }
                if passed { s.label("passed into the bladder", "已排入膀胱", 287, 262, size: 10, color: hex("#2E9E5B"), anchor: .middle, bold: true) }
            }
        },
        sources: ["AUA / EAU urolithiasis guidelines (spontaneous passage by size)"]
    )

    /// typical size by gestational week (crown–rump before 20 w, crown–heel after)
    static func fetalSize(_ week: Double) -> (cm: Double, g: Double, like: Bilingual) {
        let table: [(Double, Double, Double, Bilingual)] = [
            (6, 0.6, 0.1, Bilingual("lentil", "扁豆")), (8, 1.6, 1, Bilingual("raspberry", "树莓")), (12, 5.4, 14, Bilingual("lime", "青柠")),
            (16, 11.6, 100, Bilingual("avocado", "牛油果")), (20, 25.6, 300, Bilingual("banana", "香蕉")), (24, 30, 600, Bilingual("ear of corn", "玉米")),
            (28, 37.6, 1000, Bilingual("aubergine", "茄子")), (32, 42.4, 1700, Bilingual("squash", "南瓜")), (36, 47.4, 2600, Bilingual("papaya", "木瓜")),
            (40, 51.2, 3400, Bilingual("watermelon", "西瓜")),
        ]
        let i = max(0, (table.firstIndex { $0.0 >= week } ?? table.count) - 1)
        let a = table[i], b = table[min(table.count - 1, i + 1)]
        let u = b.0 == a.0 ? 0 : ((week - a.0) / (b.0 - a.0)).clamped(0, 1)
        return (a.1 + (b.1 - a.1) * u, a.2 + (b.2 - a.2) * u, u < 0.5 ? a.3 : b.3)
    }

    /// Curled fetus, head up in its own frame; `rotate` 180 = head down. `length` is crown to rump.
    static func drawFetus(_ s: inout Sketch, at c: CGPoint, length L: Double, headFrac: Double, rotate: Double, kick: Double = 0) {
        let skin = hex("#F2C9A5"), line = hex("#C9A58A"), limb = hex("#EBB98F")
        let hr = L * headFrac / 2, top = -L / 2
        s.group(translate: c, rotate: rotate, about: .zero) { g in
            g.path("M \(-hr * 0.5) \(top + hr * 1.6) C \(-L * 0.36) \(top + L * 0.42), \(-L * 0.32) \(L * 0.42), \(L * 0.02) \(L * 0.5) "
                   + "C \(L * 0.3) \(L * 0.46), \(L * 0.3) \(top + L * 0.5), \(hr * 0.7) \(top + hr * 1.8) Z", fill: skin, stroke: line, lw: 1)
            g.line(L * 0.02, L * 0.36, L * 0.28, L * 0.14, stroke: limb, lw: max(1.5, L * 0.1), cap: .round)
            g.line(L * 0.28, L * 0.14, L * 0.16 + kick, L * 0.36, stroke: limb, lw: max(1.2, L * 0.08), cap: .round)
            g.line(L * 0.02, top + hr * 2.3, hr * 1.0, top + hr * 1.5, stroke: limb, lw: max(1.2, L * 0.07), cap: .round)
            g.circle(L * 0.04, top + hr, hr, fill: skin, stroke: line, lw: 1)
            g.circle(L * 0.04 + hr * 0.5, top + hr * 0.85, max(0.5, hr * 0.1), fill: hex("#6B5344"))
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
            .watch("Week 40: full term — about 50 cm and 3.4 kg, head down, the womb reaching the ribs.", "第 40 周：足月——约 50 厘米、3.4 公斤，头朝下，子宫顶到肋下。", set: ["week": 40]),
            .tryIt("Drag through the weeks and watch the belly grow.", "试一试：拖动孕周，看肚子长大。",
                   TryStep(mode: .scrub([Scrub(param: "week", label: "Week 孕周", min: 6, max: 40, digits: 0)]), success: { _ in true },
                           ok: Bilingual("From week 20, fundal height (cm above the pubic bone) ≈ weeks — midwives measure it with a tape.",
                                         "约 20 周后，宫高（耻骨上厘米数）≈ 孕周数——产检时用软尺测量。"))),
        ],
        draw: { s, p, t in
            let week = p[v: "week"]
            let size = fetalSize(week)
            let purple = hex("#6C4F9E"), line = hex("#C9A58A"), skin = hex("#F7E6DA"), label = hex("#8A6A5A")
            // mother side-on, facing right; 2.85 px per cm: pubic bone y 236, navel y 176, breastbone tip y 132
            let pubis = 236.0, pxPerCm = 2.85
            let marks: [(Double, Double)] = [(6, 238), (12, 228), (20, 176), (28, 154), (36, 132), (40, 140)]
            let i = max(0, (marks.firstIndex { $0.0 >= week } ?? marks.count) - 1)
            let (w0, y0) = marks[i], (w1, y1) = marks[min(marks.count - 1, i + 1)]
            let fundus = w1 == w0 ? y0 : y0 + (y1 - y0) * ((week - w0) / (w1 - w0)).clamped(0, 1)
            let grow = ((236 - fundus) / 104).clamped(0, 1)
            // womb: pear from the cervix up to the fundus
            let cervix = CGPoint(x: 124, y: 240)
            let height = max(26, cervix.y - fundus + 6)
            let width = 14 + height * 0.66
            let cx = cervix.x + 8 + grow * 18
            let top = cervix.y - height
            // belly front = womb front plus the abdominal wall, never inside the resting profile
            var front: [CGPoint] = []
            for k in 0...24 {
                let u = Double(k) / 24, a = (1 - u) * (1 - u) * (1 - u), b = 3 * u * (1 - u) * (1 - u), c = 3 * u * u * (1 - u), d = u * u * u
                let x = a * cx + (b + c) * (cx + width / 2) + d * (cervix.x + 5)
                let y = a * top + b * (top + 4) + c * (cervix.y - height * 0.2) + d * cervix.y
                guard y > 124, y < 232 else { continue }
                let rest = y < 150 ? 150 - (y - 134) * 0.05 : 148
                front.append(CGPoint(x: max(rest, x + 5 + 3 * grow * sin(.pi * u)), y: y))
            }
            let bx = front.map(\.x).max() ?? 150
            let navelX = front.min { abs($0.y - 176) < abs($1.y - 176) }?.x ?? 148
            let belly = front.map { "L \($0.x) \($0.y) " }.joined()
            s.path("M 132 58 C 134 64, 140 70, 150 78 C 164 88, 166 110, 152 120 C 148 124, 148 128, 150 132 "
                   + belly + "L 148 236 "
                   + "C 146 242, 142 246, 138 248 C 140 270, 142 290, 142 300 L 92 300 C 90 280, 86 256, 84 232 C 80 210, 90 186, 94 160 "
                   + "C 96 130, 88 100, 96 78 C 100 70, 106 62, 110 56 Z", fill: skin, stroke: line, lw: 2)
            s.rect(112, 44, 20, 20, fill: skin)
            s.circle(122, 30, 21, fill: skin, stroke: line, lw: 2)
            s.path("M 141 24 L 147 34 L 141 36 C 142 40, 141 44, 136 48", fill: skin, stroke: line, lw: 1.5)
            s.circle(134, 26, 1.8, fill: hex("#4A4550"))
            s.path("M 102 32 C 96 10, 130 0, 142 18 C 128 14, 114 18, 106 40 Z", fill: hex("#6B5344"))
            s.circle(98, 30, 7, fill: hex("#6B5344"))
            s.path("M 100 70 C 94 110, 100 150, 108 190 C 112 210, 106 226, 104 240", stroke: hex("#EADFCB"), lw: 5, cap: .round)
            s.ellipse(144, pubis, 5, 9, fill: hex("#E9E2CF"), stroke: hex("#B8A58A"))
            s.path("M \(cervix.x - 5) \(cervix.y) C \(cx - width / 2) \(cervix.y - height * 0.2), \(cx - width / 2) \(top + 4), \(cx) \(top) "
                   + "C \(cx + width / 2) \(top + 4), \(cx + width / 2) \(cervix.y - height * 0.2), \(cervix.x + 5) \(cervix.y) Z",
                   fill: hex("#F2B8C0"), stroke: hex("#C9788A"), lw: 2)
            if week >= 10 { s.ellipse(cx - width * 0.3, top + height * 0.3, max(3, width * 0.12), height * 0.2, fill: hex("#B34A62"), opacity: 0.85) }
            // fetus: head shrinks from ½ to ¼ of body length; turns head-down after ~32 w
            let length = min((height - 10) * 0.8, max(3, size.cm * pxPerCm * 0.62))
            let headFrac = week < 20 ? 0.62 - (week - 8) / 12 * 0.14 : 0.48 - (week - 20) / 20 * 0.08
            let turn = ((week - 30) / 4).clamped(0, 1) * 180
            let kick = week >= 20 ? pow(max(0, sin(t * 3)), 8) * 3 : 0
            let centre = CGPoint(x: cx + 2, y: cervix.y - height * 0.5)
            if week >= 10 { s.path("M \(centre.x) \(centre.y + length * 0.1) Q \(cx - 10) \(top + height * 0.5) \(cx - width * 0.3) \(top + height * 0.3)", stroke: hex("#C9788A"), lw: 1.2) }
            drawFetus(&s, at: centre, length: length, headFrac: headFrac, rotate: -turn, kick: kick)
            s.circle(navelX - 2, 176, 2, fill: label)
            s.circle(150, 132, 2, fill: label)
            // tape measure from the pubic bone to the top of the womb
            if week >= 16 {
                let x = bx + 10
                s.line(x, pubis, x, fundus, stroke: hex("#E3B53B"), lw: 5)
                var cm = 0.0
                while pubis - cm * pxPerCm >= fundus { s.line(x - 2.5, pubis - cm * pxPerCm, x + 2.5, pubis - cm * pxPerCm, stroke: hex("#8A6A1B"), lw: 1); cm += 5 }
            }
            // near arm, hanging just behind the belly
            s.line(112, 80, 102, 148, stroke: line, lw: 13, cap: .round)
            s.line(102, 148, 104, 204, stroke: line, lw: 11, cap: .round)
            s.line(112, 80, 102, 148, stroke: skin, lw: 11, cap: .round)
            s.line(102, 148, 104, 204, stroke: skin, lw: 9, cap: .round)
            s.label("pubic bone", "耻骨", 150, 256, size: 8, color: label)
            s.label("womb", "子宫", cx, top - 5, size: 8, color: hex("#A0506A"), anchor: .middle)

            // right panel
            let px = 226.0
            s.label("Week \(Int(week.rounded()))", "第 \(Int(week.rounded())) 周", px, 22, size: 16, color: purple, bold: true)
            s.text(s.zh ? "约\(size.like.zh)大小" : "about a \(size.like.en)", px, 40, size: 10, color: purple)
            let barH = size.cm * 2
            s.line(px + 4, 54, px + 4, 54 + barH, stroke: purple, lw: 5, cap: .round)
            s.text(String(format: "%.1f cm", size.cm), px + 14, 64, size: 11, color: purple)
            s.text(size.g < 10 ? String(format: "%.1f g", size.g) : size.g < 1000 ? "\(Int(size.g.rounded())) g" : String(format: "%.1f kg", size.g / 1000), px + 14, 80, size: 11, color: purple)
            let milestone: (String, String) = week < 10 ? ("heart beating", "心脏开始跳动") : week < 14 ? ("all organs formed", "器官基本形成")
                : week < 18 ? ("moves, too small to feel", "会动，但还感觉不到") : week < 24 ? ("kicks felt", "能感到胎动")
                : week < 30 ? ("survives with NICU care", "早产经监护可存活") : week < 34 ? ("eyes open, turns head-down", "睁眼，转为头朝下")
                : week < 37 ? ("lungs maturing", "肺部逐渐成熟") : ("full term", "足月，随时可分娩")
            s.label(milestone.0, milestone.1, px + 14, 100, size: 9)
            if week >= 16 {
                let fh = (pubis - fundus) / pxPerCm
                s.label("fundal height", "宫高", px, 190, size: 9, color: hex("#8A6A1B"))
                s.label("≈ \(Int(fh.rounded())) cm", "≈ \(Int(fh.rounded())) 厘米", px, 206, size: 13, color: hex("#8A6A1B"), bold: true)
            }
            // trimester bar
            let bx0 = px, bw = 124.0
            for (a, b, col) in [(0.0, 13.0, hex("#E8E2F6")), (13, 27, hex("#D3C6EC")), (27, 40, hex("#B7A3DD"))] {
                s.rect(bx0 + a / 40 * bw, 262, (b - a) / 40 * bw, 10, fill: col)
            }
            s.label("1st", "孕早期", bx0 + 6.5 / 40 * bw, 286, size: 8, color: purple, anchor: .middle)
            s.label("2nd", "孕中期", bx0 + 20 / 40 * bw, 286, size: 8, color: purple, anchor: .middle)
            s.label("3rd", "孕晚期", bx0 + 33.5 / 40 * bw, 286, size: 8, color: purple, anchor: .middle)
            s.path("M \(bx0 + week / 40 * bw) 260 l -5 -8 l 10 0 Z", fill: purple)
        },
        sources: ["Typical fetal length/weight by gestational age (ACOG, Hadlock)", "Fundal height ≈ gestational weeks (cm) from 20 w"]
    )

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
        draw: { s, p, t in
            // mother side-on, front to the right: womb above the pelvis, birth canal curving down and forward
            let cm = p[v: "cm"], descent = p[v: "descent"], placenta = p[v: "placenta"] > 0.5
            let period = cm < 6 ? 6.0 : 2.5
            let sq = pow(max(0, sin(t / period * 2 * .pi)), 3)
            let label = hex("#8A3B45"), bone = hex("#E9E2CF"), edge = hex("#B8A58A"), purple = hex("#6C4F9E")
            let born = descent > 0.95
            s.path("M 30 0 C 26 70, 34 150, 48 196 C 36 226, 44 262, 80 282 C 100 292, 120 298, 140 300 L 172 300 C 176 284, 180 272, 186 262 "
                   + "C 206 240, 236 190, 236 120 C 236 60, 222 20, 214 0 Z", fill: hex("#F7E6DA"), stroke: hex("#DDBFA8"), lw: 2)
            s.path("M 56 110 C 48 160, 62 216, 98 254 C 106 262, 112 266, 118 268", stroke: bone, lw: 13, cap: .round)
            s.path("M 56 110 C 48 160, 62 216, 98 254 C 106 262, 112 266, 118 268", stroke: edge, lw: 1)
            s.ellipse(186, 236, 7, 15, fill: bone, stroke: edge)
            s.line(64, 226, 196, 226, stroke: hex("#999999"), lw: 1, dash: [3, 3])
            // birth canal
            s.path("M 116 218 C 116 250, 132 278, 150 300 M 142 218 C 146 246, 160 266, 176 292", stroke: hex("#D9A0AE"), lw: 3)
            // womb contracting; the cervix thins, then opens
            let wall = 7 + sq * 7 + (placenta ? 6 : 0)
            let shrink = placenta ? 0.72 : 1
            let gap = cm / 10 * 30
            let lip = 14 * (1 - min(cm, 4) / 4) + 4
            s.group(translate: CGPoint(x: 129 * (1 - shrink), y: 216 * (1 - shrink)), scale: shrink) { g in
                g.path("M \(129 - gap / 2 - 10) 214 C 64 200, 46 110, 78 52 C 100 14, 172 8, 198 42 C 230 92, 216 196, \(129 + gap / 2 + 10) 214",
                       fill: hex("#F4C6CF"), stroke: hex("#C9788A"), lw: wall)
                g.line(129 - gap / 2 - 12, 212, 129 - gap / 2 - 2, 212 + lip, stroke: label, lw: 6, cap: .round)
                g.line(129 + gap / 2 + 12, 212, 129 + gap / 2 + 2, 212 + lip, stroke: label, lw: 6, cap: .round)
                if !placenta { g.path("M 70 70 C 64 100, 68 130, 76 144 C 90 130, 96 96, 88 66 Z", fill: hex("#A83248")) }
            }
            // baby: head leads down the canal, chin tucked, then extends under the pubic bone
            let u = descent
            let a = (1 - u) * (1 - u), b = 2 * u * (1 - u), c = u * u
            let head = CGPoint(x: a * 128 + b * 128 + c * 170, y: a * 190 + b * 266 + c * 306)
            if !placenta && !born {
                let rot = 180 - 55 * u, L = 124.0, hf = 0.4
                let hr = L * hf / 2, local = CGPoint(x: L * 0.04, y: -L / 2 + hr), r = rot * .pi / 180
                let centre = CGPoint(x: head.x - (local.x * cos(r) - local.y * sin(r)), y: head.y - (local.x * sin(r) + local.y * cos(r)))
                s.path("M 80 104 C 100 90, \(centre.x - 10) \(centre.y - 20), \(centre.x) \(centre.y)", stroke: hex("#C9788A"), lw: 2)
                drawFetus(&s, at: centre, length: L, headFrac: hf, rotate: rot)
            }
            if placenta { s.path("M 144 262 C 138 276, 146 292, 158 296 C 172 290, 170 270, 158 260 Z", fill: hex("#A83248")) }
            s.label("sacrum", "骶骨", 12, 170, size: 8, color: hex("#8F7E63"))
            s.label("pubic bone", "耻骨", 196, 262, size: 8, color: hex("#8F7E63"))
            s.label("station 0", "0 位", 62, 222, size: 7, anchor: .end)
            if !placenta && !born { s.label("placenta", "胎盘", 44, 60, size: 8, color: label) }
            s.label("cervix", "宫颈", 150, 210, size: 8, color: label)
            if placenta { s.label("placenta out", "胎盘娩出", 176, 294, size: 8, color: label) }
            if sq > 0.3 && !placenta { s.label("contraction", "宫缩", 150, 60, size: 10, color: hex("#C9788A"), anchor: .middle, bold: true) }

            // right panel
            let stage = placenta ? s.t("Stage 3 · placenta", "第三产程 · 胎盘") : descent > 0.05 ? s.t("Stage 2 · pushing & birth", "第二产程 · 用力娩出")
                : cm < 6 ? s.t("Stage 1 · early labour", "第一产程 · 潜伏期") : s.t("Stage 1 · active labour", "第一产程 · 活跃期")
            s.rect(8, 6, 200, 24, r: 8, fill: .white, stroke: purple, lw: 2)
            s.text(stage, 18, 22, size: 10, color: purple, bold: true)
            let box = CGRect(x: 242, y: 6, width: 112, height: 150)
            s.rect(box.minX, box.minY, box.width, box.height, r: 10, fill: .white, stroke: hex("#DDDDDD"))
            if born {
                s.label("skin to skin", "肌肤接触", box.midX, box.minY + 16, size: 9, color: hex("#2E9E5B"), anchor: .middle, bold: true)
                let bc = CGPoint(x: box.midX, y: 86)
                s.ellipse(bc.x + 6, bc.y, 30, 17, fill: hex("#F2C9A5"), stroke: hex("#C9A58A"))
                s.line(bc.x + 24, bc.y + 8, bc.x + 44, bc.y + 16, stroke: hex("#EBB98F"), lw: 8, cap: .round)
                s.line(bc.x - 6, bc.y + 10, bc.x - 10, bc.y + 26, stroke: hex("#EBB98F"), lw: 6, cap: .round)
                s.circle(bc.x - 30, bc.y - 4, 17, fill: hex("#F2C9A5"), stroke: hex("#C9A58A"))
                s.path("M \(bc.x - 38) \(bc.y - 6) q 3 -2 6 0", stroke: hex("#6B5344"), lw: 1.2)
                s.path("M \(box.minX + 10) 118 C \(box.midX) 108, \(box.midX) 108, \(box.maxX - 10) 118", stroke: hex("#DDBFA8"), lw: 3)
                s.label(placenta ? "≤ 30 min later" : "born!", placenta ? "30 分钟内" : "出生了！", box.midX, box.maxY - 12, size: 10, color: hex("#2E9E5B"), anchor: .middle, bold: true)
            } else {
                // the cervix seen from below, 2.6 px per mm
                s.label("cervix from below", "宫颈（仰视）", box.midX, box.minY + 14, size: 8, anchor: .middle)
                let c = CGPoint(x: box.midX, y: 76), open = cm * 2.6
                s.shape(Path(ellipseIn: CGRect(x: c.x - 30, y: c.y - 30, width: 60, height: 60)), stroke: hex("#BBBBBB"), lw: 1, dash: [3, 3])
                s.circle(c.x, c.y, open + 4 + lip * 0.8, fill: hex("#E7A5B4"), stroke: hex("#C9788A"))
                s.circle(c.x, c.y, max(1, open), fill: cm > 7 ? hex("#E8C4A8") : hex("#8A3B45"))
                s.label("\(Int(cm.rounded())) cm", "\(Int(cm.rounded())) 厘米", box.midX, 132, size: 12, color: label, anchor: .middle, bold: true)
                let like = dilationLike[min(10, max(0, Int(cm.rounded())))]
                s.label("≈ " + like.en, "≈ " + like.zh, box.midX, 148, size: 9, anchor: .middle)
            }
            // contraction trace
            let tx = 242.0, ty = 214.0, tw = 112.0
            s.label("contractions", "宫缩", tx, 172, size: 9, color: hex("#C9788A"))
            var trace = Path()
            for i in 0...56 {
                let x = Double(i) / 56 * tw, time = x / tw * 12
                let y = ty - pow(max(0, sin(time / period * 2 * .pi)), 3) * 30
                if i == 0 { trace.move(to: CGPoint(x: tx + x, y: y)) } else { trace.addLine(to: CGPoint(x: tx + x, y: y)) }
            }
            s.line(tx, ty, tx + tw, ty, stroke: hex("#DDDDDD"), lw: 1)
            s.shape(trace, stroke: hex("#C9788A"), lw: 2)
            s.label(period == 6 ? "every 5–20 min" : "every 2–3 min", period == 6 ? "每 5–20 分钟" : "每 2–3 分钟", tx + tw, 228, size: 8, anchor: .end)
            if p[v: "hosp"] > 0.5 {
                s.rect(242, 240, 112, 54, r: 8, fill: hex("#FFF3F3"), stroke: hex("#D8434B"), lw: 1.5)
                s.label("Go in: 5-1-1", "去医院：5-1-1", 298, 256, size: 10, color: hex("#D8434B"), anchor: .middle, bold: true)
                s.label("every 5 min · 1 min", "每 5 分钟 · 持续 1 分钟", 298, 270, size: 8, color: hex("#D8434B"), anchor: .middle)
                s.label("for 1 hour", "连续 1 小时", 298, 284, size: 8, color: hex("#D8434B"), anchor: .middle)
            }
        },
        sources: ["WHO intrapartum care 2018 (active phase from 5–6 cm)", "5-1-1 rule for first labours (ACOG patient guidance)"]
    )
}
