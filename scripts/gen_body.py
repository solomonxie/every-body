"""Generate Resources/Data/body.json (and body-anchored positions in points/charts) from anatomy.

Everything is schematic geometry placed on real adult landmarks (1.75 m standing male,
anatomical position: palms forward). Written in metres, converted to scene units.
Axes: y up, +z front, +x = the figure's left. Right-side parts are mirrored.

Run: venv/bin/python scripts/gen_body.py
"""

import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "Resources" / "Data"

SCALE = 1.86  # scene units per metre; feet at y = -1.6


def U(x, y, z):
    return [round(x * SCALE, 4), round(y * SCALE - 1.6, 4), round(z * SCALE, 4)]


def L(m):
    return round(m * SCALE, 4)


def flip(p):
    return [-p[0], p[1], p[2]]


# ---------------------------------------------------------------- shapes (metres in, units out)

def sphere(c, r, scale=None, rotation=None):
    s = {"kind": "sphere", "center": U(*c), "radius": L(r)}
    if scale:
        s["scale"] = list(scale)
    if rotation:
        s["rotation"] = list(rotation)
    return s


def segment(a, b, r):
    return {"kind": "segment", "from": U(*a), "to": U(*b), "radius": L(r)}


def spindle(a, b, r):
    return {"kind": "spindle", "from": U(*a), "to": U(*b), "radius": L(r)}


def lathe(a, b, radii, scale=None):
    """Surface of revolution from a to b; radii sampled evenly along the axis."""
    s = {"kind": "lathe", "from": U(*a), "to": U(*b), "radii": [L(r) for r in radii]}
    if scale:
        s["scale"] = list(scale)
    return s


def tube(points, r, radii=None):
    s = {"kind": "tube", "points": [U(*p) for p in points], "radius": L(r)}
    if radii:
        s["radii"] = [L(x) for x in radii]
    return s


def loft(sections, square=None):
    """Stacked ellipses along a path: (x, y, z, rx, rz) with rx sideways (world x), rz across it.
    `square` > 2 turns every section into a rounded box (superellipse exponent)."""
    def row(sec):
        x, y, z, rx, rz = sec[:5]
        sq = sec[5] if len(sec) > 5 else square
        return U(x, y, z) + [L(rx), L(rz)] + ([sq] if sq else [])
    return {"kind": "loft", "sections": [row(sec) for sec in sections]}


def plate(points, thickness):
    return {"kind": "plate", "points": [U(*p) for p in points], "thickness": L(thickness)}


def sheet(origins, insertions, bulge, thickness):
    """Flat muscle as one slab from a line of origins to its insertions."""
    return {"kind": "sheet", "origins": [U(*p) for p in origins], "insertions": [U(*p) for p in insertions],
            "bulge": [L(b) for b in bulge], "thickness": L(thickness)}


def mirror_shape(s):
    s = json.loads(json.dumps(s))
    for key in ("center", "from", "to"):
        if key in s:
            s[key] = flip(s[key])
    if "bulge" in s:
        s["bulge"] = [-s["bulge"][0]] + s["bulge"][1:]
    if "grid" in s:
        s["grid"] = [[flip(p) for p in row] for row in s["grid"]]
    for key in ("points", "origins", "insertions"):
        if key in s:
            s[key] = [flip(p) for p in s[key]]
    if "sections" in s:
        s["sections"] = [[-q[0]] + q[1:] for q in s["sections"]]
    if "rotation" in s:
        r = s["rotation"]
        s["rotation"] = [r[0], -r[1], -r[2]]
    return s


PARTS = []


def part(pid, name, zh, layer, color, shape, sex=None):
    p = {"id": pid, "name": name, "nameZh": zh, "layer": layer, "color": color, "shape": shape}
    if sex:
        p["sex"] = sex
    PARTS.append(p)
    return p


def pair(pid, name, zh, layer, color, shape, sex=None):
    """Left part as given, right part mirrored."""
    part(f"{pid}-l", f"{name} (L)", f"左{zh}", layer, color, shape, sex)
    part(f"{pid}-r", f"{name} (R)", f"右{zh}", layer, color, mirror_shape(shape), sex)


# ---------------------------------------------------------------- landmarks (metres)

SHOULDER = (0.185, 1.40, -0.03)   # glenohumeral joint
ELBOW = (0.21, 1.10, -0.015)
WRIST = (0.24, 0.85, 0.005)
HIP = (0.09, 0.925, 0.0)          # femoral head
KNEE = (0.095, 0.49, 0.0)
ANKLE = (0.085, 0.08, 0.0)

BONE = "#E9E2CF"
CARTILAGE = "#C9D6E0"
DISC = "#B9C8D8"
MUSCLE = "#C1443C"
TENDON = "#E6D3C3"
ARTERY = "#D23A3A"
VEIN = "#3A5BD9"
NERVE = "#E8B923"
SKIN = "#F2C9A5"


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


# ---------------------------------------------------------------- body surface (skin lofts, reused to lay muscles on)

TORSO = {
    "male": [(0.815, 0.0, 0.05, 0.05), (0.875, -0.016, 0.152, 0.1), (0.93, -0.016, 0.172, 0.108), (0.99, -0.006, 0.156, 0.1),
             (1.05, 0.004, 0.144, 0.094), (1.11, 0.005, 0.141, 0.095), (1.19, 0.005, 0.151, 0.1), (1.27, 0.01, 0.164, 0.108),
             (1.34, 0.005, 0.172, 0.106), (1.385, -0.006, 0.184, 0.098), (1.41, -0.012, 0.19, 0.088), (1.432, -0.018, 0.165, 0.074),
             (1.452, -0.02, 0.1, 0.06), (1.468, -0.02, 0.05, 0.045)],
    "female": [(0.815, 0.0, 0.055, 0.05), (0.875, -0.02, 0.162, 0.104), (0.93, -0.02, 0.186, 0.112), (0.99, -0.008, 0.162, 0.1),
               (1.05, 0.002, 0.128, 0.088), (1.11, 0.003, 0.125, 0.088), (1.19, 0.003, 0.136, 0.093), (1.27, 0.006, 0.15, 0.1),
               (1.34, 0.002, 0.158, 0.098), (1.385, -0.008, 0.17, 0.09), (1.41, -0.013, 0.176, 0.082), (1.432, -0.018, 0.152, 0.068),
               (1.452, -0.02, 0.094, 0.056), (1.468, -0.02, 0.046, 0.042)],
}
UPPER_ARM = [(0.182, 1.418, -0.025, 0.03, 0.034), (0.19, 1.4, -0.024, 0.048, 0.052), (0.198, 1.37, -0.022, 0.053, 0.055),
    (0.203, 1.3, -0.02, 0.045, 0.05), (0.208, 1.2, -0.017, 0.04, 0.045), (0.213, 1.12, -0.013, 0.036, 0.038),
    (0.215, 1.09, -0.012, 0.035, 0.034)]
FOREARM = [(0.214, 1.12, -0.013, 0.034, 0.033), (0.215, 1.1, -0.012, 0.036, 0.034), (0.225, 1.03, -0.008, 0.039, 0.036), (0.235, 0.94, 0.0, 0.03, 0.026),
    (0.242, 0.86, 0.006, 0.026, 0.018), (0.242, 0.845, 0.007, 0.024, 0.016)]
THIGH = [(0.09, 0.93, -0.012, 0.075, 0.085), (0.097, 0.87, -0.004, 0.082, 0.088), (0.099, 0.78, 0.008, 0.072, 0.077),
    (0.098, 0.68, 0.012, 0.062, 0.068), (0.097, 0.59, 0.012, 0.053, 0.058), (0.097, 0.52, 0.008, 0.048, 0.052),
    (0.097, 0.49, 0.008, 0.048, 0.05), (0.097, 0.465, 0.006, 0.045, 0.047)]
SHIN = [(0.097, 0.515, 0.009, 0.044, 0.046), (0.097, 0.49, 0.008, 0.047, 0.05), (0.097, 0.44, -0.006, 0.048, 0.058), (0.096, 0.38, -0.012, 0.05, 0.062),
    (0.093, 0.3, -0.008, 0.043, 0.05), (0.09, 0.22, -0.002, 0.034, 0.038), (0.087, 0.14, 0.0, 0.028, 0.03),
    (0.086, 0.085, 0.0, 0.029, 0.03), (0.087, 0.055, 0.0, 0.026, 0.028)]


def surface(sections, y, theta, k=0.965, square=2.0):
    """Point on a vertical loft at height y and angle theta (degrees; 0 = +x, 90 = front, 270 = back), scaled k toward the axis."""
    rows = sorted(sections, key=lambda r: r[1] if len(r) == 5 else r[0])
    def at(r):
        return (0.0, r[0], r[1], r[2], r[3]) if len(r) == 4 else r
    rows = [at(r) for r in rows]
    y = min(max(y, rows[0][1]), rows[-1][1])
    for a, b in zip(rows, rows[1:]):
        if a[1] <= y <= b[1]:
            t = (y - a[1]) / ((b[1] - a[1]) or 1)
            x, _, z, rx, rz = [a[n] + (b[n] - a[n]) * t for n in range(5)]
            break
    c, s_ = math.cos(math.radians(theta)), math.sin(math.radians(theta))
    e = 2 / square
    return (x + k * rx * math.copysign(abs(c) ** e, c), y, z + k * rz * math.copysign(abs(s_) ** e, s_))


def panel(sections, origin, insertion, k=0.965, square=2.0, converge=None, nu=14, nv=10, start=None):
    """Surface grid for a muscle: origin and insertion are ((y, theta), (y, theta)) edges; rows run origin → insertion.
    `converge` = (point, from_u) pulls the last rows into a tendon at that point."""
    grid = []
    for i in range(nu + 1):
        u = i / nu
        row = []
        for j in range(nv + 1):
            v = j / nv
            (oy0, ot0), (oy1, ot1) = origin
            (iy0, it0), (iy1, it1) = insertion
            y = (1 - u) * (oy0 + (oy1 - oy0) * v) + u * (iy0 + (iy1 - iy0) * v)
            th = (1 - u) * (ot0 + (ot1 - ot0) * v) + u * (it0 + (it1 - it0) * v)
            p = surface(sections, y, th, k, square)
            if start and u < start[1]:
                w = 1 - u / start[1]
                w = w * w * (3 - 2 * w)
                p = tuple(p[n] + (start[0][n] - p[n]) * w for n in range(3))
            if converge and u > converge[1]:
                w = (u - converge[1]) / (1 - converge[1])
                w = w * w * (3 - 2 * w)
                p = tuple(p[n] + (converge[0][n] - p[n]) * w for n in range(3))
            row.append(p)
        grid.append(row)
    return grid


def tubes(paths, r):
    """Several thin branches as one piece (stored under "grid")."""
    return {"kind": "tubes", "grid": [[U(*p) for p in path] for path in paths], "radius": L(r)}


def slab(grid, thickness):
    return {"kind": "slab", "grid": [[U(*p) for p in row] for row in grid], "thickness": L(thickness)}


# ---------------------------------------------------------------- skeleton

RIBS = []


def skeleton():
    # skull: rounded cranium; a separate mid-face (cheekbones, upper jaw) in front of it, so the face can be
    # narrower and flatter than the braincase
    part("skull", "Skull (cranium)", "颅骨", "skeletal", BONE,
         # skull base and mastoids reach lower at the back, behind the face
         loft([(0, 1.56, -0.04, 0.04, 0.045), (0, 1.585, -0.028, 0.056, 0.07), (0, 1.61, -0.018, 0.066, 0.09), (0, 1.64, -0.013, 0.071, 0.097),
               (0, 1.68, -0.014, 0.071, 0.094), (0, 1.712, -0.017, 0.064, 0.085), (0, 1.732, -0.019, 0.05, 0.066),
               (0, 1.742, -0.02, 0.036, 0.048)]))
    part("face-bones", "Facial bones (maxilla & cheekbones)", "上颌骨与颧骨", "skeletal", BONE,
         loft([(0, 1.548, 0.05, 0.026, 0.028, 2.2), (0, 1.565, 0.048, 0.036, 0.036, 2.3), (0, 1.59, 0.046, 0.048, 0.04, 2.4),
               (0, 1.615, 0.042, 0.052, 0.04, 2.4), (0, 1.64, 0.03, 0.05, 0.048, 2.2)]))
    part("brow-ridge", "Brow ridge (frontal bone)", "眉弓（额骨）", "skeletal", BONE,
         loft([(-0.05, 1.64, 0.064, 0.003, 0.003), (-0.03, 1.644, 0.077, 0.0035, 0.004), (0.0, 1.641, 0.081, 0.003, 0.0035),
               (0.03, 1.644, 0.077, 0.0035, 0.004), (0.05, 1.64, 0.064, 0.003, 0.003)]))
    part("nasal-bone", "Nasal bone", "鼻骨", "skeletal", BONE, loft([(0, 1.632, 0.08, 0.005, 0.004), (0, 1.615, 0.085, 0.007, 0.004)]))
    pair("cheekbone", "Cheekbone (zygomatic)", "颧骨", "skeletal", BONE, sphere((0.04, 1.602, 0.056), 0.012, [1.0, 0.7, 0.75]))
    # eye sockets and nose opening: dark hollows set flush into the face
    pair("orbit", "Orbit (eye socket)", "眼眶", "skeletal", "#3E3A42", sphere((0.029, 1.623, 0.077), 0.0165, [1.05, 0.95, 0.4]))
    # nose opening: pear-shaped, narrow at the top
    part("nasal-aperture", "Nasal cavity", "鼻腔", "skeletal", "#3E3A42", lathe((0, 1.612, 0.084), (0, 1.578, 0.086), [0.003, 0.006, 0.009, 0.011, 0.009], [1, 1, 0.35]))
    pair("zygomatic", "Cheekbone (zygomatic)", "颧骨", "skeletal", BONE,
         tube([(0.046, 1.601, 0.04), (0.054, 1.599, 0.02), (0.057, 1.6, 0.0), (0.055, 1.603, -0.015)], 0.0028, [0.004, 0.0035, 0.003, 0.0028]))
    # teeth: one small crown each around the upper and lower arches
    def arch(y0, y1, a, b, z0):
        return [[(a * math.sin(t), y0, z0 + b * math.cos(t)), (a * math.sin(t), y1, z0 + b * math.cos(t))]
                for t in [(-1.35 + 2.7 * k / 13) for k in range(14)]]
    part("upper-teeth", "Teeth", "牙齿", "skeletal", "#F7F4EA", tubes(arch(1.553, 1.546, 0.025, 0.033, 0.048), 0.0028))
    part("lower-teeth", "Teeth", "牙齿", "skeletal", "#F7F4EA", tubes(arch(1.538, 1.545, 0.023, 0.031, 0.046), 0.0026))
    # lower jaw: a thick U from the chin back to the angles, rising into the rami
    part("mandible", "Mandible", "下颌骨", "skeletal", BONE,
         sheet([(0.046, 1.536, 0.004), (0.04, 1.535, 0.042), (0.022, 1.534, 0.068), (0, 1.534, 0.078), (-0.022, 1.534, 0.068), (-0.04, 1.535, 0.042), (-0.046, 1.536, 0.004)],
               [(0.05, 1.513, -0.004), (0.044, 1.51, 0.04), (0.025, 1.506, 0.068), (0, 1.503, 0.081), (-0.025, 1.506, 0.068), (-0.044, 1.51, 0.04), (-0.05, 1.513, -0.004)],
               (0, 0, 0.002), 0.008))
    part("chin-bone", "Mandible", "下颌骨", "skeletal", BONE, sphere((0, 1.508, 0.078), 0.011, [1.4, 0.8, 0.7]))
    pair("mandible-ramus", "Mandible", "下颌骨", "skeletal", BONE,
         sheet([(0.05, 1.513, -0.004), (0.047, 1.534, 0.01)], [(0.055, 1.585, -0.014), (0.053, 1.575, 0.0)], (0.004, 0, 0), 0.009))

    # spine: body centre follows the S-curve; sizes grow downwards
    curve = [(1.585, -0.012), (1.49, -0.022), (1.40, -0.055), (1.26, -0.075), (1.12, -0.058), (1.02, -0.035), (0.965, -0.03)]

    def spine_z(y):
        for (y0, z0), (y1, z1) in zip(curve, curve[1:]):
            if y1 <= y <= y0:
                t = (y0 - y) / (y0 - y1)
                t = t * t * (3 - 2 * t)
                return z0 + (z1 - z0) * t
        return curve[-1][1]

    regions = [("C", "颈椎", 7, 0.0115, 0.014, 0.004), ("T", "胸椎", 12, 0.0185, 0.0195, 0.005), ("L", "腰椎", 5, 0.027, 0.027, 0.0095)]
    y = 1.585
    for prefix, zh, count, radius, height, disc in regions:
        for n in range(1, count + 1):
            top, bottom = y, y - height
            mid = (top + bottom) / 2
            z = spine_z(mid)
            name, nzh = f"{prefix}{n} vertebra", f"第{n}{zh}"
            vid = f"vertebra-{prefix}{n}"
            part(vid, name, nzh, "skeletal", BONE, lathe((0, top, z), (0, bottom, z), [radius, radius * 1.05, radius], [1.15, 1, 0.85]))
            spinous = 0.018 if prefix == "C" else 0.03 if prefix == "T" else 0.028
            droop = 0.004 if prefix == "C" else 0.02 if prefix == "T" else 0.006
            part(f"{vid}-spinous", name, nzh, "skeletal", BONE, segment((0, mid, z - radius), (0, mid - droop, z - radius - spinous), 0.0045))
            span = 0.025 if prefix == "C" else 0.03 if prefix == "T" else 0.042
            part(f"{vid}-transverse", name, nzh, "skeletal", BONE, segment((-span, mid, z - radius * 0.7), (span, mid, z - radius * 0.7), 0.004))
            y = bottom
            if not (prefix == "L" and n == count):
                zd = spine_z(y - disc / 2)
                part(f"disc-{prefix}{n}", "Intervertebral disc", "椎间盘", "skeletal", DISC,
                     lathe((0, y, zd), (0, y - disc, zd), [radius, radius], [1.15, 1, 0.85]))
                y -= disc
    # sacrum: wide wedge under L5 narrowing to the coccyx, curved backwards
    part("sacrum", "Sacrum", "骶骨", "skeletal", BONE,
         sheet([(0.054, 0.992, -0.045), (0.0, 0.998, -0.038), (-0.054, 0.992, -0.045)], [(0.012, 0.835, -0.093), (-0.012, 0.835, -0.093)],
               (0, 0, -0.022), 0.012))
    part("coccyx", "Coccyx", "尾骨", "skeletal", BONE, tube([(0, 0.845, -0.093), (0, 0.82, -0.094), (0, 0.8, -0.086), (0, 0.788, -0.075)], 0.006, [0.008, 0.006, 0.005, 0.004]))

    # thorax: rib i leaves vertebra T_i, sweeps round an ellipse and descends to the front
    widths = [0.065, 0.09, 0.11, 0.125, 0.135, 0.142, 0.146, 0.145, 0.14, 0.132, 0.12, 0.1]
    depths = [0.05, 0.068, 0.08, 0.088, 0.094, 0.098, 0.1, 0.1, 0.098, 0.094, 0.085, 0.075]
    sternum_top, sternum_bottom = 1.435, 1.24
    for i in range(12):
        yb = 1.47 - i * 0.0215  # level of T(i+1)
        a, b = widths[i], depths[i]
        zs = spine_z(yb) - 0.005
        zc = zs + b * 0.92
        floating = i >= 10
        end = 1.3 if floating else 2.35 if i < 7 else 2.2
        # ribs slope down from the spine to the front, steeper lower down
        drop = 0.03 + 0.075 * min(i, 7) / 7
        pts = []
        for k in range(9):
            phi = 0.25 + (end - 0.25) * k / 8
            pts.append((a * math.sin(phi), yb - drop * (phi / math.pi) ** 1.3, zc - b * math.cos(phi)))
        pair(f"rib-{i + 1}", f"Rib {i + 1}", f"第{i + 1}肋", "skeletal", BONE, tube(pts, 0.0055))
        RIBS.append(pts)
        if not floating:
            front = pts[-1]
            if i < 7:
                target = (0.016, sternum_top - (sternum_top - sternum_bottom) * (i / 6.3), zc + b * 0.98)
            else:
                target = (0.05 + 0.02 * (i - 7), front[1] + 0.05, front[2] + 0.015)
            mid = ((front[0] + target[0]) / 2 + 0.01, (front[1] + target[1]) / 2 - 0.01, (front[2] + target[2]) / 2 + 0.01)
            pair(f"costal-cartilage-{i + 1}", "Costal cartilage", "肋软骨", "skeletal", CARTILAGE, tube([front, mid, target], 0.005))
    zst = 0.125
    part("sternum", "Sternum", "胸骨", "skeletal", BONE,
         lathe((0, sternum_top, zst - 0.012), (0, 1.215, zst + 0.004), [0.024, 0.02, 0.016, 0.017, 0.018, 0.012, 0.006], [1, 1, 0.35]))
    # clavicle: S-shaped, bowed forward near the breastbone and back towards the shoulder, ending at the acromion
    pair("clavicle", "Clavicle", "锁骨", "skeletal", BONE,
         tube([(0.022, 1.44, 0.098), (0.06, 1.446, 0.098), (0.1, 1.452, 0.07), (0.14, 1.458, 0.03), (0.175, 1.458, 0.005), (0.188, 1.455, -0.008)],
              0.006, [0.0075, 0.006, 0.0055, 0.0055, 0.006, 0.0065]))
    # scapula: triangle from the medial border to the glenoid, curved over the back of the ribs
    pair("scapula", "Scapula", "肩胛骨", "skeletal", BONE,
         sheet([(0.072, 1.422, -0.098), (0.075, 1.34, -0.104), (0.098, 1.25, -0.098)], [(0.162, 1.405, -0.056), (0.14, 1.33, -0.08), (0.104, 1.252, -0.097)],
               (0, 0, -0.008), 0.004))
    pair("scapular-spine", "Scapula", "肩胛骨", "skeletal", BONE,
         tube([(0.082, 1.385, -0.108), (0.14, 1.41, -0.094), (0.18, 1.44, -0.06), (0.195, 1.452, -0.03), (0.192, 1.455, -0.012)], 0.006,
              [0.004, 0.006, 0.007, 0.008, 0.007]))
    pair("coracoid", "Scapula", "肩胛骨", "skeletal", BONE, tube([(0.16, 1.4, -0.04), (0.162, 1.415, -0.01), (0.168, 1.41, 0.012)], 0.004))

    # upper limb
    pair("humeral-head", "Humeral head", "肱骨头", "skeletal", BONE, sphere(SHOULDER, 0.023))
    pair("humerus", "Humerus", "肱骨", "skeletal", BONE,
         lathe((0.188, 1.39, -0.028), (0.212, 1.105, -0.015), [0.02, 0.012, 0.0105, 0.0105, 0.012, 0.018, 0.022], [1.1, 1, 0.8]))
    pair("ulna", "Ulna", "尺骨", "skeletal", BONE, lathe((0.2, 1.118, -0.03), (0.224, 0.852, -0.004), [0.011, 0.0095, 0.0075, 0.0065, 0.006, 0.0075]))
    pair("radius", "Radius", "桡骨", "skeletal", BONE, lathe((0.226, 1.096, -0.008), (0.25, 0.853, 0.012), [0.0075, 0.007, 0.0075, 0.009, 0.011, 0.014]))
    pair("carpals", "Carpal bones", "腕骨", "skeletal", BONE,
         loft([(0.24, 0.848, 0.005, 0.019, 0.009), (0.239, 0.834, 0.006, 0.025, 0.011), (0.237, 0.82, 0.007, 0.026, 0.01)], square=2.5))
    fingers = [("index", "食指", 0.258, 0.08), ("middle", "中指", 0.24, 0.088), ("ring", "无名指", 0.223, 0.082), ("little", "小指", 0.207, 0.064)]
    for key, zh, x, length in fingers:
        base, knuckle = (x - 0.003 * (x - 0.232) / 0.03, 0.822, 0.006), (x, 0.765, 0.008)
        pair(f"metacarpal-{key}", "Metacarpal", "掌骨", "skeletal", BONE, lathe(base, knuckle, [0.0055, 0.004, 0.004, 0.0055]))
        segs = [0.45, 0.3, 0.25]
        start = knuckle
        for j, frac in enumerate(segs):
            end = (start[0] + (x - 0.232) * 0.02, start[1] - length * frac, start[2] + 0.004)
            pair(f"phalanx-{key}-{j + 1}", f"{key.capitalize()} finger phalanx", f"{zh}指骨", "skeletal", BONE,
                 lathe(start, end, [0.0048, 0.0036, 0.0045], None) if j < 2 else lathe(start, end, [0.004, 0.0033, 0.0022]))
            start = end
    thumb = [(0.252, 0.83, 0.01), (0.268, 0.795, 0.028), (0.278, 0.765, 0.04), (0.284, 0.742, 0.048)]
    for j in range(3):
        name, zh = ("Thumb metacarpal", "拇指掌骨") if j == 0 else ("Thumb phalanx", "拇指指骨")
        pair(f"thumb-{j + 1}", name, zh, "skeletal", BONE, lathe(thumb[j], thumb[j + 1], [0.0062, 0.0048, 0.005]))

    # pelvis: ilium plate + pubis/ischium ring
    # ilium: a flared wing from the iliac crest down to the hip socket, bowl-shaped inside
    pair("ilium", "Hip bone (ilium)", "髂骨", "skeletal", BONE,
         sheet([(0.118, 1.03, 0.068), (0.145, 1.07, 0.035), (0.148, 1.088, -0.01), (0.125, 1.082, -0.05), (0.075, 1.04, -0.075), (0.052, 1.0, -0.062)],
               [(0.1, 0.945, 0.03), (0.1, 0.935, 0.005), (0.09, 0.938, -0.02), (0.07, 0.955, -0.045), (0.055, 0.975, -0.055)],
               (0.012, 0, 0.0), 0.006))
    pair("acetabulum", "Hip socket (acetabulum)", "髋臼", "skeletal", BONE,
         tube([(HIP[0] + 0.004 + 0.027 * math.cos(a) * 0.3, HIP[1] + 0.027 * math.sin(a), HIP[2] + 0.027 * math.cos(a)) for a in [k * math.pi / 6 for k in range(13)]], 0.006))
    pair("pubis-ischium", "Hip bone (pubis & ischium)", "耻骨与坐骨", "skeletal", BONE,
         tube([(0.1, 0.935, 0.02), (0.06, 0.9, 0.055), (0.012, 0.88, 0.065), (0.03, 0.85, 0.045), (0.06, 0.835, 0.0),
               (0.07, 0.85, -0.035), (0.085, 0.9, -0.02), (0.1, 0.935, 0.02)], 0.011,
              # thick at the pubic body and the sitting bone, thin around the obturator hole
              [0.012, 0.008, 0.012, 0.008, 0.014, 0.011, 0.008, 0.012]))
    part("pubic-symphysis", "Pubic symphysis", "耻骨联合", "skeletal", CARTILAGE, lathe((0, 0.892, 0.066), (0, 0.868, 0.062), [0.008, 0.009, 0.008], [1, 1, 0.6]))

    # lower limb
    pair("femoral-head", "Femoral head", "股骨头", "skeletal", BONE, sphere(HIP, 0.024))
    pair("femoral-neck", "Femoral neck", "股骨颈", "skeletal", BONE, segment(HIP, (0.13, 0.9, -0.005), 0.014))
    pair("femur", "Femur", "股骨", "skeletal", BONE,
         lathe((0.132, 0.915, -0.008), (0.098, 0.505, 0.0), [0.022, 0.016, 0.0135, 0.013, 0.0135, 0.017, 0.026], [1, 1, 0.95]))
    # two rounded condyles side by side, the kneecap a flat shield in front of their groove
    pair("femoral-condyles", "Femur", "股骨", "skeletal", BONE, sphere((0.115, 0.49, -0.006), 0.021, [0.8, 0.95, 1.25]))
    pair("femoral-condyle-medial", "Femur", "股骨", "skeletal", BONE, sphere((0.08, 0.488, -0.006), 0.022, [0.8, 0.95, 1.25]))
    pair("patella", "Patella", "髌骨", "skeletal", BONE, sphere((0.098, 0.505, 0.03), 0.02, [1.0, 1.15, 0.45]))
    pair("tibia", "Tibia", "胫骨", "skeletal", BONE,
         lathe((0.095, 0.475, 0.004), (0.083, 0.078, 0.008), [0.034, 0.02, 0.0145, 0.013, 0.0135, 0.017, 0.02], [1.2, 1, 0.9]))
    pair("fibula", "Fibula", "腓骨", "skeletal", BONE, lathe((0.128, 0.46, -0.012), (0.122, 0.07, -0.008), [0.009, 0.006, 0.0055, 0.0065, 0.01]))
    # heel: calcaneus runs back from mid-foot to the heel; talus sits on it under the shin bones
    pair("talus-calcaneus", "Heel bones (talus & calcaneus)", "距骨与跟骨", "skeletal", BONE,
         loft([(0.088, 0.035, 0.04, 0.02, 0.016), (0.089, 0.038, 0.01, 0.022, 0.022), (0.09, 0.034, -0.025, 0.021, 0.026), (0.09, 0.03, -0.052, 0.017, 0.022)]))
    pair("talus", "Heel bones (talus & calcaneus)", "距骨与跟骨", "skeletal", BONE, sphere((0.087, 0.066, -0.002), 0.019, [1.0, 0.8, 1.25]))
    toes = [("big", "拇趾", 0.068, 0.2, 0.012), ("2nd", "第2趾", 0.086, 0.196, 0.008), ("3rd", "第3趾", 0.1, 0.19, 0.0075),
            ("4th", "第4趾", 0.112, 0.18, 0.007), ("5th", "第5趾", 0.123, 0.168, 0.0065)]
    for key, zh, x, tip, r in toes:
        base = (0.078 + (x - 0.09) * 0.4, 0.045, 0.04)
        head = (x, 0.018, tip - 0.045)
        pair(f"metatarsal-{key}", "Metatarsal", "跖骨", "skeletal", BONE, lathe(base, head, [r * 0.8, r * 0.6, r * 0.6, r * 0.85]))
        pair(f"toe-{key}", "Toe phalanges", f"{zh}趾骨", "skeletal", BONE, lathe(head, (x, 0.013, tip), [r * 0.8, r * 0.65, r * 0.5]))


# ---------------------------------------------------------------- muscles (origin → insertion)

def fibres(pid, name, zh, origins, insertions, r, bulge=(0, 0, 0)):
    """A flat muscle: one slab fanning from its origins to its insertions, bowed by `bulge`; `r` = half-thickness."""
    pair(pid, name, zh, "muscular", MUSCLE, sheet(origins, insertions, bulge, r * 0.6))


def muscles():
    """Superficial muscles laid on the body surface as slabs (anatomy-figure style); a few deep or thin ones stay spindles/tubes.
    Angles: 0 = outer side, 90 = front, 180 = inner side, 270 = back (left side; right is mirrored)."""
    belly = [0.14, 0.45, 0.82, 1.0, 0.97, 0.8, 0.5, 0.2, 0.1]
    m = lambda pid, name, zh, a, b, r: pair(pid, name, zh, "muscular", MUSCLE, lathe(a, b, [r * k for k in belly], [1, 1, 0.78]))
    torso = TORSO["male"]

    def on(pid, name, zh, sections, origin, insertion, thick, k=0.965, square=2.0, converge=None, nv=10, start=None):
        # set a little deeper and made thicker, so each belly rounds up and the seams between muscles show
        sq = min(square, 2.3)
        pair(pid, name, zh, "muscular", MUSCLE, slab(panel(sections, origin, insertion, k - thick * 2.2, sq, converge, nv=nv, start=start), thick * 1.9))

    # deep muscle core under each segment: seams between superficial muscles read as grooves, not holes
    DEEP = "#8E3A34"
    part("deep-trunk", "Deep muscles", "深层肌", "muscular", DEEP, loft([(0, r[0], r[1], r[2] * 0.9, r[3] * 0.88) for r in torso if 0.87 <= r[0] <= 1.44], square=2.4))
    part("deep-head", "Head & face muscles", "头面部肌", "muscular", DEEP,
         loft([(0, 1.51, 0.055, 0.018, 0.014), (0, 1.53, 0.035, 0.044, 0.05), (0, 1.56, 0.012, 0.052, 0.074), (0, 1.6, 0.0, 0.06, 0.088),
               (0, 1.64, -0.008, 0.064, 0.092), (0, 1.68, -0.012, 0.064, 0.089), (0, 1.715, -0.016, 0.056, 0.077), (0, 1.738, -0.018, 0.032, 0.042)]))
    pair("deep-foot", "Deep muscles", "深层肌", "muscular", DEEP,
         loft([(0.089, 0.1, -0.025, 0.022, 0.026), (0.09, 0.05, -0.02, 0.026, 0.034), (0.093, 0.035, 0.04, 0.034, 0.022), (0.098, 0.022, 0.12, 0.038, 0.014)]))
    # hand: palm and thumb-base muscles, a tendon down each finger
    pair("hand-muscles", "Hand muscles", "手部肌", "muscular", MUSCLE,
         loft([(0.242, 0.852, 0.006, 0.022, 0.014), (0.241, 0.83, 0.008, 0.033, 0.015), (0.239, 0.8, 0.009, 0.038, 0.014),
               (0.237, 0.775, 0.01, 0.039, 0.011)], square=2.4))
    pair("thenar-muscles", "Hand muscles", "手部肌", "muscular", MUSCLE, sphere((0.256, 0.818, 0.016), 0.013, [0.9, 1.4, 0.75]))
    tendons = []
    for key, x, length in (("index", 0.258, 0.08), ("middle", 0.24, 0.088), ("ring", 0.223, 0.082), ("little", 0.207, 0.064)):
        r = (0.0085 if key != "little" else 0.0075) * 0.86
        drift = (x - 0.232) * 0.02
        pts = [(x + drift * u * 3, 0.772 - length * u, 0.009 + 0.012 * u) for u in (0.0, 0.42, 0.6, 0.78, 0.95)]
        pair(f"deep-finger-{key}", "Deep muscles", "深层肌", "muscular", DEEP, loft([p + (r, r * 0.88) for p in pts]))
        # flexor tendon along the palm side of each finger, from mid-palm
        tendons.append([(x - drift, 0.8, 0.019)] + [(p[0], p[1], p[2] + r * 0.8) for p in pts[:-1]])
    tendons.append([(0.254, 0.83, 0.021), (0.27, 0.795, 0.034), (0.282, 0.755, 0.051)])
    pair("deep-thumb", "Deep muscles", "深层肌", "muscular", DEEP,
         loft([(0.252, 0.832, 0.013, 0.0098, 0.009), (0.266, 0.804, 0.025, 0.0095, 0.0088), (0.277, 0.775, 0.037, 0.0082, 0.0076), (0.284, 0.75, 0.046, 0.0068, 0.006)]))
    pair("finger-tendons", "Finger tendons", "指腱", "muscular", TENDON, tubes(tendons, 0.0022))
    part("deep-neck", "Deep muscles", "深层肌", "muscular", DEEP,
         loft([(0, 1.43, -0.02, 0.07, 0.05), (0, 1.47, -0.018, 0.05, 0.047), (0, 1.52, -0.012, 0.044, 0.044), (0, 1.57, -0.018, 0.04, 0.04)]))
    for key, sec, name in (("upper-arm", UPPER_ARM[1:], "arm"), ("forearm", FOREARM, "forearm"), ("thigh", THIGH, "thigh"), ("shin", SHIN, "leg")):
        pair(f"deep-{key}", "Deep muscles", "深层肌", "muscular", DEEP, loft([(x, y, z, rx * 0.86, rz * 0.86) for x, y, z, rx, rz in sec]))

    # head & neck
    m("masseter", "Masseter", "咬肌", (0.058, 1.595, 0.03), (0.05, 1.535, 0.012), 0.013)
    fibres("temporalis", "Temporalis", "颞肌", [(0.066, 1.67, 0.03), (0.07, 1.68, 0.0), (0.066, 1.665, -0.03)], [(0.058, 1.595, 0.012)], 0.011, (0.004, 0, 0))
    m("sternocleidomastoid", "Sternocleidomastoid", "胸锁乳突肌", (0.056, 1.585, -0.022), (0.02, 1.44, 0.095), 0.012)

    # trunk, front: fibres run to the arm (pectoralis) or down the belly
    on("pectoralis", "Pectoralis major", "胸大肌", torso, ((1.44, 85), (1.255, 88)), ((1.4, 22), (1.35, 14)), 0.009, 0.97, 2.6,
       converge=((0.19, 1.37, 0.005), 0.72))
    for n, (y0, y1) in enumerate(((1.245, 1.18), (1.17, 1.11), (1.1, 1.04), (1.03, 0.9))):
        on(f"rectus-abdominis-{n + 1}", "Rectus abdominis", "腹直肌", torso, ((y0, 89.6), (y0, 70)), ((y1, 89.6), (y1, 71)), 0.007, 0.985, 2.6, nv=6)
    on("external-oblique", "External oblique", "腹外斜肌", torso, ((1.26, 30), (1.02, 4)), ((1.14, 69), (0.93, 62)), 0.006, 0.975, 2.6)
    on("serratus", "Serratus anterior", "前锯肌", torso, ((1.34, 38), (1.21, 30)), ((1.36, 352), (1.26, 346)), 0.005, 0.975, 2.6)
    part("diaphragm", "Diaphragm", "膈肌", "muscular", "#B8544C", lathe((0.0, 1.165, -0.01), (0.0, 1.255, -0.01), [0.118, 0.114, 0.098, 0.064, 0.013], [1, 1, 0.7]))

    # trunk, back
    on("trapezius", "Trapezius", "斜方肌", torso, ((1.475, 271), (1.13, 271)), ((1.44, 345), (1.38, 318)), 0.007, 0.985, 2.6)
    on("erector-spinae", "Erector spinae", "竖脊肌", torso, ((1.3, 273), (1.3, 292)), ((0.95, 274), (0.95, 290)), 0.012, 0.99, 2.6, nv=4)
    on("latissimus", "Latissimus dorsi", "背阔肌", torso, ((1.25, 271), (0.98, 280)), ((1.33, 338), (1.3, 352)), 0.006, 0.975, 2.6,
       converge=((0.185, 1.35, -0.025), 0.72))
    on("gluteus-medius", "Gluteus medius", "臀中肌", torso, ((1.07, 312), (1.07, 378)), ((0.95, 338), (0.95, 362)), 0.01, 0.97, 2.6,
       converge=((0.135, 0.905, -0.012), 0.45))
    on("gluteus-maximus", "Gluteus maximus", "臀大肌", torso, ((1.02, 282), (0.855, 274)), ((0.93, 348), (0.86, 326)), 0.016, 0.985, 2.6,
       converge=((0.14, 0.85, -0.03), 0.8))

    # shoulder & arm
    # deltoid: a rounded cap over the humeral head, narrowing to its insertion halfway down the upper arm
    pair("deltoid", "Deltoid", "三角肌", "muscular", MUSCLE,
         loft([(0.186, 1.468, -0.02, 0.014, 0.018), (0.19, 1.455, -0.02, 0.038, 0.052), (0.196, 1.43, -0.019, 0.048, 0.06),
               (0.201, 1.39, -0.017, 0.048, 0.056), (0.206, 1.345, -0.014, 0.041, 0.046), (0.211, 1.305, -0.012, 0.025, 0.028),
               (0.214, 1.282, -0.012, 0.009, 0.011)]))
    on("biceps", "Biceps", "肱二头肌", UPPER_ARM, ((1.36, 65), (1.36, 120)), ((1.12, 78), (1.12, 105)), 0.012, 0.95,
       converge=((0.222, 1.085, 0.01), 0.82))
    m("brachialis", "Brachialis", "肱肌", (0.205, 1.26, 0.0), (0.212, 1.09, 0.0), 0.014)
    on("triceps", "Triceps", "肱三头肌", UPPER_ARM, ((1.38, 205), (1.38, 330)), ((1.12, 240), (1.12, 300)), 0.012, 0.95,
       converge=((0.206, 1.105, -0.045), 0.85))
    on("brachioradialis", "Brachioradialis", "肱桡肌", FOREARM, ((1.1, 20), (1.1, 70)), ((0.9, 55), (0.9, 70)), 0.008, 0.97)
    on("forearm-flexors", "Forearm flexors", "前臂屈肌", FOREARM, ((1.08, 75), (1.08, 175)), ((0.88, 100), (0.88, 160)), 0.008, 0.96,
       start=((0.195, 1.1, -0.025), 0.2), converge=((0.238, 0.86, 0.012), 0.8))
    on("flexor-carpi-ulnaris", "Flexor carpi ulnaris", "尺侧腕屈肌", FOREARM, ((1.08, 180), (1.08, 225)), ((0.88, 170), (0.88, 195)), 0.006, 0.96,
       start=((0.195, 1.1, -0.025), 0.2))
    on("forearm-extensors", "Forearm extensors", "前臂伸肌", FOREARM, ((1.08, 235), (1.08, 375)), ((0.88, 250), (0.88, 350)), 0.008, 0.96,
       start=((0.232, 1.1, -0.02), 0.2), converge=((0.245, 0.86, -0.004), 0.8))

    # thigh
    on("tensor-fasciae-latae", "Tensor fasciae latae", "阔筋膜张肌", THIGH, ((0.93, 25), (0.93, 60)), ((0.8, 15), (0.8, 30)), 0.006, 0.98)
    pair("it-band", "Iliotibial band", "髂胫束", "muscular", TENDON, slab(panel(THIGH, ((0.82, 5), (0.82, 25)), ((0.5, 5), (0.5, 20)), 0.99), 0.0015))
    on("rectus-femoris", "Rectus femoris", "股直肌", THIGH, ((0.92, 72), (0.92, 108)), ((0.53, 80), (0.53, 100)), 0.012, 0.97)
    on("vastus-lateralis", "Vastus lateralis", "股外侧肌", THIGH, ((0.88, -40), (0.88, 72)), ((0.53, 20), (0.53, 80)), 0.012, 0.965)
    on("vastus-medialis", "Vastus medialis", "股内侧肌", THIGH, ((0.76, 108), (0.76, 150)), ((0.52, 100), (0.52, 165)), 0.013, 0.965)
    on("sartorius", "Sartorius", "缝匠肌", THIGH, ((0.93, 55), (0.93, 70)), ((0.5, 190), (0.5, 200)), 0.004, 0.985, nv=4)
    on("adductors", "Adductors", "内收肌群", THIGH, ((0.88, 150), (0.88, 205)), ((0.6, 165), (0.6, 190)), 0.012, 0.955)
    on("gracilis", "Gracilis", "股薄肌", THIGH, ((0.88, 205), (0.88, 222)), ((0.5, 195), (0.5, 205)), 0.004, 0.975, nv=4)
    on("hamstrings-medial", "Hamstrings", "腘绳肌", THIGH, ((0.86, 225), (0.86, 268)), ((0.52, 215), (0.52, 250)), 0.012, 0.96)
    on("hamstrings-lateral", "Hamstrings", "腘绳肌", THIGH, ((0.86, 272), (0.86, 320)), ((0.52, 290), (0.52, 330)), 0.012, 0.96)

    # leg
    on("gastrocnemius-medial", "Calf (gastrocnemius)", "腓肠肌", SHIN, ((0.48, 215), (0.48, 268)), ((0.24, 255), (0.24, 270)), 0.013, 0.985,
       converge=((0.09, 0.2, -0.042), 0.85))
    on("gastrocnemius-lateral", "Calf (gastrocnemius)", "腓肠肌", SHIN, ((0.48, 272), (0.48, 320)), ((0.26, 272), (0.26, 285)), 0.012, 0.985,
       converge=((0.09, 0.2, -0.042), 0.85))
    on("soleus", "Soleus", "比目鱼肌", SHIN, ((0.4, 195), (0.4, 345)), ((0.13, 250), (0.13, 290)), 0.008, 0.93,
       converge=((0.09, 0.12, -0.04), 0.78))
    on("tibialis", "Tibialis anterior", "胫骨前肌", SHIN, ((0.45, 55), (0.45, 85)), ((0.13, 80), (0.13, 100)), 0.007, 0.975,
       converge=((0.074, 0.07, 0.035), 0.75))
    on("peroneus", "Peroneus longus", "腓骨长肌", SHIN, ((0.44, -15), (0.44, 25)), ((0.13, -20), (0.13, 0)), 0.006, 0.975,
       converge=((0.118, 0.075, -0.018), 0.75))
    pair("achilles", "Achilles tendon", "跟腱", "muscular", TENDON, tube([(0.09, 0.2, -0.042), (0.09, 0.1, -0.04), (0.09, 0.04, -0.05)], 0.006))


# ---------------------------------------------------------------- vessels, nerves, tubes

def vessels():
    v = lambda pid, name, zh, layer, color, pts, r, radii=None: part(pid, name, zh, layer, color, tube(pts, r, radii))
    vp = lambda pid, name, zh, layer, color, pts, r, radii=None: pair(pid, name, zh, layer, color, tube(pts, r, radii))
    v("aorta", "Aorta", "主动脉", "circulatory", ARTERY,
      [(0.012, 1.29, 0.04), (0.01, 1.34, 0.03), (0.0, 1.365, 0.0), (0.018, 1.34, -0.04), (0.02, 1.25, -0.05), (0.012, 1.1, -0.035), (0.005, 0.965, -0.012)],
      0.012, [0.014, 0.014, 0.013, 0.012, 0.011, 0.01, 0.009])
    v("vena-cava", "Vena cava", "腔静脉", "circulatory", VEIN,
      [(-0.025, 1.4, 0.02), (-0.028, 1.3, 0.03), (-0.026, 1.2, 0.0), (-0.02, 1.08, -0.02), (-0.012, 0.965, 0.0)], 0.013)
    v("pulmonary-arteries", "Pulmonary arteries", "肺动脉", "circulatory", VEIN,
      [(-0.08, 1.33, 0.0), (-0.02, 1.33, 0.04), (0.0, 1.31, 0.05), (0.03, 1.33, 0.04), (0.08, 1.33, 0.0)], 0.008)
    neck = [(0.018, 1.38, 0.025), (0.028, 1.47, 0.03), (0.04, 1.56, 0.015)]
    vp("carotid", "Carotid artery", "颈动脉", "circulatory", ARTERY, neck, 0.0055)
    vp("jugular", "Jugular vein", "颈静脉", "circulatory", VEIN, [(p[0] + 0.012, p[1], p[2] - 0.008) for p in neck], 0.006)
    arm = [(0.02, 1.38, 0.02), (0.1, 1.425, 0.02), (0.175, 1.375, -0.005), (0.205, 1.24, 0.008), (0.222, 1.09, 0.018), (0.245, 0.86, 0.02), (0.25, 0.8, 0.018)]
    vp("arm-artery", "Arm arteries", "上肢动脉", "circulatory", ARTERY, arm, 0.0045)
    vp("arm-vein", "Arm veins", "上肢静脉", "circulatory", VEIN, [(p[0] + 0.006, p[1], p[2] - 0.008) for p in arm], 0.0045)
    leg = [(0.005, 0.965, -0.01), (0.05, 0.93, 0.0), (0.09, 0.87, 0.04), (0.085, 0.65, 0.025), (0.095, 0.49, -0.035), (0.095, 0.22, -0.02), (0.085, 0.07, 0.015), (0.1, 0.03, 0.12)]
    vp("leg-artery", "Leg arteries", "下肢动脉", "circulatory", ARTERY, leg, 0.006)
    vp("leg-vein", "Leg veins", "下肢静脉", "circulatory", VEIN, [(p[0] + 0.007, p[1], p[2] - 0.01) for p in leg], 0.0065)

    v("spinal-cord", "Spinal cord", "脊髓", "nervous", NERVE,
      [(0, 1.575, -0.035), (0, 1.48, -0.04), (0, 1.36, -0.075), (0, 1.22, -0.09), (0, 1.1, -0.075)], 0.006)
    vp("arm-nerve", "Brachial plexus & median nerve", "臂丛与正中神经", "nervous", NERVE,
       [(0.025, 1.47, -0.03), (0.1, 1.42, -0.005), (0.18, 1.35, 0.0), (0.212, 1.2, 0.012), (0.222, 1.08, 0.022), (0.238, 0.87, 0.024), (0.24, 0.8, 0.022)], 0.0035)
    vp("sciatic", "Sciatic nerve", "坐骨神经", "nervous", NERVE,
       [(0.03, 0.93, -0.075), (0.08, 0.86, -0.07), (0.1, 0.7, -0.045), (0.1, 0.52, -0.04), (0.098, 0.3, -0.03), (0.085, 0.09, -0.01)], 0.005)
    vp("intercostal", "Intercostal nerve", "肋间神经", "nervous", NERVE,
       [(0.02, 1.33, -0.08), (0.11, 1.32, -0.05), (0.14, 1.3, 0.03), (0.08, 1.28, 0.1)], 0.0022)
    vp("femoral-nerve", "Femoral nerve", "股神经", "nervous", NERVE, [(0.04, 1.0, -0.02), (0.08, 0.9, 0.03), (0.085, 0.75, 0.04)], 0.004)

    vp("renal-artery", "Renal artery", "肾动脉", "circulatory", ARTERY, [(0.012, 1.085, -0.035), (0.035, 1.08, -0.05), (0.052, 1.075, -0.058)], 0.004)
    vp("renal-vein", "Renal vein", "肾静脉", "circulatory", VEIN, [(-0.012, 1.075, -0.02), (0.02, 1.07, -0.045), (0.05, 1.068, -0.056)], 0.0042)
    v("celiac-trunk", "Celiac trunk", "腹腔干", "circulatory", ARTERY, [(0.014, 1.14, -0.04), (0.02, 1.135, -0.01), (0.03, 1.14, 0.02)], 0.004)
    v("mesenteric-artery", "Superior mesenteric artery", "肠系膜上动脉", "circulatory", ARTERY,
      [(0.013, 1.11, -0.035), (0.01, 1.07, 0.02), (-0.005, 1.0, 0.055), (-0.03, 0.95, 0.06)], 0.004)
    vp("vertebral-artery", "Vertebral artery", "椎动脉", "circulatory", ARTERY, [(0.03, 1.4, 0.005), (0.03, 1.47, -0.02), (0.022, 1.56, -0.03), (0.008, 1.6, -0.03)], 0.003)
    vp("internal-iliac", "Internal iliac artery", "髂内动脉", "circulatory", ARTERY, [(0.045, 0.94, -0.005), (0.05, 0.9, -0.04), (0.045, 0.87, -0.05)], 0.004)
    vp("coronary", "Coronary artery", "冠状动脉", "circulatory", "#F2D060", [(0.005, 1.305, 0.06), (0.03, 1.27, 0.085), (0.05, 1.23, 0.09)], 0.0025)
    vp("ulnar-nerve", "Ulnar nerve", "尺神经", "nervous", NERVE, [(0.17, 1.36, -0.02), (0.195, 1.2, -0.03), (0.2, 1.11, -0.04), (0.215, 0.95, -0.01), (0.222, 0.83, 0.008)], 0.0028)
    vp("radial-nerve", "Radial nerve", "桡神经", "nervous", NERVE, [(0.17, 1.37, -0.03), (0.19, 1.27, -0.045), (0.222, 1.18, -0.02), (0.228, 1.08, 0.004), (0.25, 0.9, 0.0)], 0.0028)
    vp("common-peroneal", "Common peroneal nerve", "腓总神经", "nervous", NERVE, [(0.1, 0.52, -0.04), (0.13, 0.46, -0.02), (0.13, 0.4, 0.02), (0.1, 0.12, 0.035)], 0.003)
    vp("vagus", "Vagus nerve", "迷走神经", "nervous", NERVE, [(0.02, 1.575, -0.01), (0.022, 1.47, 0.02), (0.018, 1.38, 0.0), (0.012, 1.25, -0.03), (0.02, 1.15, -0.01)], 0.0022)
    # --- branches: small vessels and nerves that make each system read as a tree
    tp = lambda pid, name, zh, layer, color, paths, r: pair(pid, name, zh, layer, color, tubes(paths, r))
    elbow, wrist = (0.222, 1.09, 0.018), (0.245, 0.86, 0.02)
    vp("radial-artery", "Radial artery", "桡动脉", "circulatory", ARTERY, [elbow, (0.235, 1.0, 0.024), (0.248, 0.9, 0.024), (0.252, 0.84, 0.018)], 0.0032)
    vp("ulnar-artery", "Ulnar artery", "尺动脉", "circulatory", ARTERY, [elbow, (0.212, 1.02, 0.012), (0.218, 0.92, 0.012), (0.226, 0.84, 0.014)], 0.0032)
    # palm: arch across the palm, one artery down each finger
    fingers = [(0.258, 0.08), (0.24, 0.088), (0.223, 0.082), (0.207, 0.064)]
    tp("hand-arteries", "Palmar arch & digital arteries", "掌弓与指动脉", "circulatory", ARTERY,
       [[(0.252, 0.84, 0.018), (0.255, 0.8, 0.02), (0.235, 0.79, 0.022), (0.212, 0.8, 0.02), (0.226, 0.84, 0.014)]] +
       [[(x, 0.79, 0.022), (x + (x - 0.232) * 0.02, 0.765 - l * 0.4, 0.024), (x + (x - 0.232) * 0.04, 0.765 - l * 0.9, 0.02)] for x, l in fingers], 0.0018)
    vp("cephalic-vein", "Cephalic vein", "头静脉", "circulatory", VEIN,
       [(0.252, 0.85, 0.015), (0.25, 0.97, 0.02), (0.238, 1.1, 0.022), (0.228, 1.25, 0.03), (0.2, 1.4, 0.035), (0.14, 1.43, 0.06)], 0.0032)
    vp("basilic-vein", "Basilic vein", "贵要静脉", "circulatory", VEIN,
       [(0.225, 0.85, 0.0), (0.21, 0.97, -0.005), (0.198, 1.1, -0.005), (0.195, 1.22, 0.0), (0.18, 1.33, 0.0)], 0.0032)
    knee = (0.095, 0.49, -0.035)
    vp("anterior-tibial", "Anterior tibial & dorsalis pedis", "胫前动脉与足背动脉", "circulatory", ARTERY,
       [knee, (0.11, 0.44, 0.0), (0.1, 0.3, 0.02), (0.09, 0.12, 0.03), (0.09, 0.05, 0.06), (0.085, 0.03, 0.12)], 0.0035)
    vp("posterior-tibial", "Posterior tibial artery", "胫后动脉", "circulatory", ARTERY,
       [knee, (0.09, 0.4, -0.035), (0.08, 0.25, -0.025), (0.07, 0.1, -0.02), (0.075, 0.035, 0.02), (0.08, 0.018, 0.1)], 0.0035)
    vp("deep-femoral", "Deep femoral artery", "股深动脉", "circulatory", ARTERY, [(0.09, 0.84, 0.035), (0.11, 0.78, 0.0), (0.12, 0.65, -0.02)], 0.004)
    vp("great-saphenous", "Great saphenous vein", "大隐静脉", "circulatory", VEIN,
       [(0.068, 0.04, 0.03), (0.068, 0.1, 0.0), (0.06, 0.3, -0.02), (0.052, 0.49, -0.02), (0.045, 0.7, 0.02), (0.06, 0.87, 0.06)], 0.0035)
    vp("external-carotid", "External carotid & facial artery", "颈外动脉与面动脉", "circulatory", ARTERY,
       [(0.04, 1.53, 0.02), (0.05, 1.55, 0.04), (0.045, 1.54, 0.07), (0.03, 1.57, 0.085), (0.02, 1.6, 0.09)], 0.0025)
    vp("temporal-artery", "Superficial temporal artery", "颞浅动脉", "circulatory", ARTERY,
       [(0.045, 1.55, 0.0), (0.07, 1.6, -0.005), (0.074, 1.65, 0.0), (0.068, 1.68, 0.015)], 0.0022)
    # ribs: an artery and a nerve under each rib (nerve lowest), ribs 2-11
    under = lambda dy, pts: [(x, y - dy, z) for x, y, z in pts[:-1]]
    tp("intercostal-arteries", "Intercostal arteries", "肋间动脉", "circulatory", ARTERY, [under(0.006, r) for r in RIBS[1:11]], 0.0015)
    tp("intercostal-veins", "Intercostal veins", "肋间静脉", "circulatory", VEIN, [under(0.0035, r) for r in RIBS[1:11]], 0.0015)
    tp("intercostal-nerves", "Intercostal nerves", "肋间神经", "nervous", NERVE, [under(0.009, r) for r in RIBS[1:11]], 0.0013)
    # spinal nerve roots: one pair leaving between each vertebra, angling down
    roots = []
    for k in range(24):
        y = 1.575 - k * 0.0255
        z = -0.035 - 0.05 * math.sin(min(1, k / 14) * math.pi / 2)
        roots.append([(0.004, y, z), (0.022, y - 0.006, z + 0.004), (0.04, y - 0.016, z + 0.01)])
    tp("spinal-nerves", "Spinal nerves", "脊神经", "nervous", NERVE, roots, 0.0022)
    vp("tibial-nerve", "Tibial nerve", "胫神经", "nervous", NERVE, [(0.1, 0.52, -0.04), (0.095, 0.4, -0.04), (0.08, 0.2, -0.03), (0.07, 0.08, -0.018), (0.075, 0.03, 0.03)], 0.003)
    vp("facial-nerve", "Facial nerve", "面神经", "nervous", NERVE, [(0.06, 1.595, -0.02), (0.065, 1.585, 0.02), (0.055, 1.6, 0.06)], 0.002)
    vp("pulmonary-veins", "Pulmonary veins", "肺静脉", "circulatory", ARTERY, [(0.07, 1.31, -0.01), (0.04, 1.3, 0.02), (0.02, 1.295, 0.035)], 0.005)

    v("esophagus", "Esophagus", "食管", "organs", "#E0A080", [(0, 1.52, -0.015), (0.0, 1.4, -0.03), (0.01, 1.27, -0.035), (0.03, 1.21, 0.0)], 0.0075)
    v("trachea", "Trachea & bronchi", "气管与支气管", "organs", "#E8C4B0",
      [(0, 1.52, 0.02), (0, 1.43, 0.012), (0, 1.36, 0.0), (0.045, 1.33, -0.005)], 0.009)
    v("bronchus-r", "Bronchi", "支气管", "organs", "#E8C4B0", [(0, 1.36, 0.0), (-0.045, 1.33, -0.005)], 0.008)


# ---------------------------------------------------------------- skin (translucent figure)

def skin():
    s = lambda pid, shape, sex=None: part(pid, "Skin", "皮肤", "skin", SKIN, shape, sex)
    sp = lambda pid, shape, sex=None: pair(pid, "Skin", "皮肤", "skin", SKIN, shape, sex)
    # head: chin → vertex. Face sections are squarer (flat front, cheeks, jaw angle); the skull above is rounder.
    s("head", loft([(0, 1.504, 0.062, 0.02, 0.016, 2.0), (0, 1.515, 0.05, 0.036, 0.032, 2.2), (0, 1.53, 0.034, 0.05, 0.062, 2.2),
                    (0, 1.55, 0.022, 0.058, 0.078, 2.3), (0, 1.575, 0.012, 0.064, 0.087, 2.4), (0, 1.6, 0.004, 0.068, 0.095, 2.3),
                    (0, 1.63, -0.002, 0.071, 0.099, 2.25), (0, 1.66, -0.008, 0.074, 0.1, 2.15), (0, 1.69, -0.012, 0.073, 0.096, 2.1),
                    (0, 1.715, -0.016, 0.066, 0.086, 2.0), (0, 1.733, -0.018, 0.054, 0.07, 2.0), (0, 1.744, -0.02, 0.038, 0.05, 2.0)]))
    # nose: narrow bridge between the eyes, widening to the tip and the nostril wings, sunk into the face
    s("nose", loft([(0, 1.636, 0.084, 0.006, 0.006), (0, 1.622, 0.089, 0.007, 0.008), (0, 1.607, 0.093, 0.009, 0.011),
                    (0, 1.594, 0.094, 0.013, 0.014), (0, 1.586, 0.093, 0.0165, 0.013), (0, 1.58, 0.092, 0.012, 0.009)], square=2.2))
    # eyes: ball sits in the face, lids wrap it top and bottom so only an almond of white shows
    for sx, side in ((1, "l"), (-1, "r")):
        cx, cy, cz, r = sx * 0.031, 1.627, 0.0765, 0.0125
        part(f"eye-{side}", "Eye", "眼睛", "skin", "#F4F1EC", sphere((cx, cy, cz), r))
        part(f"iris-{side}", "Eye", "眼睛", "skin", "#5A4636", sphere((cx, cy, cz + r * 0.93), 0.0052, [1, 1, 0.3]))
        part(f"pupil-{side}", "Eye", "眼睛", "skin", "#1E1A18", sphere((cx, cy, cz + r * 0.99), 0.0022, [1, 1, 0.3]))
        # lids: arcs hugging the ball; the upper one covers more
        up = [(cx + sx * r * 1.05 * math.cos(a), cy + r * 0.62 * math.sin(a) + 0.0015, cz + r * 1.02 * math.sin(a) * 0.55 + r * 0.55)
              for a in [math.pi * k / 6 for k in range(7)]]
        low = [(cx + sx * r * 1.0 * math.cos(a), cy - r * 0.55 * math.sin(a) - 0.001, cz + r * 0.5 + r * 0.45 * math.sin(a))
               for a in [math.pi * k / 6 for k in range(7)]]
        part(f"eyelid-{side}", "Skin", "皮肤", "skin", SKIN, tube(up, 0.0042, [0.002, 0.0042, 0.0048, 0.005, 0.0048, 0.0042, 0.002]))
        part(f"eyelid-lower-{side}", "Skin", "皮肤", "skin", SKIN, tube(low, 0.003, [0.0015, 0.003, 0.0035, 0.0035, 0.0035, 0.003, 0.0015]))
        part(f"brow-{side}", "Eyebrow", "眉毛", "skin", "#6B5344",
             loft([(sx * 0.014, 1.647, 0.09, 0.002, 0.003), (sx * 0.031, 1.652, 0.09, 0.003, 0.0035), (sx * 0.05, 1.647, 0.08, 0.0018, 0.0025)]))
    # lips: upper and lower, a little redder than skin
    part("lip-upper", "Lips", "嘴唇", "skin", "#D9968A",
         loft([(-0.021, 1.556, 0.092, 0.002, 0.003), (-0.01, 1.558, 0.098, 0.004, 0.005), (0.0, 1.557, 0.1, 0.0045, 0.005),
               (0.01, 1.558, 0.098, 0.004, 0.005), (0.021, 1.556, 0.092, 0.002, 0.003)]))
    part("lip-lower", "Lips", "嘴唇", "skin", "#D9968A",
         loft([(-0.018, 1.549, 0.091, 0.002, 0.003), (-0.009, 1.547, 0.096, 0.0045, 0.005), (0.0, 1.546, 0.097, 0.005, 0.0055),
               (0.009, 1.547, 0.096, 0.0045, 0.005), (0.018, 1.549, 0.091, 0.002, 0.003)]))
    part("chin", "Skin", "皮肤", "skin", SKIN, sphere((0, 1.518, 0.062), 0.016, [1.1, 0.9, 0.8]))
    # ear: oval with a rolled rim (helix) and a lobe
    sp("ear", loft([(0.074, 1.598, -0.004, 0.006, 0.01), (0.078, 1.612, -0.007, 0.007, 0.019), (0.08, 1.635, -0.01, 0.007, 0.023),
                    (0.078, 1.656, -0.013, 0.006, 0.018), (0.075, 1.667, -0.013, 0.004, 0.008)]))
    sp("ear-rim", tube([(0.079, 1.6, -0.002), (0.083, 1.62, -0.024), (0.084, 1.648, -0.03), (0.081, 1.665, -0.018), (0.078, 1.662, -0.004)], 0.0028))
    s("neck", loft([(0, 1.425, -0.02, 0.07, 0.06), (0, 1.45, -0.016, 0.062, 0.057), (0, 1.48, -0.012, 0.054, 0.054), (0, 1.52, -0.008, 0.05, 0.05), (0, 1.555, -0.012, 0.048, 0.05)]))
    s("adams-apple", sphere((0, 1.49, 0.043), 0.009, [1, 1.3, 0.8]), "male")
    # torso: crotch → neck; z offsets carry the chest, belly, back and buttocks
    # torso: crotch → neck; rounded-box sections, z offsets carry chest, belly, back and buttocks; shoulders slope into the trapezius
    torso = TORSO
    for sex, rows in torso.items():
        # boxy through chest and belly, rounding off over the shoulders
        s(f"torso-{sex}", loft([(0, y, z, rx, rz, 2.6 if y < 1.36 else 2.25 if y < 1.44 else 2.0) for y, z, rx, rz in rows]), sex)
    # breast: a dome rising out of the chest wall, fuller low
    sp("breast", lathe((0.08, 1.29, 0.06), (0.086, 1.27, 0.145), [0.062, 0.061, 0.056, 0.047, 0.036, 0.024], [1, 1, 0.92]), "female")
    # upper arm starts as a rounded deltoid cap tucked under the shoulder slope
    sp("upper-arm", loft(UPPER_ARM))
    sp("forearm", loft(FOREARM))
    # hand (palm forward): rounded palm, fleshy thumb base, fingers with knuckle bulges and round tips
    sp("hand", loft([(0.242, 0.856, 0.006, 0.025, 0.017), (0.241, 0.83, 0.008, 0.036, 0.018), (0.239, 0.8, 0.009, 0.041, 0.017),
                     (0.237, 0.776, 0.01, 0.042, 0.014), (0.236, 0.766, 0.01, 0.04, 0.011)], square=2.4))
    sp("thenar", sphere((0.257, 0.818, 0.018), 0.015, [0.9, 1.4, 0.75]))
    for key, x, length in (("index", 0.258, 0.08), ("middle", 0.24, 0.088), ("ring", 0.223, 0.082), ("little", 0.207, 0.064)):
        r = 0.0085 if key != "little" else 0.0075
        start, drift = (x, 0.77, 0.009), (x - 0.232) * 0.02
        # sections at base, first joint, middle, second joint, near tip
        secs = []
        for u, k in ((0.0, 1.0), (0.42, 1.02), (0.6, 0.93), (0.78, 0.94), (0.95, 0.8)):
            secs.append((start[0] + drift * u * 3, start[1] - length * u, start[2] + 0.012 * u, r * k, r * k * 0.88))
        sp(f"finger-skin-{key}", loft(secs))
    sp("thumb", loft([(0.252, 0.832, 0.013, 0.012, 0.011), (0.265, 0.806, 0.024, 0.0115, 0.0105), (0.274, 0.782, 0.034, 0.0098, 0.009),
                      (0.28, 0.763, 0.041, 0.0095, 0.0085), (0.285, 0.746, 0.047, 0.0078, 0.007)]))
    # thigh tapers hip → knee; calf bulges at the back of the upper shin
    sp("thigh", loft(THIGH))
    sp("shin", loft(SHIN))
    # foot: heel, tall ankle, instep, broad ball; ankle bones show either side
    sp("foot", loft([(0.088, 0.032, -0.058, 0.018, 0.022), (0.089, 0.038, -0.038, 0.026, 0.031), (0.09, 0.046, -0.008, 0.03, 0.041),
                     (0.092, 0.04, 0.03, 0.034, 0.033), (0.096, 0.03, 0.08, 0.041, 0.024), (0.1, 0.021, 0.128, 0.045, 0.017),
                     (0.1, 0.017, 0.15, 0.043, 0.013)], square=2.15))
    sp("malleolus-lateral", sphere((0.115, 0.074, -0.012), 0.007, [0.7, 1.2, 1.0]))
    sp("malleolus-medial", sphere((0.069, 0.084, -0.004), 0.0075, [0.7, 1.2, 1.0]))
    for key, x, tip, r in (("big", 0.07, 0.205, 0.0115), ("2nd", 0.087, 0.197, 0.0082), ("3rd", 0.1, 0.19, 0.0078),
                           ("4th", 0.112, 0.181, 0.0073), ("5th", 0.123, 0.17, 0.0068)):
        sp(f"toe-skin-{key}", loft([(x + 0.002, 0.018, 0.142, r, r * 0.85), (x + 0.001, 0.016, tip - 0.022, r * 0.95, r * 0.8),
                                    (x, 0.014, tip - 0.006, r * 0.9, r * 0.7)]))


# ---------------------------------------------------------------- organs (pulse targets + shapes)

ORGANS = []


def organ(oid, color, position, shapes, names=None, region=False, male=None):
    o = {"id": oid, "color": color, "position": U(*position), "shapes": shapes}
    if names:
        o["names"] = names
    if region:
        o["region"] = True
    if male:
        o["male"] = male
    ORGANS.append(o)


def bean(top, bottom, width, depth, sx, hilum=0.35):
    """Kidney: a vertical loft whose medial border dips in at the hilum."""
    secs = []
    for k in range(7):
        u = k / 6
        x, y, z = lerp(top, bottom, u)
        swell = math.sin(math.pi * (0.08 + 0.84 * u))
        dip = hilum * math.exp(-((u - 0.5) / 0.17) ** 2)
        rx = width * swell * (1 - dip * 0.5)
        secs.append((x + sx * width * dip * 0.5, y, z, rx, depth * swell))
    return loft(secs)


def organs():
    # brain: each hemisphere a front-to-back loft (rx = half-width, rz = half-height), sized to sit inside the skull;
    # temporal lobe below; cerebellum across the back
    brain = []

    def scaled(shape, k=0.88, c=(0, 1.655, -0.012)):
        """shrink a loft about the brain's centre so it clears the inside of the skull"""
        cu = U(*c)
        shape["sections"] = [[cu[n] + (q[n] - cu[n]) * k for n in range(3)] + [q[3] * k, q[4] * k] + q[5:] for q in shape["sections"]]
        return shape
    for sx in (1, -1):
        hemi = []
        for z, y, rx, ry in ((0.066, 1.654, 0.017, 0.022), (0.056, 1.661, 0.026, 0.033), (0.035, 1.671, 0.031, 0.041), (0.005, 1.678, 0.033, 0.045),
                             (-0.028, 1.676, 0.033, 0.045), (-0.055, 1.667, 0.03, 0.04), (-0.074, 1.654, 0.024, 0.031), (-0.083, 1.648, 0.016, 0.02)):
            hemi.append((sx * (0.003 + rx), y, z, rx, ry))
        brain.append(scaled(loft(hemi)))
        brain.append(scaled(loft([(sx * 0.044, 1.628, 0.04, 0.007, 0.007), (sx * 0.049, 1.622, 0.026, 0.014, 0.014), (sx * 0.051, 1.622, 0.0, 0.016, 0.016),
                           (sx * 0.048, 1.628, -0.026, 0.014, 0.014), (sx * 0.041, 1.638, -0.048, 0.007, 0.007)])))
    brain.append(scaled(loft([(0.048, 1.605, -0.055, 0.01, 0.013), (0.026, 1.601, -0.062, 0.021, 0.022), (0.0, 1.603, -0.06, 0.019, 0.019),
                       (-0.026, 1.601, -0.062, 0.021, 0.022), (-0.048, 1.605, -0.055, 0.01, 0.013)])))
    brain.append(tube([(0, 1.64, -0.018), (0, 1.605, -0.028), (0, 1.565, -0.034)], 0.011, [0.013, 0.011, 0.009]))
    organ("brain", "#E8A0B4", (0, 1.665, -0.01), brain, ["Brain", "脑"])

    # heart: base (upper right, back) to apex (lower left, front); flattened front-to-back; ventricles bulge low
    organ("heart", "#C8323C", (0.02, 1.27, 0.055), [
        loft([(-0.012, 1.315, 0.028, 0.03, 0.022), (0.0, 1.3, 0.04, 0.045, 0.034), (0.015, 1.275, 0.055, 0.052, 0.04),
              (0.03, 1.25, 0.068, 0.046, 0.036), (0.043, 1.23, 0.08, 0.03, 0.025), (0.049, 1.22, 0.086, 0.017, 0.014)]),
        # pulmonary trunk rising from the right ventricle, left auricle tucked at the top left
        tube([(0.012, 1.3, 0.07), (0.008, 1.325, 0.06), (0.0, 1.335, 0.045)], 0.011, [0.012, 0.011, 0.01]),
        sphere((0.05, 1.29, 0.05), 0.012, [1.1, 0.7, 0.8]),
        # right atrium bulge and auricles
        sphere((-0.03, 1.29, 0.04), 0.024, [0.9, 1.1, 0.9]),
        sphere((0.04, 1.305, 0.055), 0.012, [1.2, 0.7, 0.8]),
    ], ["Heart", "心脏"])

    # lungs: apex above the collarbone to a broad base on the diaphragm; left lung wraps the heart (cardiac notch)
    for side, sx, zh in (("l", 1, "左肺"), ("r", -1, "右肺")):
        notch = 0.018 if side == "l" else 0.0
        secs = []
        for y, cx, rx, rz in ((1.465, 0.055, 0.008, 0.01), (1.445, 0.06, 0.025, 0.03), (1.41, 0.07, 0.04, 0.05), (1.36, 0.08, 0.05, 0.065),
                              (1.31, 0.085 + notch * 0.6, 0.055 - notch * 0.6, 0.075), (1.26, 0.09 + notch, 0.058 - notch, 0.08),
                              (1.225, 0.092 + notch * 0.5, 0.058 - notch * 0.5, 0.078), (1.2, 0.095, 0.05, 0.06)):
            if side == "r":
                rx *= 1.05
            secs.append((sx * cx, y - (0.012 if side == "r" else 0), -0.01, rx, rz))
        organ(f"lung-{side}", "#E5868F", (0.085 * sx, 1.32, -0.005), [loft(secs)], ["Left lung" if side == "l" else "Right lung", zh])

    # liver: wedge running right → left (rx = half-height, rz = half-depth); big right lobe, thin left lobe tip
    organ("liver", "#8C3B2E", (-0.055, 1.175, 0.03), [loft([
        (-0.145, 1.165, 0.0, 0.035, 0.05), (-0.12, 1.17, 0.015, 0.068, 0.075), (-0.08, 1.18, 0.03, 0.07, 0.078),
        (-0.04, 1.19, 0.04, 0.055, 0.07), (0.0, 1.2, 0.05, 0.038, 0.055), (0.04, 1.21, 0.05, 0.022, 0.04), (0.075, 1.215, 0.04, 0.008, 0.018),
    ])], ["Liver", "肝"])
    organ("stomach", "#E39B4B", (0.065, 1.14, 0.05), [tube(
        [(0.03, 1.23, 0.0), (0.07, 1.22, 0.02), (0.1, 1.17, 0.045), (0.09, 1.11, 0.065), (0.055, 1.085, 0.07), (0.015, 1.09, 0.062), (-0.018, 1.108, 0.045)],
        0.03, [0.014, 0.04, 0.046, 0.04, 0.03, 0.02, 0.013])], ["Stomach", "胃"])
    organ("pancreas", "#E8C07A", (0.03, 1.105, -0.01), [tube([(-0.035, 1.09, 0.005), (-0.01, 1.1, -0.005), (0.03, 1.108, -0.015), (0.075, 1.122, -0.022), (0.1, 1.135, -0.03)],
                                                             0.011, [0.017, 0.013, 0.011, 0.009, 0.006])], ["Pancreas", "胰腺"])
    for side, sx, zh in (("l", 1, "左肾"), ("r", -1, "右肾")):
        drop = 0.015 if side == "r" else 0
        organ(f"kidney-{side}", "#7E2130", (0.06 * sx, 1.07 - drop, -0.06), [
            bean((0.052 * sx, 1.125 - drop, -0.062), (0.07 * sx, 1.015 - drop, -0.055), 0.028, 0.02, -sx),
        ], ["Left kidney" if side == "l" else "Right kidney", zh])
    # small intestine: rows of tight coils packed into the lower abdomen, framed by the colon
    small = []
    rows = 5
    for row in range(rows):
        y = 1.045 - row * 0.032
        x0, x1 = (-0.066, 0.066) if row % 2 == 0 else (0.066, -0.066)
        n, turns = 48, 4.5 + row % 2
        for k in range(n + (1 if row == rows - 1 else 0)):
            t = k / n
            a = t * 2 * math.pi * turns
            wob = 1 + 0.35 * math.sin(a * 0.37 + row * 1.3)
            small.append((x0 + (x1 - x0) * t + 0.007 * wob * math.sin(a), y + 0.009 * wob * math.cos(a), 0.062 + 0.014 * math.sin(a * 0.8 + row)))
    # colon: ascending → transverse → descending → sigmoid, pouched every few cm (haustra)
    frame = [(-0.075, 0.93, 0.05), (-0.1, 1.0, 0.045), (-0.095, 1.08, 0.04), (-0.03, 1.095, 0.07), (0.05, 1.1, 0.07),
             (0.1, 1.08, 0.04), (0.105, 0.99, 0.03), (0.085, 0.925, 0.03), (0.03, 0.9, 0.045), (0.005, 0.87, -0.02)]
    colon, radii = [], []
    for k in range(len(frame) - 1):
        for j in range(6):
            t = j / 6
            colon.append(tuple(frame[k][n] + (frame[k + 1][n] - frame[k][n]) * t for n in range(3)))
            radii.append(0.0195 + 0.0025 * math.cos((k * 6 + j) * 2 * math.pi / 3))
    colon.append(frame[-1]); radii.append(0.016)
    organ("intestines", "#D9A77A", (0.0, 0.99, 0.06), [
        tube(small, 0.0125),
        tube(colon, 0.02, radii),
    ], ["Intestines", "肠"])
    organ("bladder", "#E0C35A", (0, 0.895, 0.05), [lathe((0, 0.87, 0.045), (0, 0.925, 0.055), [0.012, 0.03, 0.036, 0.032, 0.02], [1.1, 1, 0.9])], ["Bladder", "膀胱"])
    organ("uterus", "#C77DA0", (0, 0.935, 0.025), [lathe((0, 0.975, 0.03), (0, 0.9, 0.02), [0.018, 0.03, 0.028, 0.015, 0.008], [1, 1, 0.7])],
          ["Uterus / prostate", "子宫 / 前列腺"],
          male={"position": U(0, 0.865, 0.03), "color": "#B98AA0", "shapes": [sphere((0, 0.865, 0.03), 0.017)]})
    # spleen: a curved slab hugging the left ribs behind the stomach
    organ("spleen", "#7A2C4A", (0.105, 1.14, -0.05), [loft([(0.085, 1.185, -0.075, 0.008, 0.01), (0.1, 1.17, -0.068, 0.018, 0.028), (0.112, 1.145, -0.052, 0.02, 0.032),
                                                          (0.118, 1.115, -0.032, 0.016, 0.026), (0.115, 1.095, -0.018, 0.006, 0.01)])], ["Spleen", "脾"])
    organ("gallbladder", "#5E8C3A", (-0.06, 1.13, 0.07), [lathe((-0.06, 1.15, 0.06), (-0.064, 1.105, 0.08), [0.004, 0.008, 0.012, 0.014, 0.011])], ["Gallbladder", "胆囊"])
    organ("adrenals", "#D9A13B", (0, 1.115, -0.058), [lathe((0.05, 1.13, -0.06), (0.054, 1.112, -0.058), [0.004, 0.012, 0.013, 0.006], [1.3, 1, 0.5]),
                                                   lathe((-0.05, 1.117, -0.06), (-0.054, 1.098, -0.058), [0.004, 0.012, 0.013, 0.006], [1.3, 1, 0.5])],
          ["Adrenal glands", "肾上腺"])
    organ("thyroid", "#C0506A", (0, 1.465, 0.04), [sphere((0.017, 1.465, 0.038), 0.011, [0.7, 1.5, 0.6]), sphere((-0.017, 1.465, 0.038), 0.011, [0.7, 1.5, 0.6]),
                                                   segment((0.012, 1.46, 0.045), (-0.012, 1.46, 0.045), 0.004)], ["Thyroid", "甲状腺"])
    organ("larynx", "#E8C4B0", (0, 1.49, 0.03), [lathe((0, 1.515, 0.028), (0, 1.47, 0.022), [0.017, 0.02, 0.016, 0.012])], ["Larynx", "喉"])
    organ("appendix", "#D9A77A", (-0.068, 0.9, 0.052), [tube([(-0.075, 0.925, 0.05), (-0.07, 0.9, 0.055), (-0.06, 0.885, 0.05)], 0.0045)], ["Appendix", "阑尾"])
    # regions light up only when a reflex pulse arrives
    organ("eyes", "#4FA3E0", (0, 1.625, 0.075), [sphere((0.032, 1.625, 0.075), 0.014), sphere((-0.032, 1.625, 0.075), 0.014)], region=True)
    organ("face", "#4FA3E0", (0, 1.58, 0.085), [sphere((0, 1.58, 0.085), 0.05, [1.3, 1.1, 0.4])], region=True)
    organ("ears", "#4FA3E0", (0, 1.63, 0.0), [sphere((0.08, 1.63, -0.005), 0.032, [0.5, 1, 0.8]), sphere((-0.08, 1.63, -0.005), 0.032, [0.5, 1, 0.8])], region=True)
    organ("sinuses", "#4FA3E0", (0, 1.61, 0.08), [sphere((0, 1.61, 0.08), 0.03, [1.4, 1, 0.6])], region=True)
    organ("throat", "#E07A9A", (0, 1.48, 0.035), [sphere((0, 1.48, 0.035), 0.022, [1, 1.5, 1])], region=True)
    organ("spine", "#B8A58A", (0, 1.25, -0.08), [tube([(0, 1.58, -0.02), (0, 1.4, -0.07), (0, 1.2, -0.085), (0, 1.0, -0.045)], 0.03)], region=True)
    organ("shoulders", "#FFD166", (0, 1.44, -0.02), [sphere((0.13, 1.44, -0.02), 0.06, [1.6, 0.6, 1]), sphere((-0.13, 1.44, -0.02), 0.06, [1.6, 0.6, 1])], region=True)


# ---------------------------------------------------------------- joints

def joints():
    out = []
    for side, sx in (("l", 1), ("r", -1)):
        f = lambda p: U(p[0] * sx, p[1], p[2])
        hand_bones = [p["id"] for p in PARTS if p["id"].endswith(f"-{side}") and any(
            p["id"].startswith(k) for k in ("carpals", "metacarpal", "phalanx", "thumb-", "finger-skin"))]
        foot_bones = [p["id"] for p in PARTS if p["id"].endswith(f"-{side}") and any(
            p["id"].startswith(k) for k in ("talus", "metatarsal", "toe-", "toe-skin"))]
        ids = lambda names: [f"{n}-{side}" for n in names]
        out += [
            {"id": f"shoulder-{side}", "name": "Shoulder — raise arm", "nameZh": "肩关节 外展", "pivot": f(SHOULDER),
             "axis": [0, 0, sx], "maxDeg": 160,
             "parts": ids(["humerus", "humeral-head", "biceps", "brachialis", "triceps", "upper-arm"]), "movers": [p["id"] for p in PARTS if p["id"].startswith("deltoid-") and p["id"].endswith(f"-{side}")]},
            {"id": f"elbow-{side}", "name": "Elbow — bend", "nameZh": "肘关节 屈曲", "pivot": f(ELBOW), "axis": [-1, 0, 0], "maxDeg": 145,
             "parent": f"shoulder-{side}",
             "parts": ids(["radius", "ulna", "brachioradialis", "forearm-flexors", "flexor-carpi-ulnaris", "forearm-extensors", "forearm", "hand", "thumb"]) + hand_bones,
             "movers": ids(["biceps"])},
            {"id": f"knee-{side}", "name": "Knee — bend", "nameZh": "膝关节 屈曲", "pivot": f(KNEE), "axis": [1, 0, 0], "maxDeg": 135,
             "parts": ids(["tibia", "fibula", "gastrocnemius-medial", "gastrocnemius-lateral", "soleus", "tibialis", "peroneus", "achilles", "shin", "foot"]) + foot_bones,
             "movers": ids(["hamstrings-medial", "hamstrings-lateral"])},
        ]
    return out


# ---------------------------------------------------------------- body-anchored positions elsewhere

POINTS = {
    "foot-head": (0.105, 0.028, 0.205), "foot-kidney": (0.093, 0.056, 0.06), "foot-liver": (-0.1, 0.05, 0.12),
    "foot-stomach": (0.104, 0.048, 0.12), "hand-hegu": (0.262, 0.8, -0.006), "hand-neiguan": (0.236, 0.9, 0.028),
    "ear-shenmen": (0.086, 1.655, 0.0), "body-zusanli": (0.128, 0.4, 0.04), "body-baihui": (0, 1.753, -0.01),
    "body-sanyinjiao": (0.068, 0.14, 0.0),
    "heart": (0.02, 1.27, 0.07), "aorta": (0.0, 1.37, 0.02), "arteries": (0.205, 1.24, 0.02), "capillaries": (0.245, 0.8, 0.02),
    "veins": (0.19, 1.3, -0.01), "venacava": (-0.03, 1.2, 0.0), "lungs": (-0.085, 1.33, 0.0),
}
ANCHORS = {"hand": (0.25, 0.78, 0.012), "foot": (0.095, 0.05, 0.1), "ear": (0.086, 1.63, 0.0)}


def write(path, data):
    text = json.dumps(data, ensure_ascii=False, indent=1)
    # one line per coordinate / radius list
    text = re.sub(r"\[\s*(-?[\d.e-]+(?:,\s*-?[\d.e-]+)*)\s*\]", lambda m: "[" + ", ".join(x.strip() for x in m.group(1).split(",")) + "]", text)
    path.write_text(text + "\n")


def main():
    skeleton()
    muscles()
    vessels()
    skin()
    organs()
    body = json.loads((DATA / "body.json").read_text())
    body.update(parts=PARTS, organs=ORGANS, joints=joints())
    body.pop("skin", None)
    body.pop("femaleSkin", None)
    write(DATA / "body.json", body)

    points = json.loads((DATA / "points.json").read_text())
    for sp in points.values():
        for p in sp["points"]:
            p["position"] = U(*POINTS[p["id"]])
    write(DATA / "points.json", points)

    charts = json.loads((DATA / "charts.json").read_text())
    for chart in charts["charts"]:
        a = ANCHORS[chart["id"]]
        chart["anchors"] = {"left": U(*a), "right": U(-a[0], a[1], a[2])}
    write(DATA / "charts.json", charts)
    print(f"{len(PARTS)} parts, {len(ORGANS)} organs")


if __name__ == "__main__":
    main()
