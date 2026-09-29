"""Acupuncture points (WHO Standard Acupuncture Point Locations, 2008) and meridian lines, placed on the skin mesh.

Each point is a landmark in metres (cun measured from gen_body's skeleton) turned into a ray that is cast against the
very skin lofts the app draws, so dots and lines sit on the surface for both sexes and both sides.
Used by gen_body.py; writes the "acupuncture" entry of points.json.
"""

import bisect
import math

SCALE = 1.86


def U(x, y, z):
    return (x * SCALE, y * SCALE - 1.6, z * SCALE)


def norm(v):
    n = math.sqrt(sum(c * c for c in v)) or 1.0
    return tuple(c / n for c in v)


def add(a, b, k=1.0):
    return tuple(a[i] + b[i] * k for i in range(3))


def dot(a, b):
    return sum(a[i] * b[i] for i in range(3))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


# ---------------------------------------------------------------- skin mesh (mirrors Meshes.loft in Swift)

class Loft:
    def __init__(self, sections):
        n = len(sections)
        steps = (n - 1) * 4

        def at(u):
            f = min(n - 1 - 0.0001, max(0.0, u * (n - 1)))
            i, t = int(f), f - int(f)
            a, b, c, d = sections[max(0, i - 1)], sections[i], sections[min(n - 1, i + 1)], sections[min(n - 1, i + 2)]
            t2, t3 = t * t, t * t * t
            return [0.5 * (2 * b[k] + (-a[k] + c[k]) * t + (2 * a[k] - 5 * b[k] + 4 * c[k] - d[k]) * t2
                           + (-a[k] + 3 * b[k] - 3 * c[k] + d[k]) * t3) for k in range(len(a))]

        rows = [at(k / steps) for k in range(steps + 1)]

        def dome(end, inward):
            d = norm(tuple(end[k] - inward[k] + 1e-7 for k in range(3)))
            r = min(end[3], end[4])
            out = []
            for k0, k1 in ((0.34, 0.75), (0.5, 0.35)):
                row = list(end)
                for k in range(3):
                    row[k] += d[k] * r * k0
                row[3] *= k1
                row[4] *= k1
                out.append(row)
            return out

        rows = list(reversed(dome(rows[0], rows[1]))) + rows + dome(rows[-1], rows[-2])
        sides = 96 if len(sections[0]) > 6 else 32
        self.rows = []
        for i, r in enumerate(rows):
            c = tuple(r[:3])
            prev, nxt = rows[max(0, i - 1)], rows[min(len(rows) - 1, i + 1)]
            t = norm(tuple(nxt[k] - prev[k] + 1e-6 for k in range(3)))
            if abs(t[1]) > 0.6:
                side, depth = (1.0, 0.0, 0.0), (0.0, 0.0, -1.0 if t[1] > 0 else 1.0)
            else:
                ref = (0.0, 1.0, 0.0) if abs(t[0]) > 0.8 else (1.0, 0.0, 0.0)
                side = norm(tuple(ref[k] - dot(ref, t) * t[k] + 1e-6 for k in range(3)))
                depth = cross(side, t)
            e = 2 / max(r[5], 1) if len(r) > 5 else 1
            ring = []
            for s in range(sides):
                a = s / sides * 2 * math.pi
                ca, sa = math.cos(a), math.sin(a)
                cx, sy = math.copysign(abs(ca) ** e, ca), math.copysign(abs(sa) ** e, sa)
                k = 1.0
                if len(r) > 6:
                    m = len(r) - 6
                    f = s / sides * m
                    i0 = int(f) % m
                    w = f - int(f)
                    k = r[6 + i0] * (1 - w) + r[6 + (i0 + 1) % m] * w
                ring.append((k * cx * r[3], k * sy * r[4]))
            ring.sort(key=lambda q: math.atan2(q[1], q[0]))
            self.rows.append((c, side, depth, [math.atan2(q[1], q[0]) for q in ring], ring))
        ends = rows[-1][:3], rows[0][:3]
        self.axis = 1 if abs(ends[0][1] - ends[1][1]) >= abs(ends[0][2] - ends[1][2]) else 2
        if self.rows[0][0][self.axis] > self.rows[-1][0][self.axis]:
            self.rows.reverse()
        self.levels = [row[0][self.axis] for row in self.rows]

    def _gap(self, i, p):
        """(distance of p from row i's center in its plane) − (boundary radius in that direction)."""
        c, side, depth, angles, ring = self.rows[i]
        v = (p[0] - c[0], p[1] - c[1], p[2] - c[2])
        x, y = dot(v, side), dot(v, depth)
        d = math.hypot(x, y)
        if d < 1e-9:
            return -1.0
        a = math.atan2(y, x)
        j = bisect.bisect_left(angles, a) % len(ring)
        p1, p2 = ring[j - 1], ring[j]
        ex, ey = p2[0] - p1[0], p2[1] - p1[1]
        ux, uy = x / d, y / d
        den = ux * ey - uy * ex
        r = (p1[0] * ey - p1[1] * ex) / den if abs(den) > 1e-12 else math.hypot(*p1)
        return d - r

    def gap(self, p):
        lv = p[self.axis]
        if lv < self.levels[0] or lv > self.levels[-1]:
            return 1.0
        i = min(len(self.levels) - 2, max(0, bisect.bisect_right(self.levels, lv) - 1))
        span = self.levels[i + 1] - self.levels[i]
        t = (lv - self.levels[i]) / span if span > 1e-9 else 0.0
        return (1 - t) * self._gap(i, p) + t * self._gap(i + 1, p)

    def centre(self, level):
        i = min(len(self.levels) - 2, max(0, bisect.bisect_right(self.levels, level) - 1))
        span = self.levels[i + 1] - self.levels[i]
        t = (level - self.levels[i]) / span if span > 1e-9 else 0.0
        a, b = self.rows[i][0], self.rows[i + 1][0]
        return tuple(a[k] + (b[k] - a[k]) * t for k in range(3))


class Skin:
    """Skin lofts by logical name ("forearm", "torso", …) for one sex and one side."""

    PAIRED = {"upper-arm", "forearm", "hand", "thumb", "thigh", "shin", "foot", "ear",
              "finger-skin-index", "finger-skin-middle", "finger-skin-ring", "finger-skin-little",
              "toe-skin-big", "toe-skin-2nd", "toe-skin-3rd", "toe-skin-4th", "toe-skin-5th"}

    def __init__(self, parts):
        self.shapes = {p["id"]: p["shape"] for p in parts if p["layer"] == "skin" and p["shape"]["kind"] == "loft"}
        self.cache = {}

    def loft(self, name, sex, side):
        pid = f"{name}-{sex}" if name in ("torso", "head") else f"{name}-{side}" if name in self.PAIRED else name
        if pid not in self.cache:
            self.cache[pid] = Loft(self.shapes[pid]["sections"])
        return self.cache[pid]


# ---------------------------------------------------------------- placement specs (metres, figure's left side)

class Ray:
    """Cast from `origin` (inside the body) outward along `dir` onto the outermost of `parts`."""

    def __init__(self, parts, origin, direction, anchor=None):
        self.parts, self.origin, self.dir, self.anchor = tuple(parts), origin, norm(direction), anchor

    def resolve(self, skin, sex, side):
        sx = 1 if side == "l" else -1
        lofts = [skin.loft(n, sex, side) for n in self.parts]
        d = (self.dir[0] * sx, self.dir[1], self.dir[2])
        if self.anchor is not None:
            # radial: from the first part's axis at this height
            y = self.anchor
            o = lofts[0].centre(U(0, y, 0)[1])
        else:
            o = U(self.origin[0] * sx, self.origin[1], self.origin[2])
        return o, d, lofts


def A(y, theta, *parts):
    """On a limb (or the head/torso) at height y, angle theta: 0 = outer (+x), 90 = front, 180 = inner, 270 = back."""
    t = math.radians(theta)
    return Ray(parts, None, (math.cos(t), 0, math.sin(t)), anchor=y)


def F(x, y, *parts):
    return Ray(parts or ("torso",), (x, y, 0.0), (0, 0, 1))


def B(x, y, *parts):
    return Ray(parts or ("torso",), (x, y, -0.03), (0, 0, -1))


def R(origin, direction, *parts):
    return Ray(parts, origin, direction)


def H(phi, x=0.0):
    """Over the scalp in a sagittal arc: phi 0 = forehead, 90 = crown, 180 = back of the head."""
    p = math.radians(phi)
    return Ray(("head",), (x, 1.655, -0.012), (0, math.sin(p), math.cos(p)))


REACH = 0.25 * SCALE
STEP = 0.002 * SCALE


def cast(spec, skin, sex, side, lift):
    o, d, lofts = spec.resolve(skin, sex, side)

    def gap(q):
        return min(l.gap(q) for l in lofts)
    far = add(o, d, REACH)
    k = 0.0
    while k < REACH and gap(add(far, d, -k)) > 0:
        k += STEP
    if k >= REACH:
        raise ValueError(f"ray misses {spec.parts} from {o} along {d}")
    lo, hi = k - STEP, k
    for _ in range(24):
        mid = (lo + hi) / 2
        if gap(add(far, d, -mid)) > 0:
            lo = mid
        else:
            hi = mid
    q = add(far, d, -hi)
    return add(q, d, lift * SCALE), d


# ---------------------------------------------------------------- landmarks

# forearm: cubital crease → wrist crease = 12 cun
ELBOW_Y, WRIST_Y = 1.10, 0.853
ARM_CUN = (ELBOW_Y - WRIST_Y) / 12
# leg: popliteal crease → lateral malleolus = 16 cun; tibial medial condyle → medial malleolus = 13 cun
KNEE_Y, LAT_MAL_Y, MED_MAL_Y = 0.49, 0.074, 0.084
LEG_CUN = (KNEE_Y - LAT_MAL_Y) / 16
MED_CUN = (0.455 - MED_MAL_Y) / 13
# thigh: base of the patella → pubic symphysis = 18 cun
PATELLA_TOP, PUBIS = 0.525, 0.892
THIGH_CUN = (PUBIS - PATELLA_TOP) / 18
# abdomen: xiphisternal junction → navel = 8 cun; navel → pubic symphysis = 5 cun
XIPHOID, NAVEL = 1.24, 1.045
UPPER_CUN, LOWER_CUN = (XIPHOID - NAVEL) / 8, (NAVEL - PUBIS) / 5
# chest: nipples 8 cun apart; back: medial borders of the shoulder blades 6 cun apart
CHEST_CUN = 0.095 / 4
BACK_CUN = 0.074 / 3
INNER_BL, OUTER_BL = 1.5 * BACK_CUN, 3 * BACK_CUN


def spinous(prefix, n):
    """Height of the lower border of a spinous process (matches gen_body's spine)."""
    if prefix == "C":
        return 1.585 - (n - 1) * 0.018 - 0.014 - 0.002
    if prefix == "T":
        return 1.459 - (n - 1) * 0.0245 - 0.00975 - 0.021
    return 1.1645 - (n - 1) * 0.0365 - 0.0135 - 0.008


# ---------------------------------------------------------------- meridians

MERIDIANS = [
    ("LU", "Lung meridian", "手太阴肺经", "#5B8DEF"),
    ("LI", "Large Intestine meridian", "手阳明大肠经", "#20A4B5"),
    ("ST", "Stomach meridian", "足阳明胃经", "#F2A20C"),
    ("SP", "Spleen meridian", "足太阴脾经", "#8FA81C"),
    ("HT", "Heart meridian", "手少阴心经", "#E0474F"),
    ("SI", "Small Intestine meridian", "手太阳小肠经", "#EF8A9A"),
    ("BL", "Bladder meridian", "足太阳膀胱经", "#3F5BD0"),
    ("KI", "Kidney meridian", "足少阴肾经", "#6A4BA8"),
    ("PC", "Pericardium meridian", "手厥阴心包经", "#D2508F"),
    ("TE", "Triple Energizer meridian", "手少阳三焦经", "#E4602A"),
    ("GB", "Gallbladder meridian", "足少阳胆经", "#3FA34D"),
    ("LR", "Liver meridian", "足厥阴肝经", "#0F766E"),
    ("GV", "Governor Vessel", "督脉", "#6B5645"),
    ("CV", "Conception Vessel", "任脉", "#9A5B2E"),
]
EXTRA = ("EX", "Extra points", "经外奇穴", "#7D7D8C")

# ---------------------------------------------------------------- points
# code, pinyin, 汉字, English name, region, commonly needled, organ ids, spec,
# location, 定位, traditional uses, 主治, needling, 刺法

P = []


def point(code, pinyin, zh, en, region, common, organs, spec, loc, loc_zh, uses, uses_zh, needle, needle_zh, aliases=()):
    P.append(dict(code=code, pinyin=pinyin, zh=zh, en=en, region=region, common=common, organs=organs, spec=spec,
                  loc=loc, loc_zh=loc_zh, uses=uses, uses_zh=uses_zh, needle=needle, needle_zh=needle_zh, aliases=list(aliases)))


# head & neck
point("GV20", "Baihui", "百会", "Hundred Convergences", "head", True, ["brain"], R((0, 1.70, -0.012), (0, 1, 0.04), "head"),
      "On the midline of the head, 5 cun above the front hairline — where the line joining the ear tips crosses the midline.",
      "头部，前发际正中直上5寸；两耳尖连线与头正中线的交点。",
      "Headache, dizziness, insomnia, poor memory; traditionally lifts ‘sinking’ problems such as prolapse.",
      "头痛、眩晕、失眠、健忘；传统用于脱肛、子宫脱垂等下陷病证。",
      "Transverse (flat under the scalp) 0.5–0.8 cun; moxibustion also used.", "平刺0.5–0.8寸；可灸。")
point("EX-HN3", "Yintang", "印堂", "Hall of Impression", "head", True, ["brain", "sinuses"], F(0, 1.648, "head", "nose"),
      "On the forehead, in the depression midway between the inner ends of the eyebrows.", "额部，两眉毛内侧端中间的凹陷中。",
      "Headache, dizziness, insomnia, anxiety, blocked or runny nose.", "头痛、眩晕、失眠、焦虑、鼻塞、鼻渊。",
      "Pinch up the skin; transverse downward 0.3–0.5 cun.", "提捏局部皮肤，向下平刺0.3–0.5寸。", ["GV29"])
point("EX-HN5", "Taiyang", "太阳", "Sun", "head", True, ["brain", "eyes"], A(1.636, 42, "head"),
      "At the temple, in the hollow about one finger-breadth behind the midpoint between the outer end of the eyebrow and the outer corner of the eye.",
      "颞部，眉梢与目外眦之间，向后约一横指的凹陷中。",
      "Headache (especially one-sided), migraine, red painful eyes, toothache, facial paralysis.",
      "头痛（尤其偏头痛）、目赤肿痛、牙痛、面瘫。",
      "Perpendicular or oblique 0.3–0.5 cun, or prick to bleed.", "直刺或斜刺0.3–0.5寸，或点刺出血。")
point("BL2", "Zanzhu", "攒竹", "Gathered Bamboo", "head", False, ["eyes"], F(0.016, 1.649, "head"),
      "In the depression at the inner end of the eyebrow, over the frontal notch.", "面部，眉头凹陷中，额切迹处。",
      "Frontal headache, eye strain, blurred vision, twitching eyelids, hiccups.", "前额头痛、目视不明、眼睑瞤动、目赤肿痛、呃逆。",
      "Transverse 0.3–0.5 cun along the eyebrow. Close to the eye — moxibustion is not used.", "平刺0.3–0.5寸；邻近眼部，不宜灸。")
point("LI20", "Yingxiang", "迎香", "Welcome Fragrance", "head", True, ["sinuses"], F(0.021, 1.586, "head", "nose"),
      "In the groove beside the nose (nasolabial fold), level with the midpoint of the outer edge of the nostril wing.",
      "面部，鼻翼外缘中点旁，鼻唇沟中。",
      "Blocked or runny nose, loss of smell, sinus congestion, nosebleed, facial itching.", "鼻塞、鼻渊、不闻香臭、鼻衄、面痒。",
      "Oblique or transverse upward 0.3–0.5 cun.", "向内上方斜刺或平刺0.3–0.5寸。")
point("GV26", "Shuigou", "水沟", "Water Trough", "head", True, ["brain"], F(0, 1.571, "head", "nose", "lip-upper"),
      "On the upper lip, one-third of the way down the groove under the nose (philtrum).", "面部，人中沟的上1/3与中1/3交点处。",
      "Traditional first aid for fainting, collapse and seizures; sudden low-back sprain.", "昏厥、休克、癫痫的传统急救穴；急性腰扭伤。",
      "Oblique upward 0.3–0.5 cun, or strong fingernail pressure.", "向上斜刺0.3–0.5寸，或用指甲重掐。", ["Renzhong", "人中"])
point("ST6", "Jiache", "颊车", "Jaw Vehicle", "head", False, ["face"], A(1.545, -15, "head", "neck"),
      "One finger-breadth in front of and above the angle of the jaw, on the muscle bulge when the teeth are clenched.",
      "面部，下颌角前上方一横指，咀嚼时咬肌隆起处。",
      "Toothache, jaw pain and stiffness, facial paralysis, swollen cheek.", "牙痛、颊肿、牙关紧闭、口眼歪斜。",
      "Perpendicular 0.3–0.5 cun, or transverse toward Dicang (ST4) 0.5–1 cun.", "直刺0.3–0.5寸，或向地仓方向平刺0.5–1寸。")
point("TE17", "Yifeng", "翳风", "Wind Screen", "head", False, ["ears"], A(1.592, -32, "head"),
      "Behind the earlobe, in the hollow between the mastoid process and the angle of the jaw.", "颈部，耳垂后方，乳突下端前方凹陷中。",
      "Tinnitus, deafness, ear pain, facial paralysis, jaw pain, hiccups.", "耳鸣、耳聋、耳痛、口眼歪斜、颊肿、呃逆。",
      "Perpendicular 0.5–1 cun.", "直刺0.5–1寸。", ["SJ17"])
point("GB20", "Fengchi", "风池", "Wind Pool", "head", True, ["brain"], B(0.033, 1.562, "head", "neck"),
      "At the back of the neck under the skull, in the hollow between the upper ends of the sternocleidomastoid and trapezius muscles.",
      "颈后区，枕骨之下，胸锁乳突肌上端与斜方肌上端之间的凹陷中。",
      "Headache, dizziness, stiff neck, common cold, blurred vision, tinnitus, high blood pressure.",
      "头痛、眩晕、颈项强痛、感冒、目视不明、耳鸣、高血压。",
      "Oblique toward the tip of the nose 0.8–1.2 cun. Never deep, upward or inward — the medulla lies beneath.",
      "针尖微下，向鼻尖方向斜刺0.8–1.2寸；深部为延髓，严禁向内上方深刺。")
point("CV22", "Tiantu", "天突", "Celestial Chimney", "head", False, ["throat", "lung-l", "lung-r"], F(0, 1.442, "neck", "torso"),
      "At the base of the throat, in the center of the notch above the breastbone.", "颈前区，胸骨上窝中央，前正中线上。",
      "Cough, asthma, sore throat, sudden loss of voice, hiccups, a feeling of a lump in the throat.",
      "咳嗽、哮喘、咽喉肿痛、暴喑、呃逆、梅核气。",
      "Perpendicular 0.2 cun, then turned down behind the breastbone 0.5–1 cun. Specialist technique — trachea, great vessels and lungs lie close.",
      "先直刺0.2寸，再将针尖转向下方，紧贴胸骨柄后缘刺入0.5–1寸；邻近气管、大血管与肺，须由专业人员操作。")

# arm
point("LU5", "Chize", "尺泽", "Cubit Marsh", "arm", True, ["lung-l", "lung-r"], A(ELBOW_Y, 68, "forearm", "upper-arm"),
      "On the elbow crease, in the hollow on the thumb side of the biceps tendon.", "肘区，肘横纹上，肱二头肌腱桡侧缘凹陷中。",
      "Cough, asthma, coughing blood, sore throat, fever, elbow and arm pain.", "咳嗽、气喘、咳血、咽喉肿痛、潮热、肘臂挛痛。",
      "Perpendicular 0.8–1.2 cun, or prick the vein to bleed.", "直刺0.8–1.2寸，或点刺出血。")
point("LU7", "Lieque", "列缺", "Broken Sequence", "arm", True, ["lung-l", "lung-r"], A(WRIST_Y + 1.5 * ARM_CUN, 12, "forearm"),
      "On the thumb side of the forearm, 1.5 cun above the wrist crease, just above the bony knob of the radius, in the groove of the abductor pollicis longus tendon.",
      "前臂，腕掌侧远端横纹上1.5寸，桡骨茎突上方，拇短伸肌腱与拇长展肌腱之间。",
      "Cough, headache, stiff neck, sore throat, facial paralysis, toothache.", "咳嗽、头痛、项强、咽喉痛、口眼歪斜、牙痛。",
      "Oblique upward 0.3–0.5 cun.", "向上斜刺0.3–0.5寸。")
point("LU9", "Taiyuan", "太渊", "Great Abyss", "arm", False, ["lung-l", "lung-r", "heart"], A(WRIST_Y, 45, "forearm", "hand"),
      "On the wrist crease at the thumb side, between the radial styloid and the scaphoid, just outside the radial pulse.",
      "腕前区，桡骨茎突与舟状骨之间，拇长展肌腱尺侧凹陷中（桡动脉搏动处）。",
      "Cough, asthma, weak pulse, chest pain, wrist pain.", "咳嗽、气喘、无脉症、胸痛、腕臂痛。",
      "Perpendicular 0.3–0.5 cun, avoiding the radial artery.", "避开桡动脉，直刺0.3–0.5寸。")
point("LI4", "Hegu", "合谷", "Joining Valley", "arm", True, ["face"], R((0.2635, 0.795, 0.01), (0, 0, -1), "hand"),
      "On the back of the hand, between the 1st and 2nd metacarpal bones, at the midpoint of the 2nd metacarpal on its thumb side.",
      "手背，第1、2掌骨间，第2掌骨桡侧的中点处。",
      "Headache, toothache, facial pain, sore throat, blocked nose, fever; one of the most used points for pain.",
      "头痛、牙痛、面痛、咽喉肿痛、鼻塞、发热；最常用的止痛穴之一。",
      "Perpendicular 0.5–1 cun. Forbidden in pregnancy.", "直刺0.5–1寸。孕妇禁针。", ["虎口"])
point("LI10", "Shousanli", "手三里", "Arm Three Li", "arm", True, ["stomach", "intestines"], A(ELBOW_Y - 2 * ARM_CUN, 12, "forearm"),
      "On the back-thumb side of the forearm, 2 cun below the elbow crease on the line from Yangxi (LI5) to Quchi (LI11).",
      "前臂，肘横纹下2寸，阳溪与曲池连线上。",
      "Elbow and arm pain, tennis elbow, shoulder pain, weak arm, toothache, abdominal pain, diarrhea.",
      "肘臂疼痛、网球肘、肩痛、上肢不遂、齿痛、腹痛、腹泻。",
      "Perpendicular 1–1.5 cun.", "直刺1–1.5寸。")
point("LI11", "Quchi", "曲池", "Pool at the Bend", "arm", True, ["intestines"], A(ELBOW_Y, 22, "forearm", "upper-arm"),
      "At the outer end of the elbow crease with the elbow bent — midway between Chize (LU5) and the lateral epicondyle of the humerus.",
      "肘区，屈肘，肘横纹外侧端，尺泽与肱骨外上髁连线的中点。",
      "Fever, sore throat, rashes and itchy skin, high blood pressure, elbow and arm pain, abdominal pain.",
      "热病、咽喉肿痛、瘾疹湿疹、高血压、肘臂疼痛、腹痛吐泻。",
      "Perpendicular 1–1.5 cun.", "直刺1–1.5寸。")
point("LI15", "Jianyu", "肩髃", "Shoulder Bone", "arm", True, ["shoulders"], A(1.414, 18, "upper-arm", "torso"),
      "On the shoulder, in the front hollow just below the tip of the acromion that appears when the arm is raised sideways.",
      "肩区，肩峰外侧缘前端与肱骨大结节两骨间凹陷中（上臂外展时肩峰前下方凹陷）。",
      "Shoulder pain and stiffness (frozen shoulder), inability to raise the arm, weakness of the arm.",
      "肩臂疼痛、肩周炎、上肢不遂、手臂不举。",
      "Perpendicular or oblique downward 0.8–1.5 cun.", "直刺或向下斜刺0.8–1.5寸。")
point("PC3", "Quze", "曲泽", "Marsh at the Bend", "arm", False, ["heart", "stomach"], A(ELBOW_Y, 112, "forearm", "upper-arm"),
      "On the elbow crease, in the hollow on the little-finger side of the biceps tendon.", "肘前区，肘横纹上，肱二头肌腱尺侧缘凹陷中。",
      "Palpitations, chest pain, stomach ache, vomiting, fever, elbow and arm pain.", "心痛、心悸、胃痛、呕吐、热病、肘臂挛痛。",
      "Perpendicular 1–1.5 cun, or prick the vein to bleed.", "直刺1–1.5寸，或点刺出血。")
point("HT3", "Shaohai", "少海", "Lesser Sea", "arm", False, ["heart"], A(ELBOW_Y, 158, "forearm", "upper-arm"),
      "On the inner front of the elbow, level with the elbow crease, just in front of the medial epicondyle of the humerus.",
      "肘前区，横平肘横纹，肱骨内上髁前缘。",
      "Heart pain, elbow pain and numbness, hand tremor, swollen neck glands, forgetfulness.", "心痛、肘臂挛痛麻木、手颤、瘰疬、健忘。",
      "Perpendicular 0.5–1 cun.", "直刺0.5–1寸。")
point("SI8", "Xiaohai", "小海", "Small Sea", "arm", False, [], A(ELBOW_Y + 0.004, 222, "forearm", "upper-arm"),
      "At the back of the elbow, in the groove between the tip of the olecranon and the medial epicondyle — over the ulnar nerve (the ‘funny bone’).",
      "肘后区，尺骨鹰嘴与肱骨内上髁之间凹陷中（尺神经沟处）。",
      "Elbow pain, pain along the back of the arm and shoulder, numb little finger, headache.", "肘臂疼痛、肩背痛、小指麻木、头痛。",
      "Perpendicular 0.3–0.5 cun. The ulnar nerve lies here — an electric tingle means the needle has touched it.",
      "直刺0.3–0.5寸；此处为尺神经，出现触电感说明触及神经。")
point("PC6", "Neiguan", "内关", "Inner Pass", "arm", True, ["heart", "stomach"], A(WRIST_Y + 2 * ARM_CUN, 90, "forearm"),
      "On the inner forearm, 2 cun above the wrist crease, between the tendons of palmaris longus and flexor carpi radialis.",
      "前臂前区，腕掌侧远端横纹上2寸，掌长肌腱与桡侧腕屈肌腱之间。",
      "Nausea and vomiting (including motion and morning sickness), palpitations, chest tightness, insomnia, anxiety.",
      "恶心呕吐（含晕车、孕吐）、心悸、胸闷、失眠、焦虑。",
      "Perpendicular 0.5–1 cun. The median nerve lies beneath — avoid strong lifting and thrusting.",
      "直刺0.5–1寸；深部为正中神经，避免大幅提插。")
point("PC7", "Daling", "大陵", "Great Mound", "arm", False, ["heart", "stomach"], A(WRIST_Y, 90, "forearm", "hand"),
      "In the middle of the wrist crease, between the tendons of palmaris longus and flexor carpi radialis.",
      "腕前区，腕掌侧远端横纹中点，掌长肌腱与桡侧腕屈肌腱之间。",
      "Palpitations, chest pain, stomach pain, vomiting, anxiety, wrist pain (carpal tunnel).", "心痛、心悸、胃痛、呕吐、心烦、腕痛。",
      "Perpendicular 0.3–0.5 cun.", "直刺0.3–0.5寸。")
point("PC8", "Laogong", "劳宫", "Palace of Toil", "arm", False, ["heart"], R((0.246, 0.797, 0.0), (0, 0, 1), "hand"),
      "In the center of the palm, between the 2nd and 3rd metacarpals, where the middle fingertip rests in a loose fist.",
      "掌区，横平第3掌指关节近端，第2、3掌骨之间偏于第3掌骨（握拳屈指时中指尖处）。",
      "Mouth ulcers, bad breath, anxiety, fainting (first aid), sweaty palms.", "口疮、口臭、心烦、昏迷（急救）、鹅掌风、手汗。",
      "Perpendicular 0.3–0.5 cun.", "直刺0.3–0.5寸。")
point("HT7", "Shenmen", "神门", "Spirit Gate", "arm", True, ["heart", "brain"], A(WRIST_Y, 150, "forearm", "hand"),
      "On the wrist crease at the little-finger side, in the hollow on the thumb side of the flexor carpi ulnaris tendon.",
      "腕前区，腕掌侧远端横纹尺侧端，尺侧腕屈肌腱的桡侧缘。",
      "Insomnia, anxiety, palpitations, poor memory, restlessness.", "失眠、焦虑、心悸、健忘、心烦。",
      "Perpendicular 0.3–0.5 cun, avoiding the ulnar artery.", "避开尺动脉，直刺0.3–0.5寸。")
point("TE5", "Waiguan", "外关", "Outer Pass", "arm", True, ["ears"], A(WRIST_Y + 2 * ARM_CUN, 268, "forearm"),
      "On the back of the forearm, 2 cun above the wrist crease, midway between radius and ulna (opposite Neiguan).",
      "前臂后区，腕背侧远端横纹上2寸，尺骨与桡骨间隙中点（与内关相对）。",
      "Fever, colds, headache, tinnitus, deafness, neck and shoulder pain, wrist and hand pain.",
      "热病、感冒、头痛、耳鸣、耳聋、颈肩痛、手腕疼痛。",
      "Perpendicular 0.5–1 cun.", "直刺0.5–1寸。", ["SJ5"])
point("SI3", "Houxi", "后溪", "Back Stream", "arm", True, ["spine"], A(0.777, 180, "hand"),
      "On the little-finger edge of the hand, in the hollow just behind the 5th knuckle — the end of the palm crease in a loose fist.",
      "手内侧，第5掌指关节尺侧近端赤白肉际凹陷中（握拳时掌横纹头）。",
      "Stiff neck, low-back pain, headache, tinnitus, fever; traditionally opens the Governor Vessel along the spine.",
      "落枕、腰背痛、头项强痛、耳鸣、热病；八脉交会穴，通督脉。",
      "Perpendicular 0.5–1 cun toward Hegu.", "直刺0.5–1寸，可透合谷。")

# trunk, front
point("LU1", "Zhongfu", "中府", "Central Residence", "front", False, ["lung-l", "lung-r"], F(0.144, 1.39),
      "On the upper chest, 6 cun from the midline, level with the 1st intercostal space, 1 cun below the hollow under the outer collarbone.",
      "胸部，横平第1肋间隙，锁骨下窝外侧，前正中线旁开6寸。",
      "Cough, asthma, chest fullness and pain, shoulder and upper-back pain.", "咳嗽、气喘、胸满胸痛、肩背痛。",
      "Oblique outward 0.5–0.8 cun. Never deep or toward the chest — risk of collapsed lung (pneumothorax).",
      "向外斜刺0.5–0.8寸；不可向内深刺，以免伤及肺脏引起气胸。")
point("CV17", "Danzhong", "膻中", "Chest Center", "front", True, ["heart", "lung-l", "lung-r"], F(0, 1.325),
      "On the breastbone at the midline, level with the 4th intercostal space (between the nipples in men).",
      "胸部，横平第4肋间隙，前正中线上（男性约两乳头连线中点）。",
      "Chest tightness, shortness of breath, cough, palpitations, low breast-milk supply, hiccups.",
      "胸闷、气短、咳喘、心悸、乳少、呃逆。",
      "Transverse 0.3–0.5 cun along the bone — some people have a hole in the breastbone here.",
      "平刺0.3–0.5寸；部分人此处有胸骨裂孔，不可直刺深刺。", ["Shanzhong"])
point("CV12", "Zhongwan", "中脘", "Middle Cavity", "front", True, ["stomach"], F(0, NAVEL + 4 * UPPER_CUN),
      "On the upper-abdomen midline, 4 cun above the navel (midway between the navel and the lower end of the breastbone).",
      "上腹部，脐中上4寸，前正中线上（胸剑结合与脐中连线的中点）。",
      "Stomach pain, bloating, nausea, vomiting, acid reflux, poor appetite, indigestion.", "胃痛、腹胀、恶心呕吐、吞酸、纳呆、消化不良。",
      "Perpendicular 1–1.5 cun.", "直刺1–1.5寸。")
point("CV8", "Shenque", "神阙", "Spirit Gate Tower", "front", False, ["intestines"], F(0, NAVEL),
      "In the center of the navel.", "脐区，脐中央。",
      "Diarrhea, cold abdominal pain, collapse (moxibustion), prolapse.", "泄泻、腹痛腹冷、虚脱（灸）、脱肛。",
      "Needling is forbidden — moxibustion only (often over salt or ginger).", "禁针；宜灸（常隔盐或隔姜灸）。")
point("CV6", "Qihai", "气海", "Sea of Qi", "front", True, ["intestines", "uterus"], F(0, NAVEL - 1.5 * LOWER_CUN),
      "On the lower-abdomen midline, 1.5 cun below the navel.", "下腹部，脐中下1.5寸，前正中线上。",
      "Fatigue and weakness, abdominal pain, diarrhea, constipation, irregular periods, frequent urination.",
      "虚劳乏力、腹痛、泄泻、便秘、月经不调、遗尿尿频。",
      "Perpendicular 1–1.5 cun after emptying the bladder; moxibustion is common.", "排尿后直刺1–1.5寸；多用灸法。")
point("CV4", "Guanyuan", "关元", "Origin Pass", "front", True, ["bladder", "uterus", "intestines"], F(0, NAVEL - 3 * LOWER_CUN),
      "On the lower-abdomen midline, 3 cun below the navel.", "下腹部，脐中下3寸，前正中线上。",
      "Weakness, frequent urination, irregular or painful periods, infertility, impotence, diarrhea; a traditional strengthening point.",
      "虚劳、尿频、月经不调、痛经、不孕、阳痿、泄泻；传统强壮保健穴。",
      "Perpendicular 1–1.5 cun after emptying the bladder.", "排尿后直刺1–1.5寸。")
point("CV3", "Zhongji", "中极", "Central Pole", "front", False, ["bladder", "uterus"], F(0, NAVEL - 4 * LOWER_CUN),
      "On the lower-abdomen midline, 4 cun below the navel (1 cun above the pubic bone).", "下腹部，脐中下4寸，前正中线上。",
      "Urinary retention or frequency, painful urination, irregular periods, vaginal discharge.", "癃闭、尿频、尿痛、月经不调、带下。",
      "Perpendicular 1–1.5 cun after emptying the bladder.", "排尿后直刺1–1.5寸。")
point("ST25", "Tianshu", "天枢", "Celestial Pivot", "front", True, ["intestines"], F(2 * CHEST_CUN, NAVEL),
      "On the abdomen, 2 cun to the side of the center of the navel.", "腹部，横平脐中，前正中线旁开2寸。",
      "Constipation, diarrhea, bloating, abdominal pain, irregular periods.", "便秘、泄泻、腹胀、腹痛、月经不调。",
      "Perpendicular 1–1.5 cun.", "直刺1–1.5寸。")
point("LR14", "Qimen", "期门", "Cycle Gate", "front", False, ["liver", "gallbladder"], F(4 * CHEST_CUN, 1.262),
      "On the chest, in the 6th intercostal space, 4 cun from the midline (straight below the nipple).", "胸部，第6肋间隙，前正中线旁开4寸（乳头直下）。",
      "Rib-side pain, chest fullness, belching, acid reflux, breast swelling, low mood.", "胸胁胀痛、嗳气、吞酸、乳痈、情志抑郁。",
      "Oblique or transverse 0.5–0.8 cun. Never deep — lung and liver lie beneath.", "斜刺或平刺0.5–0.8寸；不可深刺，以免伤及肺与肝。")
point("LR13", "Zhangmen", "章门", "Camphorwood Gate", "front", False, ["liver", "spleen"], A(1.215, 18, "torso"),
      "On the side of the abdomen, just below the free end of the 11th rib.", "侧腹部，第11肋游离端的下际。",
      "Bloating, abdominal pain, indigestion, diarrhea, rib-side pain.", "腹胀、腹痛、消化不良、泄泻、胁痛。",
      "Oblique 0.5–0.8 cun; not deep (liver and spleen).", "斜刺0.5–0.8寸；不可深刺，以免伤及肝脾。")

# back
point("GV14", "Dazhui", "大椎", "Great Vertebra", "back", True, ["spine", "lung-l", "lung-r"], B(0, spinous("C", 7), "torso", "neck"),
      "On the back midline, in the hollow below the 7th cervical spinous process (the bony bump at the base of the neck).",
      "脊柱区，第7颈椎棘突下凹陷中，后正中线上。",
      "Fever, colds, cough, stiff neck, heat conditions.", "热病、感冒、咳嗽、颈项强痛、骨蒸潮热。",
      "Oblique upward 0.5–1 cun; not deep (spinal cord).", "向上斜刺0.5–1寸；不可深刺，以免伤及脊髓。")
point("GB21", "Jianjing", "肩井", "Shoulder Well", "back", True, ["shoulders"], R((0.097, 1.38, -0.035), (0, 1, -0.12), "torso"),
      "On the top of the shoulder, midway between the 7th cervical spinous process and the outer tip of the acromion.",
      "肩胛区，第7颈椎棘突与肩峰最外侧点连线的中点。",
      "Neck and shoulder pain and stiffness, headache, difficult labor, breast abscess, low milk supply.",
      "颈项强痛、肩背疼痛、头痛、难产、乳痈、乳汁不下。",
      "Perpendicular 0.5–0.8 cun only — the top of the lung lies beneath. Forbidden in pregnancy.",
      "直刺0.5–0.8寸；深部正当肺尖，不可深刺。孕妇禁针。")
point("SI11", "Tianzong", "天宗", "Celestial Gathering", "back", False, ["shoulders"], B(0.123, 1.355),
      "On the shoulder blade, in the hollow one-third of the way from the midpoint of the scapular spine to its lower angle.",
      "肩胛区，肩胛冈中点与肩胛骨下角连线上1/3与下2/3交点凹陷中。",
      "Shoulder-blade pain, upper back and arm pain, breast pain, low milk supply.", "肩胛疼痛、肩背部损伤、乳痈、乳少。",
      "Perpendicular or oblique 0.5–1 cun (over the shoulder blade).", "直刺或斜刺0.5–1寸。")
for code, py, zh, en, level, common, organs, loc, loc_zh, uses, uses_zh in (
    ("BL13", "Feishu", "肺俞", "Lung Shu", ("T", 3), True, ["lung-l", "lung-r"], "3rd thoracic", "第3胸椎",
     "Cough, asthma, coughing blood, night sweats, itchy skin.", "咳嗽、气喘、咯血、盗汗、皮肤瘙痒。"),
    ("BL15", "Xinshu", "心俞", "Heart Shu", ("T", 5), False, ["heart"], "5th thoracic", "第5胸椎",
     "Palpitations, chest pain, insomnia, forgetfulness, anxiety, night sweats.", "心悸、胸痛、失眠、健忘、心烦、盗汗。"),
    ("BL17", "Geshu", "膈俞", "Diaphragm Shu", ("T", 7), False, ["heart", "stomach"], "7th thoracic", "第7胸椎",
     "Hiccups, vomiting, anemia, coughing blood, hives; traditionally the ‘meeting point of blood’.", "呃逆、呕吐、贫血、咳血、瘾疹；血会。"),
    ("BL18", "Ganshu", "肝俞", "Liver Shu", ("T", 9), False, ["liver", "gallbladder"], "9th thoracic", "第9胸椎",
     "Rib-side pain, jaundice, red eyes, poor night vision, dizziness, irritability.", "胁痛、黄疸、目赤、夜盲、眩晕、急躁易怒。"),
    ("BL20", "Pishu", "脾俞", "Spleen Shu", ("T", 11), False, ["spleen", "stomach", "pancreas"], "11th thoracic", "第11胸椎",
     "Bloating, poor appetite, diarrhea, fatigue, swelling.", "腹胀、纳呆、泄泻、倦怠乏力、水肿。"),
):
    point(code, py, zh, en, "back", common, organs, B(INNER_BL, spinous(*level)),
          f"On the upper back, 1.5 cun to the side of the lower border of the {loc} spinous process.",
          f"脊柱区，{loc_zh}棘突下，后正中线旁开1.5寸。", uses, uses_zh,
          "Oblique toward the spine 0.5–0.8 cun. Never deep — risk of collapsed lung (pneumothorax).",
          "向脊柱方向斜刺0.5–0.8寸；不宜深刺，以免引起气胸。")
point("BL23", "Shenshu", "肾俞", "Kidney Shu", "back", True, ["kidney-l", "kidney-r", "adrenals"], B(INNER_BL, spinous("L", 2)),
      "On the lower back, 1.5 cun to the side of the lower border of the 2nd lumbar spinous process (about waist level).",
      "脊柱区，第2腰椎棘突下，后正中线旁开1.5寸。",
      "Low-back pain, frequent urination, bedwetting, impotence, irregular periods, tinnitus, swelling.",
      "腰痛、尿频、遗尿、阳痿、月经不调、耳鸣、水肿。",
      "Perpendicular 0.5–1 cun; not deep toward the kidney.", "直刺0.5–1寸；不宜深刺。")
point("GV4", "Mingmen", "命门", "Gate of Life", "back", False, ["kidney-l", "kidney-r"], B(0, spinous("L", 2)),
      "On the lower-back midline, in the hollow below the 2nd lumbar spinous process (between the two Shenshu).",
      "脊柱区，第2腰椎棘突下凹陷中，后正中线上。",
      "Low-back pain and stiffness, cold limbs, impotence, frequent urination, chronic diarrhea.", "腰脊强痛、手足逆冷、阳痿、尿频、久泻。",
      "Oblique upward 0.5–1 cun; moxibustion is common.", "向上斜刺0.5–1寸；多用灸法。")
point("BL25", "Dachangshu", "大肠俞", "Large Intestine Shu", "back", False, ["intestines"], B(INNER_BL, spinous("L", 4)),
      "On the lower back, 1.5 cun to the side of the lower border of the 4th lumbar spinous process.",
      "脊柱区，第4腰椎棘突下，后正中线旁开1.5寸。",
      "Low-back pain, sciatica, constipation, diarrhea, bloating.", "腰腿痛、便秘、泄泻、腹胀。",
      "Perpendicular 0.8–1.2 cun.", "直刺0.8–1.2寸。")
point("BL32", "Ciliao", "次髎", "Second Crevice", "back", False, ["uterus", "bladder"], B(0.021, 0.953),
      "On the sacrum, over the 2nd posterior sacral foramen.", "骶区，正对第2骶后孔中。",
      "Painful or irregular periods, low-back and sacral pain, urinary problems, sciatica.", "痛经、月经不调、腰骶痛、小便不利、下肢痿痹。",
      "Perpendicular 1–1.5 cun into the foramen.", "直刺1–1.5寸。")
point("GB30", "Huantiao", "环跳", "Jumping Circle", "back", True, [], R((0.075, 0.9, -0.02), (0.3, 0, -1), "torso"),
      "On the buttock, one-third of the way from the top of the greater trochanter toward the sacral hiatus.",
      "臀区，股骨大转子最凸点与骶管裂孔连线的外1/3与中1/3交点处。",
      "Sciatica, hip pain, low-back and leg pain, weakness of the leg.", "坐骨神经痛、髋痛、腰腿痛、下肢痿痹。",
      "Perpendicular 2–3 cun through the thick muscle; the sciatic nerve lies close.", "直刺2–3寸；深部邻近坐骨神经。")

# leg
point("GB31", "Fengshi", "风市", "Wind Market", "leg", False, [], A(KNEE_Y + 7 * (0.92 - KNEE_Y) / 19, 356, "thigh"),
      "On the outer thigh, where the tip of the middle finger rests when standing with the arms at the sides (7 cun above the knee crease).",
      "股部，直立垂手、掌心贴于大腿时中指尖所指凹陷中，髂胫束后缘（腘横纹上7寸）。",
      "Itching all over, hives, numb or weak legs, sciatica.", "遍身瘙痒、瘾疹、下肢痿痹、麻木、坐骨神经痛。",
      "Perpendicular 1–2 cun.", "直刺1–2寸。")
point("SP10", "Xuehai", "血海", "Sea of Blood", "leg", True, ["uterus"], A(PATELLA_TOP + 2 * THIGH_CUN, 128, "thigh"),
      "On the inner thigh, 2 cun above the upper inner corner of the kneecap, on the bulge of the vastus medialis.",
      "股前区，髌底内侧端上2寸，股内侧肌隆起处。",
      "Irregular or painful periods, eczema, hives, itchy skin, knee pain.", "月经不调、痛经、湿疹、瘾疹、皮肤瘙痒、膝痛。",
      "Perpendicular 1–1.5 cun.", "直刺1–1.5寸。")
point("ST35", "Dubi", "犊鼻", "Calf's Nose", "leg", False, [], A(0.478, 62, "shin", "thigh"),
      "Below the kneecap, in the hollow on the outer side of the patellar tendon (the outer ‘eye of the knee’).",
      "膝前区，髌韧带外侧凹陷中（外膝眼）。",
      "Knee pain, swelling and stiffness, arthritis of the knee.", "膝痛、膝关节肿胀、屈伸不利。",
      "With the knee bent, oblique toward the center of the knee 0.5–1 cun; strict sterility (near the joint space).",
      "屈膝，向膝中斜刺0.5–1寸；邻近关节腔，须严格消毒。", ["Xiyan", "膝眼"])
point("SP9", "Yinlingquan", "阴陵泉", "Yin Mound Spring", "leg", True, ["spleen", "bladder"], A(0.445, 178, "shin"),
      "On the inner leg, in the hollow where the lower edge of the medial condyle of the tibia meets its inner border.",
      "小腿内侧，胫骨内侧髁下缘与胫骨内侧缘之间的凹陷中。",
      "Swelling and water retention, difficult urination, diarrhea, bloating, knee pain.", "水肿、小便不利、泄泻、腹胀、膝痛。",
      "Perpendicular 1–2 cun.", "直刺1–2寸。")
point("GB34", "Yanglingquan", "阳陵泉", "Yang Mound Spring", "leg", True, ["gallbladder", "liver"], A(0.435, 24, "shin"),
      "On the outer leg, in the hollow in front of and below the head of the fibula.", "小腿外侧，腓骨头前下方凹陷中。",
      "Knee pain, numb legs and cramps, sciatica, rib-side pain, bitter taste, nausea; traditionally the ‘meeting point of sinews’.",
      "膝肿痛、下肢痿痹麻木、抽筋、胁痛、口苦、呕吐；筋会。",
      "Perpendicular 1–1.5 cun; the common peroneal nerve lies close behind.", "直刺1–1.5寸；后方邻近腓总神经。")
point("ST36", "Zusanli", "足三里", "Leg Three Li", "leg", True, ["stomach", "intestines"], A(0.478 - 3 * LEG_CUN, 66, "shin"),
      "On the front of the leg, 3 cun below Dubi (ST35), one finger-breadth outside the front edge of the tibia.",
      "小腿外侧，犊鼻下3寸，胫骨前嵴外一横指处。",
      "Stomach pain, nausea, bloating, diarrhea, constipation, fatigue, knee pain; the classic point for general well-being.",
      "胃痛、呕吐、腹胀、泄泻、便秘、虚劳乏力、膝痛；强壮保健要穴。",
      "Perpendicular 1–2 cun; moxibustion is common.", "直刺1–2寸；多用灸法。")
point("BL40", "Weizhong", "委中", "Bend Middle", "leg", True, ["spine", "bladder"], A(KNEE_Y, 270, "thigh", "shin"),
      "At the back of the knee, at the midpoint of the knee crease.", "膝后区，腘横纹中点。",
      "Low-back pain (‘for the back, look to Weizhong’), sciatica, knee pain, heat stroke, skin rashes.",
      "腰背痛（腰背委中求）、坐骨神经痛、膝痛、中暑、丹毒。",
      "Perpendicular 1–1.5 cun, or prick the small veins to bleed. The popliteal artery and tibial nerve lie deep — no deep, forceful needling.",
      "直刺1–1.5寸，或点刺腘静脉出血；深部有腘动脉与胫神经，不宜深刺、强刺激。")
point("ST40", "Fenglong", "丰隆", "Abundant Bulge", "leg", True, ["lung-l", "lung-r", "stomach"], A(LAT_MAL_Y + 8 * LEG_CUN, 45, "shin"),
      "On the outer leg, 8 cun above the outer ankle bone (midway between knee and ankle), two finger-breadths outside the front edge of the tibia.",
      "小腿外侧，外踝尖上8寸，胫骨前肌外缘（条口旁开1寸）。",
      "Phlegm and cough, asthma, dizziness, headache, chest tightness, constipation.", "痰多、咳嗽、哮喘、眩晕、头痛、胸闷、便秘。",
      "Perpendicular 1–1.5 cun.", "直刺1–1.5寸。")
point("BL57", "Chengshan", "承山", "Mountain Support", "leg", True, ["intestines"], A((KNEE_Y + LAT_MAL_Y) / 2, 270, "shin"),
      "At the back of the lower leg, in the pointed hollow below the two bellies of the calf muscle that appears on tiptoe.",
      "小腿后区，腓肠肌两肌腹与肌腱交角处（踮脚时出现的尖角凹陷）。",
      "Calf cramps, low-back and leg pain, sciatica, hemorrhoids, constipation.", "小腿抽筋、腰腿痛、坐骨神经痛、痔疮、便秘。",
      "Perpendicular 1–2 cun.", "直刺1–2寸。")
point("SP6", "Sanyinjiao", "三阴交", "Three Yin Intersection", "leg", True, ["uterus", "spleen", "liver", "kidney-l", "kidney-r"],
      A(MED_MAL_Y + 3 * MED_CUN, 188, "shin"),
      "On the inner leg, 3 cun above the tip of the inner ankle bone, just behind the inner edge of the tibia.",
      "小腿内侧，内踝尖上3寸，胫骨内侧缘后际。",
      "Painful or irregular periods, infertility, insomnia, bloating, diarrhea, frequent urination; traditionally used to bring on labor.",
      "痛经、月经不调、不孕、失眠、腹胀、泄泻、尿频；传统用于催产。",
      "Perpendicular 1–1.5 cun. Forbidden in pregnancy.", "直刺1–1.5寸。孕妇禁针。")
point("GB39", "Xuanzhong", "悬钟", "Suspended Bell", "leg", False, ["spine"], A(LAT_MAL_Y + 3 * LEG_CUN, 14, "shin"),
      "On the outer leg, 3 cun above the tip of the outer ankle bone, in front of the fibula.", "小腿外侧，外踝尖上3寸，腓骨前缘。",
      "Stiff neck, leg pain and weakness, ankle pain, rib-side pain; traditionally the ‘meeting point of marrow’.",
      "颈项强痛、下肢痿痹、踝痛、胁痛；髓会。",
      "Perpendicular 0.5–0.8 cun.", "直刺0.5–0.8寸。", ["Juegu", "绝骨"])
point("KI3", "Taixi", "太溪", "Great Stream", "leg", True, ["kidney-l", "kidney-r"], A(MED_MAL_Y, 238, "shin"),
      "On the inner ankle, in the hollow between the tip of the inner ankle bone and the Achilles tendon.", "踝区，内踝尖与跟腱之间的凹陷中。",
      "Low-back pain, tinnitus, sore throat, toothache, insomnia, frequent urination, irregular periods.",
      "腰痛、耳鸣、咽喉肿痛、牙痛、失眠、尿频、月经不调。",
      "Perpendicular 0.5–1 cun; the posterior tibial artery lies close.", "直刺0.5–1寸；邻近胫后动脉。")
point("BL60", "Kunlun", "昆仑", "Kunlun Mountains", "leg", False, ["spine", "brain"], A(LAT_MAL_Y, 305, "shin"),
      "On the outer ankle, in the hollow between the tip of the outer ankle bone and the Achilles tendon.", "踝区，外踝尖与跟腱之间的凹陷中。",
      "Headache, stiff neck, low-back pain, heel and ankle pain; traditionally used for difficult labor.",
      "头痛、项强、腰骶疼痛、足跟肿痛；传统用于难产。",
      "Perpendicular 0.5–0.8 cun. Forbidden in pregnancy.", "直刺0.5–0.8寸。孕妇禁针。")
point("SP4", "Gongsun", "公孙", "Grandfather Grandson", "leg", False, ["stomach", "spleen", "heart"], R((0.088, 0.024, 0.058), (-1, -0.35, 0), "foot"),
      "On the inner edge of the foot, in the hollow in front of and below the base of the 1st metatarsal, where the skin changes color.",
      "跖区，第1跖骨底的前下缘赤白肉际处。",
      "Stomach pain, vomiting, bloating, diarrhea, chest discomfort.", "胃痛、呕吐、腹胀、泄泻、胸闷。",
      "Perpendicular 0.6–1.2 cun.", "直刺0.6–1.2寸。")
point("LR3", "Taichong", "太冲", "Great Rush", "leg", True, ["liver"], R((0.077, 0.02, 0.07), (0, 1, 0), "foot"),
      "On the top of the foot, in the hollow between the 1st and 2nd metatarsals, just in front of where their bases meet.",
      "足背，第1、2跖骨间，跖骨底结合部前方凹陷中。",
      "Headache, dizziness, irritability and stress, red eyes, high blood pressure, painful periods, rib-side pain; with Hegu, the ‘Four Gates’ for calming and pain.",
      "头痛、眩晕、急躁易怒、目赤、高血压、痛经、胁痛；与合谷合称“四关”，镇静止痛。",
      "Perpendicular 0.5–0.8 cun.", "直刺0.5–0.8寸。")
point("ST44", "Neiting", "内庭", "Inner Court", "leg", False, ["stomach"], R((0.0935, 0.01, 0.138), (0, 1, 0.15), "foot", "toe-skin-2nd", "toe-skin-3rd"),
      "On the top of the foot, at the web between the 2nd and 3rd toes, where the skin changes color.", "足背，第2、3趾间，趾蹼缘后方赤白肉际处。",
      "Toothache, sore throat, nosebleed, stomach pain, acid reflux, fever.", "牙痛、咽喉肿痛、鼻衄、胃痛吐酸、热病。",
      "Perpendicular or oblique 0.5–0.8 cun.", "直刺或斜刺0.5–0.8寸。")
point("KI1", "Yongquan", "涌泉", "Gushing Spring", "leg", True, ["kidney-l", "kidney-r", "brain"], R((0.093, 0.03, 0.072), (0, -1, 0), "foot"),
      "On the sole, in the deepest hollow when the toes are curled — about one-third of the way from the base of the 2nd and 3rd toes to the heel.",
      "足底，屈足卷趾时足心最凹陷处；约当第2、3趾蹼缘与足跟连线的前1/3与后2/3交点。",
      "Headache, dizziness, insomnia, fainting (first aid), sore throat, constipation; often used for moxibustion or massage.",
      "头痛、眩晕、失眠、昏厥（急救）、咽喉痛、便秘；常用灸法或按摩。",
      "Perpendicular 0.5–1 cun; very sensitive.", "直刺0.5–1寸；针感强烈。")
point("BL67", "Zhiyin", "至阴", "Reaching Yin", "leg", False, ["uterus"], R((0.122, 0.014, 0.16), (1, 0.6, 0), "toe-skin-5th"),
      "On the little toe, 0.1 cun from the outer corner of the toenail.", "足趾，小趾末节外侧，趾甲根角侧后方0.1寸。",
      "Traditionally, moxibustion here is used to turn a breech baby (from about 33 weeks, under supervision); headache, blocked nose.",
      "传统用艾灸矫正胎位不正（约孕33周起，须在医生指导下）；头痛、鼻塞。",
      "Shallow 0.1 cun, or prick to bleed; moxibustion.", "浅刺0.1寸，或点刺出血；可灸。")

BY_CODE = {p["code"]: p for p in P}

# ---------------------------------------------------------------- meridian courses (left side; point codes or specs)

T_ = "torso"
ARM_TOP = 1.34

COURSES = {
    "LU": [["LU1", F(0.162, 1.405, T_, "upper-arm"), A(1.33, 72, "upper-arm"), A(1.2, 70, "upper-arm"), "LU5",
            A(1.0, 55, "forearm"), A(0.93, 30, "forearm"), "LU7", "LU9", A(0.83, 35, "hand"),
            A(0.8, 20, "thumb"), A(0.77, 10, "thumb"), A(0.752, 0, "thumb")]],
    "LI": [[A(0.7, 355, "finger-skin-index"), A(0.745, 340, "finger-skin-index", "hand"), "LI4",
            A(WRIST_Y, 330, "hand", "forearm"), A(0.95, 345, "forearm"), "LI10", "LI11",
            A(1.2, 5, "upper-arm"), A(1.3, 8, "upper-arm"), "LI15", R((0.15, 1.4, -0.02), (0, 1, 0), T_), A(1.475, 55, "neck"), A(1.52, 50, "neck", "head"), A(1.548, 50, "head"), F(0.03, 1.57, "head"), "LI20"]],
    "ST": [[A(1.69, 55, "head"), A(1.62, 20, "head"), A(1.57, -20, "head"), "ST6", A(1.515, -30, "head"),
            A(1.525, 20, "head"), F(0.026, 1.552, "head"), F(0.031, 1.575, "head"), F(0.031, 1.61, "head")],
           [A(1.51, 60, "neck"), A(1.475, 70, "neck"), F(0.095, 1.445, T_), F(0.095, 1.36, T_), F(0.095, 1.28, T_),
            F(0.07, 1.24, T_), F(0.048, 1.2, T_), "ST25", F(0.048, 0.95, T_), F(0.055, 0.89, T_, "thigh"),
            A(0.83, 75, "thigh"), A(0.7, 72, "thigh"), A(0.56, 55, "thigh"), "ST35", "ST36", A(0.34, 62, "shin"), "ST40",
            A(0.2, 75, "shin"), A(0.1, 88, "shin"), R((0.09, 0.02, 0.03), (0, 1, 0), "foot"),
            R((0.092, 0.01, 0.11), (0, 1, 0.1), "foot"), "ST44", R((0.091, 0.008, 0.188), (0.4, 1, 0), "toe-skin-2nd")]],
    "SP": [[R((0.071, 0.014, 0.19), (-1, 0.4, 0), "toe-skin-big"), R((0.086, 0.02, 0.13), (-1, -0.25, 0), "foot"),
            R((0.087, 0.022, 0.095), (-1, -0.3, 0), "foot"), "SP4", R((0.08, 0.05, 0.015), (-1, 0, 0.5), "foot", "shin"),
            A(0.11, 175, "shin"), "SP6", A(0.3, 185, "shin"), "SP9", A(0.52, 150, "thigh", "shin"), "SP10",
            A(0.7, 125, "thigh"), A(0.84, 110, "thigh"), F(0.085, 0.9, T_, "thigh"), F(0.096, 0.97, T_),
            F(4 * CHEST_CUN, NAVEL, T_), F(0.1, 1.15, T_), F(0.125, 1.26, T_), F(0.144, 1.33, T_)]],
    "HT": [[A(ARM_TOP, 175, "upper-arm"), A(1.2, 165, "upper-arm"), "HT3", A(1.0, 150, "forearm"), "HT7",
            R((0.214, 0.8, 0.0), (0, 0, 1), "hand"), R((0.212, 0.768, 0.0), (0, 0, 1), "hand", "finger-skin-little"),
            A(0.715, 40, "finger-skin-little")]],
    "SI": [[A(0.712, 200, "finger-skin-little"), A(0.76, 188, "finger-skin-little", "hand"), "SI3", A(0.83, 185, "hand"),
            A(WRIST_Y, 200, "hand", "forearm"), A(0.875, 225, "forearm"), A(1.0, 222, "forearm"), "SI8",
            A(1.2, 228, "upper-arm"), A(ARM_TOP, 245, "upper-arm"), B(0.16, 1.395, T_), "SI11", B(0.12, 1.42, T_), B(0.085, 1.418, T_), B(3 * BACK_CUN, 1.448, T_), B(0.05, 1.462, T_, "neck")],
           [A(1.5, 330, "neck"), A(1.545, 345, "head"), A(1.575, 25, "head"), A(1.6, 12, "head")]],
    "BL": [[F(0.016, 1.628, "head", "nose"), "BL2", H(28, 0.022), H(60, 0.022), H(90, 0.022), H(120, 0.022), H(150, 0.022),
            B(0.022, 1.6, "head"), B(0.024, 1.575, "head", "neck"), B(0.028, 1.53, "neck"), B(INNER_BL, 1.47, T_, "neck"),
            "BL13", "BL15", "BL17", "BL18", "BL20", "BL23", "BL25", B(INNER_BL, 0.99, T_), B(INNER_BL, 0.93, T_)],
           [B(0.024, 0.985, T_), "BL32", B(0.018, 0.9, T_)],
           [B(OUTER_BL, 1.445, T_), B(OUTER_BL, 1.35, T_), B(OUTER_BL, 1.2, T_), B(OUTER_BL, 1.05, T_), B(OUTER_BL, 0.93, T_),
            R((0.07, 0.86, -0.02), (0, 0, -1), T_, "thigh"), A(0.8, 275, "thigh"), A(0.65, 272, "thigh"), "BL40", A(0.4, 270, "shin"), "BL57", A(0.2, 290, "shin"),
            A(0.12, 300, "shin"), "BL60", R((0.1, 0.045, -0.005), (1, -0.4, 0), "foot"), R((0.1, 0.025, 0.05), (1, -0.25, 0), "foot"),
            R((0.108, 0.02, 0.11), (1, -0.2, 0), "foot"), "BL67"]],
    "KI": [["KI1", R((0.085, 0.03, 0.03), (-1, -0.6, 0), "foot"), R((0.08, 0.05, -0.02), (-1, -0.3, -0.4), "foot"), "KI3",
            A(MED_MAL_Y + 2 * MED_CUN, 225, "shin"), A(0.3, 215, "shin"), A(0.45, 210, "shin"), A(KNEE_Y, 208, "thigh", "shin"),
            A(0.62, 195, "thigh"), A(0.78, 165, "thigh"), A(0.845, 140, "thigh"), F(0.03, 0.885, T_, "thigh"), F(0.012, 0.9, T_),
            F(0.012, NAVEL, T_), F(0.012, XIPHOID, T_), F(2 * CHEST_CUN, 1.29, T_), F(2 * CHEST_CUN, 1.43, T_)]],
    "PC": [[F(0.12, 1.325, T_), F(0.155, 1.33, T_, "upper-arm"), A(1.3, 105, "upper-arm"), A(1.2, 100, "upper-arm"), "PC3",
            A(1.0, 92, "forearm"), "PC6", "PC7", "PC8", R((0.241, 0.76, 0.0), (0, 0, 1), "hand", "finger-skin-middle"),
            A(0.695, 90, "finger-skin-middle")]],
    "TE": [[A(0.7, 200, "finger-skin-ring"), A(0.765, 250, "finger-skin-ring", "hand"), R((0.216, 0.79, 0.01), (0, 0, -1), "hand"),
            A(WRIST_Y, 270, "hand", "forearm"), "TE5", A(1.0, 270, "forearm"), A(1.13, 275, "upper-arm"), A(1.25, 280, "upper-arm"),
            A(1.39, 295, "upper-arm"), R((0.13, 1.35, -0.04), (0, 1, -0.3), T_), A(1.49, 320, "neck"), A(1.55, 335, "head", "neck"), "TE17",
            A(1.625, -40, "head"), A(1.66, -12, "head"), A(1.64, 18, "head"), F(0.05, 1.648, "head")]],
    "GB": [[F(0.052, 1.627, "head"), A(1.61, 16, "head"), A(1.665, 22, "head"), A(1.69, -10, "head"), A(1.64, -45, "head"),
            A(1.6, -55, "head"), "GB20"],
           ["GB20", A(1.53, 305, "neck"), R((0.07, 1.4, -0.035), (0, 1, -0.2), T_), "GB21", A(1.37, 40, T_), A(1.26, 38, T_),
            A(1.14, 18, T_), A(1.04, 28, T_), A(0.95, 12, T_), "GB30", A(0.8, 355, "thigh"), "GB31", A(0.55, 5, "thigh"),
            "GB34", A(0.3, 18, "shin"), "GB39", R((0.105, 0.05, 0.02), (1, 0, 0.6), "foot", "shin"), R((0.112, 0.01, 0.105), (0, 1, 0), "foot"),
            R((0.111, 0.012, 0.172), (1, 0.6, 0), "toe-skin-4th")]],
    "LR": [[R((0.072, 0.016, 0.19), (0.7, 0.7, 0), "toe-skin-big"), R((0.079, 0.01, 0.14), (0, 1, 0), "foot", "toe-skin-big"), "LR3",
            R((0.08, 0.075, 0.0), (-0.5, 0, 1), "shin", "foot"), A(0.15, 150, "shin"), A(0.3, 155, "shin"), A(0.45, 190, "shin"),
            A(KNEE_Y + 0.01, 195, "thigh", "shin"), A(0.65, 170, "thigh"), A(0.8, 140, "thigh"), F(0.06, 0.88, T_, "thigh"),
            F(0.09, 0.98, T_), F(0.125, 1.1, T_), "LR13", "LR14"]],
    "GV": [[B(0, 0.86), B(0, 0.95), B(0, 1.03), "GV4", B(0, 1.18), B(0, 1.3), B(0, 1.4), "GV14", B(0, 1.52, "neck"),
            B(0, 1.58, "head", "neck"), H(150), H(120), "GV20", H(60), H(30), "EX-HN3", F(0, 1.62, "head", "nose"),
            F(0, 1.595, "head", "nose"), "GV26"]],
    "CV": [[F(0, 0.895), "CV3", "CV4", "CV6", "CV8", "CV12", F(0, XIPHOID), "CV17", F(0, 1.4), "CV22",
            F(0, 1.48, "neck"), F(0, 1.51, "neck", "head"), F(0, 1.535, "head")]],
}

POINT_LIFT, LINE_LIFT = 0.0025, 0.0014
SAMPLE = 0.012  # line resolution, metres


def region(p):
    """Region of a scene point for age reshaping — must match BodyScene.reshape."""
    if p[1] > 1.25:
        return "head"
    if abs(p[0]) > 0.316:
        return "arm"
    if p[1] < -0.04:
        return "leg"
    # shoulders to chin: children's necks are shorter
    return "neck" if p[1] > 1.05 else "trunk"


def as_spec(item):
    return BY_CODE[item]["spec"] if isinstance(item, str) else item


def lerp_spec(a, b, t):
    """A ray between two specs: origin and direction interpolated, parts combined."""
    parts = tuple(dict.fromkeys(a.parts + b.parts))
    if a.anchor is not None and b.anchor is not None and a.parts[0] == b.parts[0]:
        return Ray(parts, None, norm(tuple(a.dir[k] * (1 - t) + b.dir[k] * t for k in range(3))), anchor=a.anchor + (b.anchor - a.anchor) * t)
    return Blend(a, b, t, parts)


class Blend(Ray):
    def __init__(self, a, b, t, parts):
        self.a, self.b, self.t, self.parts = a, b, t, parts
        self.anchor = None

    def resolve(self, skin, sex, side):
        oa, da, _ = self.a.resolve(skin, sex, side)
        ob, db, _ = self.b.resolve(skin, sex, side)
        t = self.t
        o = tuple(oa[k] * (1 - t) + ob[k] * t for k in range(3))
        d = norm(tuple(da[k] * (1 - t) + db[k] * t for k in range(3)))
        return o, d, [skin.loft(n, sex, side) for n in self.parts]


def trace(course, skin, sex, side):
    specs = [as_spec(c) for c in course]
    out = []
    for a, b in zip(specs, specs[1:]):
        pa, _ = cast(a, skin, sex, side, LINE_LIFT)
        pb, _ = cast(b, skin, sex, side, LINE_LIFT)
        n = max(1, round(math.dist(pa, pb) / (SAMPLE * SCALE)))
        if not out:
            out.append(pa)
        for k in range(1, n):
            out.append(cast(lerp_spec(a, b, k / n), skin, sex, side, LINE_LIFT)[0])
        out.append(pb)
    return out


def split(path):
    """Cut where the region changes; pieces overlap a little so the joins don't show."""
    regions = [region(p) for p in path]
    pieces, start = [], 0
    for i in range(1, len(path)):
        if regions[i] != regions[i - 1]:
            pieces.append((regions[start], path[max(0, start - 1):i + 1]))
            start = i
    pieces.append((regions[start], path[max(0, start - 1):]))
    return pieces


def rnd(p):
    return [round(c, 4) for c in p]


def build(parts):
    skin = Skin(parts)
    colors = {m[0]: m[3] for m in MERIDIANS}

    def uses_torso(spec):
        return "torso" in spec.parts

    points = []
    for p in P:
        spec = p["spec"]
        bilateral = abs(spec.origin[0]) > 1e-6 if spec.anchor is None else True
        sides = ("l", "r") if bilateral else ("l",)
        sites, normal = [], None
        for side in sides:
            q, d = cast(spec, skin, "male", side, POINT_LIFT)
            sites.append(rnd(q))
            if normal is None:
                normal = d
        female = [rnd(cast(spec, skin, "female", s, POINT_LIFT)[0]) for s in sides] if uses_torso(spec) else None
        meridian = p["code"].split("-")[0].rstrip("0123456789") if not p["code"].startswith("EX") else "EX"
        acu = {"code": p["code"], "meridian": meridian, "pinyin": p["pinyin"],
               "uses": p["uses"], "usesZh": p["uses_zh"], "needling": p["needle"], "needlingZh": p["needle_zh"],
               "organIds": p["organs"], "common": p["common"], "normal": rnd(normal), "sites": sites}
        if female and female != sites:
            acu["femaleSites"] = female
        if p["aliases"]:
            acu["aliases"] = p["aliases"]
        points.append({"id": "acu-" + p["code"].lower(), "name": p["en"], "nameZh": p["zh"],
                       "description": p["loc"], "descriptionZh": p["loc_zh"], "region": p["region"],
                       "position": sites[0], "acu": acu})

    meridians = []
    for mid, name, zh, color in MERIDIANS:
        midline = mid in ("GV", "CV")

        def pieces(sex):
            out = {}
            for side in (("l",) if midline else ("l", "r")):
                for course in COURSES[mid]:
                    for reg, piece in split(trace(course, skin, sex, side)):
                        if len(piece) > 1:
                            key = reg if reg in ("head", "neck", "trunk") else f"{reg}-{side}"
                            out.setdefault(key, []).append([rnd(q) for q in piece])
            return [out[k] for k in sorted(out)]
        male = pieces("male")
        m = {"id": mid, "name": name, "nameZh": zh, "color": color, "pieces": male}
        female = pieces("female")
        if female != male:
            m["femalePieces"] = female
        meridians.append(m)
    ex = {"id": EXTRA[0], "name": EXTRA[1], "nameZh": EXTRA[2], "color": EXTRA[3], "pieces": []}
    return {"points": points, "meridians": meridians + [ex]}
