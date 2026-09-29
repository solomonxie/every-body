import SwiftUI

extension Illustrations {
    static func bleeding(for who: Profile) -> Scenario {
        var s = Scenario(
            id: "severe-bleeding", group: .firstAid, title: Bilingual("Severe bleeding", "大出血止血"),
            params: ["stage": 0, "pressure": 0, "clot": 0, "lost": 0.3],
            steps: [
                .watch("Blood is pouring from a deep cut on the lower leg. Check it’s safe, then have them sit or lie down.",
                       "小腿上一道深伤口血流不止。确认环境安全，让伤者坐下或躺下。", set: ["stage": 0, "pressure": 0, "clot": 0, "lost": 0.5]),
                .watch("Call 911 on speaker. Put on gloves if there are any — or slip your hands into plastic bags.",
                       "开免提拨打 120。有手套就戴上——没有可用塑料袋套手。", set: ["stage": 1, "lost": 0.65]),
                .tryIt("Press hard on the wound with a clean pad or cloth, both hands — and keep pressing. Don’t lift it to check.",
                       "试一试：用干净纱布或布块双手用力按住伤口，并持续按压，不要掀开查看。", set: ["stage": 2],
                       TryStep(mode: .hold(param: "pressure", progress: "clot", seconds: 8, label: "HOLD 按住"), success: { $0[v: "clot"] >= 1 },
                               ok: Bilingual("Steady pressure lets a clot form (in real life: at least 10 minutes).", "持续按压让血凝块形成（实际至少 10 分钟）。"))),
                .watch("Soaked through? Add another pad on top — don’t remove the first. Then bandage firmly over the pads.",
                       "渗透了？在上面再加一块敷料，不要揭掉第一块。然后用绷带在敷料上加压包扎。", set: ["stage": 3, "pressure": 1, "clot": 1]),
                who.age == .infant
                    ? .watch("Still soaking through? Keep pressing hard and add pads on top until help arrives — tourniquets rarely fit a baby. Keep the baby warm.",
                             "仍在渗血？继续用力按压并在上面加敷料，直到急救人员到达——止血带很难适合婴儿。注意给婴儿保暖。", set: ["stage": 4])
                    : .watch("Still pouring from an arm or leg? Tourniquet 5–7 cm above the wound, tighten till it stops, note the time. Keep them warm.",
                             "四肢伤口仍在大量出血？在伤口上方 5–7 厘米处扎止血带，拧紧至不再出血，记下时间。注意给伤者保暖。", set: ["stage": 4]),
            ],
            draw: { s, p, t in drawBleeding(&s, p, t, who) },
            sources: ["ILCOR 2025 CoSTR / Red Cross first aid: direct pressure; tourniquet for life-threatening limb bleeding"]
        )
        s.profileNote = switch who.age {
        case .infant, .toddler, .child: Bilingual("Children have much less blood — a loss that looks small can be serious. Call 911 early.",
                                        "儿童血量少得多——看起来不多的失血也可能很危险。尽早拨打 120。")
        case .senior: Bilingual("65+: many take blood thinners, so bleeding lasts longer — press longer and tell 911 their medicines.",
                                "老人：很多人服用抗凝药，出血更久——按压时间要更长，并告知 120 所用药物。")
        case .adult: nil
        }
        return s
    }

    @MainActor private static func drawBleeding(_ s: inout Sketch, _ p: Params, _ t: Double, _ who: Profile) {
        let st = Int(p[v: "stage"].rounded()), pressure = p[v: "pressure"], clot = p[v: "clot"]
        let flow = st >= 3 ? 0 : st == 2 ? max(0, (1 - pressure * 0.85) * (1 - clot)) : 1
        let infant = who.age == .infant
        let v = artPerson(who)
        let stage = p[v: "stage"].clamped(0, 4), lo = min(3, Int(stage.rounded(.down))), f = stage - Double(lo), k = f * f * (3 - 2 * f)
        s.backdrop()
        s.art([("bleeding-\(v)-\(lo)", 1 - k), ("bleeding-\(v)-\(lo + 1)", k)])
        let m = SceneMarks.at("bleeding-\(v)-\(st)")
        let at = { (key: String) in m[key] ?? CGPoint(x: 180, y: 220) }
        let wound = at("wound"), band = at("band")
        let red = hex("#D8434B"), lx = infant ? 100.0 : 112
        if flow > 0.05 {
            // blood running off the shin to the floor
            let floor = wound.y + (infant ? 22 : 16), side = CGPoint(x: wound.x + 3, y: wound.y + 6)
            s.path("M \(wound.x) \(wound.y) C \(wound.x + 3) \(wound.y + 3) \(side.x) \(side.y - 2) \(side.x + 1) \(floor)",
                   stroke: hex("#B3202C"), lw: 2, opacity: min(1, flow * 1.5), cap: .round)
            let drops = Int((flow * 4).rounded())
            for i in 0..<drops {
                let u = (t * 1.4 + Double(i) / Double(max(1, drops))).wrap(1)
                s.circle(side.x + 1 + Double(i % 2) * 3, side.y + u * (floor - side.y), 1.8 - u, fill: hex("#C8323C"))
            }
        }
        let calm = max(0, 1 - abs(stage - stage.rounded()) * 4)
        s.group(opacity: calm) { g in
            switch st {
            case 0:
                // beside the casualty, so the leader reaches the shin without crossing them
                g.callout("deep cut, blood pouring", "深伤口，血流不止", infant ? 72 : 160, infant ? 222 : 140, to: wound, color: red)
                if !infant {
                    let h = at("rescuer_head")
                    g.bubble("Sit down — I’ll help", "坐下，我来帮你", min(300, h.x + 20), max(24, h.y - 30), tip: CGPoint(x: h.x - 4, y: h.y + 2))
                }
            case 1:
                g.phone(30, infant ? 150 : 250, number: g.t("911", "120"), t: t)
                g.callout("gloves — or plastic bags", "戴手套——或套塑料袋", lx + (infant ? 150 : 120), 60, to: at("hands"), color: hex("#6C63C0"))
            case 2:
                g.callout(infant ? "press hard, keep pressing" : "both hands, press hard", infant ? "用力按住，不要松开" : "双手用力按压",
                          lx, 60, to: at("hands"), color: red)
                g.tag("don’t lift to check", "不要掀开查看", lx, 84, size: 9, bold: true)
            case 3:
                g.tag("2nd pad on top — keep the first", "第二块叠上——不揭第一块", lx, 56, size: 9, color: hex("#555555"), bold: true, width: 150)
                g.tag("bandage firmly over the pads", "绷带在敷料上加压包扎", lx, 82, size: 9, color: hex("#555555"), bold: true, width: 150)
            case 4:
                if infant {
                    g.tag("more pads, keep pressing", "加敷料，继续按压", 12, 60, size: 9, color: red, anchor: .start, bold: true)
                    g.callout("keep baby warm", "给婴儿保暖", 12, 226, to: at("torso"), color: hex("#8A6A2A"), anchor: .start)
                } else {
                    g.callout("tourniquet 5–7 cm above the wound", "止血带：伤口上方 5–7 厘米", 256, 286, to: band, color: red, width: 240)
                    g.tag("tighten till it stops · write the time", "拧紧至不出血 · 记下时间", 352, 50, size: 9, color: red, anchor: .end, bold: true, width: 240)
                    g.callout("keep them warm", "注意保暖", 12, 286, to: at("torso"), color: hex("#8A6A2A"), anchor: .start)
                    let tag = CGPoint(x: band.x - 30, y: band.y - 16)
                    g.line(tag.x + 16, tag.y + 2, band.x - 2, band.y - 2, stroke: red, lw: 0.8)
                    g.rect(tag.x - 16, tag.y - 4, 32, 8, r: 2, fill: .white, stroke: red, lw: 1)
                    g.label("T 14:05", "T 14:05", tag.x, tag.y + 2.2, size: 6, color: red, anchor: .middle, bold: true)
                }
            default: break
            }
            if st == 2 || st == 3 { padInset(&g, 236, 8, pressure: st == 3 ? 1 : pressure, clot: clot, flow: flow, t: t) }
        }
        // status pill
        let status = flow > 0.3 ? red : hex("#2E9E5B")
        s.tonal(8, 8, 148, 28, r: 14, color: status)
        s.label("Bleeding \(Int((flow * 100).rounded()))%", "出血 \(Int((flow * 100).rounded()))%", 18, 22, size: 11, color: status, bold: true)
        s.rect(104, 19, 44, 6, r: 3, fill: hex("#EEEEEE"))
        s.rect(104, 19, 44 * clot, 6, r: 3, fill: hex("#2E9E5B"))
    }

    /// under the pad: pressure squeezes the torn vessel shut so a clot can seal it
    @MainActor private static func padInset(_ s: inout Sketch, _ x: Double, _ y: Double, pressure: Double, clot: Double, flow: Double, t: Double) {
        s.inset(x, y, 116, 100, "Under the pad", "敷料下面")
        let top = y + 50, cx = x + 58
        s.rect(x + 6, top, 104, 8, fill: hex("#F2C9A5"))
        s.rect(x + 6, top + 8, 104, 36, fill: hex("#F7E3A1"))
        let squash = pressure * 4
        s.rect(x + 6, top + 22 + squash * 0.5, 104, 10 - squash, r: 4, fill: hex("#C8323C"))
        s.rect(cx - 5, top - 1, 10, 24 + squash * 0.5, fill: hex("#8A1F2B"))
        s.ellipse(cx, top + 10, 6 * clot, 9 * clot, fill: hex("#5E1219"), opacity: clot)
        for i in 0..<Int((flow * 4).rounded()) {
            let u = (t * 1.8 + Double(i) * 0.25).wrap(1)
            s.circle(cx + Double(i % 2) * 4 - 2, top - 4 - u * 20, 2.2, fill: hex("#C8323C"), opacity: 1 - u)
        }
        s.rect(cx - 26, top - 12 + (1 - pressure) * -14, 52, 10, r: 2, fill: .white, stroke: hex("#BBBBBB"))
        s.arrow(CGPoint(x: cx, y: top - 30 + (1 - pressure) * -2), CGPoint(x: cx, y: top - 16 + (1 - pressure) * -14), lw: 2)
        s.label("vessel", "血管", x + 8, top + 42, size: 8, color: hex("#8A1F2B"))
        if clot > 0.5 { s.label("clot", "血凝块", cx + 10, top + 16, size: 8, color: hex("#5E1219"), bold: true) }
    }

    static func heatDepth(_ p: Params) -> Double { max(0, 110 * (1 - p[v: "cooling"] * p[v: "minutes"] / 20)) }

    static func burns(for who: Profile) -> Scenario {
        var s = Scenario(
            id: "burns", group: .firstAid, title: Bilingual("Burns", "烧烫伤"),
            params: ["stage": 0, "minutes": 0, "cooling": 0],
            steps: [
                .watch("Scalded by a kettle. Move away from the heat. The heat keeps sinking into the skin for minutes — act fast.",
                       "被开水烫伤。先远离热源。热量会在几分钟内继续向皮肤深处传导——要快。", set: ["stage": 0, "minutes": 0, "cooling": 0]),
                .tryIt("Cool it under cool running tap water. Drag the time — aim for the full 20 minutes.", "试一试：放在流动的凉自来水下冲。拖动时间——目标 20 分钟。",
                       set: ["stage": 1, "cooling": 1],
                       TryStep(mode: .scrub([Scrub(param: "minutes", label: "Minutes 分钟", min: 0, max: 20, digits: 0)]), success: { $0[v: "minutes"] >= 19.5 },
                               ok: Bilingual("20 minutes — even up to 3 hours after the burn it still helps.", "20 分钟——即使烫伤 3 小时内冲洗仍有帮助。"),
                               demo: ["minutes": 20])),
                .watch("While it cools, take off rings, watches and tight clothes near the burn. No ice, butter or toothpaste.",
                       "冲水时取下戒指、手表和烫伤处附近的紧身衣物。不要用冰、黄油或牙膏。", set: ["stage": 2, "minutes": 20]),
                .watch("Cover loosely with cling film laid along the burn — don’t wrap it round tight. A clean plastic bag works for a hand.",
                       "用保鲜膜顺着伤处松松地覆盖——不要缠紧。手部可套干净塑料袋。", set: ["stage": 3]),
                .watch("See a doctor if it’s bigger than their palm, on the face, hands, feet, groin or a joint, looks deep, or is chemical or electrical.",
                       "面积大于伤者手掌，或在面部、手足、会阴、关节，或看起来较深，或为化学、电烧伤——需就医。", set: ["stage": 4]),
            ],
            draw: { s, p, t in drawBurns(&s, p, t, who) },
            sources: ["ILCOR 2025 CoSTR / Red Cross burns first aid: cool with running water for 20 minutes, cover with cling film"]
        )
        s.profileNote = switch who.age {
        case .infant: Bilingual("Baby: cool the burn 20 min but keep the rest of the baby wrapped and warm. Any burn on a baby needs a doctor.",
                                "婴儿：冲凉烫伤处 20 分钟，但身体其他部位要包好保暖。婴儿烫伤一律就医。")
        case .toddler, .child: Bilingual("Child: a burn bigger than the child’s own palm, or on the face, hands or groin → hospital. Keep them warm.",
                               "儿童：面积大于孩子自己的手掌，或在面部、手部、会阴——去医院。注意保暖。")
        case .senior: Bilingual("65+: thin skin burns deeper at lower heat — see a doctor sooner.", "老人：皮肤薄，较低温度也会烫得更深——更应及早就医。")
        case .adult: nil
        }
        return s
    }

    private static func drawBurns(_ s: inout Sketch, _ p: Params, _ t: Double, _ who: Profile) {
        let st = Int(p[v: "stage"].rounded()), depth = heatDepth(p)
        let floor = 292.0
        s.room(floor: floor, blob: 120)
        let counterX = 200.0, top = floor - 0.53 * 220
        // plain splashback panel, counter, sink cut away
        s.rect(counterX + 6, top - 84, 170, 84, r: 14, fill: hex("#E2EAF0"))
        s.rect(counterX, top + 8, 170, floor - top - 8, r: 6, fill: hex("#DCBF98"))
        s.rect(counterX, top + 8, 170, 6, fill: hex("#C9AA82"))
        s.line(counterX + 80, top + 20, counterX + 80, floor - 8, stroke: hex("#C9AA82"), lw: 1)
        for x in [counterX + 70, counterX + 90] { s.rect(x - 1.5, top + 26, 3, 14, r: 1.5, fill: hex("#B8966C")) }
        let carried = who.age == .infant || who.age == .toddler
        let basin = carried ? (x0: counterX + 6, x1: counterX + 96) : (x0: counterX + 10, x1: counterX + 100)
        s.rect(basin.x0, top + 4, basin.x1 - basin.x0, 44, r: 12, fill: hex("#D3DBE2"))
        s.rect(basin.x0 + 4, top + 4, basin.x1 - basin.x0 - 8, 8, r: 4, fill: hex("#BFC9D2"))
        s.rect(counterX - 4, top, basin.x0 - counterX + 6, 8, r: 4, fill: hex("#F1EEE9"))
        s.rect(basin.x1 - 2, top, 364 - basin.x1, 8, r: 4, fill: hex("#F1EEE9"))

        // person at the sink, facing right; a child stands on a stool, a baby or toddler is held by a parent
        let kid = who.age == .child
        let c = Casualty(who, adult: 220)
        let stool = kid ? 52.0 : 0
        if kid { s.rect(128, floor - stool, 56, stool, r: 8, fill: hex("#A9BFDD")); s.rect(128, floor - stool, 56, 8, r: 4, fill: hex("#BFD0E6")) }
        var v = SideFigure(h: c.h, build: c.build, look: c.look, hip: .zero, lean: carried ? 4 : 10, face: st == 0 ? .distress : .calm, bump: c.bump)
        // weight on the far leg, the near knee soft
        v.nearLeg = .init(hip: 12, knee: 16, point: 6)
        v.farLeg = .init(hip: -4, knee: 3)
        v.hip = CGPoint(x: 160, y: 0)
        v.hip.y = v.hipY(onFloor: floor - stool)
        v.look.longSleeves = false
        let underTap = st == 1 || st == 2
        var parent: SideFigure? = nil
        if carried {
            // sits on the parent's forearm, against her chest
            let toddler = who.age == .toddler
            var m = SideFigure(h: 220, look: .helper, hip: CGPoint(x: counterX - (toddler ? 40 : 26), y: floor - SideFigure.hipHeight(220, .adult)), lean: 4)
            m.nearLeg = .init(hip: 10, knee: 14, point: 6)
            m.farLeg = .init(hip: -4, knee: 3)
            m.hip.y = m.hipY(onFloor: floor)
            // a toddler sits lower and further out on the hip, clear of her face
            let front = m.front(toddler ? 0.16 : 0.3)
            v.hip = CGPoint(x: front.x + c.build.depth * c.h * (toddler ? 0.7 : 0.45), y: front.y - 2)
            v.nearLeg = .init(hip: 84, knee: 70, point: 20)
            v.farLeg = .init(hip: 76, knee: 64, point: 20)
            m.far = .init(reach: CGPoint(x: v.hip.x + 6, y: v.hip.y + c.build.legW * c.h * 0.5 + 3), hand: .open, handAngle: 0)
            parent = m
        }
        if underTap {
            v.near = .init(reach: carried ? CGPoint(x: counterX + 70, y: top - 12) : CGPoint(x: counterX + 86, y: top - 16), hand: .open, handAngle: 8)
        } else if st == 0 {
            v.near = .init(shoulder: 20, elbow: 100)
        } else {
            v.near = .init(reach: CGPoint(x: counterX + 20, y: top - 6), hand: .open, handAngle: 4)
        }
        v.far = carried ? .init(shoulder: 30, elbow: 50) : .init(shoulder: 8, elbow: 20)
        let elbow = v.elbow(), palm = v.palm()
        let burn = lerp(elbow, palm, 0.45), dir = unit(CGPoint(x: palm.x - elbow.x, y: palm.y - elbow.y))

        // tap over the burn
        let tapX = underTap ? burn.x : basin.x0 + 30
        s.path("M \(tapX + 44) \(top) L \(tapX + 44) \(top - 52) Q \(tapX + 44) \(top - 64) \(tapX + 30) \(top - 64) L \(tapX) \(top - 64) L \(tapX) \(top - 58)",
               stroke: hex("#9AA3AB"), lw: 6, cap: .round)
        s.rect(tapX + 38, top - 44, 14, 5, r: 2, fill: hex("#7C868F"))
        if st == 0 { s.kettle(counterX + 136, top) }

        parent?.drawBack(&s)
        parent?.drawBody(&s)
        v.draw(&s)
        if var m = parent {
            // her hand steadies the arm under the water
            m.near = st == 0 ? .init(reach: v.front(0.5), hand: .open) : .init(reach: lerp(elbow, palm, 0.12), hand: .open, handAngle: -10)
            m.drawArm(&s, near: true)
        }
        // the burn, fading as it cools
        let heat = depth / 110, aw = v.build.armW * v.h * 0.4
        s.group(translate: burn, rotate: atan2(dir.y, dir.x) * 180 / .pi) { g in
            g.ellipse(0, 0, 11, aw, fill: hex("#E0503C"), opacity: 0.35 + 0.5 * heat)
            if st != 1 || heat > 0.3 { g.circle(3, -2, 2, fill: hex("#FFF3E6"), stroke: hex("#E8B79E"), lw: 0.6) }
        }
        if underTap {
            let blue = hex("#6FB4E8")
            for i in 0..<5 {
                let u = (t * 2.2 + Double(i) * 0.2).wrap(1)
                s.line(tapX - 2 + Double(i % 2) * 3, top - 56 + u * 30, tapX - 2 + Double(i % 2) * 3, top - 50 + u * 30, stroke: blue, lw: 2.5, cap: .round)
            }
            s.line(tapX, top - 56, tapX, burn.y - 5, stroke: blue, lw: 3, opacity: 0.5)
            // runs off the arm into the basin
            let lo = max(basin.x0 + 6, burn.x - 8), hi = min(basin.x1 - 6, burn.x + 10)
            s.path("M \(burn.x - 6) \(burn.y + 4) Q \(lo - 2) \(burn.y + 16) \(lo) \(top + 30) M \(burn.x + 8) \(burn.y + 4) Q \(hi + 2) \(burn.y + 16) \(hi) \(top + 30)",
                   stroke: blue, lw: 2, opacity: 0.6)
        }
        if st >= 3 {
            // cling film laid along the burn, and the roll on the counter
            s.group(translate: burn, rotate: atan2(dir.y, dir.x) * 180 / .pi) { g in
                g.rect(-18, -aw - 3, 36, 2 * aw + 6, r: 4, fill: hex("#D8EEF8"), stroke: hex("#9CC7DC"), lw: 1, opacity: 0.55)
                g.line(-13, -aw - 1, 8, -aw - 1, stroke: .white, lw: 1.2)
            }
            let roll = CGPoint(x: counterX + 128, y: top - 7)
            s.rect(roll.x - 24, roll.y - 7, 48, 14, r: 7, fill: hex("#E8F2F7"), stroke: hex("#9CB0BC"))
            s.ellipse(roll.x + 24, roll.y, 3.5, 7, fill: hex("#F4F8FA"), stroke: hex("#9CB0BC"))
            s.ellipse(roll.x + 24, roll.y, 1.5, 3, fill: hex("#C9B38A"))
            s.line(roll.x - 20, roll.y - 3, roll.x + 14, roll.y - 3, stroke: .white, lw: 1.5, cap: .round)
        }
        let red = hex("#D8434B")
        switch st {
        case 0:
            s.callout("scald on the forearm", "前臂烫伤", 250, 66, to: burn, color: red)
            s.tag("move away from the heat", "先远离热源", 250, 42, size: 9, bold: true)
        case 1:
            s.callout("cool running water", "流动的凉水", 290, 70, to: CGPoint(x: burn.x + 2, y: burn.y - 12), color: hex("#3F7FA8"))
        case 2:
            // rings and watch off; no ice, butter, toothpaste
            s.circle(basin.x1 + 10, top - 4, 3.5, stroke: hex("#D4A62A"), lw: 1.6)
            s.rect(basin.x1 + 16, top - 6, 12, 5, r: 2, fill: hex("#555A60"))
            s.callout("rings & watch off", "摘下戒指手表", 300, 96, to: CGPoint(x: basin.x1 + 16, y: top - 6), color: hex("#444444"))
            let items = [("ice", "冰"), ("butter", "黄油"), ("toothpaste", "牙膏")]
            for (i, it) in items.enumerated() {
                let x = 212 + Double(i) * 50, y = 30.0
                switch i {
                case 0: s.rect(x - 8, y - 8, 16, 16, r: 3, fill: hex("#DDF1FB"), stroke: hex("#8CC4E0"))
                case 1: s.rect(x - 11, y - 6, 22, 12, r: 2, fill: hex("#F7E08A"), stroke: hex("#D2B44E"))
                default: s.path("M \(x - 12) \(y - 4) L \(x + 8) \(y - 5) L \(x + 12) \(y) L \(x + 8) \(y + 5) L \(x - 12) \(y + 4) Z", fill: .white, stroke: hex("#7FA7C9"))
                }
                s.line(x - 12, y - 12, x + 12, y + 12, stroke: red, lw: 2.2, cap: .round)
                s.line(x + 12, y - 12, x - 12, y + 12, stroke: red, lw: 2.2, cap: .round)
                s.label(it.0, it.1, x, y + 24, size: 9, color: red, anchor: .middle)
            }
        case 3:
            s.callout("cling film laid on, not wrapped", "保鲜膜平铺，不要缠绕", 270, 60, to: CGPoint(x: burn.x, y: burn.y - 6), color: hex("#3F7FA8"), width: 140)
            s.callout("cling film", "保鲜膜", 300, 100, to: CGPoint(x: counterX + 128, y: top - 12), color: hex("#555555"))
        case 4:
            // top left, where the skin inset was: clear of the arm and a carried child
            doctorCard(&s, 6, 8, look: v.look, baby: who.age == .infant)
        default: break
        }
        if st <= 2 { skinInset(&s, 8, 8, depth: depth, cooling: underTap, minutes: p[v: "minutes"] * p[v: "cooling"], t: t) }
    }

    /// when a burn needs a doctor: their own palm as the size check, then the places and kinds that always do
    private static func doctorCard(_ s: inout Sketch, _ x: Double, _ y: Double, look: Look, baby: Bool) {
        let w = 146.0, h = 132.0, red = hex("#D8434B")
        s.inset(x, y, w, h, "See a doctor if…", "以下情况需就医")
        drawHand(&s, at: CGPoint(x: x + 22, y: y + 44), dir: CGPoint(x: 0, y: -1), len: 30, shape: .open, look: look)
        s.shape(Path(roundedRect: CGRect(x: x + 8, y: y + 24, width: 28, height: 38), cornerRadius: 10), stroke: red, lw: 1.2, dash: [3, 2])
        s.label("bigger than their palm", "大于伤者手掌", x + 42, y + 40, size: 9, color: red, bold: true)
        s.label("with fingers", "（含手指）", x + 42, y + 52, size: 8, color: hex("#8A8378"))
        let rows = [("face, hands, feet, groin, joints", "面部 · 手足 · 会阴 · 关节"),
                    ("deep, white or charred", "深度：发白或焦黑"),
                    ("chemical or electrical", "化学或电烧伤"),
                    baby ? ("any burn on a baby", "婴儿任何烫伤") : ("blisters on a large area", "大面积水疱")]
        for (i, row) in rows.enumerated() {
            let yy = y + 76 + Double(i) * 14
            s.circle(x + 12, yy - 3, 2.2, fill: red)
            s.label(row.0, row.1, x + 19, yy, size: 8.5, color: hex("#444444"))
        }
    }

    /// skin cut open: how deep the heat has reached, and the cooling timer
    private static func skinInset(_ s: inout Sketch, _ x: Double, _ y: Double, depth: Double, cooling: Bool, minutes: Double, t: Double) {
        s.inset(x, y, 150, 118, "Inside the skin", "皮肤内部")
        let top = y + 38, epi = top + 5, derm = top + 28, fat = top + 46
        s.rect(x + 8, top, 134, epi - top, fill: hex("#F5D7BF"))
        s.rect(x + 8, epi, 134, derm - epi, fill: hex("#EFC1A8"))
        s.rect(x + 8, derm, 134, fat - derm, fill: hex("#F7E3A1"))
        for k in 0..<3 {
            let x0 = x + 50 + Double(k) * 22
            s.path("M \(x0) \(derm - 3) C \(x0) \(epi + 5) \(x0 + 8) \(epi + 5) \(x0 + 8) \(derm - 3)", stroke: hex("#C8323C"), lw: 1)
        }
        let reach = depth / 110 * (fat - top)
        if depth > 1 { s.path("M \(x + 36) \(top) C \(x + 44) \(top + reach * 1.2) \(x + 106) \(top + reach * 1.2) \(x + 114) \(top) Z", fill: hex("#E0503C"), opacity: 0.55) }
        if cooling {
            var g = s.clipped(x, top - 18, 150, 18)
            for i in 0..<5 {
                let yy = (t * 40 + Double(i) * 7).wrap(16)
                g.line(x + 44 + Double(i) * 16, top - 18 + yy, x + 44 + Double(i) * 16, top - 13 + yy, stroke: hex("#3F95D6"), lw: 2, cap: .round)
            }
        }
        s.label("skin", "皮肤", x + 140, epi + 10, size: 8, anchor: .end)
        s.label("fat", "脂肪", x + 140, derm + 12, size: 8, anchor: .end)
        let cooled = depth < 8, status = cooled ? hex("#2E9E5B") : hex("#E0503C")
        s.label(cooled ? "Heat drawn out" : "Heat still sinking in", cooled ? "热量已散出" : "热量仍在向深处扩散", x + 8, fat + 14, size: 9, color: status, bold: true)
        s.label("cooling \(Int(minutes.rounded())) / 20 min", "冲水 \(Int(minutes.rounded())) / 20 分钟", x + 8, fat + 27, size: 9)
    }
}
extension Sketch {
    /// kettle with steam — what caused the scald
    mutating func kettle(_ x: Double, _ y: Double) {
        rect(x - 16, y - 20, 30, 20, r: 7, fill: hex("#D9DDE2"), stroke: hex("#8C949C"))
        path("M \(x - 16) \(y - 12) L \(x - 26) \(y - 18)", stroke: hex("#8C949C"), lw: 3, cap: .round)
        path("M \(x - 8) \(y - 20) Q \(x) \(y - 30) \(x + 8) \(y - 20)", stroke: hex("#555A60"), lw: 2)
        for i in 0..<3 { path("M \(x - 24 + Double(i) * 5) \(y - 24) q -4 -6 0 -12 q 4 -6 0 -12", stroke: hex("#BBBBBB"), lw: 1.2) }
    }
}
