"""Figure faces: each group's MakeHuman face drawn onto a character head (base_head.py: Snow, Rain), its hair carried
along; optionally drawn toward photo-sample averages (face_landmarks.py → faces.npz, PLAN).

Faces are rendered (orthographic, front) and their landmarks (MediaPipe, 478) found on the render and located on the
mesh. The figure's landmarks go to the head's by a smooth warp (skin texture and features line up), then its skin is
drawn onto the head's surface, faded out down the neck and behind the ears.

  venv/bin/python scripts/models/face_fit.py [group]   # after `build_figure.py fit`, rewrites RAW <group>.*.npz
  venv/bin/python scripts/models/face_fit.py render <group> <variant> out.png
  venv/bin/python scripts/models/face_fit.py seat [group]   # only the mouth's lining seated behind the lips
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import face_landmarks as fl  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "build" / "models" / "figure"
OUT = ROOT / "Resources" / "Models"
SIZE = 900
HALF = 2.4  # half the view, in eye spacings
IRIS = np.arange(468, 478)


def load(name, fitted=False):
    """a figure as `build_figure.py fit` left it (kept in RAW/prefit on first use: this step can run again)"""
    f, keep = RAW / f"{name}.npz", RAW / "prefit" / f"{name}.npz"
    if not fitted:
        keep.parent.mkdir(exist_ok=True)
        if not keep.exists():
            keep.write_bytes(f.read_bytes())
        f = keep
    return {k[4:]: v.astype(np.float64) for k, v in np.load(f).items()}


def topo(name):
    t = np.load(RAW / f"topo.{name}.npz")
    return t["uv"], t["vmap"], t["index"].reshape(-1, 3)


def skin_for(gid, her):
    sex, age = gid.split("-")
    name = "kid" if sex == "kid" else f"{sex}-{'old' if age == 'senior' else 'young'}"
    return OUT / f"skin-{her if her != 'neutral' else 'white'}-{name}.jpg"


def frame(_, eyes):
    """the head's square in the image: centre, half size (scene units)"""
    c = eyes.mean(0)
    U = np.linalg.norm(eyes[eyes[:, 0] > 0].mean(0) - eyes[eyes[:, 0] < 0].mean(0))
    return np.array([c[0], c[1] - 0.7 * U]), HALF * U


def render(pieces, gid, her, yaw=0.0):
    """RGB image, per-pixel triangle id (-1 none) and barycentrics of the body, and the view's scale/centre"""
    layers = [(pieces["body"], topo("body"), skin_for(gid, her), True), (pieces["eyes"], topo("eyes"), OUT / "eyes.jpg", False)]
    return draw(layers, pieces["eyes"], yaw)


def draw(layers, eyes, yaw=0.0):
    """orthographic front view of layers (pos, (uv, vmap, tris), texture or None, tracked) framed on the eyes"""
    centre, half = frame(None, eyes)
    c = eyes.mean(0)
    R = np.array([[np.cos(yaw), 0, np.sin(yaw)], [0, 1, 0], [-np.sin(yaw), 0, np.cos(yaw)]])
    px = lambda p: np.stack([(p[:, 0] - centre[0]) / half * SIZE / 2 + SIZE / 2, (centre[1] - p[:, 1]) / half * SIZE / 2 + SIZE / 2], 1)
    img = np.full((SIZE, SIZE, 3), 0.85)
    depth = np.full((SIZE, SIZE), -np.inf)
    tid = np.full((SIZE, SIZE), -1)
    bary = np.zeros((SIZE, SIZE, 3))
    light = np.array([0.25, 0.35, 1.0])
    light /= np.linalg.norm(light)
    for pos, (uv, vmap, tris), tex_path, tracked in layers:
        p = (pos - c) @ R.T + c
        p = p[vmap] if vmap is not None else p
        flat = np.array(tex_path if isinstance(tex_path, tuple) else (0.82, 0.68, 0.6))
        tex = np.asarray(Image.open(tex_path).convert("RGB")).astype(np.float64) / 255 if isinstance(tex_path, Path) else None
        n = np.zeros_like(p)
        f = np.cross(p[tris[:, 1]] - p[tris[:, 0]], p[tris[:, 2]] - p[tris[:, 0]])
        for k in range(3):
            np.add.at(n, tris[:, k], f)
        n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)
        q = px(p)
        qt = q[tris]
        keep = (qt[:, :, 0].max(1) >= 0) & (qt[:, :, 0].min(1) < SIZE) & (qt[:, :, 1].max(1) >= 0) & (qt[:, :, 1].min(1) < SIZE)
        keep &= f[:, 2] > 0
        for ti in np.nonzero(keep)[0]:
            a, b, cc = q[tris[ti]]
            x0, x1 = int(max(np.floor(min(a[0], b[0], cc[0])), 0)), int(min(np.ceil(max(a[0], b[0], cc[0])), SIZE - 1))
            y0, y1 = int(max(np.floor(min(a[1], b[1], cc[1])), 0)), int(min(np.ceil(max(a[1], b[1], cc[1])), SIZE - 1))
            if x1 < x0 or y1 < y0:
                continue
            X, Y = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            det = (b[1] - cc[1]) * (a[0] - cc[0]) + (cc[0] - b[0]) * (a[1] - cc[1])
            if abs(det) < 1e-12:
                continue
            l0 = ((b[1] - cc[1]) * (X - cc[0]) + (cc[0] - b[0]) * (Y - cc[1])) / det
            l1 = ((cc[1] - a[1]) * (X - cc[0]) + (a[0] - cc[0]) * (Y - cc[1])) / det
            l2 = 1 - l0 - l1
            inside = (l0 >= -1e-6) & (l1 >= -1e-6) & (l2 >= -1e-6)
            if not inside.any():
                continue
            i3 = tris[ti]
            z = l0 * p[i3[0], 2] + l1 * p[i3[1], 2] + l2 * p[i3[2], 2]
            ys, xs = np.nonzero(inside)
            ys, xs = ys + y0, xs + x0
            zz = z[inside]
            closer = zz > depth[ys, xs]
            ys, xs, zz = ys[closer], xs[closer], zz[closer]
            L = np.stack([l0[inside][closer], l1[inside][closer], l2[inside][closer]], 1)
            depth[ys, xs] = zz
            if tex is not None:
                th, tw = tex.shape[:2]
                t_uv = L @ uv[i3]
                col = tex[np.clip(((1 - t_uv[:, 1]) * th).astype(int), 0, th - 1), np.clip((t_uv[:, 0] * tw).astype(int), 0, tw - 1)]
            else:
                col = flat
            nn = L @ n[i3]
            nn /= np.maximum(np.linalg.norm(nn, axis=1, keepdims=True), 1e-12)
            img[ys, xs] = col * (0.35 + 0.75 * np.clip(nn @ light, 0, 1))[:, None]
            tid[ys, xs] = ti if tracked else -1
            if tracked:
                bary[ys, xs] = L
    return (np.clip(img, 0, 1) * 255).astype(np.uint8), tid, bary, px


def sphere(c, r, n=16):
    th, ph = np.meshgrid(np.linspace(0, np.pi, n), np.linspace(0, 2 * np.pi, 2 * n))
    v = np.stack([np.sin(th) * np.cos(ph), np.cos(th), np.sin(th) * np.sin(ph)], -1).reshape(-1, 3) * r + c
    i = np.arange(2 * n * n).reshape(2 * n, n)
    a, b, cc, d = i[:-1, :-1].ravel(), i[1:, :-1].ravel(), i[1:, 1:].ravel(), i[:-1, 1:].ravel()
    t = np.concatenate([np.stack([a, b, cc], 1), np.stack([a, cc, d], 1)])
    return v, t


def base_layers(base):
    """a base head (base_head.extract) as layers, its eyes as white balls with dark irises"""
    layers = [(base["pos"], (None, None, base["tri"]), None, True)]
    r = float(base["eye_radius"])
    for c in base["eyes"]:
        for cc, rr, col in ((c, r, (0.9, 0.88, 0.85)), (c + np.array([0, 0, 0.55 * r]), 0.5 * r, (0.2, 0.12, 0.08))):
            v, t = sphere(cc, rr)
            fix = t[:, [0, 2, 1]]
            layers.append((v, (None, None, fix), col, False))
    return layers


def locate(lm, tid, bary):
    """image landmarks → (triangle, barycentrics) on the tracked mesh; one off it (on an eyeball) takes the nearest,
    none near: triangle -1"""
    xi = np.clip(lm[:, 0].astype(int), 0, SIZE - 1)
    yi = np.clip(lm[:, 1].astype(int), 0, SIZE - 1)
    t, b = tid[yi, xi].copy(), bary[yi, xi].copy()
    for i in np.nonzero(t < 0)[0]:
        y0, x0 = max(yi[i] - 40, 0), max(xi[i] - 40, 0)
        ys, xs = np.nonzero(tid[y0:yi[i] + 41, x0:xi[i] + 41] >= 0)
        if len(ys):
            k = np.argmin((ys + y0 - yi[i]) ** 2 + (xs + x0 - xi[i]) ** 2)
            t[i], b[i] = tid[ys[k] + y0, xs[k] + x0], bary[ys[k] + y0, xs[k] + x0]
    return t, b


def on_mesh(pieces, gid, her):
    """the render's landmarks: (478 image points, 478 mesh points (tri id, barycentrics), image)"""
    img, tid, bary, _ = render(pieces, gid, her)
    r = fl.detect(img)
    if r is None:
        raise RuntimeError(f"no face found on {gid}.{her}")
    t, b = locate(r[0], tid, bary)
    return fl.to_up(r[0]), t, b, img


# groups taking their faces from another head (base_head.py): (source head, how much of each heritage's own difference
# from the neutral face stays, how far toward the source head: adults keep some of their own maturity)
# how far each eye opening grows toward the source's, then its width and height: the lids cover the iris's top
EYE_GROW, EYE_SHAPE = 0.25, (1.0, 0.96, 1.0)
# (young children's eyes a little bigger)
EYE_GROW_BY = {"female-adult": 0.4, "kid-infant": 0.1, "kid-toddler": 0.6, "kid-child": 0.4}
# (young children's lids stay open)
EYE_SHAPE_BY = {"kid-infant": (1.0, 1.06, 1.0), "kid-toddler": (1.0, 1.05, 1.0), "kid-child": (1.0, 1.07, 1.0)}
# (a dict: per heritage, "*" the rest; the base head evens faces out, so some heritages keep more)
BASE = {"female-adult": ("rain", {"*": 0.5, "hispanic": 0.85, "southeast-asian": 0.9, "east-asian": 0.6, "south-asian": 0.85}, 0.7),
        "male-adult": ("snow", {"*": 0.5, "southeast-asian": 0.85, "south-asian": 0.85}, 0.85), "female-senior": ("rain", 0.5, 0.55),
        "male-senior": ("snow", 0.5, 0.65), "kid-child": ("rain", 0.5, 1.0), "kid-toddler": ("rain", 0.5, 0.5)}


def base_landmarks(source):
    """a base head (centred) and its landmarks on its surface"""
    base = dict(np.load(RAW / f"basehead-{source}.npz"))
    off = np.array([base["eyes"][:, 0].mean(), 0, 0])
    base["pos"], base["eyes"], base["off"] = base["pos"] - off, base["eyes"] - off, off
    img, tid, bary, _ = draw(base_layers(base), base["eyes"])
    r = fl.detect(img)
    if r is None:
        raise RuntimeError(f"no face found on the {source} base head")
    t, b = locate(r[0], tid, bary)
    return base, (base["pos"][base["tri"][t]] * b[:, :, None]).sum(1), t >= 0


def body_groups():
    """body vertex twins across the midline and the ears' mask (build_figure.fit_one), where a fit has left them"""
    f = RAW / "body-groups.npz"
    return dict(np.load(f)) if f.exists() else None


# how far below the chin (eye spacings) the base head's warp reaches
FACE_REACH = {"kid-toddler": 1.0, "kid-child": 1.4}
# round each eye, where the warp's own shape gives way to the base head's surface (eye spacings): a child drawn all the
# way onto Rain gets a wide blend, or Rain's deeper sockets print a shelf ringing the lower lid
KEEP_EYES = {"kid-child": (0.5, 1.2)}
# the landmarks round each eye (out to these radii, in eye-ring radii) move as its ring does: drawn to the source's
# bigger sockets while the ring grows less, the skin below the lid buckled into a groove (a line in low and 3/4 views)
EYE_SURROUND = {"female-adult": (1.3, 3.2)}
# the skin within these radii of each eyeball (in ball radii) moves with the ball
EYE_LINING = {"female-adult": (1.1, 1.45)}


def ball_sphere(ball):
    """an eyeball's centre and radius (fitted to its back, without the cornea's bulge)"""
    P = ball[ball[:, 2] < np.percentile(ball[:, 2], 60)]
    x = np.linalg.lstsq(np.c_[2 * P, np.ones(len(P))], (P ** 2).sum(1), rcond=None)[0]
    return x[:3], np.sqrt(x[3] + x[:3] @ x[:3])


def with_base_head(neutral, gid, source):
    """the neutral figure's face moved onto the base head: its landmarks onto the base's (texture and features line
    up), then its surface drawn onto the base's; returns the new pieces and the face weight per body vertex"""
    from scipy.spatial import cKDTree
    import base_head as bh
    uv, vmap, tris = topo("body")
    body = neutral["body"]
    _, t, b, _ = on_mesh(neutral, gid, "neutral")
    L = mesh_points(body, t, b, tris, vmap)
    base, Lb, found = base_landmarks(source)
    use = np.setdiff1d(np.arange(468), IRIS)
    use = use[found[use] & (t[use] >= 0)]
    s_, R_, T_ = fl.similarity(Lb[use], L[use])
    to = lambda q: q @ (s_ * R_).T + T_
    bpos, Lb, beyes = to(base["pos"]), to(Lb), to(base["eyes"])
    placed = dict(pos=bpos, to=(s_ * R_, T_), off=base["off"])
    brad = float(base["eye_radius"]) * s_
    eyes = neutral["eyes"]
    U = np.linalg.norm(eyes[eyes[:, 0] > 0].mean(0) - eyes[eyes[:, 0] < 0].mean(0))
    twin = np.argmin(np.linalg.norm(L[:, None] * np.array([-1, 1, 1]) - L[None], axis=2), axis=1)
    delta = Lb - L
    delta = (delta + delta[twin] * np.array([-1, 1, 1])) / 2
    # the source's eyes are cartoon-big: each eye opening grows only part of the way
    for ring in EYE_RING.values():
        a, b_ = L[ring], L[ring] + delta[ring]
        s0 = np.sqrt(((b_ - b_.mean(0)) ** 2).sum() / ((a - a.mean(0)) ** 2).sum())
        delta[ring] = b_.mean(0) + (a - a.mean(0)) * (1 + EYE_GROW_BY.get(gid, EYE_GROW) * (s0 - 1)) * np.array(EYE_SHAPE_BY.get(gid, EYE_SHAPE)) - a
    if gid in EYE_SURROUND:
        r0, r1 = EYE_SURROUND[gid]
        for ring in EYE_RING.values():
            a = L[ring]
            ac, rr = a.mean(0), np.sqrt(((a - a.mean(0)) ** 2).sum(1).mean())
            s = np.sqrt((((a + delta[ring]) - (a + delta[ring]).mean(0)) ** 2).sum() / ((a - ac) ** 2).sum())
            k = 1 - smoothstep(r0, r1, np.linalg.norm((L - ac) * np.array([1, 1.3, 1]), axis=1) / rr)
            k[ring] = 0
            delta += k[:, None] * ((a + delta[ring]).mean(0) + (L - ac) * s - L - delta)
    warp = smooth_warp(L[use], delta[use], 0.7 * U, 0.02)
    # the face: near the landmarks, in front of the ears, above the jaw's underside (a young child's chest sits
    # within reach of the chin's landmarks: the warp stops above it, or its edge prints a line across the collar)
    dist = cKDTree(L[use]).query(body)[0]
    face = 1 - smoothstep(0.3 * U, 1.5 * U, dist)
    face *= smoothstep(L[152, 1] - FACE_REACH.get(gid, 2.2) * U, L[152, 1] + 0.2 * U, body[:, 1])
    # the throat keeps its own line: the source's thinner neck would fold it under the chin
    throat = smoothstep(L[152, 1] - 0.9 * U, L[152, 1] - 0.15 * U, body[:, 1])
    moved = body + face[:, None] * (warp(body) - body)
    # the ears keep their own shape (the source's sit elsewhere: warped or pulled onto it they pinch and shear):
    # each moves as one piece with the skin at its base
    groups = body_groups()
    ears = np.zeros(len(body), bool)
    if groups is not None:
        ears = groups["ears"] > 0.5
        rim = (bh.smooth(np, ears.astype(float)[:, None], vmap[tris], len(body), 3)[:, 0] > 0.05) & ~ears
        for side in (1, -1):
            on = np.sign(body[:, 0]) == side
            moved[ears & on] = body[ears & on] + (moved - body)[rim & on].mean(0)
    bt = base["tri"]
    fn = np.cross(bpos[bt[:, 1]] - bpos[bt[:, 0]], bpos[bt[:, 2]] - bpos[bt[:, 0]])
    bn = np.zeros_like(bpos)
    for k in range(3):
        np.add.at(bn, bt[:, k], fn)
    bn /= np.maximum(np.linalg.norm(bn, axis=1, keepdims=True), 1e-12)
    tree = cKDTree(bpos)
    head = moved.copy()
    sel = face > 0.01
    # round the eyes the warp's shape stays (the source's own eye rims are cartoon-big)
    keep_eyes = np.ones(len(body))
    k0, k1 = KEEP_EYES.get(gid, (0.35, 0.6))
    for side in (1, -1):
        c = eyes[np.sign(eyes[:, 0]) == side].mean(0)
        keep_eyes *= smoothstep(k0 * U, k1 * U, np.linalg.norm(moved - c, axis=1))
    # the mouth's and nostrils' insides (well within the base head) stay where the warp put them
    _, i0 = tree.query(head)
    sel &= ((head - bpos[i0]) * bn[i0]).sum(1) > -0.06 * U
    sel &= ~ears
    for passes in (40, 15, 6, 2, 0):
        nrm = vertex_normals(head)
        _, i = tree.query(head[sel])
        d = np.zeros_like(head)
        # to the base's tangent plane at its nearest vertex
        d[sel] = -((head[sel] - bpos[i]) * bn[i]).sum(1, keepdims=True) * bn[i]
        ok = np.zeros(len(head), bool)
        ok[sel] = ((nrm[sel] * bn[i]).sum(1) > 0.4) & (np.linalg.norm(head[sel] - bpos[i], axis=1) < 0.3 * U)
        # (under the jaw, facing down, less and less: it'd fold where the source's jaw is smaller)
        w = ok[:, None] * smoothstep(-0.9, -0.2, nrm[:, 1])[:, None] * keep_eyes[:, None] * throat[:, None]
        pull = (bh.smooth(np, d * w, vmap[tris], len(body), passes) / np.maximum(bh.smooth(np, w, vmap[tris], len(body), passes), 1e-3)
                if passes else d * w)
        head = head + face[:, None] * pull
        # no vertex drawn further than a little from where the warp left it
        off = head - moved
        head = moved + off * np.minimum(1, 0.25 * U / np.maximum(np.linalg.norm(off, axis=1, keepdims=True), 1e-12))
    if groups is not None and gid in EAR_SKIN:
        head = ears_with_skin(body, head, ears, rim, U, vmap[tris], *EAR_SKIN[gid])
    if gid in EYE_LINING:
        # the skin hugging each eyeball (inner corner, lid linings) moves with it, as its lid rim does: warped, the
        # inner corner stood out in front of the ball and hid a third of it in 3/4 views
        r0, r1 = EYE_LINING[gid]
        for side, ring in EYE_RING.items():
            ball = eyes[np.sign(eyes[:, 0]) == side]
            c, R = ball_sphere(ball)
            a, b_ = L[ring], L[ring] + delta[ring]
            sc = np.clip(np.sqrt(((b_ - b_.mean(0)) ** 2).sum() / ((a - a.mean(0)) ** 2).sum()), 0.8, 1.8)
            k = (1 - smoothstep(r0 * R, r1 * R, np.linalg.norm(body - c, axis=1)))[:, None]
            head = head + k * ((body - a.mean(0)) * sc + b_.mean(0) - head)
    if groups is not None:
        # one face on both sides (the source head isn't quite mirrored)
        twin = groups["mirror"]
        paired = (twin != np.arange(len(body))) | (np.abs(body[:, 0]) < 1e-3 * U)
        paired &= np.abs(body[twin] * np.array([-1, 1, 1]) - body).max(1) < 0.1 * U
        head[paired] = (head[paired] + head[twin[paired]] * np.array([-1, 1, 1])) / 2
    out = dict(neutral, body=head)
    move = head - body
    # each eyeball with its lids: their mean move, their spread's scale
    ev = eyes.copy()
    for side, ring in EYE_RING.items():
        sel_e = np.sign(eyes[:, 0]) == side
        c = eyes[sel_e].mean(0)
        a, b_ = L[ring], L[ring] + delta[ring]
        sc = np.clip(np.sqrt(((b_ - b_.mean(0)) ** 2).sum() / ((a - a.mean(0)) ** 2).sum()), 0.8, 1.8)
        ev[sel_e] = (eyes[sel_e] - a.mean(0)) * sc + b_.mean(0)
    out["eyes"] = ev
    for k, v in neutral.items():
        if k not in ("body", "eyes"):
            i = np.argsort(np.linalg.norm(body[None, :, :] - v[:, None, :], axis=2), axis=1)[:, :4]
            out[k] = v + move[i].mean(1)
    # the chin's underside (facing down, below the lips): a variant's own difference there is carried evened out
    under = face * smoothstep(L[14, 1] - 0.3 * U, L[14, 1] - 0.5 * U, body[:, 1]) * smoothstep(-0.15, -0.5, vertex_normals(head)[:, 1])
    return out, face, placed, under


# groups whose ears turn with the skin round them once it lies on the base head (moved with their base's average,
# they lag the skin pulled forward in front of them: a crease runs from the lobe along the jaw), that skin easing
# between the two over this band (eye spacings from the ear)
EAR_SKIN = {"female-adult": (0.05, 0.3)}


def ears_with_skin(body, head, ears, rim, U, t, r0, r1, passes=400):
    """each ear moved rigidly as the skin at its base moved (best-fit turn and shift), the skin round it eased
    between the ear's move and its own (harmonic), fading out from r0 to r1"""
    from scipy.spatial import cKDTree
    out = head.copy()
    for side in (1, -1):
        on = np.sign(body[:, 0]) == side
        a, b = body[rim & on], head[rim & on]
        ca, cb = a.mean(0), b.mean(0)
        u, _, vt = np.linalg.svd((a - ca).T @ (b - cb))
        R = vt.T @ np.diag([1, 1, np.sign(np.linalg.det(vt.T @ u.T))]) @ u.T
        e = ears & on
        out[e] = (body[e] - ca) @ R.T + cb
    s = 1 - smoothstep(r0 * U, r1 * U, cKDTree(body[ears]).query(body)[0])
    near = (s > 0) & ~ears
    e = np.concatenate([t[:, [0, 1]], t[:, [1, 2]], t[:, [2, 0]]])
    cnt = np.maximum(np.bincount(e.ravel(), minlength=len(body)), 1).astype(float)[:, None]
    m = out - body
    h = m.copy()
    for _ in range(passes):
        acc = np.zeros_like(h)
        np.add.at(acc, e[:, 0], h[e[:, 1]])
        np.add.at(acc, e[:, 1], h[e[:, 0]])
        h[near] = (acc / cnt)[near]
    return body + m + (s * near)[:, None] * (h - m)


# a group's hair style taken from its source character (hair.CHARACTER_HAIR)
HAIR_OF = {}
# (source, hair mesh): how far it bends down from its root (radians; Rain's ponytail is posed straight back)
BEND = {("rain", 1): 1.25}


def bend(h, angle):
    """a hanging piece bent down from its root (its front-most point), more toward the tip"""
    root = h[np.argmax(h[:, 2])]
    v = h - root
    t = np.clip(-v[:, 2] / max(-v[:, 2].min(), 1e-9), 0, 1)
    a = angle * smoothstep(0.0, 0.5, t)
    y, z = v[:, 1], v[:, 2]
    return root + np.stack([v[:, 0], y * np.cos(a) + z * np.sin(a), -y * np.sin(a) + z * np.cos(a)], 1)


# (source, hair mesh) whose locks in front of the ears are folded up to the temple (Rain's hang to a point there)
TEMPLE = {("rain", 0)}


def fold_temples(h, eyes):
    e = eyes.mean(0)
    U = np.linalg.norm(eyes[eyes[:, 0] > 0].mean(0) - eyes[eyes[:, 0] < 0].mean(0))
    y0 = e[1] + 0.2 * U
    side = smoothstep(0.55 * U, 0.8 * U, np.abs(h[:, 0])) * smoothstep(e[2] - 1.6 * U, e[2] - 1.1 * U, h[:, 2])
    low = h[:, 1] < y0
    out = h.copy()
    out[low, 1] = y0 + (h[low, 1] - y0) * (1 - 0.7 * side[low])
    return out


def carry_hair(base, head_new, source, eyes):
    """the source character's hair meshes onto this head: each hair point moved as the source's scalp near it moved
    (source scalp → the nearest point of the new head)"""
    from scipy.spatial import cKDTree
    b0 = dict(np.load(RAW / f"basehead-{source}.npz"))
    pos, tri, sR, T = base["pos"], None, base["to"][0], base["to"][1]
    off = base["off"]
    moved = head_new[cKDTree(head_new).query(pos)[1]]
    # the source's scalp that's near the new head (not its face, where the fit already follows landmarks)
    tree = cKDTree(pos)
    out = []
    i = 0
    while f"hair{i}_pos" in b0:
        h = (b0[f"hair{i}_pos"] - off) @ sR.T + T
        d, j = tree.query(h, k=12)
        w = 1 / (d + 1e-4) ** 2
        w /= w.sum(1, keepdims=True)
        h = h + ((moved - pos)[j] * w[..., None]).sum(1)
        if (source, i) in BEND:
            h = bend(h, BEND[source, i])
        if (source, i) in TEMPLE:
            h = fold_temples(h, eyes)
        out.append((h, b0[f"hair{i}_tri"]))
        i += 1
    return out


# smoothing passes over a variant's difference under the chin (unsmoothed, it pinches into a fold on the base head's jaw)
UNDER_EVEN = 60


def base_variant(v, neutral, new_neutral, face, keep, under):
    """a variant on the base-headed neutral: its difference from the neutral kept at `keep` in the face"""
    import base_head as bh
    _, vmap, tris = topo("body")
    out = {}
    for k, x in v.items():
        n0, n1 = neutral.get(k), new_neutral.get(k)
        if n0 is None:
            out[k] = x
            continue
        f = face[:, None] if k == "body" else 1.0
        d = x - n0
        if k == "body":
            d = d + under[:, None] * (bh.smooth(np, d, vmap[tris], len(d), UNDER_EVEN) - d)
        out[k] = n1 + d * (1 - (1 - keep) * f)
    return out


# group: heritage → (sample group(s), strength); "*" is every other heritage (and the neutral figure): the mean of the
# listed heritages' moves, so each keeps its own difference
# (off with the stylized Snow/Rain heads: the samples' averages pull back toward real proportions)
PLAN = {}
# groups following another group's moves: (source group, strength)
FOLLOW = {}
PASSES = 3
# the detector pulls every face toward its own mean: moves are overdriven
GAIN = 1.3
SIGMA = 0.7
PASSES_REG = 0.3
EYE_RING = {1: [263, 249, 390, 373, 374, 380, 381, 382, 362, 398, 384, 385, 386, 387, 388, 466],
            -1: [33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246]}


def mesh_points(body, t, b, tris, vmap):
    return (body[vmap[tris[t]]] * b[:, :, None]).sum(1)


def smooth_warp(src, move, sigma, reg=0.1):
    """Gaussian RBF through the moves (smoothed by reg): bounded, fading to nothing a few sigma from the points"""
    K = np.exp(-(np.linalg.norm(src[:, None] - src[None], axis=2) / sigma) ** 2)
    w = np.linalg.solve(K + reg * np.eye(len(src)), move)

    def f(q):
        out = np.empty_like(q)
        for i in range(0, len(q), 4000):
            c = q[i:i + 4000]
            out[i:i + 4000] = c + np.exp(-(np.linalg.norm(c[:, None] - src[None], axis=2) / sigma) ** 2) @ w
        return out
    return f


def face_move(pieces, gid, her, avg, strength):
    """per-vertex move of the body (and the warp) taking this face toward avg"""
    uv, vmap, tris = topo("body")
    body = pieces["body"]
    R, t, b, _ = on_mesh(pieces, gid, her)
    L = mesh_points(body, t, b, tris, vmap)
    use = np.setdiff1d(np.arange(468), IRIS)
    R_al = fl.align(R, L)
    A_al = fl.align(avg, R_al)
    delta = strength * (A_al - R_al)
    # symmetric: each landmark's move averaged with its mirror twin's
    twin = np.argmin(np.linalg.norm(L[:, None] * np.array([-1, 1, 1]) - L[None], axis=2), axis=1)
    delta = (delta + delta[twin] * np.array([-1, 1, 1])) / 2
    eyes = pieces["eyes"]
    U = np.linalg.norm(eyes[eyes[:, 0] > 0].mean(0) - eyes[eyes[:, 0] < 0].mean(0))
    ec = eyes.mean(0)
    chin_y = L[152, 1]
    delta = GAIN * delta
    # each eye as one piece with its eyeball: moved, and scaled about the eyeball's centre as the opening widens
    eye_fit = {}
    for side, ring in EYE_RING.items():
        c = eyes[np.sign(eyes[:, 0]) == side].mean(0)
        sc = 1.0
        t_ = delta[ring].mean(0)
        delta[ring] = (L[ring] - c) * (sc - 1) + t_
        eye_fit[side] = c
    # the eye's own shape stays: landmarks round it (crease, under-eye) don't pull the lids open
    ring_all = np.concatenate(list(EYE_RING.values()))
    near_eye = np.zeros(len(L), bool)
    for side in EYE_RING:
        c = eyes[np.sign(eyes[:, 0]) == side].mean(0)
        near_eye |= np.linalg.norm(L - c, axis=1) < 0.45 * U
    near_eye[ring_all] = False
    use = use[~near_eye[use]]
    d = delta[use]
    d *= np.minimum(1, 0.3 * U / np.maximum(np.linalg.norm(d, axis=1, keepdims=True), 1e-12))
    warp = smooth_warp(L[use], d, SIGMA * U, PASSES_REG)
    near = body[:, 1] > chin_y - 2.5 * U
    move = np.zeros_like(body)
    move[near] = warp(body[near]) - body[near]
    # each eyeball as its lids actually moved (the warp is smoothed): their mean move, their spread's scale
    for side, ring in EYE_RING.items():
        a, b_ = L[ring], warp(L[ring])
        sx, sy = (np.ptp(b_[:, :2], 0) / np.ptp(a[:, :2], 0)).clip(0.95, 1.12)
        sc = np.array([sx, sy, (sx + sy) / 2])
        c = eye_fit[side]
        eye_fit[side] = (c, sc, b_.mean(0) - a.mean(0) + (a.mean(0) - c) * (1 - sc))
    return move, (warp, eye_fit), float(np.sqrt((delta[use] ** 2).sum(1).mean()) / U)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def carry(pieces, move, warp):
    """the other pieces follow the body's move: each eyeball rigidly (scaled with its surroundings), brows and lashes
    with the skin under them"""
    body = pieces["body"]
    out = dict(pieces, body=body + move)
    for k, v in pieces.items():
        if k == "body":
            continue
        if k == "eyes":
            out[k] = v.copy()
            for side in (1, -1):
                sel = np.sign(v[:, 0]) == side
                c = v[sel].mean(0)
                if isinstance(warp, tuple):
                    # each eyeball with its lids: moved as they move, scaled as the opening widens
                    ec, sc, t_ = warp[1][side]
                    out[k][sel] = (v[sel] - ec) * sc + ec + t_
                else:
                    out[k][sel] = v[sel] - c + warp(c[None])[0]
        else:
            i = np.argsort(np.linalg.norm(body[None, :, :] - v[:, None, :], axis=2), axis=1)[:, :4]
            out[k] = v + move[i].mean(1)
    return out


# brows flattened (the arch's middle lowered, in eye spacings) and lowered, by group
BROWS = {"female-adult.southeast-asian": (0.05, 0.0), "female-adult.east-asian": (0.03, 0.03)}
# brows thickened (scaled across their length about the middle line), by group or group.heritage
BROW_THICK = {"female-adult.east-asian": 1.05, "female-adult.hispanic": 1.15, "female-adult.southeast-asian": 1.1, "kid-toddler": 0.7, "kid-child": 0.8}


def thicken_brows(pieces, k, U):
    out = dict(pieces)
    for key in [key for key in pieces if key.startswith("brows-")]:
        v = pieces[key].copy()
        for side in (1, -1):
            sel = np.flatnonzero(np.sign(v[:, 0]) == side)
            x = v[sel, 0]
            near = np.abs(x[:, None] - x[None]) < 0.12 * U
            c = (near * v[sel, 1][None]).sum(1) / near.sum(1)
            v[sel, 1] = c + (v[sel, 1] - c) * k
        out[key] = v
    return out


def vertex_normals(p):
    _, vmap, tris = topo("body")
    t = vmap[tris]
    f = np.cross(p[t[:, 1]] - p[t[:, 0]], p[t[:, 2]] - p[t[:, 0]])
    n = np.zeros_like(p)
    for k in range(3):
        np.add.at(n, t[:, k], f)
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)


# brows' mean height above the eye centres (eye spacings): clear of the stylized heads' bigger eyes
BROW_RISE = 0.34


def seat_brows(pieces, arch, drop):
    """a softer, lower brow line, each brow vertex kept at its height over the skin"""
    body, eyes = pieces["body"], pieces["eyes"]
    U = np.linalg.norm(eyes[eyes[:, 0] > 0].mean(0) - eyes[eyes[:, 0] < 0].mean(0))
    out = dict(pieces)
    for k in [k for k in pieces if k.startswith("brows-")]:
        v = pieces[k].copy()
        for side in (1, -1):
            sel = np.sign(v[:, 0]) == side
            x = np.abs(v[sel, 0])
            t = (x - x.min()) / np.ptp(x)
            v[sel, 1] -= U * (drop + arch * np.sin(np.pi * np.clip(t, 0, 1)) ** 1.5)
        # back onto the skin at the old height over it
        n = vertex_normals(body)
        near_old = np.argmin(np.linalg.norm(body[None] - pieces[k][:, None], axis=2), axis=1)
        gap = ((pieces[k] - body[near_old]) * n[near_old]).sum(1)
        near = np.argmin(np.linalg.norm(body[None] - v[:, None], axis=2), axis=1)
        d = v - body[near]
        nn = n[near]
        out[k] = body[near] + d - (d * nn).sum(1, keepdims=True) * nn + np.maximum(gap, 0.004 * U)[:, None] * nn
    return out


# profile touches (eye spacings): lower lip back, chin forward (negative: back)
PROFILE = {"female-adult.east-asian": (0.06, -0.015), "female-adult.hispanic": (0.08, 0.04), "female-adult.southeast-asian": (0.06, 0.03)}


def profile(pieces, lip_back, chin_out, gid):
    import base_head

    def marks(p):
        e = p["eyes"]
        return base_head.profile_marks(np, p["body"], e[e[:, 0] > 0].mean(0), e[e[:, 0] < 0].mean(0))
    body = pieces["body"]
    try:
        m, U = marks(pieces)
    except IndexError:
        # (found on the group's neutral figure where this one's are unclear)
        m, U = marks(load(f"{gid}.neutral"))
    mid = body[np.abs(body[:, 0]) < 0.05 * U]

    def front(lo, hi):
        s = mid[(mid[:, 1] > lo) & (mid[:, 1] < hi)]
        return s[np.argmax(s[:, 2])]
    lower = front(m["mouth"][1] - 0.3 * U, m["mouth"][1] - 0.02 * U)
    chin = front(m["menton"][1] + 0.05 * U, m["mouth"][1] - 0.45 * U)
    move = np.zeros_like(body)
    lips = (lower + front(m["mouth"][1] + 0.02 * U, m["mouth"][1] + 0.3 * U)) / 2
    for c, r, d in ((lips, 0.4, (0, 0, -0.6 * lip_back)), (lower, 0.22, (0, 0.01, -0.4 * lip_back)), (chin, 0.45, (0, 0, chin_out))):
        w = np.exp(-(np.linalg.norm((body - c) * np.array([1, 1.3, 1]), axis=1) / (r * U)) ** 2)
        # the lower lip only: not the upper one above the mouth line
        if c is lower:
            w *= 1 - smoothstep(m["mouth"][1] - 0.04 * U, m["mouth"][1] + 0.04 * U, body[:, 1])
        move += w[:, None] * np.array(d) * U
    return dict(pieces, body=body + move)


# the drawn-ideal touches after the fit, by group: eyes (scale of each eye with its eyeball), nose (scale),
# jaw (how much narrower the chin's width gets), lips (height scale), mid (height scale of the face below the eyes),
# wide (width scale of the lower face), bridge (the nose ridge forward), smile (the mouth corners up; both in eye spacings),
# lid (the upper lid lowered over the eyeball, degrees)
# (by group, or group.heritage)
IDEAL = {"kid-infant": dict(nose=0.95), "kid-toddler": dict(nose=0.9, eyes=1.05), "kid-child": dict(nose=0.9),
         # (measured against the photo samples)
         "female-adult.hispanic": dict(eyes=1.05, nose=0.97, jaw=0.06, wide=0.97),
         "female-adult.southeast-asian": dict(eyes=1.05, lips=0.97, jaw=0.04, wide=0.96),
         "female-adult.east-asian": dict(eyes=1.02, nose=1.0, jaw=0.05, lips=0.95, mid=0.985, wide=0.93, bridge=0.08, smile=0.015,
                                        lid=5.0)}


def idealize(pieces, gid, her, eyes=1.0, nose=1.0, jaw=0.0, lips=1.0, mid=1.0, wide=1.0, bridge=0.0, smile=0.0, lid=0.0):
    """local, smooth reshapes about landmarks found on this face"""
    uv, vmap, tris = topo("body")
    body = pieces["body"]
    _, t, b, _ = on_mesh(pieces, gid, her)
    L = mesh_points(body, t, b, tris, vmap)
    e = pieces["eyes"]
    U = np.linalg.norm(e[e[:, 0] > 0].mean(0) - e[e[:, 0] < 0].mean(0))
    move = np.zeros_like(body)

    def fall(c, r, sq=(1, 1, 1)):
        return np.exp(-(np.linalg.norm((body - c) * np.array(sq), axis=1) / (r * U)) ** 2)[:, None]
    out = dict(pieces)
    ev = e.copy()
    for side in (1, -1):
        sel = np.sign(e[:, 0]) == side
        c = e[sel].mean(0)
        # the lids and the skin round them grow with the eyeball (full out to the brow's start, gone by the cheek)
        move += (body - c) * (eyes - 1) * fall(c, 0.42)
        ev[sel] = c + (e[sel] - c) * eyes
        if lid:
            # the upper lid turned down about the eyeball's centre (it stays on the ball), fading toward the brow
            d = body - c
            a = np.radians(lid) * smoothstep(-0.08 * U, 0.04 * U, d[:, 1]) * (1 - smoothstep(0.3 * U, 0.55 * U, np.linalg.norm(d, axis=1)))
            a *= smoothstep(-0.1 * U, 0.05 * U, d[:, 2])
            move[:, 1] += d[:, 1] * np.cos(a) - d[:, 2] * np.sin(a) - d[:, 1]
            move[:, 2] += d[:, 1] * np.sin(a) + d[:, 2] * np.cos(a) - d[:, 2]
    out["eyes"] = ev
    tip, base = L[1], L[2]
    move += (body - base) * (nose - 1) * fall((tip + base) / 2, 0.32)
    if bridge:
        # the nose's ridge brought forward, from the upper bridge to the tip
        along = (L[168, 1] - body[:, 1]) / (L[168, 1] - tip[1])
        ridge = smoothstep(0.0, 0.45, along) * (1 - smoothstep(1.0, 1.3, along))
        ridge *= np.exp(-(body[:, 0] / (0.2 * U)) ** 2) * smoothstep(base[2] - 0.5 * U, base[2] - 0.2 * U, body[:, 2])
        move[:, 2] += bridge * U * ridge
    # a V: the lower face narrowed toward the chin (not the neck below it, nor the head behind the ears)
    y, z = body[:, 1], body[:, 2]
    chin = L[152, 1]
    taper = jaw * smoothstep(L[4, 1], chin, y) * (1 - smoothstep(chin, chin - 0.7 * U, y))
    taper *= smoothstep((L[234, 2] + L[454, 2]) / 2 - 0.3 * U, (L[234, 2] + L[454, 2]) / 2 + 0.5 * U, z)
    move[:, 0] -= body[:, 0] * taper
    for corner in (L[61], L[291]):
        move[:, 1] += smile * U * fall(corner, 0.2)[:, 0]
    mc = (L[13] + L[14]) / 2
    w = fall(mc, 0.3, (0.6, 1, 1))
    move[:, 1] += (body[:, 1] - mc[1]) * (lips - 1) * w[:, 0]
    # the face below the eyes shorter (the chin's move carried a little way down the neck), the lower face wider
    ey = e[:, 1].mean()
    front = smoothstep((L[234, 2] + L[454, 2]) / 2 - 0.3 * U, (L[234, 2] + L[454, 2]) / 2 + 0.5 * U, z)
    below = np.clip(ey - y, 0, None)
    reach = ey - chin
    neck = smoothstep(chin - 1.5 * U, chin - 0.2 * U, y)
    move[:, 1] += (1 - mid) * np.minimum(below, reach) * front * neck
    lower = smoothstep(ey - 0.5 * U, ey - 2 * U, y) * (1 - smoothstep(chin - 0.3 * U, chin - 1.2 * U, y))
    move[:, 0] += body[:, 0] * (wide - 1) * lower * front
    out["body"] = body + move
    for k, v in pieces.items():
        if k not in ("body", "eyes"):
            i = np.argsort(np.linalg.norm(body[None, :, :] - v[:, None, :], axis=2), axis=1)[:, :4]
            out[k] = v + move[i].mean(1)
    return out


# groups whose lower lip is tucked under the upper lip: its top slope (lit from above, it read as a pale line along
# the seam) brought forward to just behind the upper lip's edge, the lining at the seam lifted in behind the upper
# lip; (how far behind, over what height) in scene units
TUCK_LIPS = {"female-adult": (0.001, 0.008), "female-senior": (0.001, 0.008)}
_ORIS = {}


def lip_weights(n):
    """per body vertex: upper- and lower-lip weights (MakeHuman's oris bones)"""
    if n not in _ORIS:
        import json
        from build_figure import mpfb_data
        rig = mpfb_data().parents[3] / "user_default" / "mpfb" / "data" / "rigs" / "standard" / "weights.default.json"
        weights = json.loads(rig.read_text())["weights"]
        w = np.zeros((n, 2))
        for name, pairs in weights.items():
            col = 0 if name.startswith(("oris03", "oris05")) else 1 if name.startswith(("oris01", "oris07")) else None
            if col is not None:
                for i, v in pairs:
                    if i < n:
                        w[i, col] = max(w[i, col], v)
        _ORIS[n] = w
    return _ORIS[n]


_LINING = []


def mouth_lining():
    """the mouth's lining (its own patch of the skin's UV): per triangle, and per vertex those not on the lips' rim"""
    if not _LINING:
        from scipy.sparse import coo_matrix
        from scipy.sparse.csgraph import connected_components
        uv, vmap, tris = topo("body")
        t, tuv = vmap[tris], uv[tris].mean(1)
        n = int(vmap.max()) + 1
        lin = (tuv[:, 0] > 0.72) & (tuv[:, 1] < 0.12)
        e = np.concatenate([t[lin][:, [0, 1]], t[lin][:, [1, 2]]])
        _, lab = connected_components(coo_matrix((np.ones(len(e)), (e[:, 0], e[:, 1])), shape=(n, n)), directed=False)
        # (the patch touching the lips; the same UV corner holds other bits)
        lin &= np.isin(lab[t[:, 0]], lab[lip_weights(n).max(1) > 0.3])
        inner = np.zeros(n, bool)
        inner[t[lin].ravel()] = True
        inner[t[~lin].ravel()] = False
        _LINING.extend([lin, inner])
    return _LINING


# the lining kept this far behind the lips' skin (scene units) where it lies at most LINING_OVER over it (further, it's
# skin far behind: the other cheek), as seen from these views (yaw, pitch in degrees),
# moving back at most so far
LINING_GAP, LINING_OVER, LINING_VIEWS, LINING_BACK = 0.0005, 0.003, [(y, p) for y in (0, -30, 30, -55, 55) for p in (0, -35, 25)], 0.006


def turned(yaw, pitch):
    """the rotation turning the figure to a view (degrees)"""
    a, b = np.radians(yaw), np.radians(pitch)
    return (np.array([[1, 0, 0], [0, np.cos(b), -np.sin(b)], [0, np.sin(b), np.cos(b)]])
            @ np.array([[np.cos(a), 0, np.sin(a)], [0, 1, 0], [-np.sin(a), 0, np.cos(a)]]))


def zbuffer(X, Y, Z, T, W, H):
    """per pixel: the front-most triangle (index into T, -1 for none) and its depth"""
    zb, tid = np.full((H, W), -np.inf), np.full((H, W), -1)
    x0, y0 = np.floor(X[T].min(1)).astype(int), np.floor(Y[T].min(1)).astype(int)
    x1, y1 = np.ceil(X[T].max(1)).astype(int), np.ceil(Y[T].max(1)).astype(int)
    for i, (a, b, c) in enumerate(T):
        xs, ys = np.arange(max(x0[i], 0), min(x1[i] + 1, W)), np.arange(max(y0[i], 0), min(y1[i] + 1, H))
        d = (Y[b] - Y[c]) * (X[a] - X[c]) + (X[c] - X[b]) * (Y[a] - Y[c])
        if not len(xs) or not len(ys) or abs(d) < 1e-12:
            continue
        gx, gy = np.meshgrid(xs + 0.5, ys + 0.5)
        l1 = ((Y[b] - Y[c]) * (gx - X[c]) + (X[c] - X[b]) * (gy - Y[c])) / d
        l2 = ((Y[c] - Y[a]) * (gx - X[c]) + (X[a] - X[c]) * (gy - Y[c])) / d
        z = l1 * Z[a] + l2 * Z[b] + (1 - l1 - l2) * Z[c]
        iy, ix = gy.astype(int), gx.astype(int)
        m = (l1 >= 0) & (l2 >= 0) & (l1 + l2 <= 1) & (z > zb[iy, ix])
        zb[iy[m], ix[m]], tid[iy[m], ix[m]] = z[m], i
    return tid, zb


def seat_lining(body, px=0.0001, rounds=4):
    """the mouth's lining moved back wherever it shows in front of the lips' skin (the face's fit and the lips' tuck
    can lay it over the lips at their seam, where it reads as dark slivers): in each view, the lining's triangles
    in front of the skin push their off-rim vertices straight back, in proportion to their share"""
    lin, inner = mouth_lining()
    _, vmap, tris = topo("body")
    t = vmap[tris]
    w = lip_weights(len(body))
    lip = w.max(1) > 0.3
    mc, half, zf = body[lip].mean(0), np.abs(body[lip, 0]).max(), body[lip, 2].max()
    c = body[t].mean(1)
    near = (np.abs(c[:, 0]) < half + 0.012) & (np.abs(c[:, 1] - mc[1]) < 0.03) & (c[:, 2] > zf - 0.04)
    skin, lining = t[~lin & near], t[lin & near]
    out, back = body.copy(), np.zeros(len(body))
    W, H = int(2 * (half + 0.02) / px), int(0.08 / px)
    for _ in range(rounds):
        seen = False
        for yaw, pitch in LINING_VIEWS:
            R = turned(yaw, pitch)
            r = (out - mc) @ R.T
            X, Y = (r[:, 0] + half + 0.02) / px, (0.04 - r[:, 1]) / px
            ts, zs = zbuffer(X, Y, r[:, 2], skin, W, H)
            tl, zl = zbuffer(X, Y, r[:, 2], lining, W, H)
            # over the skin's face turned to the eye (over a back face, it's the mouth seen through the seam)
            S = skin[ts.clip(0)]
            facing = np.cross(r[S[..., 1]] - r[S[..., 0]], r[S[..., 2]] - r[S[..., 0]])[..., 2] > 0
            iy, ix = np.nonzero((tl >= 0) & (ts >= 0) & (zl > zs) & (zl < zs + LINING_OVER) & facing)
            if not len(iy):
                continue
            seen = True
            T = lining[tl[iy, ix]]
            gx, gy = ix + 0.5, iy + 0.5
            p0, p1, p2 = T[:, 0], T[:, 1], T[:, 2]
            d = (Y[p1] - Y[p2]) * (X[p0] - X[p2]) + (X[p2] - X[p1]) * (Y[p0] - Y[p2])
            l1 = ((Y[p1] - Y[p2]) * (gx - X[p2]) + (X[p2] - X[p1]) * (gy - Y[p2])) / d
            l2 = ((Y[p2] - Y[p0]) * (gx - X[p2]) + (X[p0] - X[p2]) * (gy - Y[p2])) / d
            share = np.stack([l1, l2, 1 - l1 - l2], 1).clip(0, 1) * inner[T]
            # (not by the rim: what shows there is the lips' own seam)
            need = (zl[iy, ix] - zs[iy, ix] + LINING_GAP) / share.sum(1).clip(1e-9) * (share.sum(1) > 0.3)
            push = np.zeros(len(out))
            for k in range(3):
                np.maximum.at(push, T[:, k], need * (share[:, k] > 0))
            # (straight back: its depth in this view changes by R[2, 2] of that)
            push = np.minimum(push / R[2, 2], LINING_BACK - back).clip(0)
            back += push
            out[:, 2] -= push
        if not seen:
            break
    return out


def tuck_lips(pieces, depth, reach):
    from skin_textures import lip_seam
    body = pieces["body"]
    w = lip_weights(len(body))
    y0, zu, zb, half = lip_seam(np, body, w[:, 0] > 0.3, w[:, 1] > 0.3)
    d = y0 - body[:, 1]
    lower = (w[:, 1] > w[:, 0]) & (body[:, 2] > zb - 0.012)
    k = smoothstep(half, 0.8 * half, np.abs(body[:, 0]))
    out = body.copy()
    # the front layer from just under the seam to the lip's fullest point: a steep, rounded roll
    top = np.minimum(zu, zb) - depth
    want = top + (zb - top) * smoothstep(0.001, reach, d)
    # (not the lining behind it: brought forward it'd lie over the lip)
    sel = lower & (d > 0.0008) & (d < reach + 0.002) & ~mouth_lining()[1]
    k_sel = k * (1 - smoothstep(reach, reach + 0.002, d))
    out[sel, 2] = np.maximum(body[sel, 2], (body[:, 2] + k_sel * (want - body[:, 2]))[sel])
    # the lining at the seam: up behind the upper lip (no lit shelf between the lips)
    sel = lower & (d <= 0.0008) & (d > -0.002) & (body[:, 2] < top - 0.001)
    out[sel, 1] = np.maximum(body[sel, 1], (y0 + k * 0.003)[sel])
    return dict(pieces, body=ease_folds(body, out))


# faces whose lower lip's top tucks under the upper lip: its front above the fullest point at most `top` per unit
# below `gap` behind the upper lip's edge, and the upper lip's edge reaching `over` past it (its top stood out past
# the upper lip, facing up: the back light's glint, a white line between the lips); (top, gap, over, reach)
TUCK_LOWER = {"female-adult.black": (0.35, 0.0005, 0.0003, 0.0065)}


def tuck_lower(pieces, top, gap, over, reach):
    from skin_textures import lip_seam
    body = pieces["body"]
    w = lip_weights(len(body))
    inner = mouth_lining()[1]
    y0, zu, zb, _ = lip_seam(np, body, w[:, 0] > 0.3, w[:, 1] > 0.3)
    d = y0 - body[:, 1]
    front = (w.max(1) > 0.3) & ~inner & (body[:, 2] > zb - 0.008)
    up, lo = front & (w[:, 0] > w[:, 1]), front & (w[:, 1] > w[:, 0])
    # (fading out toward the mouth's corners)
    corner = np.abs(body[w[:, 1] > 0.5, 0]).max()
    k = smoothstep(corner, 0.6 * corner, np.abs(body[:, 0]))
    out = body.copy()
    sel = lo & (d > 0) & (d < reach)
    out[sel, 2] -= (k * np.clip(body[:, 2] - (zu - gap + top * d), 0, None))[sel]
    tops = np.flatnonzero(lo & (d > -0.001) & (d < 0.002))
    for i in np.flatnonzero(up & (d > -0.004) & (d < 0.0015)):
        l = tops[np.abs(out[tops, 0] - out[i, 0]) < 0.003]
        if len(l):
            want = out[l, 2].max() + over - top * max(0, -d[i] - 0.001)
            out[i, 2] += k[i] * max(0, want - out[i, 2])
    return dict(pieces, body=ease_folds(body, out))


# groups whose lips are closed: the lower lip's top under the upper lip lifted to meet it (an open slit at the sides
# read as parted lips in profile); (reach below the upper lip, gap kept) in scene units
CLOSE_LIPS = {"female-adult": (0.003, 0.0001)}


def ray_up(body, tris, pts):
    """per point: the lowest hit of a vertical ray up through `tris` (inf: none)"""
    a, b, c = (body[tris[:, k]] for k in range(3))
    d = (b[:, 2] - c[:, 2]) * (a[:, 0] - c[:, 0]) + (c[:, 0] - b[:, 0]) * (a[:, 2] - c[:, 2])
    ok = np.abs(d) > 1e-14
    d = np.where(ok, d, 1)
    out = np.full(len(pts), np.inf)
    for i, q in enumerate(pts):
        l1 = ((b[:, 2] - c[:, 2]) * (q[0] - c[:, 0]) + (c[:, 0] - b[:, 0]) * (q[2] - c[:, 2])) / d
        l2 = ((c[:, 2] - a[:, 2]) * (q[0] - c[:, 0]) + (a[:, 0] - c[:, 0]) * (q[2] - c[:, 2])) / d
        y = l1 * a[:, 1] + l2 * b[:, 1] + (1 - l1 - l2) * c[:, 1]
        m = ok & (l1 >= 0) & (l2 >= 0) & (l1 + l2 <= 1) & (y > q[1])
        if m.any():
            out[i] = y[m].min()
    return out


def close_lips(pieces, reach, keep):
    from skin_textures import lip_seam
    body = pieces["body"]
    w = lip_weights(len(body))
    lin, inner = mouth_lining()
    _, vmap, tris = topo("body")
    t = vmap[tris]
    up = w[:, 0] > w[:, 1]
    lo = ~up & (w.max(1) > 0.3) & ~inner
    y0 = lip_seam(np, body, w[:, 0] > 0.3, w[:, 1] > 0.3)[0]
    d = y0 - body[:, 1]
    cand = np.flatnonzero(lo & (d < reach + 0.002) & (d > -0.002))
    gap = ray_up(body, t[(up & (w.max(1) > 0.3))[t].all(1) & ~lin], body[cand]) - body[cand, 1]
    gap = np.where(np.isfinite(gap), gap, 0)
    out = body.copy()
    out[cand, 1] += np.clip(gap - keep, 0, None) * (1 - smoothstep(0.5 * reach, reach, gap))
    return dict(pieces, body=ease_folds(body, out))


# groups whose lower lids' ledge (flat on the eyeball, facing up: a pale rim lit from above) is pushed in under the
# ball's surface: at most this far from its centre, taken from within 1.1 of it and, toward the inner corner, `inner`
# further (the ledge widens there: a white streak under the corner); in ball radii
TUCK_LIDS = {"female-adult": (0.95, 0.12)}


def tuck_lids(pieces, reach, inner):
    body, eyes = pieces["body"], pieces["eyes"]
    n = vertex_normals(body)
    out = body.copy()
    for side in (1, -1):
        c, r = ball_sphere(eyes[np.sign(eyes[:, 0]) == side])
        q = (body - c) / r
        d = np.linalg.norm(q, axis=1)
        far = 1.1 + inner * smoothstep(0.3, 0.6, -side * q[:, 0])
        w = smoothstep(0.5, 0.85, n[:, 1]) * (d < far) * (q[:, 1] < -0.1) * (q[:, 2] > 0.3)
        out += (body - c) * (w * (np.minimum(d, reach) / np.maximum(d, 1e-9) - 1))[:, None]
    return dict(pieces, body=out)


# groups whose skin beside each eye's inner corner, toward the nose, is hollowed (left flat, it caught the key
# light's sheen in one broad patch: light grey on deep skins); (centre: medial, down, forward; radius; depth) in
# ball radii
HOLLOW_CANTHUS = {"female-adult": ((1.1, -0.4, 1.4), 1.0, 0.2)}


def hollow_canthus(pieces, centre, radius, depth):
    body, eyes = pieces["body"], pieces["eyes"]
    n = vertex_normals(body)
    out = body.copy()
    for side in (1, -1):
        c, r = ball_sphere(eyes[np.sign(eyes[:, 0]) == side])
        q = (body - c) / r
        q0 = np.array([-side * centre[0], centre[1], centre[2]])
        w = 1 - smoothstep(0, radius, np.linalg.norm(q - q0, axis=1))
        w *= smoothstep(1.25, 1.45, np.linalg.norm(q, axis=1)) * smoothstep(0.15, 0.45, side * body[:, 0] / r)
        out -= (depth * r * w)[:, None] * n
    return dict(pieces, body=out)


# groups whose upper lash strands are re-angled at the lid's edge: they left it flat (a shelf under the edge, then a
# stretch rising ~30°), seen edge-on from the front and from above: a grey line of sheen and sclera through the
# strands. (root's climb into the lid, the strand's lowest climb past row 1, in degrees; tip clearance in ball radii)
SEAT_LASHES = {"female-adult": (60, 55, 0.03)}


def lash_strands(key, lash, eyes):
    """per strip (upper / lower, each side) its strands, root → tip: (strands, rows) vertex indices"""
    uv, _, tri = topo(key)
    poly = np.load(RAW / f"topo.{key}.npz")["poly"]
    n = len(uv)
    nb = [set() for _ in range(n)]
    quads = [set() for _ in range(n)]
    edges = {}
    for t, q in zip(tri, poly):
        for a, b in ((0, 1), (1, 2), (2, 0)):
            nb[t[a]].add(t[b]); nb[t[b]].add(t[a])
            e = (min(t[a], t[b]), max(t[a], t[b]))
            edges[e] = edges.get(e, 0) + 1
        for v in t:
            quads[v].add(q)
    rim = {}
    for (a, b), m in edges.items():
        if m == 1:
            rim.setdefault(a, []).append(b); rim.setdefault(b, []).append(a)
    seen, out = set(), []
    for start in (v for v in rim if len(quads[v]) == 1):
        if start in seen:
            continue
        # the strip's rim from a corner, cut at its corners into sides; the root is the long side nearest the ball
        loop, prev = [start], None
        while True:
            nxt = next(y for y in rim[loop[-1]] if y != prev)
            if nxt == start:
                break
            prev = loop[-1]; loop.append(nxt)
        seen |= set(loop)
        cut = [i for i, v in enumerate(loop) if len(quads[v]) == 1] + [len(loop)]
        sides = sorted((loop[cut[i]:cut[i + 1]] + [loop[cut[i + 1] % len(loop)]] for i in range(len(cut) - 1)), key=len)[-2:]
        c = ball_sphere(eyes[np.sign(eyes[:, 0]) == np.sign(lash[loop, 0].mean())])[0]
        rows = [min(sides, key=lambda s: np.linalg.norm(lash[s] - c, axis=1).mean())]
        done = set(rows[0])
        while True:
            # the next row: the unvisited neighbours, walked as a path from the end beside the last row's first
            layer = {y for x in rows[-1] for y in nb[x]} - done
            if len(layer) != len(rows[0]):
                break
            ends = [y for y in layer if len(nb[y] & layer) == 1]
            path = [min(ends, key=lambda y: np.linalg.norm(lash[y] - lash[rows[-1][0]]))]
            while len(path) < len(layer):
                path.append(next(y for y in nb[path[-1]] & layer if y not in path))
            rows.append(path); done |= layer
        out.append(np.array(rows).T)
    return out


def closest_on(body, tris, p):
    """the nearest point of `tris` to p and that triangle's unit normal"""
    a, b, c = (body[tris[:, k]] for k in range(3))
    ab, ac = b - a, c - a
    n = np.cross(ab, ac)
    nn = n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-30)
    q = p - ((p - a) * nn).sum(1, keepdims=True) * nn
    # barycentric of the projection; outside the triangle: the nearest of its edges
    v2 = q - a
    d00, d01, d11 = (ab * ab).sum(1), (ab * ac).sum(1), (ac * ac).sum(1)
    d20, d21 = (v2 * ab).sum(1), (v2 * ac).sum(1)
    den = np.maximum(d00 * d11 - d01 * d01, 1e-30)
    v, w = (d11 * d20 - d01 * d21) / den, (d00 * d21 - d01 * d20) / den
    inside = (v >= 0) & (w >= 0) & (v + w <= 1)
    best = np.where(inside[:, None], q, np.nan)
    for s, e in ((a, b), (b, c), (c, a)):
        t = np.clip(((p - s) * (e - s)).sum(1) / np.maximum(((e - s) ** 2).sum(1), 1e-30), 0, 1)
        r = s + t[:, None] * (e - s)
        nearer = ~inside & (np.isnan(best[:, 0]) | (np.linalg.norm(r - p, axis=1) < np.linalg.norm(best - p, axis=1)))
        best[nearer] = r[nearer]
    i = np.argmin(np.linalg.norm(best - p, axis=1))
    return best[i], nn[i]


def depth_in(body, tris, pts):
    """per point: signed distance to the skin (negative: inside)"""
    cen = body[tris].mean(1)
    out = np.zeros(len(pts))
    for i, p in enumerate(pts):
        near = tris[np.argsort(np.linalg.norm(cen - p, axis=1))[:40]]
        q, n = closest_on(body, near, p)
        out[i] = np.linalg.norm(p - q) * np.sign((p - q) @ n)
    return out


def seat_lashes(pieces, climb, rise, clear):
    body, eyes = pieces["body"], pieces["eyes"]
    _, vmap, tris = topo("body")
    t = vmap[tris]
    out = dict(pieces)
    up = np.array([0.0, 1.0, 0.0])
    for key in [k for k in pieces if k.startswith("lashes-")]:
        lash = pieces[key].copy()
        for strands in lash_strands(key, pieces[key], eyes):
            P0 = pieces[key][strands]
            side = np.sign(P0[..., 0].mean())
            c, r = ball_sphere(eyes[np.sign(eyes[:, 0]) == side])
            if P0[..., 1].mean() < c[1]:
                continue
            near = t[(np.linalg.norm(body[t].mean(1) - c, axis=1) < 2.5 * r)]
            for ch, P in zip(strands, P0):
                f = (P[-1] - P[0]) * np.array([1, 0, 1])
                f /= np.linalg.norm(f)
                a = np.cross(f, up)
                a /= np.linalg.norm(a)
                # the root up and back into the lid, behind row 1 (kept where it was)
                l01 = np.linalg.norm(P[1] - P[0])
                lash[ch[0]] = P[1] + l01 * (np.sin(np.radians(climb)) * up - np.cos(np.radians(climb)) * f)
                # the strand past row 1 turned up about it till it leaves at `rise`, less where it would near the lid
                v = P[2:] - P[1]
                ang = max(rise - np.degrees(np.arctan2(v[0] @ up, v[0] @ f)), 0.0)
                turn = lambda x, g: x * np.cos(g) + np.cross(a, x) * np.sin(g) + np.outer(x @ a, a) * (1 - np.cos(g))
                if (turn(f[None], 0.1)[0] @ up) < 0:
                    a = -a
                while True:
                    lash[ch[2:]] = P[1] + turn(v, np.radians(ang))
                    if ang <= 0 or depth_in(body, near, lash[ch[2:]]).min() >= clear * r:
                        break
                    ang = max(ang - 3, 0)
        out[key] = lash
    return out


# views a tucked lip's


# views a tucked lip's triangles may not turn their backs to (yaw, pitch in degrees)
TUCK_VIEWS = [(y, p) for y in (0, -35, 35) for p in (0, -35, 25)]


def ease_folds(body, out, px=0.0002, rounds=10):
    """the lips' move `body` → `out` eased back where it folds the skin (at the mouth's corners the roll's push and the
    lining's lift meet and fold triangles over, read as dark specks): each round, the vertices of every triangle
    seen from its back in a view move half as far"""
    _, vmap, tris = topo("body")
    t = vmap[tris]
    lip = lip_weights(len(body)).max(1) > 0.3
    mc, half, zf = body[lip].mean(0), np.abs(body[lip, 0]).max(), body[lip, 2].max()
    c = body[t].mean(1)
    t = t[(np.abs(c[:, 0]) < half + 0.012) & (np.abs(c[:, 1] - mc[1]) < 0.03) & (c[:, 2] > zf - 0.04)]
    W, H = int(2 * (half + 0.02) / px), int(0.08 / px)
    move, k = out - body, np.ones(len(body))
    moved = np.abs(move).max(1) > 0
    for _ in range(rounds):
        q = body + k[:, None] * move
        back = np.zeros(len(t), bool)
        for yaw, pitch in TUCK_VIEWS:
            r = (q - mc) @ turned(yaw, pitch).T
            tid, _ = zbuffer((r[:, 0] + half + 0.02) / px, (0.04 - r[:, 1]) / px, r[:, 2], t, W, H)
            seen = np.unique(tid[tid >= 0])
            back[seen[np.cross(r[t[seen, 1]] - r[t[seen, 0]], r[t[seen, 2]] - r[t[seen, 0]])[:, 2] < 0]] = True
        v = np.unique(t[back])
        v = v[moved[v] & (k[v] > 0.01)]
        if not len(v):
            break
        k[v] *= 0.5
    return q


# groups whose chest surface is smoothed (MakeHuman's coarse mesh leaves facets): Taubin passes
SMOOTH_CHEST = {"female-adult": 180, "female-senior": 50}


def smooth_chest(body, eyes, passes):
    """the chest surface smoothed without shrinking (Taubin), out to the armpit fold and the side of the chest (where
    MakeHuman's own fold reads as a line), fading below the collarbones and into the arms"""
    U = np.linalg.norm(eyes[eyes[:, 0] > 0].mean(0) - eyes[eyes[:, 0] < 0].mean(0))
    arms = np.load(RAW / "regions.npz")["arms"]
    w = np.zeros(len(body))
    for i in nipples():
        r = np.linalg.norm(body - body[i], axis=1)
        # the chest centre keeps its own shape
        w = np.maximum(w, (1 - smoothstep(3.0 * U, 5.2 * U, r)) * smoothstep(0.3 * U, 0.65 * U, r))
    ny = body[nipples()[0], 1]
    w *= (1 - smoothstep(0.3, 0.55, arms)) * (1 - smoothstep(ny + 1.9 * U, ny + 2.6 * U, body[:, 1]))
    return smooth_along_normals(body, w, passes)


# groups whose jaw and throat are softened (the source head's crisp jaw edge and the fit's fold under the chin):
# Taubin passes
SOFT_JAW = {"female-adult": 70}


def soften_jaw(pieces, gid, her, passes):
    uv, vmap, tris = topo("body")
    body, e = pieces["body"], pieces["eyes"]
    _, t, b, _ = on_mesh(pieces, gid, her)
    L = mesh_points(body, t, b, tris, vmap)
    U = np.linalg.norm(e[e[:, 0] > 0].mean(0) - e[e[:, 0] < 0].mean(0))
    chin, mouth = L[152, 1], (L[13, 1] + L[14, 1]) / 2
    y, z = body[:, 1], body[:, 2]
    # from just under the lower lip down the throat, in front of the ears; the lips and chin's point keep their shape
    w = smoothstep(chin - 1.6 * U, chin - 0.9 * U, y) * (1 - smoothstep(mouth - 0.55 * U, mouth - 0.25 * U, y))
    w *= smoothstep((L[234, 2] + L[454, 2]) / 2 - 0.4 * U, (L[234, 2] + L[454, 2]) / 2 + 0.4 * U, z)
    w *= 1 - 0.5 * (1 - smoothstep(0.15 * U, 0.4 * U, np.linalg.norm(body - L[152], axis=1)))
    return dict(pieces, body=smooth_along_normals(body, w, passes))


# groups whose nose sides, under-eyes and smile lines are evened (passes of plain smoothing, then a Taubin pass to
# keep the volume): the heritage's nasojugal crease and the fit's folds there read as hard lines in low and 3/4 views
EVEN_MIDFACE = {"female-adult": 15}


def even_midface(pieces, gid, her, passes):
    import base_head as bh
    uv, vmap, tris = topo("body")
    body, e = pieces["body"], pieces["eyes"]
    _, t, b, _ = on_mesh(pieces, gid, her)
    L = mesh_points(body, t, b, tris, vmap)
    U = np.linalg.norm(e[e[:, 0] > 0].mean(0) - e[e[:, 0] < 0].mean(0))
    x, y, z = body[:, 0], body[:, 1], body[:, 2]
    ey = e[:, 1].mean()
    balls = [ball_sphere(e[np.sign(e[:, 0]) == side]) for side in (1, -1)]
    # below each eye, out across the cheek (not the lids)
    w = np.zeros(len(body))
    for side, (c, R) in zip((1, -1), balls):
        r = np.linalg.norm((body - c) * np.array([1, 1.15, 1]), axis=1)
        w = np.maximum(w, smoothstep(1.25 * R, 1.6 * R, r) * (1 - smoothstep(0.85 * U, 1.15 * U, r)) * (np.sign(x) == side)
                       * (1 - smoothstep(c[1], c[1] + 0.15 * U, y)))
    # the nose's sides up past the inner corners of the eyes
    inner = np.abs(L[133, 0])
    sides = (1 - smoothstep(inner + 0.05 * U, inner + 0.25 * U, np.abs(x))) * (1 - smoothstep(ey + 0.15 * U, ey + 0.35 * U, y))
    for c, R in balls:
        sides *= smoothstep(1.2 * R, 1.5 * R, np.linalg.norm(body - c, axis=1))
    w = np.maximum(w, sides) * smoothstep(L[13, 1] + 0.2 * U, L[13, 1] + 0.4 * U, y)
    # the smile lines, nose wing to mouth corner (outside the lips)
    mouth = (L[13] + L[14]) / 2
    for wing, corner in ((L[129], L[61]), (L[358], L[291])):
        seg = corner - wing
        s_ = np.clip(((body - wing) @ seg) / (seg @ seg), 0, 1)
        d = np.linalg.norm(body - (wing + s_[:, None] * seg), axis=1)
        w = np.maximum(w, (1 - smoothstep(0.12 * U, 0.25 * U, d)) * smoothstep(0.3, 0.45, np.linalg.norm((body - mouth) * np.array([0.7, 1.4, 1]), axis=1) / U))
    # in front, off the nose's ridge, wings and nostrils
    mid = (L[234, 2] + L[454, 2]) / 2
    w *= smoothstep(mid, mid + 0.4 * U, z) * smoothstep(0.07 * U, 0.14 * U, np.abs(x))
    w *= smoothstep(0.3 * U, 0.45 * U, np.linalg.norm((body - L[2]) * np.array([0.8, 1.4, 1]), axis=1))
    flat = body + w[:, None] * (bh.smooth(np, body, vmap[tris], len(body), passes) - body)
    return dict(pieces, body=untangle_w(flat, w, 10))


def untangle_w(body, w, passes):
    """Taubin passes where `w` (no shrinking)"""
    _, vmap, tris = topo("body")
    t = vmap[tris]
    e = np.concatenate([t[:, [0, 1]], t[:, [1, 2]], t[:, [2, 0]]])
    cnt = np.maximum(np.bincount(e.ravel(), minlength=len(body)), 1).astype(float)[:, None]
    p = body.copy()
    for _ in range(passes):
        for step in (0.5, -0.53):
            acc = np.zeros_like(p)
            np.add.at(acc, e[:, 0], p[e[:, 1]])
            np.add.at(acc, e[:, 1], p[e[:, 0]])
            p = p + step * w[:, None] * (acc / cnt - p)
    return p


# faces whose cheeks are smoothed (the heritage difference leaves ripples that read as streaks): Taubin passes
SMOOTH_CHEEKS = {"female-adult.east-asian": 200}


def smooth_cheeks(pieces, gid, her, passes):
    uv, vmap, tris = topo("body")
    body, e = pieces["body"], pieces["eyes"]
    _, t, b, _ = on_mesh(pieces, gid, her)
    L = mesh_points(body, t, b, tris, vmap)
    U = np.linalg.norm(e[e[:, 0] > 0].mean(0) - e[e[:, 0] < 0].mean(0))
    y, z = body[:, 1], body[:, 2]
    # below the eyes to the jaw's underside, in front of the ears; not the eyes, nose or lips
    w = smoothstep(L[152, 1] - 0.4 * U, L[152, 1] + 0.1 * U, y) * (1 - smoothstep(e[:, 1].mean() - 0.3 * U, e[:, 1].mean(), y))
    w *= smoothstep((L[234, 2] + L[454, 2]) / 2 - 0.3 * U, (L[234, 2] + L[454, 2]) / 2 + 0.3 * U, z)
    for side in (1, -1):
        w *= smoothstep(0.45 * U, 0.65 * U, np.linalg.norm(body - e[np.sign(e[:, 0]) == side].mean(0), axis=1))
    nose = (1 - smoothstep(0.25 * U, 0.4 * U, np.abs(body[:, 0]))) * smoothstep(L[2, 1] - 0.1 * U, L[2, 1] + 0.05 * U, y)
    mouth = (L[13] + L[14]) / 2
    lips = 1 - smoothstep(0.3, 0.45, np.linalg.norm((body - mouth) * np.array([0.7, 1.4, 1]), axis=1) / U)
    # nor the mouth's lining behind them
    lips = np.maximum(lips, smoothstep(mouth[2] - 0.4 * U, mouth[2] - 0.55 * U, z) * (1 - smoothstep(0.5 * U, 0.6 * U, np.abs(body[:, 0])))
                      * (1 - smoothstep(0.4 * U, 0.5 * U, np.abs(y - mouth[1]))))
    # the chin rounded too (its point and the edge under it)
    chin = 1 - smoothstep(0.35 * U, 0.6 * U, np.linalg.norm(body - L[152], axis=1))
    w = np.maximum(w, 0.5 * chin) * (1 - nose) * (1 - lips)
    # the jaw's underside less (soften_jaw's too; smoothed more, it folds)
    w *= 0.3 + 0.7 * smoothstep(-0.7, -0.35, vertex_normals(body)[:, 1])
    return dict(pieces, body=smooth_along_normals(body, w, passes))


def smooth_along_normals(body, w, passes):
    """the surface smoothed without shrinking (Taubin) where `w`, moving along the normal only"""
    _, vmap, tris = topo("body")
    e = vmap[tris]
    e = np.concatenate([e[:, [0, 1]], e[:, [1, 2]], e[:, [2, 0]]])
    cnt = np.bincount(e.ravel(), minlength=len(body)).astype(float)[:, None]

    def lap(p):
        acc = np.zeros_like(p)
        np.add.at(acc, e[:, 0], p[e[:, 1]])
        np.add.at(acc, e[:, 1], p[e[:, 0]])
        return acc / np.maximum(cnt, 1) - p
    tri = vmap[tris]

    def normal(p):
        # moves along the surface normal only: the skin's painted details stay where they are
        f = np.cross(p[tri[:, 1]] - p[tri[:, 0]], p[tri[:, 2]] - p[tri[:, 0]])
        n = np.zeros_like(p)
        for k in range(3):
            np.add.at(n, tri[:, k], f)
        return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)

    p = body.copy()
    for k in range(passes):
        n = normal(p) if k % 10 == 0 else n
        for step in (0.5, -0.53):
            d = lap(p)
            p = p + step * w[:, None] * (d * n).sum(1, keepdims=True) * n
    return p


_NIPPLES = []


def nipples():
    """the chest centre vertices, found once on the default woman (same topology on every variant)"""
    if not _NIPPLES:
        from build_figure import nipple_ids
        _NIPPLES.extend(nipple_ids(np, load("female-adult.neutral")))
    return _NIPPLES


# young children's shoulders: sloped down from the neck (eye spacings at the shoulder's tip), lashes shortened
SLOPE = {"kid-infant": 0.45, "kid-toddler": 0.3}
LASHES = {"kid-infant": 0.2, "kid-toddler": 0.5}
# young children's brows: shorter (toward each brow's middle)
BROW_LENGTH = {"kid-infant": 0.7, "kid-toddler": 0.8}


# young children's chest top and shoulders: the fit squashes the short neck zone, so the collarbone band and the top of
# the shoulders are inflated along their normals (eye spacings) into a soft mound
ROUND_CHEST = {"kid-infant": 0.1, "kid-toddler": 0.07}


def round_chest(body, eyes, amount):
    U = np.linalg.norm(eyes[eyes[:, 0] > 0].mean(0) - eyes[eyes[:, 0] < 0].mean(0))
    ey = eyes[:, 1].mean()
    arms = np.load(RAW / "regions.npz")["arms"]
    n = vertex_normals(body)
    y = body[:, 1] - ey
    band = smoothstep(-2.9 * U, -2.0 * U, y) * (1 - smoothstep(-1.5 * U, -1.1 * U, y))
    facing = smoothstep(0.1, 0.6, n[:, 2] + 0.7 * n[:, 1])
    w = band * facing * (1 - smoothstep(2.4 * U, 3.0 * U, np.abs(body[:, 0]))) * (1 - smoothstep(0.2, 0.5, arms))
    return body + (amount * U * w)[:, None] * n


def slope_shoulders(body, eyes, drop):
    U = np.linalg.norm(eyes[eyes[:, 0] > 0].mean(0) - eyes[eyes[:, 0] < 0].mean(0))
    ey = eyes[:, 1].mean()
    ax, y = np.abs(body[:, 0]), body[:, 1] - ey
    out = smoothstep(0.9 * U, 2.3 * U, ax)
    band = smoothstep(-4.2 * U, -2.6 * U, y) * (1 - smoothstep(-1.4 * U, -0.9 * U, y))
    move = np.zeros_like(body)
    move[:, 1] = -drop * U * out * band
    move[:, 0] = -np.sign(body[:, 0]) * 0.25 * drop * U * out * band
    return body + move


def shorten_lashes(pieces, k):
    body = pieces["body"]
    out = dict(pieces)
    for key in [k_ for k_ in pieces if k_.startswith("lashes-")]:
        v = pieces[key]
        i = np.argmin(np.linalg.norm(body[None] - v[:, None], axis=2), axis=1)
        root = body[i]
        out[key] = root + (v - root) * k
    return out


def save(name, pieces):
    gid = name.split(".")[0]
    ideal, prof = IDEAL.get(name, IDEAL.get(gid)), PROFILE.get(name, PROFILE.get(gid))
    if ideal and "eyes" in pieces and not name.endswith(".pregnant"):
        pieces = idealize(pieces, gid, name.split(".")[1], **ideal)
    if prof and "eyes" in pieces and not name.endswith(".pregnant"):
        pieces = profile(pieces, *prof, gid)
    if "eyes" in pieces and any(k.startswith("brows-") for k in pieces):
        e = pieces["eyes"]
        U = np.linalg.norm(e[e[:, 0] > 0].mean(0) - e[e[:, 0] < 0].mean(0))
        b = next(v for k, v in pieces.items() if k.startswith("brows-"))
        lift = max(BROW_RISE * U - (b[:, 1].mean() - e[:, 1].mean()), 0) / U
        if name in BROW_THICK or gid in BROW_THICK:
            pieces = thicken_brows(pieces, BROW_THICK.get(name, BROW_THICK.get(gid)), U)
        arch, drop = BROWS.get(name, BROWS.get(gid, (0.0, 0.0)))
        pieces = seat_brows(pieces, arch, drop - lift)
    if gid in SLOPE and "eyes" in pieces:
        pieces = dict(pieces, body=slope_shoulders(pieces["body"], pieces["eyes"], SLOPE[gid]))
    if gid in ROUND_CHEST and "eyes" in pieces:
        pieces = dict(pieces, body=round_chest(pieces["body"], pieces["eyes"], ROUND_CHEST[gid]))
    if gid in LASHES:
        pieces = shorten_lashes(pieces, LASHES[gid])
    if gid in BROW_LENGTH:
        for k in [k for k in pieces if k.startswith("brows-")]:
            v = pieces[k].copy()
            for side in (1, -1):
                sel = np.sign(v[:, 0]) == side
                c = v[sel].mean(0)
                v[sel, 0] = c[0] + (v[sel, 0] - c[0]) * BROW_LENGTH[gid]
            pieces = dict(pieces, **{k: v})
    if gid in SOFT_JAW and "eyes" in pieces and not name.endswith(".pregnant"):
        pieces = soften_jaw(pieces, gid, name.split(".")[1], SOFT_JAW[gid])
    if name in SMOOTH_CHEEKS and "eyes" in pieces:
        pieces = smooth_cheeks(pieces, gid, name.split(".")[1], SMOOTH_CHEEKS[name])
    if gid in EVEN_MIDFACE and "eyes" in pieces:
        # (the pregnant figure wears the white skin)
        pieces = even_midface(pieces, gid, name.split(".")[1].replace("pregnant", "white"), EVEN_MIDFACE[gid])
    if gid in TUCK_LIPS and "eyes" in pieces:
        pieces = tuck_lips(pieces, *TUCK_LIPS[gid])
    if name in TUCK_LOWER and "eyes" in pieces:
        pieces = tuck_lower(pieces, *TUCK_LOWER[name])
    if gid in CLOSE_LIPS and "eyes" in pieces:
        pieces = close_lips(pieces, *CLOSE_LIPS[gid])
    if gid in TUCK_LIDS and "eyes" in pieces:
        pieces = tuck_lids(pieces, *TUCK_LIDS[gid])
    if gid in HOLLOW_CANTHUS and "eyes" in pieces:
        pieces = hollow_canthus(pieces, *HOLLOW_CANTHUS[gid])
    if gid in SEAT_LASHES and "eyes" in pieces:
        pieces = seat_lashes(pieces, *SEAT_LASHES[gid])
    if gid in SMOOTH_CHEST:
        eyes = pieces["eyes"] if "eyes" in pieces else load(f"{gid}.neutral")["eyes"]
        pieces = dict(pieces, body=smooth_chest(pieces["body"], eyes, SMOOTH_CHEST[gid]))
    if "eyes" in pieces:
        pieces = dict(pieces, body=seat_lining(pieces["body"]))
    before = load(name)
    if "eyes" in before:
        e = before["eyes"]
        U = np.linalg.norm(e[e[:, 0] > 0].mean(0) - e[e[:, 0] < 0].mean(0))
        far = np.linalg.norm(pieces["body"] - before["body"], axis=1).max() / U
        if far > 0.8:
            print(f"  WARNING {name}: a vertex moved {far:.2f} eye spacings")
    np.savez_compressed(RAW / f"{name}.npz", **{f"pos:{k}": v.astype(np.float32) for k, v in pieces.items()})


def variants(gid):
    return sorted(p.name[len(gid) + 1:-4] for p in RAW.glob(f"{gid}.*.npz"))


def starting(gid):
    """each variant as fitted, with the base head where the group takes one"""
    got = {v: load(f"{gid}.{v}") for v in variants(gid)}
    if gid in BASE:
        source, keep, amount = BASE[gid]
        neutral = got["neutral"]
        new, face, placed, under = with_base_head(neutral, gid, source)
        new = {k: neutral[k] + amount * (v - neutral[k]) for k, v in new.items()}
        if gid in HAIR_OF:
            hairs = carry_hair(placed, new["body"], source, new["eyes"])
            pos = np.concatenate([h for h, _ in hairs])
            first = np.cumsum([0] + [len(h) for h, _ in hairs])[:-1]
            tri = np.concatenate([t + o for (_, t), o in zip(hairs, first)])
            np.savez_compressed(RAW / f"sculpt.{HAIR_OF[gid]}.npz", pos=pos.astype(np.float32), tri=tri.astype(np.uint32))
        got = {v: new if v == "neutral" else base_variant(p, neutral, new, face, keep.get(v, keep["*"]) if isinstance(keep, dict) else keep, under)
               for v, p in got.items()}
        got = {v: dict(p, body=untangle(p["body"], under)) for v, p in got.items()}
    return got


def untangle(body, under, passes=80):
    """folds under the chin (the base head's jaw drawn over a variant's own chin) relaxed, there only"""
    import base_head as bh
    _, vmap, tris = topo("body")
    t = vmap[tris]
    fn = np.cross(body[t[:, 1]] - body[t[:, 0]], body[t[:, 2]] - body[t[:, 0]])
    fn /= np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-12)
    vn = vertex_normals(body)
    bend = np.zeros(len(body))
    for k in range(3):
        np.maximum.at(bend, t[:, k], np.degrees(np.arccos(np.clip((fn * vn[t[:, k]]).sum(1), -1, 1))))
    w = bh.smooth(np, (under * smoothstep(20, 40, bend))[:, None], t, len(body), 4)[:, 0]
    w = np.clip(3 * w, 0, 1)[:, None]
    e = np.concatenate([t[:, [0, 1]], t[:, [1, 2]], t[:, [2, 0]]])
    cnt = np.maximum(np.bincount(e.ravel(), minlength=len(body)), 1).astype(float)[:, None]
    p = body.copy()
    for _ in range(passes):
        for step in (0.5, -0.53):
            acc = np.zeros_like(p)
            np.add.at(acc, e[:, 0], p[e[:, 1]])
            np.add.at(acc, e[:, 1], p[e[:, 0]])
            p = p + step * w * (acc / cnt - p)
    return p


def fit_group(gid, avgs, moves):
    start = starting(gid)
    plan = PLAN.get(gid)
    if plan is None:
        if gid in FOLLOW:
            src, k = FOLLOW[gid]
            shared = {v: k * m for v, m in moves[src].items()}
            for v, p in start.items():
                m = shared.get(v, shared["*"])
                save(f"{gid}.{v}", carry(p, m, _local_warp(p["body"], m)))
        else:
            for v, p in start.items():
                save(f"{gid}.{v}", p)
        return
    got = {}
    for her, (groups, strength) in ((h, s) for h, s in plan.items() if h != "*"):
        avg = sum(avgs[g] * avgs[g + ":n"] for g in groups) / sum(avgs[g + ":n"] for g in groups)
        p = start[her]
        total = np.zeros_like(p["body"])
        for i in range(PASSES):
            move, warp, err = face_move(p, gid, her, avg, strength)
            print(f"  {gid}.{her} pass {i}: {err:.3f} U off")
            p = carry(p, move, warp)
            total += move
        save(f"{gid}.{her}", p)
        got[her] = total
    got["*"] = plan["*"] * sum(got.values()) / len(got)
    moves[gid] = got
    for v, p in start.items():
        if v in got and v in plan:
            continue
        m = got["*"]
        save(f"{gid}.{v}", carry(p, m, _local_warp(p["body"], m)))


def seat_all(only=None):
    """seat_lining on the faces as they stand (no refit)"""
    for f in sorted(RAW.glob(f"{only or '*-*'}.*.npz")):
        got = dict(np.load(f))
        if "pos:eyes" not in got:
            continue
        body = got["pos:body"].astype(np.float64)
        new = seat_lining(body)
        moved = np.linalg.norm(new - body, axis=1)
        if moved.max() > 0:
            print(f"  {f.stem}: {(moved > 0).sum()} lining vertices back, at most {moved.max() * 1000:.1f} mm")
            got["pos:body"] = new.astype(np.float32)
            np.savez_compressed(f, **got)


def _local_warp(body, move):
    """a warp following a per-vertex move (for pieces carried along): the move of the nearest body vertices"""
    def f(q):
        i = np.argsort(np.linalg.norm(body[None, :, :] - q[:, None, :], axis=2), axis=1)[:, :6]
        return q + move[i].mean(1)
    return f


def main(only=None):
    avgs = dict(np.load(fl.AVERAGES))
    moves = {}
    for gid in ("female-adult", "male-adult", "female-senior", "male-senior", "kid-child", "kid-toddler", "kid-infant"):
        if only and gid != only and FOLLOW.get(only, (None,))[0] != gid:
            continue
        fit_group(gid, avgs, moves)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "render":
        gid, v, out = sys.argv[2:5]
        Image.fromarray(render(load(f"{gid}.{v}", fitted=True), gid, v)[0]).save(out)
    elif len(sys.argv) > 1 and sys.argv[1] == "seat":
        seat_all(sys.argv[2] if len(sys.argv) > 2 else None)
    else:
        main(sys.argv[1] if len(sys.argv) > 1 else None)
