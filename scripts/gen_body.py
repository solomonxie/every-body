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


def plate(points, thickness):
    return {"kind": "plate", "points": [U(*p) for p in points], "thickness": L(thickness)}


def mirror_shape(s):
    s = json.loads(json.dumps(s))
    for key in ("center", "from", "to"):
        if key in s:
            s[key] = flip(s[key])
    for key in ("points",):
        if key in s:
            s[key] = [flip(p) for p in s[key]]
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


# ---------------------------------------------------------------- skeleton

def skeleton():
    # skull
    part("skull", "Skull (cranium)", "颅骨", "skeletal", BONE, sphere((0, 1.655, -0.012), 0.1, [0.78, 0.92, 0.98]))
    part("face-bones", "Facial bones", "面颅骨", "skeletal", BONE, sphere((0, 1.585, 0.05), 0.06, [0.95, 0.8, 0.75]))
    part("mandible", "Mandible", "下颌骨", "skeletal", BONE,
         tube([(0.052, 1.575, -0.005), (0.05, 1.53, 0.02), (0.035, 1.51, 0.065), (0, 1.505, 0.085),
               (-0.035, 1.51, 0.065), (-0.05, 1.53, 0.02), (-0.052, 1.575, -0.005)], 0.011))

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
    part("sacrum", "Sacrum", "骶骨", "skeletal", BONE,
         plate([(0.052, 0.99, -0.04), (0.046, 0.9, -0.07), (0.012, 0.83, -0.095), (-0.012, 0.83, -0.095),
                (-0.046, 0.9, -0.07), (-0.052, 0.99, -0.04)], 0.03))
    part("coccyx", "Coccyx", "尾骨", "skeletal", BONE, tube([(0, 0.83, -0.097), (0, 0.805, -0.09), (0, 0.79, -0.075)], 0.006))

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
        drop = 0.02 + 0.05 * min(i, 7) / 7
        pts = []
        for k in range(9):
            phi = 0.25 + (end - 0.25) * k / 8
            pts.append((a * math.sin(phi), yb - drop * (phi / math.pi) ** 1.3, zc - b * math.cos(phi)))
        pair(f"rib-{i + 1}", f"Rib {i + 1}", f"第{i + 1}肋", "skeletal", BONE, tube(pts, 0.0055))
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
    pair("clavicle", "Clavicle", "锁骨", "skeletal", BONE,
         tube([(0.02, 1.44, 0.1), (0.07, 1.447, 0.09), (0.12, 1.455, 0.045), (0.165, 1.46, 0.005), (0.19, 1.452, -0.015)], 0.0075))
    pair("scapula", "Scapula", "肩胛骨", "skeletal", BONE,
         plate([(0.075, 1.425, -0.1), (0.155, 1.405, -0.075), (0.172, 1.38, -0.055), (0.12, 1.3, -0.085), (0.1, 1.235, -0.1), (0.085, 1.33, -0.105)], 0.007))
    pair("scapular-spine", "Scapula", "肩胛骨", "skeletal", BONE, tube([(0.082, 1.385, -0.108), (0.14, 1.41, -0.092), (0.19, 1.445, -0.04)], 0.006))

    # upper limb
    pair("humeral-head", "Humeral head", "肱骨头", "skeletal", BONE, sphere(SHOULDER, 0.023))
    pair("humerus", "Humerus", "肱骨", "skeletal", BONE,
         lathe((0.188, 1.39, -0.028), (0.212, 1.105, -0.015), [0.02, 0.012, 0.0105, 0.0105, 0.012, 0.018, 0.022], [1.1, 1, 0.8]))
    pair("ulna", "Ulna", "尺骨", "skeletal", BONE, lathe((0.2, 1.118, -0.03), (0.224, 0.852, -0.004), [0.011, 0.0095, 0.0075, 0.0065, 0.006, 0.0075]))
    pair("radius", "Radius", "桡骨", "skeletal", BONE, lathe((0.226, 1.096, -0.008), (0.25, 0.853, 0.012), [0.0075, 0.007, 0.0075, 0.009, 0.011, 0.014]))
    pair("carpals", "Carpal bones", "腕骨", "skeletal", BONE, sphere((0.238, 0.832, 0.006), 0.02, [1.1, 0.6, 0.55]))
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
    pair("ilium", "Hip bone (ilium)", "髂骨", "skeletal", BONE,
         plate([(0.115, 1.035, 0.07), (0.145, 1.07, 0.02), (0.14, 1.085, -0.03), (0.095, 1.065, -0.075), (0.05, 0.97, -0.055),
                (0.07, 0.935, -0.02), (0.1, 0.93, 0.02), (0.115, 0.98, 0.06)], 0.012))
    pair("pubis-ischium", "Hip bone (pubis & ischium)", "耻骨与坐骨", "skeletal", BONE,
         tube([(0.1, 0.935, 0.02), (0.06, 0.9, 0.055), (0.012, 0.88, 0.065), (0.03, 0.85, 0.045), (0.06, 0.835, 0.0),
               (0.07, 0.85, -0.035), (0.085, 0.9, -0.02), (0.1, 0.935, 0.02)], 0.011))

    # lower limb
    pair("femoral-head", "Femoral head", "股骨头", "skeletal", BONE, sphere(HIP, 0.024))
    pair("femoral-neck", "Femoral neck", "股骨颈", "skeletal", BONE, segment(HIP, (0.13, 0.9, -0.005), 0.014))
    pair("femur", "Femur", "股骨", "skeletal", BONE,
         lathe((0.132, 0.915, -0.008), (0.098, 0.505, 0.0), [0.022, 0.016, 0.0135, 0.013, 0.0135, 0.017, 0.026], [1, 1, 0.95]))
    pair("femoral-condyles", "Femur", "股骨", "skeletal", BONE, sphere((0.097, 0.492, -0.003), 0.03, [1.25, 0.72, 1.0]))
    pair("patella", "Patella", "髌骨", "skeletal", BONE, sphere((0.098, 0.5, 0.042), 0.021, [0.95, 1.1, 0.5]))
    pair("tibia", "Tibia", "胫骨", "skeletal", BONE,
         lathe((0.095, 0.475, 0.004), (0.083, 0.078, 0.008), [0.034, 0.02, 0.0145, 0.013, 0.0135, 0.017, 0.02], [1.2, 1, 0.9]))
    pair("fibula", "Fibula", "腓骨", "skeletal", BONE, lathe((0.128, 0.46, -0.012), (0.122, 0.07, -0.008), [0.009, 0.006, 0.0055, 0.0065, 0.01]))
    pair("talus-calcaneus", "Heel bones (talus & calcaneus)", "距骨与跟骨", "skeletal", BONE, sphere((0.09, 0.04, -0.02), 0.03, [0.8, 1.0, 1.55]))
    toes = [("big", "拇趾", 0.068, 0.2, 0.012), ("2nd", "第2趾", 0.086, 0.196, 0.008), ("3rd", "第3趾", 0.1, 0.19, 0.0075),
            ("4th", "第4趾", 0.112, 0.18, 0.007), ("5th", "第5趾", 0.123, 0.168, 0.0065)]
    for key, zh, x, tip, r in toes:
        base = (0.078 + (x - 0.09) * 0.4, 0.045, 0.04)
        head = (x, 0.018, tip - 0.045)
        pair(f"metatarsal-{key}", "Metatarsal", "跖骨", "skeletal", BONE, lathe(base, head, [r * 0.8, r * 0.6, r * 0.6, r * 0.85]))
        pair(f"toe-{key}", "Toe phalanges", f"{zh}趾骨", "skeletal", BONE, lathe(head, (x, 0.013, tip), [r * 0.8, r * 0.65, r * 0.5]))


# ---------------------------------------------------------------- muscles (origin → insertion)

def muscles():
    m = lambda pid, name, zh, a, b, r: pair(pid, name, zh, "muscular", MUSCLE, spindle(a, b, r))
    m("sternocleidomastoid", "Sternocleidomastoid", "胸锁乳突肌", (0.052, 1.585, -0.02), (0.02, 1.44, 0.095), 0.012)
    m("trapezius-upper", "Trapezius", "斜方肌", (0.02, 1.6, -0.075), (0.18, 1.45, -0.035), 0.022)
    m("trapezius-middle", "Trapezius", "斜方肌", (0.01, 1.4, -0.105), (0.16, 1.42, -0.075), 0.02)
    m("trapezius-lower", "Trapezius", "斜方肌", (0.01, 1.14, -0.1), (0.1, 1.39, -0.11), 0.02)
    m("deltoid-anterior", "Deltoid", "三角肌", (0.15, 1.455, 0.035), (0.214, 1.285, -0.005), 0.022)
    m("deltoid-middle", "Deltoid", "三角肌", (0.2, 1.46, -0.02), (0.218, 1.285, -0.012), 0.024)
    m("deltoid-posterior", "Deltoid", "三角肌", (0.15, 1.425, -0.08), (0.214, 1.285, -0.02), 0.022)
    m("pectoralis-clavicular", "Pectoralis major", "胸大肌", (0.04, 1.44, 0.105), (0.19, 1.37, 0.0), 0.022)
    m("pectoralis-sternal", "Pectoralis major", "胸大肌", (0.025, 1.34, 0.13), (0.19, 1.365, 0.0), 0.03)
    m("pectoralis-lower", "Pectoralis major", "胸大肌", (0.06, 1.26, 0.125), (0.185, 1.36, 0.0), 0.024)
    m("biceps", "Biceps", "肱二头肌", (0.19, 1.37, 0.012), (0.222, 1.085, 0.01), 0.021)
    m("triceps", "Triceps", "肱三头肌", (0.18, 1.37, -0.06), (0.206, 1.11, -0.045), 0.023)
    m("brachioradialis", "Brachioradialis", "肱桡肌", (0.225, 1.17, 0.0), (0.252, 0.875, 0.012), 0.013)
    m("forearm-flexors", "Forearm flexors", "前臂屈肌", (0.2, 1.09, 0.004), (0.232, 0.88, 0.02), 0.017)
    m("forearm-extensors", "Forearm extensors", "前臂伸肌", (0.232, 1.09, -0.03), (0.244, 0.88, -0.012), 0.015)
    m("latissimus", "Latissimus dorsi", "背阔肌", (0.03, 1.1, -0.108), (0.18, 1.34, -0.035), 0.034)
    m("serratus", "Serratus anterior", "前锯肌", (0.14, 1.27, 0.04), (0.09, 1.34, -0.09), 0.016)
    m("rectus-abdominis", "Rectus abdominis", "腹直肌", (0.035, 1.25, 0.13), (0.018, 0.9, 0.095), 0.024)
    m("external-oblique", "External oblique", "腹外斜肌", (0.14, 1.2, 0.07), (0.07, 0.98, 0.105), 0.03)
    m("gluteus-maximus", "Gluteus maximus", "臀大肌", (0.05, 0.99, -0.1), (0.14, 0.83, -0.035), 0.048)
    m("gluteus-medius", "Gluteus medius", "臀中肌", (0.125, 1.05, -0.04), (0.132, 0.905, -0.012), 0.028)
    m("rectus-femoris", "Rectus femoris", "股直肌", (0.112, 0.935, 0.05), (0.098, 0.525, 0.05), 0.029)
    m("vastus-lateralis", "Vastus lateralis", "股外侧肌", (0.14, 0.885, 0.0), (0.118, 0.53, 0.022), 0.034)
    m("vastus-medialis", "Vastus medialis", "股内侧肌", (0.075, 0.8, 0.03), (0.08, 0.52, 0.035), 0.028)
    m("adductors", "Adductors", "内收肌群", (0.03, 0.87, 0.03), (0.075, 0.6, 0.0), 0.03)
    m("hamstrings-medial", "Hamstrings", "腘绳肌", (0.065, 0.84, -0.04), (0.085, 0.49, -0.035), 0.026)
    m("hamstrings-lateral", "Hamstrings", "腘绳肌", (0.085, 0.84, -0.05), (0.125, 0.49, -0.03), 0.026)
    m("gastrocnemius-medial", "Calf (gastrocnemius)", "腓肠肌", (0.078, 0.475, -0.035), (0.09, 0.22, -0.04), 0.027)
    m("gastrocnemius-lateral", "Calf (gastrocnemius)", "腓肠肌", (0.116, 0.475, -0.035), (0.096, 0.22, -0.04), 0.024)
    m("soleus", "Soleus", "比目鱼肌", (0.105, 0.4, -0.022), (0.09, 0.12, -0.035), 0.024)
    m("tibialis", "Tibialis anterior", "胫骨前肌", (0.112, 0.44, 0.028), (0.08, 0.1, 0.04), 0.014)
    pair("sartorius", "Sartorius", "缝匠肌", "muscular", MUSCLE,
         tube([(0.12, 1.05, 0.065), (0.09, 0.85, 0.06), (0.06, 0.65, 0.03), (0.075, 0.48, -0.005)], 0.008))
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

    v("esophagus", "Esophagus", "食管", "organs", "#E0A080", [(0, 1.52, -0.015), (0.0, 1.4, -0.03), (0.01, 1.27, -0.035), (0.03, 1.21, 0.0)], 0.0075)
    v("trachea", "Trachea & bronchi", "气管与支气管", "organs", "#E8C4B0",
      [(0, 1.52, 0.02), (0, 1.43, 0.012), (0, 1.36, 0.0), (0.045, 1.33, -0.005)], 0.009)
    v("bronchus-r", "Bronchi", "支气管", "organs", "#E8C4B0", [(0, 1.36, 0.0), (-0.045, 1.33, -0.005)], 0.008)


# ---------------------------------------------------------------- skin (translucent figure)

def skin():
    s = lambda pid, shape, sex=None: part(pid, "Skin", "皮肤", "skin", SKIN, shape, sex)
    sp = lambda pid, shape: pair(pid, "Skin", "皮肤", "skin", SKIN, shape)
    s("head", sphere((0, 1.635, 0.0), 0.11, [0.72, 1.06, 0.94]))
    s("neck", lathe((0, 1.535, -0.012), (0, 1.43, -0.012), [0.05, 0.054, 0.06], [1, 1, 0.92]))
    heights = [0.8, 0.9, 0.98, 1.05, 1.12, 1.2, 1.3, 1.38, 1.44, 1.475]
    male = [0.07, 0.165, 0.158, 0.148, 0.143, 0.152, 0.168, 0.185, 0.19, 0.06]
    female = [0.07, 0.185, 0.17, 0.132, 0.128, 0.142, 0.158, 0.172, 0.178, 0.06]
    for sex, widths in (("male", male), ("female", female)):
        s(f"torso-{sex}", lathe((0, heights[0], 0.0), (0, heights[-1], 0.0), widths, [1, 1, 0.64]), sex)
    pair("breast", "Skin", "皮肤", "skin", SKIN, sphere((0.085, 1.285, 0.1), 0.055, [1, 0.95, 0.8]), "female")
    sp("ear", sphere((0.078, 1.63, -0.005), 0.03, [0.35, 1, 0.65]))
    sp("upper-arm", lathe((0.19, 1.43, -0.025), (0.214, 1.1, -0.012), [0.048, 0.047, 0.043, 0.037, 0.034], [1, 1, 0.95]))
    sp("forearm", lathe((0.214, 1.1, -0.012), (0.242, 0.855, 0.006), [0.034, 0.037, 0.032, 0.026, 0.021], [1, 1, 0.85]))
    sp("hand", lathe((0.24, 0.855, 0.006), (0.236, 0.672, 0.012), [0.022, 0.036, 0.042, 0.038, 0.03, 0.012], [1, 1, 0.42]))
    sp("thumb", lathe((0.252, 0.83, 0.01), (0.285, 0.738, 0.05), [0.014, 0.012, 0.011, 0.008]))
    sp("thigh", lathe((0.1, 0.96, 0.0), (0.097, 0.505, 0.008), [0.075, 0.085, 0.078, 0.068, 0.058, 0.05]))
    sp("shin", lathe((0.097, 0.505, 0.008), (0.086, 0.075, 0.0), [0.05, 0.054, 0.05, 0.04, 0.032, 0.029], [1, 1, 1.05]))
    sp("foot", lathe((0.088, 0.035, -0.055), (0.1, 0.022, 0.205), [0.028, 0.036, 0.04, 0.043, 0.038, 0.015], [1, 1, 0.55]))


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


def organs():
    organ("brain", "#E8A0B4", (0, 1.665, -0.01), [
        sphere((0.034, 1.668, -0.008), 0.05, [0.68, 1.0, 1.7]),
        sphere((-0.034, 1.668, -0.008), 0.05, [0.68, 1.0, 1.7]),
        sphere((0, 1.608, -0.062), 0.028, [1.8, 0.85, 1.0]),
        segment((0, 1.625, -0.03), (0, 1.565, -0.035), 0.011),
    ], ["Brain", "脑"])
    organ("heart", "#C8323C", (0.02, 1.27, 0.055), [lathe((-0.005, 1.31, 0.03), (0.045, 1.215, 0.085), [0.03, 0.043, 0.045, 0.038, 0.022, 0.005])],
          ["Heart", "心脏"])
    for side, sx, zh in (("l", 1, "左肺"), ("r", -1, "右肺")):
        organ(f"lung-{side}", "#E5868F", (0.085 * sx, 1.32, -0.005),
              [lathe((0.07 * sx, 1.455, -0.005), (0.1 * sx, 1.21, -0.005), [0.012, 0.035, 0.052, 0.062, 0.066 if side == "r" else 0.058, 0.06, 0.03], [0.85, 1, 1.25])],
              ["Left lung" if side == "l" else "Right lung", zh])
    organ("liver", "#8C3B2E", (-0.055, 1.175, 0.03), [sphere((-0.055, 1.175, 0.03), 0.1, [1.15, 0.5, 0.75], [0, 0, -0.25])], ["Liver", "肝"])
    organ("stomach", "#E39B4B", (0.065, 1.14, 0.05), [tube(
        [(0.035, 1.225, 0.01), (0.075, 1.21, 0.025), (0.095, 1.15, 0.05), (0.07, 1.095, 0.07), (0.025, 1.09, 0.065), (-0.015, 1.11, 0.045)],
        0.03, [0.03, 0.042, 0.04, 0.032, 0.022, 0.014])], ["Stomach", "胃"])
    organ("pancreas", "#E8C07A", (0.03, 1.105, -0.01), [tube([(-0.03, 1.095, 0.0), (0.02, 1.105, -0.012), (0.085, 1.125, -0.02)], 0.011, [0.014, 0.011, 0.008])],
          ["Pancreas", "胰腺"])
    for side, sx, zh in (("l", 1, "左肾"), ("r", -1, "右肾")):
        organ(f"kidney-{side}", "#7E2130", (0.06 * sx, 1.07 - (0.012 if side == "r" else 0), -0.06),
              [sphere((0.06 * sx, 1.07 - (0.012 if side == "r" else 0), -0.06), 0.03, [0.8, 1.9, 0.65], [0, 0, 0.25 * sx])],
              ["Left kidney" if side == "l" else "Right kidney", zh])
    small = []
    for row in range(5):
        y = 1.04 - row * 0.024
        xs = [-0.07, 0.07] if row % 2 == 0 else [0.07, -0.07]
        for k in range(4):
            x = xs[0] + (xs[1] - xs[0]) * k / 3
            small.append((x, y + 0.006 * math.sin(k * 2), 0.06 + 0.012 * math.cos(k * 1.7 + row)))
    organ("intestines", "#D9A77A", (0.0, 0.99, 0.06), [
        tube(small, 0.011),
        tube([(-0.075, 0.93, 0.05), (-0.1, 1.0, 0.045), (-0.095, 1.08, 0.04), (-0.03, 1.095, 0.07), (0.05, 1.1, 0.07),
              (0.1, 1.08, 0.04), (0.105, 0.99, 0.03), (0.085, 0.925, 0.03), (0.03, 0.9, 0.045), (0.005, 0.87, -0.02)], 0.02),
    ], ["Intestines", "肠"])
    organ("bladder", "#E0C35A", (0, 0.895, 0.05), [sphere((0, 0.895, 0.05), 0.032, [1.1, 0.9, 1.0])], ["Bladder", "膀胱"])
    organ("uterus", "#C77DA0", (0, 0.935, 0.025), [lathe((0, 0.975, 0.03), (0, 0.9, 0.02), [0.018, 0.03, 0.028, 0.015, 0.008], [1, 1, 0.7])],
          ["Uterus / prostate", "子宫 / 前列腺"],
          male={"position": U(0, 0.865, 0.03), "color": "#B98AA0", "shapes": [sphere((0, 0.865, 0.03), 0.017)]})
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
            p["id"].startswith(k) for k in ("carpals", "metacarpal", "phalanx", "thumb-"))]
        foot_bones = [p["id"] for p in PARTS if p["id"].endswith(f"-{side}") and any(
            p["id"].startswith(k) for k in ("talus", "metatarsal", "toe-"))]
        ids = lambda names: [f"{n}-{side}" for n in names]
        out += [
            {"id": f"shoulder-{side}", "name": "Shoulder — raise arm", "nameZh": "肩关节 外展", "pivot": f(SHOULDER),
             "axis": [0, 0, sx], "maxDeg": 160,
             "parts": ids(["humerus", "humeral-head", "biceps", "triceps", "upper-arm"]), "movers": ids(["deltoid-middle"])},
            {"id": f"elbow-{side}", "name": "Elbow — bend", "nameZh": "肘关节 屈曲", "pivot": f(ELBOW), "axis": [-1, 0, 0], "maxDeg": 145,
             "parent": f"shoulder-{side}",
             "parts": ids(["radius", "ulna", "brachioradialis", "forearm-flexors", "forearm-extensors", "forearm", "hand", "thumb"]) + hand_bones,
             "movers": ids(["biceps"])},
            {"id": f"knee-{side}", "name": "Knee — bend", "nameZh": "膝关节 屈曲", "pivot": f(KNEE), "axis": [1, 0, 0], "maxDeg": 135,
             "parts": ids(["tibia", "fibula", "gastrocnemius-medial", "gastrocnemius-lateral", "soleus", "tibialis", "achilles", "shin", "foot"]) + foot_bones,
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
