import SwiftUI

extension Illustrations {
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
            let floor = 250.0
            let st = Int(p[v: "stage"].rounded()), press = p[v: "press"], taps = p[v: "taps"], rate = p[v: "rate"]
            let dip = press * 14
            let breath = st == 3 ? max(0, sin(t * 2.2)) : 0
            let lift = breath * 6
            let perfusion = st >= 2 && taps > 0 ? min(1, rate / 110) * (rate > 130 ? 0.8 : 1) : 0
            let rateColor = rate == 0 ? hex("#777777") : rate < 100 ? hex("#E39B4B") : rate > 120 ? hex("#D8434B") : hex("#2E9E5B")
            let skin = hex("#F2C9A5"), skinLine = hex("#C9A58A")
            if st >= 1 && st != 3 {
                s.circle(160, 70, 16, fill: skin, stroke: skinLine, lw: 2)
                s.path("M 160 86 L 172 130 L 196 \(floor - 4)", stroke: hex("#6E6E80"), lw: 10, cap: .round)
            }
            s.line(0, floor, 360, floor, stroke: hex("#BBBBBB"), lw: 2)
            s.circle(58, 224, 20, fill: skin, stroke: skinLine, lw: 2)
            s.path("M 80 \(212 - lift) L 122 \(212 - lift) Q 155 \(212 + dip * 2 - lift) 188 \(212 - lift) L 270 214 L 270 246 L 80 246 Z",
                   fill: hex("#8FB3E0"), stroke: hex("#5F87B8"), lw: 2)
            s.rect(270, 224, 82, 20, r: 8, fill: hex("#5B6B8C"))
            s.circle(152, 230, 9 * (1 - 0.35 * press), fill: hex("#C8323C"))
            if st >= 2 && perfusion > 0 {
                for i in 0..<4 {
                    let u = (t * (0.4 + perfusion) + Double(i) / 4).wrap(1)
                    s.circle(152 - u * 90, 230 - sin(u * .pi) * 14, 3, fill: hex("#C8323C"), opacity: perfusion)
                }
            }
            if st >= 1 && st != 3 {
                s.line(158, 100, 153, 150 + dip, stroke: skin, lw: 8, cap: .round)
                s.rect(138, 150 + dip, 30, 14, r: 6, fill: skin, stroke: skinLine)
                s.rect(140, 160 + dip, 28, 12, r: 6, fill: hex("#EBB98F"), stroke: skinLine)
                s.line(155, 120, 155, 140, stroke: hex("#999999"), dash: [3, 3])
                s.text("arms straight 手臂伸直", 176, 150)
                s.text("center of chest 胸部正中", 176, 164)
            }
            if st == 0 {
                s.text("! Tap shoulders, shout 拍肩呼叫", 30, 180, size: 12, color: hex("#D8434B"))
                s.text("Breathing normally? Look ≤ 10 s 观察呼吸", 30, 198, size: 11)
                s.rect(210, 20, 140, 60, r: 10, fill: hex("#FFF3F3"), stroke: hex("#D8434B"), lw: 2)
                s.text("☎ 120 / 911", 280, 46, size: 18, color: hex("#D8434B"), anchor: .middle, bold: true)
                s.text("call · speaker on 开免提", 280, 66, color: hex("#D8434B"), anchor: .middle)
            }
            if st == 3 {
                s.circle(30, 196, 16, fill: skin, stroke: skinLine, lw: 2)
                s.path("M 44 204 Q 52 214 56 214", stroke: hex("#3F95D6"), lw: 3, opacity: breath)
                s.text("2 breaths, 1 s each 人工呼吸2次", 80, 180, size: 11, color: hex("#3F95D6"))
                s.text("tilt head, lift chin — watch the chest rise", 80, 196)
            }
            if st == 4 {
                s.rect(284, 150, 56, 40, r: 6, fill: hex("#2E9E5B"))
                s.text("AED", 312, 176, size: 14, color: .white, anchor: .middle, bold: true)
                s.line(290, 190, 140, 214, stroke: hex("#2E9E5B"), lw: 2)
                s.line(296, 190, 210, 222, stroke: hex("#2E9E5B"), lw: 2)
                s.text("Use the AED as soon as it arrives", 200, 130, size: 11, color: hex("#2E9E5B"))
            }
            if st >= 2 {
                s.rect(8, 6, 200, 46, r: 8, fill: .white, stroke: rateColor, lw: 2)
                s.text("Compressions 按压 \(Int(taps.rounded()))/30", 18, 24, size: 12, color: hex("#333333"))
                s.text(rate > 0 ? "\(Int(rate.rounded())) /min (target 100–120)" : "target 100–120 /min", 18, 42, size: 12, color: rateColor, bold: true)
                s.text("Blood to brain 脑供血", 224, 24)
                s.rect(224, 32, 124, 10, r: 5, fill: hex("#EEEEEE"))
                s.rect(224, 32, 124 * perfusion, 10, r: 5, fill: hex("#C8323C"))
            }
        },
        sources: ["ILCOR 2025 CoSTR / AHA & Red Cross adult BLS: 100–120/min, 5–6 cm, 30:2"]
    )
}
