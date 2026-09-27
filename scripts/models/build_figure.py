"""Skin figures (MakeHuman via MPFB2, CC0) → Resources/Models/figure.bin + skin/hair textures.

All MakeHuman humans share one topology, so every body (sex × age × heritage, pregnant) ships as positions
for the same meshes: one base per piece plus small int16 deltas, deflated. The app picks one and builds the mesh.
Heritage changes the head (face) and the skin texture only; the body shape is fixed per sex.
Children are fitted to the app's age reshaping (BodyScene.proportions) so bones and organs sit inside.

  Blender -b -P build_figure.py -- fit [group]   # MPFB humans → build/models/figure/*.npz
  venv/bin/python build_figure.py pack           # npz → figure.bin, garments, textures
"""

import json
import math
import sys
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from build_models import GEN, OUT, ROOT, TOP, SOLE, fitter, load_index, mesh_coords, save_index, to_scene  # noqa: E402

RAW = ROOT / "build" / "models" / "figure"
FIGURE = OUT / "figure.bin"

HERITAGES = {
    # id: (MakeHuman race macro, skin texture blend)
    "east-asian": ({"asian": 1.0}, {"asian": 1.0}),
    "southeast-asian": ({"asian": 0.7, "african": 0.15, "caucasian": 0.15}, {"asian": 0.62, "african": 0.38}),
    "south-asian": ({"caucasian": 0.5, "asian": 0.2, "african": 0.3}, {"asian": 0.42, "african": 0.58}),
    "hispanic": ({"caucasian": 0.6, "asian": 0.25, "african": 0.15}, {"caucasian": 0.5, "asian": 0.5}),
    "white": ({"caucasian": 1.0}, {"caucasian": 1.0}),
    "black": ({"african": 1.0}, {"african": 1.0}),
}
NEUTRAL = {"asian": 1 / 3, "caucasian": 1 / 3, "african": 1 / 3}
# MakeHuman age macro: 0 = 1 year, 0.1875 = 11, 0.5 = 25, 1 = 90
AGE = {"infant": 0.01, "toddler": 0.02, "child": 0.11, "adult": 0.5, "senior": 0.85}
BUILD = {
    # sex: (macros, extra targets)
    "male": ({"gender": 1.0, "muscle": 0.95, "weight": 0.56, "proportions": 0.9, "height": 0.6},
             {"torso/torso-vshape-incr": 0.35, "torso/torso-muscle-pectoral-incr": 0.25}),
    "female": ({"gender": 0.0, "muscle": 0.55, "weight": 0.5, "proportions": 0.9, "height": 0.5, "cupsize": 0.78, "firmness": 0.75},
               {"hip/hip-scale-horiz-incr": 0.3, "buttocks/buttocks-volume-incr": 0.4, "torso/measure-waist-circ-decr": 0.3,
                "breast/nipple-point-decr": 1.0, "breast/nipple-size-decr": 0.5}),
    "kid": ({"gender": 0.5, "muscle": 0.5, "weight": 0.6, "proportions": 0.5, "height": 0.5}, {}),
}
# group: (sex build, age, hair assets, eyebrows)
GROUPS = {
    "male-adult": ("male", "adult", ["short01"], "eyebrow012", "eyelashes02"),
    "female-adult": ("female", "adult", ["long01"], "eyebrow010", "eyelashes03"),
    "male-senior": ("male", "senior", ["short04"], "eyebrow012", "eyelashes02"),
    "female-senior": ("female", "senior", ["ponytail01"], "eyebrow010", "eyelashes03"),
    "kid-infant": ("kid", "infant", [], "eyebrow006", "eyelashes01"),
    "kid-toddler": ("kid", "toddler", ["short01", "ponytail01"], "eyebrow006", "eyelashes01"),
    "kid-child": ("kid", "child", ["short01", "ponytail01"], "eyebrow006", "eyelashes02"),
}
# a kid group's hairs, split by sex in pack
HAIR_SEX = {"short01": "male", "ponytail01": "female"}
# face modifiers (MakeHuman targets, CC0): a defined, friendly male face; a soft feminine one (no brow ridge,
# arched brows, oval face and tapered chin, fuller lips, open eyes, finer nose). cheek/eye targets apply to both sides.
FACE = {
    "male": {"chin/chin-width-incr": 0.5, "chin/chin-prominent-incr": 0.4, "chin/chin-height-incr": 0.3,
             "head/head-square": 0.5, "head/head-fat-decr": 0.4, "cheek/cheek-volume-decr": 0.3,
             "eyebrows/eyebrows-angle-up": 0.3, "eyes/eye-bag-decr": 0.5, "eyes/eye-scale-incr": 0.3,
             "nose/nose-point-width-decr": 0.4, "nose/nose-hump-decr": 0.4,
             "mouth/mouth-upperlip-volume-incr": 0.3, "mouth/mouth-lowerlip-volume-incr": 0.35, "mouth/mouth-angles-up": 0.2,
             "neck/measure-neck-circ-incr": 0.5},
    "female": {"forehead/forehead-nubian-decr": 1.0, "eyebrows/eyebrows-angle-up": 0.8, "eyebrows/eyebrows-trans-up": 0.3,
               "head/head-oval": 0.7, "head/head-fat-decr": 0.3, "head/head-scale-horiz-decr": 0.3, "head/head-invertedtriangular": 0.35,
               "chin/chin-triangle": 0.5, "chin/chin-width-decr": 0.75, "chin/chin-prominent-incr": 0.15,
               "mouth/mouth-upperlip-volume-incr": 0.45, "mouth/mouth-lowerlip-volume-incr": 0.45, "mouth/mouth-cupidsbow-incr": 0.5,
               "mouth/mouth-angles-up": 0.35, "mouth/mouth-scale-horiz-decr": 0.15,
               "eyes/eye-scale-incr": 0.25, "eyes/eye-bag-decr": 0.5, "eyes/eye-corner2-up": 0.4,
               "nose/nose-scale-horiz-decr": 0.5, "nose/nose-point-width-decr": 0.6, "nose/nose-point-up": 0.35, "nose/nose-scale-vert-decr": 0.55,
               "nose/nose-width1-decr": 0.3, "cheek/cheek-trans-up": 0.3, "neck/measure-neck-circ-decr": 0.5},
    "kid": {"forehead/forehead-nubian-decr": 0.5, "eyebrows/eyebrows-angle-up": 0.4, "eyes/eye-bag-decr": 0.5,
            "mouth/mouth-angles-up": 0.3},
}
# each heritage keeps its own nose and lips: the narrowing targets are toned down where they'd erase them
FACE_SCALE = {"black": {"nose/": 0.2, "mouth/mouth-upperlip-volume": 0.3, "mouth/mouth-lowerlip-volume": 0.3}, "southeast-asian": {"nose/": 0.5}, "east-asian": {"nose/": 0.6, "mouth/mouth-upperlip-volume": 0.0}, "south-asian": {"nose/": 0.8}}
# on top of the race macro: features typical of each heritage at natural strength (both sexes, every age)
HERITAGE_FACE = {
    "east-asian": {"eyes/eye-epicanthus-out": 0.3, "eyes/eye-height2-incr": 0.25, "nose/nose-scale-depth-decr": 0.3,
                   "nose/nose-hump-decr": 0.4, "head/head-back-scale-depth-decr": 0.3, "head/head-scale-horiz-incr": 0.1},
    "southeast-asian": {"eyes/eye-epicanthus-out": 0.35, "nose/nose-flaring-incr": 0.35, "nose/nose-scale-depth-decr": 0.3,
                        "mouth/mouth-lowerlip-volume-incr": 0.25, "head/head-scale-horiz-incr": 0.15},
    "south-asian": {"eyes/eye-scale-incr": 0.15, "nose/nose-point-down": 0.25, "nose/nose-scale-vert-incr": 0.2,
                    "eyebrows/eyebrows-trans-down": 0.15},
    "hispanic": {"nose/nose-hump-incr": 0.2, "cheek/cheek-bones-incr": 0.15, "nose/nose-flaring-incr": 0.15},
    "white": {"nose/nose-scale-depth-incr": 0.2, "nose/nose-width1-decr": 0.2, "eyes/eye-push1-in": 0.2},
    "black": {"nose/nose-flaring-incr": 0.5, "nose/nose-scale-horiz-incr": 0.35, "nose/nose-scale-depth-decr": 0.2,
              "mouth/mouth-upperlip-volume-incr": 0.1, "mouth/mouth-lowerlip-volume-incr": 0.1},
}


def face_targets(sex, age, heritage=None):
    """face modifier targets for this sex/age/heritage; a senior's are softened, a child's heritage features too"""
    out = {}

    def add(t, w):
        d, name = t.split("/")
        for n in [f"l-{name}", f"r-{name}"] if d in ("cheek", "eyes") else [name]:
            out[f"{d}/{n}"] = out.get(f"{d}/{n}", 0) + w
    for t, w in FACE[sex].items():
        w *= 0.7 if age == "senior" else 1.0
        for pre, s in FACE_SCALE.get(heritage, {}).items():
            if t.startswith(pre):
                w *= s
        add(t, w)
    for t, w in HERITAGE_FACE.get(heritage, {}).items():
        add(t, w * (0.6 if sex == "kid" else 1.0))
    return {t: min(w, 1.0) for t, w in out.items()}


PREGNANT = {"stomach/stomach-pregnant-incr": 1.0, "stomach/stomach-navel-out": 0.6}
# MakeHuman's full "pregnant" is about 30 weeks: the bump is scaled up to term (fundus under the ribs)
PREGNANT_GAIN = 1.45

# BodyScene.proportions / reshape, mirrored: children's bodies are reshaped adults
PROPS = {  # body, head, leg length, leg girth, arm length, arm girth, trunk width, trunk depth, neck
    "infant": (0.4, 1.85, 0.72, 1.4, 0.85, 1.3, 1.12, 1.3, 0.3),
    "toddler": (0.5, 1.5, 0.82, 1.25, 0.9, 1.2, 1.08, 1.2, 0.45),
    "child": (0.68, 1.25, 0.95, 1.05, 0.97, 1.05, 1.0, 1.05, 0.75),
}
CHIN_Y, NECK_BASE_Y, LEG_TOP = 1.25, 1.05, -0.04
# a baby's skin head sits lower and further back on the (scaled adult) skull than the landmarks alone put it
HEAD_SHIFT = {"infant": (0.0, -0.025, -0.035), "toddler": (0.0, -0.015, -0.02)}
# MakeHuman's skull base sits higher in the head than the skeleton's: mapped piecewise at it, the face stretches above
# (tall eyes and brow) and squashes below (wide jaw); evened out this much, the eyes stay close to the orbits
HEAD_EVEN = 0.6
HIP, SHOULDER =(0.167, 0.12, 0.0), (0.344, 1.004, -0.056)


def reshape(p, age):
    """adult body point → the same point on this age's body (before the overall scale), as BodyScene.agePoint"""
    if age not in PROPS:
        return tuple(p)
    _, head, leg_l, leg_g, arm_l, arm_g, tw, td, neck = PROPS[age]
    x, y, z = p

    def about(c, s):
        return tuple(c[i] + (p[i] - c[i]) * s[i] for i in range(3))
    side = -1 if x < 0 else 1
    if y > CHIN_Y:
        return (x * head, NECK_BASE_Y + (CHIN_Y - NECK_BASE_Y) * neck + (y - CHIN_Y) * head, z * head)
    if abs(x) > 0.316:
        return about((SHOULDER[0] * side, SHOULDER[1], SHOULDER[2]), (arm_g, arm_l, arm_g))
    if y < LEG_TOP:
        return about((HIP[0] * side, HIP[1], HIP[2]), (leg_g, leg_l, leg_g))
    if y > NECK_BASE_Y:
        return (x * tw, NECK_BASE_Y + (y - NECK_BASE_Y) * neck, z * td)
    return (x * tw, y, z * td)


# ------------------------------------------------------------------ Blender: fit MPFB humans


LIMB_BONES = [(r"upperarm0[12]", "uparm"), (r"lowerarm01", "fore1"), (r"lowerarm02", "fore2"),
              (r"(wrist|metacarpal|finger)", "hand"), (r"upperleg0[12]", "thigh"), (r"lowerleg0[12]", "shin"),
              (r"(foot|toe)", "foot")]


def bone_segment(name):
    import re
    m = re.match(r"(.+)\.([LR])$", name)
    if not m:
        return "trunk"
    for pat, seg in LIMB_BONES:
        if re.match(pat, m[1]):
            return f"{seg}-{m[2].lower()}"
    return "trunk"


def fit_all(only=None):
    import numpy as np
    RAW.mkdir(parents=True, exist_ok=True)
    for gid, (sex, age, hairs, brows, lashes) in GROUPS.items():
        if only and gid != only:
            continue
        # heritage and pregnancy builds reuse the neutral body's fit (heads aligned at the skull base):
        # the same map for every variant, and a child's odd landmarks can't fold the mesh
        look = (hairs, brows, lashes)
        pieces, topo, ref = fit_one(np, sex, age, NEUTRAL, face_targets(sex, age), look)
        save_raw(np, f"{gid}.neutral", pieces, topo)
        for rid, (race, _) in HERITAGES.items():
            pieces, topo, _ = fit_one(np, sex, age, race, face_targets(sex, age, rid), look, ref)
            save_raw(np, f"{gid}.{rid}", pieces, topo)
        if gid == "female-adult":
            pieces, topo, _ = fit_one(np, sex, age, NEUTRAL, {**face_targets(sex, age), **PREGNANT}, look, ref)
            save_raw(np, f"{gid}.pregnant", pieces, topo)


def save_raw(np, name, pieces, topo):
    np.savez_compressed(RAW / f"{name}.npz", **{f"pos:{k}": v for k, v in pieces.items()})
    for k, (uv, vmap, index, poly) in topo.items():
        np.savez_compressed(RAW / f"topo.{k}.npz", uv=uv, vmap=vmap, index=index, poly=poly)
    print("FIGURE", name, {k: len(v) for k, v in pieces.items()})


def fit_one(np, sex, age, race, extra, look, ref=None):
    import importlib
    import os
    import bpy

    def imp(pkg, key):
        for m in list(sys.modules):
            if m.endswith(pkg):
                return getattr(importlib.import_module(m), key)
        raise ImportError(pkg)

    HumanService = imp("mpfb.services.humanservice", "HumanService")
    AssetService = imp("mpfb.services.assetservice", "AssetService")
    TargetService = imp("mpfb.services.targetservice", "TargetService")
    LocationService = imp("mpfb.services.locationservice", "LocationService")

    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)
    macros, targets = BUILD[sex]
    m = TargetService.get_default_macro_info_dict()
    m.update(macros, age=AGE[age])
    # exact 0 / 1 race weights on a baby collapse the mesh in MPFB: keep a trace of every race
    total = sum(max(race.get(r, 0), 0.02) for r in ("asian", "caucasian", "african"))
    m["race"] = {r: max(race.get(r, 0), 0.02) / total for r in ("asian", "caucasian", "african")}
    h = HumanService.create_human(macro_detail_dict=m)
    for t, w in {**targets, **extra}.items():
        TargetService.load_target(h, os.path.join(LocationService.get_mpfb_data("targets"), t + ".target.gz"), weight=w)
    rig = HumanService.add_builtin_rig(h, "default")
    hairs, brows, lashes = look
    assets = [("eyes", "low-poly.mhclo", "Eyes", "eyes"), ("eyebrows", f"{brows}.mhclo", "Eyebrows", f"brows-{brows}"),
              ("eyelashes", f"{lashes}.mhclo", "Eyelashes", f"lashes-{lashes}")]
    assets += [("hair", f"{hair}.mhclo", "Hair", f"hair-{hair}") for hair in hairs]
    objs = {"body": h}
    for sub, f, kind, key in assets:
        before = set(bpy.data.objects)
        HumanService.add_mhclo_asset(AssetService.find_asset_absolute_path(f, asset_subdir=sub), h, asset_type=kind, subdiv_levels=0)
        objs[key] = next(iter(set(bpy.data.objects) - before))
    bones = {b.name: b for b in rig.data.bones}
    W = lambda n: to_scene(np, np.array([rig.matrix_world @ bones[n].head_local]))[0]
    Wt = lambda n: to_scene(np, np.array([rig.matrix_world @ bones[n].tail_local]))[0]
    src = {"neck": W("head")}
    for side, S in (("l", "L"), ("r", "R")):
        src.update({f"shoulder-{side}": W(f"upperarm01.{S}"), f"elbow-{side}": W(f"lowerarm01.{S}"),
                    f"wrist-{side}": W(f"wrist.{S}"), f"finger-{side}": Wt(f"finger3-3.{S}"),
                    f"hip-{side}": W(f"upperleg01.{S}"), f"knee-{side}": W(f"lowerleg01.{S}"),
                    f"ankle-{side}": W(f"foot.{S}"), f"toe-{side}": Wt(f"toe1-2.{S}"),
                    f"lateral-{side}": W(f"finger2-1.{S}") - W(f"finger5-1.{S}")})
    dg = bpy.context.evaluated_depsgraph_get()
    meshes = {}
    for key, o in objs.items():
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
        me.transform(o.matrix_world)
        meshes[key] = (o, me)
    body_raw = to_scene(np, mesh_coords(np, meshes["body"][1]))
    if os.environ.get("FIGURE_DEBUG"):
        print("FIGURE src", age, {k: np.round(v, 3).tolist() for k, v in src.items() if k[-1] != "r"}, round(body_raw[:, 1].max(), 3), round(body_raw[:, 1].min(), 3))
        print("FIGURE target", age, age_target(np, src, body_raw[:, 1].max(), age))
    shift = np.zeros(3)
    if ref is None:
        ref = (src, body_raw[:, 1].max(), body_raw[:, 1].min())
    else:
        shift = ref[0]["neck"] - src["neck"]
    rsrc, rtop, rsole = ref
    fit = fitter(np, rsrc, rtop, rsole, "skin", head_even=HEAD_EVEN, **age_target(np, rsrc, rtop, age))[0]

    pieces, topo = {}, {}
    for key, (o, me) in meshes.items():
        raw = to_scene(np, mesh_coords(np, me)) + shift
        groups = {g.index: bone_segment(g.name) for g in o.vertex_groups if g.name in bones}
        keys = sorted(set(groups.values()) | {"trunk"})
        wts = np.zeros((len(me.vertices), len(keys)))
        for v in me.vertices:
            for g in v.groups:
                if g.group in groups and g.weight > 0:
                    wts[v.index, keys.index(groups[g.group])] += g.weight
        wts[wts.sum(1) == 0, keys.index("trunk")] = 1
        wts /= wts.sum(1, keepdims=True)
        out = np.zeros_like(raw)
        for i, k in enumerate(keys):
            sel = wts[:, i] > 0
            if sel.any():
                out[sel] += fit(raw[sel], k) * wts[sel, i:i + 1]
        if age in HEAD_SHIFT:
            sh, nk = reshape(GEN["shoulder"], age)[1], reshape(GEN["neck"], age)[1]
            t = np.clip((out[:, 1] - sh) / (nk - sh), 0, 1)
            out += (t * t * (3 - 2 * t))[:, None] * np.array(HEAD_SHIFT[age])
        pieces[key] = out.astype(np.float32)
        topo[key] = topology(np, me)
    return pieces, topo, ref


def age_target(np, src, top_src, age):
    """Fitter landmarks for a child: the adult landmarks pushed through the app's reshape."""
    if age not in PROPS:
        return {}
    gen = {k: reshape(v, age) for k, v in GEN.items()}
    top = reshape((0, TOP["skin"], 0), age)[1]
    sole = reshape((HIP[0], SOLE, 0), age)[1]
    tw, td = PROPS[age][6], PROPS[age][7]
    mid = lambda k: (src[k + "-l"] + src[k + "-r"]) / 2
    hx = gen["hip"][0] / abs(src["hip-l"][0])
    sx = gen["shoulder"][0] / abs(src["shoulder-l"][0])
    head = (top - gen["neck"][1]) / (top_src - src["neck"][1])
    del mid
    return dict(gen=gen, top=top, sole=sole, widths=[(hx, hx * td / tw), (sx, sx * td / tw), (head, head), (head, head)])


def topology(np, me):
    """render vertices = unique (vertex, uv) corners; returns uv, render→vertex map, triangle indices, source face"""
    me.calc_loop_triangles()
    tri = np.empty(len(me.loop_triangles) * 3, dtype=np.int64)
    me.loop_triangles.foreach_get("loops", tri)
    poly = np.empty(len(me.loop_triangles), dtype=np.int64)
    me.loop_triangles.foreach_get("polygon_index", poly)
    lv = np.empty(len(me.loops), dtype=np.int64)
    me.loops.foreach_get("vertex_index", lv)
    uv = np.empty(len(me.loops) * 2)
    me.uv_layers.active.data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    key = np.stack([lv, np.round(uv[:, 0] * 16384).astype(np.int64), np.round(uv[:, 1] * 16384).astype(np.int64)], 1)
    uniq, first, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
    return uv[first].astype(np.float32), lv[first].astype(np.uint32), inv.reshape(-1)[tri].astype(np.uint32), poly.astype(np.uint32)


# ------------------------------------------------------------------ pack (plain Python + numpy + PIL)


def smoothstep(a, b, x):
    import numpy as np
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


class Packer:
    def __init__(self, np):
        self.np, self.chunks, self.size, self.blocks = np, [], 0, []

    def add(self, arr):
        arr = self.np.ascontiguousarray(arr)
        pad = (-self.size) % 4
        if pad:
            self.chunks.append(b"\0" * pad)
            self.size += pad
        off = self.size
        self.chunks.append(arr.tobytes())
        self.size += arr.nbytes
        return off

    def block(self, pos, ref=None, ref_pos=None):
        """positions as int16 steps from a reference block (or from zero)"""
        np = self.np
        d = pos - (ref_pos if ref is not None else 0)
        # fixed fine step (≈0.01 mm): small deltas stay small integers and deflate well
        step = np.maximum(np.abs(d).max(0) / 32000, 2e-5)
        lo = -32767 * step
        q = np.round((d - lo) / step - 32767).astype(np.int16)
        self.blocks.append({"ref": ref, "offset": self.add(q), "count": len(pos), "lo": lo.tolist(), "step": step.tolist()})
        return len(self.blocks) - 1

    def decode(self, i):
        b = self.blocks[i]
        np = self.np
        raw = b"".join(self.chunks)[b["offset"]:b["offset"] + b["count"] * 6]
        q = np.frombuffer(raw, dtype=np.int16).reshape(-1, 3).astype(np.float64)
        p = (q + 32767) * np.array(b["step"]) + np.array(b["lo"])
        return p + (self.decode(b["ref"]) if b["ref"] is not None else 0)


def pack():
    import numpy as np
    load = lambda n: {k[4:]: v.astype(np.float64) for k, v in np.load(RAW / f"{n}.npz").items()}
    topo = {p.name.split(".")[1]: dict(np.load(p)) for p in RAW.glob("topo.*.npz")}
    pk = Packer(np)
    header = {"pieces": {}, "blocks": pk.blocks, "variants": {}, "garments": {}}
    for k, t in topo.items():
        header["pieces"][k] = {"vertices": int(t["vmap"].max()) + 1, "render": len(t["vmap"]), "triangles": len(t["index"]) // 3,
                               "uv": pk.add(np.round(t["uv"].clip(0, 1) * 65535).astype(np.uint16)),
                               "vmap": pk.add(t["vmap"].astype(np.uint32)), "index": pk.add(t["index"].astype(np.uint32))}
    base_block = {}

    def put(piece, pos, ref_key=None):
        """deltas against the group's neutral piece; the neutral piece itself is absolute"""
        if ref_key is None:
            i = pk.block(pos)
        else:
            ref = base_block[ref_key]
            i = pk.block(pos, ref, pk.decode(ref))
        return i

    variants = header["variants"]
    for gid, (sex, age, hairs, _, _) in GROUPS.items():
        neutral = load(f"{gid}.neutral")
        for k, v in neutral.items():
            base_block[(gid, k)] = put(k, v)
            neutral[k] = pk.decode(base_block[(gid, k)])
        body0 = neutral["body"]
        y = body0[:, 1]
        # heritage reaches from the neck up; the body below keeps the sex's shape
        gen = {k: reshape(v, age) for k, v in GEN.items()}
        sh, nk = gen["shoulder"][1], gen["neck"][1]
        w = smoothstep(sh + 0.3 * (nk - sh), sh + 0.8 * (nk - sh), y)[:, None]
        preg = load(f"{gid}.pregnant") if gid == "female-adult" else None
        for her in HERITAGES:
            got = load(f"{gid}.{her}")
            body = body0 + w * (got["body"] - body0)
            entry = {"body": put("body", body, (gid, "body"))}
            for k, v in got.items():
                if k != "body":
                    entry[k] = put(k, v, (gid, k))
            sexes = ["male", "female"] if sex == "kid" else [sex]
            for s in sexes:
                hair = [h for h in hairs if HAIR_SEX[h] == s] if sex == "kid" else hairs
                pieces = {k: v for k, v in entry.items() if not k.startswith("hair-") or k[5:] in hair}
                variants[f"{s}.{age}.{her}"] = pieces
            if preg is not None:
                pb = body + PREGNANT_GAIN * (preg["body"] - body0)
                variants[f"female.pregnant.{her}"] = {**entry, "body": put("body", pb, (gid, "body"))}
    header["garments"] = garments(np, pk, topo["body"], load("male-adult.neutral")["body"], load("female-adult.neutral")["body"],
                                  load("kid-toddler.neutral")["body"])
    payload = b"".join(pk.chunks)
    comp = zlib.compressobj(9, zlib.DEFLATED, -15)
    data = comp.compress(payload) + comp.flush()
    head = json.dumps(header, separators=(",", ":")).encode()
    FIGURE.write_bytes(b"EBF1" + len(head).to_bytes(4, "little") + len(payload).to_bytes(4, "little") + head + data)
    print(f"FIGURE {FIGURE.name}: {len(variants)} variants, {len(pk.blocks)} blocks, payload {len(payload) // 1024} KB → {FIGURE.stat().st_size // 1024} KB")
    textures(scalp_masks(np, topo["body"]))
    index = load_index()
    index.pop("skins", None)
    index["figure"] = {"file": FIGURE.name, "source": "MakeHuman (MPFB2)", "license": "CC0",
                       "variants": sorted(variants), "triangles": {k: v["triangles"] for k, v in header["pieces"].items()}}
    save_index(index)


# ------------------------------------------------------------------ underwear: body triangles, pushed out along the normal


def garments(np, pk, topo, male, female, kid):
    """Underwear as the parts of the body where a smooth field is positive, cut exactly along its zero line.
    Each garment vertex is a point in a body triangle, so it follows every sex/age/heritage variant.
    Fields are written on the neutral adult male / female and the toddler (children share them: same topology)."""
    vmap, index = topo["vmap"], topo["index"].reshape(-1, 3)
    tris = np.unique(vmap[index], axis=0)  # position-vertex triangles (seams collapse)

    def ramp(v, a, b):
        t = np.clip((v - a) / (b - a), 0, 1)
        return t * t * (3 - 2 * t)

    def smin(a, b, k):
        h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
        return b + (a - b) * h - k * h * (1 - h)

    def smax(a, b, k):
        return -smin(-a, -b, k)

    def legs(x, y, z, front_y, front_slope, back_y, back_slope, cap):
        """leg openings: rise from the crotch to the hip, lower at the back over the buttocks; a band stays at the side"""
        ax = np.abs(x)
        front = np.minimum(front_y + front_slope * np.clip(ax - 0.025, 0, None), cap)
        back = np.minimum(back_y + back_slope * np.clip(ax - 0.02, 0, None), cap)
        w = ramp(z, -0.05, 0.05)
        return y - (w * front + (1 - w) * back)

    def briefs_male(p):
        x, y, z = p.T
        return np.minimum.reduce([0.24 - y, legs(x, y, z, -0.045, 0.9, -0.085, 0.5, 0.15), 0.31 - np.abs(x)])

    def briefs_female(p):
        x, y, z = p.T
        return np.minimum.reduce([0.25 - y, legs(x, y, z, -0.05, 1.0, -0.075, 0.5, 0.15), 0.36 - np.abs(x)])

    apex = female[(female[:, 1] > 0.6) & (female[:, 1] < 0.95) & (female[:, 0] > 0.02) & (female[:, 0] < 0.24)]
    apex = apex[np.argmax(apex[:, 2])]

    def bra(p):
        x, y, z = p.T
        ax = np.abs(x)
        ay = apex[1]
        centre = apex - np.array([0.015, 0.0, 0.075])
        sx = apex[0] - 0.01 - 0.02 * ramp(-z, -0.03, 0.03)  # strap line: over the cup in front, a little inward at the back
        # a sphere round each breast, its top a curve rising from the centre gore to the strap
        top = ay - 0.005 + 0.11 * np.clip((ax - 0.03) / (sx - 0.03), 0, 1.2)
        cups = smin(0.125 - np.sqrt((ax - centre[0]) ** 2 + (y - centre[1]) ** 2 + (z - centre[2]) ** 2), top - y, 0.01)
        lo, hi = ay - 0.15, ay - 0.085
        band = smin(smin(y - lo, hi - y, 0.01), 0.27 - ax, 0.01)
        # centre gore: the cups' neckline carried on down to a soft V between them
        gore = smin(smin(y - lo, np.minimum(top, ay - 0.005) - 0.9 * np.clip(0.03 - ax, 0, None) - y, 0.01),
                    smin(apex[0] - ax, z, 0.01), 0.01)
        strap = smin(smin(0.02 - np.abs(ax - sx), 1.2 - y, 0.01), y - (ay + 0.06) + ramp(-z, 0, 0.02) * 0.155, 0.01)
        # smooth unions: the straps flow into the cups, the cups into the band, no corners
        return smax(smax(smax(cups, gore, 0.02), band, 0.015), strap, 0.03)

    kid_hip, kid_crotch = reshape(GEN["hip"], "toddler")[1], -0.075

    def nappy(p):
        x, y, z = p.T
        return np.minimum.reduce([kid_hip + 0.17 - y, legs(x, y, z, kid_crotch - 0.03, 0.55, kid_crotch - 0.04, 0.4, kid_hip + 0.09), 0.36 - np.abs(x)])

    def briefs_kid(p):
        x, y, z = p.T
        return np.minimum.reduce([kid_hip + 0.14 - y, legs(x, y, z, kid_crotch - 0.01, 0.9, kid_crotch - 0.03, 0.5, kid_hip + 0.07), 0.36 - np.abs(x)])

    def top_kid(p):
        x, y, z = p.T
        ax = np.abs(x)
        body = np.minimum.reduce([y - 0.6, 0.9 - y, 0.26 - ax])
        strap = np.minimum.reduce([0.035 - np.abs(ax - 0.12), 1.06 - y, y - 0.85])
        return np.maximum(body, strap)

    def clip(field, pos, n=4):
        """positive part of the body, each triangle split n×n so the cut follows the field smoothly.
        A vertex is a barycentric point of a body triangle ((a, b, c), weights of a and b) plus its field value:
        about its distance to the garment's edge (hem shading, a softer lift at the edge)."""
        cand = tris[field(pos)[tris].max(1) > -0.04]
        grid = [(i, j) for i in range(n + 1) for j in range(n + 1 - i)]
        bary = np.array([(i / n, j / n, 1 - (i + j) / n) for i, j in grid])
        at = {g: k for k, g in enumerate(grid)}
        cells = [(at[(i, j)], at[(i + 1, j)], at[(i, j + 1)]) for i, j in grid if i + j < n]
        cells += [(at[(i + 1, j)], at[(i + 1, j + 1)], at[(i, j + 1)]) for i, j in grid if i + j < n - 1]
        pts = np.einsum("mk,tkd->tmd", bary, pos[cand])
        fs = field(pts.reshape(-1, 3)).reshape(len(cand), len(grid))
        verts, fval, out = {}, [], []

        def vid(tri, w, f):
            ws = {}
            for i, x in zip(tri, w):
                if x > 1e-6:
                    ws[int(i)] = ws.get(int(i), 0.0) + float(x)
            key = tuple(sorted((i, round(x, 5)) for i, x in ws.items()))
            if key not in verts:
                verts[key] = len(verts)
                fval.append(max(float(f), 0.0))
            return verts[key]

        for tri, f in zip(cand, fs):
            if f.max() <= 0:
                continue
            for cell in cells:
                if f[list(cell)].max() <= 0:
                    continue
                poly = []
                for k in range(3):
                    a, b = cell[k], cell[(k + 1) % 3]
                    fa, fb = f[a], f[b]
                    if fa > 0:
                        poly.append(vid(tri, bary[a], fa))
                    if (fa > 0) != (fb > 0):
                        t = fa / (fa - fb)
                        poly.append(vid(tri, bary[a] + t * (bary[b] - bary[a]), 0.0))
                for k in range(1, len(poly) - 1):
                    if len({poly[0], poly[k], poly[k + 1]}) == 3:
                        out.append((poly[0], poly[k], poly[k + 1]))
        keys = sorted(verts, key=verts.get)
        abc = np.array([[k[min(i, len(k) - 1)][0] for i in range(3)] for k in keys], dtype=np.uint32)
        w = np.array([[k[i][1] if i < len(k) else 0.0 for i in range(2)] for k in keys], dtype=np.float32)
        return abc, w, np.array(fval, dtype=np.float32), np.array(out, dtype=np.uint32)

    out = {}
    for name, pos, field, lift, color in (
            ("briefs-male", male, briefs_male, 0.004, "#2F3947"),
            ("briefs-female", female, briefs_female, 0.004, "#D4B2AA"),
            ("bra", female, bra, 0.0045, "#D4B2AA"),
            ("nappy", kid, nappy, 0.014, "#F4F2EE"),
            ("briefs-kid", kid, briefs_kid, 0.004, "#7FA6CF"),
            ("top-kid", kid, top_kid, 0.005, "#7FA6CF")):
        abc, w, f, tri = clip(field, pos)
        # the field isn't a distance: measure each vertex's distance to the cut edge on the neutral body instead
        wc = 1 - w.sum(1)
        p = w[:, :1] * pos[abc[:, 0]] + w[:, 1:] * pos[abc[:, 1]] + wc[:, None] * pos[abc[:, 2]]
        rim = p[f == 0]
        f = np.concatenate([np.linalg.norm(p[i:i + 512, None] - rim[None], axis=2).min(1)
                            for i in range(0, len(p), 512)]).astype(np.float32)
        out[name] = {"vertices": len(f), "triangles": len(tri), "abc": pk.add(abc), "w": pk.add(w), "f": pk.add(f),
                     "index": pk.add(tri), "lift": lift, "color": color}
        print("GARMENT", name, len(f), len(tri))
    return out


# ------------------------------------------------------------------ textures


def mpfb_data():
    import os
    tools = Path(os.environ.get("EVERYBODY_TOOLS") or ROOT / "tools")
    return tools / "blender-user" / "extensions" / ".user" / "user_default" / "mpfb" / "data"


SKIN_TEX = 1536
HAIR_TEX = 1024


# hair colour per heritage (sRGB), also in Figure.hairColor: the hair texture is grey strands tinted by it
HAIR_COLOR = {"white": (105, 81, 62), "hispanic": (62, 46, 36), "south-asian": (42, 34, 30), "southeast-asian": (42, 34, 30),
              "east-asian": (36, 30, 27), "black": (36, 30, 27), "grey": (200, 198, 194)}
# which groups' hair lies on each skin texture (children: the young female skin with their own scalp)
SCALP = {("male", "young"): ["male-adult"], ("male", "old"): ["male-senior"],
         ("female", "young"): ["female-adult"], ("female", "old"): ["female-senior"], ("kid", "young"): ["kid-toddler", "kid-child"]}


def vertex_normals(np, p, tris):
    f = np.cross(p[tris[:, 1]] - p[tris[:, 0]], p[tris[:, 2]] - p[tris[:, 0]])
    n = np.zeros_like(p)
    for k in range(3):
        np.add.at(n, tris[:, k], f)
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)


def hair_cover(np, piece, hair, origins, dirs, reach=0.08):
    """per ray (skin point, outward normal): how solid the hair it meets within `reach` is (its texture's alpha there)"""
    from PIL import Image, ImageFilter
    t = dict(np.load(RAW / f"topo.{piece}.npz"))
    f = next((mpfb_data() / "hair" / piece[5:]).glob("*_diffuse.png"))
    alpha = Image.open(f).convert("RGBA").getchannel("A").resize((256, 256), Image.BILINEAR).filter(ImageFilter.BoxBlur(3))
    alpha = np.asarray(alpha).astype(np.float32) / 255
    tri = t["index"].reshape(-1, 3)
    a, b, c = (hair[t["vmap"][tri[:, k]]] for k in range(3))
    ua, ub, uc = (t["uv"][tri[:, k]] for k in range(3))
    e1, e2 = b - a, c - a
    out = np.zeros(len(origins))
    for i in range(0, len(origins), 64):
        o, d = origins[i:i + 64, None], dirs[i:i + 64, None]
        h = np.cross(d, e2[None])
        det = np.einsum("ijk,jk->ij", h, e1)
        inv = 1 / np.where(np.abs(det) > 1e-12, det, 1e-12)
        s = o - a[None]
        u = np.einsum("ijk,ijk->ij", s, h) * inv
        q = np.cross(s, e1[None])
        v = np.einsum("ijk,ijk->ij", np.broadcast_to(d, q.shape), q) * inv
        dist = np.einsum("jk,ijk->ij", e2, q) * inv
        hit = (np.abs(det) > 1e-12) & (u >= 0) & (v >= 0) & (u + v <= 1) & (dist > -0.005) & (dist < reach)
        uv = (1 - u - v)[..., None] * ua[None] + u[..., None] * ub[None] + v[..., None] * uc[None]
        px = alpha[np.clip(((1 - uv[..., 1]) * 256).astype(int), 0, 255), np.clip((uv[..., 0] * 256).astype(int), 0, 255)]
        out[i:i + 64] = np.where(hit, px, 0).max(1)
    return out


def scalp_masks(np, topo):
    """(sex, young/old) → how much of each skin texel lies under that skin's hair: the scalp takes the hair's colour,
    so gaps between hair cards and the see-through hair of the acupuncture view read as hair, not a bald head"""
    from PIL import Image, ImageDraw, ImageFilter
    uv, vmap, index = topo["uv"], topo["vmap"], topo["index"].reshape(-1, 3)
    out = {}
    for key, groups in SCALP.items():
        under = np.zeros(int(vmap.max()) + 1)
        for gid in groups:
            got = {k[4:]: v for k, v in np.load(RAW / f"{gid}.neutral.npz").items()}
            body, eyes = got["body"], got["eyes"]
            normal = vertex_normals(np, body, vmap[index])
            cand = np.where(body[:, 1] > eyes[:, 1].max() + 0.02)[0]
            for name, hair in ((k, v) for k, v in got.items() if k.startswith("hair-")):
                # solid hair straight out along the skin's normal (the forehead under see-through hair tips stays skin)
                cover = hair_cover(np, name, hair, body[cand], normal[cand])
                under[cand] = np.maximum(under[cand], smoothstep(0.3, 0.7, cover))
        im = Image.new("L", (SKIN_TEX, SKIN_TEX), 0)
        draw = ImageDraw.Draw(im)
        w = under[vmap]
        for tri in index:
            v = w[tri].mean()
            if v > 0.02:
                draw.polygon([(uv[i, 0] * SKIN_TEX, (1 - uv[i, 1]) * SKIN_TEX) for i in tri], fill=int(v * 255))
        # a child's (and a baby's bare) scalp: a soft, lighter wash of hair colour
        soft = key[0] == "kid"
        im = im.filter(ImageFilter.MinFilter(5)).filter(ImageFilter.GaussianBlur(12 if soft else 4))
        out[key] = np.asarray(im).astype(np.float32)[..., None] / 255 * (0.6 if soft else 1)
    return out


def textures(scalp=None):
    import numpy as np
    from PIL import Image
    data = mpfb_data()

    def skin(age, race, sex):
        f = next((data / "skins" / f"{age}_{race}_{sex}").glob("*diffuse*.png"))
        return np.asarray(Image.open(f).convert("RGB").resize((SKIN_TEX, SKIN_TEX), Image.LANCZOS)).astype(np.float32)

    cache = {}
    for her, (_, blend) in HERITAGES.items():
        # children wear the young female skin (no stubble or body hair)
        for sex, age, name in (("male", "young", "male-young"), ("male", "old", "male-old"), ("female", "young", "female-young"),
                               ("female", "old", "female-old"), ("kid", "young", "kid")):
            src = "female" if sex == "kid" else sex
            px = sum(w * cache.setdefault((age, r, src), skin(age, r, src)) for r, w in blend.items())
            px = areolae(np, px, {"male": 14, "female": 17, "kid": 12}[sex])
            if scalp:
                m = scalp[(sex, age)]
                hair = np.array(HAIR_COLOR["grey" if age == "old" else her], dtype=np.float32)
                lum = px @ np.array([0.3, 0.59, 0.11])
                grain = (lum / max(float(np.median(lum)), 1))[..., None] ** 0.5
                px = px * (1 - 0.92 * m) + hair * grain * 0.92 * m
            Image.fromarray(np.clip(px, 0, 255).astype(np.uint8)).save(OUT / f"skin-{her}-{name}.jpg", quality=80, optimize=True)
    for old in list(OUT.glob("brows-*")) + list(OUT.glob("lashes*")) + list(OUT.glob("hair-*")):
        old.unlink()
    for name in sorted({g[3] for g in GROUPS.values()}):
        alpha_pair(Image.open(data / "eyebrows" / name / f"{name}.png"), f"brows-{name}", 512, grey=True, alpha_gain=1.3)
    for name in sorted({g[4] for g in GROUPS.values()}):
        alpha_pair(Image.open(data / "eyelashes" / name / f"{name}.png"), f"lashes-{name}", 256)
    for hair in sorted({h for g in GROUPS.values() for h in g[2]}):
        # strands only (grey, even brightness): the app tints them per heritage, silver for seniors
        alpha_pair(Image.open(next((data / "hair" / hair).glob("*_diffuse.png"))), f"hair-{hair}", HAIR_TEX, grey=True)
    # underwear shade across its hem: u = distance from the edge / Figure.hem; the edge rolls a little darker
    u = (np.arange(128) + 0.5) / 128
    shade = 0.8 + 0.2 * smoothstep(0.0, 0.3, u)
    Image.fromarray(np.repeat((np.clip(shade, 0, 1) * 255).astype(np.uint8)[None], 4, 0), "L").save(OUT / "fabric.png", optimize=True)
    eye = np.asarray(Image.open(data / "eyes" / "materials" / "brown_eye.png").convert("RGB").resize((512, 512), Image.LANCZOS)).astype(np.float32) / 255
    # MakeHuman's "brown" iris reads red at phone size: tone it to a dark brown
    lum = eye @ np.array([0.3, 0.59, 0.11])
    iris = (lum < 0.45)[..., None]
    eye = np.where(iris, lum[..., None] * np.array([1.0, 0.7, 0.45]) * 1.5, lum[..., None] + 0.35 * (eye - lum[..., None]))
    Image.fromarray((np.clip(eye, 0, 1) * 255).astype(np.uint8)).save(OUT / "eyes.jpg", quality=85)
    for old in list(OUT.glob("skin-*.usdz")):
        old.unlink()


AREOLA_UV = [(0.436, 0.700), (0.325, 0.700)]  # near the nipples in MakeHuman's body UVs (found per texture)


def areolae(np, px, radius):
    """MakeHuman's nipples are a small pink dot: a soft brown areola instead, a shade of the skin around it"""
    from PIL import Image, ImageFilter
    size = px.shape[0]
    lum = px @ np.array([0.3, 0.59, 0.11])
    bg = np.stack([np.asarray(Image.fromarray(np.clip(px[..., c], 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(radius * 2)))
                   for c in range(3)], -1).astype(np.float32)
    red = (px[..., 0] - px[..., 1]) - (bg[..., 0] - bg[..., 1]) + (bg @ np.array([0.3, 0.59, 0.11]) - lum)
    yy, xx = np.mgrid[0:size, 0:size]
    out = px.copy()
    for u, v in AREOLA_UV:
        cx, cy, w = int(u * size), int((1 - v) * size), size // 20
        win = red[cy - w:cy + w, cx - w:cx + w]
        dy, dx = np.unravel_index(np.argmax(win), win.shape)
        cx, cy = cx - w + dx, cy - w + dy
        d = np.hypot(xx - cx, yy - cy) / radius
        m = (1 - smoothstep(0.5, 1.3, d))[..., None]
        core = (1 - smoothstep(0.2, 0.45, d))[..., None]
        base = bg[cy, cx]
        shade = base * np.array([0.76, 0.64, 0.56]) * (1 - 0.12 * core)
        out = out * (1 - m) + (shade + 0.35 * (px - bg)) * m
    return out


def alpha_pair(im, name, size, grey=False, alpha_gain=1.0):
    """colour as JPEG (see-through texels filled with the mean strand colour) + alpha as a grey PNG;
    grey: strand detail only, the large-scale colour and shading evened out, around a light mean for tinting"""
    import numpy as np
    from PIL import Image, ImageFilter
    im = im.convert("RGBA")
    if im.width > size:
        im = im.resize((size, size * im.height // im.width), Image.LANCZOS)
    px = np.asarray(im).astype(np.float32)
    solid = px[..., 3] > 127
    rgb = px[..., :3]
    rgb[~solid] = rgb[solid].mean(0)
    if grey:
        lum = rgb @ np.array([0.3, 0.59, 0.11])
        broad = np.asarray(Image.fromarray(np.clip(lum, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(size / 24))).astype(np.float32)
        detail = np.clip(lum / np.maximum(broad, 8), 0.4, 1.6)
        rgb = np.repeat((200 * (1 + 0.8 * (detail - 1)))[..., None], 3, -1)
    Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).save(OUT / f"{name}.jpg", quality=82, optimize=True)
    Image.fromarray(np.clip(px[..., 3] * alpha_gain, 0, 255).astype(np.uint8), "L").save(OUT / f"{name}-alpha.png", optimize=True)


# ------------------------------------------------------------------ reading figure.bin back (points, checks)


def read_figure(np, path=FIGURE):
    raw = path.read_bytes()
    n = int.from_bytes(raw[4:8], "little")
    header = json.loads(raw[12:12 + n])
    payload = zlib.decompress(raw[12 + n:], -15)

    def arr(off, dtype, count):
        return np.frombuffer(payload, dtype=dtype, count=count, offset=off)

    def block(i):
        b = header["blocks"][i]
        q = arr(b["offset"], np.int16, b["count"] * 3).reshape(-1, 3).astype(np.float64)
        p = (q + 32767) * np.array(b["step"]) + np.array(b["lo"])
        return p + (block(b["ref"]) if b["ref"] is not None else 0)

    def piece(name):
        info = header["pieces"][name]
        return (arr(info["vmap"], np.uint32, info["render"]), arr(info["index"], np.uint32, info["triangles"] * 3).reshape(-1, 3))
    return header, block, piece


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    mode = args[0] if args else "pack"
    if mode == "fit":
        fit_all(args[1] if len(args) > 1 else None)
    elif mode == "textures":
        textures()
    else:
        pack()
