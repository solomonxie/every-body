"""Rig, poses and packing for the posture scenes (driven by build_postures.py; plain Python + numpy).

Scene coordinates: y up, +z front, +x = the figure's left, 1.86 units per metre, soles at y = -1.6.
Every bone carries a rigid transform per pose; a vertex moves with the weighted sum of its bones' transforms.
"""

import json
import math
import zlib
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
MODELS = ROOT / "Resources" / "Models"
OUT = MODELS / "postures"
RAW = ROOT / "build" / "postures"
TOOLS = ROOT / "tools"
M = 1.86
SOLE = -1.6

LUMBAR = ["L5", "L4", "L3", "L2", "L1"]
THORACIC = [f"T{i}" for i in range(12, 0, -1)]
CERVICAL = [f"C{i}" for i in range(7, 1, -1)]
SPINE = LUMBAR + THORACIC + CERVICAL  # bottom → top; C1 moves with C2
SIDES = ("l", "r")

# ------------------------------------------------------------------ inputs


def weights_file():
    import os
    for base in (Path(os.environ.get("EVERYBODY_TOOLS", TOOLS)), TOOLS, ROOT.parents[2] / "tools"):
        p = base / "blender-user/extensions/user_default/mpfb/data/rigs/standard/weights.default.json"
        if p.exists():
            return p
    raise FileNotFoundError("MPFB weights.default.json (EVERYBODY_TOOLS)")


class FigureFile:
    """the shipped figure.bin: variant positions, body topology and garments"""

    def __init__(self):
        raw = (MODELS / "figure.bin").read_bytes()
        n = int.from_bytes(raw[4:8], "little")
        self.header = json.loads(raw[12:12 + n])
        self.payload = zlib.decompress(raw[12 + n:], -15)

    def array(self, offset, count, dtype):
        return np.frombuffer(self.payload, dtype, count, offset)

    def block(self, i):
        b = self.header["blocks"][i]
        q = self.array(b["offset"], b["count"] * 3, np.int16).reshape(-1, 3).astype(np.float64)
        p = (q + 32767) * np.array(b["step"]) + np.array(b["lo"])
        return p + (self.block(b["ref"]) if b["ref"] is not None else 0)

    def pieces(self, variant):
        return {k: self.block(i) for k, i in self.header["variants"][variant].items()}

    def topology(self, piece):
        info = self.header["pieces"][piece]
        return dict(vmap=self.array(info["vmap"], info["render"], np.uint32),
                    uv=self.array(info["uv"], info["render"] * 2, np.uint16).reshape(-1, 2),
                    index=self.array(info["index"], info["triangles"] * 3, np.uint32).reshape(-1, 3))

    def binding(self, name):
        """a garment as points in body triangles: the app builds it on whatever body it's given"""
        g = self.header["garments"][name]
        abc = self.array(g["abc"], g["vertices"] * 3, np.uint32).reshape(-1, 3)
        w = self.array(g["w"], g["vertices"] * 2, np.float32).reshape(-1, 2)
        f = self.array(g["f"], g["vertices"], np.float32)
        offset = self.array(g["offset"], g["vertices"] * 3, np.float32) if "offset" in g else None
        return abc, w, f, self.array(g["index"], g["triangles"] * 3, np.uint32).reshape(-1, 3), g["lift"], g["color"], offset

    def shape(self, name):
        i = self.header.get("shapes", {}).get(name)
        return None if i is None else self.block(i)

    def garment(self, name, body, normals):
        """a garment on a (posed) body, as Figure.garment builds it"""
        g = self.header["garments"][name]
        abc = self.array(g["abc"], g["vertices"] * 3, np.uint32).reshape(-1, 3)
        w = self.array(g["w"], g["vertices"] * 2, np.float32).reshape(-1, 2).astype(np.float64)
        f = self.array(g["f"], g["vertices"], np.float32).astype(np.float64)
        wc = np.clip(1 - w[:, 0] - w[:, 1], 0, None)
        n = w[:, :1] * normals[abc[:, 0]] + w[:, 1:] * normals[abc[:, 1]] + wc[:, None] * normals[abc[:, 2]]
        n /= np.linalg.norm(n, axis=1, keepdims=True)
        edge = np.minimum(f / 0.01, 1)[:, None]
        p = w[:, :1] * body[abc[:, 0]] + w[:, 1:] * body[abc[:, 1]] + wc[:, None] * body[abc[:, 2]] + n * g["lift"] * (0.8 + 0.2 * edge)
        if "offset" in g:
            o = self.array(g["offset"], g["vertices"] * 3, np.float32).reshape(-1, 3)
            from build_figure import tri_frame
            t1, t2, nt = tri_frame(np, body[abc[:, 0]], body[abc[:, 1]], body[abc[:, 2]], n)
            moved = np.abs(o).sum(1) > 0
            base = w[:, :1] * body[abc[:, 0]] + w[:, 1:] * body[abc[:, 1]] + wc[:, None] * body[abc[:, 2]]
            p[moved] = (base + o[:, :1] * t1 + o[:, 1:2] * t2 + o[:, 2:] * nt)[moved]
        uv = np.stack([np.minimum(f / 0.025, 0.97), np.full(len(f), 0.5)], 1)
        return p, uv, self.array(g["index"], g["triangles"] * 3, np.uint32).reshape(-1, 3), g["color"]


def vertex_normals(p, topo):
    vm = topo["vmap"].astype(np.int64)
    t = vm[topo["index"].astype(np.int64)]
    f = np.cross(p[t[:, 1]] - p[t[:, 0]], p[t[:, 2]] - p[t[:, 0]])
    n = np.zeros_like(p)
    for k in range(3):
        np.add.at(n, t[:, k], f)
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)


def inner():
    """inner pieces in scene axes: {id: (positions, triangles)}"""
    z = np.load(RAW / "inner.npz")
    out = {}
    for k in z.files:
        if k.startswith("pos:"):
            p = z[k].astype(np.float64)
            out[k[4:]] = (np.stack([p[:, 0], p[:, 2], -p[:, 1]], 1), z["tri:" + k[4:]])
    return out


# ------------------------------------------------------------------ maths


def rot(axis, deg):
    a = np.asarray(axis, float)
    a = a / np.linalg.norm(a)
    t = math.radians(deg)
    k = np.array([[0, -a[2], a[1]], [a[2], 0, -a[0]], [-a[1], a[0], 0]])
    return np.eye(3) + math.sin(t) * k + (1 - math.cos(t)) * k @ k


def unit(v):
    v = np.asarray(v, float)
    return v / np.linalg.norm(v)


def frame(a, b):
    """orthonormal frame from a primary axis a and a secondary direction b"""
    a = unit(a)
    b = unit(np.asarray(b, float) - a * np.dot(b, a))
    return np.stack([a, b, np.cross(a, b)], 1)


def align(a0, b0, a1, b1):
    """rotation taking (a0, b0) onto (a1, b1)"""
    return frame(a1, b1) @ frame(a0, b0).T


def rigid(R, pivot_rest, pivot_posed):
    """4×4: rotate by R about the rest pivot, then carry it to the posed pivot"""
    T = np.eye(4)
    T[:3, :3] = R
    T[:3, 3] = np.asarray(pivot_posed) - R @ np.asarray(pivot_rest)
    return T


def apply(T, p):
    return np.asarray(p) @ T[:3, :3].T + T[:3, 3]


def signed_angle(u, v, axis):
    axis = unit(axis)
    u = u - axis * np.dot(u, axis)
    v = v - axis * np.dot(v, axis)
    return math.degrees(math.atan2(np.dot(np.cross(u, v), axis), np.dot(u, v)))


def two_bone(a, target, l1, l2, pole):
    """middle joint of a two-bone chain from a toward target, bending toward pole"""
    d = target - a
    dist = min(np.linalg.norm(d), (l1 + l2) * 0.999)
    d = unit(d)
    x = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
    h = math.sqrt(max(l1 * l1 - x * x, 0))
    p = unit(pole - d * np.dot(pole, d))
    return a + d * x + p * h, a + d * dist


# ------------------------------------------------------------------ rest joints


def sphere(p):
    A = np.c_[2 * p, np.ones(len(p))]
    c = np.linalg.lstsq(A, (p ** 2).sum(1), rcond=None)[0]
    return c[:3]


def joints(parts):
    """rest joint centres from the fitted skeleton"""
    P = lambda k: parts[k][0]
    J = {}
    for v in SPINE:
        J[v] = P(f"disc-{v}").mean(0)  # a vertebra turns about the disc below it
    c1 = P("vertebra-C1")
    J["head"] = np.array([0.0, c1[:, 1].max() - 0.004, c1[:, 2].mean() - 0.004])
    for s, sx in (("l", 1), ("r", -1)):
        f = P(f"femur-{s}")
        top = f[f[:, 1] > f[:, 1].max() - 0.07]
        J[f"hip-{s}"] = sphere(top[top[:, 0] * sx < np.percentile(top[:, 0] * sx, 40)])
        t = P(f"tibia-{s}")
        J[f"knee-{s}"] = np.array([J[f"hip-{s}"][0] * 0 + t[:, 0].mean(), t[:, 1].max() - 0.012, t[:, 2].mean()])
        ta = P(f"talus-{s}")
        J[f"ankle-{s}"] = np.array([ta[:, 0].mean(), ta[:, 1].max() - 0.02, ta[:, 2].mean()])
        h = P(f"humerus-{s}")
        J[f"shoulder-{s}"] = sphere(h[h[:, 1] > h[:, 1].max() - 0.05])
        lo = h[h[:, 1] < h[:, 1].min() + 0.03]
        J[f"elbow-{s}"] = lo.mean(0) + np.array([0, 0.012, 0])
        u, r = P(f"ulna-{s}"), P(f"radius-{s}")
        J[f"wrist-{s}"] = np.concatenate([u[u[:, 1] < u[:, 1].min() + 0.02], r[r[:, 1] < r[:, 1].min() + 0.02]]).mean(0)
        J[f"radial-head-{s}"] = r[r[:, 1] > r[:, 1].max() - 0.02].mean(0)
        J[f"ulnar-head-{s}"] = u[u[:, 1] < u[:, 1].min() + 0.02].mean(0)
        cl = P(f"clavicle-{s}")
        J[f"sc-{s}"] = cl[np.argsort(np.abs(cl[:, 0]))[:20]].mean(0)
        hb = P(f"hip-bone-{s}")
        J[f"ischium-{s}"] = hb[np.argsort(hb[:, 1])[:12]].mean(0)
        J[f"finger-{s}"] = P(f"phalanges-middle-{s}")[np.argmin(P(f"phalanges-middle-{s}")[:, 1])]
    J["ischium"] = (J["ischium-l"] + J["ischium-r"]) / 2
    return J


# ------------------------------------------------------------------ bones and skin weights

BONES = (["pelvis"] + SPINE + ["head"] + [f"{b}-{s}" for s in SIDES for b in
         ("clav", "uparm", "fore1", "fore2", "hand", "thigh", "shin", "foot", "ulna", "radius")])
BI = {b: i for i, b in enumerate(BONES)}

FACE = ("jaw", "eye", "levator", "oculi", "oris", "orbicularis", "risorius", "temporalis", "special", "tongue")


def mpfb_bone(name):
    """MakeHuman default-rig bone → our bone, or "spine" (spread along the vertebrae by height)"""
    side = name[-1].lower() if name[-2:] in (".L", ".R") else None
    base = name[:-2] if side else name
    if base == "head" or base.startswith(FACE):
        return "head"
    if base.startswith(("spine", "neck", "breast")):
        return "spine"
    if base in ("root", "pelvis"):
        return "pelvis"
    table = {"clavicle": "clav", "shoulder01": "clav", "upperarm01": "uparm", "upperarm02": "uparm",
             "lowerarm01": "fore1", "lowerarm02": "fore2", "upperleg01": "thigh", "upperleg02": "thigh",
             "lowerleg01": "shin", "lowerleg02": "shin"}
    if base in table:
        return f"{table[base]}-{side}"
    if base.startswith(("wrist", "metacarpal", "finger")):
        return f"hand-{side}"
    if base.startswith(("foot", "toe")):
        return f"foot-{side}"
    raise KeyError(name)


def spine_weights(y, J):
    """(n, len(BONES)) weights spreading a trunk vertex over pelvis → vertebrae → head by its height"""
    chain = ["pelvis"] + SPINE + ["head"]
    bounds = [J[v][1] for v in SPINE] + [J["head"][1]]
    centres = [bounds[0] - 0.04] + [(bounds[i] + bounds[i + 1]) / 2 for i in range(len(SPINE))] + [bounds[-1] + 0.03]
    w = np.zeros((len(y), len(BONES)))
    for i, b in enumerate(chain):
        lo = centres[i - 1] if i > 0 else -1e9
        hi = centres[i + 1] if i + 1 < len(chain) else 1e9
        c = centres[i]
        up = np.clip((y - lo) / (c - lo), 0, 1) if i > 0 else np.ones_like(y)
        down = np.clip((hi - y) / (hi - c), 0, 1) if i + 1 < len(chain) else np.ones_like(y)
        w[:, BI[b]] = np.where(y <= c, up, down)
    return w


# MakeHuman's body vertices (its weights file goes on to index helper geometry the figure doesn't keep)
BASE_VERTS = 13380


def skin_weights(n, J, pos, tris):
    """(n, len(BONES)) for the skin: MakeHuman's weights per base vertex; the chest's refined vertices (past the
    base mesh, see build_figure.refine_chest) take the average of their mesh neighbours' weights, spread inward
    (by distance alone, a chest vertex would pick up the arm's weights across the armpit)"""
    y = pos[:, 1]
    ws = json.loads(weights_file().read_text())["weights"]
    w = np.zeros((n, len(BONES)))
    trunk = np.zeros(n)
    for name, pairs in ws.items():
        if not pairs:
            continue
        b = mpfb_bone(name)
        idx = np.array([i for i, _ in pairs])
        val = np.array([v for _, v in pairs])
        keep = idx < min(n, BASE_VERTS)
        if b == "spine":
            np.add.at(trunk, idx[keep], val[keep])
        else:
            np.add.at(w[:, BI[b]], idx[keep], val[keep])
    w += trunk[:, None] * spine_weights(y, J)
    empty = w.sum(1) == 0
    if empty.any() and not empty.all():
        e = np.concatenate([tris[:, [0, 1]], tris[:, [1, 2]], tris[:, [2, 0]]]).astype(np.int64)
        e = np.concatenate([e, e[:, ::-1]])
        known = ~empty
        for _ in range(12):
            acc = np.zeros_like(w)
            cnt = np.zeros(n)
            good = known[e[:, 1]]
            np.add.at(acc, e[good, 0], w[e[good, 1]])
            np.add.at(cnt, e[good, 0], 1)
            fill = empty & (cnt > 0)
            w[fill] = acc[fill] / cnt[fill, None]
            known = known | fill
            empty = empty & ~fill
            if not empty.any():
                break
        # evened out over the refined vertices (the arm's and the trunk's weights meet at the armpit)
        new = np.arange(n) >= BASE_VERTS
        for _ in range(6):
            acc = np.zeros_like(w)
            cnt = np.zeros(n)
            np.add.at(acc, e[:, 0], w[e[:, 1]])
            np.add.at(cnt, e[:, 0], 1)
            w[new] = acc[new] / np.maximum(cnt[new], 1)[:, None]
    s = w.sum(1, keepdims=True)
    w[s[:, 0] == 0, BI["pelvis"]] = 1
    return w / np.maximum(w.sum(1, keepdims=True), 1e-9)


def inner_weights(pid, p, J):
    """(n, len(BONES)) for one inner piece"""
    n = len(p)
    w = np.zeros((n, len(BONES)))
    side = pid[-1] if pid[-2:] in ("-l", "-r") else None
    base = pid[:-2] if side else pid

    def one(b):
        w[:, BI[b]] = 1
        return w
    if base.startswith("vertebra-"):
        v = base.split("-")[1]
        return one("C2" if v == "C1" else v)
    if base.startswith("disc-"):
        lower = base.split("-")[1]
        upper = SPINE[SPINE.index(lower) + 1] if SPINE.index(lower) + 1 < len(SPINE) else "head"
        # thickness axis: the smallest spread of the disc
        c = p.mean(0)
        axis = np.linalg.svd(p - c, full_matrices=False)[2][2]
        axis *= np.sign(axis[1]) or 1
        h = (p - c) @ axis
        t = np.clip((h - h.min()) / max(h.max() - h.min(), 1e-6), 0, 1)
        t = t * t * (3 - 2 * t)
        w[:, BI[lower]] = 1 - t
        w[:, BI[upper]] = t
        # a vertebra's body sits on the disc below it: the disc's lower half follows the vertebra beneath
        below = SPINE[SPINE.index(lower) - 1] if SPINE.index(lower) > 0 else "pelvis"
        w[:, BI[below]] = w[:, BI[lower]]
        w[:, BI[lower]] = 0
        return w
    if base.startswith(("rib-", "costal-cartilage-")):
        return one(f"T{base.split('-')[-1]}")
    if base == "sternum":
        return one("T4")
    if base in ("sacrum", "coccyx", "hip-bone", "pubic-symphysis"):
        return one("pelvis")
    if base in ("hyoid",):
        return one("C3")
    if base in ("thyroid-cartilage",):
        return one("C5")
    if base in ("cricoid-cartilage",):
        return one("C6")
    if base in ("clavicle", "scapula"):
        return one(f"clav-{side}")
    if base == "humerus":
        return one(f"uparm-{side}")
    if base == "ulna":
        return one(f"ulna-{side}")
    if base == "radius":
        return one(f"radius-{side}")
    if base in ("carpals",) or base.startswith(("metacarpal", "phalanges", "thumb")):
        return one(f"hand-{side}")
    if base in ("femur", "patella"):
        return one(f"thigh-{side}")
    if base in ("tibia", "fibula", "meniscus-lateral", "meniscus-medial"):
        return one(f"shin-{side}")
    if base in ("talus", "calcaneus", "tarsals") or base.startswith(("metatarsal", "toe")):
        return one(f"foot-{side}")
    if base in ("erector-spinae", "transversospinales", "spinal-cord", "splenius", "levator-scapulae"):
        return spine_weights(p[:, 1], J)
    return one("head")  # skull, face, teeth, ossicles…


# ------------------------------------------------------------------ poses


def pose(spec, J):
    """bone → 4×4 world transform for one posture key"""
    T = {}
    X = (1, 0, 0)
    # pelvis rolls on the ischial tuberosities, which rest on the seat
    Rp = rot(X, -spec["pelvis_tilt"])
    # slumping, the hips slide forward on the seat
    seat = np.array(spec["seat_point"]) + np.array([0, 0, spec.get("slide", 0.0)])
    T["pelvis"] = rigid(Rp, J["ischium"], seat)
    R, prev = Rp, "pelvis"
    for v in SPINE:
        R = R @ rot(X, spec["flex"].get(v, 0.0))
        T[v] = rigid(R, J[v], apply(T[prev], J[v]))
        prev = v
    R = R @ rot(X, spec["flex"].get("head", 0.0))
    T["head"] = rigid(R, J["head"], apply(T["C2"], J["head"]))

    for s, sx in (("l", 1), ("r", -1)):
        # legs: hip over the seat, foot flat at a fixed spot on the floor
        hip = apply(T["pelvis"], J[f"hip-{s}"])
        ankle = np.array(spec["ankle"]) * np.array([sx, 1, 1])
        l1 = np.linalg.norm(J[f"knee-{s}"] - J[f"hip-{s}"])
        l2 = np.linalg.norm(J[f"ankle-{s}"] - J[f"knee-{s}"])
        knee, ankle = two_bone(hip, ankle, l1, l2, np.array([0.12 * sx, 0.6, 1.0]))
        th0, sh0 = J[f"knee-{s}"] - J[f"hip-{s}"], J[f"ankle-{s}"] - J[f"knee-{s}"]
        th1, sh1 = knee - hip, ankle - knee
        e1 = np.cross(th1, sh1)
        e0 = np.array([1.0, 0, 0])
        T[f"thigh-{s}"] = rigid(align(th0, e0, th1, e1), J[f"hip-{s}"], hip)
        T[f"shin-{s}"] = rigid(align(sh0, e0, sh1, e1), J[f"knee-{s}"], knee)
        T[f"foot-{s}"] = rigid(rot((0, 1, 0), spec.get("toe_out", 0) * sx), J[f"ankle-{s}"], ankle)

        # shoulder girdle: protraction (forward) and elevation about the sternoclavicular joint
        Rc = R_spine(T, "T2") @ rot((0, 1, 0), -spec.get("protract", 0) * sx) @ rot((0, 0, 1), spec.get("elevate", 0) * sx)
        T[f"clav-{s}"] = rigid(Rc, J[f"sc-{s}"], apply(T["T2"], J[f"sc-{s}"]))

        # arm: the hand rests on the thigh
        sh = apply(T[f"clav-{s}"], J[f"shoulder-{s}"])
        el0, wr0 = J[f"elbow-{s}"], J[f"wrist-{s}"]
        a0, f0 = el0 - J[f"shoulder-{s}"], wr0 - el0
        hand_at = apply(T[f"thigh-{s}"], J[f"hip-{s}"] + spec["hand_on_thigh"] * th0) + np.array([spec["hand_lift"][0] * sx, spec.get("hand_up", {}).get(s, spec["hand_lift"][1]), spec["hand_lift"][2]])
        elbow, wrist = two_bone(sh, hand_at, np.linalg.norm(a0), np.linalg.norm(f0), np.array([0.5 * sx, 0.0, -1.0]))
        a1, f1 = elbow - sh, wrist - elbow
        e0 = np.cross(a0, (0, 0, 1))
        e1 = np.cross(a1, f1)
        Ru = align(a0, e0, a1, e1)
        T[f"uparm-{s}"] = rigid(Ru, J[f"shoulder-{s}"], sh)
        Rf = align(f0, e0, f1, e1)
        T[f"ulna-{s}"] = rigid(Rf, el0, elbow)
        # pronation turns the radius (and hand) about the line from the radial head to the ulnar head
        palm0 = Rf @ np.array([0, 0, 1.0])
        axis = Rf @ unit(J[f"ulnar-head-{s}"] - J[f"radial-head-{s}"])
        phi = signed_angle(palm0, np.array(spec["palm"]) * np.array([sx, 1, 1]), axis)
        phi = sx * min(max(sx * phi, -20), spec.get("pronation_max", 150))
        pivot = apply(T[f"ulna-{s}"], J[f"ulnar-head-{s}"])

        def twisted(frac):
            Rt = rot(axis, phi * frac) @ Rf
            return rigid(Rt, J[f"ulnar-head-{s}"], pivot)
        T[f"radius-{s}"] = twisted(1.0)
        T[f"fore1-{s}"] = twisted(0.3)
        T[f"fore2-{s}"] = twisted(0.75)
        # the hand lies along the thigh: wrist bends it onto the thigh's surface
        Rh = rot(axis, phi) @ Rf
        wrist_p = apply(T[f"radius-{s}"], wr0)
        h0 = J[f"finger-{s}"] - wr0
        h_now = Rh @ h0
        down = unit(np.array(spec["palm"]) * np.array([sx, 1, 1]))
        # fingers point along the thigh toward the knee, turned slightly inward
        along = rot(down, spec.get("finger_in", 0.0) * sx) @ unit(th1 - down * np.dot(th1, down))
        h_flat = along * np.linalg.norm(h_now - down * np.dot(h_now, down)) + down * spec.get("finger_drop", 0.0) * np.linalg.norm(h_now)
        Rw = align(h_now, Rh @ np.array([0, 0, 1.0]), h_flat, down)
        T[f"hand-{s}"] = rigid(Rw @ Rh, wr0, wrist_p)
    return T


def R_spine(T, v):
    return T[v][:3, :3]


def skin(p, w, T):
    """linear blend: p (n, 3) with weights w (n, bones)"""
    out = np.zeros_like(p)
    for b, i in BI.items():
        sel = w[:, i] > 0
        if sel.any() and b in T:
            out[sel] += apply(T[b], p[sel]) * w[sel, i:i + 1]
    return out


# ------------------------------------------------------------------ topics

# relative intradiscal pressure at L3 (standing = 100): Nachemson 1981
SITTING = {
    "seat_y": None,
    "keys": {
        # sitting tall: pelvis upright on the sit bones, a gentle lumbar curve kept
        "upright": dict(pelvis_tilt=8, flex={"L5": 3, "L4": 3, "L3": 2, "L2": 1, "L1": 1, "T10": 1, "T8": 1, "T6": 1, "T3": 1,
                                          "C6": 1, "C3": -1, "head": 5},
                        slide=0, protract=0, elevate=0, hand_on_thigh=0.62),
        # slumped forward: pelvis rolled back, lumbar curve flattened into a C, rounded upper back, head poked forward
        "slouched": dict(pelvis_tilt=26, flex={"L5": 7, "L4": 9, "L3": 9, "L2": 8, "L1": 6, "T12": 3, "T11": 2, "T10": 2, "T9": 2,
                                           "T8": 2, "T7": 2, "T6": 2, "T5": 2, "T4": 2, "T3": 2, "T2": 2, "T1": 2,
                                           "C7": 5, "C6": 4, "C5": 0, "C4": -3, "C3": -6, "C2": -8, "head": -14},
                         slide=0.1, protract=14, elevate=-2, hand_on_thigh=0.9),
    },
}


def seated_common(J):
    """seat and feet shared by every sitting key (so the chair and floor stay put)"""
    hip = J["hip-l"]
    ankle_y = J["ankle-l"][1]
    shin = np.linalg.norm(J["ankle-l"] - J["knee-l"])
    thigh = np.linalg.norm(J["knee-l"] - J["hip-l"])
    knee_y = ankle_y + shin * 0.99
    hip_y = knee_y + 0.03
    seat_point = np.array([0.0, hip_y - (hip[1] - J["ischium"][1]), -0.02])
    ankle = np.array([hip[0] + 0.03, ankle_y, seat_point[2] + (hip[2] - J["ischium"][2]) + thigh * 0.98 + 0.06])
    return dict(seat_point=seat_point.tolist(), ankle=ankle.tolist(), toe_out=6, hand_on_thigh=0.62,
                hand_lift=[0.05, 0.085, 0.0], palm=[-0.35, -1.0, 0.0], finger_drop=0.15, finger_in=5)


def blend_spec(a, b, t):
    out = dict(a)
    for k, v in b.items():
        if isinstance(v, dict):
            out[k] = {j: (1 - t) * a[k].get(j, 0) + t * v.get(j, 0) for j in set(a[k]) | set(v)}
        elif isinstance(v, (int, float)):
            out[k] = (1 - t) * a.get(k, 0) + t * v
    return out


class Rest:
    """hand and forearm vertices, and a dense sampling of the legs they may rest on"""

    def __init__(self, W, topo):
        self.W, self.topo = W, topo
        self.arm = {s: np.where(sum(W[:, BI[f"{b}-{s}"]] for b in ("hand", "fore1", "fore2")) > 0.5)[0] for s in SIDES}
        leg = W[:, BI["pelvis"]] + sum(W[:, BI[f"{b}-{s}"]] for b in ("thigh", "shin") for s in SIDES)
        t = topo["vmap"].astype(np.int64)[topo["index"].astype(np.int64)]
        self.tris = t[(leg[t] > 0.5).all(1)]
        g = np.array([(i, j) for i in range(5) for j in range(5 - i)], float) / 4
        self.bary = np.c_[g, 1 - g.sum(1)] * 0.96 + 0.04 / 3

    def clearance(self, p):
        """per side: the smallest signed distance from hand/forearm to the leg surface"""
        from scipy.spatial import cKDTree
        n = vertex_normals(p, self.topo)
        q = np.einsum("sk,tkd->tsd", self.bary, p[self.tris]).reshape(-1, 3)
        m = np.einsum("sk,tkd->tsd", self.bary, n[self.tris]).reshape(-1, 3)
        tree = cKDTree(q)
        out = {}
        for s in SIDES:
            a = p[self.arm[s]]
            d, i = tree.query(a)
            near = d < 0.06
            out[s] = float(((a - q[i]) * m[i]).sum(1)[near].min()) if near.any() else 0.06
        return out


def rest_hands(spec, J, bodies, rest, gap=0.006):
    """lift or lower each hand so it lies on the thigh, just clear of it on every body given"""
    spec = dict(spec, hand_up={s: spec["hand_lift"][1] for s in SIDES})
    for _ in range(8):
        T = pose(spec, J)
        c = {s: min(rest.clearance(skin(b, rest.W, T))[s] for b in bodies) for s in SIDES}
        spec["hand_up"] = {s: spec["hand_up"][s] + gap - c[s] for s in SIDES}
        if all(abs(gap - c[s]) < 0.001 for s in SIDES):
            break
    return spec


# ------------------------------------------------------------------ chair contact


def smax(a, b, k):
    return 0.5 * (a + b + np.sqrt((a - b) ** 2 + k * k))


def ramp(v, a, b):
    t = np.clip((v - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def chair_for(J, poses, body_posed, seat_point, pelvis_pts):
    """seat and backrest placed against the upright pose; the backrest starts above the pelvis in every pose"""
    T = poses[0]
    seat_y = seat_point[1] - 0.03
    knee_z = min(apply(T[f"shin-{s}"], J[f"knee-{s}"])[2] for s in SIDES)
    lumbar_y = apply(T["L3"], J["L3"])[1]
    near = body_posed[(np.abs(body_posed[:, 0]) < 0.06) & (np.abs(body_posed[:, 1] - lumbar_y) < 0.04)]
    back_z = near[:, 2].min()
    tilt = 12.0
    t = math.radians(tilt)
    up, n = np.array([0, math.cos(t), -math.sin(t)]), np.array([0, math.sin(t), math.cos(t)])
    lumbar = np.array([0, lumbar_y, back_z])
    # lowest start (along the back) clear of the sacrum and iliac crests
    start = (seat_y + 0.26 - lumbar_y) / math.cos(t)
    for P in poses:
        q = apply(P["pelvis"], pelvis_pts)
        close = (q - lumbar) @ n < 0.02
        if close.any():
            start = max(start, float(((q[close] - lumbar) @ up).max()) + 0.025)
    o = lumbar + up * start
    return dict(seat_y=float(seat_y), seat_front=float(knee_z - 0.13), seat_back=float(back_z - 0.08), seat_width=0.92,
                back_z=float(o[2]), back_y=float(o[1]), back_height=0.7, back_tilt=tilt, back_width=0.8)


def press(p, chair):
    """skin pressed flat where it meets the seat or the backrest"""
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    q = p.copy()
    inside = (1 - ramp(np.abs(x), chair["seat_width"] / 2 - 0.05, chair["seat_width"] / 2)) * \
        ramp(z, chair["seat_back"], chair["seat_back"] + 0.03) * (1 - ramp(z, chair["seat_front"], chair["seat_front"] + 0.04))
    q[:, 1] = y + inside * (smax(y, chair["seat_y"] + 0.004, 0.02) - y)
    t = math.radians(chair["back_tilt"])
    n = np.array([0, math.sin(t), math.cos(t)])
    o = np.array([0, chair["back_y"], chair["back_z"]])
    d = (q - o) @ n
    up = (q[:, 1] - chair["back_y"]) * math.cos(t) - (q[:, 2] - chair["back_z"]) * math.sin(t)
    band = ramp(up, -0.02, 0.03) * (1 - ramp(up, chair["back_height"] - 0.03, chair["back_height"])) * \
        (1 - ramp(np.abs(x), chair["back_width"] / 2 - 0.05, chair["back_width"] / 2))
    q += (band * (smax(d, 0.004, 0.02) - d))[:, None] * n
    return q


# ------------------------------------------------------------------ pack

# with a bump the trunk can't fold over the thighs: a pregnant slump sinks back into the chair instead
PREGNANT_SLUMP = dict(pelvis_tilt=28, slide=0.15, flex={"L5": 6, "L4": 7, "L3": 7, "L2": 6, "L1": 4, "T12": 1, "T11": 1, "T10": 1, "T9": 1,
                                                    "T8": 1, "T7": 1, "T6": 1.5, "T5": 1.5, "T4": 1.5, "T3": 2, "T2": 2, "T1": 2,
                                                    "C7": 7, "C6": 6, "C5": 2, "C4": -3, "C3": -6, "C2": -8, "head": -14},
                      hand_on_thigh=0.75)
TOPICS = {"sitting": dict(keys=SITTING["keys"], order=["upright", "slouched"], steps=[0.0, 0.5, 1.0], common=seated_common,
                          variants={"pregnant": {"slouched": PREGNANT_SLUMP}})}
SOFT = ("disc-", "erector-spinae", "transversospinales", "splenius", "levator-scapulae")
SEXES = {"male": "male.adult", "female": "female.adult", "pregnant": "female.pregnant"}
HERITAGES = ["southeast-asian", "south-asian", "hispanic", "white", "black"]
SHAPES = {"female": ["chest-small", "chest-medium", "chest-xlarge", "chest-xxlarge", "hips-small", "hips-large"],
          "pregnant": ["chest-small", "chest-medium", "chest-xlarge", "chest-xxlarge"]}
GARMENTS = {"male": ["briefs-male"], "female": ["briefs-female", "bra"], "pregnant": ["briefs-pregnant", "bra"]}


class Packer:
    def __init__(self):
        self.chunks, self.size, self.blocks = [], 0, []

    def add(self, arr):
        arr = np.ascontiguousarray(arr)
        pad = (-self.size) % 4
        if pad:
            self.chunks.append(b"\0" * pad)
            self.size += pad
        off = self.size
        self.chunks.append(arr.tobytes())
        self.size += arr.nbytes
        return off

    def block(self, pos, ref=None):
        """positions as int16 steps (from a reference block when given)"""
        d = pos - (self.decode(ref) if ref is not None else 0)
        step = np.maximum(np.abs(d).max(0) / 32000, 1.2e-4)
        lo = -32767 * step
        q = np.round((d - lo) / step - 32767).astype(np.int16)
        # stored as the change from the previous vertex (wrapping int16): neighbours are close, so it deflates well
        dq = np.diff(q.astype(np.int32), axis=0, prepend=np.zeros((1, 3), np.int32)).astype(np.int16)
        self.blocks.append({"ref": ref, "offset": self.add(dq), "count": len(pos), "lo": lo.tolist(), "step": step.tolist()})
        return len(self.blocks) - 1

    def decode(self, i):
        b = self.blocks[i]
        raw = b"".join(self.chunks)[b["offset"]:b["offset"] + b["count"] * 6]
        q = np.cumsum(np.frombuffer(raw, np.int16).reshape(-1, 3).astype(np.int64), axis=0)
        q = ((q + 32768) % 65536 - 32768).astype(np.float64)
        p = (q + 32767) * np.array(b["step"]) + np.array(b["lo"])
        return p + (self.decode(b["ref"]) if b["ref"] is not None else 0)


def pack(topics=None):
    OUT.mkdir(parents=True, exist_ok=True)
    fig = FigureFile()
    parts = inner()
    J = joints(parts)
    btopo = fig.topology("body")
    rest = {sex: fig.pieces(f"{v}.white") for sex, v in SEXES.items()}
    heritage = {sex: {h: fig.pieces(f"{v}.{h}")["body"] for h in HERITAGES} for sex, v in SEXES.items()}
    tris = btopo["vmap"][btopo["index"]]
    W = {sex: skin_weights(len(r["body"]), J, r["body"], tris) for sex, r in rest.items()}
    ids = sorted(parts)
    IW = {k: inner_weights(k, parts[k][0], J) for k in ids}
    # body options on the trunk and legs only: the rig poses the arms (a shape's own arm swing is dropped)
    shapes = {}
    for sex, r in rest.items():
        keep = 1 - sum(W[sex][:, BI[f"{b}-{s}"]] for b in ("uparm", "fore1", "fore2", "hand") for s in SIDES)[:, None]
        shapes[sex] = {k: keep * d for k in SHAPES.get(sex, []) if (d := fig.shape(k)) is not None}
    for name, topic in TOPICS.items():
        if topics and name not in topics:
            continue
        common = topic["common"](J)

        def posed_keys(sex):
            """this figure's keys, each hand resting on its thigh for every body option"""
            over = topic.get("variants", {}).get(sex, {})
            ka, kb = ({**topic["keys"][k], **over.get(k, {})} for k in topic["order"])
            r = rest[sex]["body"]
            bodies = [r] + [r + d for d in shapes[sex].values()]
            fit = Rest(W[sex], btopo)
            return [pose(rest_hands({**common, **blend_spec(ka, kb, t)}, J, bodies, fit), J) for t in topic["steps"]]
        poses = posed_keys("male")
        pelvis_pts = np.concatenate([parts[k][0] for k in ("sacrum", "coccyx", "hip-bone-l", "hip-bone-r")])
        chair = chair_for(J, poses, skin(rest["male"]["body"], W["male"], poses[0]), common["seat_point"], pelvis_pts)
        pk = Packer()
        header = {"keys": topic["order"], "steps": topic["steps"], "chair": chair, "sexes": {}, "body": {}, "inner": {}}
        header["body"] = {"vertices": len(rest["male"]["body"]), "render": len(btopo["vmap"]), "triangles": len(btopo["index"]),
                          "vmap": pk.add(btopo["vmap"].astype(np.uint16)), "uv": pk.add(btopo["uv"]),
                          "index": pk.add(btopo["index"].astype(np.uint16))}
        soft = [k for k in ids if k.startswith(SOFT)]
        header["rigid"] = {k: BONES[int(np.argmax(IW[k][0]))] for k in ids if k not in soft}
        pieces, start = [], 0
        for k in soft:
            n = len(parts[k][0])
            pieces.append({"id": k, "start": start, "count": n, "triangles": len(parts[k][1]), "index": pk.add(parts[k][1].astype(np.uint16))})
            start += n

        def inner_keys(ps):
            """bones: one transform per bone and key; soft pieces (discs, muscles): positions"""
            blocks = []
            for T in ps:
                p = np.concatenate([skin(parts[k][0], IW[k], T) for k in soft])
                blocks.append(pk.block(p, blocks[0] if blocks else None))
            return bone_keys(ps), blocks

        def bone_keys(ps):
            return [{b: T[b].T.reshape(-1).round(6).tolist() for b in BONES if b in T} for T in ps]

        def neck(ps):
            """forward lean of the C7 → skull-base line, relative to the first key (degrees)"""
            lean = [math.degrees(math.atan2(*(lambda v: (v[2], v[1]))(apply(T["head"], J["head"]) - apply(T["C7"], J["C7"])))) for T in ps]
            return [round(x - lean[0], 1) for x in lean]
        header["transforms"], blocks = inner_keys(poses)
        header["inner"] = {"count": start, "blocks": blocks, "pieces": pieces}
        header["neck"] = neck(poses)
        for sex, r in rest.items():
            entry = {"variant": f"{SEXES[sex]}.white", "body": [], "heritage": {}, "garments": []}
            mine = poses if sex == "male" else posed_keys(sex)
            if sex in topic.get("variants", {}):
                entry["transforms"], entry["inner"] = inner_keys(mine)
                entry["neck"] = neck(mine)
            elif sex != "male":
                entry["transforms"] = bone_keys(mine)
            posed = []
            for T in mine:
                p = press(skin(r["body"], W[sex], T), chair)
                posed.append(p)
                entry["body"].append(pk.block(p, entry["body"][0] if entry["body"] else None))
            for h in HERITAGES:
                d = heritage[sex][h] - r["body"]
                if np.abs(d).max() > 1e-6:
                    entry["heritage"][h] = pk.block(d)
            # adult female body options, posed: the change each makes to the posed body
            for shape, d in shapes[sex].items():
                keys = []
                for T, p in zip(mine, posed):
                    q = press(skin(r["body"] + d, W[sex], T), chair) - p
                    keys.append(pk.block(q, keys[0] if keys else None))
                entry.setdefault("shapes", {})[shape] = keys
            for g in GARMENTS[sex]:
                abc, w, f, tri, lift, color, offset = fig.binding(g)
                entry["garments"].append({"name": g, "color": color, "vertices": len(f), "triangles": len(tri), "lift": lift,
                                          "abc": pk.add(abc.astype(np.uint16)), "w": pk.add(w.astype(np.float32)),
                                          "f": pk.add(f.astype(np.float32)), "index": pk.add(tri.astype(np.uint16))})
                if offset is not None:
                    entry["garments"][-1]["offset"] = pk.add(offset)
            header["sexes"][sex] = entry
        header["blocks"] = pk.blocks
        # where the camera looks: the lumbar spine, per key
        header["focus"] = [[round(float(c), 4) for c in apply(T["L3"], J["L3"])] for T in poses]
        payload = b"".join(pk.chunks)
        comp = zlib.compressobj(9, zlib.DEFLATED, -15)
        data = comp.compress(payload) + comp.flush()
        head = json.dumps(header, separators=(",", ":")).encode()
        path = OUT / f"{name}.bin"
        path.write_bytes(b"EBP1" + len(head).to_bytes(4, "little") + len(payload).to_bytes(4, "little") + head + data)
        print(f"POSTURES {path.name}: {len(poses)} keys, payload {len(payload) // 1024} KB → {path.stat().st_size // 1024} KB")
