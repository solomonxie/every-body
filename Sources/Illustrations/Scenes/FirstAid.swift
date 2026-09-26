import SwiftUI

extension Illustrations {
    static func bleeding(for who: Profile) -> Scenario {
        var s = Scenario(
            id: "severe-bleeding", group: .firstAid, title: Bilingual("Severe bleeding", "大出血止血"),
            params: ["stage": 0, "pressure": 0, "clot": 0, "lost": 0.3],
            steps: [
                .watch("Blood is pouring from a deep cut. Check it’s safe, then have them sit or lie down.",
                       "深部伤口血流不止。确认环境安全，让伤者坐下或躺下。", set: ["stage": 0, "pressure": 0, "clot": 0, "lost": 0.5]),
                .watch("Call 120/911 on speaker. Put on gloves if there are any — or slip your hands into plastic bags.",
                       "开免提拨打 120。有手套就戴上——没有可用塑料袋套手。", set: ["stage": 1, "lost": 0.65]),
                .tryIt("Press hard on the wound with a clean pad or cloth, both hands — and keep pressing. Don’t lift it to check.",
                       "试一试：用干净纱布或布块双手用力按住伤口，并持续按压，不要掀开查看。", set: ["stage": 2],
                       TryStep(mode: .hold(param: "pressure", progress: "clot", seconds: 8, label: "HOLD 按住"), success: { $0[v: "clot"] >= 1 },
                               ok: Bilingual("Steady pressure lets a clot form (in real life: at least 10 minutes).", "持续按压让血凝块形成（实际至少 10 分钟）。"))),
                .watch("Soaked through? Add another pad on top — don’t remove the first. Then bandage firmly over the pads.",
                       "渗透了？在上面再加一块敷料，不要揭掉第一块。然后用绷带在敷料上加压包扎。", set: ["stage": 3, "pressure": 1, "clot": 1]),
                .watch("Still pouring from an arm or leg? Tourniquet 5–7 cm above the wound, tighten till it stops, note the time. Keep them warm.",
                       "四肢伤口仍在大量出血？在伤口上方 5–7 厘米处扎止血带，拧紧至不再出血，记下时间。注意给伤者保暖。", set: ["stage": 4]),
            ],
            draw: { s, p, t in drawBleeding(&s, p, t, who) },
            sources: ["ILCOR 2025 CoSTR / Red Cross first aid: direct pressure; tourniquet for life-threatening limb bleeding"]
        )
        s.profileNote = switch who.age {
        case .infant, .child: Bilingual("Children have much less blood — a loss that looks small can be serious. Call 120 early.",
                                        "儿童血量少得多——看起来不多的失血也可能很危险。尽早拨打 120。")
        case .senior: Bilingual("65+: many take blood thinners, so bleeding lasts longer — press longer and tell 120 their medicines.",
                                "老人：很多人服用抗凝药，出血更久——按压时间要更长，并告知 120 所用药物。")
        case .adult: nil
        }
        return s
    }

    private static func drawBleeding(_ s: inout Sketch, _ p: Params, _ t: Double, _ who: Profile) {
        let st = Int(p[v: "stage"].rounded()), pressure = p[v: "pressure"], clot = p[v: "clot"]
        let flow = st >= 3 ? 0 : st == 2 ? max(0, (1 - pressure * 0.85) * (1 - clot)) : 1
        let floor = 274.0
        s.room(floor: floor)
        let c = who.isKid ? Casualty(Profile(age: .child), adult: 200) : Casualty(who, adult: 200)

        // casualty sits on the floor facing right, injured forearm held out
        var v = SideFigure(h: c.h, build: c.build, look: c.look, hip: .zero, lean: -6, face: st >= 3 ? .calm : .distress, bump: c.bump)
        v.hip = CGPoint(x: who.isKid ? 86 : 64, y: floor - c.build.legW * c.h * 0.5 - 3)
        v.nearLeg = .init(hip: 96, knee: 16, point: 10)
        v.farLeg = .init(hip: 115, knee: 60, point: 10)
        v.near = .init(reach: CGPoint(x: v.hip.x + 0.34 * c.h, y: v.hip.y - 0.17 * c.h), hand: .open, handAngle: -4)
        v.far = .init(shoulder: 30, elbow: 60)
        let elbow = v.elbow(), palm = v.palm()
        let wound = lerp(elbow, palm, 0.5)
        let dir = unit(CGPoint(x: palm.x - elbow.x, y: palm.y - elbow.y))

        // rescuer kneels facing left
        let rh = 200.0
        var r = SideFigure(h: rh, look: .rescuer, hip: .zero, facing: -1, lean: st <= 1 ? 10 : 34)
        r.look.gloves = st >= 1 ? hex("#8E86D8") : nil
        r.hip = CGPoint(x: wound.x + (st == 0 ? 92 : 66), y: floor - r.build.thigh * rh - r.build.legW * rh * 0.5)
        r.nearLeg = .init(hip: 0, knee: 90, point: 90)
        r.farLeg = .init(hip: 4, knee: 92, point: 90)
        let push = pressure * 2
        switch st {
        case 2, 3:
            r.near = .init(reach: CGPoint(x: wound.x + 2, y: wound.y - 7 + push), hand: .open, handAngle: 180)
            r.far = .init(reach: CGPoint(x: wound.x - 3, y: wound.y - 11 + push), hand: .open, handAngle: 185)
        case 4:
            r.near = .init(reach: CGPoint(x: wound.x - 20, y: wound.y - 14), hand: .fist)
            r.far = .init(reach: CGPoint(x: wound.x - 14, y: wound.y - 18), hand: .fist)
        default:
            // gloves on, hands ready
            r.near = .init(shoulder: 10, elbow: 95)
            r.far = .init(shoulder: 4, elbow: 100)
        }

        // blood: pool on the floor, drops falling from the wound
        let pool = min(1, p[v: "lost"]) * 40
        s.ellipse(wound.x + 4, floor + 5, pool, pool * 0.18, fill: hex("#A8232E"), opacity: 0.85)
        r.drawBack(&s)
        v.draw(&s)
        s.ellipse(wound.x, wound.y, 9, 4, fill: hex("#B3202C"))
        let drops = Int((flow * 7).rounded())
        for i in 0..<drops {
            let u = (t * 1.3 + Double(i) / Double(max(1, drops))).wrap(1)
            s.circle(wound.x - 4 + Double(i % 3) * 4, wound.y + 5 + u * (floor - wound.y - 5), 2.6 - u, fill: hex("#C8323C"))
        }
        if st >= 2 {
            // pads; a second one on top, then the bandage round the arm
            let layers = st >= 3 ? 2 : 1
            for i in 0..<layers {
                s.rect(wound.x - 13 + Double(i) * 2, wound.y - 7 - Double(i) * 4 + push, 26, 6, r: 2, fill: .white, stroke: hex("#C9C2B8"))
            }
        }
        if st >= 3 {
            for k in -2...2 {
                let c0 = CGPoint(x: wound.x + dir.x * Double(k) * 6, y: wound.y + dir.y * Double(k) * 6)
                s.limb([CGPoint(x: c0.x - 3, y: c0.y - 9), CGPoint(x: c0.x + 3, y: c0.y + 6)], w: 6, fill: hex("#FBF8F2"), line: hex("#CFC6B8"))
            }
        }
        if st == 4 {
            let band = lerp(elbow, wound, 0.4)
            s.limb([CGPoint(x: band.x - 1, y: band.y - 8), CGPoint(x: band.x + 1, y: band.y + 7)], w: 6, fill: hex("#2F3136"), line: hex("#15161A"))
            s.line(band.x - 9, band.y - 12, band.x + 7, band.y - 8, stroke: hex("#5A5E66"), lw: 3, cap: .round)
            s.tag("TIME 14:05", "时间 14:05", band.x + 6, band.y + 26, size: 9, color: hex("#D8434B"), bold: true)
        }
        r.drawBody(&s)
        r.drawArm(&s, near: false)
        r.drawArm(&s, near: true)

        let red = hex("#D8434B")
        switch st {
        case 0: s.tag("sit or lie them down", "让伤者坐下或躺下", 250, 96, size: 10, bold: true)
        case 1:
            s.phone(320, floor - 26, number: s.t("911", "120"), t: t)
            s.tag("gloves — or plastic bags", "戴手套——或套塑料袋", 250, 96, size: 10, color: hex("#6C63C0"), bold: true)
        case 4: s.tag("5–7 cm above the wound", "伤口上方 5–7 厘米", 250, 96, size: 10, color: red, bold: true)
        default: break
        }
        if st == 2 || st == 3 { padInset(&s, 236, 8, pressure: st == 3 ? 1 : pressure, clot: clot, flow: flow, t: t) }
        let status = flow > 0.3 ? red : hex("#2E9E5B")
        s.rect(8, 8, 148, 44, r: 8, fill: .white, stroke: status, lw: 2)
        s.label("Bleeding \(Int((flow * 100).rounded()))%", "出血 \(Int((flow * 100).rounded()))%", 18, 26, size: 12, color: status, bold: true)
        s.label("clot", "凝血", 18, 43, size: 9)
        s.rect(50, 38, 96, 6, r: 3, fill: hex("#EEEEEE"))
        s.rect(50, 38, 96 * clot, 6, r: 3, fill: hex("#2E9E5B"))
    }

    /// under the pad: pressure squeezes the torn vessel shut so a clot can seal it
    private static func padInset(_ s: inout Sketch, _ x: Double, _ y: Double, pressure: Double, clot: Double, flow: Double, t: Double) {
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
        s.arrow(CGPoint(x: cx, y: top - 36 + (1 - pressure) * -2), CGPoint(x: cx, y: top - 16 + (1 - pressure) * -14), lw: 2)
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
        case .child: Bilingual("Child: a burn bigger than the child’s own palm, or on the face, hands or groin → hospital. Keep them warm.",
                               "儿童：面积大于孩子自己的手掌，或在面部、手部、会阴——去医院。注意保暖。")
        case .senior: Bilingual("65+: thin skin burns deeper at lower heat — see a doctor sooner.", "老人：皮肤薄，较低温度也会烫得更深——更应及早就医。")
        case .adult: nil
        }
        return s
    }

    private static func drawBurns(_ s: inout Sketch, _ p: Params, _ t: Double, _ who: Profile) {
        let st = Int(p[v: "stage"].rounded()), depth = heatDepth(p)
        let floor = 292.0
        s.room(floor: floor)
        let counterX = 200.0, top = floor - 0.53 * 220
        // tiles, counter, sink cut away
        for row in 0..<4 {
            for col in 0..<8 {
                s.rect(counterX + Double(col) * 20 + Double(row % 2) * 10, top - 80 + Double(row) * 20, 19, 19, fill: hex("#E6EEF2"), stroke: hex("#D0DCE2"), lw: 0.8)
            }
        }
        s.rect(counterX, top + 8, 160, floor - top - 8, fill: hex("#C49A6C"))
        s.line(counterX + 80, top + 14, counterX + 80, floor - 6, stroke: hex("#A47C52"), lw: 1.2)
        let basin = (x0: counterX + 34, x1: counterX + 118)
        s.rect(basin.x0, top + 4, basin.x1 - basin.x0, 44, r: 10, fill: hex("#D5DCE1"), stroke: hex("#98A4AD"), lw: 1.2)
        s.rect(counterX - 4, top, basin.x0 - counterX + 6, 8, r: 2, fill: hex("#E4E0D8"), stroke: hex("#BDB6AA"))
        s.rect(basin.x1 - 2, top, 364 - basin.x1, 8, r: 2, fill: hex("#E4E0D8"), stroke: hex("#BDB6AA"))

        // person at the sink, facing right; a child stands on a stool
        let kid = who.isKid
        let c = kid ? Casualty(Profile(age: .child), adult: 220) : Casualty(who, adult: 220)
        let stool = kid ? 52.0 : 0
        if kid { s.rect(128, floor - stool, 56, stool, r: 3, fill: hex("#7FA7C9"), stroke: hex("#5A83A6")) }
        var v = SideFigure(h: c.h, build: c.build, look: c.look, hip: .zero, lean: 10, face: st == 0 ? .distress : .calm, bump: c.bump)
        v.hip = CGPoint(x: 160, y: floor - stool - SideFigure.hipHeight(c.h, c.build))
        v.nearLeg = .init(hip: 4, knee: 2)
        v.farLeg = .init(hip: -3, knee: 2)
        v.look.longSleeves = false
        let underTap = st == 1 || st == 2
        if underTap {
            v.near = .init(reach: CGPoint(x: counterX + 72, y: top - 18), hand: .open, handAngle: 8)
        } else if st == 0 {
            v.near = .init(shoulder: 20, elbow: 100)
        } else {
            v.near = .init(reach: CGPoint(x: counterX + 20, y: top - 6), hand: .open, handAngle: 4)
        }
        v.far = .init(shoulder: 8, elbow: 20)
        let elbow = v.elbow(), palm = v.palm()
        let burn = lerp(elbow, palm, 0.45), dir = unit(CGPoint(x: palm.x - elbow.x, y: palm.y - elbow.y))

        // tap over the burn
        let tapX = underTap ? burn.x : basin.x0 + 30
        s.path("M \(tapX + 44) \(top) L \(tapX + 44) \(top - 52) Q \(tapX + 44) \(top - 64) \(tapX + 30) \(top - 64) L \(tapX) \(top - 64) L \(tapX) \(top - 58)",
               stroke: hex("#9AA3AB"), lw: 6, cap: .round)
        s.rect(tapX + 38, top - 44, 14, 5, r: 2, fill: hex("#7C868F"))
        if st == 0 { s.kettle(counterX + 136, top) }

        v.draw(&s)
        // the burn, fading as it cools
        let heat = depth / 110
        s.group(translate: burn, rotate: atan2(dir.y, dir.x) * 180 / .pi) { g in
            g.ellipse(0, 0, 13, 5, fill: hex("#E0503C"), opacity: 0.35 + 0.5 * heat)
            if st != 1 || heat > 0.3 { g.circle(3, -2, 2, fill: hex("#FFF3E6"), stroke: hex("#E8B79E"), lw: 0.6) }
        }
        if underTap {
            let blue = hex("#6FB4E8")
            for i in 0..<5 {
                let u = (t * 2.2 + Double(i) * 0.2).wrap(1)
                s.line(tapX - 2 + Double(i % 2) * 3, top - 56 + u * 30, tapX - 2 + Double(i % 2) * 3, top - 50 + u * 30, stroke: blue, lw: 2.5, cap: .round)
            }
            s.line(tapX, top - 56, tapX, burn.y - 5, stroke: blue, lw: 3, opacity: 0.5)
            s.path("M \(burn.x - 10) \(burn.y + 4) Q \(burn.x - 14) \(burn.y + 22) \(burn.x - 12) \(top + 30) M \(burn.x + 10) \(burn.y + 4) Q \(burn.x + 14) \(burn.y + 22) \(burn.x + 12) \(top + 30)",
                   stroke: blue, lw: 2, opacity: 0.6)
        }
        if st >= 3 {
            // cling film laid along the burn, and the roll on the counter
            s.group(translate: burn, rotate: atan2(dir.y, dir.x) * 180 / .pi) { g in
                g.rect(-22, -8, 44, 15, r: 4, fill: hex("#D8EEF8"), stroke: hex("#9CC7DC"), lw: 1, opacity: 0.55)
                g.line(-16, -5, 10, -5, stroke: .white, lw: 1.2)
            }
            s.rect(counterX + 110, top - 14, 40, 14, r: 3, fill: hex("#E8EEF2"), stroke: hex("#9CB0BC"))
            s.label("film", "保鲜膜", counterX + 130, top - 4, size: 7, color: hex("#5A7080"), anchor: .middle)
        }
        let red = hex("#D8434B")
        switch st {
        case 2:
            // rings and watch off; no ice, butter, toothpaste
            s.circle(counterX + 14, top - 4, 3.5, stroke: hex("#D4A62A"), lw: 1.6)
            s.rect(counterX + 20, top - 6, 12, 5, r: 2, fill: hex("#555A60"))
            s.tag("rings & watch off", "摘下戒指手表", counterX + 30, top - 96, size: 9, bold: true)
            let items = [("ice", "冰"), ("butter", "黄油"), ("toothpaste", "牙膏")]
            for (i, it) in items.enumerated() {
                let x = 208 + Double(i) * 50, y = 30.0
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
            s.tag("loose, not wrapped tight", "松松覆盖，不要缠紧", 250, 40, size: 10, color: hex("#3F7FA8"), bold: true)
        case 4:
            // their own palm, fingers together ≈ 1% of the body
            drawHand(&s, at: CGPoint(x: 70, y: 44), dir: CGPoint(x: 0, y: -1), len: 40, shape: .open, look: v.look)
            s.label("bigger than their palm", "大于伤者手掌", 70, 82, size: 10, color: red, anchor: .middle, bold: true)
            s.label("→ see a doctor", "→ 就医", 70, 96, size: 10, color: red, anchor: .middle, bold: true)
            s.tag("face · hands · feet · groin · joints · deep", "面部 · 手足 · 会阴 · 关节 · 深度烧伤", 250, 40, size: 9, width: 200)
        default: break
        }
        if st <= 2 { skinInset(&s, 8, 8, depth: depth, cooling: underTap, minutes: p[v: "minutes"] * p[v: "cooling"], t: t) }
    }

    /// skin cut open: how deep the heat has reached, and the cooling timer
    private static func skinInset(_ s: inout Sketch, _ x: Double, _ y: Double, depth: Double, cooling: Bool, minutes: Double, t: Double) {
        s.inset(x, y, 150, 112, "Inside the skin", "皮肤内部")
        let top = y + 30, epi = top + 6, derm = top + 34, fat = top + 56
        s.rect(x + 8, top, 134, epi - top, fill: hex("#F5D7BF"))
        s.rect(x + 8, epi, 134, derm - epi, fill: hex("#EFC1A8"))
        s.rect(x + 8, derm, 134, fat - derm, fill: hex("#F7E3A1"))
        for k in 0..<3 {
            let x0 = x + 50 + Double(k) * 22
            s.path("M \(x0) \(derm - 4) C \(x0) \(epi + 6) \(x0 + 8) \(epi + 6) \(x0 + 8) \(derm - 4)", stroke: hex("#C8323C"), lw: 1)
        }
        let reach = depth / 110 * (fat - top)
        if depth > 1 { s.path("M \(x + 36) \(top) C \(x + 44) \(top + reach * 1.2) \(x + 106) \(top + reach * 1.2) \(x + 114) \(top) Z", fill: hex("#E0503C"), opacity: 0.55) }
        if cooling {
            for i in 0..<5 {
                let yy = (t * 40 + Double(i) * 7).wrap(20)
                s.line(x + 44 + Double(i) * 16, top - 22 + yy, x + 44 + Double(i) * 16, top - 16 + yy, stroke: hex("#3F95D6"), lw: 2, cap: .round)
            }
        }
        s.label("skin", "皮肤", x + 144, epi + 12, size: 8, anchor: .end)
        s.label("fat", "脂肪", x + 144, derm + 14, size: 8, anchor: .end)
        let cooled = depth < 8, status = cooled ? hex("#2E9E5B") : hex("#E0503C")
        s.label(cooled ? "Heat drawn out" : "Heat still sinking in", cooled ? "热量已散出" : "热量仍在向深处扩散", x + 8, fat + 14, size: 9, color: status, bold: true)
        s.label("cooling \(Int(minutes.rounded())) / 20 min", "冲水 \(Int(minutes.rounded())) / 20 分钟", x + 8, fat + 26, size: 9)
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
