"""Foot chart: left sole and left top, big toe on the right, toes up."""
import math

from shapely.geometry import Polygon
from shapely.ops import unary_union

from geom import band, circle, ellipse, line_d, side_of, smooth, taper

# base (ball crease), angle (+ toward the big-toe side), length, radii at base / neck / pad
TOES = {
    1: ((184, 134), -3, 82, (19, 15.8, 20)),
    2: ((145, 143), -6, 70, (11.5, 8.8, 11.2)),
    3: ((121, 152), -12, 62, (11, 8.4, 10.6)),
    4: ((99, 163), -19, 55, (10.4, 8, 10)),
    5: ((80, 177), -27, 46, (9.6, 7.4, 9.2)),
}
NECK = 0.45


def at(t, s, off=0.0):
    (bx, by), ang, L, _ = TOES[t]
    a = math.radians(ang)
    ux, uy = math.sin(a), -math.cos(a)
    return (bx + ux * L * s - uy * off, by + uy * L * s + ux * off)


def pad_s(t):
    _, _, L, (_, _, r2) = TOES[t]
    return 1 - r2 / L


def toe(t):
    _, _, L, (r0, r1, r2) = TOES[t]
    return taper([(*at(t, -0.3), r0 + 1), (*at(t, 0), r0), (*at(t, NECK), r1), (*at(t, pad_s(t)), r2)])


def seg(t, s0, s1):
    q = Polygon([at(t, s0, -60), at(t, s0, 60), at(t, s1, 60), at(t, s1, -60)]).buffer(0)
    return toe(t).intersection(q)


def digit(t):
    return seg(t, 0, 1.3)


def silhouette(top=False):
    toes = unary_union([toe(t) for t in TOES])
    if top:
        body = smooth([(64, 180), (86, 160), (110, 148), (136, 138), (160, 128), (186, 120), (204, 132), (210, 160), (206, 198),
                       (197, 248), (190, 296), (188, 326), (194, 344), (190, 364), (180, 380), (177, 400), (177, 446), (99, 446),
                       (99, 404), (90, 390), (78, 376), (76, 360), (82, 340), (80, 296), (74, 252), (66, 214), (60, 194)])
    else:
        body = smooth([(64, 180), (86, 160), (110, 148), (136, 138), (160, 128), (186, 120), (204, 132), (210, 160), (207, 192),
                       (198, 228), (190, 262), (187, 300), (188, 340), (185, 378), (175, 410), (156, 431), (131, 439), (106, 433),
                       (89, 414), (83, 386), (82, 350), (79, 310), (74, 270), (68, 232), (60, 204)])
    return unary_union([body, toes]).buffer(4, join_style="round").buffer(-4, join_style="round").intersection(
        Polygon([(-50, 0), (400, 0), (400, 440), (-50, 440)]))


def edge_strip(sil, w):
    return sil.difference(sil.buffer(-w))


def across(t, off0, off1):
    """Lengthwise strip of a toe between two sideways offsets (+ toward the big-toe side)."""
    return Polygon([at(t, -1, off0), at(t, 2, off0), at(t, 2, off1), at(t, -1, off1)]).buffer(0)


def box(x0, y0, x1, y1):
    return Polygon([(x0, y0), (x1, y0), (x1, y1), (x0, y1)])


def crease(pts):
    return line_d(pts)


def toe_crease(t, s, k=0.75):
    r = TOES[t][3][1] if s > 0.2 else TOES[t][3][0]
    return crease([at(t, s, -r * k), at(t, s + 0.015, 0), at(t, s, r * k)])


def sole_zones(sil):
    Z = []
    digits = {t: digit(t).intersection(sil) for t in TOES}
    medial = edge_strip(sil, 7).intersection(Polygon([(192, 80), (260, 80), (260, 440), (150, 440), (172, 300), (184, 200), (192, 140)])).intersection(box(0, 94, 300, 424))
    spine = {
        "sole-cervical": medial.intersection(box(0, 94, 300, 136)),
        "sole-thoracic": medial.intersection(box(0, 136, 300, 252)),
        "sole-lumbar": medial.intersection(box(0, 252, 300, 322)),
        "sole-sacrum": medial.intersection(box(0, 322, 300, 424)),
    }
    Z += list(spine.items())
    cx, cy = at(1, pad_s(1))
    Z.append(("sole-pituitary", circle(cx + 1, cy + 2, 5)))
    pad = seg(1, NECK, 1.3)
    upper = Polygon([at(1, pad_s(1), -60), at(1, pad_s(1), 60), at(1, 2, 60), at(1, 2, -60)])
    Z.append(("sole-nose", pad.intersection(across(1, 12.5, 60))))
    Z.append(("sole-trigeminal", pad.intersection(across(1, -60, -11)).intersection(upper)))
    Z.append(("sole-cerebellum", pad.intersection(across(1, -60, -11)).difference(upper)))
    Z.append(("sole-brain", pad))
    Z.append(("sole-neck", seg(1, 0.0, NECK)))
    Z.append(("sole-sinuses", unary_union([seg(t, NECK, 1.3) for t in (2, 3, 4, 5)])))
    Z.append(("sole-eyes", unary_union([seg(t, 0.02, NECK) for t in (2, 3)])))
    Z.append(("sole-ears", unary_union([seg(t, 0.02, NECK) for t in (4, 5)])))
    ball = sil.difference(unary_union(list(digits.values())))
    Z.append(("sole-parathyroid", ellipse(198, 152, 5, 8)))
    Z.append(("sole-thyroid", ball.intersection(Polygon([(162, 126), (215, 126), (215, 200), (162, 196)]))))
    shoulder = edge_strip(sil, 10).intersection(box(0, 180, 84, 222))
    Z.append(("sole-shoulder", shoulder))
    Z.append(("sole-elbow", edge_strip(sil, 7).intersection(box(0, 256, 90, 292))))
    Z.append(("sole-knee", edge_strip(sil, 7).intersection(box(0, 330, 100, 368))))
    crease_line = [(166, 140), (146, 148), (122, 156), (100, 167), (80, 182), (58, 198)]
    t2 = [(x, y + 12) for x, y in crease_line]
    Z.append(("sole-trapezius", ball.intersection(side_of(crease_line, 1)).intersection(side_of(t2, -1)).intersection(box(0, 0, 162, 400))))
    lb = [(166, 212), (136, 216), (106, 222), (78, 228), (56, 232)]
    Z.append(("sole-lungs", ball.intersection(side_of(t2, 1)).intersection(side_of(lb, -1)).intersection(
        smooth([(40, 200), (100, 160), (158, 150), (164, 180), (160, 214), (100, 240), (40, 240)]))))
    arch = ball.intersection(side_of(lb, 1))
    Z.append(("sole-solar-plexus", arch.intersection(ellipse(140, 231, 14, 10))))
    Z.append(("sole-adrenal", arch.intersection(circle(141, 250, 6))))
    kidney = ellipse(137, 271, 12.5, 18, -12)
    Z.append(("sole-kidneys", arch.intersection(kidney)))
    Z.append(("sole-stomach", arch.intersection(smooth([(160, 202), (184, 198), (194, 212), (188, 230), (168, 236), (157, 222)]))))
    Z.append(("sole-pancreas", arch.intersection(ellipse(174, 244, 18, 6, -8))))
    Z.append(("sole-duodenum", arch.intersection(band([(188, 250), (184, 260), (170, 264), (160, 260)], 7))))
    bladder = circle(173, 334, 10.5)
    Z.append(("sole-ureter", arch.intersection(band([(146, 288), (158, 306), (168, 324)], 5.5, cap="flat"))))
    Z.append(("sole-bladder", arch.intersection(bladder)))
    Z.append(("sole-colon", arch.intersection(band([(92, 291), (116, 290), (138, 292)], 10))))
    Z.append(("sole-small-intestine", arch.intersection(smooth([(100, 300), (130, 298), (154, 302), (158, 322), (152, 342), (124, 346), (100, 342), (96, 320)])).difference(bladder)))
    heel_line = [(60, 360), (130, 358), (200, 360)]
    Z.append(("sole-sciatic", arch.intersection(side_of(heel_line, 1)).intersection(side_of([(x, y + 11) for x, y in heel_line], -1))))
    Z.append(("sole-gonads", arch.intersection(ellipse(133, 406, 30, 21))))
    Z.append(("sole-heart", arch.intersection(smooth([(72, 230), (96, 226), (118, 232), (120, 248), (100, 256), (76, 254)])), "left"))
    Z.append(("sole-spleen", arch.intersection(ellipse(98, 270, 20, 10, -4)), "left"))
    gb = ellipse(112, 266, 7, 8)
    Z.append(("sole-gallbladder", arch.intersection(gb), "right"))
    Z.append(("sole-liver", arch.intersection(smooth([(68, 230), (100, 226), (124, 232), (126, 254), (112, 278), (84, 280), (70, 264)])), "right"))
    Z.append(("sole-appendix", arch.intersection(ellipse(93, 344, 7, 7)), "right"))
    strip = arch.intersection(band([(92, 290), (92, 342)], 12))
    Z.append(("sole-colon-asc", strip.intersection(box(0, 280, 200, 336)), "right"))
    Z.append(("sole-rectum", arch.intersection(ellipse(160, 352, 8, 6)), "left"))
    Z.append(("sole-colon-desc", strip.union(arch.intersection(band([(92, 350), (122, 352), (152, 352)], 9))), "left"))
    return Z


SOLE_POINTS = {
    "sole-yongquan": [(126, 240, 5)],
    "sole-insomnia": [(132, 380, 5.5)],
}


def top_zones(sil):
    Z = []
    big = seg(1, -0.1, 1.3)
    ip = 0.52
    Z.append(("top-jaw-upper", big.intersection(Polygon([at(1, ip, -40), at(1, ip, 40), at(1, ip + 0.1, 40), at(1, ip + 0.1, -40)]))))
    Z.append(("top-jaw-lower", big.intersection(Polygon([at(1, ip - 0.1, -40), at(1, ip - 0.1, 40), at(1, ip, 40), at(1, ip, -40)]))))
    Z.append(("top-tonsils", unary_union([ellipse(*at(1, 0.24, -8), 4.5, 7), ellipse(*at(1, 0.24, 8), 4.5, 7)])))
    Z.append(("top-throat", ellipse(176, 160, 9, 8)))
    Z.append(("top-chest-lymph", band([(163, 176), (164, 206), (166, 248)], 7)))
    Z.append(("top-balance", band([(90, 200), (94, 216), (98, 232)], 7)))
    Z.append(("top-shoulder-blade", band([(98, 236), (101, 248), (104, 258)], 11)))
    Z.append(("top-chest", smooth([(110, 190), (134, 182), (156, 180), (160, 214), (156, 250), (132, 256), (110, 254), (106, 222)])))
    dl = [(60, 268), (136, 266), (210, 264)]
    Z.append(("top-diaphragm", sil.intersection(side_of(dl, 1)).intersection(side_of([(x, y + 9) for x, y in dl], -1))))
    Z.append(("top-ribs", unary_union([ellipse(172, 294, 10, 8), ellipse(96, 298, 10, 8)])))
    Z.append(("top-lymph-upper", ellipse(94, 344, 9, 9)))
    Z.append(("top-lymph-lower", ellipse(178, 334, 9, 9)))
    fl = [(70, 352), (136, 362), (200, 350)]
    Z.append(("top-fallopian", sil.intersection(side_of(fl, 1)).intersection(side_of([(x, y + 10) for x, y in fl], -1))))
    return [(z[0], z[1].intersection(sil)) for z in Z]


TOP_POINTS = {
    "top-xingjian": [(165, 146, 5)],
    "top-taichong": [(163, 216, 5.5)],
    "top-neiting": [(134, 154, 5)],
    "top-zulinqi": [(100, 242, 5.5)],
    "top-jiexi": [(136, 372, 6)],
}


def nail(t):
    _, _, L, (_, _, r2) = TOES[t]
    w = r2 * 0.66
    s0, s1 = pad_s(t) - 0.08, 1 - 0.07 * r2 / L * 3
    return smooth([at(t, s0, -w * 0.9), at(t, s0 - 0.015, 0), at(t, s0, w * 0.9), at(t, (s0 + s1) / 2, w),
                   at(t, s1 - 0.03, w * 0.8), at(t, s1, 0), at(t, s1 - 0.03, -w * 0.8), at(t, (s0 + s1) / 2, -w)])


def chart(face):
    sole, top = silhouette(), silhouette(top=True)
    sole_tones = [("light", ellipse(134, 404, 40, 26)), ("light", ellipse(134, 184, 64, 20, -10)),
                  ("shade", ellipse(176, 292, 16, 58, -3)), ("shade", ellipse(118, 300, 30, 50))] + \
                 [("light", circle(*at(t, pad_s(t)), TOES[t][3][2] * 0.6)) for t in TOES]
    sole_guides = [toe_crease(t, 0.02, 0.85) for t in TOES] + [toe_crease(1, NECK), toe_crease(1, NECK + 0.05, 0.6)] + \
                  [toe_crease(t, NECK - 0.05, 0.6) for t in (2, 3, 4, 5)] + \
                  [crease([(58, 232), (80, 228), (106, 222), (136, 216), (164, 211)]), crease([(98, 368), (132, 364), (168, 368)])]
    top_tones = [("nail", nail(t)) for t in TOES] + [("light", ellipse(140, 240, 46, 70)), ("shade", ellipse(86, 362, 9, 13)),
                                                      ("light", ellipse(84, 360, 6, 9)), ("light", ellipse(188, 344, 6, 10))]
    top_guides = [toe_crease(t, 0.5, 0.5) for t in TOES] + [toe_crease(1, 0.47, 0.4)] + \
                 [crease([(98, 378), (136, 386), (176, 380)])]
    meta = {1: (178, 262), 2: (150, 264), 3: (132, 268), 4: (114, 270), 5: (96, 274)}
    top_bones = [line_d([at(t, -0.05), m]) for t, m in meta.items()]
    return {
        "id": "foot", "title": "Foot reflex zones", "titleZh": "足部反射区",
        "viewBox": [20, 34, 220, 412], "mirrorWidth": 260, "labelSize": 8,
        "faces": [
            face("sole", "Sole", "足底", "left", sole, sole_tones, sole_guides, [], sole_zones(sole), SOLE_POINTS),
            face("top", "Top", "足背", "left", top, top_tones, top_guides, top_bones, top_zones(top), TOP_POINTS),
        ],
    }
