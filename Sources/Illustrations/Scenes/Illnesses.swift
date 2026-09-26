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
            s.circle(80, 60, 36, fill: hex("#F2C9A5"), stroke: hex("#C9A58A"), lw: 2)
            s.path("M 84 70 L 90 110 L 90 150 M 90 150 L 60 200 M 90 150 L 120 200", stroke: hex("#E8C4B0"), lw: 10, cap: .round)
            s.text("nose & throat 鼻咽 · airways · lungs 肺", 20, 228)
            for i in 0..<10 {
                let inLungs = Double(i) / 10 < f * 0.7
                let x = inLungs ? 70 + Double(i % 2) * 40 + sin(t * 2 + Double(i)) * 6 : 88 + sin(t * 2 + Double(i)) * 8
                let y = inLungs ? 170 + Double(i % 3) * 10 : 70 + (Double(i) * 13).wrap(40)
                s.circle(x, y, 4, fill: hex("#7A3FA0"), opacity: 0.85)
            }
            let symptoms: [(String, Double, Double)] = [("Fever 发热", 0.1, 0.9), ("Aches 肌肉酸痛", 0.2, 0.9), ("Exhaustion 乏力", 0.3, 0.95),
                                                        ("Cough 咳嗽", 0.4, 0.7), ("Runny nose 流涕", 0.9, 0.3), ("Sore throat 咽痛", 0.7, 0.4)]
            for (i, sym) in symptoms.enumerated() {
                let v = sym.1 + (sym.2 - sym.1) * f, y = 30 + Double(i) * 34
                s.text(sym.0, 170, y)
                s.rect(170, y + 5, 170, 10, r: 5, fill: hex("#EEEEEE"))
                s.rect(170, y + 5, 170 * v, 10, r: 5, fill: v > 0.6 ? hex("#D8434B") : hex("#E39B4B"))
            }
            s.text(f > 0.5 ? "Flu 流感 — sudden, whole body 起病急、全身症状" : "Cold 感冒 — gradual, nose & throat 起病缓、鼻咽症状", 20, 256, size: 12, color: hex("#6C4F9E"), bold: true)
            s.text("virus 病毒 ● — antibiotics don’t kill viruses 抗生素对病毒无效", 20, 280)
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
            let rf = reflux(p), slosh = sin(t * 2) * 3
            let wall = hex("#F4D3C4"), edge = hex("#C98A7A"), acid = hex("#E3C23A"), label = hex("#8A6A5A")
            s.rect(170, 20, 20, 150, r: 8, fill: wall, stroke: edge, lw: 2)
            s.path("M 170 170 C 110 170, 100 260, 170 270 C 250 280, 270 200, 190 170 Z", fill: wall, stroke: edge, lw: 2)
            s.path("M 118 \(240 + slosh) C 140 \(230 - slosh), 210 \(230 + slosh), 250 \(238 - slosh) L 240 262 C 210 280, 140 280, 118 250 Z", fill: acid, opacity: 0.85)
            s.rect(172, 166, 16, 8, fill: p[v: "valveWeak"] > 0.5 ? hex("#E39B4B") : hex("#8A3B45"))
            if rf > 0.02 { s.rect(173, 170 - rf * 140, 14, rf * 140, fill: acid, opacity: 0.85) }
            s.text("oesophagus 食管", 196, 60, color: label)
            s.text("valve 贲门括约肌", 196, 176, color: label)
            s.text("stomach acid 胃酸 pH 1.5–3.5", 150, 292, color: label)
            let lying = p[v: "lying"] > 0.5, purple = hex("#6C4F9E")
            s.group(translate: CGPoint(x: 300, y: 70)) { g in
                if lying {
                    g.circle(-30, 20, 8, fill: purple)
                    g.path("M -20 20 L 30 20 M -5 20 L -10 32 M 15 20 L 20 32", stroke: purple, lw: 5, cap: .round)
                } else {
                    g.circle(0, -20, 8, fill: purple)
                    g.path("M 0 -10 L 0 25 M 0 25 L -10 45 M 0 25 L 10 45 M 0 0 L -12 12 M 0 0 L 12 12", stroke: purple, lw: 5, cap: .round)
                }
                g.text(lying ? "lying flat 平躺" : "upright 直立", 0, 62, color: purple, anchor: .middle)
            }
            for i in 0..<Int((rf * 6).rounded()) { s.circle(60 + Double(i) * 8, 40 + (t * 30 + Double(i) * 9).wrap(20), 3, fill: hex("#E0503C")) }
            let status = rf > 0.3 ? hex("#D8434B") : hex("#2E9E5B")
            s.rect(8, 6, 150, 44, r: 8, fill: .white, stroke: status, lw: 2)
            s.text("Reflux 反流 \(Int((rf * 100).rounded()))%", 20, 26, size: 12, color: status, bold: true)
            s.text(rf > 0.3 ? "heartburn 烧心" : "comfortable 无不适", 20, 42)
        },
        sources: ["ACG 2022 GERD guideline"]
    )
}
