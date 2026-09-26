import SwiftUI

extension Illustrations {
    static func choking(for who: Profile) -> Scenario {
        let infant = who.age == .infant, child = who.age == .child, chest = who.isPregnant
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
                .tryIt("Turn baby face up on your other arm, head still low. 2 fingers just below the nipple line: up to 5 sharp chest thrusts.",
                       "试一试：把婴儿翻成面朝上，头仍低。两指放在乳头连线下方的胸骨上，快速按压最多 5 次。",
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
            sources: ["ILCOR 2025 CoSTR; AHA 2025 & ERC 2025 foreign-body airway obstruction: back blows, then abdominal (chest for infants, pregnancy) thrusts",
                      "Red Cross first aid: 5 back blows, 5 thrusts"]
        )
        s.profileNote = switch who.age {
        case .infant: Bilingual("Baby: back blows face down on your forearm, then 2-finger chest thrusts — never abdominal thrusts.",
                                "婴儿：趴在前臂上拍背，再用两指按压胸部——不要做腹部冲击。")
        case .child: Bilingual("Child: same steps as adults, but kneel to their height and use a bit less force.",
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
        airwayInset(&s, 244, 8, out: out, baby: who.age == .infant)
        let cleared = out >= 0.99, status = cleared ? hex("#2E9E5B") : hex("#D8434B")
        s.rect(8, 8, 118, 40, r: 8, fill: .white, stroke: status, lw: 2)
        s.label(cleared ? "Airway clear" : "Blocked", cleared ? "气道通畅" : "气道梗阻", 67, 26, size: 12, color: status, anchor: .middle, bold: true)
        if st == 1 || st == 2 {
            s.label("\(Int(p[v: "taps"].rounded())) / 5", "\(Int(p[v: "taps"].rounded())) / 5 次", 67, 41, size: 10, anchor: .middle)
        }
    }

    private static func drawStandingChoking(_ s: inout Sketch, _ p: Params, _ t: Double, _ who: Profile) {
        let st = Int(p[v: "stage"].rounded()), press = p[v: "press"]
        let child = who.age == .child, chestThrust = who.isPregnant
        let floor = 278.0
        s.room(floor: floor)
        let c = Casualty(who, adult: 206)
        var v = SideFigure(h: c.h, build: c.build, look: c.look, hip: .zero, face: st == 3 ? .open : .distress, bump: c.bump)
        v.hip = CGPoint(x: child ? 196 : 190, y: floor - SideFigure.hipHeight(c.h, c.build))
        v.nearLeg = .init(hip: 4, knee: 2)
        v.farLeg = .init(hip: -4, knee: 2)
        let rh = 210.0
        var r = SideFigure(h: rh, hip: .zero)
        let kneel = child
        func place(_ x: Double) {
            if kneel {
                r.farLeg = .init(hip: 0, knee: 90, point: 90)
                r.nearLeg = .init(hip: 80, knee: 82)
                r.hip = CGPoint(x: x, y: floor - r.build.thigh * rh - r.build.legW * rh * 0.5)
            } else {
                r.nearLeg = .init(hip: 12, knee: 4)
                r.farLeg = .init(hip: -8, knee: 2)
                r.hip = CGPoint(x: x, y: floor - SideFigure.hipHeight(rh, r.build))
            }
        }
        switch st {
        case 1:
            // leaning well forward; rescuer beside and behind, one hand across the chest
            v.lean = 48
            v.headTilt = -25
            v.near = .init(shoulder: -40, elbow: 12)
            v.far = .init(shoulder: -36, elbow: 16)
            place(v.hip.x - (kneel ? 40 : 52))
            r.lean = kneel ? 10 : 22
            r.far = .init(reach: lerp(v.front(0.8), v.torso(0, 0.8), 0.15), hand: .open)
            let blades = v.back(0.8), n = unit(CGPoint(x: blades.x - v.torso(0, 0.8).x, y: blades.y - v.torso(0, 0.8).y))
            let gap = 2 + (1 - press) * 16
            let along = v.torso(0, 1).x - v.torso(0, 0).x, alongY = v.torso(0, 1).y - v.torso(0, 0).y
            r.near = .init(reach: CGPoint(x: blades.x + n.x * gap, y: blades.y + n.y * gap), hand: .open,
                           handAngle: atan2(alongY, along) * 180 / .pi)
        case 2:
            v.lean = 10
            v.near = .init(shoulder: 8, elbow: 25)
            v.far = .init(shoulder: 12, elbow: 30)
            place(v.hip.x - (kneel ? 30 : 32))
            r.lean = kneel ? 6 : 12
            let f = chestThrust ? 0.66 : 0.34
            let fist = lerp(v.front(f), v.torso(0, f), 0.1 + press * 0.12)
            let lift = chestThrust ? 0 : press * 4
            r.near = .init(reach: CGPoint(x: fist.x, y: fist.y - lift), hand: .fist)
            r.far = .init(reach: CGPoint(x: fist.x + 3, y: fist.y - lift - 3), hand: .open)
        default:
            // hands at the throat (0), or coughing it up (3)
            if st == 0 {
                v.near = .init(reach: v.headPoint(0.35, 1.3), hand: .open, handAngle: -60)
                v.far = .init(reach: v.headPoint(0.2, 1.4), hand: .open, handAngle: -70)
            } else {
                v.lean = 18
                v.headTilt = 10
                v.near = .init(reach: v.headPoint(1.25, 0.75), hand: .fist)
                v.far = .init(shoulder: 5, elbow: 15)
            }
            place(v.hip.x - (kneel ? 58 : 70))
            r.lean = kneel ? 4 : 6
            r.near = .init(reach: v.back(0.9), hand: .open)
            r.far = .init(shoulder: 5, elbow: 15)
        }
        r.drawBack(&s)
        r.drawBody(&s)
        if st == 1 || st == 2 { r.drawArm(&s, near: false) }
        v.draw(&s)
        r.drawArm(&s, near: true)

        let red = hex("#D8434B")
        switch st {
        case 0:
            let m = r.mouth
            s.bubble("Are you choking?", "你被噎住了吗？", m.x - 30, m.y - 36, tip: CGPoint(x: m.x + 2, y: m.y - 4))
            s.tag("can’t speak, cough or breathe", "说不出、咳不出、喘不上", 296, 150, size: 10, color: red, bold: true, width: 110)
        case 1:
            let b = v.back(0.8)
            s.tag("heel of hand, between the shoulder blades", "掌根拍两肩胛骨之间", b.x - 40, b.y - 72, size: 10, color: red, bold: true, width: 120)
            s.tag("head lower than chest", "头低于胸部", v.headPoint(0, 0).x + 44, v.headPoint(0, 0).y + 38, size: 9, width: 90)
        case 2:
            let f = v.front(chestThrust ? 0.66 : 0.34)
            if chestThrust {
                s.tag("fist on the lower breastbone, pull straight back", "拳头放在胸骨下半段，向后冲击", 296, 150, size: 10, color: red, bold: true, width: 110)
                s.arrow(CGPoint(x: f.x + 18, y: f.y - 2), CGPoint(x: f.x + 4, y: f.y - 2))
            } else {
                s.tag("fist above the navel, pull in and up", "拳在肚脐上方，向内向上", 296, 150, size: 10, color: red, bold: true, width: 100)
                s.arrow(CGPoint(x: f.x + 18, y: f.y + 8), CGPoint(x: f.x + 4, y: f.y - 8))
            }
        case 3:
            s.phone(318, floor - 26, number: s.t("911", "120"), t: t)
            s.tag("coughed out — see a doctor", "咳出了——仍需就医", 296, 144, size: 10, color: hex("#2E9E5B"), bold: true, width: 110)
            s.tag("still stuck: call · goes limp: CPR", "仍梗阻：呼救 · 失去反应：心肺复苏", 272, 200, size: 10, color: red, bold: true, width: 120)
        default: break
        }
    }

    private static func drawBabyChoking(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let st = Int(p[v: "stage"].rounded()), press = p[v: "press"]
        let floor = 284.0
        s.room(floor: floor)
        let rh = 330.0
        // rescuer sits on a chair, facing right; forearm rests on the thigh
        var r = SideFigure(h: rh, hip: CGPoint(x: 84, y: floor - 0.27 * rh), lean: 28, headTilt: 22)
        r.nearLeg = .init(hip: 90, knee: 90)
        r.farLeg = .init(hip: 86, knee: 84)
        let seat = r.hip.y + r.build.legW * rh * 0.5
        s.rect(r.hip.x - 34, seat, 64, 7, r: 2, fill: hex("#A07850"))
        s.rect(r.hip.x - 34, seat - 78, 7, 78, r: 2, fill: hex("#8C6844"))
        for x in [r.hip.x - 32, r.hip.x + 22] { s.rect(x, seat + 6, 6, floor - seat - 6, fill: hex("#8C6844")) }

        let knee = CGPoint(x: r.hip.x + r.build.thigh * rh, y: r.hip.y)
        let lap = r.build.legW * rh * 0.5
        let palm = CGPoint(x: knee.x + 8, y: knee.y - lap - 4)
        let elbowGuess = CGPoint(x: r.hip.x + 28, y: r.hip.y - lap - 16)
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
            let chest = b.front(0.66), n = unit(CGPoint(x: chest.x - b.torso(0, 0.66).x, y: chest.y - b.torso(0, 0.66).y))
            let gap = 1 + (1 - press) * 10
            r.far = .init(reach: CGPoint(x: chest.x + n.x * gap, y: chest.y + n.y * gap), hand: .twoFingers, handAngle: slope + 90)
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
            s.tag("can’t cry, cough or breathe", "哭不出、咳不出、喘不上", 290, 196, size: 10, color: red, bold: true, width: 110)
            s.tag("lips turning blue", "嘴唇发紫", 290, 222, size: 9)
        case 1:
            s.tag("heel of hand between the shoulder blades", "掌根拍两肩胛骨之间", 290, 196, size: 10, color: red, bold: true, width: 110)
            s.tag("head lower than chest · hold the jaw", "头低于胸 · 托住下颌", 290, 240, size: 9, width: 120)
        case 2:
            s.tag("2 fingers, just below the nipple line", "两指，乳头连线正下方", 290, 196, size: 10, color: red, bold: true, width: 110)
            s.tag("head lower than chest", "头低于胸", 290, 240, size: 9)
        case 3:
            s.phone(330, floor - 26, number: s.t("911", "120"), t: t)
            s.tag("goes limp: call and start baby CPR", "失去反应：呼救并开始婴儿心肺复苏", 290, 196, size: 10, color: red, bold: true, width: 110)
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
