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
            let stuckAt = 0.35 + chance * 0.6
            let travel = p[v: "moving"] > 0.5 ? min(stuckAt, (t * 0.12).truncatingRemainder(dividingBy: 1.2)) : 0
            let u = travel
            let a = pow(1 - u, 3), b = 3 * u * pow(1 - u, 2), c = 3 * u * u * (1 - u), d = pow(u, 3)
            let stone = CGPoint(x: a * 110 + b * 120 + c * 150 + d * 160, y: a * 90 + b * 140 + c * 170 + d * 230)
            let blocked = p[v: "moving"] > 0.5 && travel >= stuckAt - 0.01 && chance < 0.5
            s.path("M 80 40 C 40 40, 40 120, 90 110 C 110 105, 120 70, 110 55 C 105 45, 95 40, 80 40 Z", fill: hex("#9E3A4A"))
            s.text("kidney 肾", 30, 30, color: hex("#8A3B45"))
            s.path("M 110 90 C 120 140, 150 170, 160 230", stroke: blocked ? hex("#D8434B") : hex("#E0C35A"), lw: 8, cap: .round)
            s.text("ureter 输尿管 (3–4 mm wide)", 170, 150, color: hex("#8A6A1B"))
            s.path("M 140 230 C 140 290, 200 290, 200 230 C 200 215, 140 215, 140 230 Z", fill: hex("#E0C35A"))
            s.text("bladder 膀胱", 210, 260, color: hex("#8A6A1B"))
            s.circle(stone.x, stone.y, 2 + mm * 0.9, fill: hex("#8A7A5A"), stroke: hex("#5A4A3A"))
            if blocked { s.text("⚡ pain 剧痛", stone.x + 14, stone.y + 4, size: 11, color: hex("#D8434B")) }
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
                           ok: Bilingual("Fundal height in cm ≈ weeks, from about week 20.", "约 20 周后，宫高（厘米）≈ 孕周数。"))),
        ],
        draw: { s, p, t in
            let week = p[v: "week"]
            let size = fetalSize(week)
            let k = max(0.08, size.cm / 51.2)
            let uterus = 40 + 90 * min(1, week / 40)
            let kick = week >= 20 ? pow(max(0, sin(t * 3)), 8) * 6 : 0
            let line = hex("#C9A58A"), skin = hex("#F2C9A5"), purple = hex("#6C4F9E")
            s.path("M 70 20 C 60 90, 60 160, 90 280", stroke: line, lw: 3)
            s.path("M 110 30 C \(120 + uterus) 60, \(130 + uterus * 1.1) 200, 120 280", fill: hex("#F7E0D0"), stroke: line, lw: 3)
            let c = CGPoint(x: 120 + uterus * 0.35, y: 200 - uterus * 0.2)
            s.ellipse(c.x, c.y, uterus * 0.5, uterus * 0.62, fill: hex("#F2B8C0"), opacity: 0.6)
            s.group(translate: c, scale: k) { g in
                g.circle(-10, -45, 34, fill: skin, stroke: line, lw: 2 / k)
                g.ellipse(8, 20, 38, 50, fill: skin, stroke: line, lw: 2 / k)
                g.line(30, 50, 10 + kick, 70, stroke: hex("#EBB98F"), lw: 14, cap: .round)
                g.line(-20, 0, -40, 30, stroke: hex("#EBB98F"), lw: 12, cap: .round)
            }
            s.line(260, 40, 260, 40 + size.cm * 4, stroke: purple, lw: 4, cap: .round)
            s.text(String(format: "%.1f cm", size.cm), 270, 50, size: 11, color: purple)
            s.text(size.g < 10 ? String(format: "%.1f g", size.g) : "\(Int(size.g.rounded())) g", 270, 66, size: 11, color: purple)
            s.text("Week 第 \(Int(week.rounded())) 周 · about a \(size.like)", 20, 290, size: 13, color: purple, bold: true)
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
            let cm = p[v: "cm"], descent = p[v: "descent"], placenta = p[v: "placenta"]
            let period = cm < 6 ? 6.0 : 2.5
            let sq = pow(max(0, sin(t / period * 2 * .pi)), 3)
            let gap = cm / 10 * 44
            let stage = placenta > 0.5 ? "Stage 3 · placenta 第三产程" : descent > 0.05 ? "Stage 2 · pushing & birth 第二产程"
                : cm < 6 ? "Stage 1 · early (latent) 第一产程 潜伏期" : "Stage 1 · active 第一产程 活跃期"
            s.path("M \(100 - sq * 6) 40 C \(40 - sq * 6) 60, \(40 - sq * 6) 200, \(150 - gap / 2) 230 L \(150 + gap / 2) 230 C \(260 + sq * 6) 200, \(260 + sq * 6) 60, \(200 + sq * 6) 40 C 170 20, 130 20, \(100 - sq * 6) 40 Z",
                   fill: hex("#F2B8C0"), stroke: hex("#C9788A"), lw: 8 + sq * 8)
            if placenta < 0.5 { s.circle(150, min(150 + descent * 120, 250), 40, fill: hex("#F2C9A5"), stroke: hex("#C9A58A"), lw: 2) }
            s.path("M \(150 - gap / 2 - 30) 230 L \(150 - gap / 2) 236 M \(150 + gap / 2 + 30) 230 L \(150 + gap / 2) 236", stroke: hex("#8A3B45"), lw: 6, cap: .round)
            s.text("cervix 宫颈 \(Int(cm.rounded())) cm", 150, 262, color: hex("#8A3B45"), anchor: .middle)
            if placenta > 0.5 { s.path("M 120 90 q 30 -30 60 0 q 10 30 -30 40 q -40 -5 -30 -40 Z", fill: hex("#A83248")) }
            if sq > 0.3 { s.text("contraction 宫缩", 270, 120, size: 11, color: hex("#C9788A")) }
            s.rect(8, 272, 344, 24, r: 8, fill: .white, stroke: hex("#6C4F9E"), lw: 2)
            s.text(stage, 20, 288, size: 11, color: hex("#6C4F9E"), bold: true)
            s.text("every \(period == 6 ? "5–20" : "2–3") min", 330, 30, anchor: .end)
        },
        sources: ["WHO intrapartum care 2018 (active phase from 5–6 cm)"]
    )
}
