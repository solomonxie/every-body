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
                .watch("Baby can’t cry, cough or breathe, and may turn blue? Act now — someone calls 911.",
                       "婴儿哭不出、咳不出、无法呼吸，甚至发紫？立即施救，让旁人拨打 120。", set: ["stage": 0, "taps": 0, "dislodge": 0]),
                .tryIt("Sit, baby face down along your forearm on your thigh, head lower than the chest, jaw held. Up to 5 firm back blows.",
                       "试一试：坐下，让婴儿面朝下趴在你搭在大腿上的前臂上，头低于胸，托住下颌。掌根拍背最多 5 次。",
                       set: ["stage": 1, "taps": 0, "dislodge": 0], blows),
                .tryIt("Turn baby face up on your other arm, head still low. Heel of one hand on the center of the chest: up to 5 firm chest thrusts.",
                       "试一试：把婴儿翻成面朝上，头仍低。单手掌根放在胸部正中，用力按压最多 5 次。",
                       set: ["stage": 2, "taps": 0, "dislodge": 0.2], thrusts),
                .watch("Still blocked? Repeat 5 back blows, 5 chest thrusts. Baby goes limp? Call 911 and start baby CPR.",
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
                .watch("Still blocked? Keep alternating 5 blows and 5 thrusts, and call 911. If they go limp: lower to the floor, start CPR.",
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

    @MainActor private static func drawChoking(_ s: inout Sketch, _ p: Params, _ t: Double, _ who: Profile) {
        let st = Int(p[v: "stage"].rounded()), out = min(1, p[v: "dislodge"])
        let v = artPerson(who)
        // blows and thrusts: the ready picture, or the contact picture while a tap's press is on
        let key = { (st: Int) in st == 1 || st == 2 ? "\(st)\(p[v: "press"] > 0.5 ? "b" : "a")" : "\(st)" }
        let stage = p[v: "stage"].clamped(0, 3), lo = min(2, Int(stage.rounded(.down))), f = stage - Double(lo), k = f * f * (3 - 2 * f)
        s.backdrop()
        s.art([("choking-\(v)-\(key(lo))", 1 - k), ("choking-\(v)-\(key(lo + 1))", k)])
        let m = SceneMarks.at("choking-\(v)-\(st == 1 || st == 2 ? "\(st)a" : "\(st)")")
        let at = { (key: String) in m[key] ?? CGPoint(x: 150, y: 150) }
        let calm = max(0, 1 - abs(stage - stage.rounded()) * 4)
        s.group(opacity: calm) { g in
            if who.age == .infant { babyChokingLabels(&g, st, p, t, at) } else { chokingLabels(&g, st, p, t, who, at) }
            if st == 0 || st == 3 { airwayInset(&g, 244, 8, out: out, baby: who.age == .infant) }
        }
        // status pill
        let cleared = out >= 0.99, status = cleared ? hex("#2E9E5B") : hex("#D8434B")
        let n = min(5, Int(p[v: "taps"].rounded()))
        let en = cleared ? "Airway clear" : st == 1 ? "Blocked · back blows \(n)/5" : st == 2 ? "Blocked · thrusts \(n)/5" : "Airway blocked"
        let zh = cleared ? "气道通畅" : st == 1 ? "梗阻 · 拍背 \(n)/5" : st == 2 ? "梗阻 · 冲击 \(n)/5" : "气道梗阻"
        let txt = s.ctx.resolve(Text(s.t(en, zh)).font(.system(size: 11, weight: .bold)))
        let w = txt.measure(in: CGSize(width: 300, height: 40)).width + 28
        s.tonal(8, 8, w, 26, r: 13, color: status)
        s.circle(21, 21, 4, fill: status)
        s.label(en, zh, 30, 21, size: 11, color: status, bold: true)
    }

    @MainActor private static func chokingLabels(_ s: inout Sketch, _ st: Int, _ p: Params, _ t: Double, _ who: Profile, _ at: (String) -> CGPoint) {
        let press = p[v: "press"], chestThrust = who.isPregnant
        let red = hex("#D8434B"), green = hex("#2E9E5B"), grey = hex("#555555")
        switch st {
        case 0:
            let h = at("rescuer_head")
            s.bubble("Are you choking?", "你被噎住了吗？", max(70, h.x - 20), max(52, h.y - 26), tip: CGPoint(x: h.x + 6, y: h.y + 4))
            s.callout("hands at the throat", "双手掐喉", 296, 170, to: at("throat"), color: red)
            s.tag("can’t speak, cough or breathe", "说不出、咳不出、喘不上", 296, 196, size: 9, color: red, bold: true, width: 110)
        case 1:
            let b = at("blades")
            s.callout("heel of hand, between the shoulder blades", "掌根拍两肩胛骨之间", 250, 44, to: b, color: red, width: 140)
            s.callout("other hand supports the chest", "另一手扶住胸部", 272, 262, to: at("support"), color: grey)
            let hd = at("casualty_head")
            s.tag("head lower than chest", "头低于胸部", min(300, hd.x + 60), hd.y + 26, size: 9, bold: true)
            let from = CGPoint(x: b.x - 18, y: b.y - 36), to = CGPoint(x: b.x - 4, y: b.y - 10)
            s.arrow(lerp(from, to, press * 0.4), lerp(from, to, 0.5 + press * 0.5), color: red, lw: 2)
        case 2:
            fistCard(&s, 238, 8, chest: chestThrust)
            let f = at("fist")
            if chestThrust {
                s.arrow(CGPoint(x: f.x + 30, y: f.y), CGPoint(x: f.x + 12, y: f.y), color: red, lw: 2.2)
                s.tag("pull straight back", "向正后方冲击", 296, 150, size: 10, color: red, bold: true)
            } else {
                s.path("M \(f.x + 30) \(f.y + 14) Q \(f.x + 12) \(f.y + 12) \(f.x + 10) \(f.y - 6)", stroke: red, lw: 2.2, cap: .round)
                s.arrow(CGPoint(x: f.x + 11, y: f.y - 2), CGPoint(x: f.x + 9, y: f.y - 12), color: red, lw: 2.2)
                s.tag("pull sharply in and up", "快速向内、向上冲击", 296, 150, size: 10, color: red, bold: true)
            }
        case 3:
            s.phone(322, 256, number: s.t("911", "120"), t: t)
            s.tag("coughed out — still see a doctor", "咳出了——仍需就医", 296, 144, size: 10, color: green, bold: true, width: 110)
            s.tag("still stuck: 5 + 5 again, call 911", "仍梗阻：再 5+5\n拨打 120", 296, 184, size: 9, color: red, bold: true, width: 110)
            s.tag("goes limp: floor, CPR", "失去反应：放平做心肺复苏", 296, 214, size: 9, color: red, bold: true, width: 110)
        default: break
        }
    }

    @MainActor private static func babyChokingLabels(_ s: inout Sketch, _ st: Int, _ p: Params, _ t: Double, _ at: (String) -> CGPoint) {
        let press = p[v: "press"], red = hex("#D8434B"), grey = hex("#444444")
        switch st {
        case 0:
            s.callout("can’t cry, cough or breathe", "哭不出、咳不出、喘不上", 296, 170, to: at("mouth"), color: red, width: 110)
            s.tag("lips may turn blue", "嘴唇可能发紫", 296, 200, size: 9, bold: true)
        case 1:
            let b = at("blades")
            s.callout("heel of hand, between the shoulder blades", "掌根拍两肩胛骨之间", 290, 60, to: b, color: red, width: 120)
            s.callout("head lower than chest", "头低于胸", 300, 250, to: at("baby_head"), color: grey)
            s.callout("hold the jaw, not the throat", "托住下颌，别压喉咙", 300, 278, to: at("jaw"), color: grey, width: 110)
            let from = CGPoint(x: b.x - 10, y: b.y - 34), to = CGPoint(x: b.x - 2, y: b.y - 10)
            s.arrow(lerp(from, to, press * 0.4), lerp(from, to, 0.5 + press * 0.5), color: red, lw: 2)
        case 2:
            s.callout("heel of one hand, center of the chest", "单手掌根，胸部正中", 290, 60, to: at("chest"), color: red, width: 120)
            s.callout("head lower than chest", "头低于胸", 300, 250, to: at("baby_head"), color: grey)
        case 3:
            s.phone(330, 250, number: s.t("911", "120"), t: t)
            s.tag("goes limp: call and start baby CPR", "失去反应：呼救并开始婴儿心肺复苏", 290, 190, size: 10, color: red, bold: true, width: 110)
        default: break
        }
    }

    /// front view of the trunk: where the fist goes, thumb side in, other hand over it
    @MainActor private static func fistCard(_ s: inout Sketch, _ x: Double, _ y: Double, chest: Bool) {
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

    /// head and neck cut open: mouth → throat → windpipe, with the stuck piece of food
    @MainActor private static func airwayInset(_ s: inout Sketch, _ x: Double, _ y: Double, out: Double, baby: Bool) {
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
