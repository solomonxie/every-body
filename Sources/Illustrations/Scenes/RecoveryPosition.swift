import SwiftUI

extension Illustrations {
    static func recoveryPosition(for who: Profile) -> Scenario {
        if who.age == .infant { return babyRecovery }
        let v = artPerson(who)
        // the drag follows the far knee from the start to the end of the roll, measured in the pictures
        let dragFrom = SceneMarks.marks["recovery-\(v)-4"]?["far_knee"]?.y ?? 130
        let dragTo = max(dragFrom + 20, SceneMarks.marks["recovery-\(v)-5d"]?["far_knee"]?.y ?? 200)
        var s = Scenario(
            id: "recovery-position", group: .firstAid, title: Bilingual("Recovery position", "复原卧位"),
            params: ["stage": 0, "arm": 0, "hand": 0, "knee": 0, "roll": 0, "tilt": 0],
            steps: [
                .watch("Unresponsive but breathing normally? Lying on the back, the tongue or vomit can block the airway. Tap the shoulders and shout.",
                       "无反应但呼吸正常？仰卧时舌根后坠或呕吐物可能堵住气道。先拍双肩、大声呼唤。",
                       set: ["stage": 0, "arm": 0, "hand": 0, "knee": 0, "roll": 0, "tilt": 0]),
                .watch("Tilt the head back and lift the chin. Look, listen and feel for normal breathing — up to 10 s.",
                       "仰头抬颏，看、听、感觉有无正常呼吸，不超过 10 秒。", set: ["stage": 1, "tilt": 1]),
                .watch("Kneel beside them, glasses off. Put the arm nearest you out at a right angle, elbow bent, palm up.",
                       "跪在其身旁，取下眼镜。把靠近你的手臂向外摆成直角，屈肘，掌心向上。", set: ["stage": 2, "arm": 1, "tilt": 0]),
                .watch("Bring the far arm across the chest. Hold the back of their hand against the cheek nearest you.",
                       "把远侧手臂拉过胸前，将其手背贴在靠近你一侧的脸颊上并按住。", set: ["stage": 3, "hand": 1]),
                .watch("With your other hand, pull the far knee up so the foot is flat on the floor.",
                       "另一只手把远侧膝盖拉起，使脚掌平踩地面。", set: ["stage": 4, "knee": 1]),
                .tryIt("Keep their hand on the cheek. Drag the far knee toward you to roll them onto their side.",
                       "试一试：按住脸颊上的手，把远侧膝盖向你拖过来，让其翻成侧卧。", set: ["stage": 5],
                       TryStep(mode: .drag, success: { $0[v: "roll"] >= 0.95 },
                               ok: Bilingual("On their side — the bent top knee stops them rolling onto their face.", "侧卧了——弯曲的上方膝盖防止其翻成俯卧。"),
                               demo: ["roll": 0.55])),
                .watch("Top leg bent at hip and knee. Tilt the head back to keep the airway open — mouth pointing down so fluid drains out.",
                       "上方腿屈髋屈膝。头稍后仰保持气道通畅——嘴朝下，便于液体流出。", set: ["stage": 6, "roll": 1, "tilt": 1]),
                .watch("Call 911. Stay and keep checking breathing. Stops or not normal? Roll onto the back and start CPR.",
                       "拨打 120。守在旁边，持续观察呼吸。呼吸停止或不正常？翻回仰卧，开始心肺复苏。", set: ["stage": 7]),
            ],
            draw: { s, p, t in drawRecovery(&s, p, t, who) },
            onDrag: { point, _ in ["roll": ((point.y - dragFrom) / (dragTo - dragFrom)).clamped(0, 1)] },
            sources: ["ILCOR 2025 CoSTR first aid; ERC 2025 & Red Cross: recovery position for unresponsive, normally breathing people",
                      "Pregnancy: left lateral position to keep the womb off the vena cava"]
        )
        s.profileNote = switch who.age {
        case .infant: nil
        case .toddler, .child: Bilingual("Child: same steps as adults. Stay with them and watch the breathing the whole time.",
                                         "儿童：步骤同成人。守在旁边，全程观察呼吸。")
        case .senior: Bilingual("65+: move stiff or painful joints gently — don’t force an arm or leg into place.",
                                "老人：关节僵硬或疼痛时动作要轻，不要强行摆放手臂或腿。")
        case .adult where who.isPregnant: Bilingual("Pregnant: roll her onto her LEFT side, so the womb doesn’t press on the big vein to the heart.",
                                                    "孕妇：让她向左侧卧，避免子宫压迫回心的大静脉。")
        case .adult: Bilingual("Adult: only for someone breathing normally. Not breathing normally → CPR instead.",
                               "成人：只用于呼吸正常者。呼吸不正常→改做心肺复苏。")
        }
        return s
    }

    /// pictures: toddlers use the child's

    /// picture weights for a whole stage; the roll (stage 5) runs through four frames after the knee-up picture
    private static func recoveryFrames(_ st: Int, roll: Double) -> [(String, Double)] {
        guard st == 5 else { return [("\(st)", 1)] }
        let names = ["4", "5a", "5b", "5c", "5d"], u = roll.clamped(0, 1) * 4
        let i = min(3, Int(u)), f = u - Double(i)
        return [(names[i], 1 - f), (names[i + 1], f)]
    }

    @MainActor private static func drawRecovery(_ s: inout Sketch, _ p: Params, _ t: Double, _ who: Profile) {
        let v = artPerson(who), roll = p[v: "roll"]
        let stage = p[v: "stage"].clamped(0, 7), lo = min(6, Int(stage.rounded(.down))), f = stage - Double(lo), k = f * f * (3 - 2 * f)
        var layers: [String: Double] = [:]
        for (key, w) in recoveryFrames(lo, roll: roll) { layers[key, default: 0] += w * (1 - k) }
        for (key, w) in recoveryFrames(lo + 1, roll: roll) { layers[key, default: 0] += w * k }
        s.backdrop()
        s.art(layers.map { ("recovery-\(v)-\($0.key)", $0.value) }.sorted { $0.1 > $1.1 })
        let st = Int(stage.rounded())
        let shown = recoveryFrames(st, roll: roll).max { $0.1 < $1.1 }?.0 ?? "\(st)"
        let m = SceneMarks.at("recovery-\(v)-\(shown)")
        let at = { (key: String) in m[key] ?? CGPoint(x: 180, y: 150) }
        let calm = max(0, 1 - abs(stage - stage.rounded()) * 4)
        let her = who.isPregnant
        let red = hex("#D8434B"), green = hex("#2E9E5B")
        s.group(opacity: calm) { g in
            let head = at("head"), knee = at("far_knee"), you = at("rescuer_head")
            switch st {
            case 0:
                // a child lies across the lower frame: speak from above instead
                let kid = who.age.isChild
                g.bubble("Are you OK?", "你还好吗？", (you.x + (her ? -86 : kid ? 40 : 86)).clamped(60, 300), kid ? 60 : min(276, you.y + 66),
                         tip: kid ? CGPoint(x: you.x + 6, y: you.y + 2) : CGPoint(x: you.x + (her ? -16 : 16), y: you.y + 12))
                g.tag("no response", "无反应", head.x + (her ? 12 : -12), head.y - 40, size: 10, color: red, bold: true)
            case 1: g.tag("look · listen · feel ≤ 10 s", "看 · 听 · 感觉 ≤ 10 秒", head.x + (her ? -40 : 40), head.y - 44, size: 10, bold: true)
            case 2:
                let e = at("near_elbow")
                g.tag("right angle, palm up", "直角，掌心向上", (e.x + (her ? 76 : -76)).clamped(70, 290), min(282, e.y + 26), size: 10, color: red, bold: true)
            case 3: g.tag("back of hand on the cheek", "手背贴脸颊", head.x + (her ? -24 : 24), head.y - 44, size: 10, color: red, bold: true)
            case 4: g.tag("far knee up, foot flat", "远侧膝盖立起，脚掌着地", knee.x, knee.y - 44, size: 10, color: red, bold: true)
            case 5:
                if roll < 0.95 {
                    let pulse = 1 + 0.25 * sin(t * 5)
                    g.circle(knee.x, knee.y, 14 * pulse, stroke: red, lw: 2, opacity: 0.8)
                    g.arrow(CGPoint(x: knee.x + 24, y: knee.y - 6), CGPoint(x: knee.x + 24, y: knee.y + 30), color: red, lw: 2)
                }
                g.tag("pull the knee toward you", "把膝盖拉向你", 180, 58, size: 10, color: red, bold: true)
                if her { g.tag("onto her LEFT side", "向左侧卧", 180, 80, size: 10, color: hex("#B06C84"), bold: true) }
            case 6:
                g.tag("head tilted back — airway open", "头后仰——气道通畅", head.x + (her ? -44 : 44), head.y - 46, size: 10, color: green, bold: true)
                // clear floor above the legs; below the knee is the rescuer
                g.tag("hip and knee bent", "屈髋屈膝", her ? 110 : 250, 130, size: 10, bold: true)
            case 7:
                g.phone(her ? 40 : 320, 250, number: g.t("911", "120"), t: t)
                g.tag("keep checking breathing", "持续观察呼吸", 180, 30, size: 10, color: green, bold: true)
                g.tag("not breathing normally → CPR", "呼吸不正常 → 心肺复苏", 180, 52, size: 10, color: red, bold: true)
            default: break
            }
            if st >= 6 {
                // anything in the mouth drains out
                let mo = at("mouth")
                for i in 0..<2 {
                    let u = (t * 0.9 + Double(i) * 0.5).wrap(1)
                    g.circle(mo.x, mo.y + 4 + u * 14, 2.2 * (1 - u * 0.5), fill: hex("#7FB3D9"), opacity: 1 - u)
                }
            }
        }
        if st >= 1 && st <= 6 {
            let x0 = her ? 206.0 : 8
            s.tonal(x0, 8, 146, 30, r: 12, color: green)
            s.label("Breathing normally ✓", "呼吸正常 ✓", x0 + 73, 27, size: 11, color: green, anchor: .middle, bold: true)
        }
    }
}

// MARK: - Baby

extension Illustrations {
    static let babyRecovery = Scenario(
        id: "recovery-position", group: .firstAid, title: Bilingual("Recovery position (baby)", "婴儿复原体位"),
        profileNote: Bilingual("Baby: don’t lay them on their side — hold them in your arms, face down, head lower than the body.",
                               "婴儿：不要侧放在床上——抱在手臂上，面朝下，头低于身体。"),
        params: ["stage": 0, "tilt": 0],
        steps: [
            .watch("Baby floppy and won’t wake, but breathing normally? Tap the sole of the foot and call them.",
                   "婴儿软绵绵叫不醒，但呼吸正常？轻拍足底并呼唤。", set: ["stage": 0, "tilt": 0]),
            .watch("Keep the head level. Look, listen and feel for normal breathing — up to 10 s.",
                   "头保持水平。看、听、感觉有无正常呼吸，不超过 10 秒。", set: ["stage": 1]),
            .tryIt("Pick the baby up face down along your forearm, your hand supporting the head and jaw. Tilt so the head is lower than the body.",
                   "试一试：把婴儿面朝下抱在你的前臂上，手托住头和下颌。倾斜手臂，使头低于身体。", set: ["stage": 2, "tilt": 0],
                   TryStep(mode: .scrub([Scrub(param: "tilt", label: "Head down 头放低", min: 0, max: 1)]), success: { $0[v: "tilt"] >= 0.6 },
                           ok: Bilingual("Head lower — the tongue falls forward and vomit drains out of the mouth.", "头低了——舌头前移，呕吐物可从口中流出。"),
                           demo: ["tilt": 1])),
            .watch("Call 911. Keep holding the baby like this and keep checking breathing. It stops? Start baby CPR.",
                   "拨打 120。保持这样抱着，持续观察呼吸。呼吸停止？开始婴儿心肺复苏。", set: ["stage": 3, "tilt": 1]),
        ],
        draw: { s, p, t in drawBabyRecovery(&s, p, t) },
        sources: ["Red Cross / St John Ambulance baby first aid: hold an unresponsive, breathing baby face down along the forearm, head low",
                  "ILCOR 2025 CoSTR first aid"]
    )

    @MainActor private static func drawBabyRecovery(_ s: inout Sketch, _ p: Params, _ t: Double) {
        let tilt = p[v: "tilt"], green = hex("#2E9E5B"), red = hex("#D8434B"), blue = hex("#3F95D6")
        // stage 2 onward: held on the forearm; the tilt fades from level to head-down
        let key = { (st: Int) -> [(String, Double)] in st <= 1 ? [("\(st)", 1)] : [("2a", 1 - tilt), ("2b", tilt)] }
        let stage = p[v: "stage"].clamped(0, 3), lo = min(2, Int(stage.rounded(.down))), f = stage - Double(lo), k = f * f * (3 - 2 * f)
        var layers: [String: Double] = [:]
        for (n, w) in key(lo) { layers[n, default: 0] += w * (1 - k) }
        for (n, w) in key(lo + 1) { layers[n, default: 0] += w * k }
        s.backdrop()
        s.art(layers.map { ("recovery-infant-\($0.key)", $0.value) }.sorted { $0.1 > $1.1 })
        let st = Int(stage.rounded())
        let m = SceneMarks.at("recovery-infant-\(st <= 1 ? "\(st)" : tilt > 0.5 ? "2b" : "2a")")
        let at = { (key: String) in m[key] ?? CGPoint(x: 180, y: 150) }
        let calm = max(0, 1 - abs(stage - stage.rounded()) * 4)
        s.group(opacity: calm) { g in
            switch st {
            case 0:
                let you = at("rescuer_head")
                g.bubble("Baby? Baby!", "宝宝？宝宝！", max(60, you.x - 70), max(24, you.y - 14), tip: CGPoint(x: you.x - 14, y: you.y + 8))
                g.callout("tap the sole — don’t shake", "轻拍足底——不要摇晃", 200, 286, to: at("sole"), color: red)
                g.callout("floppy, won’t wake", "软绵绵，叫不醒", 90, 130, to: at("head"), color: red)
            case 1:
                let mouth = at("mouth"), c = at("chest"), rise = max(0, sin(t * 2.2))
                g.arrow(CGPoint(x: c.x + 8, y: c.y - 4), CGPoint(x: c.x + 8, y: c.y - 14 - rise * 6), color: blue, lw: 2)
                g.path("M \(mouth.x + 6) \(mouth.y - 6) q 4 -4 0 -8 M \(mouth.x + 11) \(mouth.y - 4) q 6 -6 0 -12", stroke: blue, lw: 1.4, cap: .round)
                g.tag("look · listen · feel ≤ 10 s", "看 · 听 · 感觉 ≤ 10 秒", 270, 110, size: 10, bold: true)
                g.tag("head level", "头保持水平", 110, 286, size: 10, bold: true)
                g.tonal(210, 8, 142, 28, r: 12, color: green)
                g.label("Breathing normally ✓", "呼吸正常 ✓", 281, 22, size: 11, color: green, anchor: .middle, bold: true)
            default:
                let headLow = tilt >= 0.6
                let hc = at("baby_head"), hip = at("hip")
                g.line(hip.x - 10, hip.y, hc.x + 30, hip.y, stroke: hex("#999999"), lw: 1, dash: [3, 3])
                g.tag(headLow ? "head lower than the body ✓" : "tilt: head lower", headLow ? "头低于身体 ✓" : "倾斜：让头更低",
                      286, 60, size: 10, color: headLow ? green : red, bold: true)
                g.callout("hand supports the jaw", "手托住下颌", 286, 84, to: at("jaw"), color: hex("#444444"))
                if st == 3 {
                    g.phone(320, 250, number: g.t("911", "120"), t: t)
                    g.tag("keep checking breathing", "持续观察呼吸", 262, 205, size: 10, color: green, bold: true)
                }
            }
        }
    }
}
