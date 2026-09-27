import SwiftUI

extension Illustrations {
    /// healing phase fractions from weeks since the break
    static func healing(_ weeks: Double) -> (hematoma: Double, soft: Double, hard: Double, remodel: Double) {
        func c(_ x: Double) -> Double { x.clamped(0, 1) }
        return (c(1 - weeks / 2), c(weeks / 2) * c((6 - weeks) / 3), c((weeks - 2) / 4) * c((14 - weeks) / 6 + 0.3), c((weeks - 6) / 6))
    }

    static let fracture = fracture(for: .standard)

    /// Children: growth plates, greenstick bends, fast healing. Seniors: thin fragile bone, slower healing.
    static func fracture(for profile: Profile) -> Scenario {
        let age = profile.isKid ? 0.0 : profile.age == .senior ? 2 : 1
        let speed = [0.6, 1, 1.4][Int(age)]
        let maxWeeks = (12 * speed).rounded()
        let first: Step = switch Int(age) {
        case 0: .watch("A fall on the hand. A child’s bone is springy: it bends and cracks on one side only — a greenstick fracture, just above the growth plate.",
                       "摔倒手撑地。儿童骨头有弹性：只弯曲、一侧裂开——青枝骨折，就在生长板上方。", set: ["offset": 1, "weeks": 0, "cast": 0, "scene": 0])
        case 2: .watch("A fall from standing breaks the wrist: thin, porous bone (osteoporosis) snaps and crumbles just above the joint.",
                       "站立摔倒即可腕部骨折：骨质疏松的骨头又薄又脆，在关节上方断裂、压碎。", set: ["offset": 1, "weeks": 0, "cast": 0, "scene": 0])
        default: .watch("A fall on the outstretched hand breaks the radius just above the wrist; the end piece tips up and back — the “dinner-fork” wrist.",
                        "跌倒时手撑地，腕上方桡骨断裂，远端骨块向手背侧翘起移位——“餐叉样”畸形。", set: ["offset": 1, "weeks": 0, "cast": 0, "scene": 0])
        }
        var s = Scenario(
            id: "fracture-healing", group: .bones, title: Bilingual("Fracture: setting & healing", "骨折：复位与愈合"),
            warning: Bilingual("Setting a bone is a clinician’s job — this shows how it works.", "骨折复位须由医生操作——此处仅演示原理。"),
            params: ["offset": 1, "weeks": 0, "cast": 0, "scene": 0, "age": age],
            steps: [
                first,
                .watch("First aid: don’t straighten it. Rest the forearm across the body on something soft, support it, cold pack, rings off, go to hospital.",
                       "急救：不要掰直。前臂横放胸前，垫上软物托住，冷敷，摘下戒指，尽快就医。", set: ["scene": 1]),
                .tryIt(age == 0 ? "Setting (reduction), after pain relief: drag the bent end back straight." : "Setting (reduction), after numbing: pull, then drag the end piece back into line.",
                       age == 0 ? "试一试（复位，先止痛）：把弯曲的一端拖回伸直。" : "试一试（复位，先麻醉）：先牵引，再把远端骨块拖回对齐。", set: ["scene": 2],
                       TryStep(mode: .drag, success: { $0[v: "offset"] < 0.08 },
                               ok: Bilingual("Lined up — an X-ray confirms it. Now it must be held still.", "对齐了——X 光确认。接下来需要固定。"), demo: ["offset": 0])),
                .watch("A cast from below the elbow to the knuckles holds the ends still; a sling keeps the hand up to limit swelling. Wiggle the fingers.",
                       "石膏从肘下到掌指关节固定断端；吊带抬高手部，减轻肿胀。多活动手指。", set: ["offset": 0, "cast": 1, "scene": 3]),
                .tryIt("Drag through the weeks: clot → soft callus → hard callus → remodelled bone.", "试一试：拖动周数：血肿 → 软骨痂 → 硬骨痂 → 塑形。",
                       set: ["scene": 4],
                       TryStep(mode: .scrub([Scrub(param: "weeks", label: "Weeks 周", min: 0, max: maxWeeks, digits: 1)]), success: { healing($0[v: "weeks"] / speed).remodel > 0.5 },
                               ok: [Bilingual("Child: ~3–6 weeks in a cast; growing bone even straightens itself.", "儿童：石膏约 3–6 周；生长中的骨头还能自行矫直。"),
                                    Bilingual("Adult wrist: ~6 weeks in a cast, remodelling for months.", "成人腕部：石膏约 6 周，塑形持续数月。"),
                                    Bilingual("Senior: 8+ weeks; ask for a bone-density (DEXA) scan to prevent a hip fracture.", "老人：8 周以上；应做骨密度检查，预防髋部骨折。")][Int(age)],
                               demo: ["weeks": maxWeeks])),
            ],
            draw: { s, p, t in drawFracture(&s, p, t, speed: speed) },
            onDrag: { point, _ in ["offset": ((172 - point.y) / 16).clamped(0, 1)] },
            sources: ["Standard fracture-healing phases: haematoma, soft callus, hard callus, remodelling",
                      "Distal radius fracture: Colles pattern; paediatric greenstick / physeal injuries; osteoporotic fragility fractures"]
        )
        s.profileNote = switch Int(age) {
        case 0: Bilingual("Children: growth plates near the ends of bones; bones bend (greenstick) and heal about twice as fast. Injuries at a growth plate need follow-up.",
                          "儿童：骨端有生长板；骨头会弯折（青枝骨折），愈合约快一倍。伤及生长板需复查随访。")
        case 2: Bilingual("65+: a wrist or hip break from a simple fall is a fragility fracture — a sign of osteoporosis. Healing is slower; ask for a bone-density test.",
                          "65 岁以上：轻微摔倒导致的腕部或髋部骨折属脆性骨折——提示骨质疏松。愈合较慢，应检查骨密度。")
        default: nil
        }
        return s
    }

    /// Where the wrist piece sits for a given displacement: returns the rigid transform of the hand side.
    private static func wristMotion(_ o: Double, kid: Bool) -> (shift: CGPoint, tilt: Double, pivot: CGPoint) {
        // adults: tipped up (dorsal) and shortened; halfway back it is pulled out to length (traction) before dropping in
        let pull = sin(Double.pi * o) * (kid ? 0 : 5)
        return kid ? (.zero, -13 * o, pt(176, 153))
            : (CGPoint(x: -5 * o + pull, y: -12 * o), -17 * o, pt(183, 172))
    }

    private static func apply(_ p: CGPoint, _ m: (shift: CGPoint, tilt: Double, pivot: CGPoint)) -> CGPoint {
        let a = m.tilt * .pi / 180, dx = p.x - m.pivot.x, dy = p.y - m.pivot.y
        return CGPoint(x: m.pivot.x + dx * cos(a) - dy * sin(a) + m.shift.x, y: m.pivot.y + dx * sin(a) + dy * cos(a) + m.shift.y)
    }

    // Right forearm from the thumb side (lateral view): elbow off to the left, back of the hand up, fingers right.
    @MainActor private static func drawFracture(_ s: inout Sketch, _ p: Params, _ t: Double, speed: Double) {
        let age = Int(p[v: "age"].rounded()), kid = age == 0, old = age == 2
        let o = p[v: "offset"], weeks = p[v: "weeks"], cast = p[v: "cast"], scene = Int(p[v: "scene"].rounded())
        let h = healing(weeks / speed)
        let m = wristMotion(o, kid: kid)
        let aligned = o < 0.08
        // the cast comes off once hard callus holds (~6 weeks adult), before remodelling ends
        let castOn = cast * (1 - ((weeks / speed - 6) / 1.5).clamped(0, 1))

        // skin: one outline whose hand side follows the wrist piece, so the “dinner fork” bump forms by itself
        let dorsal: [CGPoint] = [pt(-30, 134), pt(60, 137), pt(130, 141), pt(172, 145), pt(200, 148), pt(226, 150), pt(254, 150),
                                 pt(282, 152), pt(306, 157), pt(330, 164), pt(348, 172)]
        let volar: [CGPoint] = [pt(356, 180), pt(346, 188), pt(322, 188), pt(298, 192), pt(272, 202), pt(248, 206), pt(226, 204),
                                pt(204, 199), pt(180, 199), pt(130, 202), pt(60, 208), pt(-30, 211)]
        func moved(_ q: CGPoint) -> CGPoint { lerp(q, apply(q, m), Anat.ease((q.x - 168) / 34)) }
        let outline = (dorsal + volar).map(moved)
        let swell = aligned ? h.hematoma * 0.6 * (1 - cast) : 1
        s.gradFill(smoothPath(outline), [Anat.skin, Anat.skin, Anat.skinShade], from: pt(0, 130), to: pt(0, 218), stroke: Anat.skinEdge, lw: 1.6)
        s.softGlow(pt(190, 172), 46, 40, Anat.red, 0.22 * swell)

        drawForearmBones(&s, o: o, kid: kid, old: old, xray: false)
        drawCallus(&s, h, weeks: weeks, xray: false)

        // cast from below the elbow to the knuckles
        if castOn > 0.02 {
            let top = [pt(60, 130), pt(130, 134), pt(172, 138), pt(200, 141), pt(226, 143), pt(254, 143), pt(290, 146)]
            let bottom = [pt(290, 202), pt(272, 209), pt(248, 213), pt(226, 211), pt(204, 206), pt(180, 206), pt(130, 209), pt(60, 215)]
            var shell = Path()
            shell.move(to: top[0])
            for q in top.dropFirst() { shell.addLine(to: q) }
            for q in bottom { shell.addLine(to: q) }
            shell.closeSubpath()
            s.gradFill(shell, [.white, hex("#EEF1F4")], from: pt(0, 130), to: pt(0, 215), stroke: hex("#B9C0C8"), lw: 1.4, opacity: 0.8 * castOn)
            var weave = s
            weave.ctx.clip(to: shell)
            for x in stride(from: 50.0, through: 300, by: 12) {
                weave.line(x, 120, x - 14, 224, stroke: hex("#C9D0D8"), lw: 0.8, opacity: 0.8 * castOn)
            }
            s.rect(56, 128, 8, 89, r: 3, fill: hex("#DCD3C4"), opacity: castOn)
            s.leader("cast", "石膏", at: pt(100, 214), 92, 240, color: Anat.muted)
        }

        // labels
        if castOn < 0.5 {
            s.leader("ulna", "尺骨", at: pt(70, 151), 30, 116)
            s.leader("radius", "桡骨", at: pt(70, 170), 30, 240)
            s.leader("wrist bones", "腕骨", at: moved(pt(232, 170)), 214, 240, anchor: .middle)
            if old && scene < 3 { s.leader("thin, porous bone", "骨质疏松、变薄", at: pt(120, 171), 76, 240, color: Anat.text) }
        }
        if kid { s.leader("growth plate", "生长板", at: moved(pt(201, 168)), 186, 116, color: Anat.blue) }
        if !kid && o > 0.5 && cast < 0.5 {
            s.leader("“dinner-fork” bump", "“餐叉样”隆起", at: moved(pt(214, 149)), 140, 108, anchor: .middle, color: Anat.red)
        }
        if !aligned && cast < 0.5 {
            let msg = kid ? ("bent, cracked on one side", "弯折，一侧裂开") : old ? ("broken and crushed", "断裂并压碎") : ("broken, end tipped up", "断裂，远端上翘")
            s.leader(msg.0, msg.1, at: pt(182, kid ? 180 : 166), 170, kid ? 262 : 262, anchor: .middle, color: Anat.red, bold: true)
        }

        // status
        if cast > 0.5 {
            let wk = String(format: "%.0f", weeks.rounded())
            let phase = h.remodel > 0.5 ? ("healed", "已愈合") : h.hard > 0.3 ? ("hard callus", "硬骨痂") : h.soft > 0.3 ? ("soft callus", "软骨痂") : ("clot", "血肿")
            s.stateChip("Week \(wk) · \(phase.0)", "第 \(wk) 周 · \(phase.1)", 8, 8, color: h.remodel > 0.5 ? Anat.green : Anat.amber)
            drawTimeline(&s, weeks: weeks, speed: speed)
        } else {
            s.stateChip(aligned ? "Aligned" : kid ? "Bent" : "Displaced", aligned ? "对位良好" : kid ? "弯折" : "移位", 8, 8,
                        color: aligned ? Anat.green : Anat.red)
        }

        drawFractureCard(&s, scene: scene, age: age, o: o, weeks: weeks, speed: speed, t: t)
    }

    /// Radius (front), ulna (behind), wrist and hand bones; the wrist side moves with the break.
    @MainActor private static func drawForearmBones(_ s: inout Sketch, o: Double, kid: Bool, old: Bool, xray: Bool) {
        let m = wristMotion(o, kid: kid)
        // opaque greys on the dark film, so outlined finger bones don't burn through to solid white
        let fill = xray ? hex("#C7CCD2") : Anat.bone, shade = xray ? hex("#8C949C") : Anat.boneShade
        let edge = xray ? hex("#EEF1F4") : Anat.boneEdge
        func bone(_ d: String, _ a: CGPoint, _ b: CGPoint) { s.boneFill(d, light: a, dark: b, fill: fill, shade: shade, edge: edge, lw: xray ? 0.8 : 1.1) }
        let physis = xray ? Color.black.opacity(0.6) : Anat.blue.opacity(0.75)

        // ulna, behind and a little toward the back of the hand; stays put
        bone("M -20 147 L 150 148 C 176 148, 190 150, 198 152 C 208 150, 214 156, 212 164 C 216 168, 214 172, 208 170 "
             + "C 202 170, 196 166, 190 164 L 150 163 L -20 164 Z", pt(0, 146), pt(0, 166))
        if kid { s.line(196, 151, 196, 166, stroke: physis, lw: 1.6) }

        // radius shaft up to the break
        let jag: [(Double, Double)] = old ? [(182, 153), (186, 157), (180, 161), (187, 165), (181, 169), (186, 174), (182, 180)]
            : kid ? [(182, 153), (182, 180)] : [(182, 153), (185, 159), (181, 165), (186, 171), (183, 180)]
        let jagDown = jag.map { "L \($0.0) \($0.1) " }.joined()
        bone("M -20 157 L 140 157 C 160 157, 172 155, 182 153 " + jagDown + "C 170 180, 158 177, 140 177 L -20 177 Z", pt(0, 155), pt(0, 179))
        if old {
            for (x, y) in [(120.0, 166.0), (140, 162), (156, 170), (168, 164), (132, 172)] { s.circle(x, y, 1.3, fill: edge.opacity(0.5)) }
        }

        // the wrist piece and everything beyond it move as one
        let jagUp = jag.reversed().map { "L \($0.0) \($0.1) " }.joined()
        s.group(translate: m.shift, rotate: m.tilt, about: m.pivot) { g in
            func gbone(_ d: String, _ a: CGPoint, _ b: CGPoint) { g.boneFill(d, light: a, dark: b, fill: fill, shade: shade, edge: edge, lw: xray ? 0.8 : 1.1) }
            // distal radius: flares to the wrist, dorsal (Lister’s) bump, concave joint surface tilted toward the palm
            gbone("M 182 153 C 190 150, 196 147, 202 147 C 206 146, 209 147, 210 149 Q 200 170 206 191 C 198 191, 190 184, 183 180 " + jagUp + "Z",
                  pt(190, 148), pt(190, 190))
            if old { for (x, y) in [(192.0, 162.0), (198, 176), (190, 172)] { g.circle(x, y, 1.3, fill: edge.opacity(0.5)) } }
            if kid { g.path("M 200 148 Q 196 168 200 189", stroke: physis, lw: 1.8) }
            // carpals: lunate in the radius cup, capitate beyond, trapezium toward the thumb
            gbone("M 208 150 C 220 148, 228 158, 227 170 C 226 182, 218 190, 209 190 Q 201 170 208 150 Z", pt(212, 152), pt(224, 188))
            gbone("M 228 156 C 238 152, 250 156, 252 164 C 254 172, 250 180, 240 181 C 232 182, 226 176, 226 168 C 226 162, 226 158, 228 156 Z",
                  pt(232, 156), pt(250, 180))
            gbone("M 224 184 C 230 180, 240 182, 242 190 C 242 196, 236 199, 229 197 C 224 195, 222 189, 224 184 Z", pt(226, 182), pt(240, 198))
            // metacarpals and slightly curled fingers
            for (k, dy) in [(0, -3.0), (1, 3), (2, 9)] {
                let y0 = 171 + dy, y1 = 176 + dy
                let w = xray ? 5.5 : 6.5
                g.limb([pt(254, y0), pt(302, y1)], w: w, fill: fill, line: edge)
                g.circle(304, y1, w * 0.62, fill: fill, stroke: edge, lw: 0.8)
                if k == 0 {
                    g.limb([pt(309, y1 + 1), pt(328, y1 + 4)], w: w * 0.8, fill: fill, line: edge)
                    g.limb([pt(332, y1 + 4), pt(344, y1 + 9)], w: w * 0.7, fill: fill, line: edge)
                    g.limb([pt(348, y1 + 11), pt(354, y1 + 15)], w: w * 0.6, fill: fill, line: edge)
                }
            }
            // thumb, toward the palm
            g.limb([pt(240, 188), pt(262, 195)], w: 7, fill: fill, line: edge)
            g.limb([pt(267, 196), pt(282, 198)], w: 5.8, fill: fill, line: edge)
            g.limb([pt(286, 198), pt(295, 198)], w: 5, fill: fill, line: edge)
        }
        // fracture line: red while displaced
        if !xray {
            let c = o > 0.08 ? Anat.red : Anat.boneEdge
            if kid {
                // only the palm-side cortex cracks; the back of the bone just bends
                s.path("M 182 180 L 184 175 L 181 170", stroke: c, lw: 1.4)
            } else {
                s.path("M " + jag.map { "\($0.0) \($0.1)" }.joined(separator: " L "), stroke: c, lw: 1.3, opacity: 0.8)
            }
            if old && o > 0.08 {
                // a small crushed wedge on the back of the bone
                s.path("M 184 152 L 192 146 L 194 155 Z", fill: Anat.bone, stroke: Anat.red, lw: 1)
            }
        }
    }

    /// Clot, soft callus, hard callus and remodelling at the break (aligned position).
    @MainActor private static func drawCallus(_ s: inout Sketch, _ h: (hematoma: Double, soft: Double, hard: Double, remodel: Double), weeks: Double, xray: Bool) {
        guard weeks > 0.05 else { return }
        let c = pt(184, 166), bulge = 7 * (h.soft + h.hard) * (1 - h.remodel * 0.85)
        if !xray && h.hematoma > 0.02 { s.softGlow(c, 18, 22, hex("#A3202F"), 0.7 * h.hematoma) }
        if !xray && h.soft > 0.02 {
            s.ellipse(c.x, c.y, 7 + bulge, 13 + bulge / 2, fill: hex("#B9D3EA"), stroke: hex("#7FA6CC"), lw: 0.8, opacity: 0.85 * h.soft)
        }
        if h.hard > 0.02 {
            let fill = xray ? Color.white.opacity(0.7) : hex("#EADFC4")
            s.ellipse(c.x, c.y, 6 + bulge, 12.5 + bulge / 2, fill: fill, stroke: xray ? .white : Anat.boneEdge, lw: 0.8, opacity: h.hard)
            if !xray { for (dx, dy) in [(-3.0, -6.0), (3, -1), (-2, 5), (4, 8), (0, 1)] { s.circle(c.x + dx, c.y + dy, 1, fill: Anat.boneEdge, opacity: 0.5 * h.hard) } }
        }
    }

    @MainActor private static func drawTimeline(_ s: inout Sketch, weeks: Double, speed: Double) {
        let x0 = 24.0, w = 300.0, y = 262.0, maxW = (12 * speed).rounded()
        let phases: [(Double, Double, Color, String, String)] = [(0, 2, hex("#C0485A"), "clot", "血肿"), (2, 4, hex("#9DBEDF"), "soft callus", "软骨痂"),
                                                                  (4, 8, hex("#D2C29A"), "hard callus", "硬骨痂"), (8, 12, hex("#EFE7D3"), "remodel", "塑形")]
        for (i, (a, b, col, en, zh)) in phases.enumerated() {
            let xa = x0 + a * speed / maxW * w, xb = x0 + min(maxW, b * speed) / maxW * w
            s.rect(xa + (i == 0 ? 0 : 1), y, xb - xa - (i == 0 ? 0 : 1), 10, r: 3, fill: col)
            s.label(en, zh, (xa + xb) / 2, y + 26, size: 8.5, color: Anat.text, anchor: .middle)
        }
        s.rect(x0, y, w, 10, r: 3, stroke: Anat.boneEdge, lw: 0.6)
        let mx = x0 + (weeks / maxW).clamped(0, 1) * w
        s.path("M \(mx) \(y - 1) l -5 -7 l 10 0 Z", fill: Anat.ink)
        s.line(mx, y - 1, mx, y + 11, stroke: Anat.ink, lw: 1.2)
        s.label("0", "0", x0 - 4, y + 9, size: 8, color: Anat.muted, anchor: .end)
        s.label("\(Int(maxW)) wk", "\(Int(maxW)) 周", x0 + w + 4, y + 9, size: 8, color: Anat.muted)
    }

    @MainActor private static func drawFractureCard(_ s: inout Sketch, scene: Int, age: Int, o: Double, weeks: Double, speed: Double, t: Double) {
        let xrayCard = scene == 2 || scene >= 4
        let box = xrayCard ? CGRect(x: 188, y: 6, width: 166, height: 104) : CGRect(x: 250, y: 6, width: 104, height: 108)
        let titles: [(String, String)] = [("How it happens", "如何发生"), ("First aid", "现场处理"), ("X-ray check", "复查 X 光"),
                                          ("Cast + sling", "石膏 + 吊带"), ("Follow-up X-ray", "随访 X 光")]
        let ti = titles[min(scene, 4)]
        s.inset(box.minX, box.minY, box.width, box.height, ti.0, ti.1)
        var c = s.clipped(box.minX, box.minY, box.width, box.height)
        let look: Look = age == 0 ? .kid : age == 2 ? .senior : .man
        let build: Build = age == 0 ? .child : .adult
        var person = FacingPerson(h: age == 0 ? 120 : 140)
        person.head = age == 0 ? 1.25 : 1
        person.shirt = age == 0 ? Look.kid.top : age == 2 ? Look.senior.top : hex("#8FB3E0")
        person.shirtLine = darker(person.shirt)
        person.hair = age == 2 ? hex("#D4D4D4") : age == 0 ? hex("#6B4A2F") : hex("#6B5344")
        let o0 = CGPoint(x: box.midX + 4, y: box.minY + 44)
        switch scene {
        case 0:
            let ground = box.maxY - 10
            c.line(box.minX + 6, ground, box.maxX - 6, ground, stroke: hex("#C9C2B6"), lw: 2)
            let (_, hand) = c.fallOnHand(x: box.midX - 8, ground: ground, h: age == 0 ? 74 : 70, look: look, build: build)
            c.softGlow(CGPoint(x: hand.x - 4, y: hand.y - 6), 10, 10, Anat.red, 0.45 + 0.2 * sin(t * 4))
        case 1, 3:
            person.face = scene == 1 ? .pain : .calm
            person.drawBody(&c, at: o0)
            let hh = person.h
            let e = CGPoint(x: -0.125 * hh, y: 0.19 * hh), w = CGPoint(x: 0.05 * hh, y: scene == 1 ? 0.2 * hh : 0.15 * hh)
            if scene == 1 {
                // forearm resting on a folded towel, held from below by the other hand; cold pack on the wrist
                c.rect(o0.x - 0.12 * hh, o0.y + 0.215 * hh, 0.2 * hh, 0.04 * hh, r: 3, fill: hex("#E9D8A6"), stroke: hex("#BFA970"))
                person.drawArm(&c, at: o0, side: -1, elbow: e, hand: w)
                person.drawArm(&c, at: o0, side: 1, elbow: CGPoint(x: 0.12 * hh, y: 0.22 * hh), hand: CGPoint(x: -0.06 * hh, y: 0.245 * hh))
                c.rect(o0.x + 0.0 * hh - 7, o0.y + 0.17 * hh, 14, 10, r: 3, fill: hex("#CFE8F7"), stroke: Anat.blue)
            } else {
                person.drawArm(&c, at: o0, side: 1, elbow: CGPoint(x: 0.13 * hh, y: 0.19 * hh), hand: CGPoint(x: 0.14 * hh, y: 0.33 * hh))
                person.drawArm(&c, at: o0, side: -1, elbow: e, hand: w)
                // cast on the forearm, then the sling over it
                let q0 = CGPoint(x: o0.x + e.x + (w.x - e.x) * 0.12, y: o0.y + e.y + (w.y - e.y) * 0.12)
                let q1 = CGPoint(x: o0.x + w.x - 2, y: o0.y + w.y)
                c.limb([q0, q1], w: 0.045 * hh, fill: .white, line: hex("#B9C0C8"))
                person.drawSling(&c, at: o0, elbow: e, hand: CGPoint(x: w.x - 0.03 * hh, y: w.y))
            }
        default:
            // X-ray: the same bones in negative
            c.rect(box.minX + 4, box.minY + 20, box.width - 8, box.height - 24, r: 6, fill: hex("#1C232B"))
            var x = c.clipped(box.minX + 4, box.minY + 20, box.width - 8, box.height - 24)
            let k = 0.86
            x.group(translate: CGPoint(x: box.midX - 232 * k, y: box.minY + 54 - 172 * k), scale: k) { g in
                drawForearmBones(&g, o: o, kid: age == 0, old: age == 2, xray: true)
                drawCallus(&g, healing(weeks / speed), weeks: weeks, xray: true)
                if o > 0.08 { g.path("M 182 153 L 185 160 L 181 167 L 185 174 L 182 180", stroke: Anat.red, lw: 2) }
            }
            let ok = o < 0.08
            c.cardNote(ok ? (scene == 4 ? "callus bridges the gap" : "lined up") : "not lined up",
                       ok ? (scene == 4 ? "骨痂连接断端" : "已对齐") : "未对齐",
                       box.midX, box.maxY - 12, width: 150, size: 8.5, color: ok ? hex("#8FE3B0") : hex("#FF9C9C"), bold: true)
        }
    }
}

private func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }
