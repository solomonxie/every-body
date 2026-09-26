import SwiftUI

extension Illustrations {
    static let choking = Scenario(
        id: "choking", group: .firstAid, title: Bilingual("Choking (adult)", "气道异物梗阻"),
        params: ["stage": 0, "taps": 0, "rate": 0, "press": 0, "dislodge": 0],
        steps: [
            .watch("Can they cough? Encourage coughing. If they can’t speak, cough or breathe — act now.",
                   "能咳嗽就鼓励咳嗽；若无法说话、咳嗽或呼吸——立即施救。", set: ["stage": 0, "taps": 0, "dislodge": 0]),
            .tryIt("Lean them forward. Give 5 firm back blows between the shoulder blades.",
                   "试一试：让其身体前倾，用掌根在两肩胛骨之间用力拍击 5 次。", set: ["stage": 1, "taps": 0, "dislodge": 0],
                   TryStep(mode: .rhythm(target: 5, minRate: 0, maxRate: 9999, label: "BLOW 拍背"), success: { $0[v: "taps"] >= 5 },
                           ok: Bilingual("5 back blows — still stuck? Move to abdominal thrusts.", "拍背 5 次——仍未排出？改用腹部冲击。"))),
            .tryIt("Stand behind, fist above the navel, pull sharply in and up — up to 5 times.",
                   "试一试：站其身后，拳头置于肚脐上方，快速向内向上冲击，最多 5 次。", set: ["stage": 2, "taps": 0, "dislodge": 0.2],
                   TryStep(mode: .rhythm(target: 5, minRate: 0, maxRate: 9999, label: "THRUST 冲击"), success: { $0[v: "dislodge"] >= 0.99 },
                           ok: Bilingual("Out! Get them checked by a doctor after abdominal thrusts.", "排出了！腹部冲击后仍需就医检查。"))),
            .watch("Still blocked? Keep alternating 5 blows / 5 thrusts. If they collapse: call 120 and start CPR.",
                   "仍未排出？交替进行 5 次拍背 / 5 次冲击。若失去意识：拨打 120 并开始心肺复苏。", set: ["stage": 2, "dislodge": 1]),
        ],
        draw: { s, p, _ in
            let st = Int(p[v: "stage"].rounded()), press = p[v: "press"]
            let out = min(1, p[v: "dislodge"])
            let obj = CGPoint(x: 162 + (150 - 162) * out - out * out * 40, y: 170 + (70 - 170) * out)
            let cleared = out >= 0.99
            let skin = hex("#F2C9A5"), line = hex("#C9A58A"), airway = hex("#E8C4B0")
            s.circle(150, 60, 34, fill: skin, stroke: line, lw: 2)
            s.rect(110, 96, 100, 170, r: 30, fill: hex("#8FB3E0"), stroke: hex("#5F87B8"), lw: 2)
            s.path("M 150 72 L 160 110 L 162 176", stroke: airway, lw: 14, cap: .round)
            s.path("M 162 176 L 140 200 M 162 176 L 184 200", stroke: airway, lw: 10, cap: .round)
            s.circle(obj.x, obj.y, 8, fill: cleared ? hex("#2E9E5B") : hex("#8A5A2B"))
            s.text(cleared ? "out 排出" : "food 异物", obj.x + 12, obj.y + 4)
            if st == 0 { s.text("Can’t speak, cough or breathe 无法说话、咳嗽、呼吸", 10, 290, size: 11, color: hex("#D8434B")) }
            if st == 1 {
                s.path("M \(250 - press * 12) 150 l 30 -10 l 6 20 l -30 10 Z", fill: hex("#EBB98F"), stroke: line)
                s.text("heel of hand 掌根", 220, 200)
                s.text("between shoulder blades", 220, 214)
                s.text("两肩胛骨之间", 220, 228)
            }
            if st == 2 {
                s.circle(100 + press * 10, 196, 12, fill: hex("#EBB98F"), stroke: line)
                s.path("M \(70 + press * 10) 196 l 18 0", stroke: hex("#555555"), lw: 2)
                s.path("M 116 186 l 10 -12", stroke: hex("#D8434B"), lw: 3)
                s.text("fist above the navel 肚脐上方", 10, 230)
                s.text("pull in and up 向内向上冲击", 10, 244)
            }
            let status = cleared ? hex("#2E9E5B") : hex("#D8434B")
            s.rect(220, 6, 132, 44, r: 8, fill: .white, stroke: status, lw: 2)
            s.text(cleared ? "Airway clear 通畅" : "Blocked 梗阻", 286, 26, size: 12, color: status, anchor: .middle, bold: true)
            if st >= 1 { s.text("\(Int(p[v: "taps"].rounded())) / 5", 286, 42, anchor: .middle) }
        },
        onTap: { p in Int(p[v: "stage"].rounded()) == 2 ? ["dislodge": min(1, p[v: "dislodge"] + 0.2)] : [:] },
        sources: ["Red Cross / ERC adult choking: 5 back blows, 5 abdominal thrusts"]
    )

    static let bleeding = Scenario(
        id: "severe-bleeding", group: .firstAid, title: Bilingual("Severe bleeding", "大出血止血"),
        params: ["pressure": 0, "clot": 0, "bandage": 0, "lost": 0.3],
        steps: [
            .watch("A deep cut is bleeding heavily. Every minute counts.", "深部伤口大量出血，分秒必争。", set: ["pressure": 0, "clot": 0, "bandage": 0, "lost": 0.5]),
            .watch("Call 120/911. Protect your hands if you can (gloves or a plastic bag).", "拨打 120。尽量保护双手（手套或塑料袋）。"),
            .tryIt("Press firmly on the wound with a clean pad — and keep pressing. Don’t lift to peek.",
                   "试一试：用干净敷料用力按压伤口并持续按住，不要松开查看。",
                   TryStep(mode: .hold(param: "pressure", progress: "clot", seconds: 8, label: "HOLD 按住"), success: { $0[v: "clot"] >= 1 },
                           ok: Bilingual("Steady pressure lets a clot form (in real life: at least 10 minutes).", "持续按压让血凝块形成（实际至少 10 分钟）。"))),
            .watch("Soaked through? Add more pads on top — don’t remove the first. Then bandage firmly.",
                   "渗透了？在上面再加敷料，不要取下第一层。然后加压包扎。", set: ["pressure": 1, "clot": 1, "bandage": 1]),
            .watch("If pressure can’t stop life-threatening bleeding on an arm or leg, a tourniquet goes 5–7 cm above the wound. Note the time.",
                   "四肢危及生命的出血按压无效时，在伤口上方 5–7 厘米处使用止血带，并记录时间。"),
        ],
        draw: { s, p, t in
            let pressure = p[v: "pressure"], clot = p[v: "clot"], bandage = p[v: "bandage"]
            let flow = max(0, (1 - pressure * 0.85) * (1 - clot))
            let drops = Int((flow * 10).rounded())
            let wx = 190.0, wy = 150.0
            s.rect(20, 120, 320, 64, r: 30, fill: hex("#F2C9A5"), stroke: hex("#C9A58A"), lw: 2)
            s.text("forearm 前臂", 30, 112, color: hex("#8F7E63"))
            s.path("M \(wx - 22) \(wy) Q \(wx) \(wy - 6) \(wx + 22) \(wy)", stroke: hex("#8A1F2B"), lw: 5)
            for i in 0..<drops {
                let u = (t * 1.4 + Double(i) / Double(drops)).wrap(1)
                s.circle(wx - 10 + Double(i % 3) * 10, wy + 10 + u * 110, 4 - u * 1.5, fill: hex("#C8323C"), opacity: 1 - u * 0.4)
            }
            s.path("M 150 262 Q 190 \(262 - min(1, p[v: "lost"]) * 20) 230 262 Z", fill: hex("#C8323C"), opacity: 0.8)
            if pressure > 0.05 && bandage < 0.5 {
                s.group(opacity: pressure) { g in
                    g.rect(wx - 36, wy - 30 + (1 - pressure) * -20, 72, 40, r: 6, fill: .white, stroke: hex("#BBBBBB"))
                    g.path("M \(wx - 30) \(wy - 40) q 30 -40 60 0", stroke: hex("#EBB98F"), lw: 22, cap: .round)
                    g.text("firm pressure 用力按压", wx + 48, wy - 40)
                }
            }
            if bandage > 0.5 {
                for i in 0..<4 { s.rect(wx - 44 + Double(i) * 4, 122, 80, 60, r: 4, fill: .white, stroke: hex("#DDDDDD"), opacity: 0.9) }
                s.text("bandage over the pad 加压包扎", wx, 200, anchor: .middle)
            }
            let status = flow > 0.3 ? hex("#D8434B") : hex("#2E9E5B")
            s.rect(8, 6, 344, 50, r: 8, fill: .white, stroke: status, lw: 2)
            s.text("Bleeding 出血  \(Int((flow * 100).rounded()))%", 20, 26, size: 12, color: status, bold: true)
            s.text("Clot forming 血凝块  \(Int((clot * 100).rounded()))%", 20, 44, size: 11)
            s.rect(200, 36, 140, 8, r: 4, fill: hex("#EEEEEE"))
            s.rect(200, 36, 140 * clot, 8, r: 4, fill: hex("#2E9E5B"))
        },
        sources: ["ILCOR / Red Cross first aid: direct pressure; tourniquet for life-threatening limb bleeding"]
    )

    static func heatDepth(_ p: Params) -> Double { max(0, 110 * (1 - p[v: "cooling"] * p[v: "minutes"] / 20)) }

    static let burns = Scenario(
        id: "burns", group: .firstAid, title: Bilingual("Burns", "烧烫伤"),
        params: ["minutes": 0, "cooling": 0],
        steps: [
            .watch("Heat keeps travelling into the skin after the burn — the damage deepens for minutes.",
                   "烫伤后热量仍会持续向皮肤深层传导——损伤在几分钟内继续加深。", set: ["minutes": 0, "cooling": 0]),
            .tryIt("Cool it under cool running water. Drag the time — aim for the full 20 minutes.", "试一试：用流动冷水冲洗。拖动时间——目标 20 分钟。",
                   set: ["cooling": 1],
                   TryStep(mode: .scrub([Scrub(param: "minutes", label: "Minutes 分钟", min: 0, max: 20, digits: 0)]), success: { $0[v: "minutes"] >= 19.5 },
                           ok: Bilingual("20 minutes — even up to 3 hours after the burn it still helps.", "20 分钟——即使烫伤 3 小时内冲洗仍有帮助。"), demo: ["minutes": 20])),
            .watch("No ice, butter or toothpaste. Remove rings and watches. Cover loosely with cling film.",
                   "不要用冰、黄油或牙膏。取下戒指手表。用保鲜膜松松覆盖。", set: ["minutes": 20]),
            .watch("See a doctor if it’s bigger than their palm, on the face, hands, feet or genitals, or looks deep.",
                   "面积大于伤者手掌，或位于面部、手足、会阴，或看起来较深——需就医。"),
        ],
        draw: { s, p, t in
            let depth = heatDepth(p), cooled = depth < 8
            for (name, y, h, color) in [("Epidermis 表皮", 90.0, 30.0, "#F5D7BF"), ("Dermis 真皮", 120, 70, "#EFC1A8"), ("Fat 皮下脂肪", 190, 60, "#F7E3A1")] {
                s.rect(40, y, 280, h, fill: hex(color))
                s.text(name, 326, y + h / 2 + 4, size: 9, color: hex("#8F7E63"), anchor: .end)
            }
            s.path("M 120 90 Q 180 \(90 + depth * 2) 240 90 Z", fill: hex("#E0503C"), opacity: 0.75)
            if p[v: "cooling"] > 0.5 {
                for i in 0..<6 {
                    let y = (t * 60 + Double(i) * 13).wrap(50) + 20
                    s.line(110 + Double(i) * 26, y, 110 + Double(i) * 26, y + 12, stroke: hex("#3F95D6"), lw: 3, cap: .round)
                }
            }
            let status = cooled ? hex("#2E9E5B") : hex("#E0503C")
            s.rect(8, 256, 344, 38, r: 8, fill: .white, stroke: status, lw: 2)
            s.text("Cool running water 流动冷水  \(Int((p[v: "minutes"] * p[v: "cooling"]).rounded())) / 20 min", 20, 272, size: 11)
            s.text(cooled ? "Heat drawn out 热量已散出" : "Heat still spreading inward 热量仍在向深层扩散", 20, 287, size: 11, color: status, bold: true)
        },
        sources: ["ILCOR / Red Cross burns first aid: cool with running water for 20 minutes"]
    )
}
