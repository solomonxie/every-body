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
            let label = hex("#8A3B45")
            // left hemisphere, lateral view, face to the left
            let cortex = "M 62 138 C 58 88, 108 48, 178 45 C 248 42, 302 78, 306 132 C 308 160, 296 178, 278 186 C 262 190, 246 188, 232 184 "
                + "C 214 200, 170 210, 128 200 C 104 194, 84 184, 74 170 C 66 160, 63 150, 62 138 Z"
            s.ellipse(262, 204, 40, 21, fill: hex("#E7B3BE"), stroke: hex("#C98A97"), lw: 1.5)                       // cerebellum
            for k in 0..<4 { s.path("M \(228 + Double(k) * 4) \(196 + Double(k) * 5) q 34 -6 68 4", stroke: hex("#C98A97"), lw: 0.8) }
            s.path("M 214 190 C 216 215, 212 240, 206 268", stroke: hex("#E7B3BE"), lw: 18, cap: .round)              // brainstem
            s.path(cortex, fill: hex("#F4C6CF"), stroke: hex("#C98A97"), lw: 2)
            s.path("M 104 176 C 140 158, 186 146, 236 132", stroke: hex("#B97A88"), lw: 2.5)                           // lateral (Sylvian) fissure
            s.path("M 188 47 C 182 80, 176 110, 170 150", stroke: hex("#B97A88"), lw: 2)                               // central sulcus
            s.path("M 272 72 C 268 100, 272 130, 284 150", stroke: hex("#D29AA6"), lw: 1.2, dash: [3, 3])            // parieto-occipital
            for (name, x, y) in [("Frontal 额叶", 88.0, 108.0), ("Parietal 顶叶", 212, 82), ("Temporal 颞叶", 140, 192), ("Occipital 枕叶", 262, 150)] {
                s.text(name, x, y, size: 9, color: label)
            }
            s.text("cerebellum 小脑", 238, 232, size: 8, color: label)
            s.text("brainstem 脑干", 222, 262, size: 8, color: label)
            if blocked {
                // MCA territory around the fissure: at-risk area, dead core growing from its centre
                s.ellipse(178, 140, 78, 50, fill: treated ? hex("#F7DDE2") : hex("#E5B0BB"), opacity: 0.9)
                s.ellipse(178, 140, 78 * core, 50 * core, fill: hex("#8C8C94"))
            }
            // internal carotid rising to the middle cerebral artery, which fans over the lateral surface
            let artery = hex("#C8323C")
            s.path("M 120 280 C 118 250, 116 215, 118 188", stroke: artery, lw: 6, cap: .round)
            s.path("M 118 188 C 140 175, 160 168, 178 162", stroke: artery, lw: 5, cap: .round)
            let branches = ["M 178 162 C 170 130, 150 100, 130 78", "M 178 162 C 185 128, 196 100, 205 70", "M 178 162 C 205 145, 240 125, 268 110",
                            "M 178 162 C 210 162, 240 160, 262 168", "M 178 162 C 160 172, 145 182, 132 188"]
            for (i, d) in branches.enumerated() {
                s.path(d, stroke: artery, lw: 3, opacity: blocked && i < 4 ? 0.35 : 1, cap: .round)
            }
            if blocked { s.circle(150, 171, 6, fill: hex("#5A1420"), stroke: .white, lw: 1) }
            for i in 0..<5 {
                let u = (t * 0.5 + Double(i) / 5).wrap(1)
                if blocked && u > 0.55 { continue }
                s.circle(120 - 2 * u, 280 - u * 92, 2.5, fill: .white, opacity: 0.9)
            }
            s.text("MCA 大脑中动脉", 268, 104, size: 9, color: artery)
            s.text("internal carotid 颈内动脉", 126, 268, size: 8, color: artery)
            s.rect(8, 6, 344, 36, r: 8, fill: .white, stroke: core > 0.3 ? hex("#D8434B") : hex("#DDDDDD"), lw: 2)
            if blocked {
                let lost = min(p[v: "minutes"], treated ? 60 : 360) * 1.9
                s.text("\(Int(p[v: "minutes"].rounded())) min without blood 缺血 · neurons lost ≈ \(Int(lost.rounded())) million 百万", 18, 22, size: 10, color: hex("#D8434B"), bold: true)
                s.text(treated ? "Clot removed at 60 min — the at-risk area is saved 可挽救区得救" : "grey = dead core 坏死核心 · pink = at-risk area 缺血半暗带", 18, 36, size: 9)
            } else {
                s.text("Normal blood supply 供血正常 — the MCA feeds the side of the brain", 18, 28, size: 10)
            }
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
            let beat = 1 + 0.025 * pow(max(0, sin(t * 7.5)), 4)
            let label = hex("#5A1420")
            // anterior view: patient's right on the left; apex points down to the patient's left
            s.group(translate: CGPoint(x: 185 * (1 - beat), y: 165 * (1 - beat)), scale: beat) { g in
                // great vessels behind the heart
                g.path("M 118 112 L 118 40", stroke: hex("#5A6FB0"), lw: 22, cap: .round)                        // superior vena cava
                g.path("M 150 110 C 148 70, 150 45, 175 38 C 200 32, 222 42, 226 62 L 226 95", stroke: hex("#C8323C"), lw: 24, cap: .round) // aorta
                for (x, y) in [(165.0, 38.0), (183, 33), (201, 35)] { g.line(x, y, x - 4, y - 26, stroke: hex("#C8323C"), lw: 8, cap: .round) }
                g.path("M 188 118 C 190 95, 200 80, 215 72 L 250 66", stroke: hex("#5A6FB0"), lw: 20, cap: .round)   // pulmonary trunk
                // chambers: right atrium (left of image), right ventricle (front), left ventricle (left border + apex)
                g.path("M 112 108 C 88 120, 84 175, 110 205 C 120 214, 132 214, 140 205 C 130 175, 132 135, 142 112 Z", fill: hex("#B8364A"), stroke: hex("#7A1F2B"), lw: 2)
                g.path("M 140 112 C 132 140, 130 180, 140 205 C 170 240, 215 262, 255 258 C 240 225, 222 170, 206 120 C 185 108, 160 106, 140 112 Z",
                       fill: hex("#C8323C"), stroke: hex("#7A1F2B"), lw: 2)
                g.path("M 206 120 C 222 170, 240 225, 255 258 C 285 250, 296 220, 290 185 C 282 145, 258 118, 230 108 C 222 110, 212 114, 206 120 Z",
                       fill: hex("#B02A38"), stroke: hex("#7A1F2B"), lw: 2)
                g.path("M 226 100 C 245 92, 262 100, 262 112 C 250 118, 238 116, 230 110 Z", fill: hex("#A8283A"), stroke: hex("#7A1F2B"), lw: 1.5) // left auricle
                if clot {
                    // territory of the LAD: front wall of the left ventricle and the apex
                    let zone = "M 208 135 C 222 175, 238 225, 255 258 C 280 250, 290 222, 285 190 C 272 170, 245 150, 208 135 Z"
                    g.path(zone, fill: hex("#E88A94"))
                    g.path(zone, fill: hex("#6E6E78"), opacity: dead)
                }
                // coronary arteries on the surface
                let coronary = hex("#F2D060")
                g.path("M 150 118 C 132 128, 124 160, 128 190 C 132 205, 140 214, 150 222", stroke: coronary, lw: 5, cap: .round)   // right coronary
                g.path("M 182 112 C 196 116, 204 118, 208 124", stroke: coronary, lw: 6, cap: .round)                               // left main
                g.path("M 208 124 C 220 165, 236 215, 252 252", stroke: coronary, lw: 5, cap: .round)                                // LAD
                g.path("M 216 150 C 235 158, 250 172, 262 190", stroke: coronary, lw: 3, cap: .round)                                // diagonal
                g.path("M 208 124 C 232 114, 256 122, 276 150", stroke: coronary, lw: 4.5, cap: .round)                              // circumflex
                for i in 0..<4 {
                    let u = (t * 0.4 + Double(i) / 4).wrap(1)
                    if blocked && u > 0.22 { continue }
                    let a = pow(1 - u, 3), b = 3 * u * pow(1 - u, 2), c = 3 * u * u * (1 - u), d = pow(u, 3)
                    g.circle(a * 208 + b * 220 + c * 236 + d * 252, a * 124 + b * 165 + c * 215 + d * 252, 2.5, fill: .white)
                }
                if clot { g.circle(213, 140, 6, fill: opened ? hex("#9AA3AE") : hex("#3D0B12"), stroke: .white, lw: 1) }
            }
            s.text("aorta 主动脉", 232, 58, size: 9, color: label)
            s.text("pulmonary trunk 肺动脉", 256, 80, size: 9, color: hex("#3A4A80"))
            s.text("RA 右心房", 40, 150, size: 9, color: label)
            s.text("RV 右心室", 150, 185, size: 9, color: .white)
            s.text("LV 左心室", 276, 220, size: 9, color: label)
            s.text("LAD 前降支", 262, 130, size: 9, color: hex("#8A6A1B"))
            s.text("RCA 右冠", 58, 200, size: 9, color: hex("#8A6A1B"))
            s.text(opened ? "stent 支架" : clot ? "clot 血栓" : "", 150, 145, size: 10, color: label, bold: true)
            s.rect(8, 272, 344, 24, r: 8, fill: .white, stroke: dead > 0.3 ? hex("#D8434B") : hex("#DDDDDD"), lw: 2)
            s.text(clot ? "\(Int(p[v: "minutes"].rounded())) min · heart muscle lost 心肌坏死 \(Int((dead * 100).rounded()))%" : "Normal supply 供血正常",
                   20, 288, size: 11, color: hex("#D8434B"), bold: true)
        },
        sources: ["Reimer & Jennings wavefront of necrosis; AHA/ESC STEMI: door-to-balloon ≤ 90 min"]
    )
}
