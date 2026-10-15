import SwiftUI

extension Illustrations {
    static func childFever(for who: Profile) -> Scenario {
        var s = Scenario(
            id: "child-fever", group: .children, title: Bilingual("Fever in babies & children", "婴幼儿发热"),
            warning: Bilingual("General guidance — it doesn’t replace a doctor. Worried? Call your doctor; trust your instinct.",
                               "仅供一般参考，不能代替医生。担心就联系医生，相信你的直觉。"),
            params: ["mode": 0, "press": 0, "months": 18, "temp": 38.6, "minutes": 2],
            steps: [
                .watch("Call 911 now, at any temperature, if your child is floppy or hard to wake, struggling to breathe, blue, grey or blotchy, has a rash that doesn’t fade under a glass, has a fit, or a stiff neck and hates bright light.",
                       "无论体温多少，孩子出现以下情况立即拨打 120：软弱无力或难以唤醒、呼吸困难、皮肤或嘴唇发青发灰或出现花斑、皮疹压玻璃杯不褪色、抽搐、颈部僵硬且怕光。",
                       set: ["mode": 0, "press": 0]),
                .tryIt("The glass test: press the side of a clear glass firmly on the rash and look through it.",
                       "试一试：玻璃杯测试——用透明玻璃杯的侧面用力压在皮疹上，隔着杯子看。",
                       set: ["mode": 1, "press": 0],
                       TryStep(mode: .scrub([Scrub(param: "press", label: "Press the glass 按压玻璃杯", min: 0, max: 1)]), success: { $0[v: "press"] > 0.9 },
                               ok: Bilingual("Spots still showing through the glass can mean sepsis or meningitis — call 911 now. Don’t wait for a rash: it can come late or not at all.",
                                             "隔着杯子仍能看到的斑点可能是败血症或脑膜炎——立即拨打 120。不要等皮疹：它可能出现得晚，也可能不出现。"),
                               demo: ["press": 1])),
                .watch("Fever means 38 °C or more. Most are a virus and pass in a few days. Age changes the rule: under 3 months, 38 °C or more needs a doctor now; 3–6 months, 39 °C or more, today.",
                       "体温 ≥38 °C 就是发热。多数是病毒感染，几天就好。年龄不同，标准不同：3 个月以下 ≥38 °C 要立即就医；3–6 个月 ≥39 °C 当天就医。",
                       set: ["mode": 2, "months": 1, "temp": 38.3]),
                .tryIt("Set the age and the temperature, and see what to do.", "试一试：设置月龄和体温，看看该怎么做。",
                       set: ["months": 18, "temp": 38.6],
                       TryStep(mode: .scrub([Scrub(param: "months", label: "Age in months 月龄", min: 0, max: 60, digits: 0),
                                             Scrub(param: "temp", label: "Temperature 体温", min: 36, max: 41, unit: "°C", digits: 1)]),
                               success: { $0[v: "months"] < 3 && $0[v: "temp"] >= 38 },
                               ok: Bilingual("Under 3 months, 38 °C or more: a doctor now, even if the baby seems well. Older children: how they act matters more than the number.",
                                             "3 个月以下、≥38 °C：即使宝宝看起来没事，也要立即就医。大一些的孩子：精神状态比体温数字更重要。"),
                               demo: ["months": 1, "temp": 38.4])),
                .watch("Call your doctor today if the fever lasts 5 days, they drink much less or wet fewer diapers, a rash comes with it, they’re not their usual self — or you’re worried.",
                       "出现以下情况当天联系医生：发热持续 5 天、喝得明显少或尿布湿得少、伴有皮疹、和平时判若两人——或者你很担心。",
                       set: ["mode": 3]),
                .watch("At home: small drinks often, light clothes, check on them through the night. Medicine is for distress, not the number — dosed by weight. No cold sponging, never aspirin.",
                       "居家护理：少量多次喝水，穿得轻薄，夜里多看看。退烧药是为了缓解难受，不是为了把体温降到正常——按体重给药。不要冷水擦身，禁用阿司匹林。",
                       set: ["mode": 4]),
                .watch("A fit with a fever (febrile seizure) is frightening but usually stops within 5 minutes. Lay them on their side on the floor, nothing in the mouth, time it. Call 911 if it lasts over 5 minutes, is the first one, or they don’t wake up.",
                       "发热时抽搐（热性惊厥）看着吓人，但通常 5 分钟内停止。让孩子侧躺在地上，嘴里不塞任何东西，记录时间。超过 5 分钟、第一次发作或抽完叫不醒：拨打 120。",
                       set: ["mode": 5, "minutes": 2]),
            ],
            draw: { s, p, t in drawFever(&s, p, t, who) },
            sources: ["NICE NG143 Fever in under 5s (2019, updated 2021): traffic-light red flags; under 3 months ≥38 °C, 3–6 months ≥39 °C; fever 5 days or more; armpit thermometers; no tepid sponging; antipyretics for distress only, not both at once",
                      "NHS: High temperature (fever) in children — when to call 999 or 111; the glass test; no aspirin under 16",
                      "NHS: Febrile seizures — on their side, nothing in the mouth, time it; 999 if over 5 minutes or the first one",
                      "AAP HealthyChildren.org: Fever and your baby; fever ≥100.4 °F (38 °C) under 3 months needs a doctor; AAP 2021 febrile infant guideline",
                      "中华医学会儿科学分会：中国 0 至 5 岁儿童病因不明急性发热诊断和处理若干问题循证指南（2016）"],
            keywords: ["fever", "high temperature", "temperature", "thermometer", "febrile seizure", "fit", "rash", "glass test", "meningitis", "sepsis",
                       "paracetamol", "acetaminophen", "ibuprofen", "baby", "child", "发烧", "发热", "高烧", "体温", "体温计", "热性惊厥", "抽搐", "皮疹", "脑膜炎", "退烧药", "宝宝"]
        )
        s.profileNote = switch who.age {
        case .infant: Bilingual("Baby: under 3 months, 38 °C or more needs a doctor now — even if they seem well. No fever medicine under 3 months unless a doctor says.",
                                "婴儿：3 个月以下体温 ≥38 °C，即使看起来没事也要立即就医。3 个月以下未经医生同意不要用退烧药。")
        case .toddler, .child: Bilingual("Child: how they look and act matters more than the number. Playing and drinking when the fever dips is reassuring.",
                                         "儿童：精神状态比体温数字更重要。体温降下来时能玩、能喝，就比较让人放心。")
        default: nil
        }
        return s
    }

    /// the call-now signs, in icon order
    private static let feverFlags: [(en: String, zh: String)] = [
        ("Floppy, hard to wake, or a weak, high-pitched cry", "软弱无力、难以唤醒，或哭声微弱尖细"),
        ("Struggling to breathe: grunting, ribs sucking in", "呼吸困难：呻吟、肋间凹陷"),
        ("Blue, grey, pale or blotchy skin or lips", "皮肤或嘴唇发青、发灰、苍白或花斑"),
        ("A rash that doesn’t fade under a glass", "皮疹压玻璃杯不褪色"),
        ("A fit (seizure)", "抽搐（惊厥）"),
        ("Stiff neck, or hates bright light", "颈部僵硬，或怕光"),
    ]

    @MainActor private static func drawFever(_ s: inout Sketch, _ p: Params, _ t: Double, _ who: Profile) {
        let mode = p[v: "mode"]
        let panels: [@MainActor (inout Sketch) -> Void] = [
            { feverFlagsPanel(&$0, t, who) }, { glassTest(&$0, p) }, { ageRule(&$0, p) },
            { doctorToday(&$0) }, { homeCare(&$0, t, who) }, { feverFit(&$0, p, t, who) },
        ]
        for (i, draw) in panels.enumerated() {
            let w = panel(mode, i)
            if w > 0.01 { s.group(opacity: w) { g in draw(&g) } }
        }
    }

    /// small round symbol for each call-now sign
    @MainActor private static func flagIcon(_ s: inout Sketch, _ i: Int, at c: CGPoint, r: Double) {
        let col = Anat.red, k = r / 10
        s.circle(c.x, c.y, r, fill: hex("#FDECEC"), stroke: col, lw: 1.2)
        switch i {
        case 0:
            s.text("z", c.x - 2.5 * k, c.y + 4 * k, size: 9 * k, color: col, anchor: .middle, bold: true)
            s.text("z", c.x + 3 * k, c.y - 0.5 * k, size: 6.5 * k, color: col, anchor: .middle, bold: true)
        case 1:
            s.line(c.x, c.y - 6 * k, c.x, c.y - 1 * k, stroke: col, lw: 1.3, cap: .round)
            for side in [-1.0, 1.0] {
                s.path("M \(c.x + side * 1.2 * k) \(c.y - 2 * k) Q \(c.x + side * 6.5 * k) \(c.y - 4 * k) \(c.x + side * 5.5 * k) \(c.y + 4.5 * k) Q \(c.x + side * 2 * k) \(c.y + 6 * k) \(c.x + side * 1.2 * k) \(c.y + 2 * k) Z",
                       fill: col.opacity(0.85))
            }
        case 2:
            s.path("M \(c.x - 6 * k) \(c.y) Q \(c.x - 3 * k) \(c.y - 4 * k) \(c.x) \(c.y - 2 * k) Q \(c.x + 3 * k) \(c.y - 4 * k) \(c.x + 6 * k) \(c.y) Q \(c.x) \(c.y + 6 * k) \(c.x - 6 * k) \(c.y) Z",
                   fill: hex("#6C7FB8"))
        case 3:
            s.circle(c.x, c.y, 6 * k, fill: .white, stroke: hex("#8FB2C8"), lw: 1.1)
            for (dx, dy) in [(-2.4, -1.6), (2.2, -2.2), (0.2, 1.4), (-2.8, 2.6), (3, 2)] { s.circle(c.x + dx * k, c.y + dy * k, 1 * k, fill: hex("#8E2A4A")) }
        case 4:
            s.path("M \(c.x - 1 * k) \(c.y - 6.5 * k) L \(c.x - 4.5 * k) \(c.y + 1 * k) L \(c.x - 0.5 * k) \(c.y + 1 * k) L \(c.x - 2 * k) \(c.y + 6.5 * k) L \(c.x + 4.5 * k) \(c.y - 1.5 * k) L \(c.x + 0.5 * k) \(c.y - 1.5 * k) L \(c.x + 2 * k) \(c.y - 6.5 * k) Z",
                   fill: col)
        default:
            s.circle(c.x, c.y, 3 * k, fill: hex("#E0A21B"))
            for j in 0..<8 {
                let a = Double(j) / 8 * 2 * .pi
                s.line(c.x + cos(a) * 4.5 * k, c.y + sin(a) * 4.5 * k, c.x + cos(a) * 6.5 * k, c.y + sin(a) * 6.5 * k, stroke: hex("#E0A21B"), lw: 1.2, cap: .round)
            }
        }
    }

    // MARK: call-now signs

    @MainActor private static func feverFlagsPanel(_ s: inout Sketch, _ t: Double, _ who: Profile) {
        let o = CGPoint(x: 98, y: 134)
        var b = kidBust(who, h: 250)
        b.face = .worried
        let pulse = 0.5 + 0.5 * sin(t * 3)
        let hc = CGPoint(x: o.x + b.headCenter.x, y: o.y + b.headCenter.y)
        let (elbow, hand) = b.arm(1)
        let rashAt = lerp(CGPoint(x: o.x + elbow.x, y: o.y + elbow.y), CGPoint(x: o.x + hand.x, y: o.y + hand.y), 0.45)
        portrait(&s, b, at: o, between: { g in
            g.softGlow(hc, b.headRx * 1.6, b.headRy * 1.4, Anat.red, 0.22 + 0.1 * pulse)
        })
        rash(&s, rashAt, 9, dots: true, size: 0.6)
        let spots: [CGPoint] = [
            CGPoint(x: hc.x - b.headRx * 0.6, y: hc.y - b.headRy * 0.7), CGPoint(x: o.x + b.chest.x - 6, y: o.y + b.chest.y + 4),
            CGPoint(x: o.x + b.mouth.x, y: o.y + b.mouth.y), rashAt, CGPoint(x: o.x + b.shoulder(-1).x, y: o.y + b.shoulder(-1).y + 8),
            CGPoint(x: o.x + b.headRx * 0.45, y: o.y - 4),
        ]
        let icons: [CGPoint] = [CGPoint(x: 22, y: 44), CGPoint(x: 178, y: 156), CGPoint(x: 22, y: 150), CGPoint(x: 178, y: 258),
                                CGPoint(x: 22, y: 250), CGPoint(x: 178, y: 54)]
        for i in feverFlags.indices {
            s.line(spots[i].x, spots[i].y, icons[i].x, icons[i].y, stroke: Anat.red, lw: 0.8, dash: [2, 2], opacity: 0.7)
            s.circle(spots[i].x, spots[i].y, 1.8, fill: Anat.red)
            flagIcon(&s, i, at: icons[i], r: 11)
        }

        let px = 204.0, pw = 150.0
        s.stateChip("Call 911 now", "立即拨打 120", px + pw, 6, color: Anat.red, anchor: .end)
        s.card(px, 38, pw, 218, accent: Anat.red)
        for (i, f) in feverFlags.enumerated() {
            let y = 57 + Double(i) * 35
            flagIcon(&s, i, at: CGPoint(x: px + 20, y: y), r: 9)
            s.noteLeft(f.en, f.zh, px + 34, y, width: pw - 40, size: 8, color: Tone.ink, bold: true)
        }
        callBox(&s, px, 264, pw, 30, "At any temperature · day or night", "无论体温多少 · 不分昼夜")
    }

    // MARK: glass test

    @MainActor private static func glassTest(_ s: inout Sketch, _ p: Params) {
        let press = p[v: "press"].clamped(0, 1), shown = Anat.ease((press - 0.4) / 0.5)
        s.label("The glass test", "玻璃杯测试", 180, 18, size: 12, color: Tone.ink, anchor: .middle, bold: true)
        s.label("On darker skin, check paler places: palms, soles, tummy, inside the eyelids", "深色皮肤看颜色浅的地方：手掌、脚底、肚子、眼睑内侧",
                180, 33, size: 7.5, color: Tone.sub, anchor: .middle)
        for (i, dots) in [false, true].enumerated() {
            let x = 10 + Double(i) * 174, box = CGRect(x: x, y: 44, width: 166, height: 160)
            s.softCard(box.minX, box.minY, box.width, box.height)
            var skin = s.clipped(box.minX, box.minY, box.width, box.height)
            skin.rect(box.minX, box.minY, box.width, box.height, fill: hex("#F3D2B8"))
            let c = CGPoint(x: box.midX, y: box.midY + 4), R = 46.0
            // glass lifts off the skin and grows a shadow until pressed
            let lift = 1 - press, gc = CGPoint(x: c.x - 16 * lift, y: c.y - 20 * lift)
            rash(&skin, c, 72, dots: dots) { q in
                dots || hypot(q.x - gc.x, q.y - gc.y) > R ? 0 : 0.9 * press
            }
            skin.ellipse(gc.x + 10 * lift, gc.y + 14 * lift, R, R, fill: .black, opacity: 0.07 * lift)
            skin.circle(gc.x, gc.y, R * (1 + 0.08 * lift), fill: .white, opacity: 0.16 + 0.08 * press)
            skin.circle(gc.x, gc.y, R * (1 + 0.08 * lift), stroke: hex("#9DB8CC"), lw: 2.4)
            skin.circle(gc.x, gc.y, R * (1 + 0.08 * lift) - 5, stroke: hex("#C9DCE8"), lw: 0.9)
            skin.path("M \(gc.x - R * 0.62) \(gc.y - R * 0.38) A \(R * 0.74) \(R * 0.74) 0 0 1 \(gc.x - R * 0.1) \(gc.y - R * 0.72)",
                      stroke: .white, lw: 3, opacity: 0.8, cap: .round)
            let col = dots ? Anat.red : Anat.green
            s.group(opacity: 0.25 + 0.75 * shown) { g in
                g.pill(dots ? "Doesn’t fade" : "Fades", dots ? "不褪色" : "褪色", box.midX, 222, color: col, size: 10, anchor: .middle)
                g.cardNote(dots ? "Call 911 now" : "Usually a virus. Still see a doctor if they seem unwell.",
                           dots ? "立即拨打 120" : "多为病毒疹。精神差仍要看医生。",
                           box.midX, dots ? 250 : 254, width: 150, size: dots ? 11 : 8.5, color: dots ? Anat.red : Tone.ink, bold: true)
            }
        }
        s.label("Meningitis can start without any rash", "脑膜炎可以完全没有皮疹", 180, 290, size: 8, color: Anat.red, anchor: .middle, bold: true)
    }

    // MARK: age and temperature

    private static func feverVerdict(months: Double, temp: Double) -> (en: String, zh: String, color: Color) {
        if temp < 38 { return ("No fever", "未发热", Anat.green) }
        if months < 3 { return ("See a doctor now", "立即就医", Anat.red) }
        if months < 6 && temp >= 39 { return ("See a doctor today", "当天就医", Anat.amber) }
        return ("Watch how they are", "观察精神状态", Anat.blue)
    }

    @MainActor private static func ageRule(_ s: inout Sketch, _ p: Params) {
        let months = p[v: "months"], temp = p[v: "temp"]
        let v = feverVerdict(months: months, temp: temp)
        // thermometer, 35–42 °C
        let x = 40.0, top = 52.0, bottom = 236.0
        func y(_ c: Double) -> Double { bottom - (c.clamped(35, 42) - 35) / 7 * (bottom - top) }
        s.rect(x - 9, top - 10, 18, bottom - top + 22, r: 9, fill: .white, stroke: Tone.rule, lw: 1.2)
        s.circle(x, bottom + 22, 15, fill: .white, stroke: Tone.rule, lw: 1.2)
        let hot = temp >= 38 ? Anat.red : Anat.green
        s.rect(x - 4.5, y(temp), 9, bottom + 14 - y(temp), r: 4.5, fill: hot)
        s.circle(x, bottom + 22, 10.5, fill: hot)
        for c in 35...42 {
            let cy = y(Double(c))
            s.line(x + 10, cy, x + 16, cy, stroke: Tone.sub, lw: 0.8)
            s.text("\(c)", x + 19, cy + 3, size: 7.5, color: c == 38 ? Anat.red : Tone.sub, bold: c == 38)
        }
        s.line(x - 14, y(38), x + 14, y(38), stroke: Anat.red, lw: 1, dash: [3, 2])
        s.label("fever", "发热", x - 16, y(38) + 3, size: 7.5, color: Anat.red, anchor: .end, bold: true)
        s.text(String(format: "%.1f °C", temp), x, 20, size: 13, color: hot, anchor: .middle, bold: true)
        s.label(String(format: "age %.0f mo", months), String(format: "%.0f 个月", months), x, 34, size: 8, color: Tone.sub, anchor: .middle)

        // what to do by age
        let px = 92.0, pw = 262.0
        s.stateChip(v.en, v.zh, px + pw, 6, color: v.color, anchor: .end)
        let rows: [(String, String, String, String, Color, Bool)] = [
            ("Under 3 months", "3 个月以下", "38 °C or more → see a doctor now", "≥38 °C → 立即就医", Anat.red, months < 3),
            ("3 to 6 months", "3–6 个月", "39 °C or more → see a doctor today", "≥39 °C → 当天就医", Anat.amber, months >= 3 && months < 6),
            ("Over 6 months", "6 个月以上", "How they act matters more than the number", "精神状态比体温数字更重要", Anat.blue, months >= 6),
        ]
        for (i, r) in rows.enumerated() {
            let y0 = 40 + Double(i) * 62
            s.group(opacity: r.5 ? 1 : 0.45) { g in
                g.card(px, y0, pw, 54, accent: r.4)
                if r.5 { g.rect(px, y0, pw, 54, r: 12, stroke: r.4, lw: 1.6) }
                g.label(r.0, r.1, px + 14, y0 + 20, size: 10, color: r.4, bold: true)
                g.label(r.2, r.3, px + 14, y0 + 39, size: 9, color: Tone.ink, bold: r.5)
            }
        }
        s.card(px, 230, pw, 62)
        s.caption("How to measure", "怎么量", px + 12, 246)
        s.noteLeft("Digital thermometer in the armpit (in babies a rectal reading is most accurate). Never a glass mercury one.",
                   "腋下用电子体温计（婴儿测肛温最准）。不要用玻璃水银体温计。", px + 12, 270, width: pw - 24, size: 8.5, color: Tone.ink)
    }

    // MARK: see a doctor today

    @MainActor private static func doctorToday(_ s: inout Sketch) {
        s.stateChip("Call your doctor today", "当天联系医生", 354, 6, color: Anat.amber, anchor: .end)
        s.label("Not an emergency, but don’t wait", "不算急症，但别拖", 8, 22, size: 10, color: Tone.ink, bold: true)
        let tiles: [(String, String)] = [
            ("Fever for 5 days or more", "发热 5 天及以上"), ("Drinking much less, or fewer wet diapers", "喝得明显少，或尿布湿得少"),
            ("No tears, sunken eyes or soft spot", "哭时没眼泪、眼窝或囟门凹陷"), ("A rash along with the fever", "发热同时出皮疹"),
            ("Not their usual self, or not better with medicine", "和平时判若两人，或吃药也不见好"), ("You’re worried — trust your instinct", "你很担心——相信直觉"),
        ]
        for (i, tile) in tiles.enumerated() {
            let x = 8 + Double(i % 2) * 176, y = 40 + Double(i / 2) * 84
            s.card(x, y, 168, 76, accent: Anat.amber)
            let c = CGPoint(x: x + 26, y: y + 38)
            s.circle(c.x, c.y, 16, fill: hex("#FDF3E3"), stroke: Anat.amber, lw: 1.2)
            doctorIcon(&s, i, c)
            s.noteLeft(tile.0, tile.1, x + 50, y + 38, width: 110, size: 9, color: Tone.ink, bold: true)
        }
    }

    @MainActor private static func doctorIcon(_ s: inout Sketch, _ i: Int, _ c: CGPoint) {
        let col = Anat.amber
        switch i {
        case 0:
            s.rect(c.x - 9, c.y - 8, 18, 17, r: 3, fill: .white, stroke: col, lw: 1.2)
            s.rect(c.x - 9, c.y - 8, 18, 5, r: 2, fill: col)
            s.text("5", c.x, c.y + 7.5, size: 10, color: col, anchor: .middle, bold: true)
        case 1:
            s.path("M \(c.x) \(c.y - 10) Q \(c.x + 8) \(c.y + 1) \(c.x) \(c.y + 8) Q \(c.x - 8) \(c.y + 1) \(c.x) \(c.y - 10) Z", fill: Tone.blue.opacity(0.75))
        case 2:
            s.path("M \(c.x - 10) \(c.y - 2) Q \(c.x) \(c.y - 11) \(c.x + 10) \(c.y - 2) Q \(c.x) \(c.y + 7) \(c.x - 10) \(c.y - 2) Z", fill: .white, stroke: col, lw: 1.2)
            s.circle(c.x, c.y - 2, 3.4, fill: Tone.ink)
            s.path("M \(c.x + 4) \(c.y + 5) q 2 3 0 5 q -2 -2 0 -5 Z", fill: Tone.blue, opacity: 0.35)
        case 3:
            rash(&s, c, 10, dots: false, size: 0.4)
        case 4:
            s.circle(c.x, c.y, 10, fill: .white, stroke: col, lw: 1.2)
            s.circle(c.x - 3.5, c.y - 2, 1.3, fill: Tone.ink)
            s.circle(c.x + 3.5, c.y - 2, 1.3, fill: Tone.ink)
            s.path("M \(c.x - 4) \(c.y + 5) Q \(c.x) \(c.y + 2) \(c.x + 4) \(c.y + 5)", stroke: Tone.ink, lw: 1.2, cap: .round)
        default:
            s.heart(c.x, c.y + 1, 9, fill: col)
        }
    }

    // MARK: home care

    @MainActor private static func homeCare(_ s: inout Sketch, _ t: Double, _ who: Profile) {
        let o = CGPoint(x: 96, y: 134)
        var b = kidBust(who, h: 250)
        b.face = .calm
        let cupAt = CGPoint(x: b.mouth.x - b.headRx * 0.2, y: b.mouth.y + b.headRy * 0.5)
        b.rightHand = CGPoint(x: cupAt.x - 4, y: cupAt.y + 10)
        portrait(&s, b, at: o)
        let cup = CGPoint(x: o.x + cupAt.x, y: o.y + cupAt.y)
        s.path("M \(cup.x - 9) \(cup.y - 4) L \(cup.x + 9) \(cup.y - 4) L \(cup.x + 7) \(cup.y + 18) L \(cup.x - 7) \(cup.y + 18) Z", fill: hex("#CFE6F7"), stroke: hex("#7FA9CC"), lw: 1)
        s.path("M \(cup.x - 8) \(cup.y + 1) L \(cup.x + 8) \(cup.y + 1) L \(cup.x + 6.6) \(cup.y + 17) L \(cup.x - 6.6) \(cup.y + 17) Z", fill: Tone.blue.opacity(0.35))
        b.drawArms(&s, at: o)
        s.tag("small sips, often", "少量多次", 98, 262, size: 9, color: Tone.blue, bold: true)

        let px = 196.0, pw = 158.0
        let dos: [(String, String)] = [("Small drinks often (breast or formula milk for babies)", "少量多次喝水（婴儿继续喂母乳或奶粉）"),
                                       ("Light clothes, room not too hot", "穿得轻薄，室温别太高"),
                                       ("Check on them through the night", "夜里多看看"),
                                       ("Medicine if distressed, dose by weight", "难受时用药，按体重给量")]
        let donts: [(String, String)] = [("Cold baths or sponging", "冷水浴或擦身"), ("Bundling up to sweat it out", "捂汗"),
                                         ("Aspirin under 16", "16 岁以下用阿司匹林"), ("Two fever medicines at once", "两种退烧药同时吃")]
        s.card(px, 6, pw, 148, accent: Anat.green)
        s.caption("Do", "要", px + 14, 22, color: Anat.green)
        for (i, d) in dos.enumerated() {
            let y = 44 + Double(i) * 28
            mark(&s, CGPoint(x: px + 20, y: y), ok: true)
            s.noteLeft(d.0, d.1, px + 32, y, width: pw - 38, size: 8, color: Tone.ink)
        }
        s.card(px, 162, pw, 130, accent: Anat.red)
        s.caption("Don’t", "不要", px + 14, 178, color: Anat.red)
        for (i, d) in donts.enumerated() {
            let y = 198 + Double(i) * 24
            mark(&s, CGPoint(x: px + 20, y: y), ok: false)
            s.noteLeft(d.0, d.1, px + 32, y, width: pw - 38, size: 8, color: Tone.ink)
        }
    }

    // MARK: febrile seizure

    @MainActor private static func feverFit(_ s: inout Sketch, _ p: Params, _ t: Double, _ who: Profile) {
        let c = kid(who)
        let mat = CGRect(x: 8, y: 40, width: 186, height: 252)
        s.rect(mat.minX, mat.minY + 2, mat.width, mat.height, r: 12, fill: .black.opacity(0.06))
        s.rect(mat.minX, mat.minY, mat.width, mat.height, r: 12, fill: Palette.floor, stroke: Palette.floorEdge, lw: 1)
        s.label("Floor, seen from above", "地面俯视", mat.minX + 10, mat.minY + 16, size: 7.5, color: Tone.sub)
        // child on the side, curled a little; the shake is a tiny jitter
        let jitter = sin(t * 40) * 0.8
        var f = SideFigure(c, hip: CGPoint(x: 118 + jitter, y: 190), face: .closed)
        f.rotation = -84
        f.shadow = false
        f.headTilt = -6
        f.nearLeg = .init(hip: 50, knee: 70, point: 10)
        f.farLeg = .init(hip: 30, knee: 50, point: 10)
        f.near = .init(shoulder: 55, elbow: 100)
        f.far = .init(shoulder: 35, elbow: 90)
        f.draw(&s)
        let mouth = f.mouth
        s.callout("nothing in the mouth", "嘴里不塞东西", 84, 118, to: mouth, color: Anat.red, width: 130)
        // toys pushed out of the way
        s.rect(150, 240, 18, 18, r: 3, fill: hex("#F2B544"))
        s.rect(166, 252, 14, 14, r: 3, fill: hex("#7FB0E0"))
        s.pointer(CGPoint(x: 150, y: 236), CGPoint(x: 172, y: 222), color: Tone.sub, lw: 1.2)
        s.tag("on the side, away from hard things", "侧躺，远离硬物", 100, 278, size: 8.5, color: Tone.ink, bold: true)

        let px = 202.0, pw = 152.0, minutes = p[v: "minutes"]
        s.stateChip("Time it", "记录时间", px + pw, 6, color: Anat.purple, anchor: .end)
        s.card(px, 40, pw, 132)
        s.stopwatch(CGPoint(x: px + 26, y: 70), 15, minutes: minutes, color: Anat.purple)
        s.label("Most stop", "多数在", px + 50, 66, size: 8.5, color: Tone.sub)
        s.label("within 5 min", "5 分钟内停止", px + 50, 80, size: 10, color: Anat.purple, bold: true)
        let dos: [(String, String, Bool)] = [("Lay them on their side", "让孩子侧躺", true), ("Don’t hold them down", "不要按住", false),
                                             ("Nothing in the mouth", "嘴里不塞东西", false)]
        for (i, d) in dos.enumerated() {
            let y = 106 + Double(i) * 21
            mark(&s, CGPoint(x: px + 18, y: y), ok: d.2, r: 6.5)
            s.label(d.0, d.1, px + 30, y + 3, size: 8.5, color: Tone.ink)
        }
        s.rect(px, 180, pw, 112, r: 10, fill: hex("#FFF1F1"), stroke: Anat.red, lw: 1.2)
        s.label("Call 911 if", "以下情况拨打 120", px + pw / 2, 198, size: 10, color: Anat.red, anchor: .middle, bold: true)
        let reds: [(String, String)] = [("over 5 minutes", "超过 5 分钟"), ("it’s the first one", "第一次发作"),
                                        ("hard to breathe", "呼吸困难"), ("they don’t wake up after", "抽完叫不醒")]
        for (i, r) in reds.enumerated() {
            let y = 218 + Double(i) * 18
            s.circle(px + 14, y - 3, 2.2, fill: Anat.red)
            s.label(r.0, r.1, px + 22, y, size: 8.5, color: Tone.ink)
        }
    }
}
