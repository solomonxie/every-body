#!/usr/bin/env python3
"""Humaaans SVG parts + custom parts in the same style -> Sources/Illustrations/Art/PeopleArtData.swift.

Source: Humaaans by Pablo Stanley (humaaans.com), unpacked into tools/art/humaaans-master (gitignored).
Run: venv/bin/python scripts/art/build_art.py
Every part is normalised into its own frame and colours become tokens (skin, hair, top, …) the app recolours.
"""
import math
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LIB = ROOT / "tools/art/humaaans-master/Flat Assets/Single Pieces"
OUT = ROOT / "Sources/Illustrations/Art/PeopleArtData.swift"
NS = "{http://www.w3.org/2000/svg}"

# library colours -> tokens (the app swaps in a person's own colours)
TOKENS = {
    "#B28B67": "skin", "#997659": "skin", "#191847": "hair", "#2C2C2C": "hair",
    "#8991DC": "top", "#E4E4E4": "shoes",
}

# ---------------------------------------------------------------- affine maths

def mul(a, b):
    """a∘b for (a, b, c, d, e, f) matrices, SVG order."""
    return (a[0] * b[0] + a[2] * b[1], a[1] * b[0] + a[3] * b[1], a[0] * b[2] + a[2] * b[3],
            a[1] * b[2] + a[3] * b[3], a[0] * b[4] + a[2] * b[5] + a[4], a[1] * b[4] + a[3] * b[5] + a[5])

I = (1, 0, 0, 1, 0, 0)


def parse_transform(s):
    m = I
    for name, args in re.findall(r"(\w+)\s*\(([^)]*)\)", s or ""):
        v = [float(x) for x in re.split(r"[\s,]+", args.strip()) if x]
        if name == "translate":
            t = (1, 0, 0, 1, v[0], v[1] if len(v) > 1 else 0)
        elif name == "scale":
            t = (v[0], 0, 0, v[1] if len(v) > 1 else v[0], 0, 0)
        elif name == "rotate":
            a = math.radians(v[0])
            t = (math.cos(a), math.sin(a), -math.sin(a), math.cos(a), 0, 0)
            if len(v) == 3:
                t = mul(mul((1, 0, 0, 1, v[1], v[2]), t), (1, 0, 0, 1, -v[1], -v[2]))
        elif name == "matrix":
            t = tuple(v)
        else:
            continue
        m = mul(m, t)
    return m


def apply(m, p):
    return (m[0] * p[0] + m[2] * p[1] + m[4], m[1] * p[0] + m[3] * p[1] + m[5])

# ---------------------------------------------------------------- path parsing -> absolute M L C Z

def tokens(d):
    for t in re.findall(r"[MmLlHhVvCcSsQqTtAaZz]|-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?", d):
        yield t


def arc_to_cubics(p0, rx, ry, phi, large, sweep, p1):
    if rx == 0 or ry == 0:
        return [(p0, p1, p1)]
    rx, ry = abs(rx), abs(ry)
    cp, sp = math.cos(math.radians(phi)), math.sin(math.radians(phi))
    dx, dy = (p0[0] - p1[0]) / 2, (p0[1] - p1[1]) / 2
    x1, y1 = cp * dx + sp * dy, -sp * dx + cp * dy
    lam = x1 * x1 / (rx * rx) + y1 * y1 / (ry * ry)
    if lam > 1:
        rx, ry = rx * math.sqrt(lam), ry * math.sqrt(lam)
    num = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
    den = rx * rx * y1 * y1 + ry * ry * x1 * x1
    k = math.sqrt(max(0, num / den)) * (-1 if large == sweep else 1)
    cxp, cyp = k * rx * y1 / ry, -k * ry * x1 / rx
    cx, cy = cp * cxp - sp * cyp + (p0[0] + p1[0]) / 2, sp * cxp + cp * cyp + (p0[1] + p1[1]) / 2
    ang = lambda ux, uy, vx, vy: math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)
    t1 = ang(1, 0, (x1 - cxp) / rx, (y1 - cyp) / ry)
    dt = ang((x1 - cxp) / rx, (y1 - cyp) / ry, (-x1 - cxp) / rx, (-y1 - cyp) / ry)
    if not sweep and dt > 0:
        dt -= 2 * math.pi
    elif sweep and dt < 0:
        dt += 2 * math.pi
    n = max(1, math.ceil(abs(dt) / (math.pi / 2)))
    out, h = [], dt / n
    alpha = 4 / 3 * math.tan(h / 4)
    pt = lambda t: (cx + rx * math.cos(t) * cp - ry * math.sin(t) * sp, cy + rx * math.cos(t) * sp + ry * math.sin(t) * cp)
    der = lambda t: (-rx * math.sin(t) * cp - ry * math.cos(t) * sp, -rx * math.sin(t) * sp + ry * math.cos(t) * cp)
    for i in range(n):
        a, b = t1 + i * h, t1 + (i + 1) * h
        pa, pb, da, db = pt(a), pt(b), der(a), der(b)
        out.append(((pa[0] + alpha * da[0], pa[1] + alpha * da[1]), (pb[0] - alpha * db[0], pb[1] - alpha * db[1]), pb))
    return out


def parse_path(d):
    """-> list of segments: ('M', p) ('L', p) ('C', c1, c2, p) ('Z',)"""
    tk, out, i = list(tokens(d)), [], 0
    cur = start = (0.0, 0.0)
    last_c = last_q = None
    cmd = "M"
    num = lambda: float(tk[i])
    while i < len(tk):
        if re.match(r"[A-Za-z]", tk[i]):
            cmd = tk[i]
            i += 1
            if cmd in "Zz":
                out.append(("Z",))
                cur = start
                last_c = last_q = None
                continue
        rel = cmd.islower()
        C = cmd.upper()

        def pt(k=0):
            x, y = float(tk[i + k]), float(tk[i + k + 1])
            return (cur[0] + x, cur[1] + y) if rel else (x, y)
        if C == "M":
            cur = start = pt(); i += 2
            out.append(("M", cur)); cmd = "l" if rel else "L"; last_c = last_q = None
        elif C == "L":
            cur = pt(); i += 2; out.append(("L", cur)); last_c = last_q = None
        elif C == "H":
            x = num(); i += 1
            cur = (cur[0] + x if rel else x, cur[1]); out.append(("L", cur)); last_c = last_q = None
        elif C == "V":
            y = num(); i += 1
            cur = (cur[0], cur[1] + y if rel else y); out.append(("L", cur)); last_c = last_q = None
        elif C == "C":
            c1, c2, p = pt(0), pt(2), pt(4); i += 6
            out.append(("C", c1, c2, p)); cur = p; last_c = c2; last_q = None
        elif C == "S":
            c1 = (2 * cur[0] - last_c[0], 2 * cur[1] - last_c[1]) if last_c else cur
            c2, p = pt(0), pt(2); i += 4
            out.append(("C", c1, c2, p)); cur = p; last_c = c2; last_q = None
        elif C in "QT":
            if C == "Q":
                q, p = pt(0), pt(2); i += 4
            else:
                q = (2 * cur[0] - last_q[0], 2 * cur[1] - last_q[1]) if last_q else cur
                p = pt(0); i += 2
            c1 = (cur[0] + 2 / 3 * (q[0] - cur[0]), cur[1] + 2 / 3 * (q[1] - cur[1]))
            c2 = (p[0] + 2 / 3 * (q[0] - p[0]), p[1] + 2 / 3 * (q[1] - p[1]))
            out.append(("C", c1, c2, p)); cur = p; last_q = q; last_c = None
        elif C == "A":
            rx, ry, phi, la, sw = (float(tk[i + k]) for k in range(5))
            i += 5
            p = pt(0); i += 2
            for c1, c2, e in arc_to_cubics(cur, rx, ry, phi, la != 0, sw != 0, p):
                out.append(("C", c1, c2, e))
            cur = p; last_c = last_q = None
        else:
            i += 1
    return out


def polygon(points):
    v = [float(x) for x in re.split(r"[\s,]+", points.strip()) if x]
    pts = list(zip(v[0::2], v[1::2]))
    return [("M", pts[0])] + [("L", p) for p in pts[1:]] + [("Z",)]


def ellipse_segs(cx, cy, rx, ry):
    d = f"M{cx - rx},{cy} A{rx},{ry} 0 1 0 {cx + rx},{cy} A{rx},{ry} 0 1 0 {cx - rx},{cy} Z"
    return parse_path(d)


def transform(segs, m):
    return [(s[0],) + tuple(apply(m, p) for p in s[1:]) for s in segs]


def fmt(v):
    s = f"{v:.3f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def emit(segs):
    out, prev = [], None
    for s in segs:
        c = s[0]
        nums = " ".join(f"{fmt(p[0])} {fmt(p[1])}" for p in s[1:])
        out.append(c if c == "Z" else (nums if c == prev and c != "M" else f"{c}{nums}"))
        prev = c
    return " ".join(out).replace(" -", "-")

# ---------------------------------------------------------------- reading library SVGs

def layers(svg_path):
    """flatten an SVG into [(segments, colour, opacity, group ids)] in paint order"""
    root = ET.parse(svg_path).getroot()
    out = []

    def walk(el, m, fill, op, ids):
        m = mul(m, parse_transform(el.get("transform")))
        fill = el.get("fill", fill)
        op = float(el.get("fill-opacity", op))
        ids = ids + [el.get("id", "")]
        tag = el.tag.replace(NS, "")
        segs = None
        if tag == "path":
            segs = parse_path(el.get("d"))
        elif tag == "polygon":
            segs = polygon(el.get("points"))
        elif tag == "circle":
            segs = ellipse_segs(float(el.get("cx")), float(el.get("cy")), float(el.get("r")), float(el.get("r")))
        elif tag == "ellipse":
            segs = ellipse_segs(float(el.get("cx")), float(el.get("cy")), float(el.get("rx")), float(el.get("ry")))
        elif tag == "rect":
            x, y, w, h = (float(el.get(k, 0)) for k in ("x", "y", "width", "height"))
            segs = [("M", (x, y)), ("L", (x + w, y)), ("L", (x + w, y + h)), ("L", (x, y + h)), ("Z",)]
        if segs is not None and fill and fill != "none":
            out.append((transform(segs, m), fill.upper(), op, ids))
        for ch in el:
            walk(ch, m, fill, op, ids)
    walk(root, I, None, 1.0, [])
    return out


def token(colour, op):
    if colour == "#000000":
        return f"shade{fmt(op)}"
    if colour == "#FFFFFF":
        return f"light{fmt(op)}"
    return TOKENS.get(colour, "top")


def frame(ox, oy, unit, angle=0.0, flip=False):
    """library coords -> part frame: origin (ox, oy), x along `angle` (radians), scaled by 1/unit"""
    c, s = math.cos(-angle), math.sin(-angle)
    rot = (c, s, -s, c, 0, 0)
    m = mul((1 / unit, 0, 0, (-1 if flip else 1) / unit, 0, 0), mul(rot, (1, 0, 0, 1, -ox, -oy)))
    return m

# ---------------------------------------------------------------- parts

parts = {}   # id -> [(layer, token, d)]
notes = {}


def add(pid, layer, tok, segs):
    parts.setdefault(pid, []).append((layer, tok, emit(segs)))


# Profile heads: skull centre = origin, unit = skull half-height, face toward +x, neck included (runs to y ≈ 2).
HEAD = frame(76, 55.5, 24.5)
HEADS = {"short": "Short 1", "short2": "Short 2", "caesar": "Caesar", "long": "Long", "pony": "Pony", "bun": "Top",
         "curly": "Curly", "afro": "Afro", "bald": "No Hair", "beard": "Short Beard", "wavy": "Wavy"}
for pid, name in HEADS.items():
    seen_skin = False
    for segs, col, op, ids in layers(LIB / "Head/Front" / f"{name}.svg"):
        tok = token(col, op)
        if tok == "skin":
            seen_skin = True
            add(f"side.{pid}", "skin", tok, transform(segs, HEAD))
        else:
            add(f"side.{pid}", "front" if seen_skin else "back", tok, transform(segs, HEAD))

# Hand: the reaching hand of "Body/Long Sleeve" (first skin sub-path, from the wrist on).
# Frame: wrist centre = origin, x toward the hand's middle, unit = hand length, thumb on +y.
segs, *_ = next(l for l in layers(LIB / "Body/Long Sleeve.svg") if l[1] == "#997659")
sub = []
for s in segs:
    if s[0] == "M" and sub:
        break
    sub.append(s)
# keep from the wrist point (231.48, 59.93) round the hand back to (231.12, 70.30)
pts = [s for s in sub if s[0] in "LC"]
start = next(k for k, s in enumerate(pts) if s[-1][0] > 231 and s[-1][1] < 61)
end = next(k for k, s in enumerate(pts) if k > start and abs(s[-1][0] - 231.12) < 0.1)
hand = [("M", pts[start][-1])] + pts[start + 1:end + 1] + [("Z",)]
wrist = ((pts[start][-1][0] + pts[end][-1][0]) / 2, (pts[start][-1][1] + pts[end][-1][1]) / 2)
xs = [p for s in hand for p in s[1:]]
mid = (sum(p[0] for p in xs) / len(xs), sum(p[1] for p in xs) / len(xs))
ang = math.atan2(mid[1] - wrist[1], mid[0] - wrist[0])
probe = transform(hand, frame(wrist[0], wrist[1], 1, ang))
length = max(p[0] for s in probe for p in s[1:])
wide = frame(wrist[0], wrist[1], length, ang)
lobe = apply(wide, (251.2, 69.3))
add("hand.open", "skin", "skin", transform(hand, frame(wrist[0], wrist[1], length, ang, flip=lobe[1] < 0)))
notes["hand.open"] = f"wrist width {abs(apply(wide, (231.48, 59.93))[1] - apply(wide, (231.12, 70.30))[1]):.2f} of hand length"

# Shoes: ankle (top of the heel) = origin, x toward the toe, y toward the sole, unit = shoe length.
for pid, file, gid in [("shoe.pointy", "Bottom/Standing/Skinny Jeans.svg", "Flat-Pointy"),
                       ("shoe.sneaker", "Bottom/Standing/Shorts.svg", "Flat-Sneaker")]:
    root = ET.parse(LIB / file).getroot()
    g = next(e for e in root.iter(NS + "g") if e.get("id", "").endswith(gid))
    p = next(g.iter(NS + "path"))
    local = parse_path(p.get("d"))
    add(pid, "shoe", "shoes", transform(local, frame(11, 20, 61)))

# ---------------------------------------------------------------- custom parts, same style (flat fills, no lines)
# Drawn by hand for poses the library lacks; frames as above. CC0 like the library.

CUSTOM = {
    # baby: bare profile head, one soft curl on the crown
    "side.baby": [
        ("skin", "skin", "M-0.95 0.1 C-1.05-0.6-0.55-1.02 0.05-1.02 C0.62-1.02 0.98-0.62 0.98-0.1 C0.98 0.12 1.08 0.26 1.02 0.38 "
                         "C0.98 0.66 0.78 0.92 0.4 0.98 L0.1 1.0 L0.1 1.5 L-0.5 1.5 L-0.5 0.8 C-0.8 0.62-0.92 0.4-0.95 0.1 Z"),
        ("front", "hair", "M-0.2-1.0 C-0.05-1.28 0.34-1.3 0.38-1.08 C0.22-1.16 0.06-1.1 0.02-0.98 Z"),
        ("front", "hair", "M-0.92-0.1 C-0.95-0.62-0.55-0.98-0.05-1.0 C-0.45-0.88-0.7-0.56-0.72-0.12 Z"),
    ],
    # face-on heads for people facing us: skull + neck, unit = skull half-height, featureless like the library
    "front.skull": [
        ("neck", "skin", "M-0.3 0.6 L-0.32 2.0 L0.32 2.0 L0.3 0.6 Z"),
        ("neck", "shade0.1", "M-0.31 0.78 C-0.2 1.02 0.2 1.02 0.31 0.78 L0.32 1.1 C0.2 1.28-0.2 1.28-0.32 1.1 Z"),
        ("skin", "skin", "M0-1 C0.5-1 0.8-0.62 0.8-0.1 C0.8 0.4 0.58 0.82 0.3 0.96 C0.12 1.04-0.12 1.04-0.3 0.96 "
                         "C-0.58 0.82-0.8 0.4-0.8-0.1 C-0.8-0.62-0.5-1 0-1 Z"),
        ("skin", "skin", "M-0.78 0.02 C-0.98-0.02-1.0 0.36-0.76 0.4 Z M0.78 0.02 C0.98-0.02 1.0 0.36 0.76 0.4 Z"),
    ],
    "front.short": [("front", "hair", "M-0.84 0.08 C-0.98-0.66-0.62-1.24 0.04-1.26 C0.66-1.28 1.02-0.84 0.86 0.02 "
                                      "C0.82-0.3 0.72-0.46 0.56-0.54 C0.18-0.44-0.28-0.52-0.52-0.72 C-0.62-0.44-0.72-0.2-0.84 0.08 Z")],
    "front.short2": [("front", "hair", "M-0.84 0.1 C-0.96-0.7-0.56-1.16 0.02-1.18 C0.6-1.2 0.98-0.8 0.84 0.1 "
                                       "C0.8-0.32 0.64-0.56 0.4-0.62 L0.1-0.5 L-0.12-0.64 C-0.5-0.6-0.74-0.36-0.84 0.1 Z")],
    "front.caesar": [("front", "hair", "M-0.82-0.06 C-0.9-0.72-0.52-1.08 0-1.08 C0.52-1.08 0.9-0.72 0.82-0.06 "
                                       "C0.78-0.42 0.6-0.64 0.36-0.7 C0.12-0.64-0.16-0.64-0.46-0.7 C-0.66-0.56-0.78-0.34-0.82-0.06 Z")],
    "front.bald": [],
    "front.long": [
        ("back", "hair", "M-0.9-0.4 C-1.06 0.4-0.98 1.4-1.1 1.9 L1.1 1.9 C0.98 1.4 1.06 0.4 0.9-0.4 Z"),
        ("front", "hair", "M0-1.12 C-0.7-1.12-1.0-0.62-0.92 0.1 C-0.9 0.5-0.94 1.0-1.0 1.36 L-0.68 1.36 C-0.72 0.7-0.7 0.0-0.6-0.42 "
                          "C-0.38-0.6-0.14-0.72 0-0.9 C0.14-0.72 0.38-0.6 0.6-0.42 C0.7 0.0 0.72 0.7 0.68 1.36 L1.0 1.36 "
                          "C0.94 1.0 0.9 0.5 0.92 0.1 C1.0-0.62 0.7-1.12 0-1.12 Z"),
    ],
    "front.bun": [
        ("back", "hair", "M-0.4-1.3 A0.4 0.36 0 1 0 0.4-1.3 A0.4 0.36 0 1 0-0.4-1.3 Z"),
        ("front", "hair", "M-0.84 0 C-0.94-0.72-0.52-1.1 0-1.1 C0.52-1.1 0.94-0.72 0.84 0 C0.78-0.4 0.5-0.64 0-0.68 C-0.5-0.64-0.78-0.4-0.84 0 Z"),
    ],
    "front.pony": [
        ("back", "hair", "M0.7-0.5 C1.3-0.7 1.5-0.1 1.2 0.5 C1.1 0.1 0.9-0.1 0.7-0.2 Z"),
        ("front", "hair", "M-0.84 0 C-0.94-0.72-0.52-1.1 0-1.1 C0.52-1.1 0.94-0.72 0.84 0 C0.78-0.4 0.5-0.64 0-0.68 C-0.5-0.64-0.78-0.4-0.84 0 Z"),
    ],
    "front.curly": [
        ("back", "hair", "M-1.0-0.1 A0.42 0.42 0 0 1-0.8-0.9 A0.45 0.45 0 0 1 0-1.3 A0.45 0.45 0 0 1 0.8-0.9 A0.42 0.42 0 0 1 1.0-0.1 "
                         "A0.3 0.3 0 0 1 0.86 0.4 L-0.86 0.4 A0.3 0.3 0 0 1-1.0-0.1 Z"),
        ("front", "hair", "M-0.84-0.1 C-0.84-0.5-0.6-0.66-0.4-0.62 A0.2 0.2 0 0 1 0-0.7 A0.2 0.2 0 0 1 0.4-0.62 "
                          "C0.6-0.66 0.84-0.5 0.84-0.1 L0.9-0.6 L0-1.1 L-0.9-0.6 Z"),
    ],
    "front.afro": [
        ("back", "hair", "M-1.3-0.3 A1.3 1.12 0 1 1 1.3-0.3 C1.3 0.2 1.1 0.5 0.8 0.6 L-0.8 0.6 C-1.1 0.5-1.3 0.2-1.3-0.3 Z"),
        ("front", "hair", "M-0.82-0.1 C-0.82-0.46-0.5-0.62 0-0.62 C0.5-0.62 0.82-0.46 0.82-0.1 L0.9-0.7 L0-1.1 L-0.9-0.7 Z"),
    ],
    "front.baby": [
        ("front", "hair", "M-0.1-0.98 C-0.05-1.25 0.25-1.3 0.3-1.12 C0.15-1.2 0.05-1.1 0.06-0.97 Z"),
    ],
    # hands (frame of hand.open): fist, fingers laced over the other hand, two fingers, hand round a small chest, thumb press
    "hand.fist": [("skin", "skin", "M0-0.3 C0.25-0.42 0.66-0.4 0.76-0.12 C0.84 0.12 0.68 0.36 0.4 0.36 C0.2 0.36 0.06 0.3 0 0.28 Z "
                                   "M0.2 0.2 C0.36 0.28 0.52 0.44 0.46 0.56 C0.38 0.62 0.2 0.46 0.12 0.32 Z")],
    "hand.laced": [("skin", "skin", "M0-0.3 C0.28-0.44 0.72-0.42 0.86-0.16 C0.96 0.06 0.86 0.3 0.62 0.36 C0.4 0.4 0.12 0.34 0 0.28 Z"),
                   ("skin", "shade0.12", "M0.5-0.26 L0.8-0.18 L0.8-0.12 L0.5-0.2 Z M0.5-0.06 L0.84 0 L0.84 0.06 L0.5 0 Z M0.5 0.14 L0.78 0.2 L0.76 0.26 L0.5 0.2 Z")],
    "hand.twoFingers": [("skin", "skin", "M0-0.3 C0.2-0.4 0.5-0.4 0.58-0.2 L1.0-0.2 C1.06-0.18 1.06-0.06 1.0-0.04 L0.6-0.02 L0.96 0.02 "
                                         "C1.02 0.04 1.02 0.16 0.96 0.18 L0.56 0.2 C0.5 0.32 0.3 0.38 0.16 0.34 C0.1 0.32 0.04 0.3 0 0.28 Z")],
    # fingers wrapped round a small chest, the thumb forward along the breastbone
    "hand.encircle": [("skin", "skin", "M0-0.24 C0.3-0.34 0.72-0.32 0.9-0.2 C1.0-0.12 1.0 0.04 0.9 0.1 C0.7 0.2 0.3 0.24 0 0.2 Z"),
                      ("skin", "shade0.12", "M0.7-0.12 L0.94-0.1 L0.94-0.06 L0.7-0.08 Z M0.7 0.02 L0.92 0.02 L0.92 0.06 L0.7 0.06 Z"),
                      ("skin", "skin", "M0.1 0.12 C0.3 0.16 0.6 0.24 0.74 0.3 C0.8 0.34 0.78 0.42 0.7 0.42 C0.5 0.42 0.24 0.38 0.08 0.3 Z")],
    "hand.thumb": [("skin", "skin", "M0-0.3 C0.25-0.42 0.62-0.4 0.72-0.14 C0.8 0.1 0.66 0.32 0.4 0.34 L0.98 0.26 C1.06 0.26 1.06 0.4 0.98 0.42 "
                                    "L0.3 0.44 C0.16 0.4 0.06 0.32 0 0.28 Z")],
}
for pid, ls in CUSTOM.items():
    parts.setdefault(pid, [])
    for layer, tok, d in ls:
        add(pid, layer, tok, parse_path(d))

# ---------------------------------------------------------------- write Swift

lines = ["// Generated by scripts/art/build_art.py — do not edit.",
         "// Humaaans by Pablo Stanley (humaaans.com, CC0; earlier releases CC BY 4.0) + custom parts in the same style.",
         "",
         "extension PeopleArt {",
         "    /// part id → layers \"layer|token|path\"",
         "    static let data: [String: [String]] = ["]
for pid in sorted(parts):
    items = ",\n".join(f'            "{l}|{t}|{d}"' for l, t, d in parts[pid])
    lines.append(f'        "{pid}": [\n{items}\n        ],' if items else f'        "{pid}": [],')
lines += ["    ]", "}", ""]
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text("\n".join(lines))
print(f"{OUT.relative_to(ROOT)}: {len(parts)} parts, {OUT.stat().st_size / 1024:.1f} KB")
for k, v in notes.items():
    print(k, v, file=sys.stderr)
