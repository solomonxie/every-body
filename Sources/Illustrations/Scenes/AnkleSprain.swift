import SwiftUI

extension Illustrations {
    static let ankleSprain = ankleSprain(for: .standard)

    static func ankleSprain(for p: Profile) -> Scenario {
        let kid = p.isKid, who = p
        var s = Scenario(
            id: "ankle-sprain", group: .firstAid, title: Bilingual("Sprained ankle", "踝关节扭伤"),
            params: ["injured": 0, "grade": 0, "rice": 0, "scene": 0],
            steps: [
                .watch("Your right ankle from the outside. Ligaments are tough straps joining bone to bone; three hold the outer ankle bone (the tip of the fibula) to the foot.",
                       "从外侧看右脚踝。韧带是连接骨与骨的坚韧纤维带；外踝（腓骨下端）靠三条韧带与足骨相连。",
                       set: ["injured": 0, "grade": 0, "rice": 0, "scene": 0]),
                .watch("Stepping off a curb or landing on someone’s foot rolls the foot inward and down. The outer ligaments over-stretch — the front one (ATFL) goes first.",
                       "踩空台阶或落地踩到别人脚上，脚向内、向下翻。外侧韧带被过度拉伸——前面的距腓前韧带最先受伤。",
                       set: ["injured": 1, "scene": 1]),
                .tryIt("Compare the three grades of sprain.", "试一试：对比三种扭伤程度。", set: ["scene": 2],
                       TryStep(mode: .compare(param: "grade", options: [("I", 0), ("II", 1), ("III", 2)]), success: { $0[v: "grade"] > 1.5 },
                               ok: Bilingual("Can’t take 4 steps, or the bone itself is tender? Get an X-ray.", "无法行走 4 步，或骨头本身压痛？需拍 X 光。"))),
                .tryIt("First 48 h — Rest, Ice (20 min, wrapped in a cloth), Compression bandage, Elevate above the heart. Apply RICE.",
                       "试一试：48 小时内——休息、冰敷（包布，20 分钟）、弹力绷带加压、抬高过心脏。",
                       set: ["grade": 1, "scene": 3],
                       TryStep(mode: .scrub([Scrub(param: "rice", label: "RICE 处理", min: 0, max: 1)]), success: { $0[v: "rice"] > 0.9 },
                               ok: Bilingual("Swelling down. Then gentle movement as pain allows; most sprains heal in 2–6 weeks.", "肿胀减轻。之后在疼痛允许下逐步活动；多数扭伤 2–6 周恢复。"),
                               demo: ["rice": 1])),
            ],
            draw: { s, p, t in drawAnkle(&s, p, t, kid: kid, who: who) },
            sources: ["BJSM / Red Cross acute ankle sprain management (RICE / PEACE & LOVE)", "Ottawa ankle rules"]
        )
        s.profileNote = switch p.age {
        case .infant, .toddler, .child: Bilingual("Children: ligaments are stronger than the growth plate, so a “sprain” may be a growth-plate break — X-ray if the bone is tender or they won’t walk.",
                                        "儿童：韧带比生长板结实，“扭伤”可能是生长板骨折——骨头压痛或不肯走路要拍 X 光。")
        case .senior: Bilingual("65+: a twisted ankle is more often a broken bone — get an X-ray, and use a stick while it heals to avoid another fall.",
                                "65 岁以上：扭脚更容易骨折——应拍 X 光；恢复期拄拐杖，防止再次跌倒。")
        case .adult: nil
        }
        return s
    }

    /// how far the foot is rolled in (0…1) at time t while the injury plays
    private static func ankleRoll(_ scene: Int, _ t: Double) -> Double {
        scene == 1 ? pow(max(0, sin(t * 1.6)), 2) : 0
    }

    // Right ankle from the outside (lateral view): heel left, toes right.
    @MainActor private static func drawAnkle(_ s: inout Sketch, _ p: Params, _ t: Double, kid: Bool, who: Profile) {
        let g = p[v: "grade"], gi = Int(g.rounded()), scene = Int(p[v: "scene"].rounded())
        let injured = p[v: "injured"], rice = p[v: "rice"]
        let roll = ankleRoll(scene, t) * injured
        let pivot = pt(200, 200), angle = 11 * roll
        func foot(_ q: CGPoint) -> CGPoint {
            let a = angle * .pi / 180, dx = q.x - pivot.x, dy = q.y - pivot.y
            return CGPoint(x: pivot.x + dx * cos(a) - dy * sin(a), y: pivot.y + dx * sin(a) + dy * cos(a))
        }
        func blended(_ q: CGPoint) -> CGPoint { lerp(q, foot(q), Anat.ease((q.y - 172) / 26)) }

        // skin, the foot part turning with the bones
        let outline: [CGPoint] = [pt(238, -10), pt(236, 60), pt(234, 130), pt(236, 170), pt(244, 190), pt(264, 197), pt(292, 207),
                                  pt(320, 226), pt(344, 242), pt(356, 252), pt(357, 263), pt(348, 272), pt(310, 273), pt(250, 273),
                                  pt(190, 273), pt(140, 272), pt(118, 267), pt(106, 252), pt(106, 230), pt(116, 206), pt(124, 178),
                                  pt(128, 130), pt(132, 60), pt(134, -10)].map(blended)
        let skinPath = smoothPath(outline)
        s.gradFill(skinPath, [Anat.skin, Anat.skin, Anat.skinShade], from: pt(240, 0), to: pt(110, 0), stroke: Anat.skinEdge, lw: 1.6)
        let gradeSwell = [0.45, 0.75, 1.0][min(2, max(0, gi))]
        let swelling = injured * (scene == 1 ? roll * 0.5 : gradeSwell) * (1 - 0.65 * rice)
        s.softGlow(blended(pt(206, 212)), 44 + 14 * swelling, 30 + 10 * swelling, Anat.red, 0.3 * swelling)
        if injured > 0.5 && scene >= 2 && gi >= 1 {
            s.softGlow(pt(176, 250), 30 + Double(gi) * 8, 14, hex("#6C4F9E"), 0.22 * (1 - 0.5 * rice))
        }

        let tendonTop = pt(140, 40), tendonEnd = foot(pt(122, 236))
        s.path("M \(tendonTop.x - 6) \(tendonTop.y) C 134 120, 130 170, \(tendonEnd.x - 5) \(tendonEnd.y) L \(tendonEnd.x + 6) \(tendonEnd.y - 2) "
               + "C 142 170, 146 120, \(tendonTop.x + 8) \(tendonTop.y) Z", fill: Anat.tendon, stroke: Anat.tendonEdge, lw: 0.9)

        // tibia behind, then the foot bones, then the fibula on the outside
        s.boneFill("M 178 -10 L 228 -10 C 226 60, 224 130, 228 168 C 231 178, 229 186, 222 189 C 206 186, 190 186, 178 189 C 174 160, 176 60, 178 -10 Z",
                   light: pt(190, 0), dark: pt(228, 0), fill: hex("#EFE7D4"))
        if kid { s.path("M 180 172 C 196 170, 212 170, 228 172", stroke: Anat.blue.opacity(0.75), lw: 1.8) }
        s.group(rotate: angle, about: pivot) { f in
            // calcaneus with its heel tuberosity
            f.boneFill("M 124 232 C 116 246, 120 266, 142 268 L 232 262 C 244 258, 248 246, 242 236 C 232 230, 222 228, 212 227 L 178 227 C 160 224, 136 220, 124 232 Z",
                       light: pt(160, 228), dark: pt(160, 268))
            // talus: cartilage-capped dome under the tibia, neck and head toward the toes
            f.boneFill("M 172 197 C 180 184, 214 180, 227 190 C 234 194, 240 196, 249 198 C 259 198, 265 206, 261 214 C 257 221, 247 221, 239 217 "
                       + "C 231 219, 222 223, 212 225 L 178 225 C 169 219, 167 207, 172 197 Z", light: pt(200, 186), dark: pt(210, 225))
            f.path("M 174 195 C 184 185, 212 181, 226 190", stroke: Anat.cartilageEdge, lw: 3.4, cap: .round)
            f.path("M 174 195 C 184 185, 212 181, 226 190", stroke: Anat.cartilage, lw: 2, cap: .round)
            // midfoot
            f.boneFill("M 264 200 C 272 198, 278 204, 278 212 C 278 220, 272 224, 264 222 C 268 214, 268 206, 264 200 Z", light: pt(266, 200), dark: pt(276, 222))
            f.boneFill("M 246 236 C 256 232, 268 234, 274 240 L 274 254 C 264 258, 254 258, 246 254 C 248 248, 248 242, 246 236 Z", light: pt(250, 234), dark: pt(270, 256))
            f.boneFill("M 281 204 C 291 204, 299 210, 301 218 L 293 233 C 285 233, 279 227, 279 219 Z", light: pt(284, 204), dark: pt(296, 232))
            // metatarsals and toes
            f.limb([pt(296, 228), pt(336, 255)], w: 7, fill: Anat.boneShade, line: Anat.boneEdge)
            f.limb([pt(276, 250), pt(330, 263)], w: 7, fill: Anat.bone, line: Anat.boneEdge)
            f.circle(276, 252, 5.5, fill: Anat.bone, stroke: Anat.boneEdge, lw: 0.9)
            f.limb([pt(301, 216), pt(338, 247)], w: 9, fill: Anat.bone, line: Anat.boneEdge)
            f.limb([pt(334, 264), pt(348, 266)], w: 5, fill: Anat.bone, line: Anat.boneEdge)
            f.limb([pt(343, 251), pt(355, 257)], w: 7, fill: Anat.bone, line: Anat.boneEdge)
        }
        s.boneFill("M 164 -10 L 178 -10 C 178 60, 180 130, 186 170 C 194 180, 196 200, 190 213 C 186 221, 177 223, 173 215 "
                   + "C 167 205, 165 191, 167 177 C 166 130, 166 60, 164 -10 Z", light: pt(168, 0), dark: pt(190, 0))
        if kid { s.path("M 166 172 C 174 170, 180 170, 186 171", stroke: Anat.blue.opacity(0.75), lw: 1.8) }

        // the three outer ligaments; fibula ends stay, foot ends move with the roll
        let atfl0 = pt(190, 199), atfl1 = foot(pt(230, 206))
        let cfl0 = pt(180, 216), cfl1 = foot(pt(170, 244))
        let ptfl0 = pt(172, 206), ptfl1 = foot(pt(156, 214))
        func strain(_ a: CGPoint, _ b: CGPoint, rest: Double) -> Double { ((hypot(b.x - a.x, b.y - a.y) / rest - 1) * 5).clamped(0, 1) }
        let hurt = injured > 0.5 && scene >= 2
        let atflTear = hurt ? [0, 0.5, 1][min(2, gi)] : 0, cflTear = hurt && gi >= 2 ? 1.0 : 0
        let atflStretch = scene == 1 ? strain(atfl0, atfl1, rest: 40.6) : hurt && gi == 0 ? 0.8 : 0
        s.ligamentBand(ptfl0, ptfl1, width: 7)
        s.ligamentBand(cfl0, cfl1, width: 7, stretch: scene == 1 ? strain(cfl0, cfl1, rest: 29.7) : 0, tear: cflTear)
        s.ligamentBand(atfl0, atfl1, width: 8, stretch: atflStretch, tear: atflTear)
        if scene == 1 && roll > 0.3 { s.softGlow(lerp(atfl0, atfl1, 0.5), 12, 8, Anat.red, 0.5 * roll) }

        // RICE on the ankle: ice pack, then a figure-of-eight elastic wrap
        if rice > 0.55 {
            var wrap = s
            // figure-of-eight: turns round the lower leg, crossing over the ankle, round the midfoot; ends cut square
            wrap.ctx.clip(to: skinPath); wrap.ctx.clip(to: Path(CGRect(x: 118, y: 160, width: 186, height: 140)))
            let k = Anat.ease((rice - 0.55) / 0.2)
            // two turns round the leg, a cross over the ankle, two round the midfoot
            let turns: [(CGPoint, CGPoint)] = [(pt(110, 170), pt(260, 166)), (pt(110, 184), pt(260, 180)), (pt(150, 198), pt(262, 296)),
                                               (pt(206, 292), pt(264, 176)), (pt(258, 194), pt(284, 292)), (pt(280, 200), pt(306, 292))]
            // the layers underneath, heel left open
            wrap.shape(smoothPath([pt(108, 158), pt(262, 156), pt(302, 196), pt(314, 300), pt(196, 300), pt(150, 238), pt(108, 222)]),
                       fill: hex("#E9D8B4"), opacity: 0.94 * k)
            for (a, b) in turns {
                let d = "M \(a.x) \(a.y) L \(b.x) \(b.y)"
                wrap.path(d, stroke: hex("#B89E6E"), lw: 14, opacity: k)
                wrap.path(d, stroke: hex("#E9D8B4"), lw: 12, opacity: k)
                wrap.path(d, stroke: hex("#D6C198"), lw: 0.8, opacity: 0.8 * k, dash: [2, 3])
            }
        }
        if rice > 0.3 && rice < 0.8 {
            let k = Anat.ease((rice - 0.3) / 0.12) * (1 - Anat.ease((rice - 0.7) / 0.1))
            s.group(rotate: -14, about: pt(206, 208), opacity: k) { g in
                g.rect(178, 192, 56, 32, r: 9, fill: hex("#CFE8F7"), stroke: Anat.blue, lw: 1.5)
                g.shape(Path(roundedRect: CGRect(x: 182, y: 196, width: 48, height: 24), cornerRadius: 6), stroke: .white, lw: 1.5, dash: [3, 3])
            }
        }

        // labels
        let lig = Anat.ligament
        if rice < 0.3 {
            s.leader("front (ATFL)", "距腓前韧带", at: lerp(atfl0, atfl1, 0.6), 250, 178, color: lig, bold: true)
            s.leader("lower (CFL)", "跟腓韧带", at: lerp(cfl0, cfl1, 0.55), 196, 292, color: lig, bold: true)
            s.leader("back (PTFL)", "距腓后韧带", at: lerp(ptfl0, ptfl1, 0.6), 12, 212, color: lig, bold: true)
            s.leader("heel bone", "跟骨", at: foot(pt(150, 250)), 12, 292)
        }
        s.leader("fibula", "腓骨", at: pt(171, 110), 12, 110)
        s.leader("tibia", "胫骨", at: pt(204, 96), 204, 66, anchor: .middle)
        s.leader("Achilles tendon", "跟腱", at: pt(134, 150), 12, 150)
        if scene == 0 { s.leader("outer ankle bone", "外踝", at: pt(186, 190), 12, 184) }
        if kid { s.leader("growth plates", "生长板", at: pt(182, 172), 12, 240, color: Anat.blue) }
        if rice > 0.3 && rice < 0.8 { s.leader("ice 20 min, in a cloth", "冰袋包布，敷 20 分钟", at: pt(236, 196), 250, 180, color: Anat.blue, bold: true) }
        if rice >= 0.8 { s.leader("elastic bandage", "弹力绷带", at: pt(290, 222), 250, 180, color: hex("#A08250"), bold: true) }

        let chip: (String, String) = injured < 0.5 ? ("Healthy ligaments", "韧带正常") : scene == 3 && rice > 0.9 ? ("Swelling going down", "肿胀消退")
            : scene == 1 ? ("Rolling in", "脚踝内翻")
            : [("Grade I · stretched", "Ⅰ度 · 拉伤"), ("Grade II · partly torn", "Ⅱ度 · 部分撕裂"), ("Grade III · torn through", "Ⅲ度 · 完全断裂")][min(2, gi)]
        s.stateChip(chip.0, chip.1, 8, 8, color: injured < 0.5 ? Anat.green : scene == 3 && rice > 0.9 ? Anat.blue : Anat.red)

        drawAnkleCard(&s, scene: scene, grade: gi, rice: rice, roll: roll, who: who)
    }

    @MainActor private static func drawAnkleCard(_ s: inout Sketch, scene: Int, grade: Int, rice: Double, roll: Double, who: Profile) {
        let box = CGRect(x: 252, y: 8, width: 102, height: 144)
        let titles: [(String, String)] = [("Viewpoint", "观察角度"), ("From behind", "后面观"), ("Ligament fibers", "韧带纤维"), ("RICE, first 48 h", "伤后 48 小时 RICE")]
        let ti = titles[min(3, scene)]
        s.inset(box.minX, box.minY, box.width, box.height, ti.0, ti.1)
        var c = s.clipped(box.minX, box.minY, box.width, box.height)
        let cx = box.midX, lig = Anat.ligament
        switch scene {
        case 0:
            // right foot from above; we look at it from the little-toe side
            let fx = cx - 8, top = box.minY + 30
            c.path("M \(fx - 10) \(top + 96) C \(fx - 18) \(top + 70), \(fx - 22) \(top + 30), \(fx - 14) \(top + 12) C \(fx - 8) \(top + 2), \(fx + 12) \(top + 2), \(fx + 18) \(top + 14) "
                   + "C \(fx + 24) \(top + 36), \(fx + 18) \(top + 70), \(fx + 14) \(top + 96) C \(fx + 10) \(top + 108), \(fx - 6) \(top + 108), \(fx - 10) \(top + 96) Z",
                   fill: Anat.skin, stroke: Anat.skinEdge, lw: 1.2)
            for (i, r) in [5.5, 4, 3.6, 3.2, 2.8].enumerated() {
                c.circle(fx - 12 + Double(i) * 7, top + 4 + Double(i) * 1.6, r, fill: Anat.skin, stroke: Anat.skinEdge, lw: 0.9)
            }
            c.circle(fx + 14, top + 84, 3, fill: Anat.boneShade, stroke: Anat.boneEdge, lw: 0.8)
            c.bendArrow(pt(box.maxX - 8, top + 96), via: pt(box.maxX - 14, top + 84), pt(fx + 22, top + 84), color: Anat.blue, lw: 1.8)
            c.cardNote("outer side", "外侧", box.maxX - 20, top + 64, width: 40, size: 8, color: Anat.blue, bold: true)
        case 1:
            // from behind: the heel tips in and the outer strap stretches
            let ground = box.maxY - 14, ankle = pt(cx, ground - 30), tip = 26 * roll
            c.line(box.minX + 6, ground, box.maxX - 6, ground, stroke: hex("#C9C2B6"), lw: 2)
            c.gradFill("M \(cx - 22) \(box.minY + 20) C \(cx - 26) \(box.minY + 60), \(cx - 18) \(ankle.y - 16), \(cx - 16) \(ankle.y) L \(cx + 16) \(ankle.y) "
                       + "C \(cx + 18) \(ankle.y - 16), \(cx + 26) \(box.minY + 60), \(cx + 22) \(box.minY + 20) Z",
                       [Anat.skin, Anat.skinShade], from: pt(cx - 20, 0), to: pt(cx + 20, 0), stroke: Anat.skinEdge)
            c.group(rotate: tip, about: ankle) { f in
                f.path("M \(cx - 17) \(ankle.y - 4) C \(cx - 22) \(ankle.y + 16), \(cx - 16) \(ground), \(cx) \(ground) C \(cx + 16) \(ground), \(cx + 22) \(ankle.y + 16), \(cx + 17) \(ankle.y - 4) Z",
                       fill: Anat.skin, stroke: Anat.skinEdge)
                f.boneFill("M \(cx - 11) \(ankle.y + 6) C \(cx - 12) \(ground - 6), \(cx + 12) \(ground - 6), \(cx + 11) \(ankle.y + 6) C \(cx + 6) \(ankle.y + 2), \(cx - 6) \(ankle.y + 2), \(cx - 11) \(ankle.y + 6) Z",
                           light: pt(cx - 8, ankle.y), dark: pt(cx + 8, ground))
            }
            c.boneFill("M \(cx - 14) \(box.minY + 22) L \(cx + 4) \(box.minY + 22) L \(cx + 5) \(ankle.y - 2) C \(cx - 4) \(ankle.y + 2), \(cx - 12) \(ankle.y + 4), \(cx - 15) \(ankle.y) Z",
                       light: pt(cx - 10, 0), dark: pt(cx + 4, 0))
            c.boneFill("M \(cx + 8) \(box.minY + 22) L \(cx + 14) \(box.minY + 22) L \(cx + 16) \(ankle.y + 6) C \(cx + 14) \(ankle.y + 10), \(cx + 10) \(ankle.y + 8), \(cx + 9) \(ankle.y + 4) Z",
                       light: pt(cx + 8, 0), dark: pt(cx + 16, 0))
            let a = tip * .pi / 180, q = pt(10, 14)
            let end = pt(ankle.x + q.x * cos(a) - q.y * sin(a), ankle.y + q.x * sin(a) + q.y * cos(a))
            c.ligamentBand(pt(cx + 13, ankle.y + 7), end, width: 4, stretch: (roll * 1.4).clamped(0, 1))
            c.bendArrow(pt(cx - 30, ankle.y - 10), via: pt(cx - 34, ankle.y + 14), pt(cx - 20, ankle.y + 22), color: Anat.ink, lw: 1.3)
            c.label("inner", "内侧", box.minX + 7, ground + 10, size: 7.5, color: Anat.muted)
            c.label("outer", "外侧", box.maxX - 7, ground + 10, size: 7.5, color: Anat.muted, anchor: .end)
        case 2:
            // the same ligament up close: fibres stretched, partly torn, torn through
            let y0 = box.minY + 36, y1 = box.maxY - 30
            c.rect(box.minX + 10, y0 - 14, box.width - 20, 14, r: 4, fill: Anat.bone, stroke: Anat.boneEdge)
            c.rect(box.minX + 10, y1, box.width - 20, 14, r: 4, fill: Anat.bone, stroke: Anat.boneEdge)
            for i in 0..<8 {
                let x = box.minX + 18 + Double(i) * 9.4
                let broken = grade == 2 || (grade == 1 && [1, 2, 4, 6].contains(i))
                if broken {
                    c.path("M \(x) \(y0) C \(x + 1) \(y0 + 14), \(x - 2) \(y0 + 22), \(x + 2) \(y0 + 30)", stroke: lig, lw: 2.6, cap: .round)
                    c.path("M \(x) \(y1) C \(x - 1) \(y1 - 14), \(x + 2) \(y1 - 20), \(x - 2) \(y1 - 28)", stroke: lig, lw: 2.6, cap: .round)
                } else {
                    c.line(x, y0, x, y1, stroke: grade == 0 ? Anat.ligamentLight : lig, lw: grade == 0 ? 2 : 2.6)
                }
            }
            if grade >= 1 { c.softGlow(pt(cx, (y0 + y1) / 2), 36, 14, hex("#A3202F"), 0.3 + 0.15 * Double(grade)) }
            c.cardNote(["stretched", "partly torn", "torn through"][grade], ["拉伤", "部分撕裂", "完全断裂"][grade], cx, box.maxY - 12, width: 96, size: 9, color: lig, bold: true)
        default:
            let steps = [("R", "休"), ("I", "冰"), ("C", "压"), ("E", "抬")]
            for (i, (en, zh)) in steps.enumerated() {
                let on = rice > [0.05, 0.3, 0.55, 0.8][i]
                let x = box.minX + 17 + Double(i) * 22.5
                c.circle(x, box.minY + 34, 9.5, fill: on ? Anat.blue : hex("#EEEEEE"))
                c.label(en, zh, x, box.minY + 38, size: 10, color: on ? .white : hex("#A0A0A0"), anchor: .middle, bold: true)
            }
            let up = Anat.ease((rice - 0.8) / 0.15)
            let floor = box.maxY - 26
            c.rect(box.minX + 6, floor, box.width - 12, 6, r: 2, fill: hex("#D9C9B0"))
            let pc = Casualty(who, adult: 72)
            var body = SideFigure(h: pc.h, build: pc.build, look: pc.look, hip: .zero, rotation: -90, bump: pc.bump)
            body.near = .init(shoulder: 6, elbow: 8)
            body.nearLeg = .init(hip: 2 + 20 * up, knee: 2 + 4 * up, point: 20)
            body.farLeg = .init(hip: 1, knee: 2, point: 20)
            body.hip = CGPoint(x: box.minX + 44, y: floor - body.build.depth * body.h * 0.5)
            c.rect(box.minX + 8, floor - 6, 16, 6, r: 3, fill: .white, stroke: hex("#CCCCCC"))
            if up > 0.05 {
                let a = body.ankle(), top = a.y + body.build.legW * body.h * 0.45
                c.rect(a.x - 20, top, 30, floor - top, r: 6, fill: hex("#DCE6F2"), stroke: hex("#9FB3CC"), opacity: up)
            }
            body.drawBack(&c, farArm: false)
            body.drawBody(&c)
            body.drawArm(&c, near: true)
            if rice > 0.55 {
                let a = body.ankle()
                c.circle(a.x, a.y, body.build.legW * body.h * 0.6, fill: hex("#E6D3AE"), stroke: hex("#C4AE82"))
            }
            let now = rice > 0.8 ? ("foot above the heart", "脚高于心脏") : rice > 0.55 ? ("elastic wrap", "弹力绷带") : rice > 0.3 ? ("ice in a cloth", "冰袋包布") : ("rest, no weight", "休息，别负重")
            c.cardNote(now.0, now.1, cx, box.maxY - 10, width: 96, size: 8.5, color: Anat.blue, bold: true)
        }
    }
}

private func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }
