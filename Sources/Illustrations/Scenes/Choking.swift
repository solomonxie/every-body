import SwiftUI

extension Illustrations {
    static func choking(for who: Profile) -> Scenario {
        let infant = who.age == .infant, child = who.age.isChild, chest = who.isPregnant
        let blows = TryStep(mode: .rhythm(target: 5, minRate: 0, maxRate: 9999, label: "BLOW 拍背"), success: { $0[v: "taps"] >= 5 },
                            ok: Bilingual("5 back blows — still stuck? Move on to thrusts.", "拍背 5 次——仍未排出？改用冲击法。"))
        let thrusts = TryStep(mode: .rhythm(target: 5, minRate: 0, maxRate: 9999, label: "THRUST 冲击"), success: { $0[v: "dislodge"] >= 0.99 },
                              ok: Bilingual("Out! Get checked by a doctor after any thrusts.", "排出了！做过冲击后都要就医检查。"))
        let steps: [Step]
        if infant {
            steps = [
                .watch("Baby can’t cry, cough or breathe, and may turn blue? Act now — someone calls 120/911.",
                       "婴儿哭不出、咳不出、无法呼吸，甚至发紫？立即施救，让旁人拨打 120。", set: ["stage": 0, "taps": 0, "dislodge": 0]),
                .tryIt("Sit, baby face down along your forearm on your thigh, head lower than the chest, jaw held. Up to 5 firm back blows.",
                       "试一试：坐下，让婴儿面朝下趴在你搭在大腿上的前臂上，头低于胸，托住下颌。掌根拍背最多 5 次。",
                       set: ["stage": 1, "taps": 0, "dislodge": 0], blows),
                .tryIt("Turn baby face up on your other arm, head still low. Heel of one hand on the centre of the chest: up to 5 firm chest thrusts.",
                       "试一试：把婴儿翻成面朝上，头仍低。单手掌根放在胸部正中，用力按压最多 5 次。",
                       set: ["stage": 2, "taps": 0, "dislodge": 0.2], thrusts),
                .watch("Still blocked? Repeat 5 back blows, 5 chest thrusts. Baby goes limp? Call 120/911 and start baby CPR.",
                       "仍未排出？重复 5 次拍背、5 次胸部按压。婴儿失去反应？拨打 120 并开始婴儿心肺复苏。", set: ["stage": 3, "dislodge": 1]),
            ]
        } else {
            steps = [
                .watch("Hands at the throat, can’t speak, cough or breathe? Ask “Are you choking?” If they can cough, keep them coughing.",
                       "双手掐喉，说不出话、咳不出、无法呼吸？问“你被噎住了吗？”能咳嗽就鼓励用力咳。", set: ["stage": 0, "taps": 0, "dislodge": 0]),
                .tryIt(child ? "Kneel beside the child. Support the chest, lean them forward, up to 5 sharp back blows between the shoulder blades."
                       : "Stand beside and just behind. Support the chest, lean them well forward, up to 5 sharp back blows between the shoulder blades.",
                       child ? "试一试：跪在孩子身旁，一手扶胸使其前倾，另一手掌根在两肩胛骨之间用力拍击，最多 5 次。"
                       : "试一试：站在其侧后方，一手扶胸使其充分前倾，另一手掌根在两肩胛骨之间用力拍击，最多 5 次。",
                       set: ["stage": 1, "taps": 0, "dislodge": 0], blows),
                chest
                    ? .tryIt("Pregnant: arms under the armpits, fist on the lower half of the breastbone, other hand over it — pull straight back, up to 5 times.",
                             "试一试：孕妇双臂从腋下环抱，拳头放在胸骨下半段，另一手握拳，向正后方快速冲击，最多 5 次。",
                             set: ["stage": 2, "taps": 0, "dislodge": 0.2], thrusts)
                    : .tryIt(child ? "Kneel behind, arms round the waist. Fist just above the navel, other hand over it — pull sharply in and up, up to 5 times."
                             : "Stand behind, arms round the waist. Fist just above the navel, other hand over it — pull sharply in and up, up to 5 times.",
                             child ? "试一试：跪在孩子身后双臂环腰，拳头放在肚脐稍上方，另一手握拳，快速向内向上冲击，最多 5 次。"
                             : "试一试：站在其身后双臂环腰，拳头放在肚脐稍上方，另一手握拳，快速向内向上冲击，最多 5 次。",
                             set: ["stage": 2, "taps": 0, "dislodge": 0.2], thrusts),
                .watch("Still blocked? Keep alternating 5 blows and 5 thrusts, and call 120/911. If they go limp: lower to the floor, start CPR.",
                       "仍未排出？交替进行 5 次拍背和 5 次冲击，并拨打 120。若失去反应：放平在地，开始心肺复苏。", set: ["stage": 3, "dislodge": 1]),
            ]
        }
        var s = Scenario(
            id: "choking", group: .firstAid, title: infant ? Bilingual("Choking (baby)", "婴儿气道异物梗阻") : Bilingual("Choking", "气道异物梗阻"),
            params: ["stage": 0, "taps": 0, "rate": 0, "press": 0, "dislodge": 0],
            steps: steps,
            draw: { s, p, t in drawChoking(&s, p, t, who) },
            onTap: { p in Int(p[v: "stage"].rounded()) == 2 ? ["dislodge": min(1, p[v: "dislodge"] + 0.2)] : [:] },
            sources: ["ILCOR 2025 CoSTR; AHA 2025 & ERC 2025 foreign-body airway obstruction: back blows, then abdominal (chest for infants, pregnancy) thrusts; AHA 2025: infant chest thrusts with the heel of one hand",
                      "Red Cross first aid: 5 back blows, 5 thrusts"]
        )
        s.profileNote = switch who.age {
        case .infant: Bilingual("Baby: back blows face down on your forearm, then chest thrusts with the heel of one hand — never abdominal thrusts.",
                                "婴儿：趴在前臂上拍背，再用单手掌根按压胸部——不要做腹部冲击。")
        case .toddler, .child: Bilingual("Child: same steps as adults, but kneel to their height and use a bit less force.",
                               "儿童：步骤同成人，但要跪下与孩子同高，力度稍轻。")
        case .senior: Bilingual("65+: same steps. Thrusts can injure frail ribs and organs — always get checked afterwards.",
                                "老人：步骤相同。冲击可能伤及肋骨和内脏——事后务必就医检查。")
        case .adult where chest: Bilingual("Pregnant: chest thrusts on the breastbone instead of abdominal thrusts (same for very large people).",
                                           "孕妇：改用胸部冲击（按胸骨），不做腹部冲击（体型很大者同样）。")
        case .adult: Bilingual("Adult: back blows, then abdominal thrusts. Pregnant or very large: chest thrusts instead.",
                               "成人：先拍背，再腹部冲击。孕妇或体型很大者：改用胸部冲击。")
        }
        return s
    }

    private static func drawChoking(_ s: inout Sketch, _ p: Params, _ t: Double, _ who: Profile) {
        let st = Int(p[v: "stage"].rounded()), out = min(1, p[v: "dislodge"])
        if who.age == .infant { drawBabyChoking(&s, p, t) } else { drawStandingChoking(&s, p, t, who) }
        if st == 0 || st == 3 { airwayInset(&s, 244, 8, out: out, baby: who.age == .infant) }
        // status pill
        let cleared = out >= 0.99, status = cleared ? hex("#2E9E5B") : hex("#D8434B")
        let n = Int(p[v: "taps"].rounded())
        let en = cleared ? "Airway clear" : st == 1 ? "Blocked · back blows \(n)/5" : st == 2 ? "Blocked · thrusts \(n)/5" : "Airway blocked"
        let zh = cleared ? "气道通畅" : st == 1 ? "梗阻 · 拍背 \(n)/5" : st == 2 ? "梗阻 · 冲击 \(n)/5" : "气道梗阻"
        let txt = s.ctx.resolve(Text(s.t(en, zh)).font(.system(size: 11, weight: .bold)))
        let w = txt.measure(in: CGSize(width: 300, height: 40)).width + 28
        s.rect(8, 8, w, 26, r: 13, fill: .white, stroke: status, lw: 2)
        s.circle(21, 21, 4, fill: status)
        s.label(en, zh, 30, 21, size: 11, color: status, bold: true)
    }

    private static func drawStandingChoking(_ s: inout Sketch, _ p: Params, _ t: Double, _ who: Profile) {
        let st = Int(p[v: "stage"].rounded()), press = p[v: "press"]
        let kneel = who.age.isChild, chestThrust = who.isPregnant
        let floor = 288.0
        s.room(floor: floor)
        let rh = kneel ? 300.0 : 238
        let c = Casualty(who, adult: kneel ? 290 : 232)
        var v = SideFigure(h: c.h, build: c.build, look: c.look, hip: .zero, face: st == 3 ? .open : .distress, bump: c.bump)
        v.hip = CGPoint(x: kneel ? 180 : 176, y: floor - SideFigure.hipHeight(c.h, c.build))
        v.nearLeg = .init(hip: 4, knee: 2)
        v.farLeg = .init(hip: -4, knee: 2)
        var r = SideFigure(h: rh, hip: .zero, face: .calm)
        func place(_ x: Double) {
            if kneel {
                // high kneel on one knee, the other foot planted
                r.farLeg = .init(hip: 2, knee: 92, point: 88)
                r.nearLeg = .init(hip: 84, knee: 86, point: 4)
                r.hip = CGPoint(x: x, y: floor - r.build.thigh * rh - r.build.legW * rh * 0.5)
            } else {
                r.nearLeg = .init(hip: 16, knee: 6)
                r.farLeg = .init(hip: -10, knee: 2)
                r.hip = CGPoint(x: x, y: 0)
                r.hip.y = r.hipY(onFloor: floor)
            }
        }
        switch st {
        case 1:
            // leaning well forward; rescuer beside and behind, one hand across the chest
            // bent over far enough that the head is below the chest, so the object can fall out
            v.hip.x -= 34
            v.lean = 80
            v.headTilt = 32
            v.near = .init(shoulder: -66, elbow: 14)
            v.far = .init(shoulder: -62, elbow: 18)
            v.nearLeg = .init(hip: -6, knee: 4)
            v.farLeg = .init(hip: -12, knee: 2)
            place(v.hip.x - (kneel ? 46 : 58))
            r.lean = kneel ? 14 : 28
            r.far = .init(reach: lerp(v.front(0.74), v.torso(0, 0.74), 0.3), hand: .open, handAngle: 0)
            let blades = v.back(0.8), n = unit(CGPoint(x: blades.x - v.torso(0, 0.8).x, y: blades.y - v.torso(0, 0.8).y))
            let gap = 2 + (1 - press) * 18
            let along = v.torso(0, 1).x - v.torso(0, 0).x, alongY = v.torso(0, 1).y - v.torso(0, 0).y
            r.near = .init(reach: CGPoint(x: blades.x + n.x * gap, y: blades.y + n.y * gap), hand: .open, handAngle: atan2(alongY, along) * 180 / .pi)
        case 2:
            v.lean = 18
            v.near = .init(shoulder: 20, elbow: 30)
            v.far = .init(shoulder: 14, elbow: 34)
            place(v.hip.x - (kneel ? 30 : 30))
            r.lean = kneel ? 4 : 4
            r.headTilt = 8
            let f = chestThrust ? 0.62 : 0.36
            let fist = lerp(v.front(f), v.torso(0, f), 0.08 + press * 0.12)
            let lift = chestThrust ? 0 : press * 5
            r.near = .init(reach: CGPoint(x: fist.x + 1, y: fist.y - lift), hand: .fist, handAngle: chestThrust ? 180 : 200)
            r.far = .init(reach: CGPoint(x: fist.x + 4, y: fist.y - lift - 2), hand: .open, handAngle: 100)
        default:
            // hands at the throat (0), or coughing it up (3)
            if st == 0 {
                v.near = .init(reach: v.headPoint(0.35, 1.35), hand: .open, handAngle: -70)
                v.far = .init(reach: v.headPoint(0.15, 1.45), hand: .open, handAngle: -80)
            } else {
                v.lean = 20
                v.headTilt = 12
                v.near = .init(reach: v.headPoint(1.3, 0.8), hand: .fist)
                v.far = .init(shoulder: 5, elbow: 15)
            }
            place(v.hip.x - (kneel ? 62 : 72))
            r.lean = kneel ? 4 : 6
            r.near = .init(reach: v.back(0.9), hand: .open)
            r.far = .init(shoulder: 5, elbow: 15)
        }
        r.drawBack(&s)
        r.drawBody(&s)
        if st == 1 || st == 2 { r.drawArm(&s, near: false) }
        v.draw(&s)
        r.drawArm(&s, near: true)
        // back blows: the supporting hand, seen under the chest
        let support = lerp(v.torso(0, 0.72), v.front(0.72), 1.12)
        if st == 1 {
            drawHand(&s, at: support, dir: unit(CGPoint(x: 1, y: -0.15)), len: r.build.hand * rh, shape: .open, look: r.look, thumb: 1)
        }
        if st == 2 && !chestThrust {
            // the far hand grasping the fist, seen round the front
            drawHand(&s, at: CGPoint(x: r.palm().x + 3, y: r.palm().y - 3), dir: unit(CGPoint(x: 0.3, y: 1)), len: r.build.hand * rh, shape: .open,
                     look: r.look, thumb: 1)
        }

        let red = hex("#D8434B"), green = hex("#2E9E5B")
        switch st {
        case 0:
            let m = r.mouth
            s.bubble("Are you choking?", "你被噎住了吗？", m.x - 30, max(54, m.y - 40), tip: CGPoint(x: m.x + 2, y: m.y - 6))
            s.callout("hands at the throat", "双手掐喉", 296, 170, to: v.headPoint(0.4, 1.5), color: red)
            s.tag("can’t speak, cough or breathe", "说不出、咳不出、喘不上", 296, 196, size: 9, color: red, bold: true, width: 110)
        case 1:
            let b = v.back(0.8)
            s.callout("heel of hand, between the shoulder blades", "掌根拍两肩胛骨之间", 250, 44, to: CGPoint(x: b.x + 2, y: b.y - 2), color: red, width: 140)
            s.callout("other hand supports the chest", "另一手扶住胸部", 270, 272, to: support, color: hex("#555555"))
            s.tag("head lower than chest", "头低于胸部", v.headPoint(0, 0).x + 10, v.headPoint(0, 0).y + 52, size: 9, bold: true)
            // blow direction
            let from = CGPoint(x: b.x - 26, y: b.y - 30), to = CGPoint(x: b.x - 8, y: b.y - 10)
            s.arrow(lerp(from, to, press * 0.4), lerp(from, to, 0.5 + press * 0.5), color: red, lw: 2)
        case 2:
            fistCard(&s, 238, 8, chest: chestThrust)
            let f = v.front(chestThrust ? 0.62 : 0.36)
            if chestThrust {
                s.arrow(CGPoint(x: f.x + 26, y: f.y), CGPoint(x: f.x + 8, y: f.y), color: red, lw: 2.2)
                s.tag("pull straight back", "向正后方冲击", 296, 150, size: 10, color: red, bold: true)
            } else {
                s.path("M \(f.x + 26) \(f.y + 14) Q \(f.x + 8) \(f.y + 12) \(f.x + 6) \(f.y - 6)", stroke: red, lw: 2.2, cap: .round)
                s.arrow(CGPoint(x: f.x + 7, y: f.y - 2), CGPoint(x: f.x + 5, y: f.y - 12), color: red, lw: 2.2)
                s.tag("pull sharply in and up", "快速向内、向上冲击", 296, 150, size: 10, color: red, bold: true)
            }
        case 3:
            s.phone(322, floor - 30, number: s.t("911", "120"), t: t)
            s.tag("coughed out — still see a doctor", "咳出了——仍需就医", 296, 144, size: 10, color: green, bold: true, width: 110)
            s.tag("still stuck: 5 + 5 again, call 120", "仍梗阻：再 5+5，拨打 120", 296, 184, size: 9, color: red, bold: true, width: 110)
            s.tag("goes limp: floor, CPR", "失去反应：放平做心肺复苏", 296, 214, size: 9, color: red, bold: true, width: 110)
        default: break
        }
    }

    /// front view of the trunk: where the fist goes, thumb side in, other hand over it
    private static func fistCard(_ s: inout Sketch, _ x: Double, _ y: Double, chest: Bool) {
        let w = 114.0, h = 112.0
        s.inset(x, y, w, h, chest ? "Fist on breastbone" : "Fist above the navel", chest ? "拳头放在胸骨下半段" : "拳头放在肚脐上方")
        let cx = x + w / 2, top = y + 24
        let skin = hex("#F6D8BF"), edge = hex("#D1A98A"), bone = hex("#D9CBA8")
        var g = s.clipped(x, y + 18, w, h - 18)
        // neck, shoulders, waist, hips
        g.rect(cx - 7, top - 10, 14, 14, fill: skin, stroke: edge)
        let body = [(-0.2, 0.0), (-0.8, 0.06), (-1.0, 0.2), (-0.86, 0.5), (-0.74, 0.72), (-0.84, 1.1), (0.84, 1.1), (0.74, 0.72), (0.86, 0.5),
                    (1.0, 0.2), (0.8, 0.06), (0.2, 0.0)].map { CGPoint(x: cx + $0.0 * 42, y: top + $0.1 * 84) }
        g.shape(smoothPath(body), fill: skin, stroke: edge, lw: 1.2)
        // collarbones, breastbone, the lower edge of the ribs, navel
        g.path("M \(cx - 30) \(top + 7) Q \(cx - 14) \(top + 4) \(cx - 3) \(top + 8) M \(cx + 30) \(top + 7) Q \(cx + 14) \(top + 4) \(cx + 3) \(top + 8)",
               stroke: bone, lw: 1.4, cap: .round)
        let sb = top + 40
        g.rect(cx - 3, top + 9, 6, sb - top - 9, r: 3, fill: bone.opacity(0.6), stroke: bone, lw: 0.8)
        g.path("M \(cx - 34) \(sb + 12) Q \(cx - 18) \(sb + 6) \(cx - 4) \(sb + 1) M \(cx + 34) \(sb + 12) Q \(cx + 18) \(sb + 6) \(cx + 4) \(sb + 1)",
               stroke: bone, lw: 1.4, cap: .round)
        let navel = CGPoint(x: cx, y: top + 68)
        g.ellipse(navel.x, navel.y, 1.8, 2.6, fill: hex("#C98C7A"))
        let fc = chest ? CGPoint(x: cx, y: top + 30) : CGPoint(x: cx, y: (sb + navel.y) / 2 + 4)
        let look = Look.rescuer
        drawHand(&g, at: CGPoint(x: fc.x - 5, y: fc.y), dir: CGPoint(x: 1, y: 0), len: 24, shape: .fist, look: look, thumb: -1)
        drawHand(&g, at: CGPoint(x: fc.x + 9, y: fc.y + 1), dir: CGPoint(x: -1, y: 0.1), len: 24, shape: .open, look: look, thumb: -1)
        if !chest { g.label("navel", "肚脐", navel.x + 5, navel.y + 7, size: 8, color: hex("#8A8378")) }
    }

    private static func drawBabyChoking(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let st = Int(p[v: "stage"].rounded()), press = p[v: "press"]
        let floor = 306.0
        s.room(floor: floor)
        let rh = 380.0
        // rescuer sits on a chair, facing right; forearm rests on the thigh
        var r = SideFigure(h: rh, hip: CGPoint(x: 62, y: floor - 0.27 * rh), lean: 28, headTilt: 22)
        r.nearLeg = .init(hip: 90, knee: 90)
        r.farLeg = .init(hip: 86, knee: 84)
        let seat = r.hip.y + r.build.legW * rh * 0.5
        s.rect(r.hip.x - 34, seat, 64, 7, r: 2, fill: hex("#A07850"))
        s.rect(r.hip.x - 34, seat - 78, 7, 78, r: 2, fill: hex("#8C6844"))
        for x in [r.hip.x - 32, r.hip.x + 22] { s.rect(x, seat + 6, 6, floor - seat - 6, fill: hex("#8C6844")) }

        let knee = CGPoint(x: r.hip.x + r.build.thigh * rh, y: r.hip.y)
        let lap = r.build.legW * rh * 0.5
        let palm = CGPoint(x: knee.x + 8, y: knee.y - lap - 4)
        let elbowGuess = CGPoint(x: r.hip.x + 30, y: r.hip.y - lap - 34)
        let dir = unit(CGPoint(x: palm.x - elbowGuess.x, y: palm.y - elbowGuess.y))
        let slope = atan2(dir.y, dir.x) * 180 / .pi
        r.near = .init(reach: palm, hand: .open, handAngle: slope)

        let bh = rh * 0.38
        let prone = st == 1
        var b = SideFigure(h: bh, build: .infant, look: .baby, hip: .zero, face: st == 3 ? .open : .distress)
        b.facing = prone ? 1 : -1
        b.rotation = prone ? 90 + slope : -(90 + slope)
        b.headTilt = 0
        b.nearLeg = .init(hip: 50, knee: 60, point: 30)
        b.farLeg = .init(hip: 40, knee: 50, point: 30)
        b.near = .init(shoulder: prone ? 70 : 30, elbow: 30)
        b.far = .init(shoulder: prone ? 60 : 20, elbow: 40)
        // body lies along the forearm, head just past the hand
        let up = CGPoint(x: dir.y, y: -dir.x)
        let back = (Build.infant.torso + Build.infant.neck + Build.infant.headR * 0.9) * bh
        let lift = Build.infant.depth * bh * 0.5 + 5
        b.hip = CGPoint(x: palm.x - dir.x * back + up.x * lift + 6, y: palm.y - dir.y * back + up.y * lift)

        switch st {
        case 1:
            let blades = b.back(0.78), n = unit(CGPoint(x: blades.x - b.torso(0, 0.78).x, y: blades.y - b.torso(0, 0.78).y))
            let gap = 1 + (1 - press) * 14
            r.far = .init(reach: CGPoint(x: blades.x + n.x * gap, y: blades.y + n.y * gap), hand: .open, handAngle: slope)
        case 2:
            // heel of one hand on the breastbone, fingers lifted off toward the tummy
            let chest = b.front(0.66), n = unit(CGPoint(x: chest.x - b.torso(0, 0.66).x, y: chest.y - b.torso(0, 0.66).y))
            let gap = 3 + (1 - press) * 8, L = r.build.hand * rh
            let c = CGPoint(x: chest.x + n.x * (gap + 3) - dir.x * L * 0.4, y: chest.y + n.y * (gap + 3) - dir.y * L * 0.4)
            r.far = .init(reach: c, hand: .open, handAngle: slope + 180 - 8)
        default:
            r.far = .init(reach: b.front(0.3), hand: .open, handAngle: slope)
        }
        r.drawBack(&s, farArm: false)
        r.drawBody(&s)
        r.drawArm(&s, near: true)
        b.draw(&s)
        r.drawArm(&s, near: false)

        let red = hex("#D8434B")
        switch st {
        case 0:
            s.callout("can’t cry, cough or breathe", "哭不出、咳不出、喘不上", 296, 170, to: b.mouth, color: red, width: 110)
            s.tag("lips may turn blue", "嘴唇可能发紫", 296, 200, size: 9, bold: true)
        case 1:
            let blades = b.back(0.78)
            s.callout("heel of hand, between the shoulder blades", "掌根拍两肩胛骨之间", 290, 60, to: blades, color: red, width: 120)
            s.callout("head lower than chest", "头低于胸", 300, 250, to: b.headCentre, color: hex("#444444"))
            s.callout("hold the jaw, not the throat", "托住下颌，别压喉咙", 110, 280, to: r.palm(), color: hex("#444444"), width: 150)
        case 2:
            s.callout("heel of one hand, centre of the chest", "单手掌根，胸部正中", 290, 60, to: b.front(0.6), color: red, width: 120)
            s.callout("head lower than chest", "头低于胸", 300, 250, to: b.headCentre, color: hex("#444444"))
        case 3:
            s.phone(330, 250, number: s.t("911", "120"), t: t)
            s.tag("goes limp: call and start baby CPR", "失去反应：呼救并开始婴儿心肺复苏", 290, 190, size: 10, color: red, bold: true, width: 110)
        default: break
        }
    }

    /// head and neck cut open: mouth → throat → windpipe, with the stuck piece of food
    private static func airwayInset(_ s: inout Sketch, _ x: Double, _ y: Double, out: Double, baby: Bool) {
        s.inset(x, y, 108, 112, "Airway", "气道")
        var g = s.clipped(x, y + 16, 108, 96)
        let look: Look = baby ? .baby : .man
        let r = 26.0, c = CGPoint(x: x + 46, y: y + 50), up = CGPoint(x: 0, y: -1)
        let neckTop = headSpot(c, up: up, r: r, 0.05, 0.85)
        g.limb([neckTop, CGPoint(x: neckTop.x - 4, y: y + 130)], w: r * 0.95, fill: look.skin, line: look.skinLine)
        drawSideHead(&g, at: c, up: up, r: r, look: look, face: out >= 0.99 ? .open : .distress, baby: baby)
        let mouth = headSpot(c, up: up, r: r, 0.9, 0.58), throat = headSpot(c, up: up, r: r, 0.05, 0.62)
        let larynx = headSpot(c, up: up, r: r, 0.25, 1.1), bottom = CGPoint(x: larynx.x - 4, y: y + 118)
        // food pipe behind, windpipe in front
        g.line(throat.x - 6, throat.y + 4, bottom.x - 10, bottom.y, stroke: hex("#D9A08C"), lw: 5, cap: .round)
        g.path("M \(mouth.x) \(mouth.y) Q \(throat.x + 6) \(throat.y - 6) \(throat.x) \(throat.y + 6) L \(larynx.x) \(larynx.y) L \(bottom.x) \(bottom.y)",
               stroke: hex("#E58E8E"), lw: 6, cap: .round)
        for i in 0..<3 { g.line(larynx.x - 4, larynx.y + 8 + Double(i) * 6, larynx.x + 3, larynx.y + 8 + Double(i) * 6, stroke: hex("#C86A6A"), lw: 1) }
        let o = CGPoint(x: larynx.x + (mouth.x + 18 - larynx.x) * out, y: larynx.y + (mouth.y - larynx.y) * out - out * (1 - out) * 40)
        g.circle(o.x, o.y, 5.5, fill: out >= 0.99 ? hex("#2E9E5B") : hex("#8A5A2B"), stroke: hex("#5A3A1B"), lw: 0.8)
        if out < 0.99 {
            g.label("stuck", "卡住", larynx.x + 10, larynx.y + 4, size: 8, color: hex("#8A5A2B"), bold: true)
        } else {
            g.label("out", "排出", o.x - 6, o.y - 9, size: 8, color: hex("#2E9E5B"), bold: true)
        }
        g.label("windpipe", "气管", x + 60, y + 106, size: 8)
    }
}
