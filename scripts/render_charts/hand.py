"""Hand chart: left palm and right back share one silhouette (thumb on the left, fingers up)."""
import math

from shapely.geometry import Polygon
from shapely.ops import unary_union

from geom import band, circle, ellipse, half, line_d, side_of, smooth, taper

# name: base (web level), angle from vertical (+ toward the little finger), length, radii at base/PIP/DIP/tip
FINGERS = {
    "index": ((111, 176), -8, 118, (15.5, 14.2, 12.8, 11.8)),
    "middle": ((146, 169), -1.5, 132, (16.2, 14.8, 13.4, 12.4)),
    "ring": ((180, 174), 6, 122, (15.2, 13.8, 12.6, 11.6)),
    "little": ((211, 189), 15, 96, (13.2, 12.0, 11.0, 10.2)),
}
PIP, DIP = 0.40, 0.70
OUTER = -1
# thumb: CMC (in the thenar), MCP, IP, tip
THUMB = [(114, 322, 27), (80, 266, 19.5), (59, 228, 16.6), (46, 199, 14.6)]
THUMB_IP = 0.47


def axis(name):
    (bx, by), ang, L, _ = FINGERS[name]
    a = math.radians(ang)
    return (bx, by), (math.sin(a), -math.cos(a)), L


def at(name, s, off=0.0):
    """Point s (0 base … 1 tip) along a finger, `off` across it (+ toward the little finger)."""
    (bx, by), (ux, uy), L = axis(name)
    return (bx + ux * L * s - uy * off, by + uy * L * s + ux * off)


def finger(name):
    _, _, L, (r0, r1, r2, r3) = FINGERS[name]
    b = at(name, -0.25)
    p, d, t = at(name, PIP), at(name, DIP), at(name, 1 - r3 / L)
    return taper([(*b, r0 + 1), (*at(name, 0), r0), (*p, r1), (*at(name, (PIP + DIP) / 2), r2 - 0.4), (*d, r2), (*t, r3)])


def across(name, s, width=60):
    a, b = at(name, s, -width), at(name, s, width)
    return a, b


def seg(name, s0, s1):
    """Band of the finger between two fractions."""
    a0, b0 = across(name, s0)
    a1, b1 = across(name, s1)
    return finger(name).intersection(Polygon([a0, b0, b1, a1]).buffer(0))


def digit(name):
    """The free finger, from the web crease out."""
    return seg(name, 0, 1.3)


def thumb_at(s, off=0.0):
    """Along the thumb from MCP (0) to tip (1)."""
    (x0, y0, _), (xc, yc, r) = THUMB[1], THUMB[3]
    k = r / math.hypot(xc - x0, yc - y0)
    dx, dy = (xc - x0) * (1 + k), (yc - y0) * (1 + k)
    n = math.hypot(dx, dy)
    ux, uy = dx / n, dy / n
    return (x0 + dx * s - uy * off, y0 + dy * s + ux * off)


def tipward(s):
    """Half-plane across the thumb at s, on the tip side."""
    from shapely.geometry import Point
    h = half(thumb_at(s, -40), thumb_at(s, 40), 1)
    return h if h.contains(Point(thumb_at(s + 0.3))) else half(thumb_at(s, -40), thumb_at(s, 40), -1)


def thumb_seg(s0, s1, shape):
    a0, b0 = thumb_at(s0, -60), thumb_at(s0, 60)
    a1, b1 = thumb_at(s1, -60), thumb_at(s1, 60)
    return shape.intersection(Polygon([a0, b0, b1, a1]).buffer(0))


def silhouette():
    palm = smooth([(97, 196), (118, 176), (146, 170), (180, 174), (207, 186), (228, 204), (238, 232), (241, 268),
                   (238, 306), (228, 338), (214, 358), (200, 366), (128, 366), (112, 356), (100, 332), (92, 300), (89, 262), (91, 226)])
    thumb = taper(THUMB[1:])
    thenar = smooth([(84, 246), (72, 268), (76, 300), (92, 332), (114, 356), (134, 352), (126, 306), (104, 262)])
    web = smooth([(98, 198), (86, 212), (72, 232), (86, 246), (100, 234)])
    wrist = smooth([(122, 350), (208, 350), (214, 392), (220, 440), (110, 440), (116, 392)])
    # the heel of the hand gets a wide fillet, the finger webs a tight one
    base = unary_union([palm, thumb, thenar, web, wrist]).buffer(12, join_style="round").buffer(-12, join_style="round")
    fingers = unary_union([finger(n) for n in FINGERS])
    body = unary_union([base, fingers]).buffer(5, join_style="round").buffer(-5, join_style="round")
    return body.intersection(Polygon([(-50, -50), (350, -50), (350, 432), (-50, 432)]))


def crease(pts):
    return line_d(pts)


def finger_creases(name, palm=True):
    """Short joint creases across a finger, doubled at the PIP like real skin."""
    _, _, L, (r0, r1, r2, _) = FINGERS[name]
    out = []
    if palm:
        for s, r, n in ((0.02, r0, 2), (PIP, r1, 2), (DIP, r2, 1)):
            for k in range(n):
                s2 = s + k * 0.025
                out.append(crease([at(name, s2, -r * 0.7), at(name, s2 + 0.012, 0), at(name, s2, r * 0.7)]))
    else:
        for s, r, n in ((PIP + 0.02, r1, 3), (DIP + 0.02, r2, 2)):
            for k in range(n):
                s2 = s + (k - (n - 1) / 2) * 0.022
                w = 0.45 - abs(k - (n - 1) / 2) * 0.12
                out.append(crease([at(name, s2, -r * w), at(name, s2 - 0.01, 0), at(name, s2, r * w)]))
    return out


def nail(name):
    _, _, L, (_, _, _, r3) = FINGERS[name]
    w = r3 * 0.72
    base, tip = 0.80, 1 - 0.25 * r3 / L
    pts = [at(name, base, -w * 0.92), at(name, base - 0.012, 0), at(name, base, w * 0.92),
           at(name, (base + tip) / 2, w), at(name, tip - 0.02, w * 0.8), at(name, tip, 0), at(name, tip - 0.02, -w * 0.8), at(name, (base + tip) / 2, -w)]
    return smooth(pts)


def thumb_nail():
    pts = [thumb_at(0.66, -8.6), thumb_at(0.645, 0), thumb_at(0.66, 8.6), thumb_at(0.8, 9.4), thumb_at(0.93, 7),
           thumb_at(0.965, 0), thumb_at(0.93, -7), thumb_at(0.8, -9.4)]
    return smooth(pts)


def box(x0, y0, x1, y1):
    return Polygon([(x0, y0), (x1, y0), (x1, y1), (x0, y1)])


def edge_strip(sil, width):
    return sil.difference(sil.buffer(-width))


def build():
    sil = silhouette()
    thumb = unary_union([taper(THUMB[1:]), circle(*THUMB[1])]).intersection(sil)
    tones_palm = [
        ("light", ellipse(96, 300, 20, 40, -20)),               # thenar mound
        ("light", ellipse(222, 300, 13, 40, 4)),                # hypothenar mound
        ("light", ellipse(168, 196, 58, 12, 8)),                # finger-base pads
        ("shade", ellipse(165, 272, 36, 44, 0)),                # palm hollow
    ]
    guides_palm = [
        crease([(240, 229), (222, 221), (198, 217), (176, 210), (156, 200), (140, 188)]),   # heart line
        crease([(93, 222), (112, 234), (138, 246), (168, 256), (196, 263), (218, 268)]),    # head line
        crease([(95, 224), (108, 244), (118, 272), (124, 306), (128, 338), (134, 356)]),    # life line
        crease([(122, 358), (145, 361), (172, 362), (200, 359)]),                          # wrist creases
        crease([(118, 367), (146, 371), (174, 372), (206, 368)]),
        crease([(222, 262), (230, 266), (237, 268)]),
    ] + [c for n in FINGERS for c in finger_creases(n)] + [
        crease([thumb_at(THUMB_IP, -11), thumb_at(THUMB_IP + 0.015, 0), thumb_at(THUMB_IP, 11)]),
        crease([thumb_at(THUMB_IP + 0.04, -9), thumb_at(THUMB_IP + 0.055, 0), thumb_at(THUMB_IP + 0.04, 9)]),
        crease([thumb_at(0.0, 4), thumb_at(0.02, 10), thumb_at(0.0, 17)]),
    ]
    metacarpal = {"index": (123, 340), "middle": (146, 342), "ring": (170, 344), "little": (194, 342)}
    bones_back = [line_d([at(n, -0.12), ((at(n, -0.12)[0] + m[0]) / 2, (at(n, -0.12)[1] + m[1]) / 2 + 2), m]) for n, m in metacarpal.items()] \
        + [line_d([thumb_at(0.02), (100, 292), (116, 336)])]
    knuckles = [crease([at(n, -0.1, -8), at(n, -0.13, 0), at(n, -0.1, 8)]) for n in FINGERS]
    guides_back = [c for n in FINGERS for c in finger_creases(n, palm=False)] + knuckles + [
        crease([thumb_at(THUMB_IP + 0.02, -7), thumb_at(THUMB_IP, 0), thumb_at(THUMB_IP + 0.02, 7)]),
        crease([thumb_at(THUMB_IP - 0.03, -5), thumb_at(THUMB_IP - 0.045, 0), thumb_at(THUMB_IP - 0.03, 5)]),
        crease([(124, 362), (148, 366), (176, 366), (202, 362)]),
    ]
    tones_back = [("nail", nail(n)) for n in FINGERS] + [("nail", thumb_nail()),
                  ("light", ellipse(160, 262, 50, 60, 0)), ("shade", ellipse(98, 250, 10, 26, -30))]
    return sil, thumb, tones_palm, guides_palm, tones_back, guides_back, bones_back


def palm_zones(sil, thumb):
    Z = []
    fing = {n: digit(n).intersection(sil) for n in FINGERS}
    palm = sil.difference(unary_union(list(fing.values()) + [thumb.intersection(half((20, 120), (110, 340), -1))]))
    # thumb: spine runs down its outer edge to the wrist
    spine = edge_strip(sil, 6.5).intersection(half(thumb_at(0.3, -40), thumb_at(0.3, 40), 1)).intersection(
        Polygon([(-20, 150), (60, 150), (84, 262), (104, 300), (122, 372), (100, 380), (-20, 380)]))
    Z.append(("palm-spine", spine))
    tip = thumb_seg(THUMB_IP, 1.2, thumb)
    pit = circle(*thumb_at(0.74, 0.5), 4.8)
    Z.append(("palm-pituitary", pit))
    Z.append(("palm-brain", tip.difference(pit).difference(spine)))
    Z.append(("palm-neck", thumb_seg(0.0, THUMB_IP, thumb).difference(spine)))
    Z.append(("palm-sinuses", unary_union([seg(n, DIP, 1.2) for n in FINGERS])))
    Z.append(("palm-teeth", unary_union([seg(n, PIP, DIP) for n in FINGERS])))
    Z.append(("palm-eyes", unary_union([seg(n, 0.03, PIP) for n in ("index", "middle")])))
    Z.append(("palm-ears", unary_union([seg(n, 0.03, PIP) for n in ("ring", "little")])))
    thy = band([(72, 226), (86, 230), (97, 246), (102, 268), (104, 288)], 9)
    Z.append(("palm-thyroid", thy.intersection(sil).difference(spine)))
    shoulder = edge_strip(sil, 11).intersection(Polygon([(215, 190), (260, 190), (260, 238), (215, 238)]))
    Z.append(("palm-shoulder", shoulder))
    arm = edge_strip(sil, 8).intersection(Polygon([(215, 238), (260, 238), (260, 290), (215, 290)]))
    Z.append(("palm-arm", arm))
    hipknee = edge_strip(sil, 8).intersection(Polygon([(205, 290), (260, 290), (260, 350), (205, 350)]))
    Z.append(("palm-hip", hipknee))
    lungs = palm.intersection(side_of([(90, 214), (130, 206), (170, 210), (205, 222), (240, 236)], -1)).difference(unary_union([thy, spine, shoulder]))
    Z.append(("palm-lungs", lungs))
    below = palm.difference(unary_union([lungs, thy, spine, shoulder, arm, hipknee]))
    Z.append(("palm-solar-plexus", below.intersection(ellipse(152, 226, 13, 12))))
    Z.append(("palm-adrenal", below.intersection(ellipse(142, 247, 6, 6))))
    kidney = ellipse(152, 266, 11, 17, -8)
    Z.append(("palm-kidneys", below.intersection(kidney)))
    Z.append(("palm-stomach", below.intersection(smooth([(96, 212), (128, 208), (138, 220), (132, 238), (102, 242), (90, 228)]))))
    Z.append(("palm-pancreas", below.intersection(ellipse(116, 250, 20, 5.5, -4))))
    Z.append(("palm-duodenum", below.intersection(band([(132, 256), (126, 264), (112, 266), (100, 262)], 7))))
    bladder = ellipse(136, 334, 10, 9, 10)
    Z.append(("palm-ureter", below.intersection(band([(154, 284), (148, 305), (141, 324)], 5, cap="flat"))))
    Z.append(("palm-bladder", below.intersection(bladder)))
    Z.append(("palm-colon", below.intersection(band([(110, 290), (160, 289), (220, 290)], 10))))
    Z.append(("palm-small-intestine", below.intersection(smooth([(118, 300), (160, 298), (206, 300), (210, 318), (204, 336), (160, 340), (122, 336), (116, 318)])).difference(bladder)))
    Z.append(("palm-gonads", sil.intersection(Polygon([(142, 348), (200, 348), (200, 366), (142, 366)]))))
    Z.append(("palm-uterus", sil.intersection(Polygon([(112, 346), (142, 348), (142, 366), (112, 366)])).difference(spine)))
    Z.append(("palm-heart", below.intersection(smooth([(172, 218), (202, 218), (230, 228), (232, 246), (204, 252), (172, 246)])), "left"))
    Z.append(("palm-spleen", below.intersection(ellipse(204, 267, 24, 10)), "left"))
    gb = ellipse(190, 266, 8, 8)
    Z.append(("palm-gallbladder", below.intersection(gb), "right"))
    Z.append(("palm-liver", below.intersection(smooth([(170, 218), (204, 218), (232, 228), (234, 256), (220, 278), (186, 280), (170, 262)])), "right"))
    strip = below.intersection(band([(221, 294), (221, 338)], 12))
    Z.append(("palm-colon-asc", strip.intersection(box(0, 280, 300, 334)), "right"))
    Z.append(("palm-appendix", below.intersection(ellipse(221, 340, 6.5, 6.5)), "right"))
    Z.append(("palm-rectum", below.intersection(ellipse(150, 346, 7, 5.5)), "left"))
    Z.append(("palm-colon-desc", strip.union(below.intersection(band([(221, 344), (190, 347), (160, 346)], 9))), "left"))
    return Z


def notches():
    """Bottom of the skin web between neighbouring fingers."""
    names = list(FINGERS)
    out = []
    for a, b in zip(names, names[1:]):
        pa, pb = at(a, 0.02, FINGERS[a][3][0]), at(b, 0.02, -FINGERS[b][3][0])
        out.append(((pa[0] + pb[0]) / 2, (pa[1] + pb[1]) / 2))
    return out


def webs(sil):
    return unary_union([circle(x, y + 3, 8.5) for x, y in notches()]).intersection(sil)


def back_zones(sil, thumb):
    Z = []
    fing = unary_union([digit(n) for n in FINGERS]).intersection(sil)
    edge = edge_strip(sil, 9)
    mcp_cut = tipward(0)
    outer = half(thumb_at(-1, -6), thumb_at(1, -6), OUTER)
    radial = edge.intersection(Polygon([(-20, 150), (70, 150), (110, 300), (122, 380), (80, 380), (-20, 300)])).intersection(outer)
    Z.append(("back-cervical", radial.intersection(mcp_cut).difference(tipward(THUMB_IP))))
    below_mcp = radial.difference(mcp_cut)
    for zid, y0, y1 in (("back-thoracic", 200, 300), ("back-lumbar", 300, 338), ("back-sacrum", 338, 380)):
        Z.append((zid, below_mcp.intersection(Polygon([(-50, y0), (200, y0), (200, y1), (-50, y1)]))))
    Z.append(("back-throat", thumb_seg(0.16, THUMB_IP - 0.03, thumb).difference(radial).intersection(half(thumb_at(-1, 3), thumb_at(1, 3), OUTER))))
    ulnar = edge.intersection(Polygon([(205, 196), (260, 196), (260, 372), (205, 372)]))
    for zid, y0, y1 in (("back-shoulder", 190, 240), ("back-elbow", 240, 282), ("back-knee", 282, 322), ("back-hip", 322, 372)):
        Z.append((zid, ulnar.intersection(Polygon([(200, y0), (260, y0), (260, y1), (200, y1)]))))
    Z.append(("back-lymph-head", webs(sil)))
    dorsum = sil.difference(unary_union([fing, edge, thumb.intersection(mcp_cut), webs(sil)]))
    l2 = [(96, 222), (140, 212), (180, 216), (226, 230)]
    l3 = [(100, 250), (150, 246), (200, 252), (236, 258)]
    notch_line = [(x, y + 9) for x, y in notches()]
    Z.append(("back-upper-back", dorsum.intersection(side_of(l2, -1)).intersection(side_of(notch_line, 1))))
    Z.append(("back-chest", dorsum.intersection(side_of(l2, 1)).intersection(side_of(l3, -1)).intersection(half((112, 200), (118, 260), -1))))
    Z.append(("back-diaphragm", dorsum.intersection(side_of(l3, 1)).intersection(side_of([(p[0], p[1] + 7) for p in l3], -1))))
    Z.append(("back-ribs", dorsum.intersection(unary_union([ellipse(135, 322, 6.5, 12, -4), ellipse(184, 324, 6.5, 12, 8)]))))
    Z.append(("back-lymph-upper", sil.intersection(ellipse(206, 358, 11, 8, -20)).difference(ulnar)))
    Z.append(("back-lymph-lower", sil.intersection(ellipse(126, 352, 10, 8, 20)).difference(radial)))
    Z.append(("back-groin", sil.intersection(side_of([(110, 366), (160, 370), (220, 366)], 1)).intersection(side_of([(110, 378), (160, 382), (220, 378)], -1))))
    return Z


BACK_POINTS = {
    "back-hegu": [(102, 256, 6.5)],
    "back-luozhen": [(129, 218, 5.5)],
    "back-zhongzhu": [(202, 230, 5.5)],
    "back-yemen": [(198, 189, 5)],
    "back-houxi": [(236, 234, 5.5)],
    "back-yaotong": [(135, 290, 5.5), (188, 294, 5.5)],
    "back-yangxi": [(116, 354, 5.5)],
    "back-yangchi": [(176, 360, 5.5)],
    "back-waiguan": [(164, 410, 6)],
}
