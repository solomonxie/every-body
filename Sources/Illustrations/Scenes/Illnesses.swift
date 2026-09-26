import SwiftUI

extension Illustrations {
    static let coldFlu = Scenario(
        id: "cold-vs-flu", group: .illness, title: Bilingual("Cold vs flu", "感冒与流感"),
        params: ["flu": 0, "inside": 0, "elbow": 0, "kid": 0],
        steps: [
            .watch("Colds and flu spread in droplets: one sneeze sprays thousands of them 1–2 m, onto people, hands and door handles.",
                   "感冒和流感通过飞沫传播：一个喷嚏喷出成千上万飞沫，可达 1–2 米，落到人、手和门把手上。", set: ["flu": 0, "inside": 0, "elbow": 0]),
            .tryIt("Your turn: sneeze into a tissue or your elbow — not into the air or your hands.", "试一试：用纸巾或手肘挡住喷嚏——不要直接打，也不要用手捂。",
                   TryStep(mode: .compare(param: "elbow", options: [("Into the air 直接打", 0), ("Into the elbow 用肘挡", 1)]), success: { $0[v: "elbow"] > 0.5 },
                           ok: Bilingual("Most droplets stay in the sleeve. Wash hands often too.", "大部分飞沫留在袖子上。也要勤洗手。"), demo: ["elbow": 1])),
            .watch("Inside: a cold virus infects the lining of the nose and throat — runny nose, sore throat. It comes on slowly and stays mild.",
                   "在体内：感冒病毒感染鼻咽部黏膜——流涕、咽痛。起病缓慢，症状较轻。", set: ["inside": 1, "flu": 0]),
            .watch("Flu goes deeper, down the windpipe towards the lungs, and hits suddenly — high fever, aches, exhaustion.",
                   "流感侵入更深，沿气管到达肺部，起病急——高热、全身酸痛、极度乏力。", set: ["flu": 1]),
            .tryIt("Switch between them and watch the symptoms change.", "试一试：切换对比，观察症状变化。",
                   TryStep(mode: .compare(param: "flu", options: [("Cold 感冒", 0), ("Flu 流感", 1)]), success: { _ in true },
                           ok: Bilingual("Fever + aches + sudden start points to flu.", "发热 + 酸痛 + 起病急，提示流感。"))),
            .watch("Rest and fluids for both. Flu: antivirals work best within 48 h; yearly vaccine. See a doctor if breathless, chest pain, confused, or fever over 3 days.",
                   "两者均需休息、多饮水。流感：48 小时内用抗病毒药效果最好；每年接种疫苗。出现气促、胸痛、意识模糊或发热超过 3 天需就医。"),
        ],
        draw: { s, p, t in
            if p[v: "inside"] > 0.5 { drawAirwayInfection(&s, p, t) } else { drawSneeze(&s, p, t) }
        },
        sources: ["CDC “Cold versus flu”; WHO influenza fact sheet; WHO respiratory hygiene"]
    )

    static func coldFlu(for p: Profile) -> Scenario {
        var s = coldFlu
        switch p.age {
        case .infant:
            s.profileNote = Bilingual("Baby under 3 months with 38 °C or more: see a doctor now. Any baby: fast or hard breathing, not feeding, few wet nappies, very sleepy → urgent care.",
                                      "3 个月以下婴儿体温 ≥38 °C：立即就医。任何婴儿出现呼吸急促费力、拒奶、尿布很少湿、异常嗜睡 → 急诊。")
            return s.rebased(["kid": 1])
        case .child:
            s.profileNote = Bilingual("Children: never give aspirin. Dose paracetamol or ibuprofen by weight. Flu vaccine every year from 6 months.",
                                      "儿童：禁用阿司匹林。对乙酰氨基酚或布洛芬按体重给药。6 月龄起每年接种流感疫苗。")
            return s.rebased(["kid": 1])
        case .senior:
            s.profileNote = Bilingual("65+: flu can turn into pneumonia. Get the flu vaccine every autumn and see a doctor early for antivirals.",
                                      "65 岁以上：流感易并发肺炎。每年秋季接种流感疫苗，出现症状尽早就医用抗病毒药。")
        case .adult where p.isPregnant:
            s.profileNote = Bilingual("Pregnant: flu hits harder. The flu vaccine is safe in any trimester and protects the newborn. Paracetamol for fever.",
                                      "孕妇：流感更易重症。流感疫苗在孕期任何阶段都安全，还能保护新生儿。发热可用对乙酰氨基酚。")
        case .adult: break
        }
        return s
    }

    /// spiky virus particle
    @MainActor static func virus(_ s: inout Sketch, _ x: Double, _ y: Double, _ r: Double, opacity: Double = 1) {
        let c = hex("#7A3FA0")
        for i in 0..<8 {
            let a = Double(i) / 8 * 2 * .pi
            s.line(x + cos(a) * r, y + sin(a) * r, x + cos(a) * r * 1.6, y + sin(a) * r * 1.6, stroke: c, lw: 1, opacity: opacity)
        }
        s.circle(x, y, r, fill: c, opacity: opacity)
    }

    @MainActor private static func drawSneeze(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let elbow = p[v: "elbow"], floor = 268.0, h = 180.0
        let hip = CGPoint(x: 70, y: floor - 0.49 * h - 4)
        var sneezer = Person(h: h, lean: 14)
        if elbow > 0.5 { sneezer.shoulder = 107; sneezer.elbow = 137 } else { sneezer.shoulder = 8; sneezer.elbow = 12 }
        s.line(0, floor, 360, floor, stroke: hex("#BBBBBB"), lw: 2)
        // the other person, facing back
        let kid = p[v: "kid"] > 0.5, oh = kid ? 120.0 : 180.0
        s.group(translate: CGPoint(x: 300, y: floor - 0.49 * oh - 4)) { g in
            g.ctx.scaleBy(x: -1, y: 1)
            Person(h: oh, shirt: hex("#F2D48A"), shirtLine: hex("#C9A14F"), shoulder: 6, elbow: 10).draw(&g, at: .zero)
        }
        sneezer.draw(&s, at: hip)
        // mouth, after the lean
        let a = 14 * Double.pi / 180, m = CGPoint(x: 0.07 * h, y: -0.39 * h)
        let mouth = CGPoint(x: hip.x + m.x * cos(a) - m.y * sin(a), y: hip.y + m.x * sin(a) + m.y * cos(a))
        let reach = elbow > 0.5 ? 0.06 : 1.0, blue = hex("#3F95D6")
        for i in 0..<(elbow > 0.5 ? 8 : 60) {
            let u = (t * 0.5 + Double(i) * 0.137).wrap(1)
            let spread = (Double(i) * 0.618).wrap(1) - 0.45
            let x = mouth.x + 6 + u * 230 * reach, y = mouth.y + spread * u * 90 * reach + u * u * 40 * reach
            s.circle(x, y, 1.2 + Double(i % 3) * 0.7, fill: blue, opacity: 0.8 * (1 - u * 0.5))
            if i % 12 == 0 && elbow < 0.5 { virus(&s, x, y - 6, 2) }
        }
        if elbow < 0.5 {
            s.line(mouth.x + 10, floor + 10, 280, floor + 10, stroke: hex("#777777"), lw: 1)
            s.path("M \(mouth.x + 16) \(floor + 6) L \(mouth.x + 10) \(floor + 10) L \(mouth.x + 16) \(floor + 14) M 274 \(floor + 6) L 280 \(floor + 10) L 274 \(floor + 14)",
                   stroke: hex("#777777"), lw: 1)
            s.label("droplets fly 1–2 m", "飞沫可达 1–2 米", (mouth.x + 280) / 2, floor + 20, size: 10, color: hex("#555555"), anchor: .middle)
        } else {
            s.label("caught in the sleeve", "被袖子挡住", mouth.x + 30, mouth.y - 30, size: 10, color: hex("#2E9E5B"), bold: true)
        }
        s.label("Achoo!", "阿嚏！", mouth.x + 14, mouth.y - 50, size: 14, color: hex("#6C4F9E"), bold: true)
        s.rect(200, 8, 152, 36, r: 8, fill: .white, stroke: elbow > 0.5 ? hex("#2E9E5B") : hex("#D8434B"), lw: 2)
        s.label(elbow > 0.5 ? "elbow: few escape" : "open air: thousands", elbow > 0.5 ? "用肘挡：极少飞出" : "直接打：成千上万", 276, 23, size: 11,
                color: elbow > 0.5 ? hex("#2E9E5B") : hex("#D8434B"), anchor: .middle, bold: true)
        s.label("virus rides on droplets", "病毒附着在飞沫上", 276, 38, size: 9, color: hex("#555555"), anchor: .middle)
    }

    @MainActor private static func drawAirwayInfection(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let f = p[v: "flu"]
        let skin = hex("#F7E6DA"), air = hex("#E8B4A0"), sore = hex("#E0603C"), label = hex("#8A6A5A")
        // side view of head, neck and chest, facing right
        s.path("M 40 80 C 40 30 90 12 125 22 C 142 28 150 44 150 60 L 152 70 C 150 74 148 76 150 80 L 166 100 L 152 106 C 154 110 155 114 152 116 "
               + "C 155 120 154 124 150 126 C 150 134 146 140 136 142 C 124 144 118 146 116 156 L 116 196 C 130 206 170 214 176 240 L 176 296 L 26 296 "
               + "L 26 232 C 26 214 46 204 60 196 L 62 150 C 48 140 40 112 40 80 Z", fill: skin, stroke: hex("#C9A58A"), lw: 1.5)
        s.ellipse(72, 96, 7, 11, fill: skin, stroke: hex("#C9A58A"))
        s.circle(138, 72, 2.5, fill: hex("#4A4550"))
        s.path("M 36 60 C 40 24 96 6 138 30 C 128 36 100 36 84 44 C 66 52 52 70 44 96 Z", fill: hex("#6B5344"))
        // lungs behind the ribs
        s.ellipse(100, 262, 52, 40, fill: hex("#F2C4CC"), opacity: 0.85)
        // airway: nostril → nasal cavity → throat → voice box → windpipe → bronchi
        let noseSore = 0.6 + 0.4 * (1 - f), deepSore = f
        let airway = "M 158 102 C 140 92 116 88 100 94 C 90 98 88 108 92 120 L 96 150 L 100 168 L 102 228"
        s.path(airway, stroke: air, lw: 9, cap: .round)
        s.path("M 158 102 C 140 92 116 88 100 94 C 90 98 88 108 92 120 L 96 150", stroke: sore, lw: 9, opacity: 0.55 * noseSore, cap: .round)
        s.path("M 96 150 L 100 168 L 102 228 M 102 228 L 80 250 M 102 228 L 124 250", stroke: sore, lw: 7, opacity: 0.55 * deepSore, cap: .round)
        s.path("M 102 228 L 80 250 M 102 228 L 124 250", stroke: air, lw: 5, opacity: 1 - 0.55 * deepSore, cap: .round)
        for d in ["M 80 250 L 66 266 M 80 250 L 80 272", "M 124 250 L 138 266 M 124 250 L 124 274"] { s.path(d, stroke: air, lw: 2.5, cap: .round) }
        for (x, y) in [(128.0, 86.0), (118, 84), (108, 86)] { s.path("M \(x - 6) \(y) q 6 -5 12 0", stroke: hex("#D29A86"), lw: 1.5) }
        s.path("M 150 120 C 130 122 110 122 94 126", stroke: hex("#D29A86"), lw: 3, cap: .round)                          // mouth
        let spots: [(Double, Double, Double)] = [(140, 96, 0), (122, 92, 0), (104, 94, 0), (93, 112, 0), (95, 134, 0), (98, 160, 0.4), (101, 190, 0.5),
                                                 (102, 214, 0.6), (80, 256, 0.8), (124, 258, 0.85), (92, 276, 0.9)]
        for (i, spot) in spots.enumerated() where f >= spot.2 || spot.2 == 0 {
            virus(&s, spot.0 + sin(t * 2 + Double(i)) * 2, spot.1, 3, opacity: spot.2 == 0 ? 0.9 : min(1, (f - spot.2 + 0.2) * 3))
        }
        if f < 0.5 {
            for i in 0..<3 {
                let u = (t * 0.6 + Double(i) / 3).wrap(1)
                s.path("M 160 \(104 + u * 30) q 3 5 0 8 q -3 -3 0 -8 Z", fill: hex("#BFE0F2"), opacity: 1 - u)          // runny nose
            }
        }
        s.label("nose", "鼻腔", 150, 52, size: 8, color: label)
        s.label("throat", "咽", 56, 128, size: 8, color: label, anchor: .end)
        s.line(58, 126, 90, 130, stroke: label, lw: 0.6)
        s.label("windpipe", "气管", 56, 190, size: 8, color: label, anchor: .end)
        s.line(58, 188, 98, 190, stroke: label, lw: 0.6)
        s.label("lungs", "肺", 160, 262, size: 8, color: label)

        // symptoms and a thermometer
        let temp = 37.2 + 2.3 * f
        let symptoms: [(String, String, Double, Double)] = [("Fever", "发热", 0.1, 0.9), ("Aches", "肌肉酸痛", 0.15, 0.9), ("Exhaustion", "乏力", 0.25, 0.95),
                                                            ("Cough", "咳嗽", 0.4, 0.7), ("Runny nose", "流涕", 0.9, 0.3), ("Sore throat", "咽痛", 0.7, 0.4)]
        for (i, sym) in symptoms.enumerated() {
            let v = sym.2 + (sym.3 - sym.2) * f, y = 22 + Double(i) * 30
            s.label(sym.0, sym.1, 196, y, size: 10, color: hex("#555555"))
            if i == 0 { s.text(String(format: "%.1f °C", temp), 344, y, size: 10, color: temp >= 38 ? hex("#D8434B") : hex("#555555"), anchor: .end, bold: true) }
            s.rect(196, y + 5, 148, 9, r: 4.5, fill: hex("#EEEEEE"))
            s.rect(196, y + 5, 148 * v, 9, r: 4.5, fill: v > 0.6 ? hex("#D8434B") : hex("#E39B4B"))
        }
        s.label(f > 0.5 ? "Flu — sudden, whole body," : "Cold — gradual,", f > 0.5 ? "流感——起病急，全身症状，" : "感冒——起病缓慢，",
                196, 206, size: 10, color: hex("#6C4F9E"), bold: true)
        s.label(f > 0.5 ? "can reach the lungs" : "stays in nose & throat", f > 0.5 ? "可累及肺" : "局限于鼻咽", 196, 220, size: 10, color: hex("#6C4F9E"), bold: true)
        virus(&s, 202, 246, 3)
        s.label("virus", "病毒", 212, 250, size: 9, color: hex("#555555"))
        s.label("antibiotics don’t work on viruses", "抗生素对病毒无效", 196, 266, size: 9, color: hex("#555555"))
    }

    /// open airway radius (0..1): narrowed by inflammation + muscle squeeze, widened by the inhaler
    static func airway(_ p: Params) -> Double { max(0.25, 1 - 0.65 * p[v: "attack"] * (1 - 0.8 * p[v: "inhaler"])) }
    static func airflow(_ p: Params) -> Double { pow(airway(p), 4) }

    static let asthma = Scenario(
        id: "asthma", group: .illness, title: Bilingual("Asthma attack", "哮喘发作"),
        params: ["attack": 0, "inhaler": 0, "kid": 0],
        steps: [
            .watch("Deep in the lungs, small airways are ringed with muscle. Normally they're wide open and air flows easily.",
                   "肺内的小气道外包一圈平滑肌。正常时气道通畅，气流顺畅。", set: ["attack": 0, "inhaler": 0]),
            .watch("A trigger — cold air, pollen, smoke, a cold, exercise — sets off an attack: the muscle tightens, the lining swells, mucus builds. Wheeze, tight chest.",
                   "诱因——冷空气、花粉、烟雾、感冒、运动——引发发作：平滑肌收缩、黏膜水肿、痰液增多。喘鸣、胸闷。", set: ["attack": 1]),
            .tryIt("Use the blue reliever inhaler through a spacer: shake, 1 puff into the spacer, 4–6 slow breaths. Watch airflow: a little wider = a lot more air.",
                   "试一试：用蓝色缓解吸入剂接储雾罐：摇匀，按 1 喷进储雾罐，慢慢吸 4–6 口。气道稍宽，气流大增。",
                   TryStep(mode: .scrub([Scrub(param: "inhaler", label: "Inhaler 吸入剂", min: 0, max: 1)]), success: { airflow($0) > 0.5 },
                           ok: Bilingual("Breathing eases. If it doesn’t within minutes, call 120.", "呼吸缓解。几分钟内不缓解请拨打 120。"), demo: ["inhaler": 1])),
            .watch("Attack plan: sit upright, 1 puff every 30–60 s up to 10. Can’t speak in sentences or lips turn blue → 120.",
                   "发作处理：坐直，每 30–60 秒吸 1 喷，最多 10 喷。说话不成句或嘴唇发紫 → 拨打 120。", set: ["inhaler": 1]),
        ],
        draw: { s, p, t in drawAsthma(&s, p, t) },
        sources: ["GINA 2024 asthma strategy; Asthma + Lung UK attack plan; Poiseuille flow ∝ r⁴"]
    )

    static func asthma(for p: Profile) -> Scenario {
        var s = asthma
        switch p.age {
        case .infant:
            s.profileNote = Bilingual("Babies: wheeze under 1 is often bronchiolitis from a virus — see a doctor. Inhalers go through a spacer with a soft face mask.",
                                      "婴儿：1 岁内喘息多为病毒性毛细支气管炎——需就医。吸入药要用带软面罩的储雾罐。")
            return s.rebased(["kid": 1])
        case .child:
            s.profileNote = Bilingual("Children: always use a spacer; under about 5, one with a face mask held on for 5–6 breaths per puff.",
                                      "儿童：一定要用储雾罐；约 5 岁以下用带面罩的，每喷扣紧面罩呼吸 5–6 次。")
            return s.rebased(["kid": 1])
        case .senior:
            s.profileNote = Bilingual("65+: a spacer helps if pressing and breathing in together is hard. Asthma and COPD can overlap — review inhalers yearly.",
                                      "65 岁以上：按压与吸气难以同步时，储雾罐很有帮助。哮喘与慢阻肺可能并存——每年复查用药。")
        case .adult where p.isPregnant:
            s.profileNote = Bilingual("Pregnant: keep using your asthma inhalers — an uncontrolled attack is the bigger risk to the baby.",
                                      "孕妇：继续使用哮喘吸入药——发作失控对胎儿的风险更大。")
        case .adult: break
        }
        return s
    }

    @MainActor private static func drawAsthma(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let r = airway(p), flow = airflow(p), attack = p[v: "attack"], inh = p[v: "inhaler"], kid = p[v: "kid"] > 0.5
        let squeeze = attack * (1 - 0.8 * inh)
        let floor = 284.0, h = kid ? 150.0 : 200.0, ink = hex("#555555")
        let hip = CGPoint(x: 70, y: floor - 0.49 * h - 4)
        var person = Person(h: h, shirt: hex("#B7D3A8"), shirtLine: hex("#6E9E4F"), lean: 8 * attack)
        let a = person.lean * .pi / 180
        func leaned(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: hip.x + (x * cos(a) - y * sin(a)) * h, y: hip.y + (x * sin(a) + y * cos(a)) * h) }
        let mouth = leaned(0.075, -0.39)
        let using = inh > 0.2
        let spacerEnd = CGPoint(x: mouth.x + 0.17 * h, y: mouth.y + 2)
        if using {
            person.aimHand(at: CGPoint(x: spacerEnd.x - hip.x, y: spacerEnd.y - hip.y - 0.02 * h))
        } else if attack > 0.5 {
            person.aimHand(at: CGPoint(x: 0.07 * h, y: -0.22 * h))
        }
        s.line(0, floor, 190, floor, stroke: hex("#BBBBBB"), lw: 2)
        person.draw(&s, at: hip)
        // faint airway tree inside the chest, with a zoom to the cross-section
        let chest = leaned(0.01, -0.22)
        s.path("M \(chest.x) \(chest.y - 18) L \(chest.x) \(chest.y) M \(chest.x) \(chest.y) L \(chest.x - 8) \(chest.y + 12) M \(chest.x) \(chest.y) L \(chest.x + 8) \(chest.y + 12)",
               stroke: hex("#D8434B"), lw: 1.5, opacity: 0.6)
        s.circle(chest.x + 6, chest.y + 12, 6, stroke: ink, lw: 1)
        s.line(chest.x + 12, chest.y + 12, 200, 150, stroke: ink, lw: 0.8, dash: [3, 2])
        if using {
            // spacer: clear tube from the mouth, inhaler canister at the far end
            let tubeH = 0.09 * h
            if kid {
                s.path("M \(mouth.x - 2) \(mouth.y - 12) L \(mouth.x + 12) \(mouth.y - tubeH / 2) L \(mouth.x + 12) \(mouth.y + tubeH / 2) L \(mouth.x - 2) \(mouth.y + 10) Z",
                       fill: hex("#CFE3F2"), stroke: hex("#5F87B8"), lw: 1.5)
            } else {
                s.rect(mouth.x - 2, mouth.y - 3, 14, 6, r: 2, fill: hex("#CFE3F2"), stroke: hex("#5F87B8"))
            }
            s.rect(mouth.x + 10, mouth.y - tubeH / 2, spacerEnd.x - mouth.x - 10, tubeH, r: tubeH / 2, fill: hex("#E6F1FA"), stroke: hex("#5F87B8"), lw: 1.5)
            s.rect(spacerEnd.x - 2, mouth.y - tubeH / 2 - 0.1 * h, 9, 0.1 * h + 4, r: 2, fill: hex("#3F7FD6"))
            s.rect(spacerEnd.x - 3, mouth.y - 4, 10, 8, r: 2, fill: hex("#2E5FA8"))
            for i in 0..<Int((inh * 8).rounded()) {
                let u = (t * 0.7 + Double(i) / 8).wrap(1)
                s.circle(spacerEnd.x - u * (spacerEnd.x - mouth.x - 6), mouth.y + sin(Double(i) * 2.1) * tubeH * 0.3, 1.6, fill: hex("#7FB2E5"), opacity: 1 - u * 0.6)
            }
            s.label(kid ? "spacer + mask" : "spacer", kid ? "储雾罐+面罩" : "储雾罐", spacerEnd.x + 12, mouth.y + 10, size: 9, color: hex("#2E5FA8"), bold: true)
            s.label("reliever", "缓解剂", spacerEnd.x + 10, mouth.y - tubeH / 2 - 0.06 * h, size: 9, color: hex("#2E5FA8"))
        } else if squeeze > 0.4 {
            for i in 0..<3 {
                let u = (t * 1.5 + Double(i) / 3).wrap(1)
                s.path("M \(mouth.x + 8 + u * 30) \(mouth.y - 4) q 3 -4 6 0 t 6 0", stroke: hex("#D8434B"), lw: 1.5, opacity: 1 - u)
            }
            s.label("wheeze, tight chest", "喘鸣、胸闷", mouth.x + 10, mouth.y - 18, size: 10, color: hex("#D8434B"), bold: true)
        }

        // airway cross-section
        let c = CGPoint(x: 272, y: 150), R = 56.0
        let breath = (sin(t * (flow > 0.3 ? 1.6 : 3.2)) + 1) / 2
        s.circle(c.x, c.y, R + 16, fill: hex("#E8B4B8"))
        for i in 0..<12 {
            let ang = Double(i) / 12 * 2 * .pi
            let q = CGPoint(x: c.x + cos(ang) * (R + 6), y: c.y + sin(ang) * (R + 6))
            s.group(rotate: ang * 180 / .pi + 90, about: q) { g in g.rect(q.x - 5, q.y - 8, 10, 16, r: 2, fill: hex("#C1443C"), opacity: 0.3 + squeeze * 0.7) }
        }
        s.circle(c.x, c.y, R, fill: hex("#F2C9D0"))
        s.circle(c.x, c.y, R * r, fill: .white, stroke: hex("#E0A0AA"), lw: 2)
        if attack > 0.3 { s.path("M \(c.x - R * r) \(c.y) Q \(c.x) \(c.y + R * r * 0.5) \(c.x + R * r) \(c.y) Z", fill: hex("#F2E0A0"), opacity: 0.8 * squeeze + 0.2) }
        for i in 0..<5 { s.circle(c.x + Double(i - 2) * R * r * 0.3, c.y - R * r * 0.5 + breath * R * r, 3, fill: hex("#3F95D6"), opacity: flow) }
        s.label("muscle", "平滑肌", 352, c.y - R - 8, size: 9, color: hex("#C1443C"), anchor: .end)
        s.label("swollen lining", "黏膜水肿", c.x - R - 14, c.y + R + 16, size: 9, color: hex("#B77A85"))
        if attack > 0.3 { s.label("mucus", "痰", c.x, c.y + R * r * 0.22 + 3, size: 8, color: hex("#9A8A3B"), anchor: .middle) }
        s.label("small airway, cut across", "小气道横截面", c.x, 244, size: 9, color: hex("#8A3B45"), anchor: .middle, bold: true)
        let status = flow < 0.3 ? hex("#D8434B") : hex("#2E9E5B")
        s.rect(196, 6, 156, 52, r: 8, fill: .white, stroke: status, lw: 2)
        s.label("Airflow", "气流", 206, 24, size: 11, color: ink)
        s.text("\(Int((flow * 100).rounded()))%", 342, 30, size: 22, color: status, anchor: .end, bold: true)
        s.label("width \(Int((r * 100).rounded()))% → flow ∝ r⁴", "管径 \(Int((r * 100).rounded()))% → 气流 ∝ r⁴", 206, 48, size: 9, color: ink)
    }

    /// how high acid climbs the oesophagus (0..1)
    static func reflux(_ p: Params) -> Double { (p[v: "valveWeak"] * (0.3 + 0.7 * p[v: "lying"]) * (1 - 0.8 * p[v: "antacid"])).clamped(0, 1) }

    static let acidReflux = Scenario(
        id: "acid-reflux", group: .illness, title: Bilingual("Acid reflux & heartburn", "胃食管反流"),
        params: ["valveWeak": 0, "lying": 0, "antacid": 0, "pregnant": 0],
        steps: [
            .watch("After a meal the stomach churns food in strong acid. A ring of muscle where the gullet meets the stomach (the valve) keeps it down.",
                   "饭后胃用强酸搅拌食物。食管与胃连接处的一圈括约肌（贲门）把胃酸挡在胃里。", set: ["valveWeak": 0, "lying": 0, "antacid": 0]),
            .watch("When that valve relaxes too often, acid splashes up and burns the gullet — heartburn behind the breastbone.",
                   "括约肌经常松弛时，胃酸反流灼伤食管——胸骨后烧灼感（烧心）。", set: ["valveWeak": 1]),
            .watch("Lie down after a big meal and gravity stops helping — acid runs straight into the gullet (worst lying on the right side).",
                   "饱餐后躺下，重力不再帮忙——胃酸直接流进食管（右侧卧最重）。", set: ["lying": 1]),
            .tryIt("Compare: lying flat vs. the head of the bed raised on blocks.", "对比：平躺 vs. 床头垫高。",
                   TryStep(mode: .compare(param: "lying", options: [("Flat 平躺", 1), ("Raised 抬高", 0.3)]), success: { $0[v: "lying"] < 0.5 },
                           ok: Bilingual("Raise the head 15–20 cm, don’t eat 3 h before bed, smaller meals.", "床头抬高 15–20 厘米，睡前 3 小时不进食，少食多餐。"),
                           demo: ["lying": 0.3])),
            .watch("See a doctor if it’s weekly, food sticks, you lose weight or vomit blood.", "每周发作、吞咽梗阻、体重下降或呕血时应就医。", set: ["lying": 0.3]),
        ],
        draw: { s, p, t in drawReflux(&s, p, t) },
        sources: ["ACG 2022 GERD guideline"]
    )

    static func acidReflux(for p: Profile) -> Scenario {
        var s = acidReflux
        switch p.age {
        case .infant:
            s.profileNote = Bilingual("Babies often spit up after feeds — normal if they grow and seem happy. See a doctor for forceful or green vomit, blood, refusing feeds or poor weight gain.",
                                      "婴儿喂奶后吐奶很常见——生长良好、情绪好就正常。喷射性或绿色呕吐、带血、拒奶或体重不增要就医。")
        case .senior:
            s.profileNote = Bilingual("65+: new heartburn after 60, trouble swallowing or weight loss — get checked (endoscopy). Some medicines worsen reflux.",
                                      "65 岁以上：60 岁后新出现烧心、吞咽困难或消瘦——需做胃镜检查。部分药物会加重反流。")
        case .adult where p.isPregnant:
            s.profileNote = Bilingual("Pregnant: hormones relax the valve and the growing womb pushes on the stomach — heartburn is very common. Small meals; ask before antacids.",
                                      "孕妇：激素使括约肌松弛，增大的子宫挤压胃——烧心很常见。少食多餐；用抗酸药前先咨询医生。")
            return s.rebased(["pregnant": 1])
        case .child, .adult: break
        }
        return s
    }

    @MainActor private static func drawReflux(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let rf = reflux(p), lying = p[v: "lying"], weak = p[v: "valveWeak"] > 0.5
        let wall = hex("#F4D3C4"), edge = hex("#C98A7A"), acid = hex("#E3C23A"), label = hex("#8A6A5A"), ink = hex("#555555")
        let pose = lying > 0.65 ? 2 : lying > 0.15 ? 1 : 0
        let hurt = rf > 0.6

        // the person: upright after the meal, lying flat, or on a bed raised at the head
        if pose == 0 {
            var person = FacingPerson(h: 104, face: hurt ? .pain : .calm, legs: true)
            person.bump = p[v: "pregnant"] > 0.5
            person.rightHand = hurt ? CGPoint(x: 2, y: 0.12 * person.h) : nil
            s.line(20, 112, 200, 112, stroke: hex("#BBBBBB"), lw: 2)
            person.draw(&s, at: CGPoint(x: 70, y: 26))
            s.label("upright after eating", "饭后保持直立", 150, 62, size: 9, color: ink, anchor: .middle)
        } else {
            let tilt = pose == 1 ? 7.0 : 0
            s.group(rotate: tilt, about: CGPoint(x: 210, y: 98)) { g in
                g.rect(24, 92, 190, 12, r: 4, fill: hex("#DCE6F2"), stroke: hex("#9FB3CC"))
                g.rect(20, 76, 8, 36, r: 2, fill: hex("#B08A64"))
                g.rect(28, 80, 34, 12, r: 6, fill: .white, stroke: hex("#CCCCCC"))
                var person = FacingPerson(h: 132, face: hurt ? .pain : .calm, legs: true)
                person.rightHand = CGPoint(x: -0.11 * 132, y: 0.32 * 132)
                person.leftHand = CGPoint(x: 0.11 * 132, y: 0.32 * 132)
                person.bump = p[v: "pregnant"] > 0.5
                g.group(translate: CGPoint(x: 72, y: 92 - 0.115 * 132), rotate: -90, about: .zero) { q in person.draw(&q, at: .zero) }
            }
            if pose == 1 {
                s.rect(16, 89, 16, 23, r: 2, fill: hex("#8A6A4A"))
                s.label("blocks 15–20 cm", "垫高 15–20 厘米", 36, 112, size: 8, color: ink)
            }
            s.label(pose == 2 ? "lying down after a big meal" : "head of bed raised", pose == 2 ? "饱餐后躺下" : "床头抬高",
                    120, 20, size: 10, color: ink, anchor: .middle, bold: true)
        }

        // gullet and stomach, front view. Lying down, the acid pocket (fundus) sits right against the valve.
        let k = 0.72, pivot = CGPoint(x: 196, y: 214), center = CGPoint(x: -30, y: 50)
        func world(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: pivot.x + (x - center.x) * k, y: pivot.y + (y - center.y) * k) }
        let stomach = "M 11 2 C 43 -10 63 8 57 38 C 51 92 11 140 -47 134 C -79 130 -101 110 -107 88 L -123 86 L -123 74 L -103 74 "
            + "C -95 94 -79 106 -53 104 C -25 102 -13 74 -13 38 C -13 24 -13 12 -11 4 Z"
        // gravity in the picture: straight down upright, towards the fundus and valve when lying
        let lie = lying.clamped(0, 1), gx = 0.8 * lie, gy = 1 - 1.6 * lie
        let gl = hypot(gx, gy), g = CGPoint(x: gx / gl, y: gy / gl), n = CGPoint(x: -g.y, y: g.x)
        let outline: [(Double, Double)] = [(11, 2), (40, -4), (57, 38), (40, 100), (-47, 134), (-107, 88), (-13, 38), (0, 0)]
        let deepPoint = outline.max { $0.0 * g.x + $0.1 * g.y < $1.0 * g.x + $1.1 * g.y } ?? (0, 0)
        let deepest = deepPoint.0 * g.x + deepPoint.1 * g.y
        let d = deepest - 34 + sin(t * 2) * 1.5
        let base = CGPoint(x: g.x * d, y: g.y * d)
        var poly = Path()
        poly.addLines([CGPoint(x: base.x + n.x * 400, y: base.y + n.y * 400), CGPoint(x: base.x - n.x * 400, y: base.y - n.y * 400),
                       CGPoint(x: base.x - n.x * 400 + g.x * 400, y: base.y - n.y * 400 + g.y * 400), CGPoint(x: base.x + n.x * 400 + g.x * 400, y: base.y + n.y * 400 + g.y * 400)])
        poly.closeSubpath()
        s.group(translate: CGPoint(x: pivot.x - center.x * k, y: pivot.y - center.y * k), scale: k) { a in
            a.path("M -120 -14 C -80 -30 -34 -34 -14 -22 M 14 -22 C 34 -34 80 -30 120 -14", stroke: hex("#B8544C"), lw: 6, cap: .round)
            a.rect(-11, -90, 22, 96, r: 8, fill: wall, stroke: edge, lw: 2)
            a.path(stomach, fill: wall, stroke: edge, lw: 2)
            var pool = a
            pool.ctx.clip(to: SVGPath.parse(stomach))
            pool.shape(poly, fill: acid, opacity: 0.85)
            a.rect(-10, -4, 20, 8, fill: weak ? hex("#E39B4B") : hex("#8A3B45"))
            if rf > 0.02 { a.rect(-8, -2 - rf * 84, 16, rf * 84, fill: acid, opacity: 0.85) }
            if hurt { a.rect(-11, -90, 22, 86, r: 8, stroke: hex("#D8434B"), lw: 3, opacity: 0.4 + 0.3 * sin(t * 4)) }
        }
        let top = world(0, -90)
        s.label("diaphragm", "膈肌", world(-120, -14).x, world(-120, -14).y - 10, size: 8, color: hex("#B8544C"))
        let valve = world(0, 0), pooled = world(deepPoint.0 - g.x * 14 - 6, deepPoint.1 - g.y * 14), fundus = world(40, 20)
        s.label("gullet", "食管", top.x + 12, top.y + 12, size: 9, color: label, bold: true)
        s.line(valve.x - 8, valve.y, 120, valve.y + 8, stroke: label, lw: 0.6)
        s.label("valve (LES)", "贲门括约肌", 118, valve.y + 12, size: 9, color: label, anchor: .end, bold: true)
        s.label("acid", "胃酸", pooled.x, pooled.y + 3, size: 9, color: hex("#9A8A1B"), anchor: .middle, bold: true)
        s.label("fundus", "胃底", fundus.x + 22, fundus.y - 14, size: 8, color: label)
        let status = hurt ? hex("#D8434B") : rf > 0.25 ? hex("#E39B4B") : hex("#2E9E5B")
        s.rect(236, 6, 116, 44, r: 8, fill: .white, stroke: status, lw: 2)
        s.label("Reflux \(Int((rf * 100).rounded()))%", "反流 \(Int((rf * 100).rounded()))%", 246, 25, size: 12, color: status, bold: true)
        s.label(hurt ? "heartburn" : rf > 0.25 ? "mild burning" : "comfortable", hurt ? "烧心" : rf > 0.25 ? "轻微烧灼" : "无不适", 246, 41, size: 10, color: ink)
    }
}
