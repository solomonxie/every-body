import SwiftUI

extension Illustrations {
    /// healing phase fractions from weeks since the break
    static func healing(_ weeks: Double) -> (hematoma: Double, soft: Double, hard: Double, remodel: Double) {
        func c(_ x: Double) -> Double { x.clamped(0, 1) }
        return (c(1 - weeks / 2), c(weeks / 2) * c((6 - weeks) / 3), c((weeks - 2) / 4) * c((14 - weeks) / 6 + 0.3), c((weeks - 6) / 6))
    }

    static let fracture = Scenario(
        id: "fracture-healing", group: .bones, title: Bilingual("Fracture: setting & healing", "骨折：复位与愈合"),
        warning: Bilingual("Setting a bone is a clinician’s job — this shows how it works.", "骨折复位须由医生操作——此处仅演示原理。"),
        params: ["offset": 1, "weeks": 0, "cast": 0],
        steps: [
            .watch("A broken forearm bone: the lower piece has slipped sideways.", "前臂骨折：远端骨块向侧方移位。", set: ["offset": 1, "weeks": 0, "cast": 0]),
            .watch("First aid: keep it still in the position found, support it, cold pack, go to hospital.", "急救：保持原位不动，托扶固定，冷敷，尽快就医。"),
            .tryIt("Setting (reduction): drag the lower piece back into line.", "试一试（复位）：把远端骨块拖回对齐。",
                   TryStep(mode: .drag, success: { $0[v: "offset"] < 0.08 },
                           ok: Bilingual("Ends aligned — now they must be held still.", "断端对齐——接下来需要固定。"), demo: ["offset": 0])),
            .watch("A cast holds the ends together while the bone heals.", "石膏固定，使断端在愈合期间保持对位。", set: ["offset": 0, "cast": 1]),
            .tryIt("Drag through the weeks: clot → soft callus → hard callus → remodelled bone.", "试一试：拖动周数：血肿 → 软骨痂 → 硬骨痂 → 塑形。",
                   TryStep(mode: .scrub([Scrub(param: "weeks", label: "Weeks 周", min: 0, max: 12, digits: 1)]), success: { healing($0[v: "weeks"]).remodel > 0.5 },
                           ok: Bilingual("Adult forearm: ~6–8 weeks in a cast, remodelling for months.", "成人前臂：石膏约 6–8 周，塑形持续数月。"), demo: ["weeks": 12])),
        ],
        draw: { s, p, _ in
            let bone = hex("#E9E2CF"), edge = hex("#B8A58A"), breakY = 150.0
            let dx = p[v: "offset"] * 40
            let h = healing(p[v: "weeks"])
            let aligned = p[v: "offset"] < 0.08
            let bulge = 18 * (h.soft + h.hard) * (1 - h.remodel * 0.8)
            s.rect(160, 20, 40, breakY - 20, r: 14, fill: bone, stroke: edge, lw: 2)
            s.rect(160 + dx, breakY + 4, 40, 130, r: 14, fill: bone, stroke: edge, lw: 2)
            s.path("M 160 \(breakY) l 10 6 l 10 -6 l 10 6 l 10 -6", stroke: hex("#8F7E63"), lw: 2)
            let cx = 180 + dx / 2
            if h.hematoma > 0.02 { s.ellipse(cx, breakY + 2, 40, 22, fill: hex("#B3263A"), opacity: 0.6 * h.hematoma) }
            if h.soft > 0.02 { s.ellipse(cx, breakY + 2, 20 + bulge, 20, fill: hex("#8FB3E0"), opacity: 0.7 * h.soft) }
            if h.hard > 0.02 { s.ellipse(cx, breakY + 2, 20 + bulge, 18, fill: bone, stroke: edge, opacity: h.hard) }
            if p[v: "cast"] > 0.5 { s.rect(138, 60, 84 + dx, 180, r: 20, fill: .white, stroke: hex("#CCCCCC"), lw: 2, opacity: 0.55) }
            if p[v: "offset"] > 0.02 { s.text("← displaced 移位", 210 + dx, breakY + 60, color: hex("#D8434B")) }
            let status = aligned ? hex("#2E9E5B") : hex("#D8434B")
            s.rect(8, 6, 130, 30, r: 8, fill: .white, stroke: status, lw: 2)
            s.text(aligned ? "Aligned 对位良好" : "Displaced 移位", 73, 26, size: 11, color: status, anchor: .middle, bold: true)
            s.text(String(format: "Week 第 %.1f 周", p[v: "weeks"]), 20, 268, size: 11)
            s.text(h.hematoma > 0.5 ? "Blood clot 血肿" : h.soft > 0.5 ? "Soft callus 软骨痂" : h.remodel > 0.5 ? "Remodelling 塑形" : "Hard callus 硬骨痂", 20, 284)
        },
        onDrag: { point, _ in ["offset": ((point.x - 180) / 40).clamped(0, 1)] },
        sources: ["Standard fracture-healing phases: haematoma, soft callus, hard callus, remodelling"]
    )
}
