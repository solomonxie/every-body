import SwiftUI

extension Illustrations {
    static func cpr(for who: Profile) -> Scenario {
        let infant = who.age == .infant, child = who.age.isChild, pregnant = who.isPregnant
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
        case .toddler, .child: Bilingual("Child: one hand (two if big), about 5 cm deep. Alone? 2 min of CPR, then call 120.",
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
        if who.age == .infant { drawBabyCPR(&s, p, t); return }
        let child = who.age.isChild
        let st = Int(p[v: "stage"].rounded()), press = p[v: "press"], taps = p[v: "taps"], rate = p[v: "rate"]
        let floor = 262.0
        s.room(floor: floor)
        let rh = 330.0
        let c = Casualty(art: who, adult: rh * (who.age == .toddler ? 1.3 : child ? 1.12 : 0.95))

        // casualty on the back, head left, legs running off the right edge; breastbone at x ≈ 180
        var pt = SideFigure(h: c.h, build: c.build, look: c.look, hip: .zero, rotation: -90, face: .closed, bump: c.bump)
        pt.near = .init(shoulder: 6, elbow: 8)
        pt.far = .init(shoulder: 3, elbow: 8)
        pt.nearLeg = .init(hip: 3, knee: 4, point: 25)
        pt.farLeg = .init(hip: 1, knee: 2, point: 25)
        if st == 4 { pt.headTilt = -24 }
        pt.hip = CGPoint(x: 0, y: floor - c.build.depth * c.h * 0.5)
        pt.hip.x = 180 - pt.front(0.68).x
        let sternum = pt.front(0.68)
        let sink = press * (child ? 5 : 6)

        // rescuer kneels on the far side, facing us
        var r = FrontFigure(h: rh, build: Build.adult.art, look: Look.Cast.rescuer, neck: CGPoint(x: sternum.x + 10, y: floor - 0.56 * rh), left: .zero, right: .zero,
                            floor: floor)
        let hands = CGPoint(x: sternum.x, y: sternum.y + sink)
        switch st {
        case 0:
            // tap both shoulders
            r.bow = 0.1
            let sh = pt.front(0.95)
            r.neck.x = sh.x + 26
            r.left = CGPoint(x: sh.x - 3, y: sh.y - 3 + sin(t * 9) * 1.5)
            r.right = CGPoint(x: sh.x + 10, y: sh.y + 1)
        case 2, 3, 6:
            if child {
                // one hand, arm straight; the other keeps the head tilted
                let L = (r.build.upperArm + r.build.foreArm + r.build.hand * 0.3) * rh
                r.neck = CGPoint(x: hands.x - r.build.shoulderW * 0.85 * rh, y: hands.y - L - 0.035 * rh)
                r.right = hands
                r.left = pt.headPoint(0.3, -0.8)
            } else {
                r.hands = .interlocked
                r.neck = FrontFigure.neckAbove(hands, h: rh, build: r.build)
                r.left = CGPoint(x: hands.x - 1, y: hands.y)
                r.right = CGPoint(x: hands.x + 1, y: hands.y - 2)
            }
        case 4:
            // at the head: hand on the forehead, fingers under the chin, leaning down over the face
            r.bow = 0.45
            let head = pt.headCentre
            r.neck = CGPoint(x: head.x + 14, y: floor - 0.44 * rh)
            r.left = pt.headPoint(0.3, -0.9)
            r.right = pt.headPoint(0.55, 1.2)
            r.hands = .twoFingers
        case 5:
            r.neck.x = sternum.x - 12
            r.left = CGPoint(x: r.neck.x - 0.13 * rh, y: r.neck.y - 0.13 * rh)
            r.right = CGPoint(x: r.neck.x + 0.13 * rh, y: r.neck.y - 0.13 * rh)
        default:
            r.left = CGPoint(x: r.neck.x - 0.09 * rh, y: floor - 0.2 * rh)
            r.right = CGPoint(x: r.neck.x + 0.09 * rh, y: floor - 0.2 * rh)
        }

        if st == 1 {
            // helper hurries off for the AED
            let hh = 196.0
            var helper = SideFigure(h: hh, build: Build.adult.art, look: Look.Cast.helper, hip: CGPoint(x: 300, y: floor - 6 - 0.51 * hh), lean: 8)
            helper.near = .init(shoulder: 24, elbow: 40)
            helper.far = .init(shoulder: -22, elbow: 30)
            helper.nearLeg = .init(hip: 26, knee: 12, point: -6)
            helper.farLeg = .init(hip: -18, knee: 24, point: 16)
            helper.draw(&s)
        }
        r.draw(&s)
        pt.draw(&s)
        if st == 5 { bareChest(&s, pt) }
        if who.isPregnant && (st == 6 || st == 3) { pushBump(&s, pt) }
        if st == 5 {
            // AED by the head, pads on the bare chest
            let box = CGPoint(x: 34, y: floor - 14)
            s.aed(box.x, box.y, open: true)
            if child {
                s.pad(pt.front(0.62), to: CGPoint(x: box.x + 20, y: box.y + 4), w: 11, h: 5)
            } else {
                s.pad(pt.front(0.9), to: CGPoint(x: box.x + 20, y: box.y + 2), w: 14, h: 5)
                s.pad(pt.front(0.5), to: CGPoint(x: box.x + 20, y: box.y + 8), w: 14, h: 5)
            }
        }
        r.drawArms(&s)

        let red = hex("#D8434B"), blue = hex("#3F95D6")
        let rhead = r.headCentre, rr = r.build.headR * rh
        switch st {
        case 0:
            s.bubble("Are you OK?", "你还好吗？", rhead.x - rr - 58, rhead.y - 4, tip: CGPoint(x: rhead.x - rr * 0.85, y: rhead.y + rr * 0.45))
            s.callout("Normal breathing? ≤ 10 s", "有无正常呼吸？≤ 10 秒", 70, 150, to: pt.mouth, color: hex("#333333"))
        case 1:
            s.phone(30, floor - 30, number: s.t("911", "120"), t: t)
            s.bubble("Get an AED!", "快去拿 AED！", 250, 50, tip: CGPoint(x: rhead.x + rr * 0.9, y: rhead.y + rr * 0.1))
            s.tag("phone on speaker", "手机开免提", 44, floor + 18, size: 9, bold: true)
            if child {
                s.tag("Alone, no phone? 2 min CPR, then call", "独自一人且无手机：先做 2 分钟再去呼救", 226, floor + 22, size: 10, color: red, bold: true, width: 220)
            }
        case 2, 6:
            if st == 2 {
                s.chestMap(238, 8, 114, 112, mark: child ? .oneHand : .twoHands, baby: false, title: Bilingual("Where to push", "按压位置"))
            } else {
                bumpInset(&s, 222, 8)
            }
            let top = CGPoint(x: child ? r.neck.x + r.build.shoulderW * 0.85 * rh : r.neck.x, y: r.neck.y + 0.035 * rh)
            s.line(top.x, top.y, hands.x, hands.y - 4, stroke: red, lw: 1.2, dash: [3, 3])
            s.callout("shoulders over hands", "肩在手正上方", 58, top.y - 6, to: CGPoint(x: top.x - (child ? 0 : r.build.shoulderW * 0.85 * rh), y: top.y), color: red)
            s.callout("arms straight", "手臂伸直", 58, (top.y + hands.y) / 2 + 8, to: child ? lerp(top, r.right, 0.55) : lerp(CGPoint(x: r.neck.x - r.build.shoulderW * 0.85 * rh, y: top.y), r.left, 0.5),
                      color: red)
            if st == 2 { s.callout(child ? "heel of one hand" : "heel of hand, fingers laced", child ? "单手掌根" : "掌根按压，十指相扣", 250, 150,
                                   to: CGPoint(x: hands.x + 6, y: hands.y - 2), color: red, width: 120) }
        case 3:
            let perfusion = taps > 0 ? min(1, rate / 110) * (rate > 130 ? 0.8 : 1) : 0
            let rateColor = rate == 0 ? hex("#777777") : rate < 100 ? hex("#E39B4B") : rate > 120 ? red : hex("#2E9E5B")
            s.tonal(8, 8, 134, 62, r: 12, color: rateColor)
            s.label("Compressions \(Int(taps.rounded()))/30", "按压 \(Int(taps.rounded()))/30", 18, 26, size: 11, color: hex("#333333"), bold: true)
            s.label(rate > 0 ? "\(Int(rate.rounded())) /min" : "aim 100–120 /min", rate > 0 ? "\(Int(rate.rounded())) 次/分" : "目标 100–120 次/分",
                    18, 43, size: 12, color: rateColor, bold: true)
            s.label("Blood to brain", "大脑供血", 18, 58, size: 8)
            s.rect(78, 55, 48, 6, r: 3, fill: hex("#EEEEEE"))
            s.rect(78, 55, 48 * perfusion, 6, r: 3, fill: hex("#C8323C"))
            s.compressionSection(236, 8, press: press, depth: child ? "≈ 5 cm" : "5–6 cm")
            depthMark(&s, x: hands.x + 30, top: sternum.y - 10, depth: 12, text: child ? "≈ 5 cm" : "5–6 cm")
            if who.age == .senior { s.tag("ribs may crack — keep going", "肋骨可能骨折——继续按", 84, 90, size: 10, color: red, bold: true) }
        case 4:
            breathInset(&s, 204, 8, baby: false, t: t)
            let rise = max(0, sin(t * 2.2))
            s.arrow(CGPoint(x: sternum.x + 18, y: sternum.y - 6), CGPoint(x: sternum.x + 18, y: sternum.y - 14 - rise * 6), color: blue, lw: 2)
            s.tag("watch the chest rise", "看胸廓抬起", sternum.x + 22, sternum.y - 30, size: 9, color: blue, anchor: .start, bold: true)
        case 5:
            s.chestMap(238, 8, 114, 112, mark: child ? .padsFrontBack : .pads, baby: false, title: Bilingual("Pads on bare skin", "电极片贴裸露皮肤"))
            s.bubble("Stand clear!", "都别碰！", rhead.x - rr - 58, rhead.y - rr - 10, tip: CGPoint(x: rhead.x - rr * 0.9, y: rhead.y), color: red, border: red)
            s.tag("then 30:2 until help takes over", "之后继续 30:2，直到急救人员接手", 200, floor + 20, size: 10, bold: true)
        default: break
        }
    }

    // MARK: baby

    /// close-up of a baby on a table; the rescuer's hands and head come in from above
    private static func drawBabyCPR(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let st = Int(p[v: "stage"].rounded()), press = p[v: "press"], taps = p[v: "taps"], rate = p[v: "rate"]
        let top = 252.0, bh = 290.0
        s.backdrop()
        s.ellipse(170, top - 30, 170, 110, fill: Palette.blob)
        var b = SideFigure(h: bh, build: Build.infant.art, look: Look.Cast.baby, hip: .zero, rotation: -90, face: .closed)
        b.near = .init(shoulder: 14, elbow: 50)
        b.far = .init(shoulder: -6, elbow: 40)
        b.nearLeg = .init(hip: 16, knee: 28, point: 20)
        b.farLeg = .init(hip: 26, knee: 40, point: 20)
        b.hip = CGPoint(x: 0, y: top - b.build.depth * bh * 0.5 - 1)
        b.hip.x = 158 - b.front(0.64).x
        let sink = st == 3 ? press * 7 : 0
        let sternum = b.front(0.64), L = 58.0
        let push = CGPoint(x: sternum.x, y: sternum.y + sink)
        let red = hex("#D8434B"), blue = hex("#3F95D6")

        // far hand behind the chest (only its forearm shows), then the table and the baby
        if st == 2 || st == 3 { reachIn(&s, from: CGPoint(x: push.x + 110, y: -10), palm: CGPoint(x: push.x + 6, y: push.y + L * 0.4), dir: unit(CGPoint(x: -0.35, y: 1)), len: L, shape: .encircle, thumb: -1, look: Look.Cast.rescuer.shaded(0.85)) }
        s.rect(-20, top, 400, 320 - top, r: 14, fill: hex("#DCC3A2"))
        s.rect(-20, top, 400, 6, r: 3, fill: hex("#E9D6BC"))
        s.ellipse(b.hip.x - 30, top + 1, 110, 4, fill: .black.opacity(0.08))
        if st == 5 {
            // onesie off, nappy on
            (b.look.top, b.look.topLine, b.look.bottom) = (b.look.skin, b.look.skinLine, b.look.skin)
            b.draw(&s)
            let nappy = [(0.5, 0.18), (0.54, 0.02), (0.3, -0.12), (-0.2, -0.14), (-0.56, -0.02), (-0.54, 0.18)].map { b.torso($0.0, $0.1) }
            s.shape(smoothPath(nappy), fill: .white, stroke: hex("#C9C2B8"), lw: 1.2)
        } else {
            b.draw(&s)
        }

        switch st {
        case 0:
            // tap the sole of the foot
            let toe = b.foot(near: true).toe, tap = sin(t * 9) * 2
            reachIn(&s, from: CGPoint(x: 400, y: 150), palm: CGPoint(x: toe.x + 26 + tap, y: toe.y + 6), dir: unit(CGPoint(x: -1, y: 0.05)), len: L,
                    shape: .twoFingers, thumb: -1, look: Look.Cast.rescuer)
            s.bubble("Baby? Baby!", "宝宝？宝宝！", 250, 40, tip: CGPoint(x: 290, y: -2))
            s.callout("tap the sole — don’t shake", "轻拍足底——不要摇晃", 280, 120, to: CGPoint(x: toe.x + 4, y: toe.y - 6), color: red)
            s.callout("Normal breathing? ≤ 10 s", "有无正常呼吸？≤ 10 秒", 110, 110, to: b.front(0.55), color: hex("#333333"))
        case 1:
            s.phone(40, top - 24, number: s.t("911", "120"), t: t)
            s.bubble("Call 120 — get an AED!", "打 120，拿 AED！", 170, 50, tip: CGPoint(x: 200, y: -2))
            s.tag("phone on speaker", "手机开免提", 44, top + 20, size: 9, bold: true)
            s.tag("Alone, no phone? 2 min CPR first, then call", "独自一人且无手机：先做 2 分钟再去呼救", 200, 112, size: 10, color: red, bold: true, width: 240)
        case 2, 3:
            // near hand wrapped round the chest, thumbs on the breastbone; forearm rises straight up
            var g = s
            g.ctx.clip(to: Path(CGRect(x: 0, y: 0, width: 360, height: top)))
            reachIn(&g, from: CGPoint(x: push.x + 80, y: -10), palm: CGPoint(x: push.x - 2, y: push.y + L * 0.42), dir: unit(CGPoint(x: -0.25, y: 1)), len: L, shape: .encircle, thumb: 1, look: Look.Cast.rescuer)
            if st == 2 {
                s.chestMap(238, 8, 114, 112, mark: .thumbs, baby: true, title: Bilingual("Where to push", "按压位置"))
                s.callout("both thumbs on the breastbone", "双拇指并排按胸骨", 84, 150, to: CGPoint(x: push.x - 2, y: push.y + 2), color: red, width: 120)
                s.callout("fingers round the back", "其余手指环抱背部", 84, 196, to: CGPoint(x: push.x - 14, y: push.y + 34), color: hex("#555555"), width: 120)
            } else {
                let rateColor = rate == 0 ? hex("#777777") : rate < 100 ? hex("#E39B4B") : rate > 120 ? red : hex("#2E9E5B")
                s.tonal(8, 8, 138, 46, r: 12, color: rateColor)
                s.label("Compressions \(Int(taps.rounded()))/30", "按压 \(Int(taps.rounded()))/30", 18, 26, size: 11, color: hex("#333333"), bold: true)
                s.label(rate > 0 ? "\(Int(rate.rounded())) /min" : "aim 100–120 /min", rate > 0 ? "\(Int(rate.rounded())) 次/分" : "目标 100–120 次/分",
                        18, 43, size: 12, color: rateColor, bold: true)
                s.compressionSection(236, 8, press: press, depth: "≈ 4 cm", baby: true)
                depthMark(&s, x: push.x + 34, top: sternum.y, depth: 16, text: "≈ 4 cm")
            }
        case 4:
            babyBreath(&s, b, t)
        case 5:
            s.aed(50, top - 22, scale: 0.9, open: true)
            s.pad(b.front(0.66), to: CGPoint(x: 68, y: top - 18), w: 16, h: 5)
            let back = b.back(0.66)
            s.shape(Path(roundedRect: CGRect(x: back.x - 8, y: back.y - 2, width: 16, height: 5), cornerRadius: 1.5), stroke: hex("#2E9E5B"), lw: 1.2, dash: [2, 2])
            s.chestMap(238, 8, 114, 112, mark: .padsFrontBack, baby: true, title: Bilingual("Pads on bare skin", "电极片贴裸露皮肤"))
            s.bubble("Stand clear!", "都别碰！", 130, 50, tip: CGPoint(x: 160, y: -2), color: red, border: red)
            s.tag("then 30:2 until help takes over", "之后继续 30:2，直到急救人员接手", 180, top + 22, size: 10, bold: true)
        default: break
        }
        if st == 2 { s.tag("firm, flat surface", "坚硬平面", 180, top + 22, size: 10, bold: true) }
    }

    /// rescuer's head comes down over the baby's face: mouth over mouth and nose, head kept level
    private static func babyBreath(_ s: inout Sketch, _ b: SideFigure, _ t: Double) {
        let blue = hex("#3F95D6")
        let target = b.headPoint(1.02, 0.44)
        let ru = unit(CGPoint(x: 1, y: -0.75)), rr = 0.064 * 700
        let off = headSpot(.zero, up: ru, r: rr, 0.95, 0.6)
        let rc = CGPoint(x: target.x - off.x, y: target.y - off.y - 3)
        let rn = headSpot(rc, up: ru, r: rr, -0.2, 0.85)
        let look = Look.Cast.rescuer
        // neck and a shoulder leaving the frame at the top left
        // the library head brings its own neck; the shoulder covers where it ends
        let nb = headSpot(rc, up: ru, r: rr, -0.4, 1.9)
        let sh = CGPoint(x: nb.x - 6, y: nb.y - 10)
        drawSideHead(&s, at: rc, up: ru, r: rr, look: look, face: .closed, only: [.back, .skin])
        s.shape(smoothPath([CGPoint(x: sh.x + 26, y: sh.y - 8), CGPoint(x: sh.x - 8, y: sh.y + 22), CGPoint(x: -30, y: sh.y + 40),
                            CGPoint(x: -30, y: -30), CGPoint(x: sh.x + 30, y: -30)]), fill: look.top)
        drawSideHead(&s, at: rc, up: ru, r: rr, look: look, face: .closed, only: [.front])
        let rise = max(0, sin(t * 2.2)), c = b.front(0.58)
        s.arrow(CGPoint(x: c.x + 10, y: c.y - 4), CGPoint(x: c.x + 10, y: c.y - 14 - rise * 6), color: blue, lw: 2)
        s.tag("chest just rises", "胸廓刚好抬起", c.x + 14, c.y - 28, size: 10, color: blue, anchor: .start, bold: true)
        s.callout("mouth over mouth AND nose", "嘴包住口和鼻", 290, 150, to: CGPoint(x: target.x + 4, y: target.y - 2), color: blue, width: 110)
        s.tag("head level — not tilted", "头保持水平，不后仰", 110, 272, size: 10, bold: true)
        s.tag("2 gentle puffs", "轻吹 2 口", 280, 272, size: 10, color: blue, bold: true)
    }

    /// an adult forearm (sleeve pushed up) reaching in from off-frame to a hand at `palm`
    static func reachIn(_ s: inout Sketch, from: CGPoint, palm: CGPoint, dir: CGPoint, len L: Double, shape: SideFigure.Hand, thumb: Double,
                        gloves: Color? = nil, look base: Look = .rescuer) {
        var look = base
        look.gloves = gloves
        let aw = L * 0.5
        let wrist = CGPoint(x: palm.x - dir.x * L * 0.45, y: palm.y - dir.y * L * 0.45)
        // bare forearm about 1.2 hand-lengths long, then the pushed-up sleeve runs off the frame
        let u = unit(CGPoint(x: from.x - wrist.x, y: from.y - wrist.y))
        let dist = hypot(from.x - wrist.x, from.y - wrist.y), bare = min(dist * 0.65, L * 1.2)
        let cuff = CGPoint(x: wrist.x + u.x * bare, y: wrist.y + u.y * bare)
        if look.art != nil {
            s.taper([CGPoint(x: cuff.x + u.x * 4, y: cuff.y + u.y * 4), wrist], [aw * 0.62, aw * 0.4], fill: look.skin, line: nil)
            s.taper([CGPoint(x: from.x + u.x * 20, y: from.y + u.y * 20), cuff], [aw * 1.2, aw * 1.0], fill: look.top, line: nil)
            drawHand(&s, at: palm, dir: dir, len: L, shape: shape, look: look, thumb: thumb)
            return
        }
        s.taper([CGPoint(x: cuff.x + u.x * 4, y: cuff.y + u.y * 4), wrist], [aw * 0.95, aw * 0.6], fill: look.skin, line: look.skinLine)
        s.taper([CGPoint(x: from.x + u.x * 20, y: from.y + u.y * 20), cuff], [aw * 1.25, aw * 1.12], fill: look.top, line: look.topLine)
        s.line(cuff.x - u.y * aw * 0.5, cuff.y + u.x * aw * 0.5, cuff.x + u.y * aw * 0.5, cuff.y - u.x * aw * 0.5, stroke: look.topLine, lw: 1, opacity: 0.8)
        drawHand(&s, at: palm, dir: dir, len: L, shape: shape, look: look, thumb: thumb)
    }

    /// shirt opened: bare skin over the front of the chest
    private static func bareChest(_ s: inout Sketch, _ pt: SideFigure) {
        let fs = [0.94, 0.84, 0.72, 0.6, 0.5, 0.42]
        let outer = fs.map { pt.front($0) }
        let inner = fs.reversed().map { pt.torso(0.12, $0) }
        s.shape(smoothPath(outer + inner), fill: pt.look.skin)
        s.shape(openPath(inner), stroke: pt.look.topLine, lw: 1.6)
    }

    /// double-headed depth arrow beside the hands
    private static func depthMark(_ s: inout Sketch, x: Double, top: Double, depth: Double, text: String) {
        let red = hex("#D8434B")
        s.line(x - 5, top, x + 5, top, stroke: red, lw: 1.2)
        s.line(x - 5, top + depth, x + 5, top + depth, stroke: red, lw: 1.2)
        s.arrow(CGPoint(x: x, y: top + 1), CGPoint(x: x, y: top + depth - 1), color: red, lw: 1.4)
        s.tag(text, text, x + 8, top + depth / 2, size: 9, color: red, anchor: .start, bold: true)
    }

    /// helper kneeling on our side pushes the bump away from us — to her left
    private static func pushBump(_ s: inout Sketch, _ pt: SideFigure) {
        let bump = pt.front(0.28), look = Look.Cast.helper, aw = 0.1 * 200
        for (i, dx) in [-14.0, 10].enumerated() {
            let palm = CGPoint(x: bump.x + dx + 4, y: bump.y + 20 + Double(i) * 2)
            let elbow = CGPoint(x: palm.x + dx * 1.2 + 12, y: 300)
            dressedArm(&s, CGPoint(x: elbow.x - 8, y: 330), elbow, lerp(elbow, palm, 0.8), aw: aw, look: look)
            drawHand(&s, at: palm, dir: unit(CGPoint(x: palm.x - elbow.x, y: palm.y - elbow.y)), len: 26, shape: .encircle, look: look, thumb: dx < 0 ? 1 : -1)
        }
        s.callout("helper pushes the bump to her left", "旁人把子宫推向她的左侧", 290, 150, to: CGPoint(x: bump.x + 4, y: bump.y + 2),
                  color: hex("#B06C84"), width: 110)
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

    /// close-up: open the airway (and for a baby, how the mouth covers mouth and nose)
    private static func breathInset(_ s: inout Sketch, _ x: Double, _ y: Double, baby: Bool, t: Double) {
        let w = 148.0, h = 118.0
        s.inset(x, y, w, h, baby ? "Head level, cover mouth + nose" : "Tilt head back, lift chin", baby ? "头保持水平，包住口鼻" : "仰头抬颏")
        var g = s.clipped(x, y + 18, w, h - 18)
        let pr = baby ? 29.0 : 28
        let a = (baby ? 0 : 18.0) * .pi / 180
        let up = CGPoint(x: -cos(a), y: sin(a)), f = CGPoint(x: -up.y, y: up.x)
        let ground = y + h - 5
        let pc = CGPoint(x: x + 60, y: ground - pr * (baby ? 1.0 : 1.06))
        let look: Look = baby ? Look.Cast.baby : Look.Cast.man
        g.rect(x, ground, w, 8, fill: Palette.floor)
        let neck = headSpot(pc, up: up, r: pr, -0.05, 0.8)
        g.taper([neck, CGPoint(x: neck.x + 34, y: neck.y + 2)], [pr * 0.8, pr * 0.9], fill: look.skin, line: look.skinLine)
        g.shape(smoothPath([CGPoint(x: neck.x + 24, y: neck.y - pr * 0.55), CGPoint(x: x + w + 10, y: neck.y - pr * 0.7),
                            CGPoint(x: x + w + 10, y: ground + 4), CGPoint(x: neck.x + 18, y: ground + 4)]), fill: look.top, stroke: look.topLine, lw: 1.2)
        drawSideHead(&g, at: pc, up: up, r: pr, look: look, face: .closed, baby: baby)
        let red = hex("#D8434B"), blue = hex("#3F95D6")
        // palm on the forehead, fingers toward the crown; forearm rises from the wrist
        let d1 = unit(CGPoint(x: up.x + f.x * 0.2, y: up.y + f.y * 0.2))
        let fh = headSpot(pc, up: up, r: pr, 0.66, -0.78)
        let p1 = CGPoint(x: fh.x + d1.x * 3, y: fh.y + d1.y * 3)
        hand(&g, at: p1, dir: d1, from: CGPoint(x: p1.x + 14, y: y - 10), shape: .open, thumb: 1)
        // fingertips under the bony chin, forearm off to the upper right
        let chin = headSpot(pc, up: up, r: pr, 0.72, 1.16)
        let d2 = unit(CGPoint(x: up.x * 0.9 + f.x * 0.45, y: up.y * 0.9 + f.y * 0.45))
        let p2 = CGPoint(x: chin.x - d2.x * 9 - f.x * 1, y: chin.y - d2.y * 9 - f.y * 1)
        hand(&g, at: p2, dir: d2, from: CGPoint(x: x + w + 10, y: y + 20), shape: .twoFingers, thumb: -1)
        let mouth = headSpot(pc, up: up, r: pr, 1.02, baby ? 0.42 : 0.6)
        if baby {
            g.shape(Path(ellipseIn: CGRect(x: mouth.x - pr * 0.5, y: mouth.y - pr * 0.5, width: pr, height: pr)), stroke: blue, lw: 1.6, dash: [3, 2])
        } else {
            // push the forehead back, lift the chin
            g.arrow(headSpot(pc, up: up, r: pr, 1.45, -0.2), headSpot(pc, up: up, r: pr, 1.45, -0.95), color: red, lw: 1.8)
            g.arrow(headSpot(pc, up: up, r: pr, 1.15, 1.75), headSpot(pc, up: up, r: pr, 1.75, 1.6), color: red, lw: 1.8)
        }
        let puff = (t * 0.8).wrap(1)
        let from = CGPoint(x: mouth.x + f.x * 24, y: mouth.y + f.y * 24), to = CGPoint(x: mouth.x + f.x * 6, y: mouth.y + f.y * 6)
        g.arrow(lerp(from, to, puff * 0.3), lerp(from, to, 0.3 + puff * 0.7), color: blue, lw: 1.8)
        s.tag(baby ? "puff × 2" : "breath 1 s × 2", baby ? "轻吹 2 口" : "吹气 1 秒 × 2", x + w - 8, y + h - 16, size: 8, color: blue, anchor: .end, bold: true)
    }

    /// the rescuer's forearm and hand reaching into a close-up from `from`
    private static func hand(_ s: inout Sketch, at: CGPoint, dir: CGPoint, from: CGPoint, shape: SideFigure.Hand, thumb: Double = -1) {
        let look = Look.Cast.rescuer, L = 24.0
        let wrist = CGPoint(x: at.x - dir.x * L * 0.45, y: at.y - dir.y * L * 0.45)
        dressedArm(&s, from, lerp(from, wrist, 0.5), wrist, aw: 10, look: look)
        drawHand(&s, at: at, dir: dir, len: L, shape: shape, look: look, thumb: thumb)
    }
}
