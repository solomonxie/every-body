import SwiftUI

extension Illustrations {
    static func ankleSprain(for p: Profile) -> Scenario {
        var s: Scenario = ankleSprain
        s.profileNote = switch p.age {
        case .infant, .child: Bilingual("Children: ligaments are stronger than the growth plate, so a “sprain” may be a growth-plate break — X-ray if the bone is tender or they won’t walk.",
                                        "儿童：韧带比生长板结实，“扭伤”可能是生长板骨折——骨头压痛或不肯走路要拍 X 光。")
        case .senior: Bilingual("65+: a twisted ankle is more often a broken bone — get an X-ray, and use a stick while it heals to avoid another fall.",
                                "65 岁以上：扭脚更容易骨折——应拍 X 光；恢复期拄拐杖，防止再次跌倒。")
        case .adult: nil
        }
        return s
    }

    static let ankleSprain = Scenario(
        id: "ankle-sprain", group: .firstAid, title: Bilingual("Sprained ankle", "踝关节扭伤"),
        params: ["injured": 0, "grade": 0, "rice": 0, "scene": 0],
        steps: [
            .watch("Your ankle from the outside. Ligaments are tough straps holding bone to bone; three of them hold the outer ankle bone (the fibula’s tip) to the foot.",
                   "从外侧看脚踝。韧带是连接骨与骨的坚韧纤维带；外踝（腓骨下端）靠三条韧带与足骨相连。",
                   set: ["injured": 0, "grade": 0, "rice": 0, "scene": 0]),
            .watch("Stepping off a kerb or landing on someone’s foot rolls the ankle inward. The outer ligaments over-stretch — the front one (ATFL) goes first.",
                   "踩空台阶或落地踩到别人脚上，脚踝向内翻。外侧韧带被过度拉伸——前面的距腓前韧带最先受伤。",
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
        draw: { s, p, _ in
            // right ankle from the outside (lateral view), toes to the right
            let g = Int(p[v: "grade"].rounded()), scene = Int(p[v: "scene"].rounded())
            let injured = p[v: "injured"] > 0.5, rice = p[v: "rice"]
            let swelling = max(0, p[v: "injured"] * (0.4 + Double(g) * 0.3) * (1 - 0.6 * rice))
            let bone = hex("#E9E2CF"), edge = hex("#B8A58A"), lig = hex("#C1443C"), label = hex("#8F7E63"), blue = hex("#3F95D6")
            let skin = "M 132 0 C 134 80, 132 150, 124 196 C 116 216, 108 244, 116 258 C 124 268, 140 270, 156 268 L 250 268 C 290 270, 320 272, 344 270 "
                + "C 358 268, 360 254, 350 248 C 320 236, 280 216, 252 196 C 240 186, 234 170, 232 140 C 230 100, 228 50, 230 0 Z"
            s.path(skin, fill: hex("#F7E6DA"), stroke: hex("#DDBFA8"), lw: 2)
            s.ellipse(186, 204, 34 + swelling * 22, 22 + swelling * 14, fill: hex("#D8434B"), opacity: 0.25 * swelling)
            if injured && g >= 1 { s.ellipse(178, 236, 18 + Double(g) * 8, 10 + Double(g) * 3, fill: hex("#6C4F9E"), opacity: 0.18 * (1 - 0.5 * rice)) }
            // bones: heel, talus, tibia, then the fibula on top (it's the outer bone)
            s.path("M 124 222 C 118 240, 122 262, 146 264 L 222 256 C 232 248, 230 232, 216 226 L 176 214 C 156 210, 132 208, 124 222 Z", fill: bone, stroke: edge, lw: 1.5)
            s.path("M 158 192 C 176 176, 208 176, 222 184 C 230 188, 236 194, 240 200 C 236 210, 224 212, 212 210 L 162 212 C 152 208, 150 198, 158 192 Z", fill: bone, stroke: edge, lw: 1.5)
            s.path("M 170 0 L 226 0 C 224 60, 222 130, 224 170 C 222 180, 214 184, 204 182 L 176 180 C 168 150, 170 60, 170 0 Z", fill: hex("#E2DAC4"), stroke: edge, lw: 1.5)
            s.ellipse(248, 204, 9, 9, fill: bone, stroke: edge)
            s.ellipse(264, 208, 8, 9, fill: bone, stroke: edge)
            s.ellipse(240, 236, 13, 11, fill: bone, stroke: edge)
            for (x0, y0, x1, y1) in [(272.0, 212.0, 330.0, 246.0), (262, 228, 326, 256), (252, 246, 318, 262)] {
                s.line(x0, y0, x1, y1, stroke: edge, lw: 9, cap: .round)
                s.line(x0, y0, x1, y1, stroke: bone, lw: 7, cap: .round)
                s.line(x1 + 5, y1 + 2, x1 + 24, y1 + 6, stroke: edge, lw: 7, cap: .round)
                s.line(x1 + 5, y1 + 2, x1 + 24, y1 + 6, stroke: bone, lw: 5, cap: .round)
            }
            s.path("M 158 0 L 172 0 C 172 60, 174 130, 180 170 C 188 182, 190 198, 180 210 C 170 212, 160 204, 158 192 C 158 170, 160 130, 158 0 Z", fill: bone, stroke: edge, lw: 1.5)
            // lateral ligaments: ATFL (front), CFL (down to the heel), PTFL (back)
            func band(_ d: String, torn: Bool, stretched: Bool) {
                if torn {
                    s.path(d, stroke: lig, lw: 5, cap: .round, dash: [6, 7])
                } else {
                    s.path(d, stroke: lig, lw: stretched ? 3 : 5, opacity: stretched ? 0.75 : 1, cap: .round)
                }
            }
            band("M 186 194 L 222 196", torn: injured && g >= 1, stretched: injured && g == 0)
            band("M 178 208 L 170 238", torn: injured && g >= 2, stretched: injured && g == 1)
            band("M 164 200 L 150 206", torn: false, stretched: false)

            // RICE: ice pack, then an elastic wrap
            if rice > 0.55 {
                var wrap = s
                wrap.ctx.clip(to: SVGPath.parse(skin))
                wrap.ctx.clip(to: Path(CGRect(x: 136, y: 140, width: 150, height: 132)))
                for k in 0..<7 {
                    let y = 150 + Double(k) * 17
                    wrap.line(150, y + 34, 300, y - 6 + Double(k) * 8, stroke: hex("#E8D5B0"), lw: 14, opacity: 0.9)
                    wrap.line(150, y + 34, 300, y - 6 + Double(k) * 8, stroke: hex("#C9B48A"), lw: 1, opacity: 0.9)
                }
            }
            if rice > 0.3 {
                s.group(rotate: -12, about: CGPoint(x: 186, y: 204)) { g in
                    g.rect(160, 188, 54, 32, r: 8, fill: hex("#BFE3F5"), stroke: blue, lw: 1.5)
                    g.shape(Path(roundedRect: CGRect(x: 164, y: 192, width: 46, height: 24), cornerRadius: 6), stroke: .white, lw: 1.5, dash: [3, 3])
                }
                s.label("ice 20 min", "冰敷 20 分钟", 150, 180, size: 9, color: blue, anchor: .end)
            }
            if scene == 0 { s.label("outer ankle bone", "外踝", 150, 188, size: 9, color: label, anchor: .end) }
            s.label("fibula", "腓骨", 152, 70, size: 9, color: label, anchor: .end)
            s.label("tibia", "胫骨", 232, 70, size: 9, color: label)
            if rice <= 0.3 {
                s.label("ATFL", "距腓前韧带", 226, 186, size: 9, color: lig)
                s.label("CFL", "跟腓韧带", 106, 290, size: 9, color: lig)
                s.path("M 128 282 L 168 240", stroke: lig, lw: 0.8)
                s.label("PTFL", "距腓后韧带", 110, 210, size: 9, color: lig, anchor: .end)
                s.label("heel", "跟骨", 180, 286, size: 9, color: label)
            }
            s.rect(8, 6, 220, 30, r: 8, fill: .white, stroke: lig, lw: 2)
            let grades = [s.t("I — ATFL stretched", "Ⅰ度：距腓前韧带拉伤"), s.t("II — ATFL torn", "Ⅱ度：距腓前韧带撕裂"), s.t("III — ATFL + CFL torn", "Ⅲ度：两条韧带断裂")]
            s.text(injured ? grades[min(2, max(0, g))] : s.t("Healthy ligaments", "韧带正常"), 18, 26, size: 11, color: lig, bold: true)

            // inset
            let box = CGRect(x: 262, y: 44, width: 92, height: 128)
            let cx = box.midX
            if scene == 1 {
                // from behind: the foot tips inward and the outer strap stretches
                s.rect(box.minX, box.minY, box.width, box.height, r: 10, fill: .white, stroke: hex("#DDDDDD"), lw: 1.5)
                s.label("from behind", "后面观", cx, box.minY + 14, size: 8, color: label, anchor: .middle)
                s.label("rolled in", "内翻", cx, 170, size: 8, color: lig, anchor: .middle, bold: true)
                s.line(box.minX + 8, 162, box.maxX - 8, 162, stroke: hex("#BBBBBB"), lw: 2)
                let ankle = CGPoint(x: cx, y: 128), tip = 18.0
                s.group(rotate: tip, about: ankle) { f in
                    f.path("M \(cx - 18) 128 C \(cx - 24) 146, \(cx - 18) 158, \(cx) 158 C \(cx + 18) 158, \(cx + 24) 146, \(cx + 18) 128 Z", fill: hex("#F7E6DA"), stroke: hex("#DDBFA8"))
                    f.ellipse(cx, 144, 11, 9, fill: bone, stroke: edge)
                    f.line(cx - 16, 158, cx + 16, 158, stroke: hex("#8A6A5A"), lw: 3, cap: .round)
                }
                s.path("M \(cx - 24) 64 C \(cx - 27) 90, \(cx - 18) 114, \(cx - 16) 132 L \(cx + 16) 132 C \(cx + 18) 114, \(cx + 27) 90, \(cx + 24) 64 Z", fill: hex("#F7E6DA"), stroke: hex("#DDBFA8"))
                s.rect(cx - 14, 64, 16, 62, r: 3, fill: hex("#E2DAC4"), stroke: edge)
                s.rect(cx + 6, 64, 8, 72, r: 4, fill: bone, stroke: edge)
                s.label("inner", "内侧", box.minX + 8, 170, size: 7, color: label)
                s.label("outer", "外侧", box.maxX - 8, 170, size: 7, color: label, anchor: .end)
                let a = tip * .pi / 180, q = CGPoint(x: cx + 14 - ankle.x, y: 146 - ankle.y)
                let end = CGPoint(x: ankle.x + q.x * cos(a) - q.y * sin(a), y: ankle.y + q.x * sin(a) + q.y * cos(a))
                s.line(cx + 11, 134, end.x, end.y, stroke: lig, lw: 3, cap: .round)
                s.path("M \(cx - 30) 110 C \(cx - 34) 132, \(cx - 26) 146, \(cx - 18) 150", stroke: hex("#555555"), lw: 1.2, dash: [3, 2])
            } else if scene == 2 {
                // ligament fibres up close
                s.rect(box.minX, box.minY, box.width, box.height, r: 10, fill: .white, stroke: hex("#DDDDDD"), lw: 1.5)
                s.label("fibres", "纤维", cx, box.minY + 14, size: 8, color: label, anchor: .middle)
                s.rect(box.minX + 10, 66, box.width - 20, 16, r: 4, fill: bone, stroke: edge)
                s.rect(box.minX + 10, 140, box.width - 20, 16, r: 4, fill: bone, stroke: edge)
                for i in 0..<7 {
                    let x = box.minX + 20 + Double(i) * 8.5
                    let broken = g == 2 || (g == 1 && i % 2 == 0)
                    if broken {
                        s.path("M \(x) 82 L \(x + 1) 100 l -2 4", stroke: lig, lw: 2.5, cap: .round)
                        s.path("M \(x) 140 L \(x - 1) 122 l 2 -4", stroke: lig, lw: 2.5, cap: .round)
                    } else {
                        s.path(g == 0 ? "M \(x) 82 L \(x) 140" : "M \(x) 82 C \(x + 3) 100, \(x - 3) 120, \(x) 140", stroke: lig, lw: g == 0 ? 2 : 2.5)
                    }
                }
                s.label(["stretched", "partly torn", "torn through"][g],["拉伸", "部分撕裂", "完全断裂"][g], cx, box.maxY - 4, size: 8, color: lig, anchor: .middle)
            } else if scene == 3 {
                // lying down, foot up on pillows above the heart
                s.rect(box.minX, box.minY, box.width, box.height, r: 10, fill: .white, stroke: hex("#DDDDDD"), lw: 1.5)
                let steps = [("R", "休"), ("I", "冰"), ("C", "压"), ("E", "抬")]
                for (i, (en, zh)) in steps.enumerated() {
                    let on = rice > [0.08, 0.3, 0.55, 0.8][i]
                    let x = box.minX + 14 + Double(i) * 21.5
                    s.circle(x, box.minY + 18, 9, fill: on ? blue : hex("#EEEEEE"))
                    s.label(en, zh, x, box.minY + 22, size: 10, color: on ? .white : hex("#999999"), anchor: .middle, bold: true)
                }
                let up = rice > 0.8
                let floor = 150.0
                s.rect(box.minX + 6, floor, box.width - 12, 6, r: 2, fill: hex("#D9C9B0"))
                if up { s.rect(box.maxX - 34, floor - 20, 28, 20, r: 6, fill: hex("#DCE6F2"), stroke: hex("#9FB3CC")) }
                let body = Person(h: 66, shirt: hex("#DCE6F2"), shirtLine: hex("#9FB3CC"), shoulder: 0, elbow: 0, hip: up ? 22 : 0)
                body.draw(&s, at: CGPoint(x: box.minX + 44, y: floor - 5), rotation: -90, farArm: false)
                let now = rice > 0.8 ? s.t("foot above heart", "脚高于心脏") : rice > 0.55 ? s.t("elastic wrap", "弹力绷带") : rice > 0.3 ? s.t("ice in a cloth", "冰袋包布") : s.t("rest, no weight", "休息，别负重")
                s.text(now, cx, box.maxY - 4, size: 8, color: blue, anchor: .middle)
            }
        },
        sources: ["BJSM / Red Cross acute ankle sprain management (RICE / PEACE & LOVE)", "Ottawa ankle rules"]
    )
}
