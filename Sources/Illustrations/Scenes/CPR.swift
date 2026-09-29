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
                ? .watch("Not breathing normally? A helper calls 911 and fetches an AED now. Alone: do 2 minutes of CPR first, then call on speaker.",
                         "无正常呼吸？有旁人：让其立即拨打 120 并去取 AED。独自一人：先做 2 分钟心肺复苏，再开免提拨打 120。", set: ["stage": 1])
                : .watch("Not breathing, or only gasping? Call 911 with the phone on speaker. Send someone for an AED.",
                         "无呼吸或仅有喘息？拨打 120，手机开免提。让旁人去取 AED。", set: ["stage": 1]),
            infant
                ? .watch("Baby on a firm, flat surface. Both thumbs side by side on the breastbone just below the nipple line, hands around the chest.",
                         "婴儿仰卧在坚硬平面上。双拇指并排放在乳头连线正下方的胸骨上，其余手指环抱胸廓。", set: ["stage": 2])
                : child
                ? .watch("Heel of one hand on the lower half of the breastbone (two hands for a big child). Arm straight, shoulder over the hand.",
                         "单手掌根放在胸骨下半段（大孩子可用双手）。手臂伸直，肩在手的正上方。", set: ["stage": 2])
                : .watch("Kneel beside them. Heel of one hand on the center of the chest, other hand on top. Arms straight, shoulders over your hands.",
                         "跪在一侧。一手掌根放在胸部正中，另一手叠放其上。手臂伸直，肩在手的正上方。", set: ["stage": 2]),
        ]
        if pregnant {
            steps.append(.watch("Big bump? A helper pushes it gently to her left with both hands, so it stops squashing the big vein to the heart.",
                                "腹部明显隆起？请旁人用双手将子宫轻推向她的左侧，避免压迫回心的大静脉。", set: ["stage": 2, "lud": 1]))
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
            params: ["stage": 0, "press": 0, "taps": 0, "rate": 0, "lud": 0],
            steps: steps,
            draw: { s, p, t in drawCPR(&s, p, t, who) },
            sources: ["ILCOR 2025 CoSTR; AHA 2025 adult & pediatric BLS; ERC 2025; Red Cross: 100–120/min, 30:2",
                      "AHA 2025 maternal cardiac arrest: manual left uterine displacement"]
        )
        s.profileNote = switch who.age {
        case .infant: Bilingual("Baby: two thumbs on the breastbone, about 4 cm deep, breaths cover mouth and nose. Alone? 2 min of CPR, then call.",
                                "婴儿：双拇指按压胸骨，深约 4 厘米，吹气时包住口鼻。独自一人：先做 2 分钟再呼救。")
        case .toddler, .child: Bilingual("Child: one hand (two if big), about 5 cm deep. Alone? 2 min of CPR, then call 911.",
                               "儿童：单手按压（大孩子用双手），深约 5 厘米。独自一人：先做 2 分钟再拨打 120。")
        case .senior: Bilingual("65+: same as adults. Ribs may crack under proper compressions — don’t stop.",
                                "老人：方法同成人。正确按压可能压断肋骨——不要停。")
        case .adult where pregnant: Bilingual("Pregnant: same hands and depth; a helper pushes the bump to her left. Tell 911 she is pregnant.",
                                              "孕妇：按压位置和深度不变；旁人把子宫推向她的左侧。告诉 120 她怀孕了。")
        case .adult: Bilingual("Adult: both hands, 5–6 cm deep, call 911 first.", "成人：双手按压，深 5–6 厘米，先拨打 120。")
        }
        return s
    }

    /// picture for a stage: compressions pick the up / half / down frame by `press`; the helper's push is its own picture
    private static func artKey(_ stage: Int, press: Double, lud: Double) -> String {
        switch stage {
        case 3: "3" + (press < 0.25 ? "a" : press < 0.75 ? "b" : "c")
        case 2 where lud > 0.5: "6"
        default: "\(stage)"
        }
    }

    @MainActor private static func drawCPR(_ s: inout Sketch, _ p: Params, _ t: Double, _ who: Profile) {
        let v = artPerson(who)
        let stage = p[v: "stage"].clamped(0, 5), press = p[v: "press"], lud = p[v: "lud"]
        let lo = min(4, Int(stage.rounded(.down))), f = stage - Double(lo)
        let k = f * f * (3 - 2 * f)
        let name = { (st: Int, l: Double) in "cpr-\(v)-\(artKey(st, press: press, lud: l))" }
        let layers = abs(stage - stage.rounded()) < 0.002 && lud > 0.002 && lud < 0.998 && Int(stage.rounded()) == 2
            ? [(name(2, 0), 1 - lud), (name(2, 1), lud)]
            : [(name(lo, lud), 1 - k), (name(lo + 1, lud), k)]
        s.backdrop()
        s.art(layers)
        let st = Int(stage.rounded())
        let m = SceneMarks.marks["cpr-\(v)-\(st == 3 ? "3a" : st == 2 && lud > 0.5 ? "6" : "\(st)")"] ?? [:]
        let at = { (key: String) in m[key] ?? CGPoint(x: 180, y: 180) }
        // captions fade in once the picture has settled
        let calm = max(0, 1 - abs(stage - stage.rounded()) * 4)
        s.group(opacity: calm) { g in
            cprLabels(&g, st, p, t, who, at, lud: lud > 0.5)
        }
    }

    @MainActor private static func cprLabels(_ s: inout Sketch, _ st: Int, _ p: Params, _ t: Double, _ who: Profile, _ at: (String) -> CGPoint, lud: Bool) {
        let infant = who.age == .infant, child = who.age.isChild
        let press = p[v: "press"], taps = p[v: "taps"], rate = p[v: "rate"]
        let red = hex("#D8434B"), blue = hex("#3F95D6"), ink = hex("#333333")
        let head = at("rescuer_head")
        switch st {
        case 0:
            if infant {
                s.bubble("Baby? Baby!", "宝宝？宝宝！", head.x - 70, max(24, head.y - 14), tip: CGPoint(x: head.x - 16, y: head.y + 10))
                s.callout("tap the sole — don’t shake", "轻拍足底——不要摇晃", 200, 286, to: at("sole"), color: red, width: 130)
                s.callout("Normal breathing? ≤ 10 s", "有无正常呼吸？≤ 10 秒", 92, 146, to: at("mouth"), color: ink)
            } else {
                s.bubble("Are you OK?", "你还好吗？", max(52, head.x - 64), max(24, head.y - 34), tip: CGPoint(x: head.x - 8, y: head.y - 4))
                s.callout("Normal breathing? ≤ 10 s", "有无正常呼吸？≤ 10 秒", 290, 118, to: at("mouth"), color: ink, width: 130)
            }
        case 1:
            s.bubble("Get an AED!", "快去拿 AED！", max(56, at("point").x - 6), max(24, at("point").y - 34), tip: at("point"))
            let ph = at("phone")
            // baby: the rescuer stands right of the phone, so the label goes up and left
            s.callout("911 on speaker", "拨打 120，开免提", infant ? ph.x - 60 : min(312, ph.x + 88), infant ? ph.y - 56 : ph.y + 30, to: ph, color: ink, width: 130)
            if infant || child {
                s.tag("Alone, no phone? 2 min CPR, then call", "独自一人且无手机：先做 2 分钟再去呼救", 180, 286, size: 10, color: red, bold: true, width: 300)
            }
        case 2 where lud:
            bumpInset(&s, 222, 8)
            let hh = at("helper_head")
            s.callout("helper pushes the bump to her left", "旁人把子宫推向她的左侧", 96, 92, to: CGPoint(x: hh.x - 4, y: hh.y - 10),
                      color: hex("#B06C84"), width: 150)
        case 2:
            if infant {
                s.chestMap(238, 8, 114, 112, mark: .thumbs, baby: true, title: Bilingual("Where to push", "按压位置"))
                s.callout("both thumbs on the breastbone", "双拇指并排按胸骨", 84, 176, to: at("hands"), color: red, width: 120)
                s.tag("firm, flat surface", "坚硬平面", 180, 286, size: 10, bold: true)
            } else {
                s.chestMap(238, 8, 114, 112, mark: child ? .oneHand : .twoHands, baby: false, title: Bilingual("Where to push", "按压位置"))
                let sh = at("shoulders"), hands = at("hands")
                s.line(sh.x, sh.y, hands.x, hands.y - 4, stroke: red, lw: 1.2, dash: [3, 3])
                s.callout("shoulders over hands", "肩在手正上方", 58, max(30, sh.y - 10), to: sh, color: red)
                s.callout("arms straight", "手臂伸直", 58, (sh.y + hands.y) / 2 + 12, to: at("elbow"), color: red)
                s.callout(child ? "heel of one hand" : "heel of hand, fingers laced", child ? "单手掌根" : "掌根按压，十指相扣",
                          286, min(270, hands.y + 40), to: hands, color: red, width: 120)
            }
        case 3:
            let perfusion = taps > 0 ? min(1, rate / 110) * (rate > 130 ? 0.8 : 1) : 0
            let rateColor = rate == 0 ? hex("#777777") : rate < 100 ? hex("#E39B4B") : rate > 120 ? red : hex("#2E9E5B")
            s.tonal(8, 8, 134, 62, r: 12, color: rateColor)
            s.label("Compressions \(Int(taps.rounded()))/30", "按压 \(Int(taps.rounded()))/30", 18, 26, size: 11, color: ink, bold: true)
            s.label(rate > 0 ? "\(Int(rate.rounded())) /min" : "aim 100–120 /min", rate > 0 ? "\(Int(rate.rounded())) 次/分" : "目标 100–120 次/分",
                    18, 43, size: 12, color: rateColor, bold: true)
            s.label("Blood to brain", "大脑供血", 18, 58, size: 8)
            s.rect(78, 55, 48, 6, r: 3, fill: hex("#EEEEEE"))
            s.rect(78, 55, 48 * perfusion, 6, r: 3, fill: hex("#C8323C"))
            let depth = infant ? "≈ 4 cm" : child ? "≈ 5 cm" : "5–6 cm"
            s.compressionSection(236, 8, press: press, depth: depth, baby: infant)
            let hands = at("hands")
            depthMark(&s, x: hands.x + (infant ? 26 : -30), top: hands.y - 12 + press * 4, depth: 12, text: depth, left: !infant)
            if who.age == .senior { s.tag("ribs may crack — keep going", "肋骨可能骨折——继续按", 84, 90, size: 10, color: red, bold: true) }
        case 4:
            breathInset(&s, 204, 8, baby: infant, t: t, art: "cpr-\(artPerson(who))-4i")
            let c = at("chest"), rise = max(0, sin(t * 2.2)), dx = infant ? 16.0 : -18
            s.arrow(CGPoint(x: c.x + dx, y: c.y - 4), CGPoint(x: c.x + dx, y: c.y - 14 - rise * 6), color: blue, lw: 2)
            s.tag(infant ? "chest just rises" : "watch the chest rise", infant ? "胸廓刚好抬起" : "看胸廓抬起", c.x + dx, infant ? c.y - 30 : c.y + 16,
                  size: 9, color: blue, anchor: .middle, bold: true)
            if infant {
                s.callout("mouth over mouth AND nose", "嘴包住口和鼻", 96, 150, to: at("mouth"), color: blue, width: 110)
                s.tag("2 gentle puffs", "轻吹 2 口", 180, 286, size: 10, color: blue, bold: true)
            }
        case 5:
            s.chestMap(infant ? 8 : 238, 8, 114, 112, mark: infant || child ? .padsFrontBack : .pads, baby: infant,
                       title: Bilingual("Pads on bare skin", "电极片贴裸露皮肤"))
            let hands = at("hands_up")
            let bx = infant ? max(52, head.x - 92) : max(52, min(hands.x, head.x) - 74)
            s.bubble("Stand clear!", "都别碰！", bx, max(24, head.y + (infant ? 30 : 4)), tip: CGPoint(x: head.x - 16, y: head.y + (infant ? 30 : 14)),
                     color: red, border: red)
            s.tag("then 30:2 until help takes over", "之后继续 30:2，直到急救人员接手", 180, 286, size: 10, bold: true, width: 300)
        default: break
        }
    }

    /// an adult forearm (sleeve pushed up) reaching in from off-frame to a hand at `palm`
    static func reachIn(_ s: inout Sketch, from: CGPoint, palm: CGPoint, dir: CGPoint, len L: Double, shape: SideFigure.Hand, thumb: Double,
                        gloves: Color? = nil) {
        var look = Look.rescuer
        look.gloves = gloves
        let aw = L * 0.5
        let wrist = CGPoint(x: palm.x - dir.x * L * 0.45, y: palm.y - dir.y * L * 0.45)
        // bare forearm about 1.2 hand-lengths long, then the pushed-up sleeve runs off the frame
        let u = unit(CGPoint(x: from.x - wrist.x, y: from.y - wrist.y))
        let dist = hypot(from.x - wrist.x, from.y - wrist.y), bare = min(dist * 0.65, L * 1.2)
        let cuff = CGPoint(x: wrist.x + u.x * bare, y: wrist.y + u.y * bare)
        s.taper([CGPoint(x: cuff.x + u.x * 4, y: cuff.y + u.y * 4), wrist], [aw * 0.95, aw * 0.6], fill: look.skin, line: look.skinLine)
        s.taper([CGPoint(x: from.x + u.x * 20, y: from.y + u.y * 20), cuff], [aw * 1.25, aw * 1.12], fill: look.top, line: look.topLine)
        s.line(cuff.x - u.y * aw * 0.5, cuff.y + u.x * aw * 0.5, cuff.x + u.y * aw * 0.5, cuff.y - u.x * aw * 0.5, stroke: look.topLine, lw: 1, opacity: 0.8)
        drawHand(&s, at: palm, dir: dir, len: L, shape: shape, look: look, thumb: thumb)
    }

    /// double-headed depth arrow beside the hands
    private static func depthMark(_ s: inout Sketch, x: Double, top: Double, depth: Double, text: String, left: Bool = false) {
        let red = hex("#D8434B")
        s.line(x - 5, top, x + 5, top, stroke: red, lw: 1.2)
        s.line(x - 5, top + depth, x + 5, top + depth, stroke: red, lw: 1.2)
        s.arrow(CGPoint(x: x, y: top + 1), CGPoint(x: x, y: top + depth - 1), color: red, lw: 1.4)
        s.tag(text, text, left ? x - 8 : x + 8, top + depth / 2, size: 9, color: red, anchor: left ? .end : .start, bold: true)
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
    @MainActor private static func breathInset(_ s: inout Sketch, _ x: Double, _ y: Double, baby: Bool, t: Double, art: String? = nil) {
        let w = 148.0, h = 118.0
        s.inset(x, y, w, h, baby ? "Head level, mouth + nose" : "Tilt head back, lift chin", baby ? "头保持水平，包住口鼻" : "仰头抬颏")
        if let art, let img = SceneArt.image(art) {
            // rendered close-up of the same moment
            let g = s.clipped(x, y + 18, w, h - 18)
            let ih = h - 18, iw = ih * 1.25
            g.ctx.draw(img, in: CGRect(x: x + (w - iw) / 2, y: y + 18, width: iw, height: ih))
            s.tag(baby ? "puff × 2" : "breath 1 s × 2", baby ? "轻吹 2 口" : "吹气 1 秒 × 2", x + w - 8, y + h - 12, size: 8,
                  color: hex("#3F95D6"), anchor: .end, bold: true)
            return
        }
        var g = s.clipped(x, y + 18, w, h - 18)
        let pr = baby ? 29.0 : 28
        let a = (baby ? 0 : 18.0) * .pi / 180
        let up = CGPoint(x: -cos(a), y: sin(a)), f = CGPoint(x: -up.y, y: up.x)
        let ground = y + h - 5
        let pc = CGPoint(x: x + 60, y: ground - pr * (baby ? 1.0 : 1.06))
        let look: Look = baby ? .baby : .man
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
        let look = Look.rescuer, L = 19.0
        let wrist = CGPoint(x: at.x - dir.x * L * 0.45, y: at.y - dir.y * L * 0.45)
        dressedArm(&s, from, lerp(from, wrist, 0.5), wrist, aw: 10, look: look)
        drawHand(&s, at: at, dir: dir, len: L, shape: shape, look: look, thumb: thumb)
    }
}
