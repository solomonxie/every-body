import SwiftUI

extension Illustrations {
    static func cpr(for p: Profile) -> Scenario { cpr }

    static let cpr = Scenario(
        id: "cpr", group: .firstAid, title: Bilingual("CPR", "心肺复苏"),
        params: ["stage": 0, "press": 0, "taps": 0, "rate": 0],
        steps: [
            .watch("Someone collapses. Tap and shout. Not breathing normally? Call 120/911 on speaker and start CPR.",
                   "有人倒地：拍肩呼叫。无正常呼吸？立即拨打 120（开免提），开始心肺复苏。", set: ["stage": 0]),
            .watch("Heel of the hand on the center of the chest, other hand on top. Arms straight, shoulders over the hands.",
                   "掌根放在胸部正中，另一手叠放其上。手臂伸直，肩在手的正上方。", set: ["stage": 1]),
            .tryIt("Your turn: tap the button for each compression — 30 of them, 100–120 per minute, 5–6 cm deep.",
                   "试一试：每按一次点击按钮——共 30 次，频率每分钟 100–120 次，深度 5–6 厘米。", set: ["stage": 2, "taps": 0, "rate": 0],
                   TryStep(mode: .rhythm(target: 30, minRate: 100, maxRate: 120),
                           success: { $0[v: "taps"] >= 30 && (100...120).contains($0[v: "rate"]) },
                           ok: Bilingual("30 at the right pace — that keeps blood reaching the brain.", "30 次，节奏正确——保证大脑供血。"))),
            .watch("If trained, give 2 rescue breaths. If not, keep doing compressions only.", "受过培训可给予 2 次人工呼吸；未受培训则持续胸外按压。", set: ["stage": 3]),
            .watch("Keep going 30:2 without pausing until help or an AED arrives. Switch the AED on and follow its voice.",
                   "按 30:2 持续进行，直到急救人员或 AED 到达。打开 AED，按语音提示操作。", set: ["stage": 4]),
        ],
        draw: { s, p, t in
            let floor = 262.0, h = 200.0
            let st = Int(p[v: "stage"].rounded()), press = p[v: "press"], taps = p[v: "taps"], rate = p[v: "rate"]
            let breath = st == 3 ? max(0, sin(t * 2.2)) : 0
            let perfusion = st >= 2 && taps > 0 ? min(1, rate / 110) * (rate > 130 ? 0.8 : 1) : 0
            let rateColor = rate == 0 ? hex("#777777") : rate < 100 ? hex("#E39B4B") : rate > 120 ? hex("#D8434B") : hex("#2E9E5B")

            // patient supine, head left; lower half of the breastbone is where the hands go
            let patientHip = CGPoint(x: 250, y: floor - 0.07 * h)
            let sternum = CGPoint(x: patientHip.x - 0.21 * h, y: patientHip.y - 0.078 * h - breath * 4)
            let patient = Person(h: h, shirt: hex("#DCE6F2"), shirtLine: hex("#9FB3CC"), shoulder: 0, elbow: 0)

            // rescuer kneels on the far side, facing us: shoulders straight over the hands
            let rescuer = FrontRescuer(h: h)
            var side = Person(h: h, lean: 80, shoulder: -10, elbow: 10, hip: 0, knee: 90)
            if st == 3 {
                side.draw(&s, at: CGPoint(x: 79, y: floor - 0.245 * h))
            }
            s.line(0, floor, 360, floor, stroke: hex("#BBBBBB"), lw: 2)
            patient.draw(&s, at: patientHip, rotation: -90)
            if st == 0 {
                rescuer.draw(&s, hands: CGPoint(x: patientHip.x - 0.3 * h, y: patientHip.y - 0.07 * h), spread: 0.06 * h)
            } else if st != 3 {
                rescuer.draw(&s, hands: CGPoint(x: sternum.x, y: sternum.y + press * 6), drop: press * 6)
            }
            if st == 3 {
                s.path("M \(patientHip.x - 0.43 * h + 16) \(patientHip.y - 0.1 * h) q 8 -6 16 -2", stroke: hex("#3F95D6"), lw: 2.5, opacity: breath)
                s.text("head tilt, chin lift 仰头抬颏 · 2 breaths 人工呼吸2次", 20, 150, size: 11, color: hex("#3F95D6"))
                s.text("watch the chest rise 观察胸廓起伏", 20, 166, size: 10)
            }
            if st == 0 {
                s.text("“Are you OK?” — tap shoulders, shout 拍肩呼叫", 12, 110, size: 11, color: hex("#D8434B"))
                s.text("Breathing normally? Look ≤ 10 s 观察呼吸", 12, 126, size: 10)
                s.rect(210, 20, 140, 60, r: 10, fill: hex("#FFF3F3"), stroke: hex("#D8434B"), lw: 2)
                s.text("☎ 120 / 911", 280, 46, size: 18, color: hex("#D8434B"), anchor: .middle, bold: true)
                s.text("call · speaker on 开免提", 280, 66, color: hex("#D8434B"), anchor: .middle)
            }
            if st == 4 {
                // AED pads: below the right collarbone, and on the left side below the armpit
                let pad1 = CGPoint(x: patientHip.x - 0.3 * h, y: patientHip.y - 0.075 * h)
                let pad2 = CGPoint(x: patientHip.x - 0.19 * h, y: patientHip.y - 0.03 * h)
                s.rect(300, 160, 50, 38, r: 6, fill: hex("#2E9E5B"))
                s.text("AED", 325, 184, size: 13, color: .white, anchor: .middle, bold: true)
                for pad in [pad1, pad2] {
                    s.rect(pad.x - 8, pad.y - 5, 16, 10, r: 2, fill: .white, stroke: hex("#2E9E5B"), lw: 1.5)
                    s.path("M \(pad.x) \(pad.y) Q \((pad.x + 300) / 2) \(pad.y - 30) 300 180", stroke: hex("#2E9E5B"), lw: 1.5)
                }
                s.text("pads: below right collarbone · left side under the armpit", 12, 110, size: 10, color: hex("#2E9E5B"))
                s.text("电极片：右锁骨下 · 左腋下", 12, 124, size: 10, color: hex("#2E9E5B"))
            }
            if st >= 2 && st != 3 {
                // chest cross-section: breastbone pushes the heart against the spine
                let c = CGPoint(x: 300, y: 95), depth = press * 10
                s.rect(245, 50, 110, 90, r: 8, fill: .white, stroke: hex("#DDDDDD"))
                s.ellipse(c.x, c.y, 45, 30, fill: hex("#F7E3D6"), stroke: hex("#C9A58A"))
                s.ellipse(c.x - 24, c.y + 2, 14, 18 - depth * 0.3, fill: hex("#F2C4CC"))
                s.ellipse(c.x + 24, c.y + 2, 14, 18 - depth * 0.3, fill: hex("#F2C4CC"))
                s.ellipse(c.x, c.y + 4 + depth * 0.3, 12, 11 - depth * 0.45, fill: hex("#C8323C"))
                s.rect(c.x - 7, c.y - 30 + depth, 14, 6, r: 2, fill: hex("#E9E2CF"), stroke: hex("#B8A58A"))
                s.circle(c.x, c.y + 26, 6, fill: hex("#E9E2CF"), stroke: hex("#B8A58A"))
                s.text("breastbone 胸骨", 250, 62, size: 8)
                s.text("heart 心", c.x + 14, c.y + 8, size: 8, color: hex("#C8323C"))
                s.text("spine 脊柱", 250, 134, size: 8)
                s.text("5–6 cm", 318, 62, size: 8, color: hex("#D8434B"), bold: true)
            }
            if st == 2 {
                s.rect(8, 6, 200, 46, r: 8, fill: .white, stroke: rateColor, lw: 2)
                s.text("Compressions 按压 \(Int(taps.rounded()))/30", 18, 24, size: 12, color: hex("#333333"))
                s.text(rate > 0 ? "\(Int(rate.rounded())) /min (target 100–120)" : "target 100–120 /min", 18, 42, size: 12, color: rateColor, bold: true)
                s.text("Blood to brain 脑供血", 224, 18, size: 9)
                s.rect(224, 24, 124, 8, r: 4, fill: hex("#EEEEEE"))
                s.rect(224, 24, 124 * perfusion, 8, r: 4, fill: hex("#C8323C"))
            }
        },
        sources: ["ILCOR 2025 CoSTR / AHA & Red Cross adult BLS: 100–120/min, 5–6 cm, 30:2"]
    )
}
