import SwiftUI

/// Organs for the health-topic scenes, each drawn in its own unit frame (place with `group(translate:scale:)`).
extension Sketch {
    /// Upper-abdomen organs, front view (image left = person's right). Frame: x −50…50, y 0 (diaphragm) … 150 (pelvis).
    /// `pancreasOff` greys the pancreas (type 1).
    mutating func abdomen(pancreasOff: Bool = false, pancreasGlow: Double = 0, colon: Bool = true) {
        let edge = hex("#9E5A52")
        if colon {
            path("M -38 132 L -40 88 C -40 80 -34 78 -26 80 C -10 84 10 84 26 80 C 34 78 40 80 40 88 L 40 128 C 40 136 34 140 26 140",
                 stroke: hex("#D9957F"), lw: 11, cap: .round)
            for y in stride(from: 92.0, through: 128, by: 9) {
                for x in [-38.0, 38] { line(x - 5, y, x + 5, y, stroke: hex("#B97A66"), lw: 0.8) }
            }
            for x in stride(from: -24.0, through: 24, by: 10) { line(x, 77, x, 87, stroke: hex("#B97A66"), lw: 0.8) }
            // small intestine loops
            let loop = "M -26 96 C -18 90 -8 92 -6 100 C -4 108 8 108 10 100 C 12 92 24 92 26 100 C 28 108 18 112 12 114 "
                + "C 4 116 -4 112 -12 116 C -20 120 -26 124 -20 130 C -14 136 -2 134 6 130 C 14 126 22 128 24 134"
            path(loop, stroke: hex("#C98472"), lw: 9, cap: .round)
            path(loop, stroke: hex("#EDB4A0"), lw: 6.5, cap: .round)
        }
        // stomach
        let stomach = "M 10 10 C 14 2 30 0 38 10 C 46 22 44 44 36 56 C 28 68 12 72 0 68 C -8 66 -12 62 -12 56 L -6 54 "
            + "C 2 58 12 56 18 48 C 24 40 20 26 12 20 Z"
        shade(stomach, hex("#F2B8BE"), hex("#D98590"), stroke: edge, lw: 1)
        path("M 20 16 C 30 22 34 36 28 50 M 26 12 C 38 22 40 40 32 56", stroke: hex("#C9707C"), lw: 0.7, opacity: 0.6)
        // duodenum and pancreas
        path("M -12 58 C -22 58 -24 70 -20 78 C -16 84 -6 84 0 80", stroke: hex("#E0A58C"), lw: 5, cap: .round)
        let panc = "M -16 70 C -18 62 -8 60 0 64 C 10 66 22 60 34 58 C 42 57 46 62 40 66 C 30 70 16 72 4 74 C -6 78 -14 76 -16 70 Z"
        if pancreasGlow > 0.01 { glow(10, 68, 30, hex("#F2C14E"), opacity: 0.5 * pancreasGlow) }
        shade(panc, pancreasOff ? hex("#DCD6CC") : hex("#F6CD7A"), pancreasOff ? hex("#B8B0A4") : hex("#DDA24A"), stroke: pancreasOff ? hex("#9A9288") : hex("#B07C2E"), lw: 1)
        for x in stride(from: -8.0, through: 34, by: 6) { circle(x, 67 - (x > 0 ? x * 0.12 : 0), 1.1, fill: pancreasOff ? hex("#C8C0B4") : hex("#E9B25A")) }
        // liver with gallbladder
        let liver = "M -48 16 C -46 6 -30 2 -12 4 C 6 5 22 8 32 14 C 36 17 34 22 28 24 C 16 28 4 32 -6 40 C -18 50 -34 56 -44 50 C -50 44 -50 28 -48 16 Z"
        shade(liver, hex("#C06A5E"), hex("#8C3F3A"), stroke: hex("#6E2E2A"), lw: 1)
        path("M -6 6 C -8 16 -8 26 -6 38", stroke: hex("#7A3530"), lw: 0.8, opacity: 0.7)
        ellipse(-16, 44, 5, 7, fill: hex("#7FA35A"), stroke: hex("#5A7A3A"), lw: 0.8)
    }

    /// Heart, front (anterior) view. Frame ≈ 0…190 × 0…230; apex at (150, 212). `zone` 0…1 tints the LAD territory,
    /// `dead` greys it; `clot` puts a clot high in the LAD, `stent` a stent there instead.
    mutating func heartFront(zone: Double = 0, dead: Double = 0, clot: Bool = false, stent: Bool = false, flow: Double = 1, t: Double = 0) {
        let edge = hex("#6E1E28")
        // great vessels behind
        shade("M 44 -4 L 66 -4 L 66 78 L 44 84 Z", hex("#6F86C8"), hex("#46609F"), stroke: hex("#34497E"), lw: 1)                    // superior vena cava
        for (x, lean) in [(94.0, -4.0), (110, 0), (126, 4)] {
            shade("M \(x - 5) 16 L \(x - 5 + lean) -8 L \(x + 5 + lean) -8 L \(x + 5) 16 Z", hex("#E0606A"), hex("#B02A36"), stroke: edge, lw: 1)
        }
        shade("M 72 86 C 70 50 74 20 96 10 C 116 2 140 6 150 22 C 156 32 156 44 152 56 L 138 56 C 140 40 132 26 116 26 C 98 26 92 44 92 86 Z",
              hex("#E0606A"), hex("#A82834"), stroke: edge, lw: 1.2)                                                                    // aorta, arch
        // chambers
        let ra = "M 30 96 C 22 76 36 62 56 66 C 70 68 78 80 76 96 C 76 120 70 150 58 166 C 44 170 30 160 26 140 C 22 124 26 108 30 96 Z"
        shade(ra, hex("#C9505C"), hex("#9C2F3C"), stroke: edge, lw: 1.2)
        shade("M 30 96 C 20 88 22 74 34 72 C 40 72 44 78 42 86 Z", hex("#D0606A"), hex("#A8343F"), stroke: edge, lw: 1)               // right auricle
        let lv = "M 132 84 C 156 80 176 100 180 128 C 184 160 172 196 150 214 C 140 212 128 200 120 186 C 128 150 132 116 132 84 Z"
        shade(lv, hex("#C24450"), hex("#8E2532"), stroke: edge, lw: 1.2)
        shade("M 146 70 C 158 64 172 70 170 80 C 166 88 156 90 146 86 Z", hex("#C95562"), hex("#9C3440"), stroke: edge, lw: 1)       // left auricle
        let rv = "M 62 84 C 80 72 112 70 134 82 C 136 120 132 160 150 214 C 126 216 96 204 74 186 C 58 172 54 150 58 124 C 60 108 60 94 62 84 Z"
        shade(rv, hex("#DA6670"), hex("#B23A46"), stroke: edge, lw: 1.2)
        if zone > 0.01 {
            let lad = "M 128 96 C 134 130 138 170 150 214 C 164 202 176 176 178 146 C 176 120 160 100 140 90 Z"
            path(lad, fill: hex("#F29AA2"), opacity: zone)
            path(lad, fill: hex("#6D6570"), opacity: dead * zone)
            if dead > 0.05 {
                for i in 0..<5 {
                    let y = 120 + Double(i) * 18
                    path("M \(142 + Double(i) * 1.5) \(y) q 6 -4 12 0 q 6 4 12 0", stroke: hex("#4E4852"), lw: 0.7, opacity: dead * zone * 0.8)
                }
            }
        }
        // pulmonary trunk over the aortic root
        shade("M 88 84 C 88 62 94 44 110 36 L 136 30 C 146 28 152 36 146 44 L 128 50 C 116 56 112 70 114 86 Z",
              hex("#7F97D6"), hex("#4E68AE"), stroke: hex("#34497E"), lw: 1.2)
        // coronary arteries: RCA in the right groove, LAD down the front groove, circumflex round the left
        let cor = hex("#F0C04A"), corLo = hex("#B5812A")
        let rca = "M 76 90 C 66 104 58 130 56 150 C 56 170 66 184 84 194"
        let lad = "M 118 88 C 126 120 132 170 148 208"
        let lcx = "M 118 88 C 132 86 150 90 168 104 C 176 112 180 122 182 132"
        let diag = "M 128 124 C 142 132 156 146 166 164"
        for (d, w) in [(rca, 5.0), (lad, 5.0), (lcx, 4.2), (diag, 3.2)] {
            path(d, stroke: corLo, lw: w + 1.6, cap: .round)
            path(d, stroke: cor, lw: w, cap: .round)
        }
        path("M 60 150 C 70 156 76 164 80 176", stroke: cor, lw: 2.4, cap: .round)
        // blood moving down the LAD
        let blocked = clot && !stent
        for i in 0..<5 {
            let u = (t * 0.45 + Double(i) / 5).wrap(1)
            if blocked && u > 0.14 { continue }
            let a = pow(1 - u, 3), b = 3 * u * pow(1 - u, 2), c = 3 * u * u * (1 - u), d = pow(u, 3)
            circle(a * 118 + b * 126 + c * 132 + d * 148, a * 88 + b * 120 + c * 170 + d * 208, 1.6, fill: .white, opacity: 0.9 * flow)
        }
        if clot {
            if stent {
                rect(117, 96, 10, 22, r: 3, fill: cor, stroke: hex("#7E8794"), lw: 1.2)
                for k in 0..<4 { path("M 117 \(98 + Double(k) * 5) L 127 \(101 + Double(k) * 5)", stroke: hex("#7E8794"), lw: 0.9) }
            } else {
                ellipse(123, 106, 6.5, 8, fill: hex("#4A0E18"), stroke: .white, lw: 1.2)
                ellipse(121, 104, 2, 2.5, fill: hex("#7A2530"))
            }
        }
    }

    /// Left side of the brain (front to the left). Frame ≈ 0…220 × 0…180. `core` / `penumbra` 0…1 in the middle-cerebral-artery field.
    mutating func brainSide(penumbra: Double = 0, core: Double = 0, clot: Bool = false, cleared: Bool = false, lobes: Bool = true, t: Double = 0) {
        let edge = hex("#B07A86"), fold = hex("#D6A0AD")
        let cortex = "M 14 96 C 4 60 30 16 86 8 C 140 0 196 22 212 70 C 220 94 212 112 196 118 C 180 122 164 118 152 116 "
            + "C 140 132 110 142 84 136 C 64 132 52 124 44 116 C 30 114 18 108 14 96 Z"
        // internal carotid, rising behind the temporal lobe
        let art = Tone.artery, artLo = hex("#8E1E28"), dim = clot && !cleared
        path("M 56 180 C 58 164 54 146 58 126", stroke: artLo, lw: 7, cap: .round)
        path("M 56 180 C 58 164 54 146 58 126", stroke: art, lw: 5, cap: .round)
        // cerebellum and brainstem (pons, medulla) behind
        shade("M 122 122 C 136 116 150 124 148 140 C 146 150 140 156 138 166 L 134 182 L 120 182 L 122 164 C 116 152 114 136 122 122 Z",
              hex("#EBC3CB"), hex("#C99AA5"), stroke: edge, lw: 1.2)
        let cbl = SVGPath.parse("M 150 116 C 160 104 198 104 210 118 C 216 134 200 150 176 150 C 156 150 144 136 150 116 Z")
        shade(cbl, hex("#EBC0CA"), hex("#C98E9C"), stroke: edge, lw: 1.2)
        var cb = clipped(to: cbl)
        for j in 0..<7 { cb.path("M 146 \(112 + Double(j) * 6) Q 182 \(104 + Double(j) * 7) 214 \(116 + Double(j) * 6)", stroke: edge, lw: 0.7) }
        let cp = SVGPath.parse(cortex)
        shade(cp, hex("#F8D6DC"), hex("#E8B2BE"), stroke: edge, lw: 1.6)
        var inside = clipped(to: cp)
        let central = "C 112 30 104 60 94 94", fissure = "C 76 100 58 108 44 116"
        if lobes {
            inside.path("M 0 0 L 118 0 L 118 4 \(central) \(fissure) L 0 150 Z", fill: hex("#F2B8C4"), opacity: 0.35)                  // frontal
            inside.path("M 118 0 L 180 0 L 180 20 C 186 50 190 76 192 92 C 176 90 160 88 150 88 C 130 90 110 92 94 94 C 104 60 112 30 118 4 Z",
                        fill: hex("#F6D2B8"), opacity: 0.45)                                                                      // parietal
            inside.path("M 180 0 L 240 0 L 240 150 L 196 124 C 196 110 194 100 192 92 C 190 76 186 50 180 20 Z", fill: hex("#DCCBEA"), opacity: 0.55) // occipital
            inside.path("M 44 116 C 58 108 76 100 94 94 C 110 92 130 90 150 88 C 160 88 176 90 192 92 C 194 100 196 110 196 124 L 170 160 L 30 160 Z",
                        fill: hex("#CFDDF0"), opacity: 0.5)                                                                       // temporal
        }
        // gyri and sulci
        for d in ["M 30 56 C 44 48 50 66 64 56", "M 36 86 C 50 78 58 92 72 84", "M 56 30 C 70 22 80 40 96 30", "M 76 60 C 84 52 92 66 100 58",
                  "M 140 22 C 150 36 162 26 174 40", "M 142 60 C 154 70 168 58 182 72", "M 196 60 C 202 70 206 80 204 92",
                  "M 70 122 C 88 112 104 124 122 114", "M 124 108 C 138 102 150 110 166 104", "M 20 70 C 26 64 32 72 40 66"] {
            inside.path(d, stroke: fold, lw: 1.1, cap: .round)
        }
        inside.path("M 118 4 \(central)", stroke: edge, lw: 1.6)                                                      // central sulcus
        inside.path("M 108 2 C 102 30 94 60 86 96", stroke: fold, lw: 0.9)
        inside.path("M 130 6 C 124 34 116 64 108 92", stroke: fold, lw: 0.9)
        inside.path("M 180 20 C 186 50 190 76 192 92", stroke: fold, lw: 1)                                         // parieto-occipital
        if penumbra > 0.01 {
            let c = CGPoint(x: 102, y: 88), rx = 76 * penumbra, ry = 50 * penumbra
            let pen = Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: 2 * rx, height: 2 * ry))
            inside.ctx.fill(pen, with: .radialGradient(Gradient(colors: [hex("#E26A78").opacity(0.7), hex("#E26A78").opacity(0.12)]),
                                                        center: c, startRadius: 0, endRadius: rx))
        }
        if core > 0.01 {
            let c = CGPoint(x: 98, y: 92)
            inside.ctx.fill(Path(ellipseIn: CGRect(x: c.x - 58 * core, y: c.y - 38 * core, width: 116 * core, height: 76 * core)),
                            with: .radialGradient(Gradient(colors: [hex("#6A6270"), hex("#8A828E")]), center: c, startRadius: 0, endRadius: 58 * core))
            for i in 0..<Int(core * 12) {
                let a = Double(i) * 2.4, rr = (Double(i) * 0.37).wrap(1) * 0.8
                inside.circle(c.x + cos(a) * 58 * core * rr, c.y + sin(a) * 38 * core * rr, 1.1, fill: hex("#554E5A"))
            }
        }
        path("M 150 88 C 130 90 110 92 94 94 \(fissure)", stroke: edge, lw: 2.2)                                 // lateral (Sylvian) fissure
        path("M 150 88 C 156 84 160 80 164 74", stroke: edge, lw: 1.6)
        // middle cerebral artery: deep in the fissure (dashed), branches fanning out over the surface
        path("M 58 126 C 64 116 80 104 104 96", stroke: art, lw: 3.2, dash: [3, 2])
        let up = ["M 60 110 C 50 96 40 84 28 74 M 44 98 C 40 90 34 84 24 82", "M 76 102 C 72 84 66 66 60 48 M 70 80 C 60 74 52 70 42 70",
                  "M 98 95 C 100 76 100 56 104 34 M 100 64 C 110 56 116 48 120 38", "M 118 92 C 130 76 140 62 150 46 M 138 66 C 148 66 158 62 166 56",
                  "M 140 89 C 154 82 170 80 184 86"]
        let down = ["M 88 98 C 88 108 90 118 94 128", "M 116 92 C 120 104 126 114 134 122", "M 150 88 C 160 96 170 104 180 110"]
        for d in up + down {
            path(d, stroke: artLo, lw: 3, opacity: dim ? 0.3 : 1, cap: .round)
            path(d, stroke: art, lw: 1.8, opacity: dim ? 0.3 : 1, cap: .round)
        }
        for i in 0..<4 {
            let u = (t * 0.5 + Double(i) / 4).wrap(1)
            if dim && u > 0.7 { continue }
            let y = 180 - u * 54
            circle(56 + (y < 150 ? (150 - y) * 0.08 : 0), y, 1.6, fill: .white, opacity: 0.9)
        }
        if clot {
            if cleared {
                circle(66, 116, 2.5, fill: hex("#C9C2C8"))
            } else {
                ellipse(66, 116, 6.5, 5, fill: hex("#4A0E18"), stroke: .white, lw: 1.2)
            }
        }
    }
}
