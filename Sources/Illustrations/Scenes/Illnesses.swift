import SwiftUI

extension Illustrations {
    static let coldFlu = Scenario(
        id: "cold-vs-flu", group: .illness, title: Bilingual("Cold vs flu", "感冒与流感"),
        params: ["flu": 0],
        steps: [
            .watch("A cold: viruses stay in the nose and throat. Comes on slowly, mild.", "普通感冒：病毒停留在鼻咽部。起病缓慢，症状轻。", set: ["flu": 0]),
            .watch("Flu: reaches deeper airways, hits suddenly — high fever, aches, exhaustion.", "流感：可侵入下呼吸道，起病急——高热、全身酸痛、极度乏力。", set: ["flu": 1]),
            .tryIt("Switch between them and watch the symptoms change.", "试一试：切换对比，观察症状变化。",
                   TryStep(mode: .compare(param: "flu", options: [("Cold 感冒", 0), ("Flu 流感", 1)]), success: { _ in true },
                           ok: Bilingual("Fever + aches + sudden start points to flu.", "发热 + 酸痛 + 起病急，提示流感。"))),
            .watch("Rest and fluids for both. Flu: antivirals work best within 48 h; yearly vaccine. See a doctor if breathless, chest pain, confused, or fever over 3 days.",
                   "两者均需休息、多饮水。流感：48 小时内用抗病毒药效果最好；每年接种疫苗。出现气促、胸痛、意识模糊或发热超过 3 天需就医。"),
        ],
        draw: { s, p, t in
            let f = p[v: "flu"]
            // side view of the head and neck, with the airway tree below
            let air = hex("#E8B4A0"), label = hex("#8A6A5A")
            s.path("M 40 60 C 40 20, 120 10, 138 50 C 146 64, 150 76, 144 86 C 140 96, 132 102, 118 104 L 112 120 L 64 120 C 58 104, 40 90, 40 60 Z",
                   fill: hex("#F7E6DA"), stroke: hex("#C9A58A"), lw: 1.5)
            s.path("M 132 70 C 116 66, 100 70, 92 80", stroke: air, lw: 6, cap: .round)                          // nasal cavity
            s.path("M 92 80 C 86 92, 86 106, 88 118", stroke: air, lw: 7, cap: .round)                           // pharynx
            s.path("M 88 118 L 90 170", stroke: air, lw: 7, cap: .round)                                          // larynx + trachea
            s.path("M 90 170 L 62 196 M 90 170 L 118 196", stroke: air, lw: 5, cap: .round)
            for (x, sx) in [(62.0, -1.0), (118, 1.0)] {
                s.ellipse(x + sx * 4, 214, 30, 40, fill: hex("#F2C4CC"), opacity: 0.8)
                for k in 0..<3 { s.path("M \(x) 196 L \(x + sx * Double(k - 1) * 12) \(222 + Double(k) * 6)", stroke: air, lw: 2) }
            }
            s.text("nose 鼻腔", 132, 62, size: 8, color: label)
            s.text("throat 咽", 100, 100, size: 8, color: label)
            s.text("windpipe 气管", 96, 150, size: 8, color: label)
            s.text("lungs 肺", 40, 262, size: 8, color: label)
            // viruses: the nose and throat for a cold; the flu also reaches the airways and lungs
            let spots: [(Double, Double, Double)] = [(118, 68, 0), (104, 72, 0), (90, 92, 0), (88, 108, 0), (90, 140, 0.4), (90, 160, 0.5),
                                                     (72, 190, 0.7), (108, 190, 0.7), (58, 214, 0.9), (122, 216, 0.9)]
            for (i, spot) in spots.enumerated() where f >= spot.2 || spot.2 == 0 {
                s.circle(spot.0 + sin(t * 2 + Double(i)) * 3, spot.1, 3.5, fill: hex("#7A3FA0"), opacity: spot.2 == 0 ? 0.85 : min(1, (f - spot.2 + 0.2) * 3))
            }
            let symptoms: [(String, Double, Double)] = [("Fever 发热", 0.1, 0.9), ("Aches 肌肉酸痛", 0.2, 0.9), ("Exhaustion 乏力", 0.3, 0.95),
                                                        ("Cough 咳嗽", 0.4, 0.7), ("Runny nose 流涕", 0.9, 0.3), ("Sore throat 咽痛", 0.7, 0.4)]
            for (i, sym) in symptoms.enumerated() {
                let v = sym.1 + (sym.2 - sym.1) * f, y = 30 + Double(i) * 34
                s.text(sym.0, 180, y)
                s.rect(180, y + 5, 160, 10, r: 5, fill: hex("#EEEEEE"))
                s.rect(180, y + 5, 160 * v, 10, r: 5, fill: v > 0.6 ? hex("#D8434B") : hex("#E39B4B"))
            }
            s.text(f > 0.5 ? "Flu 流感 — sudden, can reach lungs" : "Cold 感冒 — gradual, nose & throat", 180, 244, size: 10, color: hex("#6C4F9E"), bold: true)
            s.text(f > 0.5 ? "起病急、全身症状，可累及肺" : "起病缓、局限于鼻咽", 180, 258, size: 10, color: hex("#6C4F9E"))
            s.text("virus 病毒 ● — antibiotics don’t kill viruses 抗生素对病毒无效", 20, 290, size: 9)
        },
        sources: ["CDC “Cold versus flu”; WHO influenza fact sheet"]
    )

    /// open airway radius (0..1): narrowed by inflammation + muscle squeeze, widened by the inhaler
    static func airway(_ p: Params) -> Double { max(0.25, 1 - 0.65 * p[v: "attack"] * (1 - 0.8 * p[v: "inhaler"])) }
    static func airflow(_ p: Params) -> Double { pow(airway(p), 4) }

    static let asthma = Scenario(
        id: "asthma", group: .illness, title: Bilingual("Asthma attack", "哮喘发作"),
        params: ["attack": 0, "inhaler": 0],
        steps: [
            .watch("A normal airway: wide open, air flows easily.", "正常气道：通畅，气流顺畅。", set: ["attack": 0, "inhaler": 0]),
            .watch("Attack: the muscle ring tightens, the lining swells, mucus builds. The tube narrows.", "发作时：平滑肌收缩、黏膜水肿、痰液增多，气道变窄。", set: ["attack": 1]),
            .tryIt("Use the reliever inhaler — it relaxes the muscle. Watch airflow: a little wider = a lot more air.", "试一试：使用缓解吸入剂——放松平滑肌。气道稍宽，气流大增。",
                   TryStep(mode: .scrub([Scrub(param: "inhaler", label: "Inhaler 吸入剂", min: 0, max: 1)]), success: { airflow($0) > 0.5 },
                           ok: Bilingual("Breathing eases. If it doesn’t within minutes, call 120.", "呼吸缓解。几分钟内不缓解请拨打 120。"), demo: ["inhaler": 1])),
            .watch("Attack plan: sit upright, 1 puff every 30–60 s up to 10. Can’t speak in sentences or lips turn blue → 120.",
                   "发作处理：坐直，每 30–60 秒吸 1 喷，最多 10 喷。说话不成句或嘴唇发紫 → 拨打 120。", set: ["inhaler": 1]),
        ],
        draw: { s, p, t in
            let r = airway(p), flow = airflow(p), R = 70.0
            let breath = (sin(t * (flow > 0.3 ? 1.6 : 3.2)) + 1) / 2
            let squeeze = p[v: "attack"] * (1 - 0.8 * p[v: "inhaler"])
            s.circle(120, 140, R + 18, fill: hex("#E8B4B8"))
            for i in 0..<12 {
                let a = Double(i) / 12 * 2 * .pi
                let c = CGPoint(x: 120 + cos(a) * (R + 6), y: 140 + sin(a) * (R + 6))
                s.group(rotate: a * 180 / .pi + 90, about: c) { g in g.rect(c.x - 5, c.y - 9, 10, 18, fill: hex("#C1443C"), opacity: 0.3 + squeeze * 0.7) }
            }
            s.circle(120, 140, R, fill: hex("#F2C9D0"))
            s.circle(120, 140, R * r, fill: .white, stroke: hex("#E0A0AA"), lw: 2)
            if p[v: "attack"] > 0.3 { s.path("M \(120 - R * r) 140 Q 120 \(140 + R * r * 0.4) \(120 + R * r) 140", stroke: hex("#F2E0A0"), lw: 6, opacity: 0.8) }
            for i in 0..<5 { s.circle(120 + Double(i - 2) * R * r * 0.3, 140 - R * r * 0.5 + breath * R * r, 3, fill: hex("#3F95D6"), opacity: flow) }
            s.text("airway cross-section 气道横截面", 120, 250, color: hex("#8A3B45"), anchor: .middle)
            s.text("muscle 平滑肌 · swollen lining 黏膜水肿 · mucus 痰", 120, 264, size: 9, color: hex("#8A3B45"), anchor: .middle)
            let status = flow < 0.3 ? hex("#D8434B") : hex("#2E9E5B")
            s.rect(230, 40, 122, 96, r: 8, fill: .white, stroke: status, lw: 2)
            s.text("Airflow 气流", 291, 62, size: 11, anchor: .middle)
            s.text("\(Int((flow * 100).rounded()))%", 291, 92, size: 24, color: status, anchor: .middle, bold: true)
            s.text("radius \(Int((r * 100).rounded()))% → flow ∝ r⁴", 291, 116, anchor: .middle)
            if p[v: "attack"] > 0.5 { s.text("wheeze · tight chest 喘鸣 胸闷", 230, 160, size: 11, color: hex("#D8434B")) }
        },
        sources: ["GINA 2024 asthma strategy; Poiseuille flow ∝ r⁴"]
    )

    /// how high acid climbs the oesophagus (0..1)
    static func reflux(_ p: Params) -> Double { (p[v: "valveWeak"] * (0.3 + 0.7 * p[v: "lying"]) * (1 - 0.8 * p[v: "antacid"])).clamped(0, 1) }

    static let acidReflux = Scenario(
        id: "acid-reflux", group: .illness, title: Bilingual("Acid reflux & heartburn", "胃食管反流"),
        params: ["valveWeak": 0, "lying": 0, "antacid": 0],
        steps: [
            .watch("A ring of muscle at the stomach’s top keeps acid down.", "胃入口的括约肌环把胃酸挡在胃里。", set: ["valveWeak": 0, "lying": 0, "antacid": 0]),
            .watch("When it relaxes too often, acid splashes up and burns — heartburn.", "括约肌松弛时，胃酸反流灼伤食管——烧心。", set: ["valveWeak": 1]),
            .watch("Lying flat after a big meal makes it worse — gravity stops helping.", "饱餐后平躺会加重——重力不再帮忙。", set: ["lying": 1]),
            .tryIt("Compare: lying flat vs. head of the bed raised.", "对比：平躺 vs. 抬高床头。",
                   TryStep(mode: .compare(param: "lying", options: [("Flat 平躺", 1), ("Raised 抬高", 0.3)]), success: { $0[v: "lying"] < 0.5 },
                           ok: Bilingual("Raise the head 15–20 cm, don’t eat 3 h before bed, smaller meals.", "床头抬高 15–20 厘米，睡前 3 小时不进食，少食多餐。"))),
            .watch("See a doctor if it’s weekly, food sticks, you lose weight or vomit blood.", "每周发作、吞咽梗阻、体重下降或呕血时应就医。"),
        ],
        draw: { s, p, t in
            let rf = reflux(p), slosh = sin(t * 2) * 2
            let lying = p[v: "lying"] > 0.5
            let wall = hex("#F4D3C4"), edge = hex("#C98A7A"), acid = hex("#E3C23A"), label = hex("#8A6A5A")
            // diaphragm with the oesophagus passing through its hiatus
            s.path("M 20 120 C 80 96, 150 92, 172 104 M 196 104 C 230 92, 300 96, 350 120", stroke: hex("#B8544C"), lw: 5, cap: .round)
            s.text("diaphragm 膈肌", 270, 96, size: 8, color: hex("#B8544C"))
            s.rect(172, 10, 22, 118, r: 8, fill: wall, stroke: edge, lw: 2)
            // J-shaped stomach: fundus up by the junction, body, antrum, pylorus to the duodenum
            let stomach = "M 172 124 C 140 112, 120 130, 126 160 C 132 214, 172 262, 230 256 C 262 252, 284 232, 290 210 L 306 208 L 306 196 L 286 196 "
                + "C 278 216, 262 228, 236 226 C 208 224, 196 196, 196 160 C 196 146, 196 134, 194 126 Z"
            s.path(stomach, fill: wall, stroke: edge, lw: 2)
            if lying {
                // lying flat: acid runs back to the fundus, against the valve
                s.path("M 130 150 C 140 140, 176 132, 194 132 L 196 160 C 180 168, 150 170, 128 166 Z", fill: acid, opacity: 0.85)
            } else {
                s.path("M 142 \(214 + slosh) C 170 \(208 - slosh), 230 \(212 + slosh), 262 \(226 - slosh) C 250 250, 200 258, 170 246 C 156 238, 146 228, 142 \(214 + slosh) Z",
                       fill: acid, opacity: 0.85)
            }
            s.rect(173, 118, 20, 8, fill: p[v: "valveWeak"] > 0.5 ? hex("#E39B4B") : hex("#8A3B45"))
            if rf > 0.02 { s.rect(175, 124 - rf * 110, 16, rf * 110, fill: acid, opacity: 0.85) }
            s.text("oesophagus 食管", 200, 40, size: 8, color: label)
            s.text("valve (LES) 贲门括约肌", 40, 136, size: 8, color: label)
            s.text("fundus 胃底", 96, 150, size: 8, color: label)
            s.text("pylorus 幽门", 290, 190, size: 8, color: label)
            s.text("stomach acid 胃酸 pH 1.5–3.5", 150, 290, size: 8, color: label)
            let purple = hex("#6C4F9E")
            s.group(translate: CGPoint(x: 310, y: 30)) { g in
                if lying {
                    g.circle(-24, 10, 7, fill: purple)
                    g.path("M -16 10 L 30 10 M -2 10 L -6 20 M 16 10 L 20 20", stroke: purple, lw: 4, cap: .round)
                } else {
                    g.circle(0, -6, 7, fill: purple)
                    g.path("M 0 2 L 0 30 M 0 30 L -8 46 M 0 30 L 8 46 M 0 10 L -10 20 M 0 10 L 10 20", stroke: purple, lw: 4, cap: .round)
                }
                g.text(lying ? "lying flat 平躺" : "upright 直立", 0, 62, size: 8, color: purple, anchor: .middle)
            }
            let status = rf > 0.3 ? hex("#D8434B") : hex("#2E9E5B")
            s.rect(8, 6, 150, 44, r: 8, fill: .white, stroke: status, lw: 2)
            s.text("Reflux 反流 \(Int((rf * 100).rounded()))%", 20, 26, size: 12, color: status, bold: true)
            s.text(rf > 0.3 ? "heartburn 烧心" : "comfortable 无不适", 20, 42)
        },
        sources: ["ACG 2022 GERD guideline"]
    )
}
