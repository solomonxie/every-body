import SwiftUI

extension Illustrations {
    /// chance a stone passes on its own, by size in mm (typical clinical figures)
    static func passChance(_ mm: Double) -> Double { mm <= 4 ? 0.9 : mm <= 6 ? 0.6 : mm <= 8 ? 0.3 : 0.1 }

    static let kidneyStones = Scenario(
        id: "kidney-stones", group: .illness, title: Bilingual("Kidney stones", "肾结石"),
        params: ["mm": 3, "moving": 0],
        steps: [
            .watch("Minerals in urine can crystallise into a stone inside the kidney.", "尿液中的矿物质可在肾内结晶成结石。", set: ["mm": 3, "moving": 0]),
            .watch("When it moves into the narrow ureter it can cause severe, wave-like pain.", "结石进入狭窄的输尿管时会引起剧烈的阵发性绞痛。", set: ["moving": 1]),
            .tryIt("Drag the size. Small stones usually pass; big ones get stuck.", "试一试：拖动大小。小结石多能排出，大的易卡住。",
                   TryStep(mode: .scrub([Scrub(param: "mm", label: "Size 大小", min: 2, max: 12, unit: "mm", digits: 0)]), success: { $0[v: "mm"] >= 8 },
                           ok: Bilingual("Over ~6 mm often needs shock-wave or laser treatment.", "超过约 6 毫米常需碎石或激光治疗。"), demo: ["mm": 9])),
            .watch("Prevention: 2.5–3 L of water a day, less salt. Fever with the pain → hospital now.", "预防：每天饮水 2.5–3 升，少盐。疼痛伴发热 → 立即就医。"),
        ],
        draw: { s, p, t in
            let mm = p[v: "mm"], chance = passChance(mm)
            // ureter path: renal pelvis → junction (narrow) → crosses the iliac vessels (narrow) → enters the bladder (narrowest)
            let ureter = [CGPoint(x: 128, y: 104), CGPoint(x: 134, y: 150), CGPoint(x: 150, y: 196), CGPoint(x: 166, y: 236), CGPoint(x: 178, y: 256)]
            func along(_ u: Double) -> CGPoint {
                let f = u * Double(ureter.count - 1), i = min(ureter.count - 2, Int(f)), k = f - Double(i)
                return CGPoint(x: ureter[i].x + (ureter[i + 1].x - ureter[i].x) * k, y: ureter[i].y + (ureter[i + 1].y - ureter[i].y) * k)
            }
            // where it sticks: the first narrowing too tight for its size
            let narrowings: [(Double, String)] = [(0.05, "junction 肾盂输尿管连接处"), (0.47, "iliac crossing 跨髂血管处"), (0.93, "bladder entry 膀胱入口")]
            let stuck = mm > 8 ? 0.05 : mm > 6 ? 0.47 : mm > 4 ? 0.93 : 1.1
            let travel = p[v: "moving"] > 0.5 ? min(stuck, (t * 0.12).truncatingRemainder(dividingBy: 1.3)) : 0
            let stone = travel <= 0 ? CGPoint(x: 112, y: 70) : along(min(1, travel))
            let blocked = p[v: "moving"] > 0.5 && travel >= stuck - 0.01 && stuck <= 1
            // kidney in section: cortex, pyramids, calyces draining into the pelvis
            s.path("M 90 20 C 40 20, 30 120, 90 128 C 112 130, 124 110, 118 96 C 108 84, 108 64, 118 52 C 124 36, 112 20, 90 20 Z", fill: hex("#9E3A4A"), stroke: hex("#7A2A38"), lw: 2)
            for (x, y) in [(66.0, 44.0), (56, 74), (62, 104)] { s.path("M \(x) \(y) L \(x + 26) \(y + 8) L \(x + 4) \(y + 16) Z", fill: hex("#7E2130")) }
            s.path("M 94 50 C 102 62, 106 70, 122 76 M 92 76 L 122 80 M 94 106 C 104 96, 108 88, 122 84", stroke: hex("#E8C98A"), lw: 5, cap: .round)
            s.path("M 118 72 C 132 76, 134 90, 128 104", fill: hex("#E8C98A"), stroke: hex("#D0B070"), lw: 1)
            var path = Path()
            path.move(to: ureter[0])
            for q in ureter.dropFirst() { path.addLine(to: q) }
            s.shape(path, stroke: blocked ? hex("#D8434B") : hex("#E0C35A"), lw: 6)
            s.path("M 110 200 C 140 190, 170 186, 210 192", stroke: hex("#C8323C"), lw: 7, cap: .round)            // iliac vessels
            s.path("M 160 240 C 150 294, 230 294, 226 240 C 222 222, 170 222, 160 240 Z", fill: hex("#E0C35A"), stroke: hex("#C9A94A"))
            for (u, name) in narrowings {
                let q = along(u)
                s.circle(q.x, q.y, 4, stroke: hex("#555555"), lw: 1)
                s.text(name, q.x + 10, q.y + 3, size: 7)
            }
            s.circle(stone.x, stone.y, 1.8 + mm * 0.55, fill: hex("#8A7A5A"), stroke: hex("#5A4A3A"))
            if blocked { s.text("⚡ stuck — colic 卡住 · 肾绞痛", 20, 176, size: 9, color: hex("#D8434B"), bold: true) }
            s.text("kidney 肾 · pelvis 肾盂", 20, 150, size: 8, color: hex("#8A3B45"))
            s.text("iliac artery 髂动脉", 212, 196, size: 7, color: hex("#C8323C"))
            s.text("bladder 膀胱", 234, 264, size: 8, color: hex("#8A6A1B"))
            let status = chance >= 0.5 ? hex("#2E9E5B") : hex("#D8434B")
            s.rect(220, 20, 132, 70, r: 8, fill: .white, stroke: status, lw: 2)
            s.text("Stone 结石 \(Int(mm.rounded())) mm", 286, 40, size: 11, anchor: .middle)
            s.text("\(Int((chance * 100).rounded()))%", 286, 66, size: 20, color: status, anchor: .middle, bold: true)
            s.text("pass on their own 自行排出", 286, 82, size: 9, anchor: .middle)
        },
        sources: ["AUA / EAU urolithiasis guidelines (spontaneous passage by size)"]
    )

    /// typical size by gestational week (crown–rump before 20 w, crown–heel after)
    static func fetalSize(_ week: Double) -> (cm: Double, g: Double, like: String) {
        let table: [(Double, Double, Double, String)] = [
            (6, 0.6, 0.1, "lentil 扁豆"), (8, 1.6, 1, "raspberry 树莓"), (12, 5.4, 14, "lime 青柠"), (16, 11.6, 100, "avocado 牛油果"),
            (20, 25.6, 300, "banana 香蕉"), (24, 30, 600, "corn 玉米"), (28, 37.6, 1000, "aubergine 茄子"), (32, 42.4, 1700, "squash 南瓜"),
            (36, 47.4, 2600, "papaya 木瓜"), (40, 51.2, 3400, "watermelon 西瓜"),
        ]
        let i = max(0, (table.firstIndex { $0.0 >= week } ?? table.count) - 1)
        let a = table[i], b = table[min(table.count - 1, i + 1)]
        let u = b.0 == a.0 ? 0 : ((week - a.0) / (b.0 - a.0)).clamped(0, 1)
        return (a.1 + (b.1 - a.1) * u, a.2 + (b.2 - a.2) * u, u < 0.5 ? a.3 : b.3)
    }

    static let fetalGrowth = Scenario(
        id: "fetal-growth", group: .pregnancy, title: Bilingual("Pregnancy week by week", "孕期胎儿发育"),
        params: ["week": 8],
        steps: [
            .watch("Week 8: the heart is beating; about the size of a raspberry.", "第 8 周：心脏已开始跳动，约树莓大小。", set: ["week": 8]),
            .watch("Week 12: all organs formed; the first-trimester scan.", "第 12 周：器官基本形成，孕早期超声检查。", set: ["week": 12]),
            .watch("Week 20: halfway. Movements (quickening) are felt.", "第 20 周：孕期过半，开始感到胎动。", set: ["week": 20]),
            .watch("Week 28: eyes open; a baby born now often survives with care.", "第 28 周：眼睛睁开；此时早产经救治多可存活。", set: ["week": 28]),
            .watch("Week 40: full term — about 50 cm and 3.4 kg.", "第 40 周：足月——约 50 厘米、3.4 公斤。", set: ["week": 40]),
            .tryIt("Drag through the weeks.", "试一试：拖动孕周。",
                   TryStep(mode: .scrub([Scrub(param: "week", label: "Week 孕周", min: 6, max: 40, digits: 0)]), success: { _ in true },
                           ok: Bilingual("Fundal height (cm above the pubic bone) ≈ weeks, from about week 20.", "约 20 周后，宫高（耻骨上厘米数）≈ 孕周数。"))),
        ],
        draw: { s, p, t in
            let week = p[v: "week"]
            let size = fetalSize(week)
            let purple = hex("#6C4F9E"), line = hex("#C9A58A"), skin = hex("#F2C9A5"), label = hex("#8A6A5A")
            // fundal height: pubic bone at 12 w, navel at 20 w, breastbone tip at 36 w, drops a little by 40 w
            let marks: [(Double, Double)] = [(6, 250), (12, 244), (20, 168), (28, 132), (36, 100), (40, 110)]
            let i = max(0, (marks.firstIndex { $0.0 >= week } ?? marks.count) - 1)
            let (w0, y0) = marks[i], (w1, y1) = marks[min(marks.count - 1, i + 1)]
            let fundus = w1 == w0 ? y0 : y0 + (y1 - y0) * ((week - w0) / (w1 - w0)).clamped(0, 1)
            let grow = ((250 - fundus) / 150).clamped(0, 1)
            let belly = 150 + grow * 62
            // mother, side view facing right: back, spine, pubic bone, navel, breastbone tip
            s.path("M 60 20 C 58 90, 64 170, 72 230 C 76 262, 92 285, 120 290 L 150 290 C 162 270, 164 256, 160 248 "
                   + "C \(belly) 238, \(belly + 6) 170, 162 104 C 168 80, 172 50, 170 20 Z", fill: hex("#F7E6DA"), stroke: line, lw: 2)
            s.path("M 70 30 C 64 90, 70 150, 80 200 C 86 230, 84 250, 96 268", stroke: hex("#D9CBB0"), lw: 9, cap: .round)
            s.ellipse(157, 250, 6, 10, fill: hex("#E9E2CF"), stroke: hex("#B8A58A"))
            s.text("pubic bone 耻骨", 170, 262, size: 8, color: label)
            s.circle(belly - 12 - (1 - grow) * 2, 168, 2.5, fill: label)
            s.text("navel 脐", belly - 4, 172, size: 8, color: label)
            s.circle(162, 100, 2.5, fill: label)
            s.text("breastbone tip 剑突", 172, 98, size: 8, color: label)
            // uterus: pear from the cervix up to the fundus, leaning forward
            let cervix = CGPoint(x: 128, y: 250)
            let height = max(34, cervix.y - fundus + 8)
            let width = 16 + height * 0.62
            let cx = cervix.x + width * 0.18
            let top = cervix.y - height
            s.path("M \(cervix.x - 6) \(cervix.y) C \(cx - width / 2) \(cervix.y - height * 0.2), \(cx - width / 2) \(top + 4), \(cx) \(top) "
                   + "C \(cx + width / 2) \(top + 4), \(cx + width / 2) \(cervix.y - height * 0.2), \(cervix.x + 6) \(cervix.y) Z",
                   fill: hex("#F2B8C0"), stroke: hex("#C9788A"), lw: 2)
            s.text("uterus 子宫", cx - 22, top - 6, size: 8, color: hex("#A0506A"))
            // fetus: head shrinks from ½ to ¼ of body length; turns head-down after ~32 w
            let length = min((height - 16) * 0.95, max(4, size.cm * 3.2))
            let headFrac = week < 20 ? 0.5 - (week - 8) / 12 * 0.17 : 0.33 - (week - 20) / 20 * 0.08
            let headR = length * headFrac / 2
            let turn = ((week - 30) / 4).clamped(0, 1) * 170
            let kick = week >= 20 ? pow(max(0, sin(t * 3)), 8) * 4 : 0
            let centre = CGPoint(x: cx, y: cervix.y - height * 0.48)
            s.group(translate: centre, rotate: -turn, about: .zero) { g in
                let top = -length / 2 + headR
                g.ellipse(2, top + headR + length * 0.28, headR * 0.95, length * 0.3, fill: skin, stroke: line)
                g.circle(0, top, headR, fill: skin, stroke: line)
                g.line(headR * 0.4, top + headR * 1.4, headR * 1.2, top + headR * 2.2, stroke: hex("#EBB98F"), lw: max(1.5, headR * 0.35), cap: .round)
                g.line(-headR * 0.2, length * 0.32, headR * 1.1 + kick, length * 0.4, stroke: hex("#EBB98F"), lw: max(2, headR * 0.45), cap: .round)
            }
            if week >= 12 { s.path("M \(cx) \(centre.y) Q \(cx - 30) \(centre.y + 30) \(cx - 18) \(top + 16)", stroke: hex("#C9788A"), lw: 1.2) }
            s.line(290, 40, 290, 40 + size.cm * 4, stroke: purple, lw: 4, cap: .round)
            s.text(String(format: "%.1f cm", size.cm), 298, 50, size: 11, color: purple)
            s.text(size.g < 10 ? String(format: "%.1f g", size.g) : "\(Int(size.g.rounded())) g", 298, 66, size: 11, color: purple)
            s.text("Week 第 \(Int(week.rounded())) 周 · about a \(size.like)", 12, 14, size: 13, color: purple, bold: true)
        },
        sources: ["Typical fetal length/weight by gestational age (ACOG, Hadlock)"]
    )

    static let labor = Scenario(
        id: "labor", group: .pregnancy, title: Bilingual("Labour & birth", "分娩过程"),
        params: ["cm": 1, "descent": 0, "placenta": 0],
        steps: [
            .watch("Early labour: irregular contractions slowly soften and open the cervix.", "潜伏期：不规律宫缩使宫颈逐渐变软、扩张。", set: ["cm": 2, "descent": 0, "placenta": 0]),
            .watch("Active labour (from ~6 cm): strong contractions every 2–3 minutes.", "活跃期（约 6 厘米起）：强宫缩，每 2–3 分钟一次。", set: ["cm": 7]),
            .tryIt("Open the cervix to full dilation — 10 cm.", "试一试：宫口开全——10 厘米。",
                   TryStep(mode: .scrub([Scrub(param: "cm", label: "Dilation 宫口", min: 0, max: 10, unit: "cm", digits: 0)]), success: { $0[v: "cm"] >= 9.8 },
                           ok: Bilingual("Fully dilated — time to push.", "宫口开全——开始用力。"), demo: ["cm": 10])),
            .tryIt("Stage 2: with each push the baby moves down and out.", "试一试：第二产程：每次用力，胎儿下降娩出。", set: ["cm": 10],
                   TryStep(mode: .scrub([Scrub(param: "descent", label: "Descent 下降", min: 0, max: 1)]), success: { $0[v: "descent"] >= 0.95 },
                           ok: Bilingual("Born!", "宝宝出生了！"), demo: ["descent": 1])),
            .watch("Stage 3: the placenta follows, usually within 30 minutes.", "第三产程：胎盘娩出，通常在 30 分钟内。", set: ["descent": 1, "placenta": 1]),
            .watch("Go to hospital: contractions regular ~5 min apart (first baby), waters break, bleeding, or fewer movements.",
                   "何时去医院：宫缩规律约 5 分钟一次（初产）、破水、出血或胎动减少。"),
        ],
        draw: { s, p, t in
            // sagittal view, mother's front to the right: uterus above the pelvis, birth canal curving forward
            let cm = p[v: "cm"], descent = p[v: "descent"], placenta = p[v: "placenta"]
            let period = cm < 6 ? 6.0 : 2.5
            let sq = pow(max(0, sin(t / period * 2 * .pi)), 3)
            let label = hex("#8A3B45"), bone = hex("#E9E2CF"), edge = hex("#B8A58A")
            let born = descent > 0.95
            // pelvis: sacrum and coccyx behind, pubic bone in front
            s.path("M 92 120 C 88 170, 100 225, 140 262 C 150 270, 160 272, 168 270", stroke: bone, lw: 14, cap: .round)
            s.path("M 92 120 C 88 170, 100 225, 140 262 C 150 270, 160 272, 168 270", stroke: edge, lw: 1)
            s.ellipse(258, 222, 10, 18, fill: bone, stroke: edge)
            s.text("sacrum 骶骨", 20, 180, size: 8, color: hex("#8F7E63"))
            s.text("pubic bone 耻骨", 272, 222, size: 8, color: hex("#8F7E63"))
            // birth canal (curve of Carus) from the cervix to the outside
            let canal = [CGPoint(x: 190, y: 214), CGPoint(x: 196, y: 250), CGPoint(x: 222, y: 284)]
            s.path("M 176 216 C 180 252, 196 280, 212 296 M 206 214 C 214 246, 236 270, 252 290", stroke: hex("#D9A0AE"), lw: 3)
            s.line(120, 240, 280, 240, stroke: hex("#999999"), lw: 1, dash: [3, 3])
            s.text("station 0 · ischial spines 坐骨棘", 282, 244, size: 7)
            // uterus contracting; the cervix opens with dilation
            let wall = 7 + sq * 7 + (placenta > 0.5 ? 6 : 0)
            let shrink = placenta > 0.5 ? 0.75 : 1
            let gap = cm / 10 * 34
            s.group(translate: CGPoint(x: 191 * (1 - shrink), y: 214 * (1 - shrink)), scale: shrink) { g in
                g.path("M \(191 - gap / 2 - 10) 214 C 120 196, 104 100, 150 44 C 176 18, 214 18, 238 44 C 284 100, 268 196, \(191 + gap / 2 + 10) 214",
                       fill: hex("#F4C6CF"), stroke: hex("#C9788A"), lw: wall)
                g.line(191 - gap / 2 - 12, 216, 191 - gap / 2, 222, stroke: hex("#8A3B45"), lw: 6, cap: .round)
                g.line(191 + gap / 2 + 12, 216, 191 + gap / 2, 222, stroke: hex("#8A3B45"), lw: 6, cap: .round)
                if placenta < 0.5 {
                    g.path("M 128 70 C 120 100, 126 130, 136 140 C 150 128, 156 96, 146 70 Z", fill: hex("#A83248"))
                }
            }
            // baby: head leads down the canal, flexed, body curled above it
            let u = descent
            let a = (1 - u) * (1 - u), b = 2 * u * (1 - u), c = u * u
            let head = CGPoint(x: a * canal[0].x + b * canal[1].x + c * canal[2].x, y: a * (canal[0].y - 22) + b * canal[1].y + c * (canal[2].y + 10))
            if placenta < 0.5 && !born {
                let skin = hex("#F2C9A5"), line = hex("#C9A58A")
                s.ellipse(head.x - 4, head.y - 58, 30, 44, fill: skin, stroke: line)
                s.line(head.x + 14, head.y - 70, head.x + 26, head.y - 40, stroke: hex("#EBB98F"), lw: 8, cap: .round)
                s.line(head.x - 20, head.y - 92, head.x + 10, head.y - 100, stroke: hex("#EBB98F"), lw: 9, cap: .round)
                s.circle(head.x, head.y, 26, fill: skin, stroke: line, lw: 1.5)
                s.path("M \(head.x - 30) \(head.y - 70) C \(head.x - 40) \(head.y - 120), \(head.x - 60) \(head.y - 140), \(head.x - 58) \(head.y - 150)",
                       stroke: hex("#C9788A"), lw: 2)
            }
            if placenta > 0.5 {
                s.path("M 200 262 C 196 276, 204 290, 214 294 C 226 288, 226 270, 214 260 Z", fill: hex("#A83248"))
                s.text("placenta delivered 胎盘娩出", 228, 282, size: 8, color: label)
            }
            if born && placenta < 0.5 { s.text("baby born 出生", 232, 290, size: 9, color: hex("#2E9E5B"), bold: true) }
            s.text("cervix 宫颈 \(Int(cm.rounded())) cm", 200, 208, size: 8, color: label)
            if placenta < 0.5 { s.text("placenta 胎盘", 60, 60, size: 8, color: label) }
            if sq > 0.3 && placenta < 0.5 { s.text("contraction 宫缩", 268, 60, size: 10, color: hex("#C9788A")) }
            let stage = placenta > 0.5 ? "Stage 3 · placenta 第三产程" : descent > 0.05 ? "Stage 2 · pushing & birth 第二产程"
                : cm < 6 ? "Stage 1 · early (latent) 第一产程 潜伏期" : "Stage 1 · active 第一产程 活跃期"
            s.rect(8, 6, 250, 24, r: 8, fill: .white, stroke: hex("#6C4F9E"), lw: 2)
            s.text(stage, 18, 22, size: 10, color: hex("#6C4F9E"), bold: true)
            s.text("every \(period == 6 ? "5–20" : "2–3") min", 350, 24, anchor: .end)
        },
        sources: ["WHO intrapartum care 2018 (active phase from 5–6 cm)"]
    )
}
