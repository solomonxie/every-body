import SwiftUI

extension Illustrations {
    /// reduction path: quadratic curve from in-place (u = 0) to dislocated (u = 1)
    static func humeralHead(_ u: Double) -> CGPoint {
        let a = (1 - u) * (1 - u), b = 2 * u * (1 - u), c = u * u
        return CGPoint(x: a * 142 + b * 128 + c * 182, y: a * 128 + b * 205 + c * 168)
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
            // right shoulder, front view: the arm is on the left of the picture, the chest on the right
            let head = humeralHead(p[v: "disloc"])
            let inPlace = p[v: "disloc"] < 0.08
            let shaft = CGPoint(x: head.x - 38 + p[v: "disloc"] * 12, y: head.y + 160)
            let bone = hex("#E9E2CF"), edge = hex("#B8A58A"), label = hex("#8F7E63")
            for k in 0..<4 { s.path("M \(240 + Double(k) * 8) \(130 + Double(k) * 38) C 280 \(120 + Double(k) * 38), 320 \(125 + Double(k) * 38), 350 \(140 + Double(k) * 38)", stroke: hex("#E6DDD0"), lw: 7, cap: .round) }
            // scapula behind the ribs, glenoid facing out to the arm
            s.path("M 168 100 C 205 104, 236 140, 248 205 C 244 236, 222 246, 204 230 C 190 186, 178 148, 166 134 Z", fill: hex("#EFE9DA"), stroke: edge, lw: 1.5)
            s.path("M 166 104 C 152 114, 151 142, 165 152", stroke: hex("#9C8A6A"), lw: 7, cap: .round)
            s.path("M 186 82 C 168 72, 146 70, 128 80 C 124 91, 138 95, 150 90", fill: bone, stroke: edge, lw: 1.5)          // acromion
            s.path("M 190 100 C 180 92, 164 100, 158 114 C 164 118, 172 110, 180 110 Z", fill: bone, stroke: edge, lw: 1.5)   // coracoid
            s.path("M 320 100 C 280 90, 232 70, 192 78 C 168 82, 150 78, 136 74", stroke: bone, lw: 13, cap: .round)          // clavicle
            s.path("M 320 100 C 280 90, 232 70, 192 78 C 168 82, 150 78, 136 74", stroke: edge, lw: 1)
            if p[v: "showPath"] > 0.5 {
                var guide = Path()
                for i in 0...20 {
                    let pt = humeralHead(Double(i) / 20)
                    if i == 0 { guide.move(to: pt) } else { guide.addLine(to: pt) }
                }
                s.shape(guide, stroke: hex("#3F95D6"), lw: 2, dash: [5, 4])
                s.shape(Path(ellipseIn: CGRect(x: 118, y: 104, width: 48, height: 48)), stroke: hex("#2E9E5B"), lw: 2, dash: [4, 4])
            }
            s.line(head.x, head.y, shaft.x, shaft.y, stroke: bone, lw: 24, cap: .round)
            s.line(head.x, head.y, shaft.x, shaft.y, stroke: edge, lw: 0.8)
            s.circle(head.x - 14, head.y + 6, 9, fill: bone, stroke: edge)                                                  // greater tubercle
            s.circle(head.x, head.y, 24, fill: inPlace ? bone : hex("#F1D08A"), stroke: inPlace ? edge : hex("#D8434B"), lw: 2.5)
            s.text("clavicle 锁骨", 250, 70, size: 9, color: label)
            s.text("acromion 肩峰", 88, 64, size: 9, color: label)
            s.text("coracoid 喙突", 196, 104, size: 9, color: label)
            s.text("socket 关节盂", 176, 140, size: 9, color: label)
            s.text("humerus 肱骨", shaft.x + 16, shaft.y - 20, size: 9, color: label)
            if !inPlace && p[v: "disloc"] > 0.9 { s.text("below the coracoid 喙突下", 208, 186, size: 9, color: hex("#D8434B")) }
            if p[v: "sling"] > 0.5 {
                s.path("M 300 40 L \(shaft.x + 14) \(shaft.y - 40)", stroke: hex("#3F95D6"), lw: 10, opacity: 0.6, cap: .round)
                s.rect(shaft.x - 26, shaft.y - 56, 52, 30, r: 10, fill: hex("#3F95D6"), opacity: 0.55)
                s.text("sling 吊带", shaft.x + 30, shaft.y - 36, size: 9, color: hex("#3F95D6"))
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
        sources: ["Anterior (subcoracoid) dislocation ≈ 95% of shoulder dislocations; reduction by traction–external rotation"]
    )
}
