import SwiftUI

/// Ready-made character parts (Humaaans style: flat fills, no outlines, small heads, spiky hands),
/// recoloured per person. Path data comes from `PeopleArtData.swift`, parsed once.
enum PeopleArt {
    enum Layer: String, Sendable { case back, neck, skin, front, shoe }
    struct Piece: Sendable {
        let layer: Layer, token: String, path: Path
    }

    static let parts: [String: [Piece]] = data.mapValues { rows in
        rows.compactMap { row in
            let f = row.split(separator: "|", maxSplits: 2).map(String.init)
            guard f.count == 3, let layer = Layer(rawValue: f[0]) else { return nil }
            return Piece(layer: layer, token: f[1], path: SVGPath.parse(f[2]))
        }
    }

    /// Head styles; the profile ones are library heads, the face-on ones custom in the same style.
    enum Head: String, Sendable {
        case short, short2, caesar, long, pony, bun, curly, afro, bald, beard, wavy, baby
        var front: String {
            switch self {
            case .wavy: "long"
            case .beard: "caesar"
            default: rawValue
            }
        }
    }

    /// fill one part, `tf` maps the part's frame into the sketch
    static func draw(_ id: String, _ s: inout Sketch, _ tf: CGAffineTransform, look: Look, only: Set<Layer>? = nil) {
        for p in parts[id] ?? [] where only?.contains(p.layer) ?? true {
            let (c, a) = color(p.token, look)
            s.ctx.fill(p.path.applying(tf), with: .color(c.opacity(a)))
        }
    }

    static func color(_ token: String, _ look: Look) -> (Color, Double) {
        switch token {
        case "skin": (look.gloves ?? look.skin, 1)
        case "hair": (look.hair, 1)
        case "top": (look.top, 1)
        case "shoes": (look.shoes, 1)
        default:
            if token.hasPrefix("shade") { (.black, Double(token.dropFirst(5)) ?? 0.1) }
            else if token.hasPrefix("light") { (.white, Double(token.dropFirst(5)) ?? 0.3) }
            else { (look.top, 1) }
        }
    }

    /// unit frame: origin `o`, x along `x` (length = scale), y along `y`
    static func frame(_ o: CGPoint, x: CGPoint, y: CGPoint) -> CGAffineTransform {
        CGAffineTransform(a: x.x, b: x.y, c: y.x, d: y.y, tx: o.x, ty: o.y)
    }

    // MARK: pieces used by the figure kit

    /// profile head, frame as `drawSideHead` (x toward the face, y down, unit = r)
    static func sideHead(_ s: inout Sketch, _ tf: CGAffineTransform, look: Look, face: Face, baby: Bool, only: Set<Layer>? = nil) {
        let head = "side.\((look.art ?? .short).rawValue)"
        draw(head, &s, tf, look: look, only: only)
        guard only?.contains(.front) ?? true else { return }
        if face == .distress || face == .open {
            s.ctx.fill(Path(ellipseIn: CGRect(x: 0.66, y: 0.42, width: 0.2, height: 0.2)).applying(tf), with: .color(Ink.mouth))
        }
        if look.glasses {
            var p = Path(ellipseIn: CGRect(x: 0.46, y: -0.24, width: 0.28, height: 0.24))
            p.move(to: CGPoint(x: 0.46, y: -0.12))
            p.addLine(to: CGPoint(x: 0.02, y: -0.06))
            s.ctx.stroke(p.applying(tf), with: .color(Ink.ink), lineWidth: 0.06 * hypot(tf.a, tf.b))
        }
    }

    /// face-on head centred at `c`, unit = r; `bow` tips it toward us (more crown, face drops)
    static func frontHead(_ s: inout Sketch, c: CGPoint, r: Double, look: Look, bow: Double = 0, only: Set<Layer>? = nil) {
        let head = look.art ?? .short
        let tf = CGAffineTransform(a: r, b: 0, c: 0, d: r * (1 - 0.2 * bow), tx: c.x, ty: c.y)
        let hair = "front.\(head.front)"
        if only?.contains(.back) ?? true { draw(hair, &s, tf, look: look, only: [.back]) }
        if only?.contains(.neck) ?? true { draw("front.skull", &s, tf, look: look, only: [.neck]) }
        if only?.contains(.skin) ?? true { draw("front.skull", &s, tf, look: look, only: [.skin]) }
        if only?.contains(.front) ?? true {
            // leaning toward us: the hairline slides down over the forehead
            draw(hair, &s, tf.translatedBy(x: 0, y: bow * 0.5), look: look, only: [.front])
            if look.glasses && bow < 0.5 {
                for x in [-0.34, 0.34] {
                    s.ctx.stroke(Path(ellipseIn: CGRect(x: x - 0.2, y: -0.12, width: 0.4, height: 0.3)).applying(tf), with: .color(Ink.ink),
                                 lineWidth: 0.06 * r)
                }
            }
        }
    }

    /// hand: palm centre `c`, fingers along `dir`, `len` = reach length; thumb on the `thumb` side (−1 left of `dir`)
    static func hand(_ s: inout Sketch, at c: CGPoint, dir d: CGPoint, len: Double, shape: SideFigure.Hand, look: Look, thumb: Double) {
        let L = len * 0.8
        let wrist = CGPoint(x: c.x - d.x * L * 0.42, y: c.y - d.y * L * 0.42)
        let id: String = switch shape {
        case .open: "hand.open"
        case .fist: "hand.fist"
        case .laced: "hand.laced"
        case .twoFingers: "hand.twoFingers"
        case .encircle: "hand.encircle"
        case .thumb: "hand.thumb"
        }
        // library thumb sits on +y: point +y to the asked side
        let y = CGPoint(x: -d.y * thumb * L, y: d.x * thumb * L)
        draw(id, &s, frame(wrist, x: CGPoint(x: d.x * L, y: d.y * L), y: y), look: look)
    }

    /// arm from shoulder `sh` via elbow `e` to wrist `w`: wide flat sleeve, thin bare wrist (long sleeves) or thin bare arm
    static func arm(_ s: inout Sketch, _ sh: CGPoint, _ e: CGPoint, _ w: CGPoint, aw: Double, look: Look) {
        let skin = look.skin
        if look.longSleeves {
            s.shape(smoothLimb([lerp(e, w, 0.5), w], [aw * 0.24, aw * 0.19]), fill: skin)
            let cuff = lerp(e, w, 0.86)
            s.shape(smoothLimb([sh, e, cuff], [aw * 0.6, aw * 0.44, aw * 0.4], bulge: [(aw * 0.03, aw * 0.03), (0, 0)]), fill: look.top)
        } else {
            s.shape(smoothLimb([sh, e, w], [aw * 0.34, aw * 0.26, aw * 0.19]), fill: skin)
            let hem = lerp(sh, e, 0.5)
            s.shape(smoothLimb([sh, hem], [aw * 0.62, aw * 0.5]), fill: look.top)
        }
    }

    /// straight tapered leg hip → knee → ankle; trousers to the ankle (bare for babies and shorts)
    static func leg(_ s: inout Sketch, hip: CGPoint, knee k: CGPoint, ankle an: CGPoint, lw: Double, look: Look) {
        if look.bareFeet {
            s.shape(smoothLimb([hip, k, an], [lw * 0.62, lw * 0.44, lw * 0.3]), fill: look.onePiece ? look.top : look.skin)
            return
        }
        s.shape(smoothLimb([lerp(k, an, 0.5), an], [lw * 0.24, lw * 0.18]), fill: look.skin)
        let hem = lerp(k, an, 0.9)
        s.shape(smoothLimb([hip, k, hem], [lw * 0.68, lw * 0.4, lw * 0.28]), fill: look.bottom)
    }

    /// library shoe (or a bare foot) from the ankle along `dir`, sole on the `n` side
    static func shoe(_ s: inout Sketch, ankle a: CGPoint, dir fd: CGPoint, n: CGPoint, len F: Double, w: Double, look: Look) {
        if look.bareFeet {
            func P(_ along: Double, _ down: Double) -> CGPoint { CGPoint(x: a.x + fd.x * along + n.x * down, y: a.y + fd.y * along + n.y * down) }
            s.shape(smoothPath([P(-w * 0.26, -w * 0.12), P(F * 0.4, -w * 0.1), P(F * 0.82, w * 0.04), P(F * 0.8, w * 0.28), P(F * 0.2, w * 0.3),
                                P(-w * 0.28, w * 0.24)]), fill: look.skin)
            return
        }
        draw(look.sneakers ? "shoe.sneaker" : "shoe.pointy", &s,
             frame(a, x: CGPoint(x: fd.x * F, y: fd.y * F), y: CGPoint(x: n.x * F, y: n.y * F)), look: look)
    }
}

// MARK: - Mix and match

extension Look {
    /// A person built from character parts: head style, skin, hair colour, top, bottom, shoes.
    static func person(_ head: PeopleArt.Head, skin: Color, hair: Color = Tone.ink, top: Color, bottom: Color, shoes: Color = Tone.ink,
                       sneakers: Bool = false, longSleeves: Bool = true, onePiece: Bool = false, female: Bool = false, glasses: Bool = false) -> Look {
        var l = Look(skin: skin, hair: hair, style: head.legacy, top: top, bottom: bottom, shoes: shoes, longSleeves: longSleeves,
                     onePiece: onePiece, female: female, glasses: glasses)
        l.art = head
        l.sneakers = sneakers
        return l
    }

    /// library palette
    enum Tone {
        static let ink = hex("#191847"), navy = hex("#2F3676"), blue = hex("#2B44FF"), red = hex("#FF4133"), orange = hex("#FF9B21")
        static let teal = hex("#89C5CC"), mint = hex("#C1DEE2"), grey = hex("#C5CFD6"), white = hex("#E4E4E4"), slate = hex("#5C63AB")
        static let skinLight = hex("#F1C7A4"), skinTan = hex("#D4A07A"), skinMid = hex("#B28B67"), skinBrown = hex("#8F5E3E"), skinDeep = hex("#6B4130")
        static let grey2 = hex("#D5D2CE"), brown = hex("#5A3A28")
    }

    /// the cast in character-art style
    enum Cast {
        static let rescuer = Look.person(.short, skin: Tone.skinTan, hair: Tone.ink, top: Tone.blue, bottom: Tone.navy)
        static let helper = Look.person(.afro, skin: Tone.skinDeep, top: Tone.orange, bottom: Tone.teal, sneakers: true, female: true)
        static let man = Look.person(.short2, skin: Tone.skinLight, hair: Tone.brown, top: Tone.grey, bottom: Tone.navy)
        static let woman = Look.person(.long, skin: Tone.skinMid, top: Tone.teal, bottom: Tone.slate, female: true)
        static let pregnant = Look.person(.bun, skin: Tone.skinMid, top: Tone.mint, bottom: Tone.slate, female: true)
        static let senior = Look.person(.caesar, skin: Tone.skinLight, hair: Tone.grey2, top: hex("#69A1AC"), bottom: hex("#4A4E6B"), glasses: true)
        static let kid = Look.person(.short2, skin: Tone.skinBrown, top: Tone.orange, bottom: Tone.blue, sneakers: true, longSleeves: false)
        static let toddler = Look.person(.short, skin: Tone.skinLight, hair: hex("#8A5A3A"), top: Tone.red, bottom: Tone.teal, shoes: Tone.white,
                                         sneakers: true, longSleeves: false)
        static let baby = Look.person(.baby, skin: hex("#E9B892"), hair: hex("#8A5A3A"), top: Tone.mint, bottom: Tone.mint, shoes: hex("#E9B892"),
                                      onePiece: true)
    }
}

extension PeopleArt.Head {
    /// nearest hand-drawn hair style, for code that still reads `Look.style`
    var legacy: Look.Hair {
        switch self {
        case .long, .wavy: .long
        case .pony: .ponytail
        case .bun: .bun
        case .curly, .afro: .curly
        case .baby: .baby
        case .bald, .caesar: .thin
        default: .short
        }
    }
}

extension Build {
    /// character-art proportions: smaller heads, slimmer hands
    var art: Build {
        var b = self
        let k = headR < 0.09 ? 0.78 : headR < 0.105 ? 0.88 : 0.95
        b.headR *= k
        b.hand *= 0.8
        b.shoulderW *= 0.82
        b.armW *= 0.9
        return b
    }
}

extension Casualty {
    /// the same person drawn with character parts
    init(art p: Profile, adult h: Double) {
        self.init(p, adult: h)
        build = build.art
        look = switch p.age {
        case .infant: Look.Cast.baby
        case .toddler: Look.Cast.toddler
        case .child: Look.Cast.kid
        case .senior: Look.Cast.senior
        case .adult: p.isPregnant ? Look.Cast.pregnant : p.female ? Look.Cast.woman : Look.Cast.man
        }
    }
}
