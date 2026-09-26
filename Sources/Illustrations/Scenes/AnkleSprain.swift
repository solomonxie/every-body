import SwiftUI

extension Illustrations {
    static let ankleSprain = Scenario(
        id: "ankle-sprain", group: .firstAid, title: Bilingual("Sprained ankle", "踝关节扭伤"),
        params: ["injured": 0, "grade": 0, "rice": 0],
        steps: [
            .watch("Ligaments are tough straps holding bone to bone.", "韧带是连接骨与骨的坚韧纤维带。", set: ["injured": 0, "grade": 0, "rice": 0]),
            .watch("Rolling the ankle inward over-stretches the outer ligaments — the ATFL goes first.", "脚踝内翻使外侧韧带过度拉伸——距腓前韧带最先受伤。", set: ["injured": 1]),
            .tryIt("Compare the three grades of sprain.", "试一试：对比三种扭伤程度。",
                   TryStep(mode: .compare(param: "grade", options: [("I", 0), ("II", 1), ("III", 2)]), success: { $0[v: "grade"] > 1.5 },
                           ok: Bilingual("Can’t take 4 steps, or bone tender? Get an X-ray.", "无法行走 4 步或骨头压痛？需拍 X 光。"))),
            .tryIt("First 48 h — Rest, Ice (20 min), Compression, Elevation. Apply RICE.", "试一试：48 小时内——休息、冰敷（20 分钟）、加压、抬高。",
                   set: ["grade": 1],
                   TryStep(mode: .scrub([Scrub(param: "rice", label: "RICE 处理", min: 0, max: 1)]), success: { $0[v: "rice"] > 0.9 },
                           ok: Bilingual("Swelling down. Then gentle movement as pain allows.", "肿胀减轻。之后在疼痛允许下逐步活动。"), demo: ["rice": 1])),
        ],
        draw: { s, p, _ in
            // right ankle from the outside (lateral view), toes to the right
            let g = Int(p[v: "grade"].rounded())
            let injured = p[v: "injured"] > 0.5
            let swelling = max(0, p[v: "injured"] * (0.4 + Double(g) * 0.3) * (1 - 0.6 * p[v: "rice"]))
            let bone = hex("#E9E2CF"), edge = hex("#B8A58A"), lig = hex("#C1443C"), label = hex("#8F7E63")
            s.path("M 118 214 C 126 150, 140 60, 146 10 L 262 10 C 250 90, 236 160, 262 200 L 350 244 C 356 262, 340 268, 320 266 L 130 262 C 108 256, 108 232, 118 214 Z",
                   fill: hex("#F7E6DA"), stroke: hex("#E2C8B6"), lw: 1.5)
            s.ellipse(205, 200, 42 + swelling * 26, 24 + swelling * 18, fill: hex("#D8434B"), opacity: 0.22 * swelling)
            s.path("M 150 10 L 184 10 L 186 165 C 190 176, 188 184, 176 186 L 150 186 C 144 176, 146 168, 150 160 Z", fill: hex("#E2DAC4"), stroke: edge, lw: 1.5)   // tibia
            s.path("M 146 188 C 152 170, 204 168, 216 186 C 224 200, 214 214, 196 216 L 150 214 C 140 208, 140 196, 146 188 Z", fill: bone, stroke: edge, lw: 1.5)   // talus
            s.path("M 118 218 C 108 238, 118 258, 146 260 L 214 252 C 226 242, 222 226, 206 220 L 150 214 C 136 212, 124 210, 118 218 Z", fill: bone, stroke: edge, lw: 1.5) // calcaneus
            s.ellipse(232, 205, 16, 12, fill: bone, stroke: edge)                                       // navicular
            s.ellipse(238, 236, 16, 13, fill: bone, stroke: edge)                                       // cuboid
            for (y0, y1) in [(200.0, 238.0), (214, 246), (230, 254)] {
                s.line(250, y0, 318, y1, stroke: bone, lw: 10, cap: .round)
                s.line(250, y0, 318, y1, stroke: edge, lw: 0.8)
                s.line(322, y1 + 1, 346, y1 + 6, stroke: bone, lw: 8, cap: .round)
            }
            s.path("M 184 20 L 198 20 L 200 176 C 208 188, 206 200, 194 206 C 184 204, 180 194, 184 180 Z", fill: bone, stroke: edge, lw: 1.5)                          // fibula
            // lateral ligaments: ATFL (front), CFL (down to the heel), PTFL (back)
            func band(_ d: String, torn: Bool, stretched: Bool) {
                if torn {
                    s.path(d, stroke: lig, lw: 6, cap: .round, dash: [8, 10])
                } else {
                    s.path(d, stroke: lig, lw: stretched ? 4 : 6, opacity: stretched ? 0.75 : 1, cap: .round)
                }
            }
            band("M 202 192 L 228 196", torn: injured && g >= 1, stretched: injured && g == 0)
            band("M 196 206 L 176 240", torn: injured && g >= 2, stretched: injured && g == 1)
            band("M 186 200 L 152 206", torn: false, stretched: false)
            s.text("tibia 胫骨", 108, 70, size: 9, color: label)
            s.text("fibula 腓骨", 206, 70, size: 9, color: label)
            s.text("ATFL 距腓前韧带", 226, 180, size: 9, color: lig)
            s.text("CFL 跟腓韧带", 128, 282, size: 9, color: lig)
            s.path("M 150 280 L 174 244", stroke: lig, lw: 0.8)
            s.text("PTFL 距腓后", 96, 200, size: 9, color: lig)
            s.text("talus 距骨 · heel 跟骨", 20, 244, size: 9, color: label)
            if injured { s.path("M 300 120 C 290 150, 270 160, 250 158", stroke: hex("#555555"), lw: 1.5, dash: [4, 3]); s.text("rolled inward 内翻", 262, 116, size: 9) }
            s.rect(8, 6, 220, 30, r: 8, fill: .white, stroke: lig, lw: 2)
            let grades = ["I — ATFL stretched 距腓前韧带拉伤", "II — ATFL torn 距腓前韧带撕裂", "III — ATFL + CFL torn 两条韧带断裂"]
            s.text(injured ? grades[min(2, max(0, g))] : "Healthy ligaments 韧带正常", 18, 26, size: 11, color: lig, bold: true)
            if p[v: "rice"] > 0.1 { s.text("RICE applied — swelling \(Int((swelling * 100).rounded()))%", 20, 298, size: 10, color: hex("#3F95D6")) }
        },
        sources: ["BJSM / Red Cross acute ankle sprain management (RICE / PEACE & LOVE)"]
    )
}
