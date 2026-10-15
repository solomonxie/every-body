import SwiftUI

extension Illustrations {
    static func childVaccines(for who: Profile) -> Scenario {
        var s = Scenario(
            id: "child-vaccines", group: .children, title: Bilingual("Vaccinations", "预防接种"),
            warning: Bilingual("Schedules differ by country and change — follow your clinic’s record. This doesn’t replace your doctor’s advice.",
                               "各国程序不同且会调整，以接种门诊和预防接种证为准。本内容不能代替医生建议。"),
            params: ["mode": 0, "months": 2],
            steps: [
                .watch("Serious reactions are very rare (about 1 in a million doses) and come within minutes — why you wait at the clinic. Call 911 for swelling of the face or lips, trouble breathing, spreading hives, or a pale, floppy child.",
                       "严重过敏极少见（约百万分之一），多在几分钟内出现——所以接种后要留观。面部或嘴唇肿胀、呼吸困难、荨麻疹迅速扩散、孩子苍白瘫软：立即拨打 120。",
                       set: ["mode": 0]),
                .watch("What each vaccine protects against: diseases that once killed or disabled many children, and still do where few are vaccinated.",
                       "每种疫苗预防什么：这些疾病曾让许多孩子死亡或残疾，在接种率低的地方至今仍是如此。",
                       set: ["mode": 1]),
                .tryIt("Slide through the visits and see which vaccines are given at each age.", "试一试：拖动年龄，看看每个月龄要接种哪些疫苗。",
                       set: ["mode": 2, "months": 0],
                       TryStep(mode: .scrub([Scrub(param: "months", label: "Age in months 月龄", min: 0, max: 72, digits: 0)]), success: { $0[v: "months"] >= 48 },
                               ok: Bilingual("Most doses come in the first 18 months, with boosters before school. Missed one? You don’t start again — just catch up.",
                                             "大多数疫苗在 18 月龄内完成，入学前加强。漏种了？不用重新开始，补种即可。"),
                               demo: ["months": 72])),
                .watch("Afterwards, a sore, red spot, a mild fever and a fussy or sleepy day are normal and pass in 1–2 days. Call your doctor for a fever of 40 °C or more, crying for 3 hours or more, a fit — or if you’re worried.",
                       "接种后，针眼处酸痛发红、低热、烦躁或嗜睡一两天都是正常的。发热 ≥40 °C、哭闹 3 小时以上、抽搐——或你担心时，联系医生。",
                       set: ["mode": 3]),
                .watch("Making it easier: feed or cuddle during and after the jab, hold them upright on your lap, stay calm, and distract older children.",
                       "让接种更轻松：打针时和打完后喂奶或抱着安抚，让孩子竖直坐在你腿上，保持平静，大孩子可以转移注意力。",
                       set: ["mode": 4]),
                .watch("Vaccines protect your child when germs are most dangerous, and babies too young to be vaccinated. They don’t cause autism — studies of over 650,000 children found no link.",
                       "疫苗在病菌最危险的时候保护孩子，也保护还太小不能接种的婴儿。疫苗不会导致自闭症——对超过 65 万名儿童的研究没有发现关联。",
                       set: ["mode": 5]),
            ],
            draw: { s, p, t in drawVaccines(&s, p, t) },
            sources: ["AAP Recommended Child and Adolescent Immunization Schedule (US)",
                      "国家免疫规划疫苗儿童免疫程序及说明（2021 年版）；国家卫生健康委：自 2025 年 1 月 1 日起百白破疫苗改为 2、4、6、18 月龄和 6 周岁各 1 剂",
                      "WHO: Vaccines and immunization — diseases prevented; WHO position paper on reducing pain at the time of vaccination (2015)",
                      "CDC Vaccine Information Statements: common side effects, when to call; McNeil et al. 2016: anaphylaxis about 1.3 per million doses",
                      "Hviid et al. 2019, Annals of Internal Medicine: MMR and autism in 657,461 Danish children, no link; WHO and AAP: vaccines do not cause autism"],
            keywords: ["vaccine", "vaccination", "immunization", "jab", "shot", "schedule", "MMR", "DTaP", "polio", "hepatitis B", "side effects", "autism",
                       "疫苗", "预防接种", "打疫苗", "免疫程序", "接种证", "麻腮风", "百白破", "脊灰", "乙肝", "卡介苗", "副作用"]
        )
        s.profileNote = switch who.age {
        case .infant: Bilingual("Baby: most doses come in the first year. A feed during the jab soothes best.", "婴儿：大部分疫苗在第一年接种。打针时喂奶最能安抚。")
        case .toddler, .child: Bilingual("Child: boosters before school (4–6 years). Tell them honestly it’s a quick pinch.", "儿童：入学前（4–6 岁）要加强。诚实地告诉孩子只是被捏一下。")
        default: nil
        }
        return s
    }

    @MainActor private static func drawVaccines(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let mode = p[v: "mode"]
        let panels: [@MainActor (inout Sketch) -> Void] = [
            { vaccineCallNow(&$0) }, { vaccineGrid(&$0) }, { vaccineSchedule(&$0, p) }, { vaccineAfter(&$0) }, { vaccineComfort(&$0) }, { vaccineWhy(&$0) },
        ]
        for (i, draw) in panels.enumerated() {
            let w = panel(mode, i)
            if w > 0.01 { s.group(opacity: w) { g in draw(&g) } }
        }
    }

    /// card with a coloured title and bullet lines
    @MainActor private static func bulletCard(_ s: inout Sketch, _ x: Double, _ y: Double, _ w: Double, _ h: Double, color: Color,
                                               _ title: (String, String), _ rows: [(String, String)], ok: Bool? = nil, gap: Double = 24) {
        s.card(x, y, w, h, accent: color)
        s.label(title.0, title.1, x + 14, y + 18, size: 9.5, color: color, bold: true)
        for (i, r) in rows.enumerated() {
            let cy = y + 38 + Double(i) * gap
            if let ok { mark(&s, CGPoint(x: x + 19, y: cy), ok: ok, r: 6) } else { s.circle(x + 18, cy, 2.4, fill: color) }
            s.noteLeft(r.0, r.1, x + 30, cy, width: w - 36, size: 8.5, color: Tone.ink)
        }
    }

    // MARK: serious reactions

    @MainActor private static func vaccineCallNow(_ s: inout Sketch) {
        s.stateChip("Call 911 now", "立即拨打 120", 354, 6, color: Anat.red, anchor: .end)
        s.label("Severe allergy: within minutes", "严重过敏：几分钟内出现", 8, 22, size: 10, color: Tone.ink, bold: true)
        bulletCard(&s, 8, 36, 172, 150, color: Anat.red, ("Call 911 now", "立即拨打 120"),
                   [("Swelling of the face, lips or tongue", "面部、嘴唇或舌头肿胀"), ("Struggling to breathe, wheezing", "呼吸困难、喘鸣"),
                    ("Hives spreading fast", "荨麻疹迅速扩散"), ("Pale, floppy or collapsing", "苍白、瘫软或晕倒")], gap: 27)
        bulletCard(&s, 8, 194, 172, 100, color: Anat.amber, ("Call your doctor", "联系医生"),
                   [("Fever 40 °C or more", "发热 ≥40 °C"), ("Crying 3 hours or more, or a fit", "哭闹 3 小时以上或抽搐"), ("You’re worried", "你很担心")], gap: 19)
        s.card(188, 36, 164, 150)
        s.stopwatch(CGPoint(x: 222, y: 76), 18, minutes: 15, color: Anat.purple)
        s.label("Wait at the clinic", "接种后留观", 248, 70, size: 9.5, color: Anat.purple, bold: true)
        s.label("15–30 min", "15–30 分钟", 248, 86, size: 13, color: Anat.purple, bold: true)
        s.noteLeft("Staff can treat a reaction on the spot, with adrenaline.", "出现反应时医护人员可以当场用肾上腺素处理。", 200, 140, width: 142, size: 8.5, color: Tone.ink)
        s.card(188, 194, 164, 100)
        s.label("≈ 1 in 1,000,000", "约百万分之一", 270, 228, size: 13, color: Tone.ink, anchor: .middle, bold: true)
        s.cardNote("doses causes a severe allergic reaction", "剂次会引起严重过敏", 270, 256, width: 146, size: 8.5, color: Tone.sub)
    }

    // MARK: what each protects against

    private static let vaccineList: [(String, String, String, String)] = [
        ("Hep B", "乙肝疫苗", "Hepatitis B: liver damage, liver cancer", "乙型肝炎：肝损伤、肝癌"),
        ("DTaP", "百白破疫苗", "Diphtheria, tetanus, whooping cough", "白喉、破伤风、百日咳"),
        ("Polio", "脊灰疫苗", "Polio: lifelong paralysis", "脊髓灰质炎：终身瘫痪"),
        ("Hib", "Hib 疫苗", "Meningitis, throat swelling, pneumonia", "脑膜炎、会厌炎、肺炎"),
        ("Pneumococcal", "肺炎球菌疫苗", "Pneumonia, meningitis, blood infection", "肺炎、脑膜炎、血流感染"),
        ("Rotavirus", "轮状病毒疫苗", "Severe diarrhoea and dehydration", "严重腹泻和脱水"),
        ("MMR", "麻腮风疫苗", "Measles, mumps, rubella", "麻疹、腮腺炎、风疹"),
        ("Chickenpox", "水痘疫苗", "Chickenpox and its complications", "水痘及其并发症"),
        ("Meningococcal", "流脑疫苗", "Meningitis and sepsis", "流行性脑脊髓膜炎、败血症"),
        ("Flu", "流感疫苗", "Flu — every year from 6 months", "流感——6 月龄起每年接种"),
    ]

    @MainActor private static func vaccineGrid(_ s: inout Sketch) {
        s.label("What each vaccine prevents", "每种疫苗预防什么", 8, 20, size: 11, color: Tone.ink, bold: true)
        for (i, v) in vaccineList.enumerated() {
            let x = 8 + Double(i % 2) * 176, y = 32 + Double(i / 2) * 53
            s.card(x, y, 168, 47, accent: Tone.blue)
            syringe(&s, CGPoint(x: x + 22, y: y + 23.5))
            s.label(v.0, v.1, x + 40, y + 17, size: 9.5, color: Tone.blue, bold: true)
            s.noteLeft(v.2, v.3, x + 40, y + 32, width: 122, size: 7.8, color: Tone.ink)
        }
    }

    @MainActor private static func syringe(_ s: inout Sketch, _ c: CGPoint) {
        s.circle(c.x, c.y, 12, fill: Tone.blue.opacity(0.1))
        s.group(rotate: -45, about: c) { g in
            g.rect(c.x - 7, c.y - 3, 12, 6, r: 1.5, fill: .white, stroke: Tone.blue, lw: 1.1)
            g.rect(c.x - 6, c.y - 2, 6, 4, fill: Tone.blue.opacity(0.4))
            g.line(c.x + 5, c.y, c.x + 10, c.y, stroke: Tone.blue, lw: 1)
            g.line(c.x - 7, c.y, c.x - 10, c.y, stroke: Tone.blue, lw: 1.4)
            g.line(c.x - 10, c.y - 3, c.x - 10, c.y + 3, stroke: Tone.blue, lw: 1.4)
        }
    }

    // MARK: schedule

    /// US (AAP) and China (national programme) routine visits: age in months, label, vaccines
    private static let usVisits: [(Int, String, [String])] = [
        (0, "Birth", ["Hep B"]), (2, "2 mo", ["Hep B", "Rotavirus", "DTaP", "Hib", "Pneumococcal", "Polio"]),
        (4, "4 mo", ["Rotavirus", "DTaP", "Hib", "Pneumococcal", "Polio"]), (6, "6 mo", ["Hep B", "Rotavirus", "DTaP", "Pneumococcal", "Polio", "Flu, yearly"]),
        (12, "12–15 mo", ["MMR", "Chickenpox", "Hib", "Pneumococcal", "Hep A"]), (15, "15–18 mo", ["DTaP"]),
        (48, "4–6 yr", ["DTaP", "Polio", "MMR", "Chickenpox"]),
    ]
    private static let cnVisits: [(Int, String, [String])] = [
        (0, "出生", ["乙肝", "卡介苗"]), (1, "1 月", ["乙肝"]), (2, "2 月", ["脊灰（IPV）", "百白破"]), (3, "3 月", ["脊灰（IPV）"]),
        (4, "4 月", ["脊灰（口服）", "百白破"]), (6, "6 月", ["乙肝", "百白破", "A 群流脑"]), (8, "8 月", ["麻腮风", "乙脑"]), (9, "9 月", ["A 群流脑"]),
        (18, "18 月", ["百白破", "麻腮风", "甲肝"]), (24, "2 岁", ["乙脑"]), (36, "3 岁", ["A 群 C 群流脑"]), (48, "4 岁", ["脊灰（口服）"]),
        (72, "6 岁", ["百白破", "A 群 C 群流脑"]),
    ]

    @MainActor private static func vaccineSchedule(_ s: inout Sketch, _ p: Params) {
        let visits = s.zh ? cnVisits : usVisits, months = p[v: "months"]
        let idx = visits.lastIndex { Double($0.0) <= months + 0.5 } ?? 0
        let v = visits[idx]
        s.label("Routine visits", "常规接种", 8, 20, size: 11, color: Tone.ink, bold: true)
        s.pill("US · AAP schedule", "中国 · 国家免疫规划", 8 + s.width("Routine visits", "常规接种", size: 11, bold: true) + 8, 16, color: Tone.blue, size: 8, filled: false)
        s.stateChip(v.1, v.1, 354, 2, color: Tone.blue, anchor: .end)
        let x0 = 22.0, x1 = 338.0, y = 62.0, gap = (x1 - x0) / Double(visits.count - 1)
        s.line(x0, y, x1, y, stroke: Tone.rule, lw: 3, cap: .round)
        s.line(x0, y, x0 + gap * Double(idx), y, stroke: Tone.blue, lw: 3, cap: .round)
        for (i, vi) in visits.enumerated() {
            let x = x0 + gap * Double(i), on = i == idx
            s.circle(x, y, on ? 7 : 4, fill: i <= idx ? Tone.blue : .white, stroke: Tone.blue, lw: 1.2)
            s.label(vi.1, vi.1, x, y + (i % 2 == 0 ? 20 : -12), size: on ? 8.5 : 7, color: on ? Tone.blue : Tone.sub, anchor: .middle, bold: on)
        }
        // vaccines at this visit, as wrapped pills
        s.card(8, 96, 344, 130, accent: Tone.blue)
        s.caption("Given at this visit", "本次接种", 22, 114, color: Tone.blue)
        var px = 22.0, py = 138.0
        for name in v.2 {
            let w = s.width(name, name, size: 10, bold: true) + 26
            if px + w > 342 { px = 22; py += 28 }
            s.rect(px, py - 11, w, 22, r: 11, fill: Tone.blue.opacity(0.12))
            syringeDot(&s, CGPoint(x: px + 10, y: py))
            s.label(name, name, px + 18, py + 3.5, size: 10, color: Tone.ink, bold: true)
            px += w + 6
        }
        s.card(8, 234, 344, 60)
        s.noteLeft("Missed a dose? You don’t start again — catch up. Other countries: follow your national schedule.",
                   "漏种可以补种，不用重新开始。肺炎球菌、Hib、轮状病毒、水痘、流感等非免疫规划疫苗可咨询接种门诊。",
                   22, 264, width: 320, size: 8.5, color: Tone.ink)
    }

    @MainActor private static func syringeDot(_ s: inout Sketch, _ c: CGPoint) {
        s.circle(c.x, c.y, 3.5, fill: Tone.blue)
    }

    // MARK: afterwards

    @MainActor private static func vaccineAfter(_ s: inout Sketch) {
        s.label("After the jab", "接种之后", 8, 20, size: 11, color: Tone.ink, bold: true)
        bulletCard(&s, 8, 32, 172, 152, color: Anat.green, ("Normal · passes in 1–2 days", "正常 · 一两天消退"),
                   [("Sore, red or swollen spot", "针眼处酸痛、发红或肿"), ("Mild fever", "低热"), ("Fussy or sleepy", "烦躁或嗜睡"),
                    ("MMR: rash or fever 1–2 weeks later", "麻腮风：1–2 周后可能出疹或发热")], ok: true, gap: 28)
        bulletCard(&s, 8, 192, 172, 102, color: Tone.blue, ("What helps", "怎么缓解"),
                   [("Cool, damp cloth on the spot", "针眼处敷凉湿毛巾"), ("Extra feeds or drinks", "多喂奶、多喝水"),
                    ("Fever medicine if uncomfortable, by weight", "难受时按体重用退烧药")], gap: 20)
        bulletCard(&s, 188, 32, 164, 152, color: Anat.amber, ("Call your doctor", "联系医生"),
                   [("Fever 40 °C or more", "发热 ≥40 °C"), ("Crying 3 hours or more", "哭闹 3 小时以上"), ("A fit", "抽搐"),
                    ("You’re worried", "你很担心")], gap: 28)
        callBox(&s, 188, 192, 164, 102, "Swelling of the face, trouble breathing or a floppy child: call 911", "面部肿胀、呼吸困难或孩子瘫软：拨打 120")
    }

    // MARK: comfort

    @MainActor private static func vaccineComfort(_ s: inout Sketch) {
        s.stateChip("Less pain, less fear", "少疼、少怕", 354, 6, color: Anat.green, anchor: .end)
        s.label("Making it easier", "让接种更轻松", 8, 22, size: 10, color: Tone.ink, bold: true)
        tiles(&s, [("Breastfeed or give a bottle during and after", "打针时和打完后喂奶"), ("Hold them upright on your lap", "让孩子竖直坐在你腿上"),
                   ("Stay calm and talk softly — they read your face", "保持平静、轻声说话——孩子会看你的表情"),
                   ("Distract older children: toys, songs, blowing bubbles", "大孩子转移注意力：玩具、唱歌、吹泡泡"),
                   ("Tell them honestly: a quick pinch", "诚实告诉孩子：像被捏一下"), ("Ask about numbing cream beforehand", "可提前咨询表面麻醉膏")],
              color: Anat.green)
    }

    // MARK: why

    @MainActor private static func vaccineWhy(_ s: inout Sketch) {
        s.label("Why vaccinate", "为什么要接种", 8, 20, size: 11, color: Tone.ink, bold: true)
        let rows: [(String, String, String, String, Color)] = [
            ("Protects them early", "尽早保护", "Before they meet the germs that hit babies hardest", "在遇到对婴儿最危险的病菌之前就建立保护", Tone.blue),
            ("Protects others", "保护他人", "Babies too young for a dose, and children who can’t have one", "保护还太小不能接种的婴儿，以及不能接种的孩子", Anat.green),
            ("Checked again and again", "反复验证", "No link with autism — studies of over 650,000 children", "与自闭症无关——超过 65 万名儿童的研究证实", Anat.purple),
        ]
        for (i, r) in rows.enumerated() {
            let y = 34 + Double(i) * 86
            s.card(8, y, 344, 78, accent: r.4)
            let c = CGPoint(x: 44, y: y + 39)
            s.circle(c.x, c.y, 22, fill: r.4.opacity(0.12))
            whyIcon(&s, i, c, r.4)
            s.label(r.0, r.1, 80, y + 26, size: 11, color: r.4, bold: true)
            s.noteLeft(r.2, r.3, 80, y + 50, width: 262, size: 9, color: Tone.ink)
        }
    }

    @MainActor private static func whyIcon(_ s: inout Sketch, _ i: Int, _ c: CGPoint, _ col: Color) {
        switch i {
        case 0:
            s.path("M \(c.x) \(c.y - 12) L \(c.x + 10) \(c.y - 8) L \(c.x + 10) \(c.y + 1) Q \(c.x + 10) \(c.y + 9) \(c.x) \(c.y + 13) Q \(c.x - 10) \(c.y + 9) \(c.x - 10) \(c.y + 1) L \(c.x - 10) \(c.y - 8) Z",
                   fill: col)
            s.path("M \(c.x - 4.5) \(c.y) l 3.5 3.5 l 6 -7", stroke: .white, lw: 2, cap: .round)
        case 1:
            for (dx, r) in [(-8.0, 5.0), (8, 5), (0, 6.5)] {
                s.circle(c.x + dx, c.y - 5 + (r > 5 ? -2 : 0), r * 0.6, fill: col)
                s.path("M \(c.x + dx - r) \(c.y + 10) Q \(c.x + dx) \(c.y - 2) \(c.x + dx + r) \(c.y + 10) Z", fill: col)
            }
        default:
            s.circle(c.x - 2, c.y - 2, 8, stroke: col, lw: 2.2)
            s.line(c.x + 4, c.y + 4, c.x + 10, c.y + 10, stroke: col, lw: 2.6, cap: .round)
        }
    }
}
