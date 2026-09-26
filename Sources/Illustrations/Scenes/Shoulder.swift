import SwiftUI

extension Illustrations {
    /// reduction path: quadratic curve from in-place (u = 0) to dislocated (u = 1)
    static func humeralHead(_ u: Double) -> CGPoint {
        let a = (1 - u) * (1 - u), b = 2 * u * (1 - u), c = u * u
        return CGPoint(x: a * 158 + b * 222 + c * 190, y: a * 120 + b * 138 + c * 196)
    }

    static let shoulder = Scenario(
        id: "shoulder-dislocation", group: .bones, title: Bilingual("Shoulder dislocation", "肩关节脱位与复位"),
        warning: Bilingual("This shows what a clinician does — don’t try it on someone yourself.", "此演示为医生操作——请勿自行复位。"),
        params: ["disloc": 0, "showPath": 0, "sling": 0],
        steps: [
            .watch("The shoulder is a ball in a shallow socket — huge range of motion, but easy to dislocate.",
                   "肩关节是“球”在浅“窝”里——活动范围大，但容易脱位。", set: ["disloc": 0, "showPath": 0, "sling": 0]),
            .watch("A fall on an outstretched arm levers the ball forward and down, out of the socket.",
                   "跌倒时手臂伸直撑地，肱骨头被撬向前下方，脱出关节盂。", set: ["disloc": 1]),
            .watch("First aid: support the arm in the position it’s in, ice, and go to A&E. Don’t pull it back.",
                   "急救：保持手臂现有姿势并托住，冷敷，尽快就医。不要强行拉回。"),
            .tryIt("How a clinician reduces it: drag the ball along the path back into the socket.",
                   "医生如何复位：沿路径拖动肱骨头，使其回到关节盂内。", set: ["showPath": 1],
                   TryStep(mode: .drag, success: { $0[v: "disloc"] < 0.08 },
                           ok: Bilingual("Back in the socket — reduced.", "回到关节盂——复位成功。"), demo: ["disloc": 0])),
            .watch("A sling rests the joint for about 3 weeks while the stretched ligaments heal, then physio.",
                   "用吊带固定约 3 周，让拉伤的韧带愈合，之后进行康复训练。", set: ["disloc": 0, "showPath": 0, "sling": 1]),
        ],
        draw: { s, p, _ in
            let head = humeralHead(p[v: "disloc"])
            let inPlace = p[v: "disloc"] < 0.08
            let shaft = CGPoint(x: head.x + 60, y: head.y + 150)
            let bone = hex("#8F7E63")
            s.path("M 60 40 L 130 70 L 128 190 L 70 250", stroke: hex("#D9CBB0"), lw: 22, cap: .round)
            s.text("shoulder blade 肩胛骨", 20, 30, color: bone)
            s.path("M 146 84 A 36 36 0 0 0 146 156", stroke: bone, lw: 8)
            s.text("socket 关节盂", 86, 172, color: bone)
            s.path("M 118 60 Q 170 40 205 70", stroke: hex("#D9CBB0"), lw: 12, cap: .round)
            s.text("collarbone 锁骨", 180, 52, color: bone)
            if p[v: "showPath"] > 0.5 {
                var guide = Path()
                for i in 0...20 {
                    let pt = humeralHead(Double(i) / 20)
                    if i == 0 { guide.move(to: pt) } else { guide.addLine(to: pt) }
                }
                s.shape(guide, stroke: hex("#3F95D6"), lw: 2, dash: [5, 4])
                s.shape(Path(ellipseIn: CGRect(x: 128, y: 90, width: 60, height: 60)), stroke: hex("#2E9E5B"), lw: 2, dash: [4, 4])
            }
            s.line(head.x, head.y, shaft.x, shaft.y, stroke: hex("#E4DECB"), lw: 26, cap: .round)
            s.circle(head.x, head.y, 30, fill: inPlace ? hex("#E4DECB") : hex("#F1D08A"), stroke: inPlace ? bone : hex("#D8434B"), lw: 3)
            s.text("upper arm 肱骨", shaft.x - 6, shaft.y - 30, color: bone, anchor: .end)
            if p[v: "sling"] > 0.5 {
                s.path("M 110 60 Q 250 150 \(shaft.x + 10) \(shaft.y)", stroke: hex("#3F95D6"), lw: 16, opacity: 0.7)
            }
            let status = inPlace ? hex("#2E9E5B") : hex("#D8434B")
            s.rect(220, 6, 132, 30, r: 8, fill: .white, stroke: status, lw: 2)
            s.text(inPlace ? "In place 复位" : "Dislocated 脱位", 286, 26, size: 12, color: status, anchor: .middle, bold: true)
        },
        onDrag: { point, _ in
            let best = (0...60).map { Double($0) / 60 }.min { a, b in
                let pa = humeralHead(a), pb = humeralHead(b)
                return hypot(pa.x - point.x, pa.y - point.y) < hypot(pb.x - point.x, pb.y - point.y)
            } ?? 0
            return ["disloc": best]
        },
        sources: ["Orthopaedic references on anterior shoulder dislocation (≈95% anterior)"]
    )
}
