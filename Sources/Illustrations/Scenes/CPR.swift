import SwiftUI

extension Illustrations {
    static func cpr(for who: Profile) -> Scenario {
        let infant = who.age == .infant, child = who.age == .child, pregnant = who.isPregnant
        let depth = infant ? Bilingual("about 4 cm (⅓ of the chest)", "约 4 厘米（胸廓厚度 1/3）")
            : child ? Bilingual("about 5 cm (⅓ of the chest)", "约 5 厘米（胸廓厚度 1/3）") : Bilingual("5–6 cm deep", "深 5–6 厘米")
        var steps: [Step] = [
            infant
                ? .watch("Make sure it’s safe. Tap the sole of the foot and call the baby — don’t shake. Look for normal breathing, up to 10 s.",
                         "确认环境安全。轻拍婴儿足底并呼唤，不要摇晃。观察有无正常呼吸，不超过 10 秒。", set: ["stage": 0])
                : .watch("Make sure it’s safe. Tap both shoulders and shout. No response? Look for normal breathing, up to 10 s.",
                         "确认环境安全。拍打双肩、大声呼唤。无反应？观察有无正常呼吸，不超过 10 秒。", set: ["stage": 0]),
            infant || child
                ? .watch("Not breathing normally? A helper calls 120/911 and fetches an AED now. Alone: do 2 minutes of CPR first, then call on speaker.",
                         "无正常呼吸？有旁人：让其立即拨打 120 并去取 AED。独自一人：先做 2 分钟心肺复苏，再开免提拨打 120。", set: ["stage": 1])
                : .watch("Not breathing, or only gasping? Call 120/911 with the phone on speaker. Send someone for an AED.",
                         "无呼吸或仅有喘息？拨打 120，手机开免提。让旁人去取 AED。", set: ["stage": 1]),
            infant
                ? .watch("Baby on a firm, flat surface. Both thumbs side by side on the breastbone just below the nipple line, hands around the chest.",
                         "婴儿仰卧在坚硬平面上。双拇指并排放在乳头连线正下方的胸骨上，其余手指环抱胸廓。", set: ["stage": 2])
                : child
                ? .watch("Heel of one hand on the lower half of the breastbone (two hands for a big child). Arm straight, shoulder over the hand.",
                         "单手掌根放在胸骨下半段（大孩子可用双手）。手臂伸直，肩在手的正上方。", set: ["stage": 2])
                : .watch("Kneel beside them. Heel of one hand on the centre of the chest, other hand on top. Arms straight, shoulders over your hands.",
                         "跪在一侧。一手掌根放在胸部正中，另一手叠放其上。手臂伸直，肩在手的正上方。", set: ["stage": 2]),
        ]
        if pregnant {
            steps.append(.watch("Big bump? A helper pushes it gently to her left with both hands, so it stops squashing the big vein to the heart.",
                                "腹部明显隆起？请旁人用双手将子宫轻推向她的左侧，避免压迫回心的大静脉。", set: ["stage": 6]))
        }
        let pushEn = "Your turn: tap for each compression — 30 at 100–120 a minute, \(depth.en). Let the chest come fully back up."
            + (who.age == .senior ? " Ribs may crack — keep going." : "")
        let pushZh = "试一试：每按一次点一下——共 30 次，每分钟 100–120 次，\(depth.zh)，每次让胸廓完全回弹。" + (who.age == .senior ? "肋骨可能骨折——继续按压。" : "")
        steps += [
            .tryIt(pushEn, pushZh, set: ["stage": 3, "taps": 0, "rate": 0],
                   TryStep(mode: .rhythm(target: 30, minRate: 100, maxRate: 120),
                           success: { $0[v: "taps"] >= 30 && (100...120).contains($0[v: "rate"]) },
                           ok: Bilingual("30 at the right pace — that keeps blood reaching the brain.", "30 次，节奏正确——保证大脑供血。"))),
            infant
                ? .watch("Keep the head level. Cover the baby’s mouth AND nose with your mouth: 2 gentle puffs, just enough to lift the chest.",
                         "头保持水平位。用嘴同时包住婴儿口鼻：轻吹 2 口，见胸廓抬起即可。", set: ["stage": 4])
                : .watch("Tilt the head, lift the chin, pinch the nose, seal your mouth over theirs: 2 breaths of 1 s. Untrained? Just keep pushing.",
                         "仰头抬颏，捏紧鼻子，口对口包严：吹气 2 次，每次 1 秒。未受训练：只做按压即可。", set: ["stage": 4]),
            infant || child
                ? .watch("AED here? Switch it on and follow the voice. Child pads if it has them — one on the chest, one on the back. Keep 30:2 until help takes over.",
                         "AED 到了？开机并按语音操作。有儿童电极片就用——胸前一片、背后一片。持续 30:2，直到急救人员接手。", set: ["stage": 5])
                : .watch("AED here? Switch it on and follow the voice. Pads as shown; nobody touches during the shock. Keep 30:2 until help takes over.",
                         "AED 到了？开机并按语音操作。按图贴电极片，电击时任何人不得接触。持续 30:2，直到急救人员接手。", set: ["stage": 5]),
        ]
        var s = Scenario(
            id: "cpr", group: .firstAid, title: infant ? Bilingual("CPR (baby)", "婴儿心肺复苏") : child ? Bilingual("CPR (child)", "儿童心肺复苏")
                : Bilingual("CPR", "心肺复苏"),
            params: ["stage": 0, "press": 0, "taps": 0, "rate": 0],
            steps: steps,
            draw: { s, p, t in drawCPR(&s, p, t, who) },
            sources: ["ILCOR 2025 CoSTR; AHA 2025 adult & pediatric BLS; ERC 2025; Red Cross: 100–120/min, 30:2",
                      "AHA 2025 maternal cardiac arrest: manual left uterine displacement"]
        )
        s.profileNote = switch who.age {
        case .infant: Bilingual("Baby: two thumbs on the breastbone, about 4 cm deep, breaths cover mouth and nose. Alone? 2 min of CPR, then call.",
                                "婴儿：双拇指按压胸骨，深约 4 厘米，吹气时包住口鼻。独自一人：先做 2 分钟再呼救。")
        case .child: Bilingual("Child: one hand (two if big), about 5 cm deep. Alone? 2 min of CPR, then call 120.",
                               "儿童：单手按压（大孩子用双手），深约 5 厘米。独自一人：先做 2 分钟再拨打 120。")
        case .senior: Bilingual("65+: same as adults. Ribs may crack under proper compressions — don’t stop.",
                                "老人：方法同成人。正确按压可能压断肋骨——不要停。")
        case .adult where pregnant: Bilingual("Pregnant: same hands and depth; a helper pushes the bump to her left. Tell 120 she is pregnant.",
                                              "孕妇：按压位置和深度不变；旁人把子宫推向她的左侧。告诉 120 她怀孕了。")
        case .adult: Bilingual("Adult: both hands, 5–6 cm deep, call 120 first.", "成人：双手按压，深 5–6 厘米，先拨打 120。")
        }
        return s
    }

    private static func drawCPR(_ s: inout Sketch, _ p: Params, _ t: Double, _ who: Profile) {
        let infant = who.age == .infant, child = who.age == .child
        let st = Int(p[v: "stage"].rounded()), press = p[v: "press"], taps = p[v: "taps"], rate = p[v: "rate"]
        // a baby goes on a table: closer view, the rescuer stands behind it
        let floor = infant ? 244.0 : 266
        s.room(floor: infant ? 300 : floor)
        let rh = infant ? 400.0 : child ? 210 : 192
        let ground = infant ? floor + 0.45 * rh : floor
        let c = Casualty(who, adult: rh * 0.95)

        // casualty on the back, head left, arms by the sides
        var pt = SideFigure(h: c.h, build: c.build, look: c.look, hip: .zero, rotation: -90, face: .closed, bump: c.bump)
        pt.hip = CGPoint(x: infant ? 212 : child ? 226 : 236, y: floor - c.build.depth * c.h * 0.5)
        pt.near = .init(shoulder: 6, elbow: 8)
        pt.far = .init(shoulder: 3, elbow: 8)
        pt.nearLeg = .init(hip: 3, knee: 4, point: 25)
        pt.farLeg = .init(hip: 1, knee: 2, point: 25)
        let sternum = pt.front(infant ? 0.64 : 0.68)
        let sink = press * (infant ? 4 : 6)

        // rescuer kneels on the far side, facing us
        var r = FrontFigure(h: rh, neck: CGPoint(x: sternum.x + 6, y: floor - (infant ? 0.37 : 0.56) * rh), left: .zero, right: .zero, floor: infant ? nil : floor)
        let pushing = [2, 3, 6].contains(st)
        if pushing {
            let hands = CGPoint(x: sternum.x, y: sternum.y + sink)
            if infant {
                r.hands = .thumbs
                r.bow = 0.2
                r.neck = CGPoint(x: hands.x, y: hands.y - 0.29 * rh)
                r.left = CGPoint(x: hands.x - 7, y: hands.y + 4)
                r.right = CGPoint(x: hands.x + 7, y: hands.y + 4)
            } else if child {
                let L = (r.build.upperArm + r.build.foreArm + r.build.hand * 0.3) * rh
                r.neck = CGPoint(x: hands.x - r.build.shoulderW * 0.85 * rh, y: hands.y - L - 0.035 * rh)
                r.right = hands
                r.left = pt.headPoint(0.5, -0.75)
            } else {
                r.hands = .interlocked
                r.neck = FrontFigure.neckAbove(hands, h: rh)
                r.left = hands
                r.right = hands
            }
        } else if st == 0 {
            let target = infant ? CGPoint(x: pt.hip.x + c.build.thigh * c.h + c.build.shin * c.h, y: floor - 12) : pt.front(0.95)
            r.neck.x = target.x + (infant ? -10 : 10)
            r.left = CGPoint(x: target.x - 5, y: target.y + 2)
            r.right = CGPoint(x: target.x + 9, y: target.y + 4)
        } else if st == 4 {
            // at the head: one hand on the forehead, fingers under the chin
            r.bow = 0.35
            let head = pt.headCentre
            r.neck = CGPoint(x: head.x + 10, y: floor - (infant ? 0.3 : 0.5) * rh)
            r.left = pt.headPoint(0.45, -0.9)
            r.right = pt.headPoint(0.6, 1.15)
            r.hands = infant ? .open : .twoFingers
        } else if st == 5 {
            r.hands = .open
            r.left = CGPoint(x: r.neck.x - 0.14 * rh, y: r.neck.y - 0.04 * rh)
            r.right = CGPoint(x: r.neck.x + 0.14 * rh, y: r.neck.y - 0.04 * rh)
        } else {
            let y = infant ? floor - 4 : floor - 0.22 * rh
            r.left = CGPoint(x: r.neck.x - 0.1 * rh, y: y)
            r.right = CGPoint(x: r.neck.x + 0.1 * rh, y: y)
        }

        let number = s.t("911", "120")
        if st == 1 {
            // helper hurries off for the AED
            let hh = infant ? rh * 0.95 : 184
            var helper = SideFigure(h: hh, look: .helper, hip: CGPoint(x: infant ? 40 : 52, y: ground - 0.51 * hh), facing: -1, lean: 8)
            helper.near = .init(shoulder: 18, elbow: 30)
            helper.far = .init(shoulder: -18, elbow: 20)
            helper.nearLeg = .init(hip: 24, knee: 10, point: -10)
            helper.farLeg = .init(hip: -16, knee: 22, point: 20)
            helper.draw(&s)
        }
        r.draw(&s)
        if infant {
            s.rect(0, floor, 360, 300 - floor, fill: hex("#C9A77F"))
            s.rect(0, floor, 360, 5, fill: hex("#DDBE96"))
            s.line(0, floor + 5, 360, floor + 5, stroke: hex("#A8865F"), lw: 1)
        }
        pt.draw(&s)
        if st == 5 {
            // AED on the floor by the head, pads on the bare chest
            let box = CGPoint(x: infant ? 96 : 104, y: floor - 16)
            s.aed(box.x, box.y, open: true)
            if infant || child {
                s.pad(pt.front(0.7), to: CGPoint(x: box.x + 18, y: box.y + 6), w: 10, h: 7)
            } else {
                s.pad(pt.front(0.9), to: CGPoint(x: box.x + 18, y: box.y + 4))
                s.pad(pt.front(0.52), to: CGPoint(x: box.x + 18, y: box.y + 8))
            }
        }
        if who.isPregnant && (st == 6 || st == 3) { pushBump(&s, pt) }
        r.drawArms(&s)

        let red = hex("#D8434B")
        let rhead = r.headCentre, rr = r.build.headR * rh
        switch st {
        case 0:
            s.bubble(infant ? "Baby? Baby!" : "Are you OK?", infant ? "宝宝？宝宝！" : "你还好吗？", rhead.x - rr - 62, rhead.y - rr - 8,
                     tip: CGPoint(x: rhead.x - rr * 0.8, y: rhead.y + rr * 0.3))
            s.tag("Breathing normally?", "有无正常呼吸？", 76, 188, size: 11, color: hex("#333333"), bold: true)
            s.tag("look ≤ 10 s", "观察 ≤ 10 秒", 76, 206, size: 10)
            s.arrow(CGPoint(x: 100, y: 216), CGPoint(x: pt.headPoint(0.9, 1.6).x, y: pt.headPoint(0.9, 1.6).y - 6), color: hex("#999999"), lw: 1.4)
        case 1:
            s.phone(infant ? 98 : 118, floor - 26, number: number, t: t)
            s.bubble("Get an AED!", "快去拿 AED！", 150, 62, tip: CGPoint(x: rhead.x - rr * 0.8, y: rhead.y + rr * 0.2))
            if infant || child {
                s.tag("Alone? 2 min CPR first, then call", "独自一人：先做 2 分钟再呼救", 250, 26, size: 10, color: red, bold: true)
            }
        case 2, 6:
            if st == 2 {
                s.chestMap(238, 8, 114, 112, mark: infant ? .thumbs : child ? .oneHand : .twoHands, baby: infant, title: Bilingual("Where to push", "按压位置"))
            } else {
                bumpInset(&s, 222, 8)
            }
            if !infant {
                let sh = CGPoint(x: child ? r.right.x : r.neck.x, y: r.neck.y + 0.035 * rh)
                s.line(sh.x - 30, sh.y, sh.x - 30, sternum.y, stroke: hex("#999999"), lw: 1, dash: [3, 3])
                s.tag("shoulders over hands", "肩在手正上方", sh.x - 36, sh.y + 8, size: 9, anchor: .end)
                s.tag("arms straight", "手臂伸直", sh.x - 36, (sh.y + sternum.y) / 2 + 6, size: 9, anchor: .end)
            }
        case 3:
            let perfusion = taps > 0 ? min(1, rate / 110) * (rate > 130 ? 0.8 : 1) : 0
            let rateColor = rate == 0 ? hex("#777777") : rate < 100 ? hex("#E39B4B") : rate > 120 ? red : hex("#2E9E5B")
            s.rect(8, 8, 150, 62, r: 9, fill: .white, stroke: rateColor, lw: 2)
            s.label("Compressions \(Int(taps.rounded()))/30", "按压 \(Int(taps.rounded()))/30", 18, 26, size: 12, color: hex("#333333"), bold: true)
            s.label(rate > 0 ? "\(Int(rate.rounded())) /min" : "aim 100–120 /min", rate > 0 ? "\(Int(rate.rounded())) 次/分" : "目标 100–120 次/分",
                    18, 43, size: 12, color: rateColor, bold: true)
            s.label("Blood to brain", "大脑供血", 18, 58, size: 8)
            s.rect(78, 55, 70, 6, r: 3, fill: hex("#EEEEEE"))
            s.rect(78, 55, 70 * perfusion, 6, r: 3, fill: hex("#C8323C"))
            s.compressionSection(236, 8, press: press, depth: infant ? "≈ 4 cm" : child ? "≈ 5 cm" : "5–6 cm", baby: infant)
            if who.age == .senior { s.tag("ribs may crack — keep going", "肋骨可能骨折——继续按", 84, 90, size: 10, color: red, bold: true) }
        case 4:
            breathInset(&s, 212, 8, baby: infant, t: t)
            let rise = max(0, sin(t * 2.2))
            s.arrow(CGPoint(x: sternum.x + 20, y: sternum.y - 6), CGPoint(x: sternum.x + 20, y: sternum.y - 14 - rise * 6), color: hex("#3F95D6"), lw: 2)
            s.tag("chest rises", "胸廓抬起", sternum.x + 22, sternum.y - 30, size: 9, color: hex("#3F95D6"), anchor: .start)
        case 5:
            s.chestMap(238, 8, 114, 112, mark: infant || child ? .padsFrontBack : .pads, baby: infant, title: Bilingual("Pads on bare skin", "电极片贴在裸露皮肤上"))
            s.bubble("Stand clear!", "都别碰！", rhead.x - rr - 60, rhead.y - rr, tip: CGPoint(x: rhead.x - rr * 0.8, y: rhead.y + rr * 0.3),
                     color: red, border: red)
            s.tag("then 30:2 until help takes over", "之后继续 30:2，直到急救人员接手", 110, 30, size: 10, bold: true)
        default: break
        }
    }

    /// helper kneeling on our side pushes the bump away from us — to her left
    private static func pushBump(_ s: inout Sketch, _ pt: SideFigure) {
        let bump = pt.front(0.28), look = Look.helper, lw = 0.05 * 184
        for (i, dx) in [-12.0, 10].enumerated() {
            let palm = CGPoint(x: bump.x + dx + 4, y: bump.y + 22 + Double(i) * 2)
            let elbow = CGPoint(x: palm.x + dx * 1.2 + 10, y: 300)
            s.limb([CGPoint(x: elbow.x - 8, y: 320), elbow, palm], w: lw * 0.8, fill: look.skin, line: look.skinLine)
            s.limb([CGPoint(x: elbow.x - 8, y: 320), lerp(elbow, palm, 0.4)], w: lw, fill: look.top, line: look.topLine)
            drawHand(&s, at: palm, dir: unit(CGPoint(x: palm.x - elbow.x, y: palm.y - elbow.y)), len: 16, shape: .open, look: look)
        }
        s.tag("helper pushes the bump to her left", "旁人把子宫推向她的左侧", bump.x + 30, bump.y - 16, size: 9, color: hex("#B06C84"),
              anchor: .start, bold: true, width: 100)
    }

    /// seen from her feet: the womb lies on the big vein until it is pushed to her left
    private static func bumpInset(_ s: inout Sketch, _ x: Double, _ y: Double) {
        s.inset(x, y, 130, 112, "Seen from her feet", "从脚侧看")
        let c = CGPoint(x: x + 65, y: y + 70)
        s.ellipse(c.x, c.y, 54, 30, fill: hex("#F6D8BF"), stroke: hex("#D1A98A"))
        s.circle(c.x, c.y + 20, 8, fill: hex("#E9E2CF"), stroke: hex("#B8A58A"))
        s.circle(c.x + 14, c.y + 15, 5, fill: hex("#C8323C"))
        s.ellipse(c.x - 14, c.y + 15, 6, 5, fill: hex("#3F6FB5"))
        s.circle(c.x + 12, c.y - 8, 22, fill: hex("#E8A7B8"), stroke: hex("#B06C84"))
        s.arrow(CGPoint(x: c.x - 40, y: c.y - 6), CGPoint(x: c.x - 16, y: c.y - 8), color: hex("#B06C84"), lw: 2)
        s.label("vein open", "静脉通畅", c.x - 50, c.y + 40, size: 8, color: hex("#3F6FB5"))
        s.label("spine", "脊柱", c.x - 6, c.y + 40, size: 8)
        s.label("her R", "她的右侧", x + 6, y + 26, size: 8, color: hex("#8A8378"))
        s.label("her L", "她的左侧", x + 124, y + 26, size: 8, color: hex("#8A8378"), anchor: .end)
    }

    /// close-up of opening the airway and giving a breath
    private static func breathInset(_ s: inout Sketch, _ x: Double, _ y: Double, baby: Bool, t: Double) {
        s.inset(x, y, 140, 116, baby ? "Head level, cover mouth + nose" : "Tilt head, lift chin", baby ? "头保持水平，包住口鼻" : "仰头抬颏")
        var s = s.clipped(x, y + 18, 140, 98)
        let pr = baby ? 26.0 : 22
        let up = baby ? CGPoint(x: -1, y: 0) : unit(CGPoint(x: -0.9, y: 0.42))
        let pc = CGPoint(x: x + 50, y: y + 84)
        let look: Look = baby ? .baby : .man
        // neck and shoulder of the casualty running off to the right
        let neck = headSpot(pc, up: up, r: pr, -0.05, 0.85)
        s.limb([neck, CGPoint(x: neck.x + 60, y: neck.y + (baby ? 0 : -6))], w: pr * 0.8, fill: look.skin, line: look.skinLine)
        s.limb([CGPoint(x: neck.x + 24, y: neck.y + 2), CGPoint(x: x + 136, y: neck.y)], w: pr * 1.3, fill: look.top, line: look.topLine)
        drawSideHead(&s, at: pc, up: up, r: pr, look: look, face: .closed, baby: baby)
        // rescuer's head comes down on top, face down
        let target = baby ? lerp(headSpot(pc, up: up, r: pr, 0.97, 0.58), headSpot(pc, up: up, r: pr, 1.04, 0.3), 0.5)
            : headSpot(pc, up: up, r: pr, 0.97, 0.58)
        let ru = unit(CGPoint(x: -1, y: -0.2)), rr = 20.0
        let off = headSpot(.zero, up: ru, r: rr, 0.9, 0.58, side: -1)
        let rc = CGPoint(x: target.x - off.x, y: target.y - off.y)
        let rn = headSpot(rc, up: ru, r: rr, -0.1, 0.9, side: -1)
        s.limb([rn, CGPoint(x: rn.x + 30, y: rn.y - 12)], w: rr * 0.8, fill: Look.rescuer.skin, line: Look.rescuer.skinLine)
        s.limb([CGPoint(x: rn.x + 22, y: rn.y - 10), CGPoint(x: rn.x + 90, y: rn.y - 30)], w: rr * 1.6, fill: Look.rescuer.top, line: Look.rescuer.topLine)
        drawSideHead(&s, at: rc, up: ru, side: -1, r: rr, look: .rescuer, face: .closed)
        let hand = Look.rescuer
        if !baby {
            drawHand(&s, at: headSpot(pc, up: up, r: pr, 0.35, -0.95), dir: unit(CGPoint(x: -up.y, y: up.x)), len: 22, shape: .open, look: hand)
            drawHand(&s, at: headSpot(pc, up: up, r: pr, 0.6, 1.15), dir: unit(CGPoint(x: -up.y, y: up.x)), len: 22, shape: .twoFingers, look: hand)
            s.arrow(headSpot(pc, up: up, r: pr, 0.7, 1.7), headSpot(pc, up: up, r: pr, 1.2, 1.5), color: hex("#D8434B"), lw: 1.6)
        } else {
            drawHand(&s, at: headSpot(pc, up: up, r: pr, 0.2, -1.05), dir: unit(CGPoint(x: -up.y, y: up.x)), len: 20, shape: .open, look: hand)
        }
        let puff = (t * 0.8).wrap(1)
        s.arrow(CGPoint(x: target.x + 16, y: target.y - 26 + puff * 8), CGPoint(x: target.x + 6, y: target.y - 10 + puff * 8), color: hex("#3F95D6"), lw: 1.8)
        s.label(baby ? "gentle puff" : "1 s breath", baby ? "轻吹一口" : "吹气 1 秒", target.x + 20, target.y - 26, size: 8, color: hex("#3F95D6"))
    }
}
