import SwiftUI

/// Parses the small SVG path subset the chart data uses: M L C Q A Z, absolute and relative.
enum SVGPath {
    static func parse(_ d: String) -> Path {
        var path = Path()
        let tokens = tokenize(d)
        var i = 0
        var cmd: Character = "M"
        var current = CGPoint.zero, start = CGPoint.zero

        func number() -> CGFloat {
            defer { i += 1 }
            return i < tokens.count ? CGFloat(Double(tokens[i]) ?? 0) : 0
        }
        func point(_ relative: Bool) -> CGPoint {
            let x = number(), y = number()
            return relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
        }

        while i < tokens.count {
            if let c = tokens[i].first, c.isLetter { cmd = c; i += 1 }
            let rel = cmd.isLowercase
            switch cmd.uppercased() {
            case "M":
                current = point(rel); start = current
                path.move(to: current)
                cmd = rel ? "l" : "L"
            case "L":
                current = point(rel); path.addLine(to: current)
            case "Q":
                let c = point(rel), e = point(rel)
                path.addQuadCurve(to: e, control: c); current = e
            case "C":
                let c1 = point(rel), c2 = point(rel), e = point(rel)
                path.addCurve(to: e, control1: c1, control2: c2); current = e
            case "A":
                let rx = number(), ry = number(), rot = number(), large = number() != 0, sweep = number() != 0
                let e = point(rel)
                addArc(&path, from: current, to: e, rx: rx, ry: ry, rotation: rot, large: large, sweep: sweep)
                current = e
            case "Z":
                path.closeSubpath(); current = start
            default:
                i += 1
            }
        }
        return path
    }

    private static func tokenize(_ d: String) -> [String] {
        var out: [String] = [], cur = ""
        for ch in d {
            if ch.isLetter && ch != "e" {
                if !cur.isEmpty { out.append(cur); cur = "" }
                out.append(String(ch))
            } else if ch == "," || ch == " " {
                if !cur.isEmpty { out.append(cur); cur = "" }
            } else if ch == "-" && !cur.isEmpty && cur.last != "e" {
                out.append(cur); cur = "-"
            } else {
                cur.append(ch)
            }
        }
        if !cur.isEmpty { out.append(cur) }
        return out
    }

    /// SVG endpoint arc → centre parameterisation (SVG spec F.6.5), drawn as line segments.
    private static func addArc(_ path: inout Path, from p1: CGPoint, to p2: CGPoint, rx rx0: CGFloat, ry ry0: CGFloat,
                               rotation: CGFloat, large: Bool, sweep: Bool) {
        var rx = abs(rx0), ry = abs(ry0)
        guard rx > 0, ry > 0 else { path.addLine(to: p2); return }
        let phi = rotation * .pi / 180, cp = cos(phi), sp = sin(phi)
        let dx = (p1.x - p2.x) / 2, dy = (p1.y - p2.y) / 2
        let x1 = cp * dx + sp * dy, y1 = -sp * dx + cp * dy
        let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lambda > 1 { rx *= sqrt(lambda); ry *= sqrt(lambda) }
        let num = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let den = rx * rx * y1 * y1 + ry * ry * x1 * x1
        var coef = sqrt(max(0, num / den))
        if large == sweep { coef = -coef }
        let cxp = coef * rx * y1 / ry, cyp = -coef * ry * x1 / rx
        let cx = cp * cxp - sp * cyp + (p1.x + p2.x) / 2, cy = sp * cxp + cp * cyp + (p1.y + p2.y) / 2
        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let a = atan2(ux * vy - uy * vx, ux * vx + uy * vy)
            return a
        }
        let t1 = angle(1, 0, (x1 - cxp) / rx, (y1 - cyp) / ry)
        var dt = angle((x1 - cxp) / rx, (y1 - cyp) / ry, (-x1 - cxp) / rx, (-y1 - cyp) / ry)
        if !sweep && dt > 0 { dt -= 2 * .pi } else if sweep && dt < 0 { dt += 2 * .pi }
        let steps = 24
        for s in 1...steps {
            let t = t1 + dt * CGFloat(s) / CGFloat(steps)
            let x = cx + rx * cos(t) * cp - ry * sin(t) * sp
            let y = cy + rx * cos(t) * sp + ry * sin(t) * cp
            path.addLine(to: CGPoint(x: x, y: y))
        }
    }
}
