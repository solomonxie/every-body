import SwiftUI

extension Illustrations {
    static let ankleSprain = Scenario(
        id: "ankle-sprain", group: .firstAid, title: Bilingual("Sprained ankle", "踝关节扭伤"),
        params: ["injured": 0, "grade": 0, "rice": 0],
        steps: [
            .watch("Ligaments are tough straps holding bone to bone.", "韧带是连接骨与骨的坚韧纤维带。", set: ["injured": 0, "grade": 0, "rice": 0]),
            .watch("Rolling the ankle inward over-stretches the outer ligament.", "脚踝内翻使外侧韧带过度拉伸。", set: ["injured": 1]),
            .tryIt("Compare the three grades of sprain.", "试一试：对比三种扭伤程度。",
                   TryStep(mode: .compare(param: "grade", options: [("I", 0), ("II", 1), ("III", 2)]), success: { $0[v: "grade"] > 1.5 },
                           ok: Bilingual("Can’t take 4 steps, or bone tender? Get an X-ray.", "无法行走 4 步或骨头压痛？需拍 X 光。"))),
            .tryIt("First 48 h — Rest, Ice (20 min), Compression, Elevation. Apply RICE.", "试一试：48 小时内——休息、冰敷（20 分钟）、加压、抬高。",
                   set: ["grade": 1],
                   TryStep(mode: .scrub([Scrub(param: "rice", label: "RICE 处理", min: 0, max: 1)]), success: { $0[v: "rice"] > 0.9 },
                           ok: Bilingual("Swelling down. Then gentle movement as pain allows.", "肿胀减轻。之后在疼痛允许下逐步活动。"), demo: ["rice": 1])),
        ],
        draw: { s, p, _ in
            let g = Int(p[v: "grade"].rounded())
            let swelling = max(0, p[v: "injured"] * (0.4 + Double(g) * 0.3) * (1 - 0.6 * p[v: "rice"]))
            let bone = hex("#E9E2CF"), edge = hex("#B8A58A"), lig = hex("#C1443C")
            s.rect(120, 20, 50, 150, r: 20, fill: bone, stroke: edge, lw: 2)
            s.rect(185, 30, 22, 140, r: 10, fill: bone, stroke: edge, lw: 2)
            s.text("shin bones 胫腓骨", 60, 60, color: hex("#8F7E63"))
            s.path("M 100 190 C 100 170, 230 165, 240 190 L 330 230 C 340 250, 320 260, 300 255 L 110 250 C 90 240, 95 210, 100 190 Z", fill: bone, stroke: edge, lw: 2)
            s.text("foot bones 足骨", 250, 275, color: hex("#8F7E63"))
            s.ellipse(210, 185, 40 + swelling * 30, 24 + swelling * 20, fill: hex("#D8434B"), opacity: 0.25 * swelling)
            switch g {
            case 0: s.path("M 198 165 L 240 205", stroke: lig, lw: 8, opacity: p[v: "injured"] > 0.5 ? 0.7 : 1, cap: .round)
            case 1:
                s.path("M 198 165 L 215 182", stroke: lig, lw: 8, cap: .round)
                s.path("M 222 188 L 240 205", stroke: lig, lw: 5, cap: .round)
            default:
                s.path("M 198 165 L 210 177", stroke: lig, lw: 8, cap: .round)
                s.path("M 228 193 L 240 205", stroke: lig, lw: 8, cap: .round)
            }
            s.text("ligament 韧带", 250, 160, color: lig)
            s.rect(8, 6, 200, 30, r: 8, fill: .white, stroke: lig, lw: 2)
            let grades = ["Stretched 拉伤 (I)", "Partly torn 部分撕裂 (II)", "Torn through 完全断裂 (III)"]
            s.text(p[v: "injured"] > 0.5 ? grades[min(2, max(0, g))] : "Healthy ligament 韧带正常", 20, 26, size: 11, color: lig, bold: true)
            if p[v: "rice"] > 0.1 { s.text("RICE applied — swelling \(Int((swelling * 100).rounded()))%", 20, 290, size: 11, color: hex("#3F95D6")) }
        },
        sources: ["BJSM / Red Cross acute ankle sprain management (RICE / PEACE & LOVE)"]
    )
}
