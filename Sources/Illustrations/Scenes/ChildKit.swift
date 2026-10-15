import SwiftUI

/// Shared pieces for the children's topics: the child drawn for the chosen age, and small list icons.
extension Illustrations {
    /// the child a topic is about; adults and seniors see a toddler
    static func kid(_ who: Profile, adult h: Double = 300) -> Casualty {
        let age: AgeGroup = who.age == .infant || who.age == .child ? who.age : .toddler
        return Casualty(Profile(age: age, female: who.female), adult: h)
    }

    /// waist-up child for a portrait
    static func kidBust(_ who: Profile, h: Double) -> Bust {
        var b = Bust(kid(who))
        b.h = h
        b.waist = 0.62
        return b
    }

    /// cross-fade weight of one panel while `mode` moves between whole numbers
    static func panel(_ mode: Double, _ i: Int) -> Double { max(0, 1 - abs(mode - Double(i))) }

    /// red "call now" box at the bottom of a list
    @MainActor static func callBox(_ s: inout Sketch, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ en: String, _ zh: String) {
        s.rect(x, y, w, h, r: 9, fill: hex("#FFF1F1"), stroke: Anat.red, lw: 1.2)
        s.cardNote(en, zh, x + w / 2, y + h / 2, width: w - 12, size: 8.5, color: Anat.red, bold: true)
    }

    /// 2 × 3 tiles: icon number and a wrapped line each
    @MainActor static func tiles(_ s: inout Sketch, _ items: [(String, String)], color: Color, top: Double = 40) {
        for (i, it) in items.enumerated() {
            let x = 8 + Double(i % 2) * 176, y = top + Double(i / 2) * 84
            s.card(x, y, 168, 76, accent: color)
            badge(&s, x + 22, y + 38, "\(i + 1)", color)
            s.noteLeft(it.0, it.1, x + 40, y + 38, width: 120, size: 9, color: Tone.ink, bold: true)
        }
    }

    /// tick or cross in a small circle, for do / don't lists
    @MainActor static func mark(_ s: inout Sketch, _ c: CGPoint, ok: Bool, r: Double = 7) {
        let col = ok ? Anat.green : Anat.red
        s.circle(c.x, c.y, r, fill: col.opacity(0.12), stroke: col, lw: 1.1)
        if ok {
            s.path("M \(c.x - r * 0.45) \(c.y) l \(r * 0.35) \(r * 0.38) l \(r * 0.6) \(r * -0.75)", stroke: col, lw: 1.5, cap: .round)
        } else {
            let k = r * 0.38
            s.line(c.x - k, c.y - k, c.x + k, c.y + k, stroke: col, lw: 1.5, cap: .round)
            s.line(c.x + k, c.y - k, c.x - k, c.y + k, stroke: col, lw: 1.5, cap: .round)
        }
    }

    /// a sprinkle of rash spots; `faint` 0…1 lets a blanching rash fade
    @MainActor static func rash(_ s: inout Sketch, _ c: CGPoint, _ r: Double, dots: Bool, size: Double = 1, faint: (CGPoint) -> Double = { _ in 0 }) {
        let n = dots ? 26 : 14
        for i in 0..<n {
            // golden-angle scatter: even, repeatable
            let a = Double(i) * 2.39996, d = r * (Double(i) + 0.5).squareRoot() / Double(n).squareRoot()
            let p = CGPoint(x: c.x + cos(a) * d, y: c.y + sin(a) * d * 0.8)
            let o = 1 - faint(p)
            if dots {
                s.circle(p.x, p.y, (1.3 + Double(i % 3) * 0.55) * size, fill: hex("#8E2A4A"), opacity: 0.9 * o)
            } else {
                s.ellipse(p.x, p.y, (5 + Double(i % 3) * 2) * size, (3.5 + Double(i % 2) * 2) * size, fill: hex("#E07A7E"), opacity: 0.55 * o)
            }
        }
    }
}

extension Sketch {
    /// Left-aligned wrapped text, vertically centred on `midY`.
    mutating func noteLeft(_ en: String, _ zh: String, _ x: Double, _ midY: Double, width: Double, size: Double = 9,
                           color: Color = Anat.text, bold: Bool = false) {
        let txt = ctx.resolve(Text(t(en, zh)).font(.system(size: size, weight: bold ? .semibold : .medium)).foregroundStyle(color))
        let m = txt.measure(in: CGSize(width: width, height: 200))
        ctx.draw(txt, in: CGRect(x: x, y: midY - m.height / 2, width: width, height: m.height + 1))
    }
}
