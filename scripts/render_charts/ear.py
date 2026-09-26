"""Ear chart: left outer ear, face to the left. Areas and points follow GB/T 13734-2008."""
import math

from shapely.geometry import LineString, Point, Polygon
from shapely.ops import unary_union

from geom import band, circle, ellipse, line_d, side_of, slices, smooth, smooth_d, taper

C = (150, 172)  # centre for cutting the helix and scapha by angle

OUTLINE = [(76, 126), (80, 86), (98, 50), (128, 24), (164, 14), (198, 24), (223, 54), (237, 98), (240, 146), (234, 196),
           (222, 244), (206, 284), (196, 318), (186, 350), (166, 378), (140, 390), (114, 382), (96, 360), (88, 330), (84, 304),
           (74, 290), (62, 276), (52, 254), (49, 226), (54, 204), (64, 191), (70, 172), (72, 148)]
HELIX_FOLD = [(84, 134), (90, 100), (106, 68), (132, 46), (164, 37), (194, 45), (214, 70), (224, 104), (226, 146), (220, 192),
              (208, 238), (194, 276), (184, 298)]
AH_BODY = [(160, 276, 10), (182, 238, 11), (194, 200, 11), (198, 164, 10.5), (192, 128, 9.5)]
AH_SUP = [(192, 128, 9.5), (186, 100, 9), (174, 78, 8.5), (158, 62, 7.5), (142, 54, 6.5)]
AH_INF = [(192, 128, 8), (165, 116, 7), (135, 106, 6), (104, 100, 5)]
CRUS = [(70, 136, 7.5), (90, 147, 6.5), (108, 155, 5), (124, 160, 3.5)]
TRAGUS = [(52, 206), (64, 196), (75, 204), (81, 228), (78, 254), (67, 270), (55, 262), (50, 234)]
ANTITRAGUS = [(100, 276), (116, 264), (140, 256), (160, 260), (168, 272), (152, 286), (124, 292), (104, 288)]


def xy(p):
    return p[0], p[1]


def wedge(a0, a1):
    pts = [C]
    for k in range(25):
        a = math.radians(a0 + (a1 - a0) * k / 24)
        pts.append((C[0] + 600 * math.cos(a), C[1] + 600 * math.sin(a)))
    return Polygon(pts).buffer(0)


def angle_point(a, r_from_edge, sil):
    """Point on the ray at angle a, r inside the outer edge."""
    ray = LineString([C, (C[0] + 600 * math.cos(math.radians(a)), C[1] + 600 * math.sin(math.radians(a)))])
    hit = ray.intersection(sil.exterior)
    p = hit if hit.geom_type == "Point" else min(hit.geoms, key=lambda g: g.distance(Point(C)))
    d = math.hypot(p.x - C[0], p.y - C[1])
    return (C[0] + (d - r_from_edge) * math.cos(math.radians(a)), C[1] + (d - r_from_edge) * math.sin(math.radians(a)))


def left_of(pts, far=300):
    """Region on the face side (−x) of a roughly vertical polyline."""
    c = [xy(p) for p in pts]
    return Polygon(c + [(c[-1][0] - far, c[-1][1]), (c[0][0] - far, c[0][1])]).buffer(0)


def build():
    sil = smooth(OUTLINE)
    lobe_line = [(60, 300), (120, 298), (210, 292)]
    lobule = sil.intersection(side_of(lobe_line, 1))
    inner = smooth(HELIX_FOLD + [(170, 300), (120, 302), (80, 300), (58, 250), (62, 190), (74, 150)]).intersection(sil)
    helix = sil.difference(inner).difference(lobule)
    crus = taper(CRUS).intersection(sil)
    tragus = smooth(TRAGUS).intersection(sil)
    antitragus = smooth(ANTITRAGUS).difference(lobule)
    body = taper(AH_BODY)
    sup = taper(AH_SUP)
    inf = taper(AH_INF)
    antihelix = unary_union([body, sup, inf]).intersection(inner)
    back = Polygon([(142, 54), (158, 62), (174, 78), (186, 100), (192, 128), (198, 164), (194, 200), (182, 238), (160, 276),
                    (200, 330), (320, 330), (320, -20), (120, -20)])
    scapha = inner.intersection(back).difference(antihelix)
    tf = inner.intersection(Polygon([(80, 104), (96, 50), (128, 44), (150, 56), (192, 128), (165, 116), (106, 100)])).difference(
        unary_union([antihelix, scapha]))
    concha = inner.difference(unary_union([antihelix, scapha, tf, tragus, antitragus, crus, lobule]))
    split = side_of([(40, 150), (70, 138), (96, 150), (124, 160), (150, 168), (200, 172)], -1)
    cymba = concha.intersection(split)
    cavum = concha.difference(split)
    return dict(sil=sil, lobule=lobule, inner=inner, helix=helix, crus=crus, tragus=tragus, antitragus=antitragus,
                body=body.intersection(inner), sup=sup.intersection(inner).difference(body), inf=inf.intersection(inner).difference(body),
                antihelix=antihelix, scapha=scapha, tf=tf, cymba=cymba, cavum=cavum, concha=concha)


def zones(a):
    Z = []
    # helix, by angle round the ear
    helix = a["helix"]
    Z.append(("ear-center", a["crus"]))
    for zid, a0, a1 in (("ear-rectum", -160, -148), ("ear-urethra", -148, -137), ("ear-ext-genitals", -137, -124),
                        ("ear-anus", -124, -110), ("ear-helix", -28, 68)):
        Z.append((zid, helix.intersection(wedge(a0, a1))))
    # scapha: six equal steps top to bottom
    sc = a["scapha"]
    edges = [-76 + k * 22.5 for k in range(7)]
    for zid, i0, i1 in (("ear-finger", 0, 1), ("ear-wrist", 1, 2), ("ear-elbow", 2, 3), ("ear-shoulder", 3, 5), ("ear-clavicle", 5, 6)):
        Z.append((zid, sc.intersection(wedge(edges[i0], edges[i1]))))
    # superior crus: hip, knee, then ankle below heel (front) and toe (back)
    sup = a["sup"]
    axis = [xy(p) for p in AH_SUP]
    sax = [(196, 146)] + axis[1:] + [(126, 50)]
    hip, knee, top = slices(sup, sax, [0, 0.36, 0.64, 1.0])
    ankle, upper = slices(top, sax, [0.64, 0.8, 1.0])
    front = side_of([(120, 40), (150, 58), (170, 90)], 1)
    Z += [("ear-hip", hip), ("ear-knee", knee), ("ear-ankle", ankle), ("ear-heel", upper.intersection(front)), ("ear-toe", upper.difference(front))]
    # inferior crus: sciatic front 2/3, gluteal back 1/3
    inf = a["inf"]
    ax = [(94, 98), (104, 100), (135, 106), (165, 116), (192, 128)]
    sciatic, gluteal = slices(inf, ax, [0, 0.64, 1.0])
    Z += [("ear-sciatic", sciatic), ("ear-gluteal", gluteal)]
    # antihelix body: 2/5, 2/5, 1/5 top to bottom; front quarter is trunk, back is spine
    body = a["body"]
    bax = [(190, 114), (192, 128), (198, 164), (194, 200), (182, 238), (160, 276), (150, 292)]
    upper_b, middle_b, lower_b = slices(body, bax, [0.08, 0.44, 0.8, 1.0])
    trunk = left_of([(186, 114), (188, 128), (193, 164), (189, 200), (177, 238), (155, 274), (146, 290)])
    for zid, zid2, piece in (("ear-abdomen", "ear-lumbosacral", upper_b), ("ear-chest", "ear-thoracic", middle_b), ("ear-neck", "ear-cervical", lower_b)):
        Z.append((zid, piece.intersection(trunk)))
        Z.append((zid2, piece.difference(trunk)))
    # triangular fossa: thirds front to back, outer thirds split top and bottom
    tf = a["tf"]
    t1, t2, t3 = slices(tf, [(88, 84), (116, 80), (150, 86), (190, 112)], [0, 0.36, 0.64, 1.0])

    def upper_half(g):
        c = g.centroid
        return g.intersection(side_of([(c.x - 60, c.y - 19), (c.x + 60, c.y + 19)], -1))
    Z += [("ear-tf-upper", upper_half(t1)), ("ear-genitals", t1), ("ear-tf-middle", t2),
          ("ear-shenmen", upper_half(t3)), ("ear-pelvis", t3)]
    # tragus: outer face upper/lower; inner edge (toward the canal) throat/inner nose
    tr = a["tragus"]
    inner_edge = tr.difference(tr.buffer(-4.5)).intersection(Polygon([(70, 190), (100, 190), (100, 280), (62, 280)]))
    top_half = side_of([(40, 233), (90, 235)], -1)
    Z += [("ear-throat", inner_edge.intersection(top_half)), ("ear-inner-nose", inner_edge.difference(top_half)),
          ("ear-upper-tragus", tr.intersection(top_half)), ("ear-lower-tragus", tr.difference(top_half))]
    # antitragus: inner rim is subcortex; outer face forehead, temple, occiput front to back
    at = a["antitragus"]
    rim = at.difference(at.buffer(-5)).intersection(side_of([(90, 280), (130, 268), (170, 274)], -1))
    Z.append(("ear-subcortex", rim))
    Z += [("ear-forehead", at.intersection(Polygon([(0, 0), (122, 0), (122, 400), (0, 400)]))),
          ("ear-temple", at.intersection(Polygon([(122, 0), (144, 0), (144, 400), (122, 400)]))),
          ("ear-occiput", at.intersection(Polygon([(144, 0), (300, 0), (300, 400), (144, 400)])))]
    # concha around the helix crus
    cav, cym = a["cavum"], a["cymba"]
    concha = a["concha"]
    Z.append(("ear-stomach", concha.intersection(ellipse(132, 164, 10, 9))))
    under = cav.intersection(side_of([(60, 164), (90, 160), (124, 170)], -1))
    Z += [("ear-mouth", under.intersection(Polygon([(0, 0), (96, 0), (96, 400), (0, 400)]))),
          ("ear-esophagus", under.intersection(Polygon([(96, 0), (110, 0), (110, 400), (96, 400)]))),
          ("ear-cardia", under.intersection(Polygon([(110, 0), (126, 0), (126, 400), (110, 400)])))]
    # cymba: upper row under the inferior crus, lower row above the helix crus
    row = side_of([(90, 126), (130, 130), (196, 142)], -1)
    up, low = cym.intersection(row), cym.difference(row)
    cols = lambda g, x0, x1: g.intersection(Polygon([(x0, 0), (x1, 0), (x1, 400), (x0, 400)]))
    Z += [("ear-cymba-angle", cols(up, 0, 116)), ("ear-bladder", cols(up, 116, 140)), ("ear-kidney", cols(up, 140, 164)),
          ("ear-pancreas", cols(up, 164, 300)), ("ear-large-intestine", cols(low, 0, 122)), ("ear-small-intestine", cols(low, 122, 144)),
          ("ear-duodenum", cols(low, 144, 164)), ("ear-liver", cols(low, 164, 300))]
    # cavum
    Z += [("ear-heart", cav.intersection(circle(124, 212, 9.5))),
          ("ear-trachea", cav.intersection(ellipse(102, 212, 7, 6))),
          ("ear-spleen", cav.intersection(ellipse(170, 188, 14, 12, 20))),
          ("ear-endocrine", cav.intersection(ellipse(96, 262, 12, 7, -10))),
          ("ear-sanjiao", cav.intersection(ellipse(106, 244, 8, 7))),
          ("ear-lung", cav)]
    # lobule: three rows of three squares
    lb = a["lobule"]
    x0, y0, x1, y1 = lb.bounds
    y0 = 298
    xs = [x0 + (x1 - x0) * k / 3 for k in range(4)]
    ys = [y0 + (y1 - y0) * k / 3 for k in range(4)]
    cell = lambda i, j: lb.intersection(Polygon([(xs[i], ys[j]), (xs[i + 1], ys[j]), (xs[i + 1], ys[j + 1]), (xs[i], ys[j + 1])]))
    Z += [("ear-teeth", cell(0, 0)), ("ear-tongue", cell(1, 0)), ("ear-jaw", cell(2, 0)),
          ("ear-lobe-front", cell(0, 1)), ("ear-eye", cell(1, 1)), ("ear-inner-ear", cell(2, 1)),
          ("ear-tonsil", lb.intersection(Polygon([(0, ys[2]), (300, ys[2]), (300, 400), (0, 400)])))]
    return Z, (xs, ys)


def points(a, grid):
    sil = a["sil"]
    xs, ys = grid
    apex = angle_point(-96, 7, sil)
    return {
        "ear-apex": [(*apex, 5)],
        "ear-sympathetic": [(99, 99, 4.5)],
        "ear-wind-stream": [(*angle_point(-60, 24, sil), 4)],
        "ear-tragus-apex": [(64, 200, 4)],
        "ear-adrenal": [(67, 263, 4)],
        "ear-nose": [(59, 232, 4)],
        "ear-antitragus-apex": [(140, 262, 4)],
        "ear-brainstem": [(166, 268, 4)],
        "ear-ureter": [(140, 127, 3.5)],
        "ear-appendix": [(122, 146, 3.5)],
        "ear-cheek": [(xs[2], (ys[1] + ys[2]) / 2, 4)],
    }


def chart(face):
    a = build()
    Z, grid = zones(a)
    sil = a["sil"]
    rim = sil.difference(sil.buffer(-5)).difference(a["lobule"])
    tones = [("deep", a["concha"].buffer(1)), ("deep", ellipse(88, 226, 7, 14, 6)), ("deep", ellipse(86, 280, 9, 5)),
             ("shade", a["scapha"]), ("shade", a["tf"]), ("shade", a["inner"].difference(a["inner"].buffer(-4))),
             ("light", rim), ("light", band([xy(p) for p in AH_BODY[::-1]] + [xy(p) for p in AH_SUP[1:]], 5)), ("light", band([xy(p) for p in AH_INF], 4)),
             ("light", a["tragus"].buffer(-3)), ("light", a["antitragus"].buffer(-3)), ("light", ellipse(140, 350, 26, 20))]
    outlines = [a["inner"], a["antihelix"], a["crus"], a["tragus"], a["antitragus"]]
    guides = [smooth_d(g, 4) for g in outlines]
    xs, ys = grid
    lobe = a["lobule"].buffer(-1.5)
    for seg in [LineString([(xs[0], y), (xs[3], y)]) for y in ys[1:3]] + [LineString([(x, ys[0]), (x, ys[2])]) for x in xs[1:3]]:
        cut = seg.intersection(lobe)
        if not cut.is_empty and cut.geom_type == "LineString":
            guides.append(line_d(list(cut.coords)))
    return {
        "id": "ear", "title": "Ear points", "titleZh": "耳穴",
        "viewBox": [10, 4, 240, 392], "mirrorWidth": 260, "labelSize": 7.5,
        "faces": [face("outer", "Outer ear", "耳廓", "left", sil, tones, guides, [], Z, points(a, grid))],
    }
