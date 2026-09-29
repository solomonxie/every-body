import SwiftUI

extension Illustrations {
    static let coldFlu = Scenario(
        id: "cold-vs-flu", group: .illness, title: Bilingual("Cold vs flu", "感冒与流感"),
        params: ["flu": 0, "inside": 0, "elbow": 0, "kid": 0, "care": 0],
        steps: [
            .watch("Colds and flu spread in droplets: one sneeze sprays thousands of them 1–2 m, onto people, hands and door handles.",
                   "感冒和流感通过飞沫传播：一个喷嚏喷出成千上万飞沫，可达 1–2 米，落到人、手和门把手上。", set: ["flu": 0, "inside": 0, "elbow": 0, "care": 0]),
            .tryIt("Your turn: sneeze into a tissue or your elbow — not into the air or your hands.", "试一试：用纸巾或手肘挡住喷嚏——不要直接打，也不要用手捂。",
                   TryStep(mode: .compare(param: "elbow", options: [("Into the air 直接打", 0), ("Into the elbow 用肘挡", 1)]), success: { $0[v: "elbow"] > 0.5 },
                           ok: Bilingual("Most droplets stay in the sleeve. Wash hands often too.", "大部分飞沫留在袖子上。也要勤洗手。"), demo: ["elbow": 1])),
            .watch("Inside: a cold virus infects the lining of the nose and throat — runny nose, sore throat. It comes on slowly and stays mild.",
                   "在体内：感冒病毒感染鼻咽部黏膜——流涕、咽痛。起病缓慢，症状较轻。", set: ["inside": 1, "flu": 0]),
            .watch("Flu goes deeper, down the windpipe toward the lungs, and hits suddenly — high fever, aches, exhaustion.",
                   "流感侵入更深，沿气管到达肺部，起病急——高热、全身酸痛、极度乏力。", set: ["flu": 1]),
            .tryIt("Switch between them and watch the symptoms change.", "试一试：切换对比，观察症状变化。",
                   TryStep(mode: .compare(param: "flu", options: [("Cold 感冒", 0), ("Flu 流感", 1)]), success: { _ in true },
                           ok: Bilingual("Fever + aches + sudden start points to flu.", "发热 + 酸痛 + 起病急，提示流感。"))),
            .watch("Rest and fluids for both. Flu: antivirals work best within 48 h; yearly vaccine. See a doctor if breathless, chest pain, confused, or fever over 3 days.",
                   "两者均需休息、多饮水。流感：48 小时内用抗病毒药效果最好；每年接种疫苗。出现气促、胸痛、意识模糊或发热超过 3 天需就医。",
                   set: ["care": 1]),
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
            s.profileNote = Bilingual("Baby under 3 months with 38 °C or more: see a doctor now. Any baby: fast or hard breathing, not feeding, few wet diapers, very sleepy → urgent care.",
                                      "3 个月以下婴儿体温 ≥38 °C：立即就医。任何婴儿出现呼吸急促费力、拒奶、尿布很少湿、异常嗜睡 → 急诊。")
            return s.rebased(["kid": 1])
        case .toddler, .child:
            s.profileNote = Bilingual("Children: never give aspirin. Dose acetaminophen or ibuprofen by weight. Flu vaccine every year from 6 months.",
                                      "儿童：禁用阿司匹林。对乙酰氨基酚或布洛芬按体重给药。6 月龄起每年接种流感疫苗。")
            return s.rebased(["kid": 1])
        case .senior:
            s.profileNote = Bilingual("65+: flu can turn into pneumonia. Get the flu vaccine every fall and see a doctor early for antivirals.",
                                      "65 岁以上：流感易并发肺炎。每年秋季接种流感疫苗，出现症状尽早就医用抗病毒药。")
        case .adult where p.isPregnant:
            s.profileNote = Bilingual("Pregnant: flu hits harder. The flu vaccine is safe in any trimester and protects the newborn. Acetaminophen for fever.",
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
            s.line(x + cos(a) * r, y + sin(a) * r, x + cos(a) * r * 1.55, y + sin(a) * r * 1.55, stroke: c, lw: 0.9, opacity: opacity)
            s.circle(x + cos(a) * r * 1.6, y + sin(a) * r * 1.6, r * 0.22, fill: c, opacity: opacity)
        }
        s.circle(x, y, r, fill: hex("#9A5CC0"), stroke: c, lw: 0.8, opacity: opacity)
    }

    @MainActor private static func drawSneeze(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let elbow = p[v: "elbow"] > 0.5, floor = 258.0
        s.room(floor: floor)
        if !elbow {
            // the spray plume
            let a = CGPoint(x: 112, y: 106)
            var plume = Path()
            plume.move(to: a)
            plume.addQuadCurve(to: CGPoint(x: 320, y: 50), control: CGPoint(x: 200, y: 60))
            plume.addQuadCurve(to: CGPoint(x: 320, y: 220), control: CGPoint(x: 360, y: 140))
            plume.addQuadCurve(to: a, control: CGPoint(x: 200, y: 150))
            s.ctx.fill(plume, with: .radialGradient(Gradient(colors: [hex("#3F95D6").opacity(0.2), hex("#3F95D6").opacity(0)]), center: a, startRadius: 0, endRadius: 210))
        }
        // the other person, facing back
        let other = p[v: "kid"] > 0.5 ? Casualty(Profile(age: .child), adult: 176) : Casualty(Profile.standard, adult: 172, adultLook: .helper)
        var o = SideFigure(other, facing: -1)
        o.nearLeg = .init(hip: 11, knee: 20)
        o.farLeg = .init(hip: -4, knee: 1)
        o.near = .init(shoulder: 6, elbow: 12)
        o.far = .init(shoulder: -4, elbow: 10)
        o.hip = CGPoint(x: 302, y: o.hipY(onFloor: floor))
        o.draw(&s)
        // the sneezer, jerking forward
        var v = SideFigure(Casualty(Profile.standard, adult: 180), lean: elbow ? 20 : 12, face: elbow ? .closed : .distress)
        v.headTilt = elbow ? 14 : 4
        v.nearLeg = .init(hip: 10, knee: 14)
        v.farLeg = .init(hip: -8, knee: 4)
        v.hip = CGPoint(x: 70, y: v.hipY(onFloor: floor))
        v.far = .init(shoulder: -8, elbow: 16)
        let mouth = v.mouth
        if elbow {
            // elbow crook in front of the mouth, forearm across the face to the far side
            let sh = v.shoulderPoint, U = v.build.upperArm * v.h, dy = mouth.y + 1 - sh.y
            let e = CGPoint(x: sh.x + max(0, U * U - dy * dy).squareRoot(), y: sh.y + dy), c = v.torso(-0.2, 1.0)
            let up = atan2(e.x - sh.x, e.y - sh.y) * 180 / .pi, fore = atan2(c.x - e.x, c.y - e.y) * 180 / .pi
            v.near = .init(shoulder: up - v.lean, elbow: (fore - up + 540).truncatingRemainder(dividingBy: 360) - 180, hand: .fist)
            v.drawBack(&s)
            // the fist ends up on the far side of the head: clip it so it can't peek out behind the neck
            var arm = s
            arm.ctx.clip(to: Path(CGRect(x: v.headCentre.x - v.headR * 0.2, y: 0, width: 400, height: 400)))
            v.drawArm(&arm, near: true)
            v.drawBody(&s)
            let e2 = v.elbow()
            s.limb([lerp(sh, e2, 0.3), e2, lerp(e2, v.palm(), 0.3)], w: v.build.armW * v.h, fill: v.look.top, line: v.look.topLine)
        } else {
            v.near = .init(shoulder: -4, elbow: 22)
            v.draw(&s)
        }
        let reach = elbow ? 0.06 : 1.0, blue = hex("#3F95D6")
        for i in 0..<(elbow ? 8 : 64) {
            let u = (t * 0.5 + Double(i) * 0.137).wrap(1)
            let spread = (Double(i) * 0.618).wrap(1) - 0.45
            let x = mouth.x + 8 + u * 220 * reach, y = mouth.y + spread * u * 90 * reach + u * u * 40 * reach
            let r = 1.1 + Double(i % 3) * 0.7
            s.circle(x, y, r, fill: blue, opacity: 0.75 * (1 - u * 0.5))
            if r > 2 { s.circle(x - r * 0.3, y - r * 0.3, r * 0.35, fill: .white, opacity: 0.6 * (1 - u * 0.5)) }
            if i % 12 == 0 && !elbow && x < 282 { virus(&s, x, y - 6, 2) }
        }
        if !elbow {
            let a = mouth.x + 10, b = 292.0, y = floor + 16
            s.line(a, y, b, y, stroke: hex("#8A7A66"), lw: 1)
            s.path("M \(a + 6) \(y - 4) L \(a) \(y) L \(a + 6) \(y + 4) M \(b - 6) \(y - 4) L \(b) \(y) L \(b - 6) \(y + 4)", stroke: hex("#8A7A66"), lw: 1)
            s.tag("droplets fly 1–2 m", "飞沫可达 1–2 米", (a + b) / 2, y + 12, size: 9.5, color: Tone.ink, bold: true)
        } else {
            s.tag("caught in the sleeve", "被袖子挡住", mouth.x + 80, mouth.y - 14, size: 9.5, color: Tone.green, bold: true)
        }
        s.label("Achoo!", "阿嚏！", mouth.x + 8, mouth.y - 38, size: 13, color: Tone.purple, bold: true)
        let ok = elbow ? Tone.green : Tone.red
        s.card(196, 8, 156, 44, accent: ok)
        s.label(elbow ? "Elbow: few escape" : "Open air: thousands", elbow ? "用肘挡：极少飞出" : "直接打：成千上万", 206, 25, size: 10.5, color: ok, bold: true)
        s.label("the virus rides on droplets", "病毒附着在飞沫上", 206, 41, size: 8, color: Tone.sub)
        virus(&s, 338, 38, 3)
    }

    @MainActor private static func drawAirwayInfection(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let f = p[v: "flu"]
        s.card(8, 6, 180, 290, fill: hex("#FBF7F3"))
        s.caption("Nose, throat and lungs, side cut", "鼻、咽、肺 · 侧面剖面", 16, 19)
        var g = s.clipped(8, 6, 180, 290)
        g.group(translate: CGPoint(x: 6, y: 16), scale: 0.93) { a in airwaySection(&a, flu: f, t: t) }
        func at(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: 6 + x * 0.93, y: 16 + y * 0.93) }
        s.callout("nose", "鼻腔", at: at(140, 98), 150, at(140, 98).y - 34, anchor: .start, color: Tone.label, size: 8)
        s.callout("throat", "咽", at: at(92, 138), 16, at(92, 138).y + 4, color: Tone.label, size: 8)
        s.callout("windpipe", "气管", at: at(108, 206), 16, at(108, 206).y + 4, color: Tone.label, size: 8)
        s.label("lungs", "肺", at(160, 290).x, at(160, 290).y, size: 8, color: Tone.label, anchor: .middle, bold: true)

        // symptoms: thermometer and bars
        let temp = 37.2 + 2.3 * f
        s.card(196, 6, 156, 290)
        s.caption(f > 0.5 ? "Flu" : "Cold", f > 0.5 ? "流感" : "感冒", 206, 20, color: Tone.purple)
        s.pill(f > 0.5 ? "sudden, within hours" : "gradual, over days", f > 0.5 ? "起病急，数小时内" : "起病缓，数天内", 232, 16.5, color: Tone.purple, size: 7, filled: false)
        // thermometer
        let tx = 212.0, ty0 = 34.0, ty1 = 74.0
        s.rect(tx - 4, ty0, 8, ty1 - ty0, r: 4, fill: .white, stroke: Tone.faint, lw: 1)
        s.circle(tx, ty1 + 3, 6.5, fill: temp >= 38 ? Tone.red : Tone.amber, stroke: Tone.faint, lw: 1)
        let lvl = ((temp - 36) / 4).clamped(0, 1)
        s.rect(tx - 1.8, ty1 - (ty1 - ty0 - 4) * lvl, 3.6, (ty1 - ty0 - 4) * lvl + 4, r: 1.8, fill: temp >= 38 ? Tone.red : Tone.amber)
        s.text(String(format: "%.1f °C", temp), 226, 56, size: 17, color: temp >= 38 ? Tone.red : Tone.ink, bold: true)
        s.label(temp >= 38 ? "fever" : "normal or slight", temp >= 38 ? "发热" : "正常或低热", 226, 70, size: 8, color: Tone.sub)
        let symptoms: [(String, String, Double, Double)] = [("Aches", "全身酸痛", 0.15, 0.9), ("Exhaustion", "极度乏力", 0.25, 0.95), ("Cough", "咳嗽", 0.4, 0.7),
                                                            ("Runny, stuffy nose", "流涕、鼻塞", 0.9, 0.3), ("Sore throat", "咽痛", 0.7, 0.4), ("Sneezing", "打喷嚏", 0.8, 0.25)]
        for (i, sym) in symptoms.enumerated() {
            let v = sym.2 + (sym.3 - sym.2) * f, y = 104 + Double(i) * 26
            s.label(sym.0, sym.1, 206, y, size: 8.5, color: Tone.ink)
            s.text(v > 0.6 ? s.t("strong", "明显") : v > 0.3 ? s.t("some", "轻度") : s.t("rare", "少见"), 342, y, size: 7, color: Tone.sub, anchor: .end)
            s.meterBar(206, y + 5, 136, v, color: v > 0.6 ? Tone.red : v > 0.3 ? Tone.amber : hex("#C9C2B8"), h: 6)
        }
        let care = p[v: "care"] > 0.5
        s.line(206, 252, 342, 252, stroke: Tone.rule, lw: 0.8)
        if care {
            s.label("✓ rest · fluids · acetaminophen", "✓ 休息 · 多饮水 · 退热药", 206, 266, size: 8, color: Tone.green, bold: true)
            s.label("flu: antivirals within 48 h", "流感：48 小时内用抗病毒药", 206, 280, size: 8, color: Tone.purple, bold: true)
        } else {
            virus(&s, 211, 264, 3)
            s.label("virus", "病毒", 220, 267, size: 8, color: Tone.sub)
            s.label("antibiotics don’t work on viruses", "抗生素对病毒无效", 206, 283, size: 8, color: Tone.sub)
        }
    }

    /// Head, neck and chest cut down the middle, facing right: nasal cavity, throat, voice box, windpipe, lungs. Frame ≈ 0…185 × 0…300.
    @MainActor static func airwaySection(_ s: inout Sketch, flu f: Double, t: Double) {
        let skin = hex("#F6DECF"), skinLine = hex("#C99A7A"), mucosa = hex("#F2B7AE"), mucosaLo = hex("#D98A80")
        let bone = hex("#EDE3CF"), boneLine = hex("#C8B48E"), sore = hex("#E0503C")
        let outline = "M 36 92 C 30 50 60 18 104 16 C 140 14 160 32 162 58 L 164 74 C 166 82 172 92 176 104 C 178 110 172 114 166 114 "
            + "C 166 118 168 122 166 126 L 160 130 C 166 134 166 140 162 144 C 164 152 160 160 150 162 C 140 164 134 170 132 178 L 130 214 "
            + "C 150 222 176 234 180 262 L 182 320 L 18 320 L 18 250 C 20 228 42 216 56 210 L 60 160 C 46 140 38 118 36 92 Z"
        s.shade(outline, skin, dim(skin, 0.94), stroke: skinLine, lw: 1.3, vertical: true)
        // skull and brain
        s.path("M 48 92 C 44 54 70 28 106 26 C 138 26 154 44 154 66 L 152 80 C 122 84 92 88 72 100 C 60 106 50 102 48 92 Z", fill: hex("#EFE0E2"), stroke: boneLine, lw: 2)
        for d in ["M 64 60 C 74 52 84 62 94 54", "M 100 44 C 110 38 120 48 132 42", "M 70 82 C 82 74 92 84 104 78", "M 112 64 C 122 58 132 68 144 62"] {
            s.path(d, stroke: hex("#DCC4C8"), lw: 1)
        }
        // spine
        for i in 0..<12 {
            let y = 112 + Double(i) * 17
            s.rect(62 - Double(i) * 0.4, y, 14, 13, r: 3, fill: bone, stroke: boneLine, lw: 0.8)
        }
        // lungs and bronchial tree
        let lungs = "M 70 238 C 72 226 90 222 106 226 C 122 222 150 224 160 238 C 170 256 174 290 176 320 L 66 320 C 64 290 66 256 70 238 Z"
        s.shade(lungs, hex("#F8D3D8"), hex("#EDB1BA"), stroke: hex("#D494A0"), lw: 1)
        for i in 0..<26 {
            let x = 74 + (Double(i) * 37).wrap(96), y = 246 + (Double(i) * 13).wrap(52)
            s.circle(x, y, 2.2, stroke: hex("#E3A1AC"), lw: 0.6)
        }
        // oesophagus behind the windpipe
        s.path("M 84 166 L 84 320 M 98 172 L 98 320", stroke: hex("#E8C1B6"), lw: 1.2)
        s.rect(85, 168, 12, 152, fill: hex("#F5D6CC"))
        // nasal cavity with turbinates, throat
        let nose = "M 100 84 C 120 80 150 82 166 98 L 168 110 C 150 112 124 112 102 112 Z"
        s.shade(nose, mucosa, mucosaLo)
        for (y, l) in [(90.0, 34.0), (98, 40), (106, 44)] {
            s.path("M 106 \(y) C 118 \(y - 3) \(106 + l * 0.7) \(y - 2) \(106 + l) \(y + 2)", stroke: hex("#E3998E"), lw: 3.2, cap: .round)
        }
        let throat = "M 88 94 C 84 112 84 142 86 170 L 100 170 C 98 152 98 132 102 118 L 104 96 Z"
        s.shade(throat, mucosa, mucosaLo)
        s.path("M 104 114 L 162 116", stroke: bone, lw: 3.2, cap: .round)                          // hard palate
        s.path("M 104 114 C 98 118 96 124 98 130", stroke: hex("#E08E86"), lw: 4, cap: .round)     // soft palate
        s.path("M 104 128 C 112 118 140 118 156 124 C 162 132 154 146 140 150 C 124 154 108 150 102 140 Z", fill: hex("#E48E8E"), stroke: hex("#C87070"), lw: 0.8)
        s.path("M 100 150 C 104 152 108 156 106 164", stroke: hex("#E3998E"), lw: 3, cap: .round) // epiglottis
        // voice box and windpipe with its rings
        s.rect(100, 162, 16, 24, r: 4, fill: mucosa, stroke: hex("#D9A08A"), lw: 1)
        s.path("M 102 174 L 114 172 M 102 177 L 114 175", stroke: hex("#C87A70"), lw: 0.8)
        s.rect(101, 186, 14, 52, fill: mucosa)
        for i in 0..<9 { s.line(100, 189 + Double(i) * 5.6, 116, 189 + Double(i) * 5.6, stroke: hex("#EEDFD0"), lw: 2.2) }
        let bronchi = "M 108 236 C 100 244 92 252 84 262 M 108 236 C 118 244 128 252 140 262 M 84 262 L 76 280 M 84 262 L 92 284 M 140 262 L 132 284 M 140 262 L 152 280"
        s.path(bronchi, stroke: hex("#EAC0B6"), lw: 5, cap: .round)
        s.path(bronchi, stroke: mucosa, lw: 3, cap: .round)
        // inflamed lining: nose and throat for a cold, windpipe and lungs for flu
        let hot = 0.45 + 0.1 * sin(t * 3)
        s.path("M 104 92 C 120 88 150 90 164 104", stroke: sore, lw: 6, opacity: hot * (0.9 - 0.4 * f), cap: .round)
        s.path("M 94 100 C 90 120 90 146 93 168", stroke: sore, lw: 7, opacity: hot * (0.9 - 0.3 * f), cap: .round)
        if f > 0.05 {
            s.path("M 108 188 L 108 236", stroke: sore, lw: 9, opacity: hot * f, cap: .round)
            s.path(bronchi, stroke: sore, lw: 5, opacity: hot * f, cap: .round)
            s.glow(114, 280, 44, sore, opacity: 0.35 * f)
        }
        // viruses where they attach
        let spots: [(Double, Double, Double)] = [(146, 96, 0), (126, 92, 0), (112, 100, 0), (94, 112, 0), (92, 136, 0), (94, 158, 0),
                                                 (108, 196, 0.4), (108, 220, 0.5), (90, 256, 0.7), (132, 258, 0.75), (96, 286, 0.85), (140, 290, 0.9)]
        for (i, sp) in spots.enumerated() where sp.2 == 0 || f >= sp.2 - 0.2 {
            let o = sp.2 == 0 ? 1 : min(1, (f - sp.2 + 0.2) * 4)
            virus(&s, sp.0 + sin(t * 2 + Double(i)) * 1.2, sp.1, 2.6, opacity: o)
        }
        // runny nose
        if f < 0.6 {
            for i in 0..<3 {
                let u = (t * 0.6 + Double(i) / 3).wrap(1)
                s.path("M 168 \(116 + u * 26) q 3 5 0 8 q -3 -3 0 -8 Z", fill: hex("#BFE0F2"), stroke: hex("#8CC4EC"), lw: 0.5, opacity: (1 - u) * (1 - f))
            }
        }
    }

    /// open airway radius (0..1): narrowed by muscle squeeze and swelling, widened by the reliever inhaler
    static func airway(_ p: Params) -> Double { max(0.25, 1 - 0.65 * p[v: "attack"] * (1 - p[v: "inhaler"])) }
    /// peak expiratory flow, % of personal best
    static func peakFlow(_ p: Params) -> Double { 100 * (0.2 + 0.8 * pow(airway(p), 2)) }

    static let asthma = Scenario(
        id: "asthma", group: .illness, title: Bilingual("Asthma attack", "哮喘发作"),
        params: ["attack": 0, "inhaler": 0, "kid": 0],
        steps: [
            .watch("Deep in the lungs, small airways are ringed with muscle. Normally they're wide open: a peak-flow meter reads near your personal best.",
                   "肺内的小气道外包一圈平滑肌。正常时气道通畅：峰流速仪读数接近个人最佳值。", set: ["attack": 0, "inhaler": 0]),
            .watch("A trigger — cold air, pollen, smoke, a cold, exercise — sets off an attack: the muscle tightens, the lining swells, mucus builds. Wheeze, tight chest.",
                   "诱因——冷空气、花粉、烟雾、感冒、运动——引发发作：平滑肌收缩、黏膜水肿、痰液增多。喘鸣、胸闷。", set: ["attack": 1]),
            .tryIt("Use the blue reliever inhaler through a spacer: shake, 1 puff into the spacer, 4–6 slow breaths. Get peak flow back into the green zone.",
                   "试一试：用蓝色缓解吸入剂接储雾罐：摇匀，按 1 喷进储雾罐，慢慢吸 4–6 口。让峰流速回到绿区。",
                   TryStep(mode: .scrub([Scrub(param: "inhaler", label: "Inhaler 吸入剂", min: 0, max: 1)]), success: { peakFlow($0) >= 80 },
                           ok: Bilingual("Breathing eases. If it doesn’t within minutes, call 911.", "呼吸缓解。几分钟内不缓解请拨打 120。"), demo: ["inhaler": 1])),
            .watch("Attack plan: sit upright, 1 puff every 30–60 s up to 10. Can’t speak in sentences or lips turn blue → 911.",
                   "发作处理：坐直，每 30–60 秒吸 1 喷，最多 10 喷。说话不成句或嘴唇发紫 → 拨打 120。", set: ["inhaler": 1]),
        ],
        draw: { s, p, t in drawAsthma(&s, p, t) },
        sources: ["GINA 2024 asthma strategy; Asthma + Lung UK attack plan; peak-flow zones (NHLBI asthma action plan)"]
    )

    static func asthma(for p: Profile) -> Scenario {
        var s = asthma
        let f: Double = p.female ? 1 : 0
        switch p.age {
        case .infant:
            s.profileNote = Bilingual("Babies: wheeze under 1 is often bronchiolitis from a virus — see a doctor. Inhalers go through a spacer with a soft face mask.",
                                      "婴儿：1 岁内喘息多为病毒性毛细支气管炎——需就医。吸入药要用带软面罩的储雾罐。")
            return s.rebased(["kid": 1, "female": f])
        case .toddler, .child:
            s.profileNote = Bilingual("Children: always use a spacer; under about 5, one with a face mask held on for 5–6 breaths per puff.",
                                      "儿童：一定要用储雾罐；约 5 岁以下用带面罩的，每喷扣紧面罩呼吸 5–6 次。")
            return s.rebased(["kid": 1, "female": f])
        case .senior:
            s.profileNote = Bilingual("65+: a spacer helps if pressing and breathing in together is hard. Asthma and COPD can overlap — review inhalers yearly.",
                                      "65 岁以上：按压与吸气难以同步时，储雾罐很有帮助。哮喘与慢阻肺可能并存——每年复查用药。")
            return s.rebased(["senior": 1, "female": f])
        case .adult where p.isPregnant:
            s.profileNote = Bilingual("Pregnant: keep using your asthma inhalers — an uncontrolled attack is the bigger risk to the baby.",
                                      "孕妇：继续使用哮喘吸入药——发作失控对胎儿的风险更大。")
            return s.rebased(["pregnant": 1])
        case .adult: break
        }
        return s.rebased(["female": f])
    }

    @MainActor private static func drawAsthma(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let r = airway(p), pef = peakFlow(p), attack = p[v: "attack"], inh = p[v: "inhaler"], kid = p[v: "kid"] > 0.5
        let squeeze = attack * (1 - inh)
        let zone: (String, String, Color) = pef >= 80 ? ("Green zone", "绿区", Tone.green) : pef >= 50 ? ("Yellow zone", "黄区", hex("#D9A21B")) : ("Red zone", "红区", Tone.red)

        // top: peak-flow meter and its reading
        s.card(8, 6, 344, 58, accent: zone.2)
        s.caption("Peak-flow meter", "峰流速仪", 18, 19)
        let mx0 = 30.0, mx1 = 196.0, my = 36.0
        s.rect(14, my - 5, 18, 10, r: 3, fill: hex("#DCE4EE"), stroke: hex("#8C9AAE"), lw: 0.8)          // mouthpiece
        s.shade(Path(roundedRect: CGRect(x: mx0, y: my - 9, width: mx1 - mx0, height: 18), cornerRadius: 9), hex("#F4F8FC"), hex("#D6E0EA"), stroke: hex("#8C9AAE"), lw: 1)
        let w = mx1 - mx0 - 20
        for (lo, hi, c) in [(0.0, 50.0, Tone.red), (50, 80, hex("#E8C040")), (80, 100, Tone.green)] {
            s.rect(mx0 + 10 + w * lo / 100, my + 11, w * (hi - lo) / 100, 4, fill: c)
        }
        for k in 0...10 { s.line(mx0 + 10 + w * Double(k) / 10, my - 6, mx0 + 10 + w * Double(k) / 10, my - (k % 5 == 0 ? 0 : 3), stroke: hex("#6E7A8A"), lw: 0.7) }
        let ix = mx0 + 10 + w * pef / 100
        s.rect(ix - 2.5, my - 7, 5, 14, r: 1.5, fill: Tone.red)
        s.text("\(Int(pef.rounded()))%", 286, 40, size: 22, color: zone.2, anchor: .end, bold: true)
        s.label("of your best", "个人最佳值", 290, 30, size: 7.5, color: Tone.sub)
        s.pill(zone.0, zone.1, 290, 43, color: zone.2, size: 7.5)
        s.label(pef >= 80 ? "breathing well" : pef >= 50 ? "use your reliever" : "reliever now; no better → 911",
                pef >= 80 ? "呼吸良好" : pef >= 50 ? "使用缓解药" : "立即用缓解药；不缓解 → 120", 206, 57, size: 7.5, color: zone.2, bold: true)

        // left: the person, using a spacer when the reliever is in
        let floor = 290.0
        let who = kid ? Casualty(Profile(age: .child, female: p[v: "female"] > 0.5), adult: 210) : Casualty(p, adult: 200)
        let using = inh > 0.2
        var v = SideFigure(who, lean: using ? 6 : 10 * attack, face: attack > 0.5 && !using ? .distress : .calm)
        if !kid && p[v: "senior"] < 0.5 && p[v: "pregnant"] < 0.5 { v.look.top = hex("#9CCB9E"); v.look.topLine = Look.edge(v.look.top) }
        v.nearLeg = .init(hip: 12, knee: 22)
        v.farLeg = .init(hip: -3, knee: 1)
        v.hip = CGPoint(x: 66, y: v.hipY(onFloor: floor))
        let h = v.h, mouth = v.mouth
        let spacerEnd = CGPoint(x: mouth.x + 0.24 * h, y: mouth.y + 2)
        let tubeH = 0.085 * h
        if using {
            v.near = .init(reach: CGPoint(x: spacerEnd.x + 2, y: mouth.y + 1), hand: .fist)
            v.far = .init(reach: CGPoint(x: (mouth.x + spacerEnd.x) / 2, y: mouth.y + tubeH / 2 + 2), hand: .open, handAngle: 0)
        } else if attack > 0.5 {
            v.near = .init(reach: v.front(0.72), hand: .open, handAngle: 200)
            v.far = .init(reach: v.front(0.6), hand: .open, handAngle: 200)
        } else {
            v.near = .init(shoulder: 6, elbow: 12)
            v.far = .init(shoulder: -3, elbow: 10)
        }
        s.stage(v.hip.x + 30, floor: floor, r: 84, width: 190)
        v.drawBack(&s)
        v.drawBody(&s)
        // airway tree through the chest, seen through the arm
        let top = v.torso(0.16, 1.02), fork = v.torso(0.06, 0.74)
        let lobe1 = v.torso(-0.14, 0.44), lobe2 = v.torso(0.24, 0.46)
        let ring = lerp(fork, lobe2, 0.8)
        let tree = { (g: inout Sketch) in
            let col = squeeze > 0.4 ? Tone.red : hex("#D98A80")
            let lung = v.torso(0.05, 0.6), dh = v.build.depth * v.h, th = v.build.torso * v.h
            g.ellipse(lung.x, lung.y, dh * 0.42, th * 0.26, fill: hex("#F2A7A0"), opacity: 0.35)
            g.line(top.x, top.y, fork.x, fork.y, stroke: col, lw: 1.8, cap: .round, opacity: 0.75)
            for (end, k) in [(lobe1, 1.0), (lobe2, -1.0)] {
                g.line(fork.x, fork.y, end.x, end.y, stroke: col, lw: 1.3, cap: .round, opacity: 0.75)
                let q = lerp(fork, end, 0.6)
                g.line(q.x, q.y, q.x - k * 4, q.y + 5, stroke: col, lw: 0.9, cap: .round, opacity: 0.7)
            }
        }
        if using {
            if kid {
                s.path("M \(mouth.x - 3) \(mouth.y - 11) L \(mouth.x + 12) \(mouth.y - tubeH / 2) L \(mouth.x + 12) \(mouth.y + tubeH / 2) L \(mouth.x - 3) \(mouth.y + 10) Z",
                       fill: hex("#CFE3F2"), stroke: hex("#5F87B8"), lw: 1.2, opacity: 0.9)
            } else {
                s.rect(mouth.x - 2, mouth.y - 3, 14, 6, r: 2, fill: hex("#CFE3F2"), stroke: hex("#5F87B8"))
            }
            s.shade(Path(roundedRect: CGRect(x: mouth.x + 10, y: mouth.y - tubeH / 2, width: spacerEnd.x - mouth.x - 10, height: tubeH), cornerRadius: tubeH / 2),
                    hex("#EEF5FB"), hex("#CFE0EF"), stroke: hex("#5F87B8"), lw: 1.2)
            s.rect(spacerEnd.x - 2, mouth.y - tubeH / 2 - 0.1 * h, 9, 0.1 * h + 4, r: 2, fill: hex("#3F7FD6"))
            s.rect(spacerEnd.x - 3, mouth.y - 4, 10, 8, r: 2, fill: hex("#2E5FA8"))
            for i in 0..<Int((inh * 8).rounded()) {
                let u = (t * 0.7 + Double(i) / 8).wrap(1)
                s.circle(spacerEnd.x - u * (spacerEnd.x - mouth.x - 6), mouth.y + sin(Double(i) * 2.1) * tubeH * 0.3, 1.5, fill: hex("#7FB2E5"), opacity: 1 - u * 0.6)
            }
            s.callout(kid ? "spacer + mask" : "spacer", kid ? "储雾罐+面罩" : "储雾罐", at: CGPoint(x: (mouth.x + spacerEnd.x) / 2 + 6, y: mouth.y + tubeH / 2),
                      spacerEnd.x + 8, mouth.y + tubeH / 2 + 16, anchor: .start, color: hex("#2E5FA8"), size: 8)
            s.callout("blue reliever", "蓝色缓解剂", at: CGPoint(x: spacerEnd.x + 3, y: mouth.y - tubeH / 2 - 0.08 * h), spacerEnd.x - 26, mouth.y - tubeH / 2 - 0.1 * h - 10,
                      anchor: .start, color: hex("#2E5FA8"), size: 8)
        } else if squeeze > 0.4 {
            for i in 0..<3 {
                let u = (t * 1.5 + Double(i) / 3).wrap(1)
                s.path("M \(mouth.x + 8 + u * 28) \(mouth.y - 3) q 3 -4 6 0 q 3 4 6 0", stroke: Tone.red, lw: 1.4, opacity: 1 - u)
            }
            s.label("wheeze, tight chest", "喘鸣、胸闷", mouth.x + 6, mouth.y - 16, size: 9, color: Tone.red, bold: true)
        }
        v.drawArm(&s, near: true)
        tree(&s)

        // right: a small airway, cut across
        let c = CGPoint(x: 280, y: 184), R = 62.0
        var lens = s.lens(c, R, from: ring, 5, fill: hex("#F7E4E0"))
        let breath = (sin(t * (pef >= 60 ? 1.6 : 3.2)) + 1) / 2
        let outer = R - 6, lumen = 30 * r
        lens.circle(c.x, c.y, outer, fill: hex("#F0CFCB"))
        // smooth-muscle bands: thicker and darker as they squeeze
        for i in 0..<14 {
            let a = Double(i) / 14 * 2 * .pi, rr = lumen + 10 + 8 * (1 - squeeze) + 4
            let q = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
            lens.group(rotate: a * 180 / .pi + 90, about: q) { g in
                g.rect(q.x - 6, q.y - 3 - 2 * squeeze, 12, 6 + 4 * squeeze, r: 2.5, fill: hex("#C1443C"), opacity: 0.45 + squeeze * 0.55)
            }
        }
        // swollen lining (mucosa) and the open channel
        let mucosaR = lumen + 6 + 8 * squeeze
        lens.circle(c.x, c.y, mucosaR, fill: squeeze > 0.3 ? hex("#EDA6AE") : hex("#F4C4CA"))
        lens.circle(c.x, c.y, lumen, fill: .white, stroke: hex("#E0A0AA"), lw: 1.5)
        for i in 0..<16 {
            let a = Double(i) / 16 * 2 * .pi
            lens.line(c.x + cos(a) * lumen, c.y + sin(a) * lumen, c.x + cos(a) * (lumen - 2.5), c.y + sin(a) * (lumen - 2.5), stroke: hex("#E0A0AA"), lw: 0.8)
        }
        if attack > 0.3 {
            lens.path("M \(c.x - lumen * 0.95) \(c.y + lumen * 0.2) Q \(c.x) \(c.y + lumen * (0.2 + 0.9 * squeeze)) \(c.x + lumen * 0.95) \(c.y + lumen * 0.2) "
                      + "Q \(c.x) \(c.y + lumen * 1.05) \(c.x - lumen * 0.95) \(c.y + lumen * 0.2) Z", fill: hex("#F2E0A0"), stroke: hex("#D9C070"), lw: 0.8, opacity: 0.5 + 0.5 * squeeze)
        }
        for i in 0..<5 {
            lens.circle(c.x + Double(i - 2) * lumen * 0.3, c.y - lumen * 0.55 + breath * lumen * 0.9, 2.4, fill: hex("#3F95D6"), opacity: min(1, pef / 90))
        }
        s.lensRing(c, R)
        s.caption("Small airway, cut across", "小气道横截面", c.x, c.y + R + 16, anchor: .middle)
        let rs = lumen + 10 + 8 * (1 - squeeze) + 4
        s.callout(squeeze > 0.3 ? "muscle squeezes" : "muscle ring", squeeze > 0.3 ? "平滑肌收缩" : "平滑肌", at: CGPoint(x: c.x + rs * 0.7, y: c.y - rs * 0.7),
                  352, c.y - R + 2, anchor: .end, color: hex("#A8352E"), size: 8)
        s.callout(squeeze > 0.3 ? "swollen lining" : "lining", squeeze > 0.3 ? "黏膜水肿" : "黏膜", at: CGPoint(x: c.x - mucosaR * 0.75, y: c.y + mucosaR * 0.6),
                  200, c.y + R + 2, color: hex("#B0606A"), size: 8)
        if attack > 0.3 && squeeze > 0.2 {
            s.callout("mucus", "痰", at: CGPoint(x: c.x + lumen * 0.3, y: c.y + lumen * 0.75), 352, c.y + R + 2, anchor: .end, color: hex("#8A7A2B"), size: 8)
        }
        s.label("open width \(Int((r * 100).rounded()))% of normal", "管腔为正常的 \(Int((r * 100).rounded()))%", c.x, 277, size: 8, color: Tone.sub, anchor: .middle, bold: true)
    }

    /// how high acid climbs the oesophagus (0..1)
    static func reflux(_ p: Params) -> Double { (p[v: "valveWeak"] * (0.3 + 0.7 * p[v: "lying"]) * (1 - 0.8 * p[v: "antacid"])).clamped(0, 1) }

    static let acidReflux = Scenario(
        id: "acid-reflux", group: .illness, title: Bilingual("Acid reflux & heartburn", "胃食管反流"),
        params: ["valveWeak": 0, "lying": 0, "antacid": 0, "pregnant": 0, "flags": 0],
        steps: [
            .watch("After a meal the stomach churns food in strong acid. A ring of muscle where the gullet meets the stomach (the valve) keeps it down.",
                   "饭后胃用强酸搅拌食物。食管与胃连接处的一圈括约肌（贲门）把胃酸挡在胃里。", set: ["valveWeak": 0, "lying": 0, "antacid": 0, "flags": 0]),
            .watch("When that valve relaxes too often, acid splashes up and burns the gullet — heartburn behind the breastbone.",
                   "括约肌经常松弛时，胃酸反流灼伤食管——胸骨后烧灼感（烧心）。", set: ["valveWeak": 1]),
            .watch("Lie down after a big meal and gravity stops helping — acid runs straight into the gullet (worst lying on the right side).",
                   "饱餐后躺下，重力不再帮忙——胃酸直接流进食管（右侧卧最重）。", set: ["lying": 1]),
            .tryIt("Compare: lying flat vs. the head of the bed raised on blocks.", "对比：平躺 vs. 床头垫高。",
                   TryStep(mode: .compare(param: "lying", options: [("Flat 平躺", 1), ("Raised 抬高", 0.3)]), success: { $0[v: "lying"] < 0.5 },
                           ok: Bilingual("Raise the head 15–20 cm, don’t eat 3 h before bed, smaller meals.", "床头抬高 15–20 厘米，睡前 3 小时不进食，少食多餐。"),
                           demo: ["lying": 0.3])),
            .watch("See a doctor if it’s weekly, food sticks, you lose weight or vomit blood.", "每周发作、吞咽梗阻、体重下降或呕血时应就医。", set: ["lying": 0.3, "flags": 1]),
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
            return s.rebased(["senior": 1, "female": p.female ? 1 : 0])
        case .adult where p.isPregnant:
            s.profileNote = Bilingual("Pregnant: hormones relax the valve and the growing womb pushes on the stomach — heartburn is very common. Small meals; ask before antacids.",
                                      "孕妇：激素使括约肌松弛，增大的子宫挤压胃——烧心很常见。少食多餐；用抗酸药前先咨询医生。")
            return s.rebased(["pregnant": 1])
        case .toddler, .child, .adult: break
        }
        return s.rebased(["female": p.female ? 1 : 0])
    }

    @MainActor private static func drawReflux(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let rf = reflux(p), lying = p[v: "lying"], weak = p[v: "valveWeak"] > 0.5
        let wall = hex("#F4D3C4"), edge = hex("#B97A6A"), acid = hex("#E3C23A")
        let pose = lying > 0.65 ? 2 : lying > 0.15 ? 1 : 0
        let hurt = rf > 0.6
        let status: (String, String, Color) = hurt ? ("Heartburn", "烧心", Tone.red) : rf > 0.25 ? ("Mild burning", "轻微烧灼", Tone.amber) : ("Comfortable", "无不适", Tone.green)

        // top left: the everyday picture
        s.card(8, 6, 176, 112)
        var room = s.clipped(8, 6, 176, 112)
        let who = Casualty(p, adult: 120)
        if pose == 0 {
            room.rect(8, 104, 176, 14, fill: hex("#EFE8DE"))
            var v = SideFigure(Casualty(p, adult: 90), face: hurt ? .distress : .calm)
            v.nearLeg = .init(hip: 12, knee: 22)
            v.farLeg = .init(hip: -3, knee: 1)
            v.hip = CGPoint(x: 50, y: v.hipY(onFloor: 106))
            v.near = hurt ? .init(reach: v.front(0.72), hand: .open, handAngle: 200) : .init(shoulder: 4, elbow: 10)
            v.far = .init(shoulder: -4, elbow: 10)
            v.draw(&room)
            room.label("upright after eating", "饭后保持直立", 136, 44, size: 8.5, color: Tone.green, anchor: .middle, bold: true)
            room.label("gravity keeps acid down", "重力让胃酸留在胃里", 136, 58, size: 7.5, color: Tone.sub, anchor: .middle)
        } else {
            let tilt = pose == 1 ? 7.0 : 0
            room.rect(8, 108, 176, 10, fill: hex("#EFE8DE"))
            if pose == 1 { room.rect(22, 94, 16, 14, r: 2, fill: hex("#8A6A4A")) }
            room.group(rotate: tilt, about: CGPoint(x: 170, y: 104)) { g in
                g.rect(24, 92, 150, 5, r: 2, fill: hex("#B08A64"))
                g.rect(26, 96, 5, 12, fill: hex("#9B7550"))
                g.rect(166, 96, 5, 12, fill: hex("#9B7550"))
                g.rect(24, 80, 150, 12, r: 4, fill: hex("#DCE6F2"), stroke: hex("#9FB3CC"))
                g.rect(28, 68, 30, 12, r: 6, fill: .white, stroke: hex("#CCCCCC"))
                var v = SideFigure(who, face: hurt ? .distress : .calm)
                v.rotation = -90
                v.hip = CGPoint(x: 104, y: 80 - v.build.depth * v.h * 0.5 - 1)
                v.nearLeg = .init(hip: 2, knee: 3, point: 25)
                v.farLeg = .init(hip: 1, knee: 2, point: 25)
                v.near = hurt ? .init(reach: v.front(0.72), hand: .open, handAngle: 180) : .init(shoulder: 6, elbow: 10)
                v.far = .init(shoulder: 3, elbow: 8)
                v.draw(&g)
            }
            if pose == 1 {
                room.callout("blocks 15–20 cm", "垫高 15–20 厘米", at: CGPoint(x: 38, y: 101), 50, 114, color: Tone.green, size: 7.5)
            }
            room.label(pose == 2 ? "lying flat after a big meal" : "head of the bed raised", pose == 2 ? "饱餐后平躺" : "床头抬高",
                       96, 26, size: 8.5, color: pose == 2 ? Tone.red : Tone.green, anchor: .middle, bold: true)
        }

        // top right: how it feels
        s.card(192, 6, 160, 50, accent: status.2)
        s.caption("Acid in the gullet", "食管内胃酸", 202, 20)
        let pct = "\(Int((rf * 100).rounded()))%"
        s.text(pct, 202, 44, size: 18, color: status.2, bold: true)
        s.pill(status.0, status.1, 210 + s.width(pct, pct, size: 18, bold: true), 38, color: status.2, size: 8)

        // bottom left: what helps, or when to see a doctor
        let flags = p[v: "flags"] > 0.5
        s.card(8, 126, 176, 168, accent: flags ? Tone.red : nil)
        s.caption(flags ? "See a doctor if" : "What helps", flags ? "出现以下情况就医" : "如何缓解", 16, 140, color: flags ? Tone.red : Tone.sub)
        let tips: [(String, String)] = flags
            ? [("Heartburn every week", "每周都烧心"), ("Food sticks going down", "吞咽时食物梗住"), ("Losing weight", "体重下降"),
               ("Vomiting blood", "呕血"), ("Black, tarry stools", "黑色柏油样大便"), ("New symptoms after 60", "60 岁后新出现症状")]
            : [("Smaller meals", "少食多餐"), ("No food 3 h before bed", "睡前 3 小时不进食"), ("Raise the bed head 15–20 cm", "床头抬高 15–20 厘米"),
               ("Lose extra weight", "减掉多余体重"), ("Less fatty food, alcohol, coffee", "少吃油腻，少饮酒和咖啡"), ("No smoking", "戒烟")]
        for (i, tip) in tips.enumerated() {
            let y = 160 + Double(i) * 21
            if flags {
                s.circle(21, y - 3, 5.5, fill: Tone.red.opacity(0.14))
                s.text("!", 21, y, size: 8, color: Tone.red, anchor: .middle, bold: true)
            } else {
                s.circle(21, y - 3, 5.5, fill: Tone.green.opacity(0.14))
                s.path("M 18.5 \(y - 3) L 20.5 \(y - 1) L 24 \(y - 5.5)", stroke: Tone.green, lw: 1.3, cap: .round)
            }
            s.label(tip.0, tip.1, 32, y, size: 8.5, color: Tone.ink)
        }

        // right: gullet, valve and stomach (front view). Lying down, the acid pocket sits against the valve.
        let k = 0.78, pivot = CGPoint(x: 290, y: 212), center = CGPoint(x: -30, y: 50)
        func world(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: pivot.x + (x - center.x) * k, y: pivot.y + (y - center.y) * k) }
        let stomach = "M 11 2 C 43 -10 63 8 57 38 C 51 92 11 140 -47 134 C -79 130 -101 110 -107 88 L -123 86 L -123 74 L -103 74 "
            + "C -95 94 -79 106 -53 104 C -25 102 -13 74 -13 38 C -13 24 -13 12 -11 4 Z"
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
            // diaphragm with the opening the gullet passes through
            a.path("M -150 -8 C -100 -34 -40 -38 -14 -24 M 14 -24 C 40 -38 100 -34 150 -8", stroke: hex("#B8544C"), lw: 7, cap: .round)
            a.path("M -150 -8 C -100 -34 -40 -38 -14 -24 M 14 -24 C 40 -38 100 -34 150 -8", stroke: hex("#D9776E"), lw: 3, cap: .round)
            a.shade(Path(roundedRect: CGRect(x: -11, y: -150, width: 22, height: 156), cornerRadius: 8), wall, dim(wall, 0.9), stroke: edge, lw: 1.8)
            a.shade(stomach, wall, dim(wall, 0.88), stroke: edge, lw: 1.8)
            var pool = a.clipped(to: SVGPath.parse(stomach))
            pool.shade(poly, acid, dim(acid, 0.85), opacity: 0.9)
            for k2 in 0..<4 { pool.path("M \(-60 + Double(k2) * 22) \(60 + Double(k2) * 8) C \(-40 + Double(k2) * 22) \(40 + Double(k2) * 8) \(-20 + Double(k2) * 22) \(80 + Double(k2) * 6) \(0 + Double(k2) * 22) \(60 + Double(k2) * 8)",
                                            stroke: dim(wall, 0.8), lw: 1.2, opacity: 0.6) }                                        // folds
            // the valve: a thick muscle ring, gapping when weak
            let gap = weak ? 3.0 + 2 * sin(t * 3) : 0
            a.rect(-13, -8, 11 - gap, 10, r: 2, fill: weak ? hex("#E39B4B") : hex("#8A3B45"))
            a.rect(2 + gap, -8, 11 - gap, 10, r: 2, fill: weak ? hex("#E39B4B") : hex("#8A3B45"))
            if rf > 0.02 { a.rect(-8, -6 - rf * 140, 16, rf * 140, r: 6, fill: acid, opacity: 0.9) }
            if hurt {
                a.rect(-11, -150, 22, 144, r: 8, stroke: Tone.red, lw: 3.5, opacity: 0.45 + 0.3 * sin(t * 4))
                for k2 in 0..<3 {
                    let yy = -40 - Double(k2) * 36
                    a.path("M 18 \(yy) q 6 -6 0 -12 q -6 -6 0 -12", stroke: Tone.red, lw: 1.6, opacity: 0.7, cap: .round)
                }
            }
        }
        s.callout("gullet", "食管", at: world(8, -110), 352, world(8, -110).y + 4, anchor: .end, color: Tone.label, size: 8)
        s.callout("diaphragm", "膈肌", at: world(-120, -18), max(218, world(-120, -18).x), world(-120, -18).y - 16, anchor: .middle, color: hex("#A8443C"), size: 8)
        s.callout("valve (LES)", "贲门括约肌", at: world(-12, -3), 196, world(-12, -3).y + 22, color: weak ? hex("#C0721B") : Tone.organLine, size: 8)
        let pooled = world(deepPoint.0 - g.x * 16 - 6, deepPoint.1 - g.y * 16)
        s.label("acid", "胃酸", pooled.x, pooled.y + 3, size: 8.5, color: hex("#7A6A12"), anchor: .middle, bold: true)
        s.label("stomach", "胃", world(22, 62).x, world(22, 62).y, size: 8.5, color: Tone.organLine, anchor: .middle, bold: true)
    }
}
