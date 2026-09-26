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
        case 0: .watch("A fall on the hand. A child’s bone is springy: it bends and cracks on one side only — a greenstick fracture, near the growth plate.",
                       "摔倒手撑地。儿童骨头有弹性：只弯曲、一侧裂开——青枝骨折，靠近生长板。", set: ["offset": 1, "weeks": 0, "cast": 0, "scene": 0])
        case 2: .watch("A fall from standing breaks the wrist: thin, fragile bone (osteoporosis) snaps and crushes just above the joint.",
                       "站立摔倒即可腕部骨折：骨质疏松的骨头又薄又脆，在关节上方断裂、压缩。", set: ["offset": 1, "weeks": 0, "cast": 0, "scene": 0])
        default: .watch("A fall on the outstretched hand breaks the radius just above the wrist; the lower piece shifts back — the “dinner-fork” wrist.",
                        "跌倒时手撑地，腕上方桡骨断裂，远端骨块向背侧移位——“餐叉样”畸形。", set: ["offset": 1, "weeks": 0, "cast": 0, "scene": 0])
        }
        var s = Scenario(
            id: "fracture-healing", group: .bones, title: Bilingual("Fracture: setting & healing", "骨折：复位与愈合"),
            warning: Bilingual("Setting a bone is a clinician’s job — this shows how it works.", "骨折复位须由医生操作——此处仅演示原理。"),
            params: ["offset": 1, "weeks": 0, "cast": 0, "scene": 0, "age": age],
            steps: [
                first,
                .watch("First aid: don’t straighten it. Rest the forearm across the body, support it with the other hand or a folded magazine, cold pack, rings off, go to hospital.",
                       "急救：不要掰直。前臂横放胸前，用另一只手或卷起的杂志托住，冷敷，摘下戒指，尽快就医。", set: ["scene": 1]),
                .tryIt(age == 0 ? "Setting (reduction): drag the bent end back straight." : "Setting (reduction), after numbing: drag the lower piece back into line.",
                       age == 0 ? "试一试（复位）：把弯曲的一端拖回伸直。" : "试一试（复位，先麻醉）：把远端骨块拖回对齐。", set: ["scene": 2],
                       TryStep(mode: .drag, success: { $0[v: "offset"] < 0.08 },
                               ok: Bilingual("Ends aligned — now they must be held still.", "断端对齐——接下来需要固定。"), demo: ["offset": 0])),
                .watch("A cast from below the elbow to the knuckles holds the ends still; a sling keeps the hand up to limit swelling.",
                       "石膏从肘下到掌指关节固定断端；吊带抬高手部，减轻肿胀。", set: ["offset": 0, "cast": 1, "scene": 3]),
                .tryIt("Drag through the weeks: clot → soft callus → hard callus → remodelled bone.", "试一试：拖动周数：血肿 → 软骨痂 → 硬骨痂 → 塑形。",
                       TryStep(mode: .scrub([Scrub(param: "weeks", label: "Weeks 周", min: 0, max: maxWeeks, digits: 1)]), success: { healing($0[v: "weeks"] / speed).remodel > 0.5 },
                               ok: [Bilingual("Child: ~3–6 weeks in a cast; growing bone even straightens itself.", "儿童：石膏约 3–6 周；生长中的骨头还能自行矫直。"),
                                    Bilingual("Adult forearm: ~6 weeks in a cast, remodelling for months.", "成人前臂：石膏约 6 周，塑形持续数月。"),
                                    Bilingual("Senior: 8+ weeks; ask for a bone-density (DEXA) check to prevent a hip fracture.", "老人：8 周以上；应做骨密度检查，预防髋部骨折。")][Int(age)],
                               demo: ["weeks": maxWeeks])),
            ],
            draw: { s, p, _ in draw(&s, p, speed: speed) },
            onDrag: { point, _ in ["offset": ((160 - point.y) / 16).clamped(0, 1)] },
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

    @MainActor private static func draw(_ s: inout Sketch, _ p: Params, speed: Double) {
        // right forearm and hand seen from above, palm down: elbow off to the left, thumb side (radius) on top
        let age = Int(p[v: "age"].rounded()), kid = age == 0, old = age == 2
        let bone = old ? hex("#F1ECDD") : hex("#E9E2CF"), edge = hex("#B8A58A"), label = hex("#8F7E63"), red = hex("#D8434B")
        let skin = hex("#F7E6DA"), skinLine = hex("#DDBFA8")
        let o = p[v: "offset"], weeks = p[v: "weeks"], cast = p[v: "cast"] > 0.5
        let h = healing(weeks / speed)
        let aligned = o < 0.08
        let breakX = 206.0
        // kids bend about the intact lower cortex; adults shift up (radially) and back, slightly tilted
        let pivot = kid ? CGPoint(x: breakX, y: 170) : CGPoint(x: breakX, y: 158)
        let shift = kid ? CGPoint.zero : CGPoint(x: -5 * o, y: -15 * o)
        let tilt = kid ? -13 * o : -8 * o

        s.path("M 0 128 C 100 128, 190 130, 236 134 L 240 212 C 190 214, 100 214, 0 216 Z", fill: skin)
        s.path("M 0 128 C 100 128, 190 130, 236 134 M 240 212 C 190 214, 100 214, 0 216", stroke: skinLine, lw: 2)
        let swell = aligned ? h.hematoma * 0.5 : 1
        if !cast && swell > 0.02 { s.ellipse(breakX + 8, 168, 40, 44, fill: red, opacity: 0.16 * swell) }

        // ulna: shaft, head and styloid on the little-finger side
        s.path("M 0 182 C 80 184, 170 186, 214 184 C 226 182, 234 184, 236 190 L 240 196 C 236 202, 226 204, 214 200 C 170 198, 80 198, 0 198 Z",
               fill: bone, stroke: edge, lw: 1.5)
        if kid { s.line(222, 183, 222, 201, stroke: hex("#3F95D6"), lw: 2) }
        // radius shaft up to the break
        s.path("M 0 150 C 80 150, 160 150, \(breakX) 146 L \(breakX) 172 C 160 168, 80 168, 0 166 Z", fill: bone, stroke: edge, lw: 1.5)
        if old { for (x, y) in [(186.0, 156.0), (196, 162), (192, 150)] { s.circle(x, y, 1.6, fill: edge.opacity(0.6)) } }

        // distal radius fragment + the whole hand move together
        s.group(translate: shift, rotate: tilt, about: pivot) { g in
            let hand = "M 238 134 C 262 128, 290 114, 314 96 C 322 90, 336 92, 332 104 C 326 114, 316 124, 310 134 C 330 134, 346 134, 360 134 "
            g.path(hand + "L 360 206 C 320 212, 280 210, 240 212 Z", fill: skin)
            g.path(hand + "M 360 206 C 320 212, 280 210, 240 212", stroke: skinLine, lw: 2)
            g.path("M \(breakX + 2) 146 C 224 144, 236 136, 248 136 C 246 150, 242 166, 238 180 C 230 178, 220 176, \(breakX + 2) 172 Z", fill: bone, stroke: edge, lw: 1.5)
            if kid { g.path("M 230 141 C 232 156, 232 168, 230 178", stroke: hex("#3F95D6"), lw: 2) }
            if old { for (x, y) in [(220.0, 156.0), (230, 164), (226, 150), (216, 166)] { g.circle(x, y, 1.6, fill: edge.opacity(0.6)) } }
            for (x, y, rx, ry) in [(256.0, 146.0, 8.0, 7.0), (254, 162, 7, 7), (254, 177, 7, 6.5), (257, 191, 5.5, 5), (272, 140, 7, 6), (272, 154, 6.5, 6), (272, 168, 8, 7.5), (270, 184, 8, 7)] {
                g.ellipse(x, y, rx, ry, fill: bone, stroke: edge)
            }
            for (x0, y0, x1, y1) in [(280.0, 136.0, 300.0, 120.0), (282, 150, 330, 148), (282, 166, 334, 166), (280, 180, 330, 182), (278, 192, 322, 198)] {
                g.line(x0, y0, x1, y1, stroke: edge, lw: 9.5, cap: .round)
                g.line(x0, y0, x1, y1, stroke: bone, lw: 7.5, cap: .round)
                let dx = x1 - x0, dy = y1 - y0, l = hypot(dx, dy), f = y0 < 140 ? 22.0 : 40
                let a = CGPoint(x: x1 + dx / l * 6, y: y1 + dy / l * 6)
                g.line(a.x, a.y, a.x + dx / l * f, a.y + dy / l * f, stroke: edge, lw: 7.5, cap: .round)
                g.line(a.x, a.y, a.x + dx / l * f, a.y + dy / l * f, stroke: bone, lw: 5.5, cap: .round)
            }
        }
        if kid {
            s.path("M \(breakX) 146 l 5 4 l -4 4 l 5 4", stroke: o > 0.08 ? red : label, lw: 1.5)
        } else {
            let jag = old ? "l 4 3 l -5 3 l 6 3 l -4 3 l 5 3 l -5 3 l 4 3 l -5 3" : "l 5 4 l -4 5 l 5 4 l -4 5 l 4 4"
            s.path("M \(breakX) 146 \(jag)", stroke: o > 0.08 ? red : label, lw: 1.5)
        }

        // healing at the break
        let c = CGPoint(x: breakX + 2, y: 159)
        let bulge = 8 * (h.soft + h.hard) * (1 - h.remodel * 0.8)
        if weeks > 0 || cast {
            if h.hematoma > 0.02 { s.ellipse(c.x, c.y, 16, 20, fill: hex("#B3263A"), opacity: 0.5 * h.hematoma) }
            if h.soft > 0.02 { s.ellipse(c.x, c.y, 8 + bulge, 13 + bulge / 2, fill: hex("#8FB3E0"), opacity: 0.7 * h.soft) }
            if h.hard > 0.02 { s.ellipse(c.x, c.y, 7 + bulge, 13 + bulge / 2, fill: bone, stroke: edge, opacity: h.hard) }
        }
        if cast {
            s.path("M 70 124 L 244 128 C 262 128, 280 132, 292 136 L 292 212 C 270 216, 256 216, 244 218 L 70 220 Z",
                   fill: .white, stroke: hex("#BBBBBB"), lw: 2, opacity: 0.55)
            for x in stride(from: 90.0, through: 270, by: 30) { s.line(x, 126, x - 8, 218, stroke: hex("#CCCCCC"), lw: 1, opacity: 0.6) }
            s.label("cast", "石膏", 110, 236, size: 9, color: hex("#888888"))
        }

        s.label("radius", "桡骨", 40, 144, size: 9, color: label)
        if old { s.label("thin, porous bone", "骨质疏松", 110, 144, size: 9, color: label) }
        s.label("ulna", "尺骨", 40, 212, size: 9, color: label)
        if kid { s.label("growth plate", "生长板", 214, 232, size: 9, color: hex("#3F95D6")) }
        else if !cast { s.label("wrist bones", "腕骨", 262, 226, size: 9, color: label) }
        if o > 0.08 && !cast {
            let msg = kid ? s.t("bent — cracked on one side", "弯折——一侧裂开") : s.t("lower piece shifted", "远端骨块移位")
            s.text(msg, 140, 118, size: 9, color: red)
        }
        let status = aligned ? hex("#2E9E5B") : red
        s.rect(8, 6, 130, 30, r: 8, fill: .white, stroke: status, lw: 2)
        s.text(aligned ? s.t("Aligned", "对位良好") : kid ? s.t("Bent", "弯折") : s.t("Displaced", "移位"), 73, 26, size: 11, color: status, anchor: .middle, bold: true)

        // healing timeline once in the cast
        if cast {
            let x0 = 20.0, w = 320.0, maxW = (12 * speed).rounded()
            let phases: [(Double, Double, Color, String, String)] = [(0, 2, hex("#B3263A"), "clot", "血肿"), (2, 4, hex("#8FB3E0"), "soft callus", "软骨痂"),
                                                                      (4, 8, hex("#C9B98F"), "hard callus", "硬骨痂"), (8, 12, bone, "remodel", "塑形")]
            for (a, b, col, en, zh) in phases {
                let xa = x0 + a * speed / maxW * w, xb = x0 + min(maxW, b * speed) / maxW * w
                s.rect(xa, 262, xb - xa, 10, fill: col, stroke: edge, lw: 0.5, opacity: 0.8)
                s.label(en, zh, (xa + xb) / 2, 288, size: 8, color: label, anchor: .middle)
            }
            let mx = x0 + weeks / maxW * w
            s.path("M \(mx) 258 l -5 -7 l 10 0 Z", fill: hex("#333333"))
            s.text(s.t("Week \(String(format: "%.1f", weeks))", "第 \(String(format: "%.1f", weeks)) 周"), 306, 26, size: 11, color: hex("#333333"), anchor: .middle, bold: true)
        }

        // inset: the injured person or the side-view deformity
        let box = CGRect(x: 146, y: 6, width: 110, height: 100)
        let scene = Int(p[v: "scene"].rounded())
        if scene == 1 || scene == 3 {
            s.rect(box.minX, box.minY, box.width, box.height, r: 10, fill: .white, stroke: hex("#DDDDDD"), lw: 1.5)
            var fig = InjuryFigure(h: 130)
            if scene == 1 {
                (fig.right, fig.left) = (InjuryFigure.guarding.right, InjuryFigure.guarding.left)
            } else {
                fig.right = (CGPoint(x: -0.125, y: 0.19), CGPoint(x: 0.03, y: 0.15))
                fig.cast = true
                fig.sling = true
            }
            var clip = s
            clip.ctx.clip(to: Path(roundedRect: CGRect(x: box.minX + 1, y: box.minY + 1, width: box.width - 2, height: box.height - 2), cornerRadius: 10))
            fig.draw(&clip, at: CGPoint(x: box.midX, y: 36))
            if scene == 1 { s.rect(box.midX - 2, 57, 16, 10, r: 3, fill: hex("#BFE3F5"), stroke: hex("#3F95D6")) }
        } else {
            // side view: the wrist steps up like a dinner fork until it's set
            s.rect(box.minX, box.minY, box.width, box.height, r: 10, fill: .white, stroke: hex("#DDDDDD"), lw: 1.5)
            let k = kid ? o * 0.6 : o
            let x = box.minX, y = box.minY
            s.path("M \(x + 6) \(y + 46) L \(x + 58) \(y + 46) C \(x + 64) \(y + 46 - 10 * k), \(x + 70) \(y + 44 - 12 * k), \(x + 74) \(y + 44 - 10 * k) "
                   + "C \(x + 84) \(y + 46 - 8 * k), \(x + 96) \(y + 48 - 6 * k), \(x + 106) \(y + 52 - 6 * k) L \(x + 106) \(y + 60 - 6 * k) "
                   + "C \(x + 94) \(y + 62 - 6 * k), \(x + 82) \(y + 64 - 4 * k), \(x + 72) \(y + 66) L \(x + 6) \(y + 68) Z",
                   fill: skin, stroke: skinLine, lw: 1.5)
            s.label("side view", "侧面观", box.midX, y + 18, size: 9, color: label, anchor: .middle)
            if k > 0.2 {
                s.label(kid ? "bent" : "“dinner fork”", kid ? "弯曲" : "“餐叉样”畸形", box.midX, y + 86, size: 9, color: red, anchor: .middle)
            } else {
                s.label("straight", "已矫直", box.midX, y + 86, size: 9, color: hex("#2E9E5B"), anchor: .middle)
            }
        }
    }
}
