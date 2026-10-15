import SwiftUI

extension Illustrations {
    static func childGrowth(for who: Profile) -> Scenario {
        let months: Double = who.age == .infant ? 6 : who.age == .toddler ? 18 : 12
        let girl = who.female ? 1.0 : 0
        var s = Scenario(
            id: "child-growth", group: .children, title: Bilingual("Growth & milestones", "生长发育与里程碑"),
            warning: Bilingual("Every child grows at their own pace. This is general guidance and doesn’t replace check-ups with your doctor.",
                               "每个孩子的发育节奏不同。本内容仅供参考，不能代替医生的定期体检。"),
            params: ["mode": 0, "girl": girl, "len": 0, "months": months, "kg": WHOGrowth.weight(girl: girl > 0.5, months)[1], "stage": months],
            steps: [
                .watch("Not an emergency, but talk to your doctor soon if your child loses skills or words they had, isn’t back to birth weight by 3 weeks, drops across the chart’s lines, doesn’t react to sounds, isn’t walking by 18 months — or you’re worried.",
                       "不算急症，但出现以下情况要尽快咨询医生：失去已会的能力或词语、出生 3 周还没恢复出生体重、体重曲线往下跨线、对声音没反应、18 个月还不会走——或者你很担心。",
                       set: ["mode": 0]),
                .watch("The WHO chart shows how healthy breastfed babies grow. Most are between the outer lines. Following their own curve matters more than being on the middle line.",
                       "世卫组织生长曲线展示健康母乳喂养婴儿的生长情况。大多数孩子落在两条外线之间。沿着自己的曲线稳定增长，比是否在中线上更重要。",
                       set: ["mode": 1, "len": 0, "months": months, "kg": WHOGrowth.weight(girl: girl > 0.5, months)[1]]),
                .tryIt("Set an age and a weight, and see where it falls on the chart.", "试一试：设置月龄和体重，看看落在曲线的哪里。",
                       TryStep(mode: .scrub([Scrub(param: "months", label: "Age in months 月龄", min: 0, max: 24, digits: 0),
                                             Scrub(param: "kg", label: "Weight 体重", min: 2, max: 16, unit: "kg", digits: 1)]),
                               success: { p in
                                   let w = WHOGrowth.weight(girl: p[v: "girl"] > 0.5, p[v: "months"])
                                   return p[v: "months"] >= 1 && p[v: "kg"] >= w[0] && p[v: "kg"] <= w[2]
                               },
                               ok: Bilingual("Inside the band: the usual range. One reading means little — the trend over several check-ups is what counts.",
                                             "落在区间内：属于常见范围。单次测量说明不了什么——几次体检连起来的趋势才重要。"))),
                .watch("Length grows fastest in the first year: about 50 cm at birth and 75 cm at 1 year. Birth weight roughly triples by the first birthday.",
                       "第一年长得最快：出生时约 50 厘米，1 岁时约 75 厘米。到 1 岁时体重约为出生时的 3 倍。",
                       set: ["mode": 1, "len": 1]),
                .watch("Milestones are what most children (3 in 4) can do by an age. A few weeks late is common. Losing a skill they had is not — tell your doctor.",
                       "里程碑是大多数孩子（4 个里有 3 个）在某个年龄能做到的事。晚几周很常见；但失去已会的能力不正常——要告诉医生。",
                       set: ["mode": 2, "stage": months]),
                .tryIt("Slide through the ages and see what most children do by then.", "试一试：拖动年龄，看看大多数孩子这时会做什么。",
                       TryStep(mode: .scrub([Scrub(param: "stage", label: "Age in months 月龄", min: 2, max: 60, digits: 0)]), success: { $0[v: "stage"] >= 59 },
                               ok: Bilingual("By 5: hops on one foot, counts to 10, tells a short story. Ask early about any worry — early help works best.",
                                             "到 5 岁：能单脚跳、数到 10、讲个小故事。有任何担心尽早问——越早干预效果越好。"),
                               demo: ["stage": 60])),
                .watch("Help them grow: tummy time when awake, talk, read and play every day, breast milk alone for about 6 months, and check-ups to weigh and measure.",
                       "帮助孩子成长：醒着时多趴一趴，每天说话、读书、玩耍，约 6 个月内纯母乳喂养，按时体检称体重、量身长。",
                       set: ["mode": 3]),
            ],
            draw: { s, p, t in drawGrowth(&s, p, t) },
            sources: ["WHO Child Growth Standards (2006): weight- and length-for-age, 0–24 months, 2.3rd / 50th / 97.7th percentiles (tables via CDC NCHS)",
                      "CDC: use the WHO growth charts for children under 2",
                      "CDC “Learn the Signs. Act Early.” developmental milestones (2022, with AAP): what 3 in 4 children do by each age",
                      "NICE NG75 Faltering growth (2017): back to birth weight by 3 weeks; falls across centile lines",
                      "NHS: Baby and toddler development; talk to your health visitor if not walking by 18 months",
                      "AAP: tummy time, media under 18 months; WHO: exclusive breastfeeding for 6 months",
                      "国家卫生健康委员会 WS/T 423-2022《7 岁以下儿童生长标准》"],
            keywords: ["growth", "growth chart", "percentile", "centile", "weight", "height", "length", "milestones", "development", "walking", "talking",
                       "生长曲线", "百分位", "身高", "体重", "身长", "发育", "里程碑", "走路", "说话", "宝宝"]
        )
        s.profileNote = switch who.age {
        case .infant: Bilingual("Baby: weighed often in the first weeks. Most lose a little weight after birth and are back to it by 2 weeks.",
                                "婴儿：头几周要多称体重。多数宝宝出生后体重略降，2 周左右恢复。")
        case .toddler: Bilingual("Toddler: growth slows after the first year, and appetite with it — that’s normal.",
                                 "幼儿：1 岁后长得变慢，胃口也随之变小——这是正常的。")
        case .child: Bilingual("Child: the chart here stops at 2. Older children use height and BMI charts for their age at check-ups.",
                               "儿童：这里的曲线到 2 岁为止。大孩子体检时用相应年龄的身高和 BMI 曲线。")
        default: nil
        }
        return s
    }

    @MainActor private static func drawGrowth(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let mode = p[v: "mode"]
        let panels: [@MainActor (inout Sketch) -> Void] = [{ growthFlags(&$0) }, { growthChart(&$0, p) }, { milestones(&$0, p) }, { growthHelp(&$0) }]
        for (i, draw) in panels.enumerated() {
            let w = panel(mode, i)
            if w > 0.01 { s.group(opacity: w) { g in draw(&g) } }
        }
    }

    @MainActor private static func growthFlags(_ s: inout Sketch) {
        s.stateChip("Talk to your doctor soon", "尽快咨询医生", 354, 6, color: Anat.amber, anchor: .end)
        s.label("Don’t wait and see", "不要一味等待", 8, 22, size: 10, color: Tone.ink, bold: true)
        tiles(&s, [("Loses skills or words they had — at any age", "失去已会的能力或词语——任何年龄"),
                   ("Not back to birth weight by 3 weeks", "出生 3 周还没恢复出生体重"),
                   ("Weight drops across the chart’s lines, or stays flat for months", "体重往下跨线，或几个月不长"),
                   ("Doesn’t react to loud sounds, or look at your face", "对大的声音没反应，或不看你的脸"),
                   ("Not walking by 18 months", "18 个月还不会走"),
                   ("You’re worried — ask early, early help works best", "你很担心——尽早问，越早干预越好")], color: Anat.amber)
    }

    // MARK: WHO chart

    @MainActor private static func growthChart(_ s: inout Sketch, _ p: Params) {
        let girl = p[v: "girl"] > 0.5, len = p[v: "len"].clamped(0, 1) > 0.5
        let months = p[v: "months"].clamped(0, 24), col = girl ? hex("#D0638A") : Tone.blue
        let (lo, hi) = len ? (44.0, 96.0) : (2.0, 16.0)
        let box = CGRect(x: 40, y: 40, width: 300, height: 220)
        func pt(_ m: Double, _ v: Double) -> CGPoint {
            CGPoint(x: box.minX + m / 24 * box.width, y: box.maxY - (v - lo) / (hi - lo) * box.height)
        }
        func curve(_ k: Int) -> [CGPoint] {
            stride(from: 0.0, through: 24, by: 1).map { m in pt(m, len ? WHOGrowth.length(girl: girl, m)[k] : WHOGrowth.weight(girl: girl, m)[k]) }
        }
        s.card(4, 30, 352, 266)
        // grid
        let step = len ? 10.0 : 2
        for v in stride(from: (lo / step).rounded(.up) * step, through: hi, by: step) {
            let y = pt(0, v).y
            s.line(box.minX, y, box.maxX, y, stroke: Tone.rule, lw: 0.6)
            s.text(String(format: "%g", v), box.minX - 5, y + 3, size: 7.5, color: Tone.sub, anchor: .end)
        }
        for m in stride(from: 0, through: 24, by: 3) {
            let x = pt(Double(m), lo).x
            s.line(x, box.minY, x, box.maxY, stroke: Tone.rule, lw: 0.6)
            s.text("\(m)", x, box.maxY + 11, size: 7.5, color: Tone.sub, anchor: .middle)
        }
        s.label("age, months", "月龄", box.maxX, box.maxY + 24, size: 7.5, color: Tone.sub, anchor: .end)
        s.label(len ? "cm" : "kg", len ? "厘米" : "千克", box.minX - 5, box.minY - 6, size: 7.5, color: Tone.sub, anchor: .end)
        // usual range band, then the three lines
        let low = curve(0), mid = curve(1), high = curve(2)
        var band = Path()
        band.addLines(high + low.reversed())
        band.closeSubpath()
        s.shape(band, fill: col.opacity(0.12))
        for (k, line) in [low, mid, high].enumerated() {
            var path = Path()
            path.addLines(line)
            s.shape(path, stroke: col, lw: k == 1 ? 2 : 1, dash: k == 1 ? [] : [3, 2])
        }
        for (k, name) in [(2, ("98th", "P98")), (1, ("50th", "P50")), (0, ("2nd", "P2"))] {
            let e = [low, mid, high][k].last!
            s.label(name.0, name.1, e.x + 3, e.y + 3, size: 7, color: col, bold: k == 1)
        }
        // the child's reading
        let w = len ? WHOGrowth.length(girl: girl, months) : WHOGrowth.weight(girl: girl, months)
        let v = len ? w[1] : p[v: "kg"]
        let d = pt(months, v.clamped(lo, hi))
        s.circle(d.x, d.y, 6, fill: .white, stroke: col, lw: 2.2)
        s.circle(d.x, d.y, 2.6, fill: col)
        s.text(String(format: len ? "%.0f cm" : "%.1f kg", v), d.x + (months > 18 ? -9 : 9), d.y - 8, size: 9, color: Tone.ink, anchor: months > 18 ? .end : .start, bold: true)
        // header
        s.label(len ? "Length for age" : "Weight for age", len ? "年龄别身长" : "年龄别体重", 8, 20, size: 11, color: Tone.ink, bold: true)
        s.pill(girl ? "Girls · WHO" : "Boys · WHO", girl ? "女孩 · 世卫" : "男孩 · 世卫", 8 + s.width(len ? "Length for age" : "Weight for age", len ? "年龄别身长" : "年龄别体重", size: 11, bold: true) + 8, 16,
               color: col, size: 8, filled: false)
        if !len {
            let (en, zh, c): (String, String, Color) = v < w[0] ? ("Below the 2nd line: ask your doctor", "低于 P2 线：咨询医生", Anat.amber)
                : v > w[2] ? ("Above the 98th line: ask your doctor", "高于 P98 线：咨询医生", Anat.amber)
                : ("Within the usual range", "在常见范围内", Anat.green)
            s.stateChip(en, zh, 354, 2, color: c, anchor: .end)
        } else {
            s.stateChip("+25 cm in year one", "第一年长约 25 厘米", 354, 2, color: col, anchor: .end)
        }
    }

    // MARK: milestones

    /// CDC 2022 milestones: what 3 in 4 children do by each age
    private static let milestoneStops: [(months: Int, en: String, zh: String, items: [(String, String)])] = [
        (2, "2 mo", "2 月", [("Smiles when you talk to them", "你说话时会笑"), ("Holds head up on tummy", "趴着时能抬头"), ("Looks at your face", "会看你的脸")]),
        (4, "4 mo", "4 月", [("Holds head steady when held", "竖抱时头稳"), ("Makes sounds back when you talk", "你说话时会回应发声"), ("Brings hands to mouth", "把手放进嘴里")]),
        (6, "6 mo", "6 月", [("Rolls from tummy to back", "能从趴着翻到仰卧"), ("Laughs", "会笑出声"), ("Pushes up on straight arms", "趴着时能直臂撑起")]),
        (9, "9 mo", "9 月", [("Sits without support", "能独坐"), ("Babbles “mamamama”", "会发“妈妈妈妈”的音"), ("Looks when you call their name", "叫名字会看你")]),
        (12, "1 yr", "1 岁", [("Pulls up to stand, walks holding furniture", "扶物站起，扶着家具走"), ("Waves bye-bye", "会挥手再见"), ("Calls you “mama”, “dada” or a special name", "会叫“妈妈”“爸爸”或特别的称呼")]),
        (15, "15 mo", "15 月", [("Takes a few steps alone", "能自己走几步"), ("Tries 1–2 words besides mama, dada", "除爸爸妈妈外会说 1–2 个词"), ("Points to ask for something", "会用手指要东西")]),
        (18, "18 mo", "18 月", [("Walks without holding on", "能独自走路"), ("Tries 3 or more words", "会说 3 个以上的词"), ("Copies you doing chores", "模仿你做家务")]),
        (24, "2 yr", "2 岁", [("Kicks a ball", "会踢球"), ("Puts two words together: “more milk”", "会说两个词的短语：“还要奶”"), ("Points to things in a book", "能指出书里的东西")]),
        (36, "3 yr", "3 岁", [("Talks with you, back and forth", "能和你一来一回地对话"), ("Draws a circle when shown", "示范后能画圆"), ("Puts on some clothes", "能自己穿部分衣服")]),
        (48, "4 yr", "4 岁", [("Says sentences of 4 or more words", "能说 4 个词以上的句子"), ("Catches a large ball most times", "多数时候能接住大球"), ("Pretends during play", "玩耍时会假扮角色")]),
        (60, "5 yr", "5 岁", [("Hops on one foot", "能单脚跳"), ("Counts to 10", "能数到 10"), ("Tells a story with 2 events", "能讲有两个情节的小故事")]),
    ]

    @MainActor private static func milestones(_ s: inout Sketch, _ p: Params) {
        let age = p[v: "stage"]
        let idx = milestoneStops.lastIndex { Double($0.months) <= age + 0.5 } ?? 0
        let stop = milestoneStops[idx]
        s.label("Milestones", "发育里程碑", 8, 20, size: 11, color: Tone.ink, bold: true)
        s.stateChip("By \(stop.en)", "\(stop.zh)时", 354, 2, color: Anat.purple, anchor: .end)
        // timeline: evenly spaced stops
        let x0 = 24.0, x1 = 336.0, y = 62.0
        let gap = (x1 - x0) / Double(milestoneStops.count - 1)
        s.line(x0, y, x1, y, stroke: Tone.rule, lw: 3, cap: .round)
        s.line(x0, y, x0 + gap * Double(idx), y, stroke: Anat.purple, lw: 3, cap: .round)
        for (i, m) in milestoneStops.enumerated() {
            let x = x0 + gap * Double(i), on = i == idx
            s.circle(x, y, on ? 7 : 4, fill: i <= idx ? Anat.purple : .white, stroke: Anat.purple, lw: 1.2)
            s.label(m.en, m.zh, x, y + (i % 2 == 0 ? 20 : -12), size: on ? 8.5 : 7, color: on ? Anat.purple : Tone.sub, anchor: .middle, bold: on)
        }
        for (i, it) in stop.items.enumerated() {
            let cy = 104 + Double(i) * 58
            s.card(8, cy, 344, 50, accent: Anat.purple)
            mark(&s, CGPoint(x: 32, y: cy + 25), ok: true, r: 10)
            s.noteLeft(it.0, it.1, 52, cy + 25, width: 290, size: 10.5, color: Tone.ink, bold: true)
        }
        s.cardNote("A few weeks late is common · losing a skill is not", "晚几周很常见 · 失去已会的能力不正常", 180, 286, width: 344, size: 8.5, color: Anat.red, bold: true)
    }

    // MARK: help them grow

    @MainActor private static func growthHelp(_ s: inout Sketch) {
        s.stateChip("Every day", "每天", 354, 6, color: Anat.green, anchor: .end)
        s.label("Help them grow", "帮助孩子成长", 8, 22, size: 10, color: Tone.ink, bold: true)
        tiles(&s, [("Tummy time when awake, from the first days", "醒着时多趴，从出生头几天开始"),
                   ("Talk, read and sing together", "一起说话、读书、唱歌"),
                   ("Play on the floor; no screens under 18 months except video calls", "多在地上玩；18 个月内除视频通话外不看屏幕"),
                   ("Breast milk alone for about 6 months, then foods too", "约 6 个月内纯母乳，之后添加辅食"),
                   ("Check-ups: weigh, measure, and ask", "按时体检：称重、测量、提问"),
                   ("Vaccines on time", "按时接种疫苗")], color: Anat.green)
    }
}

/// WHO Child Growth Standards, 0–24 months, monthly: (2.3rd, 50th, 97.7th) percentiles.
enum WHOGrowth {
    static let boysWeight: [[Double]] = [
        [2.5, 3.3, 4.4], [3.4, 4.5, 5.8], [4.3, 5.6, 7.1], [5, 6.4, 8], [5.6, 7, 8.7], [6, 7.5, 9.3], [6.4, 7.9, 9.8], [6.7, 8.3, 10.3], [6.9, 8.6, 10.7],
        [7.1, 8.9, 11], [7.4, 9.2, 11.4], [7.6, 9.4, 11.7], [7.7, 9.6, 12], [7.9, 9.9, 12.3], [8.1, 10.1, 12.6], [8.3, 10.3, 12.8], [8.4, 10.5, 13.1],
        [8.6, 10.7, 13.4], [8.8, 10.9, 13.7], [8.9, 11.1, 13.9], [9.1, 11.3, 14.2], [9.2, 11.5, 14.5], [9.4, 11.8, 14.7], [9.5, 12, 15], [9.7, 12.2, 15.3],
    ]
    static let girlsWeight: [[Double]] = [
        [2.4, 3.2, 4.2], [3.2, 4.2, 5.5], [3.9, 5.1, 6.6], [4.5, 5.8, 7.5], [5, 6.4, 8.2], [5.4, 6.9, 8.8], [5.7, 7.3, 9.3], [6, 7.6, 9.8], [6.3, 7.9, 10.2],
        [6.5, 8.2, 10.5], [6.7, 8.5, 10.9], [6.9, 8.7, 11.2], [7, 8.9, 11.5], [7.2, 9.2, 11.8], [7.4, 9.4, 12.1], [7.6, 9.6, 12.4], [7.7, 9.8, 12.6],
        [7.9, 10, 12.9], [8.1, 10.2, 13.2], [8.2, 10.4, 13.5], [8.4, 10.6, 13.7], [8.6, 10.9, 14], [8.7, 11.1, 14.3], [8.9, 11.3, 14.6], [9, 11.5, 14.8],
    ]
    static let boysLength: [[Double]] = [
        [46.1, 49.9, 53.7], [50.8, 54.7, 58.6], [54.4, 58.4, 62.4], [57.3, 61.4, 65.5], [59.7, 63.9, 68], [61.7, 65.9, 70.1], [63.3, 67.6, 71.9],
        [64.8, 69.2, 73.5], [66.2, 70.6, 75], [67.5, 72, 76.5], [68.7, 73.3, 77.9], [69.9, 74.5, 79.2], [71, 75.7, 80.5], [72.1, 76.9, 81.8],
        [73.1, 78, 83], [74.1, 79.1, 84.2], [75, 80.2, 85.4], [76, 81.2, 86.5], [76.9, 82.3, 87.7], [77.7, 83.2, 88.8], [78.6, 84.2, 89.8],
        [79.4, 85.1, 90.9], [80.2, 86, 91.9], [81, 86.9, 92.9], [81.7, 87.8, 93.9],
    ]
    static let girlsLength: [[Double]] = [
        [45.4, 49.1, 52.9], [49.8, 53.7, 57.6], [53, 57.1, 61.1], [55.6, 59.8, 64], [57.8, 62.1, 66.4], [59.6, 64, 68.5], [61.2, 65.7, 70.3],
        [62.7, 67.3, 71.9], [64, 68.7, 73.5], [65.3, 70.1, 75], [66.5, 71.5, 76.4], [67.7, 72.8, 77.8], [68.9, 74, 79.2], [70, 75.2, 80.5],
        [71, 76.4, 81.7], [72, 77.5, 83], [73, 78.6, 84.2], [74, 79.7, 85.4], [74.9, 80.7, 86.5], [75.8, 81.7, 87.6], [76.7, 82.7, 88.7],
        [77.5, 83.7, 89.8], [78.4, 84.6, 90.8], [79.2, 85.5, 91.9], [80, 86.4, 92.9],
    ]

    static func weight(girl: Bool, _ months: Double) -> [Double] { at(girl ? girlsWeight : boysWeight, months) }
    static func length(girl: Bool, _ months: Double) -> [Double] { at(girl ? girlsLength : boysLength, months) }

    /// linear between monthly rows
    private static func at(_ table: [[Double]], _ months: Double) -> [Double] {
        let m = months.clamped(0, 24), i = min(23, Int(m)), f = m - Double(i)
        return (0..<3).map { table[i][$0] + (table[i + 1][$0] - table[i][$0]) * f }
    }
}
