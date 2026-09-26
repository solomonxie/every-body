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
            let cleared = out >= 0.99
            let floor = 290.0, h = 230.0
            // casualty faces right; bent forward for back blows, upright for abdominal thrusts
            let lean = st == 1 ? 40.0 : 8
            let hip = CGPoint(x: 170, y: floor - 0.49 * h)
            let casualty = Person(h: h, shirt: hex("#DCE6F2"), shirtLine: hex("#9FB3CC"), lean: lean,
                                  shoulder: st == 0 ? 35 : 20, elbow: st == 0 ? 125 : 30)
            func local(_ x: Double, _ y: Double) -> CGPoint {
                let a = lean * .pi / 180
                return CGPoint(x: hip.x + x * cos(a) - y * sin(a), y: hip.y + x * sin(a) + y * cos(a))
            }
            let rescuerHip = CGPoint(x: hip.x - (st == 1 ? 75 : 45), y: hip.y)
            let reachLength = 0.33 * h
            func shoulderOf(_ lean: Double) -> CGPoint {
                let a = lean * .pi / 180
                return CGPoint(x: rescuerHip.x + 0.29 * h * sin(a), y: rescuerHip.y - 0.29 * h * cos(a))
            }
            if st == 1 {
                // rescuer beside and behind, arm swung to the upper back
                let target = local(-0.075 * h, -0.24 * h)
                let sh = shoulderOf(15)
                let angle = atan2(target.x - sh.x, target.y - sh.y) * 180 / .pi
                let rescuer = Person(h: h, lean: 15, shoulder: angle - 15, elbow: 0)
                let dx = target.x - (sh.x + sin(angle * .pi / 180) * reachLength)
                rescuer.draw(&s, at: CGPoint(x: rescuerHip.x + dx, y: rescuerHip.y))
            }
            if st == 2 {
                Person(h: h, lean: 10, shoulder: 60, elbow: 30).draw(&s, at: rescuerHip, farArm: false)
            }
            casualty.draw(&s, at: hip)
            if st == 2 {
                // the rescuer's near arm wraps round the casualty's waist to the fist
                let fist = local(0.07 * h, -0.08 * h)
                let sh = shoulderOf(10)
                let elbow = CGPoint(x: (sh.x + fist.x) / 2 - 6, y: fist.y - 2)
                s.line(sh.x, sh.y, elbow.x, elbow.y, stroke: hex("#8FB3E0"), lw: 0.045 * h, cap: .round)
                s.line(elbow.x, elbow.y, fist.x, fist.y, stroke: hex("#F2C9A5"), lw: 0.036 * h, cap: .round)
            }
            // airway: mouth → throat → windpipe, with the object lodged in it
            let mouth = local(0.06 * h, -0.39 * h), larynx = local(0.02 * h, -0.34 * h), trachea = local(0.01 * h, -0.25 * h)
            s.path("M \(mouth.x) \(mouth.y) Q \(larynx.x + 6) \(larynx.y - 10) \(larynx.x) \(larynx.y) L \(trachea.x) \(trachea.y)", stroke: hex("#E8B4A0"), lw: 7, cap: .round)
            let obj = CGPoint(x: larynx.x + (mouth.x + 26 - larynx.x) * out, y: larynx.y + (mouth.y - 4 - larynx.y) * out - out * (1 - out) * 30)
            s.circle(obj.x, obj.y, 6, fill: cleared ? hex("#2E9E5B") : hex("#8A5A2B"))
            s.text(cleared ? "out 排出" : "food 异物", obj.x + 10, obj.y - 6, size: 9)
            s.line(0, floor, 360, floor, stroke: hex("#BBBBBB"), lw: 2)
            if st == 1 {
                // heel of the hand between the shoulder blades
                let blades = local(-0.075 * h, -0.24 * h)
                s.path("M \(blades.x - 24 - press * 8) \(blades.y - 30) L \(blades.x - 8) \(blades.y - 12)", stroke: hex("#D8434B"), lw: 2.5, cap: .round)
                s.text("heel of hand, between shoulder blades", 10, 60, size: 10)
                s.text("掌根拍击两肩胛骨之间 · lean them well forward 身体前倾", 10, 74, size: 10)
            }
            if st == 2 {
                // fist above the navel, below the breastbone; pull in and up
                let fist = local(0.07 * h, -0.08 * h)
                s.circle(fist.x + press * 4, fist.y, 9, fill: hex("#EBB98F"), stroke: hex("#C9A58A"))
                s.path("M \(fist.x + 18) \(fist.y + 10) L \(fist.x + 6) \(fist.y - 8)", stroke: hex("#D8434B"), lw: 2.5, cap: .round)
                s.path("M \(fist.x + 2) \(fist.y - 14) l -3 6 l 6 0 Z", fill: hex("#D8434B"))
                s.text("fist above the navel, below the ribs 肚脐上方、肋下", 10, 60, size: 10)
                s.text("pull sharply in and up 向内向上快速冲击", 10, 74, size: 10)
            }
            if st == 0 { s.text("Can’t speak, cough or breathe 无法说话、咳嗽、呼吸 · hands at throat", 10, 60, size: 10, color: hex("#D8434B")) }
            let status = cleared ? hex("#2E9E5B") : hex("#D8434B")
            s.rect(220, 6, 132, 38, r: 8, fill: .white, stroke: status, lw: 2)
            s.text(cleared ? "Airway clear 通畅" : "Blocked 梗阻", 286, 24, size: 12, color: status, anchor: .middle, bold: true)
            if st >= 1 { s.text("\(Int(p[v: "taps"].rounded())) / 5", 286, 38, anchor: .middle) }
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
            // skin cross-section, true proportions: thin epidermis, thick dermis, fat, then muscle
            let depth = heatDepth(p)
            let top = 70.0, epi = 80.0, derm = 150.0, fat = 220.0, bottom = 246.0
            s.rect(20, top, 300, epi - top, fill: hex("#F5D7BF"))
            s.rect(20, epi, 300, derm - epi, fill: hex("#EFC1A8"))
            s.rect(20, derm, 300, fat - derm, fill: hex("#F7E3A1"))
            for k in 0..<10 { s.circle(35 + Double(k) * 30, derm + 18 + Double(k % 2) * 30, 14, fill: hex("#F2D98A"), stroke: hex("#E6C66E"), lw: 0.8) }
            s.rect(20, fat, 300, bottom - fat, fill: hex("#C1443C"))
            for k in 0..<6 { s.line(20, fat + 4 + Double(k) * 4, 320, fat + 4 + Double(k) * 4, stroke: hex("#A8352E"), lw: 0.6) }
            // hair follicle, sweat gland, capillary loops, nerve ending
            s.path("M 70 40 L 90 \(top) L 104 128", stroke: hex("#5A3A2A"), lw: 2)
            s.path("M 96 104 C 90 112, 94 132, 106 134 C 116 134, 118 118, 110 104", fill: hex("#E4B7A0"), stroke: hex("#B98A74"))
            s.path("M 262 \(top) C 258 100, 266 120, 260 140 C 254 146, 270 150, 262 156 C 254 150, 250 144, 262 140", stroke: hex("#6FA8C8"), lw: 1.5)
            for x in [150.0, 190, 226] { s.path("M \(x) \(derm - 20) C \(x) 88, \(x + 10) 88, \(x + 10) \(derm - 20)", stroke: hex("#C8323C"), lw: 1.5) }
            s.path("M 300 \(derm - 10) C 290 120, 300 100, 292 86", stroke: hex("#E8B923"), lw: 1.5)
            // heat front, then the burn classes it has reached
            let reach = depth * 1.45
            if depth > 1 { s.path("M 120 \(top) C 130 \(top + reach), 230 \(top + reach), 240 \(top) Z", fill: hex("#E0503C"), opacity: 0.55) }
            if depth > 20 { s.path("M 130 \(top) C 150 \(top - 16), 210 \(top - 16), 230 \(top)", fill: hex("#FFF6EA"), stroke: hex("#E0B89A")) }
            let classes: [(String, Double, Double)] = [("superficial 浅表（I度）", top, epi), ("partial thickness 部分皮层（II度）", epi, derm), ("full thickness 全层（III度）", derm, fat)]
            for (name, y0, y1) in classes {
                s.line(324, y0 + 1, 324, y1 - 1, stroke: hex("#999999"))
                s.text(name, 318, (y0 + y1) / 2 + 3, size: 7, anchor: .end)
            }
            s.text("epidermis 表皮", 24, top + 8, size: 7)
            s.text("dermis 真皮", 24, epi + 12, size: 7)
            s.text("fat 皮下脂肪", 24, derm + 12, size: 7)
            s.text("muscle 肌肉", 24, fat + 14, size: 7, color: .white)
            s.text("hair 毛囊", 60, 36, size: 7)
            s.text("sweat gland 汗腺", 226, 166, size: 7)
            if p[v: "cooling"] > 0.5 {
                for i in 0..<6 {
                    let y = (t * 60 + Double(i) * 13).wrap(40) + 10
                    s.line(110 + Double(i) * 26, y, 110 + Double(i) * 26, y + 12, stroke: hex("#3F95D6"), lw: 3, cap: .round)
                }
            }
            let cooled = depth < 8
            let reached = depth < 1 ? "none 无" : top + reach * 0.75 < epi ? "superficial 浅表" : top + reach * 0.75 < derm ? "partial 部分皮层" : "full thickness 全层"
            let status = cooled ? hex("#2E9E5B") : hex("#E0503C")
            s.rect(8, 256, 344, 38, r: 8, fill: .white, stroke: status, lw: 2)
            s.text("Cooling 冷水冲洗 \(Int((p[v: "minutes"] * p[v: "cooling"]).rounded())) / 20 min · heat reaches 热损伤深度: \(reached)", 18, 272, size: 10)
            s.text(cooled ? "Heat drawn out 热量已散出" : "Heat still spreading inward 热量仍在向深层扩散", 18, 287, size: 11, color: status, bold: true)
        },
        sources: ["ILCOR / Red Cross burns first aid: cool with running water for 20 minutes"]
    )
}
