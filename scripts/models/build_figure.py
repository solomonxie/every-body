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
    "male-adult": ("male", "adult", ["short02"], "eyebrow001"),
    "female-adult": ("female", "adult", ["ponytail01"], "eyebrow009"),
    "male-senior": ("male", "senior", ["short02"], "eyebrow001"),
    "female-senior": ("female", "senior", ["short04"], "eyebrow009"),
    "kid-infant": ("kid", "infant", [], "eyebrow009"),
    "kid-toddler": ("kid", "toddler", ["short02", "ponytail01"], "eyebrow009"),
    "kid-child": ("kid", "child", ["short02", "ponytail01"], "eyebrow009"),
}
PREGNANT = {"stomach/stomach-pregnant-incr": 1.0}

# BodyScene.proportions / reshape, mirrored: children's bodies are reshaped adults
PROPS = {  # body, head, leg length, leg girth, arm length, arm girth, trunk width, trunk depth, neck
    "infant": (0.4, 1.85, 0.72, 1.4, 0.85, 1.3, 1.12, 1.3, 0.3),
    "toddler": (0.5, 1.5, 0.82, 1.25, 0.9, 1.2, 1.08, 1.2, 0.45),
    "child": (0.68, 1.25, 0.95, 1.05, 0.97, 1.05, 1.0, 1.05, 0.75),
}
CHIN_Y, NECK_BASE_Y, LEG_TOP = 1.25, 1.05, -0.04
# a baby's skin head sits lower and further back on the (scaled adult) skull than the landmarks alone put it
HEAD_SHIFT = {"infant": (0.0, -0.025, -0.035), "toddler": (0.0, -0.015, -0.02)}
HIP, SHOULDER = (0.167, 0.12, 0.0), (0.344, 1.004, -0.056)


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
    for gid, (sex, age, hairs, brows) in GROUPS.items():
        if only and gid != only:
            continue
        # heritage and pregnancy builds reuse the neutral body's fit (heads aligned at the skull base):
        # the same map for every variant, and a child's odd landmarks can't fold the mesh
        pieces, topo, ref = fit_one(np, sex, age, NEUTRAL, {}, hairs, brows)
        save_raw(np, f"{gid}.neutral", pieces, topo)
        for rid, (race, _) in HERITAGES.items():
            pieces, topo, _ = fit_one(np, sex, age, race, {}, hairs, brows, ref)
            save_raw(np, f"{gid}.{rid}", pieces, topo)
        if gid == "female-adult":
            pieces, topo, _ = fit_one(np, sex, age, NEUTRAL, PREGNANT, hairs, brows, ref)
            save_raw(np, f"{gid}.pregnant", pieces, topo)


def save_raw(np, name, pieces, topo):
    np.savez_compressed(RAW / f"{name}.npz", **{f"pos:{k}": v for k, v in pieces.items()})
    for k, (uv, vmap, index, poly) in topo.items():
        np.savez_compressed(RAW / f"topo.{k}.npz", uv=uv, vmap=vmap, index=index, poly=poly)
    print("FIGURE", name, {k: len(v) for k, v in pieces.items()})


def fit_one(np, sex, age, race, extra, hairs, brows, ref=None):
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
    assets = [("eyes", "low-poly.mhclo", "Eyes", "eyes"), ("eyebrows", f"{brows}.mhclo", "Eyebrows", f"brows-{brows}"),
              ("eyelashes", "eyelashes01.mhclo", "Eyelashes", "lashes")]
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
    fit = fitter(np, rsrc, rtop, rsole, "skin", **age_target(np, rsrc, rtop, age))[0]

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
    for gid, (sex, age, hairs, brows) in GROUPS.items():
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
            kids = [("", None)] if sex != "kid" else [("", None)]
            for suffix, _ in kids:
                pass
            sexes = ["male", "female"] if sex == "kid" else [sex]
            for s in sexes:
                hair = [h for h in hairs if (h == "short02") == (s == "male")] if sex == "kid" else hairs
                pieces = {k: v for k, v in entry.items() if not k.startswith("hair-") or k[5:] in hair}
                variants[f"{s}.{age}.{her}"] = pieces
            if preg is not None:
                pb = body + (preg["body"] - body0)
                variants[f"female.pregnant.{her}"] = {**entry, "body": put("body", pb, (gid, "body"))}
    header["garments"] = garments(np, pk, topo["body"], load("male-adult.neutral")["body"], load("female-adult.neutral")["body"],
                                  load("kid-toddler.neutral")["body"])
    payload = b"".join(pk.chunks)
    comp = zlib.compressobj(9, zlib.DEFLATED, -15)
    data = comp.compress(payload) + comp.flush()
    head = json.dumps(header, separators=(",", ":")).encode()
    FIGURE.write_bytes(b"EBF1" + len(head).to_bytes(4, "little") + len(payload).to_bytes(4, "little") + head + data)
    print(f"FIGURE {FIGURE.name}: {len(variants)} variants, {len(pk.blocks)} blocks, payload {len(payload) // 1024} KB → {FIGURE.stat().st_size // 1024} KB")
    textures()
    index = load_index()
    index.pop("skins", None)
    index["figure"] = {"file": FIGURE.name, "source": "MakeHuman (MPFB2)", "license": "CC0",
                       "variants": sorted(variants), "triangles": {k: v["triangles"] for k, v in header["pieces"].items()}}
    save_index(index)


# ------------------------------------------------------------------ underwear: body triangles, pushed out along the normal


def garments(np, pk, topo, male, female, kid):
    """Underwear as the parts of the body where a smooth field is positive, cut exactly along its zero line.
    Each garment vertex is a point on a body edge (a, b, t), so it follows every sex/age/heritage variant.
    Fields are written on the neutral adult male / female and the toddler (children share them: same topology)."""
    vmap, index = topo["vmap"], topo["index"].reshape(-1, 3)
    tris = np.unique(vmap[index], axis=0)  # position-vertex triangles (seams collapse)

    def ramp(v, a, b):
        t = np.clip((v - a) / (b - a), 0, 1)
        return t * t * (3 - 2 * t)

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
        # a sphere round each breast, its top cut along a line rising from the centre to the strap
        cups = np.minimum(0.125 - np.sqrt((ax - centre[0]) ** 2 + (y - centre[1]) ** 2 + (z - centre[2]) ** 2),
                          ay + 0.025 + 0.5 * np.clip(ax - (apex[0] - 0.07), 0, None) - y)
        lo, hi = ay - 0.15, ay - 0.085
        band = np.minimum.reduce([y - lo, hi - y, 0.27 - ax])
        gore = np.minimum.reduce([y - lo, ay - 0.02 - y, apex[0] - ax, z - 0.0])
        sx = np.where(z > 0, apex[0] - 0.035, apex[0] - 0.01)
        strap = np.minimum.reduce([0.024 - np.abs(ax - sx), 1.2 - y, y - (ay + 0.03) + ramp(-z, 0, 0.02) * 0.125])
        return np.maximum.reduce([cups, band, gore, strap])

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

    def clip(f):
        """positive part of every triangle; vertices are (a, b, t) on body edges"""
        verts, out = {}, []

        def vid(a, b, t):
            if t <= 1e-6:
                b, t = a, 0.0
            if a > b:
                a, b, t = b, a, 1 - t
            key = (int(a), int(b), round(float(t), 5))
            if key not in verts:
                verts[key] = len(verts)
            return verts[key]

        fv = f[tris]
        for tri, vals in zip(tris[(fv > 0).any(1)], fv[(fv > 0).any(1)]):
            poly = []
            for k in range(3):
                a, b = tri[k], tri[(k + 1) % 3]
                fa, fb = vals[k], vals[(k + 1) % 3]
                if fa > 0:
                    poly.append(vid(a, a, 0.0))
                if (fa > 0) != (fb > 0):
                    poly.append(vid(a, b, fa / (fa - fb)))
            for k in range(1, len(poly) - 1):
                out.append((poly[0], poly[k], poly[k + 1]))
        keys = sorted(verts, key=verts.get)
        ab = np.array([(k[0], k[1]) for k in keys], dtype=np.uint32)
        t = np.array([k[2] for k in keys], dtype=np.float32)
        return ab, t, np.array(out, dtype=np.uint32)

    out = {}
    for name, pos, field, lift, color in (
            ("briefs-male", male, briefs_male, 0.004, "#3E4A5C"),
            ("briefs-female", female, briefs_female, 0.004, "#C9A7B5"),
            ("bra", female, bra, 0.0045, "#C9A7B5"),
            ("nappy", kid, nappy, 0.014, "#F3F1EC"),
            ("briefs-kid", kid, briefs_kid, 0.004, "#6F9BC9"),
            ("top-kid", kid, top_kid, 0.005, "#6F9BC9")):
        ab, t, tri = clip(field(pos))
        out[name] = {"vertices": len(t), "triangles": len(tri), "ab": pk.add(ab), "t": pk.add(t), "index": pk.add(tri),
                     "lift": lift, "color": color}
        print("GARMENT", name, len(t), len(tri))
    return out


# ------------------------------------------------------------------ textures


def mpfb_data():
    import os
    tools = Path(os.environ.get("EVERYBODY_TOOLS") or ROOT / "tools")
    return tools / "blender-user" / "extensions" / ".user" / "user_default" / "mpfb" / "data"


SKIN_TEX = 1536
HAIR = ["short02", "ponytail01", "short04"]


def textures():
    import numpy as np
    from PIL import Image
    data = mpfb_data()

    def skin(age, race, sex):
        f = next((data / "skins" / f"{age}_{race}_{sex}").glob("*diffuse*.png"))
        return np.asarray(Image.open(f).convert("RGB").resize((SKIN_TEX, SKIN_TEX), Image.LANCZOS)).astype(np.float32)

    cache = {}
    for her, (_, blend) in HERITAGES.items():
        for sex in ("male", "female"):
            for age in ("young", "old"):
                px = sum(w * cache.setdefault((age, r, sex), skin(age, r, sex)) for r, w in blend.items())
                Image.fromarray(np.clip(px, 0, 255).astype(np.uint8)).save(OUT / f"skin-{her}-{sex}-{age}.jpg", quality=80, optimize=True)
    for name in ("eyebrow001", "eyebrow009"):
        alpha_pair(Image.open(data / "eyebrows" / name / f"{name}.png"), f"brows-{name}", 256)
    alpha_pair(Image.open(data / "eyelashes" / "eyelashes01" / "eyelashes01.png"), "lashes", 256)
    for hair in HAIR:
        im = Image.open(next((data / "hair" / hair).glob("*_diffuse.png")))
        alpha_pair(im, f"hair-{hair}", 1024)
        if hair != "ponytail01":
            alpha_pair(im, f"hair-{hair}-grey", 1024, grey=True, alpha=False)
    eye = np.asarray(Image.open(data / "eyes" / "materials" / "brown_eye.png").convert("RGB").resize((512, 512), Image.LANCZOS)).astype(np.float32) / 255
    # MakeHuman's "brown" iris reads red at phone size: tone it to a dark brown
    lum = eye @ np.array([0.3, 0.59, 0.11])
    iris = (lum < 0.45)[..., None]
    eye = np.where(iris, lum[..., None] * np.array([1.0, 0.7, 0.45]) * 1.5, lum[..., None] + 0.35 * (eye - lum[..., None]))
    Image.fromarray((np.clip(eye, 0, 1) * 255).astype(np.uint8)).save(OUT / "eyes.jpg", quality=85)
    for old in list(OUT.glob("skin-*.usdz")):
        old.unlink()


def alpha_pair(im, name, size, grey=False, alpha=True):
    """colour as JPEG (see-through texels filled with the mean strand colour) + alpha as a grey PNG"""
    import numpy as np
    from PIL import Image
    im = im.convert("RGBA")
    if im.width > size:
        im = im.resize((size, size * im.height // im.width), Image.LANCZOS)
    px = np.asarray(im).astype(np.float32)
    solid = px[..., 3] > 127
    rgb = px[..., :3]
    rgb[~solid] = rgb[solid].mean(0)
    if grey:
        lum = rgb @ np.array([0.3, 0.59, 0.11])
        rgb = np.repeat((150 + lum * 0.55)[..., None], 3, -1) * np.array([1.0, 0.98, 0.95])
    Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).save(OUT / f"{name}.jpg", quality=82, optimize=True)
    if alpha:
        Image.fromarray(px[..., 3].astype(np.uint8), "L").save(OUT / f"{name}-alpha.png", optimize=True)


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
