import SwiftUI

extension Illustrations {
    /// fraction of the starved zone lost after `minutes` without flow
    static func strokeCore(_ p: Params) -> Double {
        p[v: "clot"] < 0.5 ? 0 : min(1, (min(p[v: "minutes"], p[v: "treated"] > 0.5 ? 60 : 360) / 360).squareRoot())
    }

    static let stroke = Scenario(
        id: "stroke", group: .illness, title: Bilingual("Stroke", "脑卒中（中风）"),
        params: ["clot": 0, "minutes": 0, "treated": 0],
        steps: [
            .watch("Arteries carry oxygen to every part of the brain.", "动脉为大脑各部分输送氧气。", set: ["clot": 0, "minutes": 0, "treated": 0]),
            .watch("Ischaemic stroke: a clot blocks an artery. The brain beyond it is starved of oxygen.", "缺血性卒中：血栓堵塞动脉，其供血区域脑组织缺氧。",
                   set: ["clot": 1, "minutes": 5]),
            .tryIt("Drag the time. About 1.9 million neurons die every minute — the dead core spreads.", "试一试：拖动时间。每分钟约 190 万个神经元死亡——坏死区不断扩大。",
                   TryStep(mode: .scrub([Scrub(param: "minutes", label: "Minutes 分钟", min: 0, max: 360, digits: 0)]), success: { $0[v: "minutes"] >= 120 },
                           ok: Bilingual("Time is brain.", "时间就是大脑。"), demo: ["minutes": 180])),
            .watch("Spot it — 中风120: 1 face uneven, 2 one arm weak, 0 (listen) slurred speech → call 120 now, note the time.",
                   "识别“中风120”：1 看脸不对称，2 查两臂一侧无力，0 聆听言语不清 → 立即拨打 120，记下发病时间。"),
            .tryIt("Compare: clot removed at hospital within an hour vs. no treatment.", "对比：1 小时内在医院溶栓/取栓 vs. 未治疗。", set: ["minutes": 240],
                   TryStep(mode: .compare(param: "treated", options: [("No treatment 未治疗", 0), ("Treated at 1 h 1小时内治疗", 1)]),
                           success: { $0[v: "treated"] > 0.5 }, ok: Bilingual("Fast treatment saves the at-risk area.", "及时治疗可挽救缺血半暗带。"))),
        ],
        draw: { s, p, t in
            let core = strokeCore(p), blocked = p[v: "clot"] > 0.5, treated = p[v: "treated"] > 0.5
            s.ellipse(170, 120, 130, 95, fill: hex("#F4C6CF"), stroke: hex("#C98A97"), lw: 2)
            s.text("brain (side view) 脑", 60, 40, color: hex("#8A3B45"))
            if blocked {
                s.circle(205, 120, 46, fill: treated ? hex("#F7DDE2") : hex("#E5B8C0"))
                s.circle(205, 120, 46 * core, fill: hex("#8C8C94"))
            }
            let branches = ["M 150 250 C 150 200, 160 170, 175 150 C 190 130, 215 118, 240 110",
                            "M 150 250 C 148 190, 130 150, 110 120", "M 150 250 C 160 200, 200 190, 250 170"]
            for (i, d) in branches.enumerated() { s.path(d, stroke: hex("#C8323C"), lw: i == 0 ? 6 : 4, cap: .round) }
            if blocked { s.circle(175, 150, 7, fill: hex("#5A1420")) }
            for i in 0..<5 {
                let u = (t * 0.5 + Double(i) / 5).wrap(1)
                if blocked && i % 3 == 0 && u > 0.45 { continue }
                let x = 150 + (i % 3 == 0 ? u * 90 : i % 3 == 1 ? -u * 40 : u * 100)
                s.circle(x, 250 - u * (i % 3 == 1 ? 130 : 110), 3, fill: .white, opacity: 0.9)
            }
            s.rect(8, 232, 344, 62, r: 8, fill: .white, stroke: core > 0.3 ? hex("#D8434B") : hex("#DDDDDD"), lw: 2)
            s.text(blocked ? "Minutes without blood 缺血 \(Int(p[v: "minutes"].rounded())) min" : "Normal blood supply 供血正常", 20, 252, size: 11)
            if blocked {
                let lost = min(p[v: "minutes"], treated ? 60 : 360) * 1.9
                s.text("Neurons lost 神经元损失 ≈ \(Int(lost.rounded())) million 百万", 20, 270, size: 12, color: hex("#D8434B"), bold: true)
            }
            s.text(treated ? "Clot removed at 60 min — surrounding area saved 周围脑组织被挽救" : blocked ? "grey = dead core · pink = at-risk area 灰：坏死 粉：可挽救区" : "", 20, 286)
        },
        sources: ["Saver 2006 “Time is brain” (1.9 million neurons/min); Chinese Stroke Association 中风120"]
    )

    static func necrosis(_ p: Params) -> Double {
        guard p[v: "clot"] >= 0.5 else { return 0 }
        let m = p[v: "opened"] > 0.5 ? min(p[v: "minutes"], 90) : p[v: "minutes"]
        return m < 20 ? 0 : 1 - exp(-(m - 20) / 140)
    }

    static let heartAttack = Scenario(
        id: "heart-attack", group: .illness, title: Bilingual("Heart attack", "心肌梗死"),
        params: ["clot": 0, "minutes": 0, "opened": 0],
        steps: [
            .watch("Coronary arteries on the heart’s surface feed the heart muscle itself.", "心脏表面的冠状动脉为心肌自身供血。", set: ["clot": 0, "minutes": 0, "opened": 0]),
            .watch("A plaque ruptures, a clot blocks the artery — the muscle below loses its blood.", "斑块破裂，血栓堵塞冠状动脉——下游心肌失去血供。", set: ["clot": 1, "minutes": 10]),
            .tryIt("Drag the time: muscle starts dying after ~20 min and keeps dying for hours.", "试一试：拖动时间：约 20 分钟后心肌开始坏死，并持续数小时。",
                   TryStep(mode: .scrub([Scrub(param: "minutes", label: "Minutes 分钟", min: 0, max: 360, digits: 0)]), success: { $0[v: "minutes"] >= 180 },
                           ok: Bilingual("Time is muscle — lost heart muscle doesn’t grow back.", "时间就是心肌——坏死心肌无法再生。"), demo: ["minutes": 240])),
            .watch("Signs: crushing chest pain over 15 min, spreading to arm, jaw or back; sweating, breathless. Call 120 — don’t drive yourself.",
                   "信号：胸口压榨样疼痛超过 15 分钟，放射至手臂、下颌或后背；出汗、气短。拨打 120，不要自己开车。"),
            .tryIt("Compare: artery reopened with a stent within 90 min vs. left blocked.", "对比：90 分钟内支架开通血管 vs. 持续堵塞。", set: ["minutes": 300],
                   TryStep(mode: .compare(param: "opened", options: [("Blocked 未开通", 0), ("Stent at 90 min 支架", 1)]), success: { $0[v: "opened"] > 0.5 },
                           ok: Bilingual("Opening the artery early saves most of the muscle.", "尽早开通血管可挽救大部分心肌。"))),
        ],
        draw: { s, p, t in
            let dead = necrosis(p), clot = p[v: "clot"] > 0.5, opened = p[v: "opened"] > 0.5
            let blocked = clot && !opened
            let beat = 1 + 0.03 * pow(max(0, sin(t * 7.5)), 4)
            s.group(translate: CGPoint(x: 180 * (1 - beat), y: 150 * (1 - beat)), scale: beat) { g in
                g.path("M 180 60 C 230 20, 320 60, 290 150 C 270 210, 210 250, 180 270 C 150 250, 90 210, 70 150 C 40 60, 130 20, 180 60 Z",
                       fill: hex("#C8323C"), stroke: hex("#8A1F2B"), lw: 3)
                if clot {
                    let zone = "M 150 170 C 160 210, 200 240, 184 262 C 170 250, 130 220, 120 180 Z"
                    g.path(zone, fill: hex("#E88A94"))
                    g.path(zone, fill: hex("#6E6E78"), opacity: dead)
                }
                g.path("M 176 70 C 172 120, 176 180, 184 250", stroke: hex("#F2D060"), lw: 6)
                g.path("M 176 70 C 230 80, 270 110, 280 160", stroke: hex("#F2D060"), lw: 5)
                g.path("M 176 70 C 120 80, 90 110, 84 150", stroke: hex("#F2D060"), lw: 5)
                for i in 0..<3 {
                    let u = (t * 0.4 + Double(i) / 3).wrap(1)
                    if blocked && u > 0.25 { continue }
                    g.circle(172 + u * 12, 70 + u * 180, 3, fill: .white)
                }
                if clot { g.circle(174, 115, 7, fill: opened ? hex("#9AA3AE") : hex("#3D0B12")) }
            }
            s.text(opened ? "stent 支架" : clot ? "clot 血栓" : "", 196, 112, color: .white)
            s.text("coronary arteries 冠状动脉 (yellow)", 20, 30, color: hex("#8A6A1B"))
            s.rect(8, 272, 344, 24, r: 8, fill: .white, stroke: dead > 0.3 ? hex("#D8434B") : hex("#DDDDDD"), lw: 2)
            s.text(clot ? "\(Int(p[v: "minutes"].rounded())) min · heart muscle lost 心肌坏死 \(Int((dead * 100).rounded()))%" : "Normal supply 供血正常",
                   20, 288, size: 11, color: hex("#D8434B"), bold: true)
        },
        sources: ["Reimer & Jennings wavefront of necrosis; AHA/ESC STEMI: door-to-balloon ≤ 90 min"]
    )
}
