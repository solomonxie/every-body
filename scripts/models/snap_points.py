"""Put acupuncture points, meridian lines and reflex points onto the real skin (Resources/Models/figure.bin).

The WHO landmarks are cast onto the generated skin lofts first (scripts/acupuncture.py); this moves every site
onto the adult MakeHuman figure of each sex (face: the mean of the six heritages), keeping the same small lift.
Points travel along their own normal to the nearest skin crossing; line samples drop onto the nearest surface.
Idempotent. Run: venv/bin/python scripts/models/snap_points.py   (gen_body.py calls snap() too)
"""

import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
from build_figure import FIGURE, HERITAGES, read_figure  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
POINTS = ROOT / "Resources" / "Data" / "points.json"
POINT_LIFT, LINE_LIFT, REFLEX_LIFT = 0.0025 * 1.86, 0.0014 * 1.86, 0.02


class Skin:
    def __init__(self, positions, tris):
        self.p, self.t = positions, tris
        a, b, c = (positions[tris[:, k]] for k in range(3))
        self.a, self.e1, self.e2 = a, b - a, c - a
        fn = np.cross(self.e1, self.e2)
        vn = np.zeros_like(positions)
        for k in range(3):
            np.add.at(vn, tris[:, k], fn)
        self.vn = vn / np.maximum(np.linalg.norm(vn, axis=1, keepdims=True), 1e-12)
        self.arm = is_arm(positions)

    def ray(self, o, d, near=0.0):
        """the crossing of the line o + s·d closest to s = near: (point, normal)"""
        h = np.cross(d, self.e2)
        det = np.einsum("ij,ij->i", self.e1, h)
        ok = np.abs(det) > 1e-12
        inv = np.where(ok, 1 / np.where(ok, det, 1), 0)
        s_ = o - self.a
        u = np.einsum("ij,ij->i", s_, h) * inv
        q = np.cross(s_, self.e1)
        v = (q @ d) * inv
        s = np.einsum("ij,ij->i", self.e2, q) * inv
        hit = ok & (u >= 0) & (v >= 0) & (u + v <= 1)
        idx = np.nonzero(hit)[0]
        if not len(idx):
            return None
        i = idx[np.argmin(np.abs(s[idx] - near))]
        n = self.vn[self.t[i]].mean(0)
        return o + s[i] * d, n / np.linalg.norm(n)

    def nearest(self, q):
        """closest vertex on the same part (arm or not), then onto its tangent plane"""
        same = self.arm == is_arm(q[None])[0]
        d2 = np.where(same, ((self.p - q) ** 2).sum(1), np.inf)
        i = np.argmin(d2)
        n = self.vn[i]
        return q - n * np.dot(q - self.p[i], n), n


# the arm's axis (generated body, left): shoulder, elbow, wrist, finger tip
ARM = np.array([(0.344, 1.004, -0.056), (0.391, 0.446, -0.028), (0.441, -0.014, 0.008), (0.447, -0.345, 0.037)])


def is_arm(p):
    """points hanging with the arms (below the armpit, near the arm's axis): a hip sample must not snap to the wrist"""
    p = np.atleast_2d(p)
    q = np.stack([np.abs(p[:, 0]), p[:, 1], p[:, 2]], 1)
    best = np.full(len(p), np.inf)
    for a, b in zip(ARM, ARM[1:]):
        ab = b - a
        t = np.clip(((q - a) @ ab) / (ab @ ab), 0, 1)
        best = np.minimum(best, np.linalg.norm(q - (a + t[:, None] * ab), axis=1))
    return (best < 0.1) & (p[:, 1] < 0.95) | (q[:, 0] > 0.34)


def skins():
    header, block, piece = read_figure(np)
    vmap, index = piece("body")
    tris = np.unique(vmap[index], axis=0)
    out = {}
    for sex in ("male", "female"):
        bodies = [block(header["variants"][f"{sex}.adult.{h}"]["body"]) for h in HERITAGES]
        out[sex] = Skin(np.mean(bodies, 0), tris)
    return out


def snap_point(skin, q, d, lift):
    q, d = np.array(q, float), np.array(d, float)
    d /= np.linalg.norm(d)
    hit = skin.ray(q - d * 0.2, d, near=0.2)
    if hit is None or np.linalg.norm(hit[0] - q) > 0.12:
        hit = skin.nearest(q)
    p, n = hit
    if np.dot(n, d) < 0:
        n = -n
    return p + n * lift


def rnd(p):
    return [round(float(c), 4) for c in p]


def snap(points):
    if not FIGURE.exists():
        return points
    sk = skins()
    acu = points["acupuncture"]
    for p in acu["points"]:
        a = p["acu"]
        d = np.array(a["normal"], float)
        male = a["sites"]
        female = a.get("femaleSites") or male

        def side(q, d=d):
            return d * np.array([np.sign(q[0]) or 1, 1, 1]) if abs(q[0]) > 1e-6 else d
        a["sites"] = [rnd(snap_point(sk["male"], q, side(q), POINT_LIFT)) for q in male]
        a["femaleSites"] = [rnd(snap_point(sk["female"], q, side(q), POINT_LIFT)) for q in female]
        p["position"] = a["sites"][0]
    for m in acu["meridians"]:
        female = m.get("femalePieces") or m["pieces"]
        m["pieces"] = regroup([[rnd(line(sk["male"], q)) for q in path] for piece in m["pieces"] for path in piece])
        m["femalePieces"] = regroup([[rnd(line(sk["female"], q)) for q in path] for piece in female for path in piece])
    for key, sp in points.items():
        if key in ("acupuncture", "circulatory"):
            continue
        for p in sp["points"]:
            q = np.array(p["position"], float)
            p["position"] = rnd(line(sk["male"], q, REFLEX_LIFT))
    return points


def regroup(paths):
    """re-cut paths where the age region changes (acupuncture.region) and group them per region, as acupuncture.build"""
    sys.path.insert(0, str(ROOT / "scripts"))
    from acupuncture import region, split
    out = {}
    for path in paths:
        for reg, piece in split(path):
            # 2-sample stubs are only the overlap of an earlier cut
            if len(piece) > 2:
                key = reg if reg in ("head", "neck", "trunk") else f"{reg}-{'l' if piece[len(piece) // 2][0] >= 0 else 'r'}"
                out.setdefault(key, []).append(piece)
    return [out[k] for k in sorted(out)]


def line(skin, q, lift=LINE_LIFT):
    p, n = skin.nearest(np.array(q, float))
    return p + n * lift


if __name__ == "__main__":
    sys.path.insert(0, str(ROOT / "scripts"))
    from gen_body import write  # noqa: E402
    write(POINTS, snap(json.loads(POINTS.read_text())))
    print("snapped", POINTS)
