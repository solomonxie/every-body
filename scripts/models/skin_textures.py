"""Skin colour for the figure's textures: MakeHuman's (CC0) skins, blended per heritage, brought to a target tone
with natural colour by region (cheeks, nose, ears, lips, lids, knees, elbows, knuckles, chest).
Called from build_figure.textures; regions come from the fitted neutral bodies and MPFB's vertex groups."""

import json
from pathlib import Path

# body tone per heritage (sRGB median of the body's skin), light to dark
TONE = {
    "white": (209, 156, 133),
    "hispanic": (182, 130, 98),
    "east-asian": (206, 158, 124),
    "southeast-asian": (165, 117, 86),
    "south-asian": (116, 76, 52),
    "black": (92, 58, 40),
}
# face shading strength per heritage (cheeks, nose, lids)
SHADE = {"east-asian": 1.5}
# lip colour scale per heritage
LIP_TINT = {"east-asian": (1.0, 0.82, 0.84)}
# per texture: brightness and warmth (men a shade deeper and ruddier, seniors a little duller, children lighter)
VARIANT = {"male-young": (0.97, (1.0, 0.985, 0.97)), "male-old": (0.95, (1.0, 0.99, 0.98)), "female-young": (1.0, (1, 1, 1)),
           "female-old": (0.98, (1.0, 0.995, 0.99)), "kid": (1.03, (1.0, 0.995, 0.995))}
# how much face colour each texture carries (men and seniors lighter)
FACE = {"female-young": 1.0, "female-old": 0.7, "male-young": 0.5, "male-old": 0.4, "kid": 0.7}
# the chest centre points in MakeHuman's body UVs (the same layout on every figure)
NIPPLE_UV = [(0.4346, 0.6967), (0.3265, 0.6967)]
# heritages whose women get STYLIZED_FACE targets (build_figure)
STYLIZED = set()
# how clean the head's skin is drawn per texture (its pores, blotches and lines evened out), 0 … 1
CLEAN = {"female-young": 1.0, "female-old": 0.6, "kid": 1.0, "male-young": 0.8, "male-old": 0.45}
# the same over the rest of the body (MakeHuman's mottling and painted creases read as wrinkled skin on the shoulders
# and chest at the app's scale)
BODY_CLEAN = {"female-young": 0.75, "female-old": 0.35, "kid": 0.85, "male-young": 0.55, "male-old": 0.25}
# how much of the body's broad shading (MakeHuman's baked light and its tone steps at the UV seams, which the clean skin
# no longer hides) is kept, 0 … 1; the head keeps all of it
BODY_SHADE = {"female-young": 0.3, "female-old": 0.5, "kid": 0.25, "male-young": 0.5, "male-old": 0.6}
# local detail contrast about the broad colour (MakeHuman's skins read flat once toned)
DETAIL = 1.15


def smoothstep(a, b, x):
    import numpy as np
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def lip_seam(np, p, up, lo, bins=24):
    """where the lips meet, by x: per vertex the seam's height, the upper lip's front edge just over it and the
    lower lip's fullest point below it (z), and the mouth's half width"""
    half = np.abs(p[up | lo, 0]).max()
    xs, seam, edge, bulge = [], [], [], []
    for a, b in zip(*(np.linspace(-half, half, bins + 1)[i:] for i in (0, 1))):
        u = up & (p[:, 0] >= a) & (p[:, 0] < b)
        l = lo & (p[:, 0] >= a) & (p[:, 0] < b)
        if not (u.any() and l.any()):
            continue
        # the lips' front surfaces only (not the lining inside the mouth)
        uf = u & (p[:, 2] > p[u, 2].max() - 0.008)
        lf = l & (p[:, 2] > p[l, 2].max() - 0.008)
        y0 = (p[uf, 1].min() + p[lf, 1].max()) / 2
        nu = u & (p[:, 1] > y0) & (p[:, 1] < y0 + 0.004)
        nl = l & (p[:, 1] < y0) & (p[:, 1] > y0 - 0.012)
        xs.append((a + b) / 2)
        seam.append(y0)
        edge.append(p[nu, 2].max() if nu.any() else p[uf, 2].max())
        bulge.append(p[nl, 2].max() if nl.any() else p[lf, 2].max())
    at = lambda v: np.interp(p[:, 0], xs, v)
    return at(seam), at(edge), at(bulge), half


def blur(np, a, r):
    """Gaussian blur, sigma `r` px (in frequency space; the atlas's edges are background)"""
    fy, fx = np.fft.fftfreq(a.shape[0])[:, None], np.fft.rfftfreq(a.shape[1])[None]
    g = np.exp(-2 * np.pi ** 2 * r ** 2 * (fx ** 2 + fy ** 2))
    return np.fft.irfft2(np.fft.rfft2(a) * g, a.shape)


def blur3(np, px, r):
    return np.stack([blur(np, px[..., c], r) for c in range(px.shape[-1])], -1)


class Regions:
    """per-texel weights in the skin's UV space, from per-vertex weights"""

    def __init__(self, np, raw, mpfb, size):
        from PIL import Image, ImageDraw
        topo = dict(np.load(raw / "topo.body.npz"))
        self.np, self.size = np, size
        uv, vmap, tris = topo["uv"], topo["vmap"], topo["index"].reshape(-1, 3)
        self.uv, self.vmap, self.tris = uv, vmap, tris
        self.tri_v = vmap[tris]
        # triangle id per texel (-1: none)
        im = Image.new("I", (size, size), 0)
        draw = ImageDraw.Draw(im)
        for i, tri in enumerate(tris):
            draw.polygon([(uv[k, 0] * size, (1 - uv[k, 1]) * size) for k in tri], fill=i + 1)
        self.tri = np.asarray(im).astype(np.int64) - 1
        self.covered = self.tri >= 0
        got = {k[4:]: v for k, v in np.load(raw / "female-adult.neutral.npz").items()}
        self.pos, self.eyes = got["body"].astype(np.float64), got["eyes"].astype(np.float64)
        weights = json.loads((mpfb / "data" / "rigs" / "standard" / "weights.default.json").read_text())["weights"]
        n = len(self.pos)
        self.bone = {}
        for name, pairs in weights.items():
            w = np.zeros(n)
            for i, v in pairs:
                if i < n:
                    w[i] = v
            self.bone[name] = w
        self.group = {}
        extra = (mpfb / "entities" / "socketobject" / "_extra_vertex_groups.py").read_text()
        for line in extra.splitlines():
            if line.startswith('vertex_group_information["basemesh"]["'):
                key = line.split('"')[3]
                ids = [i for i in json.loads(line.split("=", 1)[1]) if i < n]
                w = np.zeros(n)
                w[ids] = 1
                self.group[key] = w

    def paint(self, w, r=3):
        """per-vertex weights → texels (each triangle its mean), softened by `r` px"""
        np = self.np
        per_tri = np.append(w[self.tri_v].mean(1), 0)
        return blur(np, per_tri[self.tri].astype(np.float32), r) if r else per_tri[self.tri]

    def ring(self, a, b):
        """where two bones' weights meet: the joint between them"""
        wa, wb = self.bone[a], self.bone[b]
        return self.np.clip(4 * wa * wb / self.np.maximum((wa + wb) ** 2, 1e-9), 0, 1) * self.np.clip((wa + wb) * 2, 0, 1)


def regions(np, raw, mpfb, size):
    """UV weights of each colour region; `mpfb`: MPFB's package folder (rigs, vertex groups)"""
    r = Regions(np, raw, mpfb, size)
    p, eyes = r.pos, r.eyes
    left, right = eyes[eyes[:, 0] > 0].mean(0), eyes[eyes[:, 0] < 0].mean(0)
    U = np.linalg.norm(left - right)
    s = U / 0.063  # scene units per metre, by the eyes' spacing
    face = p[:, 2] > left[2] - 0.07 * s
    out = {}

    def blob(c, radius, scale=(1, 1, 1)):
        d = np.linalg.norm((p - c) * np.array(scale), axis=1) / (radius * s)
        return np.exp(-d ** 2)

    # cheek apples: below and a little outside each eye
    cheeks = sum(blob(e + np.array([np.sign(e[0]) * 0.012, -0.035, 0.0]) * s, 0.022, (1, 1.2, 0.6)) for e in (left, right))
    out["cheeks"] = r.paint(np.clip(cheeks, 0, 1) * face, 8)
    # nose: its tip (the face's most forward point between eyes and mouth) and the wings beside it
    mid = (np.abs(p[:, 0]) < 0.004 * s) & (p[:, 1] < left[1] - 0.02 * s) & (p[:, 1] > left[1] - 0.07 * s)
    tip = p[mid][np.argmax(p[mid][:, 2])]
    out["nose"] = r.paint(blob(tip - np.array([0, 0.004, 0.004]) * s, 0.013, (0.8, 1, 1)) * face, 4)
    out["ears"] = r.paint(r.group["ears"], 5)
    lips = r.group["lips"] * np.clip(r.bone["oris01"] + r.bone["oris02"] + r.bone["oris03.L"] + r.bone["oris03.R"] + r.bone["oris04.L"]
                                       + r.bone["oris04.R"] + r.bone["oris05"] + r.bone["oris06"] + r.bone["oris06.L"] + r.bone["oris06.R"]
                                       + r.bone["oris07.L"] + r.bone["oris07.R"] + 0.3, 0, 1)
    out["lips"] = r.paint(lips, 1.5)
    # the vermilion only: an almond round the mouth line, taller at the middle, the lower lip a little fuller
    lg = (r.group["lips"] > 0) & face
    lp = p[lg]
    half = np.abs(lp[:, 0]).max() * 0.92
    cy = np.median(lp[:, 1])
    t = np.clip(1 - (p[:, 0] / half) ** 2, 0, 1) ** 0.6
    dy = p[:, 1] - cy
    h = np.where(dy > 0, 0.0065, 0.008) * s * t
    core = smoothstep(1.15, 0.8, np.abs(dy) / np.maximum(h, 1e-6)) * (t > 0) * lg
    out["lips-core"] = r.paint(core.astype(float), 1.0)
    # the mouth line: a thin band where the lips meet, and the lining behind their edges
    up = np.maximum(r.bone["oris03.L"], np.maximum(r.bone["oris03.R"], r.bone["oris05"])) > 0.3
    lo = np.maximum(r.bone["oris01"], np.maximum(r.bone["oris07.L"], r.bone["oris07.R"])) > 0.3
    y0, zu, zb, half = lip_seam(np, p, up, lo)
    lipv = r.group["lips"] > 0
    line = (1 - smoothstep(0.0006, 0.0018, np.abs(p[:, 1] - y0))) * smoothstep(half, 0.85 * half, np.abs(p[:, 0]))
    lining = lipv & (p[:, 2] < np.minimum(zu, zb) - 0.004)
    out["mouth-line"] = r.paint(np.maximum(line * lipv, lining * 0.8), 0.8)
    out["lids"] = r.paint(r.bone["orbicularis03.L"] + r.bone["orbicularis03.R"], 2.5)
    out["under-eyes"] = r.paint(r.bone["orbicularis04.L"] + r.bone["orbicularis04.R"], 3)
    # knees (front), elbows (back), knuckles and finger joints
    knees = sum(r.ring(f"upperleg02.{x}", f"lowerleg01.{x}") for x in "LR")
    front = smoothstep(-0.01 * s, 0.03 * s, p[:, 2] - np.median(p[knees > 0.3][:, 2]))
    out["knees"] = r.paint(knees * front, 6)
    elbows = sum(r.ring(f"upperarm02.{x}", f"lowerarm01.{x}") for x in "LR")
    back = smoothstep(-0.01 * s, 0.02 * s, np.median(p[elbows > 0.3][:, 2]) - p[:, 2])
    out["elbows"] = r.paint(elbows * back, 5)
    knuckles = sum(r.ring(f"metacarpal{m}.{x}", f"finger{m + 1}-1.{x}") + 0.6 * r.ring(f"finger{m + 1}-1.{x}", f"finger{m + 1}-2.{x}")
                   for m in range(1, 5) for x in "LR")
    out["knuckles"] = r.paint(smoothstep(0.55, 0.95, np.clip(knuckles, 0, 1)), 2)
    out["nails"] = r.paint(r.group["fingernails"] + r.group["toenails"], 1)
    out["head"] = r.paint(smoothstep(left[1] - 0.2 * s, left[1] - 0.09 * s, p[:, 1]), 12)
    # a child's chest mark: a round dot in body space (painted in the atlas it stretches with the UVs)
    dot = np.zeros(len(p))
    for side in (1, -1):
        band = (side * p[:, 0] > 0.5 * U) & (side * p[:, 0] < 2.8 * U) & (p[:, 1] < left[1] - 3.2 * U) & (p[:, 1] > left[1] - 7 * U)
        c = p[np.flatnonzero(band)[np.argmax(p[band][:, 2])]]
        dot = np.maximum(dot, 1 - smoothstep(0.006 * s, 0.011 * s, np.linalg.norm(p - c, axis=1)))
    out["kid-areola"] = r.paint(dot, 3)
    out["covered"] = r.covered
    out["mesh"] = r
    return out


def tone_of(np, px, covered):
    body = px[covered]
    body = body[body.sum(1) > 40]
    return np.median(body, 0)


def areolae(np, px, radius, strength, male=False):
    """MakeHuman's chest marks are a small dot: a soft tone, a deeper shade of the skin around it"""
    size = px.shape[0]
    lum = px @ np.array([0.3, 0.59, 0.11])
    bg = blur3(np, px, radius * 2)
    red = (px[..., 0] - px[..., 1]) - (bg[..., 0] - bg[..., 1]) + (bg @ np.array([0.3, 0.59, 0.11]) - lum)
    yy, xx = np.mgrid[0:size, 0:size]
    out = px.copy()
    for u, v in NIPPLE_UV:
        cx, cy, w = int(u * size), int((1 - v) * size), size // 80
        win = red[cy - w:cy + w, cx - w:cx + w]
        dy, dx = np.unravel_index(np.argmax(win), win.shape)
        cx, cy = cx - w + dx, cy - w + dy
        d = np.hypot(xx - cx, yy - cy) / radius
        # the skin round it evened out: its texels stretch into spokes where the mesh fans in to the centre
        # (a child's: wiped clean, the soft mark is painted over it after)
        wide = (1 - smoothstep(1.0, 2.4, d))[..., None] * (0.8 if strength else 1.0)
        out = out * (1 - wide) + (bg + (0.25 if strength else 0.0) * (px - bg)) * wide
        m = (1 - smoothstep(0.45, 1.25, d))[..., None] * strength
        core = (1 - smoothstep(0.15, 0.4, d))[..., None]
        base = bg[cy, cx]
        dark = float(np.clip((170 - base @ np.array([0.3, 0.59, 0.11])) / 110, 0, 1))
        # a tone that follows the skin's
        ratio = np.array([0.80, 0.63, 0.55]) * (1 - dark) + np.array([0.66, 0.58, 0.55]) * dark
        if male:  # a more muted tone
            ratio = np.array([0.80, 0.70, 0.66]) * (1 - dark) + np.array([0.76, 0.70, 0.68]) * dark
        # (an even tone: a darker centre reads as a hole)
        shade = base * ratio
        if male:
            shade = shade * 0.75 + (shade @ np.array([0.3, 0.59, 0.11]))[..., None] * 0.25 * np.array([1.06, 0.98, 0.9])
        out = out * (1 - m) + (shade + 0.1 * (px - bg)) * m
    return out


def mix(px, w, tint, k=1.0):
    """multiply by `tint` where `w`"""
    w = w[..., None] * k
    return px * (1 - w) + px * tint * w


def finish(np, px, heritage, name, reg):
    """blended MakeHuman skin → the heritage's tone with natural colour by region"""
    covered = reg["covered"]
    bright, warm = VARIANT[name]
    target = np.array(TONE[heritage], np.float64) * bright * np.array(warm)
    # broad colour to the target, detail kept (a little stronger); the broad colour from skin texels only
    cov = covered.astype(np.float32)
    # on the head, the deep folds (nostrils, the mouth's corners) don't darken the broad colour round them
    med = tone_of(np, px, covered)
    head = reg["head"][..., None]
    src = px * (1 - head) + np.maximum(px, 0.82 * med) * head
    broad = blur3(np, src * cov[..., None], 24) / np.maximum(blur(np, cov, 24), 1e-3)[..., None]
    broad = np.where(covered[..., None], broad, px)
    broad = broad * (1 - (1 - BODY_SHADE[name]) * (1 - head)) + med * (1 - BODY_SHADE[name]) * (1 - head)
    # brightness scaled, hue moved: regions that differ in hue from the body (palms, soles, lips) keep that difference
    Y = np.array([0.3, 0.59, 0.11])
    lum = np.maximum(broad @ Y, 1)[..., None]
    hue = target / (target @ Y) * (np.clip(broad / lum, 0.05, 3) / (med / (med @ Y))) ** 0.4
    detail = np.clip(px / np.maximum(broad, 1), 0.2, 3) ** DETAIL
    detail = detail ** (1 - np.maximum(reg["head"][..., None] * CLEAN[name], BODY_CLEAN[name]))
    px = lum * (target @ Y) / (med @ Y) * hue * detail
    lum = float(target @ np.array([0.3, 0.59, 0.11]))
    dark = float(np.clip((190 - lum) / 120, 0, 1))  # 0 light … 1 deep
    f = FACE[name]
    sh = SHADE.get(heritage, 1.0)
    # blood shows as a warmth that follows the skin's tone
    flush = np.array([1.02, 0.88, 0.87]) * (1 - dark) + np.array([0.96, 0.88, 0.86]) * dark
    px = mix(px, reg["cheeks"], flush, min(0.55 * f * sh, 0.95))
    px = mix(px, reg["nose"], flush, min(0.45 * sh, 0.95))
    px = mix(px, reg["ears"], flush, 0.35)
    # lids a touch deeper and browner (defines the eye), a faint shadow under the eyes
    px = mix(px, reg["lids"], np.array([0.93, 0.89, 0.88]) * (1 - dark) + np.array([0.88, 0.85, 0.84]) * dark, min(0.55 * sh, 0.95))
    px = mix(px, reg["under-eyes"], np.array([0.96, 0.92, 0.94]), 0.4)
    # lips: a tone that follows the skin's
    lip = np.array([0.94, 0.75, 0.76]) * (1 - dark) + np.array([0.82, 0.70, 0.74]) * dark
    lip = lip * np.array(LIP_TINT.get(heritage, (1.0, 1.0, 1.0)))
    if name == "kid":
        # a child's lips barely darker than the skin
        px = mix(px, reg["lips-core"], lip, 0.15 + 0.2 * f)
    elif not name.startswith("male"):
        # a soft rose over the lips, clearer on the lips themselves
        px = mix(px, reg["lips"], lip, 0.35 * f)
        px = mix(px, reg["lips-core"], lip * np.array([0.95, 0.84, 0.87]), 0.3 + 0.5 * f)
    else:
        px = mix(px, reg["lips"], lip, 0.3 + 0.45 * f)
    # the mouth line: a deeper shade where the lips meet
    px = mix(px, reg["mouth-line"], np.array([0.62, 0.52, 0.52]) * (1 - dark) + np.array([0.6, 0.55, 0.55]) * dark, 0.55)
    # knees, elbows, knuckles: warmer and deeper
    joint = np.array([0.96, 0.86, 0.83]) * (1 - dark) + np.array([0.84, 0.79, 0.78]) * dark
    px = mix(px, reg["knees"], joint, 0.7)
    px = mix(px, reg["elbows"], joint, 0.6)
    px = mix(px, reg["knuckles"], joint, 0.4)
    px = mix(px, reg["nails"], np.array([1.05, 0.98, 0.98]) * (1 - dark) + np.array([1.12, 1.04, 1.02]) * dark, 0.5)
    radius = {"male": 14, "female": 12, "kid": 9}[name.split("-")[0]]
    px = areolae(np, px, radius, 0.0 if name == "kid" else 1.0, male=name.startswith("male"))
    if name == "kid":
        px = mix(px, reg["kid-areola"], np.array([0.9, 0.8, 0.78]) * (1 - dark) + np.array([0.86, 0.8, 0.78]) * dark, 0.3)
    return np.clip(px, 0, 255)


def level_seams(np, px, reg, reach=0.05, size=2.0):
    """the skin's UV islands meet along seams (down the spine, over the shoulders) where the two sides' tones differ
    and print as lines: each side is moved to their mean there, the change fading into the island (over about
    1/sqrt(reach) edges); the atlas round the islands takes their edge colour (no background bleeding into the
    sampled or mipmapped edge)"""
    r, covered = reg["mesh"], reg["covered"]
    uv, vmap, tris = r.uv.astype(np.float64), r.vmap, r.tris
    n = px.shape[0]
    cov = covered.astype(np.float64)
    soft = blur3(np, px * cov[..., None], size) / np.maximum(blur(np, cov, size), 1e-3)[..., None]

    def sample(q):
        x = np.clip(q[:, 0] * n - 0.5, 0, n - 1.001)
        y = np.clip((1 - q[:, 1]) * n - 0.5, 0, n - 1.001)
        x0, y0 = x.astype(int), y.astype(int)
        fx, fy = (x - x0)[:, None], (y - y0)[:, None]
        return ((soft[y0, x0] * (1 - fx) + soft[y0, x0 + 1] * fx) * (1 - fy)
                + (soft[y0 + 1, x0] * (1 - fx) + soft[y0 + 1, x0 + 1] * fx) * fy)
    # each render vertex's colour, sampled a little inside each of its triangles
    cen = uv[tris].mean(1)
    col, cnt = np.zeros((len(uv), 3)), np.zeros(len(uv))
    for k in range(3):
        np.add.at(col, tris[:, k], sample(0.8 * uv[tris[:, k]] + 0.2 * cen))
        np.add.at(cnt, tris[:, k], 1)
    col /= np.maximum(cnt, 1)[:, None]
    twins = np.bincount(vmap, minlength=vmap.max() + 1)
    seam = twins[vmap] > 1
    mean = np.zeros((len(twins), 3))
    np.add.at(mean, vmap, col)
    mean /= np.maximum(twins, 1)[:, None]
    fix = np.where(seam[:, None], mean[vmap] - col, 0.0)
    e = np.unique(np.sort(np.concatenate([tris[:, [0, 1]], tris[:, [1, 2]], tris[:, [2, 0]]]), axis=1), axis=0)
    deg = np.bincount(e.ravel(), minlength=len(uv)).astype(np.float64)
    g = fix.copy()
    for _ in range(300):
        acc = np.zeros_like(g)
        np.add.at(acc, e[:, 0], g[e[:, 1]])
        np.add.at(acc, e[:, 1], g[e[:, 0]])
        g = np.where(seam[:, None], fix, acc / (deg + reach)[:, None])
    # onto the texels: barycentric within each texel's triangle
    ys, xs = np.nonzero(covered)
    t = r.tri[ys, xs]
    q = np.stack([(xs + 0.5) / n, 1 - (ys + 0.5) / n], 1)
    a, b, c = uv[tris[t, 0]], uv[tris[t, 1]], uv[tris[t, 2]]
    v0, v1, v2 = b - a, c - a, q - a
    den = v0[:, 0] * v1[:, 1] - v1[:, 0] * v0[:, 1]
    den = np.where(np.abs(den) < 1e-12, 1e-12, den)
    wb = np.clip((v2[:, 0] * v1[:, 1] - v1[:, 0] * v2[:, 1]) / den, 0, 1)
    wc = np.clip((v0[:, 0] * v2[:, 1] - v2[:, 0] * v0[:, 1]) / den, 0, 1 - wb)
    out = px.copy()
    out[ys, xs] += (1 - wb - wc)[:, None] * g[tris[t, 0]] + wb[:, None] * g[tris[t, 1]] + wc[:, None] * g[tris[t, 2]]
    # the background: the islands' colour spread outward
    filled = cov.copy()
    for sigma in (2, 6, 18, 54):
        w = blur(np, filled, sigma)
        spread = blur3(np, out * filled[..., None], sigma) / np.maximum(w, 1e-6)[..., None]
        new = (filled == 0) & (w > 0.02)
        out[new] = spread[new]
        filled[new] = 1
    return out


def save(np, px, path, limit=250_000):
    """JPEG at the best quality that stays under `limit` bytes"""
    from PIL import Image
    im = Image.fromarray(np.clip(px, 0, 255).astype(np.uint8))
    for q in range(80, 60, -2):
        im.save(path, quality=q, optimize=True)
        if path.stat().st_size <= limit:
            return
