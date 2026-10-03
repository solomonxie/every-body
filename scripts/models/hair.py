"""Hair: strand cards grown on each figure's scalp, plus one shared strand texture (both generated here, CC0).

A groom is grown once per figure group on its neutral body: roots scattered over the scalp, each strand combed
along the style's flow, pulled by gravity and kept off the skin, then turned into a textured card. Heritage variants
carry the neutral groom along with the head (each card vertex follows its nearest skin vertices).
Lengths are in cm of the real head; U = scene units per cm, from the eye-to-crown height (11.5 cm).
"""

import math

# strips: KINDS × LEVELS × VARIANTS, 64 texels (about a centimetre of card) wide
KINDS, LEVELS, VARIANTS = ("sparse", "dense", "coil"), 4, 3
STRIPS = len(KINDS) * LEVELS * VARIANTS
# one more strip at the right: solid hair colour for the shell under the cards
TEX_W, TEX_H = 64 * (STRIPS + 1), 1024
SHELL_U = (STRIPS + 0.5) / (STRIPS + 1)
# strip brightness by depth in the hair (inner cards darker: baked occlusion)
LEVEL_SHADE = (1.0, 0.8, 0.64, 0.5)

# hairline height (cm above the eyes) by azimuth around the head (deg, 0 = front)
HAIRLINE = [(0, 6.4), (30, 6.0), (55, 4.2), (70, 1.5), (80, -1.2), (86, -2.2), (92, 2.6), (128, 2.6), (145, -3.5),
            (160, -5.8), (180, -6.6)]

STYLES = {
    # kind: texture strips (KINDS); flow: "part" falls away from a side part (part: its x, of a half head),
    # "back": brushed back, "fringe": forward from the crown, "random": no direction; tousle: per-root scatter
    # lengths (short cuts, cm): top front, crown, sides, nape; cut (long): cm below the chin where the tips end
    # hug: how firmly a strand is drawn back onto its layer when it lifts off (within hug_reach cm)
    # widths, volume, base (offset off the scalp), wave, tuck (ends turned under), recede: cm; sideburns: hair in
    # front of the ears (False: none; a number: how far down they reach, cm above the eyes); ear: the hairline's
    # height over the ears (cm above the eyes) on short cuts
    # soft shoulder-length hair from a deep side part, a side-swept fringe
    "woman": dict(count=3000, width=0.9, rows=16, flow="part", part=0.5, cut=2.0, max_len=34, gravity=0.4, stiff=2.0,
                  lift=0.2, volume=1.2, base=0.25, hug=0.5, hug_reach=2.0, face=1.0, wave=0.25, recede=0.0, tuck=0.8,
                  sculpt=dict(locks=True, root=0.75, tip=0.6, bangs=dict(count=24, part=0.5, lift=0.35, radius=0.5, end=3.0),
                              style=dict(lift=0.3, base=0.25, volume=0.3, hug=0.85))),
    # curls: waves every wave_len cm, turning round the strand (curl) instead of side to side
    "woman-curly": dict(count=2100, width=0.85, rows=36, flow="part", part=0.45, cut=5.0, max_len=32, gravity=0.35, stiff=2.0,
                        lift=0.3, volume=1.8, base=0.3, hug=0.45, hug_reach=2.0, face=1.0, wave=0.7, wave_len=3.2, curl=True, cut_jitter=2.5, recede=0.0, tuck=0.0,
                        sculpt=dict(locks=False, root=0.7, tip=0.6, smooth=40,
                                    style=dict(cut_jitter=1.2, lift=0.35, base=0.3, volume=0.45, wave=0.85, wave_len=2.8))),
    "woman-coily": dict(kind="coil", count=1600, width=1.1, rows=32, flow="part", part=0.0, cut=1.5, max_len=24, gravity=0.2, stiff=2.5,
                        lift=0.6, volume=2.6, base=0.4, hug=0.35, hug_reach=2.0, face=1.0, wave=0.9, wave_len=2.6, curl=True, cut_jitter=2.0, recede=0.0, tuck=0.0,
                        sculpt=dict(root=0.9, tip=0.8, smooth=65, style=dict(cut_jitter=0.5, volume=1.1, lift=0.35))),
    # sculpted: the groom's strands fused into one smooth solid (build_figure.sculpt_hair), no see-through cards;
    # sculpt: tube radius (cm) at the root and tip, every n-th strand
    "sculpt-woman-long": dict(count=2400, width=0.9, rows=16, flow="part", part=0.5, cut=6.5, max_len=34, gravity=0.4, stiff=2.0,
                              lift=0.05, volume=0.3, base=0.1, hug=0.9, hug_reach=3.0, face=1.0, wave=0.0, recede=0.0, tuck=0.4,
                              sculpt=dict(root=0.7, tip=0.5, every=2, bangs=dict(count=22, part=0.5, lift=0.45, radius=0.55))),
    # a soft short bob to the jaw, side-swept
    "woman-senior": dict(sideburns=False, count=2400, width=1.0, rows=12, flow="part", part=0.45, cut=-2.0, max_len=16, gravity=0.35, stiff=2.5,
                         lift=0.25, volume=1.4, base=0.3, hug=0.45, hug_reach=2.0, face=1.0, wave=0.3, recede=0.4, tuck=0.35,
                         sculpt=dict(locks=True, root=0.75, tip=0.5, bangs=dict(count=20, part=0.45, lift=0.4, radius=0.5, end=3.0),
                                     style=dict(lift=0.35, base=0.25, volume=0.4, hug=0.75))),
    # oxford: short tapered back and sides, longer on top combed back and across from a side part
    "man": dict(kind="dense", tousle=0.2, count=2800, width=0.75, rows=6, flow="back", part=0.4, sweep=0.7, side_down=0.35,
                lengths=(5.5, 3.5, 1.0, 0.8), gravity=0.02, stiff=4, lift=0.25, volume=1.0, top_loose=0.6, base=0.12, hug=0.6,
                hug_reach=3.0, recede=0.6, ear=2.0, part_line=True, swirl=0.2,
                sculpt=dict(root=0.8, tip=0.55, short=0.5, edge=0.45, taper=1.0, rim=0.5, trim=0.9)),
    # short and thin; a light side part
    "man-senior": dict(kind="dense", tousle=0.2, count=3000, width=0.7, rows=6, flow="back", part=0.45, sweep=0.6, side_down=0.4,
                       lengths=(3.5, 2.2, 0.8, 0.6), gravity=0.02, stiff=4, lift=0.2, volume=0.5, top_loose=0.4, base=0.08, hug=0.6,
                       hug_reach=3.0, recede=2.6, sideburns=False, ear=2.5, swirl=0.2,
                       sculpt=dict(root=0.7, tip=0.5, short=0.3, edge=0.3, taper=2.0, rim=0.5, trim=0.9, voxel=0.2, smooth=45)),
    # short, the top combed across from a side part (a boy's oxford)
    "boy": dict(kind="dense", tousle=0.25, count=2400, width=0.75, rows=6, flow="back", part=0.4, sweep=0.9, side_down=0.4,
                lengths=(4.5, 3.0, 1.1, 0.9), gravity=0.04, stiff=3, lift=0.25, volume=0.8, top_loose=0.5, base=0.12, hug=0.6,
                hug_reach=3.0, recede=0.0, sideburns=1.2, ear=2.5, part_line=True, swirl=0.2,
                sculpt=dict(root=0.8, tip=0.55, short=0.5, edge=0.45, taper=1.0, rim=0.5, trim=0.9)),
    "boy-toddler": dict(kind="dense", tousle=0.3, count=2600, width=0.75, rows=6, flow="back", part=0.4, sweep=0.9, side_down=0.5,
                        lengths=(3.5, 2.8, 1.1, 0.7), gravity=0.04, stiff=3, lift=0.2, volume=0.7, top_loose=0.5, base=0.12, hug=0.6,
                        hug_reach=3.0, recede=0.0, sideburns=1.5, ear=2.5, swirl=0.25,
                        sculpt=dict(root=0.8, tip=0.55, short=0.45, edge=0.45, taper=1.5, rim=0.5, trim=0.9)),
    # tightly coiled hair, cut short: a soft even cap with no combed direction
    "man-coily": dict(kind="coil", count=4200, width=0.75, rows=4, flow="random", part=0.0, lengths=(1.4, 1.3, 0.9, 0.8), gravity=0.0,
                      stiff=4, lift=0.05, volume=0.5, base=0.1, hug=0.8, hug_reach=3.0, recede=0.6,
                      ear=2.5, sculpt=dict(root=0.7, tip=0.6, edge=0.35, taper=1.0, rim=0.35, trim=0.9, style=dict(volume=0.3, lift=0.1))),
    "man-senior-coily": dict(kind="coil", count=3500, width=0.75, rows=4, flow="random", part=0.0, lengths=(1.1, 1.0, 0.8, 0.7),
                             gravity=0.0, stiff=4, lift=0.05, volume=0.4, base=0.1, hug=0.8, hug_reach=3.0, recede=2.6,
                             sideburns=False, ear=2.5, sculpt=dict(root=0.7, tip=0.6, edge=0.35, taper=1.0, rim=0.35, trim=0.9, style=dict(volume=0.3, lift=0.1))),
    "boy-coily": dict(kind="coil", count=3800, width=0.75, rows=4, flow="random", part=0.0, lengths=(1.6, 1.5, 1.0, 0.9), gravity=0.0,
                      stiff=4, lift=0.05, volume=0.6, base=0.1, hug=0.8, hug_reach=3.0, recede=0.0, sideburns=1.2,
                      ear=3.0, sculpt=dict(root=0.7, tip=0.6, edge=0.35, taper=1.0, rim=0.35, trim=0.9, style=dict(volume=0.3, lift=0.1))),
    "boy-toddler-coily": dict(kind="coil", count=3300, width=0.75, rows=4, flow="random", part=0.0, lengths=(1.4, 1.3, 1.0, 0.9),
                              gravity=0.0, stiff=4, lift=0.05, volume=0.5, base=0.1, hug=0.8, hug_reach=3.0, recede=0.0, sideburns=1.5,
                              ear=3.0, sculpt=dict(root=0.7, tip=0.6, edge=0.35, taper=1.0, rim=0.35, trim=0.9, style=dict(volume=0.3, lift=0.1))),
    "girl": dict(count=3000, width=0.9, rows=16, flow="part", part=0.4, cut=3.0, max_len=30, gravity=0.4, stiff=2.0,
                 lift=0.15, volume=1.0, base=0.25, hug=0.5, hug_reach=2.0, face=1.0, wave=0.25, recede=0.0, tuck=0.6,
                 sculpt=dict(locks=True, root=0.8, tip=0.6, bangs=dict(count=20, part=0.4, lift=0.35, radius=0.45, end=3.0),
                             style=dict(lift=0.3, base=0.25, volume=0.3, hug=0.85))),
    # a little chin-length bob from a side part, with side-swept bangs
    "girl-toddler": dict(count=2600, width=0.8, rows=12, flow="part", part=0.4, cut=-4.0, max_len=14, gravity=0.35, stiff=2.5,
                         lift=0.25, volume=1.0, base=0.25, hug=0.5, hug_reach=2.0, face=1.0, wave=0.2, recede=0.0, tuck=0.3,
                         sculpt=dict(locks=False, root=0.75, tip=0.55, bangs=dict(count=18, part=0.4, lift=0.35, radius=0.45, end=3.0),
                                     style=dict(lift=0.3, base=0.25, volume=0.35, hug=0.8))),
}

# every style is sculpted (stylized, one solid), by strand kind: tube radius (cm) at the root and tip, every n-th
# strand, voxel size and smoothing passes of the fused solid, bumps (height, size in cm) over its surface, the
# face-framing locks' thinness (lock_thin), and changes to the style's growth (an even hem, a little lift on top)
SCULPT = {"sparse": dict(root=0.8, tip=0.6, every=1, voxel=0.3, smooth=70, locks=True, style=dict(cut_jitter=0.3, lift=0.35, base=0.3, volume=0.35)),
          "dense": dict(root=0.8, tip=0.55, every=1, voxel=0.25, smooth=60, style=dict(tousle=0.05)),
          "coil": dict(root=1.0, tip=0.9, every=1, voxel=0.3, smooth=30, bumps=(0.4, 1.2), decimate=0.35,
                       style=dict(cut_jitter=0.5, volume=1.1, lift=0.35))}
for _style in STYLES.values():
    _base, _own = SCULPT[_style.get("kind", "sparse")], _style.get("sculpt", {})
    _style["sculpt"] = {**_base, **_own, "style": {**_base.get("style", {}), **_own.get("style", {})}}

# a character's own sculpted hair (face_fit.py carries it onto the group's neutral head → RAW sculpt.<style>.npz)
CHARACTER_HAIR = {"rain": "rain", "rain-senior": "rain", "rain-girl": "rain", "rain-toddler": "rain", "snow": "snow"}
for _name, _source in CHARACTER_HAIR.items():
    STYLES[_name] = dict(character=_source, recede=0.0)


# long, straight to the mid-back
STYLES["woman-long"] = {**STYLES["woman"], "cut": 26.0, "max_len": 62, "gravity": 0.5, "wave": 0.1, "tuck": 0.2}

# a heritage's own version of a cut
HERITAGE_STYLE = {"east-asian": {"woman": "woman-long"}, "hispanic": {"woman": "woman-curly"},
                  "black": {"woman": "woman-coily", "man": "man-coily", "man-senior": "man-senior-coily", "boy": "boy-coily", "boy-toddler": "boy-toddler-coily"}}


def styles_for(names, heritage):
    return [HERITAGE_STYLE.get(heritage, {}).get(n, n) for n in names]


def smooth(a, b, x):
    import numpy as np
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def unit(np, v):
    return v / np.maximum(np.linalg.norm(v, axis=-1, keepdims=True), 1e-12)


def vertex_normals(np, p, tris):
    f = np.cross(p[tris[:, 1]] - p[tris[:, 0]], p[tris[:, 2]] - p[tris[:, 0]])
    n = np.zeros_like(p)
    for k in range(3):
        np.add.at(n, tris[:, k], f)
    return unit(np, n)


class Head:
    """landmarks of one neutral figure: eyes, crown, cm scale, head centre; the skin near the head to collide with"""

    def __init__(self, np, body, eyes, tris):
        self.eye = eyes.mean(0)
        self.top = body[:, 1].max()
        self.U = (self.top - self.eye[1]) / 11.5
        band = body[(body[:, 1] > self.eye[1]) & (body[:, 1] < self.eye[1] + 4 * self.U) & (np.abs(body[:, 0]) < 1.5 * self.U)]
        self.C = np.array([0.0, self.eye[1] + 2 * self.U, (band[:, 2].min() + band[:, 2].max()) / 2])
        self.normals = vertex_normals(np, body, tris)
        self.near = np.where(body[:, 1] > self.eye[1] - 32 * self.U)[0]
        self.pts, self.nrm = body[self.near], self.normals[self.near]
        # face half-width per 1 cm of height (for keeping long hair off the face)
        front = body[(body[:, 2] > self.C[2] + 2 * self.U) & (body[:, 1] > self.eye[1] - 16 * self.U)]
        self.face_w = {}
        for y, x in zip(np.floor((front[:, 1] - self.eye[1]) / self.U).astype(int), np.abs(front[:, 0])):
            self.face_w[y] = max(self.face_w.get(y, 0), x)

    def local(self, p):
        """cm: height above the eyes, azimuth (deg, 0 front), horizontal radius"""
        import numpy as np
        q = p - self.C
        return (p[..., 1] - self.eye[1]) / self.U, np.degrees(np.arctan2(q[..., 0], q[..., 2])), np.hypot(q[..., 0], q[..., 2]) / self.U

    def scalp(self, p, recede=0.0, sideburns=True, ear=None):
        """0..1: how much a skin point lies inside the hairline (a soft 1 cm edge)"""
        y, az, _ = self.local(p)
        line = self.line(az, recede, sideburns, ear)
        return smooth(line - 0.4, line + 0.8, y)

    @staticmethod
    def line(az, recede=0.0, sideburns=True, ear=None):
        """the hairline's height (cm above the eyes) by azimuth"""
        import numpy as np
        a = np.abs(az)
        xs, ys = zip(*HAIRLINE)
        line = np.interp(a, xs, ys)
        if sideburns is not True:
            low = 1.5 if sideburns is False else float(sideburns)
            line = np.maximum(line, np.interp(a, [60, 75, 92, 100], [-9, low, low, -9]))
        if ear is not None:
            # a short cut's hairline: close over the ear, down behind it, level across the nape
            w = smooth(86, 96, a)
            line = line * (1 - w) + w * np.interp(a, [96, 118, 130, 150, 180], [ear, ear, -3.8, -5.6, -6.4])
        # a higher hairline (a rounded peak in the middle)
        return line + recede * np.interp(a, [0, 12, 28, 45, 65, 80], [0.4, 0.5, 1.1, 1.6, 0.6, 0])

    def rim(self, np, style, inset=0.5, step=2.0):
        """a line round the scalp just inside the hairline, on the skin (a clean, even edge for short cuts)"""
        y, az, r = self.local(self.pts)
        out = []
        for a in np.arange(-180, 180 + step, step):
            h = self.line(a, style.get("recede", 0.0), style.get("sideburns", True), style.get("ear")) + inset
            d = np.radians(((az - a + 180) % 360) - 180) * r
            out.append(self.pts[np.argmin(d ** 2 + (y - h) ** 2)])
        out = np.array(out)
        # finer steps, laid back onto the skin
        seg = np.linalg.norm(np.diff(out, axis=0), axis=1)
        cum = np.concatenate([[0], np.cumsum(seg)])
        want = np.linspace(0, cum[-1], int(cum[-1] / (0.3 * self.U)) + 2)
        out = np.stack([np.interp(want, cum, out[:, k]) for k in range(3)], 1)
        for _ in range(4):
            dep, n = self.depth(np, out)
            out = out - n * dep[:, None]
        return out

    def nearest(self, np, p, k=3):
        """per point: k nearest skin vertices (indices into self.pts) and squared distances"""
        out_i, out_d = [], []
        v2 = (self.pts ** 2).sum(1)
        for s in range(0, len(p), 2048):
            c = p[s:s + 2048]
            d = np.maximum((c ** 2).sum(1)[:, None] + v2[None] - 2 * c @ self.pts.T, 0)
            i = np.argpartition(d, k, axis=1)[:, :k]
            out_i.append(i)
            out_d.append(np.take_along_axis(d, i, 1))
        return np.concatenate(out_i), np.concatenate(out_d)

    def depth(self, np, p):
        """distance outside the skin (negative inside) and the skin's normal there"""
        i, d = self.nearest(np, p)
        w = 1 / (d + 1e-10)
        w /= w.sum(1, keepdims=True)
        n = unit(np, (self.nrm[i] * w[..., None]).sum(1))
        dep = np.einsum("ijk,ijk->ij", p[:, None] - self.pts[i], self.nrm[i])
        return (dep * w).sum(1), n


def roots(np, rng, head, body, tris, style):
    """root points (and skin normals) scattered over the scalp, sparser at the hairline"""
    a, b, c = body[tris[:, 0]], body[tris[:, 1]], body[tris[:, 2]]
    cen = (a + b + c) / 3
    w = head.scalp(cen, style.get("recede", 0.0), style.get("sideburns", True), style.get("ear")) * np.linalg.norm(np.cross(b - a, c - a), axis=1)
    # the part itself stays bare (sculpted hair keeps its roots: the part is a groove, see build_figure.sculpt_hair)
    if (style["flow"] == "part" or style.get("part_line")) and not style.get("sculpt"):
        y, az, _ = head.local(cen)
        xp = style["part"] * 5.5 * head.U
        on_top = smooth(3, 7, y) * (cen[:, 2] > head.C[2] - 3 * head.U)
        w *= 1 - 0.85 * on_top * (1 - smooth(0.05 * head.U, 0.22 * head.U, np.abs(cen[:, 0] - xp)))
    pick = rng.choice(len(tris), size=style["count"] * 5, p=w / w.sum())
    u, v = rng.random((2, len(pick)))
    flip = u + v > 1
    u[flip], v[flip] = 1 - u[flip], 1 - v[flip]
    p = a[pick] + u[:, None] * (b - a)[pick] + v[:, None] * (c - a)[pick]
    # thin to an even spread (blue noise) and the wanted count
    keep, r2 = [], (math.sqrt(w.sum() / style["count"]) * 0.42) ** 2
    grid = {}
    cell = math.sqrt(r2)
    for i, q in enumerate(p):
        key = tuple((q // cell).astype(int))
        if any(((p[j] - q) ** 2).sum() < r2 for dx in (-1, 0, 1) for dy in (-1, 0, 1) for dz in (-1, 0, 1)
               for j in grid.get((key[0] + dx, key[1] + dy, key[2] + dz), [])):
            continue
        grid.setdefault(key, []).append(i)
        keep.append(i)
        if len(keep) == style["count"]:
            break
    p = p[keep]
    _, n = head.depth(np, p)
    return p, n


def flow(np, head, p, n, style):
    """the comb direction at each root, in the skin's tangent plane"""
    U = head.U
    y = (p[:, 1] - head.eye[1]) / U
    X, Y, Z = np.eye(3)
    crown = head.C + np.array([0, 7.5 * U, -4.5 * U])
    radial = unit(np, p - crown)
    behind = smooth(-1.0 * U, -4.0 * U, p[:, 2] - crown[2])[:, None]
    side = np.sign(p[:, 0] - style["part"] * 5.5 * U + 1e-9)[:, None]
    if style["flow"] == "part":
        # away from the part and back over the temples; behind the crown, out from it
        front = side * X - 0.2 * Z
        v = front * (1 - behind) + (radial - 0.3 * Y) * behind
    elif style["flow"] == "back":
        top = smooth(2.0, 5.0, y)[:, None]
        # (straight back at the front hairline: the part opens into a notch there if the sides sweep apart)
        sweep = style.get("sweep", 0.3) * (1 - 0.7 * smooth(4.5 * U, 7.5 * U, p[:, 2] - head.C[2]))[:, None]
        front = top * (-Z + sweep * side * X) + (1 - top) * (-style.get("side_down", 1.0) * Y - 0.6 * Z)
        v = front * (1 - behind) + (radial - 0.8 * Y) * behind
    elif style["flow"] == "random":
        v = np.random.default_rng(1).normal(size=p.shape)
    else:  # fringe: forward from the crown, down at the sides and back
        v = unit(np, p - (crown - U * Z)) - 0.3 * Y - style.get("sweep", 0.0) * np.sign(style["part"]) * smooth(0, 3 * U, p[:, 2] - head.C[2])[:, None] * X
    # tousled: each root combed a little its own way
    v = unit(np, v) + style.get("tousle", 0.0) * np.random.default_rng(2).normal(size=p.shape)
    if style.get("swirl"):
        # neighbouring roots turned together: soft clumps and grooves
        g = np.random.default_rng(4)
        for _ in range(6):
            k = unit(np, g.normal(size=3)) * 2 * np.pi / (g.uniform(3, 6) * U)
            v = v + style["swirl"] * g.normal(size=3) / 2.4 * np.sin(p @ k + g.uniform(0, 6.3))[:, None]
    v = v - (v * n).sum(1, keepdims=True) * n
    return unit(np, v)


def grow(np, rng, head, p0, n0, style):
    """strand polylines (strands × rows+1 × 3), their lengths (cm), layer (0 inner … 1 outer)"""
    U = head.U
    S = len(p0)
    rows = style["rows"]
    y0, az0, _ = head.local(p0)
    t = flow(np, head, p0, n0, style)
    # a lifted front (quiff) on brushed-back cuts
    fore = smooth(3, 7, (p0[:, 2] - head.C[2]) / U)
    if style["flow"] == "back":
        lift = style["lift"] * (1 + 1.2 * fore)
    elif style["flow"] == "part":
        # hair by the part rises a little before it falls away (it hides the part's front)
        lift = style["lift"] * (1 + 1.0 * fore * (1 - smooth(0.3 * U, 2.0 * U, np.abs(p0[:, 0] - style["part"] * 5.5 * U))))
    else:
        lift = np.full(S, style["lift"])
    t = unit(np, t + lift[:, None] * n0 * (0.6 + 0.8 * rng.random((S, 1))))
    # higher roots lie on top
    scalp_h = np.clip((y0 + 9) / 20, 0, 1)
    layer = np.clip(0.75 * scalp_h + 0.25 * rng.random(S), 0, 1)
    if "lengths" in style:
        top, crown, side, nape = style["lengths"]
        front = smooth(-3, 4, (p0[:, 2] - head.C[2]) / U)
        up = smooth(1.0, 6.5, y0)
        length = up * (crown + (top - crown) * front) + (1 - up) * (side + (nape - side) * smooth(100, 160, np.abs(az0)))
        length *= 0.85 + 0.3 * rng.random(S)
        cut = None
    else:
        length = np.full(S, float(style["max_len"]))
        # shoulder-length: tips end near one level below the chin (cm below the eyes), a little shorter on the top layer
        cut = -(11.5 + style["cut"]) + rng.normal(0, style.get("cut_jitter", 0.7), S)
    ds = 0.3
    steps = int(max(length.max(), 1) / ds) + 1
    # each card starts a little behind its root, tucked under its neighbours (no bare seams, a tight part)
    tuck = 0.35
    if style["flow"] == "part":
        tuck = 0.35 + 0.6 * (1 - smooth(0.3 * U, 1.5 * U, np.abs(p0[:, 0] - style["part"] * 5.5 * U)))[:, None]
    # (not out over the hairline onto bare skin)
    tuck = tuck * head.scalp(p0 - 0.8 * U * t, style.get("recede", 0.0), ear=style.get("ear"))[:, None]
    path = [p0 - 0.1 * U * n0 - tuck * U * t]
    p = p0.copy()
    s = np.zeros(S)
    alive = np.ones(S, bool)
    phase = rng.random(S) * 2 * np.pi
    for k in range(steps):
        g = style["gravity"] * smooth(0, style["stiff"], s)
        t = unit(np, t + (g * ds)[:, None] * np.array([0.0, -1.0, 0.0]))
        step = np.where(alive, ds * U, 0.0)
        p = p + t * step[:, None]
        s = s + np.where(alive, ds, 0)
        dep, n = head.depth(np, p)
        off = U * (style["base"] + style["volume"] * layer * smooth(0.0, 5.0, s))
        push = np.clip(off - dep, 0, None)
        # hair lies along the head: a strand just off its layer is drawn back onto it (not one hanging free)
        # (long hair only over the skull: below its widest part it falls free)
        yl = (p[:, 1] - head.eye[1]) / U
        hug = style["hug"] * (smooth(-3.5, -0.5, yl) if "cut" in style else 1 - style.get("top_loose", 0) * smooth(3, 7, y0))
        pull = np.where((dep > off) & (dep < off + style["hug_reach"] * U), (dep - off) * hug, 0)
        p = p + n * (push - pull)[:, None]
        hit = push > 0
        inward = np.minimum((t * n).sum(1), 0)
        t = unit(np, t - (hit * inward)[:, None] * n)
        if style.get("face"):
            p, t = keep_off_face(np, head, p, t, style["face"])
        yl = (p[:, 1] - head.eye[1]) / U
        alive &= s < length
        if cut is not None:
            alive &= yl > cut
            # ends that reach the shoulders rest there (not pushed along them, forward or up); ends turned forward
            # round the jaw by the skin stop at it (a hem that hooks forward under the ears)
            alive &= ~((yl < -12) & (t[:, 1] > -0.35))
            alive &= ~((yl < -6) & hit & (t[:, 2] > 0.35))
        path.append(p.copy())
        if not alive.any():
            break
    path = np.stack(path, 1)  # S × K × 3
    # resample each strand to rows+1 points evenly along its length
    seg = np.linalg.norm(np.diff(path, axis=1), axis=2)
    cum = np.concatenate([np.zeros((S, 1)), np.cumsum(seg, 1)], 1)
    total = cum[:, -1]
    out = np.empty((S, rows + 1, 3))
    for i in range(S):
        want = np.linspace(0, total[i], rows + 1)
        for d in range(3):
            out[i, :, d] = np.interp(want, cum[i], path[i, :, d])
    # soft waves across the strand and ends turning under toward the neck
    if style.get("wave"):
        f = np.linspace(0, 1, rows + 1)[None]
        side = unit(np, np.cross(np.gradient(out, axis=1), out - head.C))
        amp = style["wave"] * U * smooth(0.15, 0.6, f)
        wl = style.get("wave_len", 9)
        if style.get("curl"):
            # every curl its own size and pitch (no rows of identical coils)
            crng = np.random.default_rng(11)
            amp = amp * (0.55 + 0.9 * crng.random((len(out), 1)))
            wl = wl * (0.7 + 0.6 * crng.random((len(out), 1)))
        a = 2 * np.pi * f * total[:, None] / U / wl + phase[:, None]
        out += side * (amp * np.sin(a))[..., None]
        if style.get("curl"):
            out += unit(np, np.cross(side, np.gradient(out, axis=1))) * (amp * np.cos(a))[..., None]
    if style.get("tuck"):
        f = np.linspace(0, 1, rows + 1)[None]
        axis = head.C + np.array([0, -14 * U, -1.0 * U])
        inward = out - axis
        inward[..., 1] = 0
        out -= unit(np, inward) * (style["tuck"] * U * smooth(0.7, 1.0, f) * (total[:, None] / U > 8))[..., None]
    return out, total / U, layer


def keep_off_face(np, head, p, t, margin):
    """strands steer around the face (a zone narrowing over the forehead, so there's no ledge)"""
    U = head.U
    yl = (p[:, 1] - head.eye[1]) / U
    front = smooth(0.5 * U, 2.5 * U, p[:, 2] - head.C[2])
    w = (np.array([head.face_w.get(int(math.floor(y)), 0) for y in yl]) + margin * U) * smooth(4.0, 0.5, yl) * (yl > -16)
    over = np.clip(w - np.abs(p[:, 0]), 0, None) * front
    sgn = np.sign(p[:, 0] + 1e-9)
    p[:, 0] += sgn * over * 0.6
    t[:, 0] += sgn * np.clip(over / U, 0, 1) * 0.8
    return p, unit(np, t)


def cards(np, rng, head, strands, lengths, layer, edge, style):
    """strand polylines → card mesh: positions, uv, triangle index (inner cards first)"""
    S, R, _ = strands.shape
    U = head.U
    tan = np.gradient(strands, axis=1)
    tan = unit(np, tan)
    out = strands - head.C
    out[..., 1] = np.minimum(out[..., 1], 0) * 0.35 + np.maximum(out[..., 1], 0)
    side = unit(np, np.cross(tan, unit(np, out)))
    # a little twist per card
    twist = rng.normal(0, 0.25, (S, 1, 1))
    side = unit(np, side + twist * unit(np, out))
    f = np.linspace(0, 1, R)[None, :, None]
    # narrow cards along the hairline (fine wisps, not a row of blunt card ends)
    w = style["width"] * U * (0.8 + 0.5 * rng.random((S, 1, 1))) * (0.75 + 0.45 * f) * (1 - 0.55 * edge)[:, None, None]
    pos = np.stack([strands - side * w / 2, strands + side * w / 2], 2).reshape(S, R * 2, 3)
    level = np.clip(((1 - layer) * LEVELS).astype(int), 0, LEVELS - 1)
    # (hairline cards take the sparse, wispier strips)
    kind = np.where(edge > 0.5, 0, KINDS.index(style.get("kind", "sparse")))
    strip = kind * LEVELS * VARIANTS + level * VARIANTS + rng.integers(0, VARIANTS, S)
    pad = 3 / TEX_W
    u0, u1 = strip / (STRIPS + 1) + pad, (strip + 1) / (STRIPS + 1) - pad
    v = np.linspace(0.995, 0.005, R)
    uv = np.empty((S, R, 2, 2))
    uv[:, :, 0, 0], uv[:, :, 1, 0] = u0[:, None], u1[:, None]
    uv[:, :, :, 1] = v[None, :, None]
    q = np.arange(R - 1)[None] * 2 + (np.arange(S) * R * 2)[:, None]
    tri = np.stack([q, q + 1, q + 2, q + 1, q + 3, q + 2], -1).reshape(S, -1)
    order = np.argsort(layer, kind="stable")
    return pos.reshape(-1, 3), uv.reshape(-1, 2).astype(np.float32), tri[order].reshape(-1).astype(np.uint32)


def strays(np, head, strands, curl=False):
    """strands that kink back on themselves (curls may) or end up across the face"""
    seg = unit(np, np.diff(strands, axis=1))
    kinked = ((seg[:, 1:] * seg[:, :-1]).sum(-1) < 0.2).any(1) & (not curl)
    U = head.U
    yl = (strands[..., 1] - head.eye[1]) / U
    w = np.vectorize(lambda y: head.face_w.get(int(math.floor(y)), 0))(yl)
    on_face = ((strands[..., 2] > head.C[2] + 3.5 * U) & (yl < 1) & (yl > -14) & (np.abs(strands[..., 0]) < 0.9 * w)).any(1)
    # hair from the back that wraps round the neck to the front, or lies along the jaw
    wrapped = (strands[:, 0, 2] < head.C[2] - 2 * U) & (strands[:, -1, 2] > head.C[2] + 0.5 * U)
    dep = head.depth(np, strands.reshape(-1, 3))[0].reshape(strands.shape[:2]) / U
    on_jaw = ((yl < -3) & (dep < 0.6) & (strands[..., 2] > head.C[2] + 0.5 * U)).sum(1) >= 3
    return kinked | on_face | wrapped | on_jaw


def shell(np, head, body, tris, style):
    """the scalp's triangles (well inside the hairline), pushed out along the skin normal into the hair"""
    w = head.scalp(body, style.get("recede", 0.0) + 0.6, False)
    if "lengths" not in style:
        # long, parted hair lies thick enough on its own (a shell would fill the part)
        w = w * 0
    keep = tris[(w[tris] > 0.5).all(1)]
    used = np.unique(keep)
    remap = np.full(len(body), -1)
    remap[used] = np.arange(len(used))
    depth = head.U * (style["base"] + (0.55 if "lengths" in style else 0.3) * style["volume"]) * np.clip(w[used] * 2 - 1, 0.05, 1)
    return body[used] + head.normals[used] * depth[:, None], remap[keep]


def grown(np, rng, style, body, eyes, tris):
    """the style's strands on this figure: head, strands, lengths, layer, hairline edge"""
    head = Head(np, body, eyes, tris)
    p0, n0 = roots(np, rng, head, body, tris, style)
    strands, lengths, layer = grow(np, rng, head, p0, n0, style)
    # roots at the hairline: bare skin just behind them, against their comb direction
    edge = 1 - head.scalp(strands[:, 1] - 0.8 * head.U * unit(np, strands[:, 2] - strands[:, 1]), style.get("recede", 0.0), ear=style.get("ear"))
    keep = ~strays(np, head, strands, style.get("curl", False))
    return head, strands[keep], lengths[keep], layer[keep], edge[keep]


def bangs(np, rng, head, cfg):
    """side-swept bangs: strands from the front hairline curving across the forehead to the far temple,
    lying just off the skin, their ends above the brows"""
    U = head.U
    n, part = cfg["count"], cfg["part"]
    out = []
    for k in range(n):
        f = k / max(n - 1, 1)
        # roots along the front hairline on the part's side, ends spread over the other temple
        x0 = (part + (-0.2 - part) * f * 0.8) * 5.5 * U
        start = np.array([x0, head.eye[1] + 7.4 * U, 0.0])
        end = np.array([-np.sign(part) * (2.0 + 4.5 * f) * U, head.eye[1] + (cfg.get("end", 2.4) + 1.2 * (1 - f)) * U + rng.normal(0, 0.12) * U, 0.0])
        t = np.linspace(0, 1, 14)[:, None]
        pts = start * (1 - t) + end * t
        # bowed up and out a little (a soft swoop), then laid on the forehead
        pts[:, 1] += (np.sin(np.pi * t[:, 0]) * 0.6 * U)
        pts[:, 2] = head.C[2] + 12 * U
        for _ in range(6):
            dep, nrm = head.depth(np, pts)
            pts = pts + nrm * (cfg["lift"] * U - dep)[:, None]
            pts[:, 2] = np.maximum(pts[:, 2], pts[:, 2])
        out.append(pts)
    return np.array(out)


def pigtails(np, rng, head, cfg):
    """two little bunches high behind the ears: strands out from a point on the scalp, falling in a soft curve"""
    U = head.U
    out = []
    for sx in (-1, 1):
        a = np.radians(cfg.get("az", 110)) * sx
        d = np.array([np.sin(a), 0.0, np.cos(a)])
        anchor = head.C + np.array([0, cfg.get("height", 3.0) * U - 2 * U, 0]) + 12 * U * d
        for _ in range(6):
            dep, nrm = head.depth(np, anchor[None])
            anchor = anchor - nrm[0] * dep[0]
        for _ in range(cfg["count"]):
            p = anchor + rng.normal(0, cfg.get("spread", 0.35) * U, 3)
            t = unit(np, nrm[0] + np.array([0, -0.2, -0.3]) + rng.normal(0, 0.12, 3))
            pts = [p]
            n = int(cfg["length"] / 0.3)
            for k in range(n):
                t = unit(np, t + np.array([0, -cfg.get("fall", 0.15), 0]) + rng.normal(0, 0.02, 3))
                pts.append(pts[-1] + t * 0.3 * U)
            out.append(np.array(pts))
    return out


class Sculpt:
    """a sculpted style (one solid mesh, RAW sculpt.<style>.npz) bound to its neutral figure like a Groom"""

    def __init__(self, np, style_name, body, eyes, tris, raw):
        head = Head(np, body, eyes, tris)
        got = np.load(raw / f"sculpt.{style_name}.npz")
        self.pos, tri = got["pos"].astype(np.float64), got["tri"].astype(np.uint32)
        # wrapped round the head: u by azimuth, v by height (the texture's streaks run down the hair)
        uv = self.uv(np, head, self.pos)
        n = len(self.pos)
        self.topo = dict(uv=uv, vmap=np.arange(n, dtype=np.uint32), index=tri.reshape(-1), poly=np.arange(len(tri), dtype=np.uint32))
        i, d = head.nearest(np, self.pos, k=6)
        w = 1 / (np.sqrt(d) + 0.5 * head.U) ** 2
        self.bind = (head.near[i], w / w.sum(1, keepdims=True))
        self.body0 = body
        self.shell_pos = np.zeros((0, 3))

    @staticmethod
    def uv(np, head, pos):
        # u by azimuth, mirrored at the back (no seam where it wraps); v down from the crown, so the texture's
        # streaks run down the hair on every side (by height they turn into rings over the top)
        _, az, _ = head.local(pos)
        q = pos - head.C - np.array([0, 4 * head.U, 0])
        down = np.degrees(np.arctan2(np.hypot(q[..., 0], q[..., 2]), q[..., 1]))
        return np.stack([np.abs(az) / 180, np.clip(down / 180, 0, 1)], 1).astype(np.float32)

    def follow(self, np, body):
        i, w = self.bind
        return self.pos + ((body - self.body0)[i] * w[..., None]).sum(1)


class Groom:
    """one style grown on one neutral figure; follow() carries it onto a variant of that figure"""

    def __init__(self, np, style_name, body, eyes, tris, seed=7):
        style = STYLES[style_name]
        rng = np.random.default_rng(seed)
        head, strands, lengths, layer, edge = grown(np, rng, style, body, eyes, tris)
        self.pos, uv, index = cards(np, rng, head, strands, lengths, layer, edge, style)
        n = len(self.pos)
        self.topo = dict(uv=uv, vmap=np.arange(n, dtype=np.uint32), index=index,
                         poly=(np.arange(len(index) // 3) // 2).astype(np.uint32))
        i, d = head.nearest(np, self.pos, k=6)
        w = 1 / (np.sqrt(d) + 0.5 * head.U) ** 2
        self.bind = (head.near[i], w / w.sum(1, keepdims=True))
        self.body0 = body
        # an opaque shell in the hair's colour under the cards, part way out through the hair: no light through the gaps
        # (its own piece: see-through cards don't hide what's behind them)
        sp, st = shell(np, head, body, tris, style)
        self.shell_pos = sp
        self.shell_topo = dict(uv=np.tile(np.array([[SHELL_U, 0.5]], np.float32), (len(sp), 1)),
                               vmap=np.arange(len(sp), dtype=np.uint32), index=st.reshape(-1).astype(np.uint32),
                               poly=np.arange(len(st), dtype=np.uint32))
        self.shell_bind = None
        if len(sp):
            i, d = head.nearest(np, sp, k=6)
            w = 1 / (np.sqrt(d) + 0.5 * head.U) ** 2
            self.shell_bind = (head.near[i], w / w.sum(1, keepdims=True))

    def follow(self, np, body):
        i, w = self.bind
        return self.pos + ((body - self.body0)[i] * w[..., None]).sum(1)

    def follow_shell(self, np, body):
        i, w = self.shell_bind
        return self.shell_pos + ((body - self.body0)[i] * w[..., None]).sum(1)


# ------------------------------------------------------------------ strand texture


def strand_texture(np, seed=3):
    """grey strands (root at the top) on see-through, in STRIPS columns; returns rgb (H×W×3, 0..1) and alpha (H×W).
    Strands are laid over each other (the last on top), grouped in a few locks per strip that drift together."""
    rng = np.random.default_rng(seed)
    ss = 2
    W, H = TEX_W * ss, TEX_H * ss
    sw = W // (STRIPS + 1)
    alpha = np.zeros((H, W), np.float32)
    col = np.zeros((H, W, 3), np.float32)
    for s in range(STRIPS):
        kind = KINDS[s // (LEVELS * VARIANTS)]
        dense = kind != "sparse"
        level = (s % (LEVELS * VARIANTS)) // VARIANTS
        shade = 1 - (0.5 if dense else 1.0) * (1 - LEVEL_SHADE[level])
        # shadowed hair turns warmer as well as darker
        warmth = np.array([1.0, 1 - 0.03 * level, 1 - 0.06 * level], np.float32)
        lo, hi = s * sw + 3 * ss, (s + 1) * sw - 3 * ss - 1
        sheen = rng.uniform(0.16, 0.3)
        locks = [(sw * rng.uniform(0.3, 0.7), rng.normal(0, 0.05), rng.normal(1.0, 0.06 if dense else 0.2)) for _ in range(4)]
        for _ in range({"sparse": 110, "dense": 190, "coil": 900}[kind]):
            cx, lock_drift, lock_tone = locks[rng.integers(len(locks))]
            # denser in the middle of the card
            x0 = s * sw + np.clip(cx + rng.normal(0, sw * 0.14), 2 * ss, sw - 2 * ss)
            # short hair fades in over a longer root (a soft hairline, not blunt card ends)
            start = H * abs(rng.normal(0.0, 0.08 if dense else 0.035))
            end = H * np.clip(rng.normal(0.95, 0.04), 0.6, 1.0)
            if kind == "coil":
                # tight coils: short springy lengths anywhere along the card
                start = H * rng.uniform(0, 0.8)
                end = start + H * rng.uniform(0.12, 0.3)
            if end - start < H * 0.08 or end > H:
                continue
            drift = (lock_drift + rng.normal(0, 0.02)) * sw / H
            amp, freq, ph = rng.random() * 1.5 * ss, rng.uniform(1.5, 4) * 2 * np.pi / H, rng.random() * 6.3
            if kind == "coil":
                amp, freq = rng.uniform(2.0, 3.5) * ss, 2 * np.pi / (rng.uniform(9, 16) * ss)
                x0 = s * sw + np.clip(cx + rng.normal(0, sw * 0.25), 2 * ss, sw - 2 * ss)
            rows = np.arange(int(start), int(end))
            f = (rows - start) / (end - start)
            x = x0 + drift * (rows - start) + amp * np.sin(freq * rows + ph)
            width = rng.uniform(0.5, 0.85) * ss * (1.6 if kind == "coil" else 1.0) * (1 - 0.6 * smooth(0.7, 1.0, f))
            op = rng.uniform(0.8, 1.0) * (1 - smooth(0.8, 1.0, f)) * smooth(0.0, 0.15 if dense else 0.05, f)
            bright = lock_tone * np.clip(rng.normal(1.0, 0.16), 0.6, 1.4)
            # darker roots, lighter tips, and a soft sheen band a little way down (the light across the crown)
            band = np.exp(-(((f - sheen - rng.normal(0, 0.03)) / 0.07) ** 2))
            tone = 0.7 * bright * shade * (0.75 + 0.25 * smooth(0.0, 0.3, f)) * (1 + 0.12 * smooth(0.5, 1.0, f)) * (1 + 0.22 * band)
            warm = rng.normal(0, 0.05)
            hue = np.array([1 + warm, 1.0, 1 - 1.4 * warm], np.float32) * warmth
            xi = np.floor(x).astype(int)
            for dx in range(-2, 3):
                xc = xi + dx
                a = op * np.clip(1 - np.abs(xc + 0.5 - x) / width, 0, 1)
                a = np.where((xc >= lo) & (xc <= hi), a, 0)[:, None]
                xc = np.clip(xc, lo, hi)
                col[rows, xc] = col[rows, xc] * (1 - a) + a * tone[:, None] * hue[None]
                alpha[rows, xc] = alpha[rows, xc] * (1 - a[:, 0]) + a[:, 0]
    # the shell strip: solid, the colour of the inner strands
    x0 = STRIPS * sw
    alpha[:, x0:] = 1
    solid = alpha[:, :x0] > 0.5
    col[:, x0:] = 0.8 * col[:, :x0][solid].mean(0)
    # downsample the supersampled image (colour weighted by coverage)
    a4 = alpha.reshape(TEX_H, ss, TEX_W, ss)
    rgb = (col.reshape(TEX_H, ss, TEX_W, ss, 3)).sum((1, 3)) / np.maximum(a4.sum((1, 3)), 1e-6)[..., None]
    del a4
    return np.clip(rgb, 0, 1), alpha.reshape(TEX_H, ss, TEX_W, ss).mean((1, 3))
