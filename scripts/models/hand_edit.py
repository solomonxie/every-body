"""Hand editing in Blender: the shipped models out to .blend files, and edited figure shapes back in.

  Blender -b -P hand_edit.py -- export <dir>   # figure variants + anatomy → <dir>/*.blend (an old <dir> goes to /tmp)
                                               # MODELS_ONLY=female.adult.white: just that variant (no anatomy)
  Blender -b -P hand_edit.py -- import <dir>   # moved vertices of body / eyes / brows / lashes → build/models/figure
                                               # (then build.sh pack; build.sh fit starts over from MakeHuman)

Export gives the body MakeHuman's targets as shape-key sliders. Import keeps each mesh's vertex count and order: move vertices only (sculpt, proportional edit, shape keys), apply
modifiers first. Body edits below the neck reach every heritage of that sex and age; head edits stay with the variant.
Hair is regrown by hair.py and not imported.
"""

import gzip
import os
import shutil
import sys
import time
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from build_figure import FIGURE, HERITAGES, RAW, read_figure  # noqa: E402
from build_models import OUT, ROOT, to_blender, to_scene  # noqa: E402

import bpy  # noqa: E402
import numpy as np  # noqa: E402

ANATOMY = ["skeleton", "muscles", "organs", "vessels", "nerves"]
# Figure.swift hairColor / browColor
HAIR = {"white": "#E8C184", "hispanic": "#58412F", "south-asian": "#4E3E35", "southeast-asian": "#4E3E35",
        "east-asian": "#2B2522", "black": "#40352F"}
BROW = {"white": "#9C7A52", "hispanic": "#3A2B22", "south-asian": "#362B26", "southeast-asian": "#362B26",
        "east-asian": "#4A3B34", "black": "#3A2F2A"}
GREY_HAIR, GREY_BROW = "#F4F1EC", "#B8B4AE"
KIDS = ("infant", "toddler", "child")
# MakeHuman targets offered as shape-key sliders on the body (not: expressions, asymmetry, macros, genitals)
SLIDERS = ["head", "forehead", "eyebrows", "eyes", "nose", "mouth", "ears", "cheek", "chin", "neck", "torso", "breast",
           "stomach", "hip", "pelvis", "buttocks", "arms", "hands", "legs", "feet"]
# below this a vertex counts as unmoved (figure.bin keeps positions to ~0.01 mm)
STILL = 1e-4


def rgb(hex_):
    """sRGB hex → Blender's linear colour"""
    c = [int(hex_[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c] + [1.0]


def faces(tris, vmap, poly):
    """triangles (render indices) → polygons, the two halves of a quad merged back"""
    if poly is None or len(poly) != len(tris):
        return [list(t) for t in tris]
    out, i = [], 0
    while i < len(tris):
        t = list(tris[i])
        if i + 1 < len(tris) and poly[i + 1] == poly[i]:
            u = list(tris[i + 1])
            tv, uv_ = [vmap[r] for r in t], [vmap[r] for r in u]
            extra = [k for k, v in enumerate(uv_) if v not in tv]
            if len(extra) == 1:
                d = u[extra[0]]
                for k in range(3):
                    a, b = tv[k], tv[(k + 1) % 3]
                    if b in uv_ and a in uv_ and uv_[(uv_.index(b) + 1) % 3] == a:
                        t.insert(k + 1, d)
                        break
                else:
                    out += [t, u]
                    i += 2
                    continue
                out.append(t)
                i += 2
                continue
        out.append(t)
        i += 1
    return out


def mesh_object(name, pos, uv, vmap, tris, poly, smooth):
    polys = faces(tris, vmap, poly)
    me = bpy.data.meshes.new(name)
    me.from_pydata(to_blender(np, pos).tolist(), [], [[int(vmap[r]) for r in f] for f in polys])
    loop_uv = np.array([uv[r] for f in polys for r in f], dtype=np.float32)
    me.uv_layers.new(name="UVMap").data.foreach_set("uv", loop_uv.ravel())
    me.polygons.foreach_set("use_smooth", [smooth] * len(me.polygons))
    me.update()
    ob = bpy.data.objects.new(name, me)
    ob["piece"] = name
    bpy.context.scene.collection.objects.link(ob)
    return ob


def material(name, tex_dir, color, tint=None, alpha=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    bsdf = nodes["Principled BSDF"]
    img = nodes.new("ShaderNodeTexImage")
    img.image = bpy.data.images.load(str(tex_dir / color), check_existing=True)
    out = img.outputs["Color"]
    if tint:
        mix = nodes.new("ShaderNodeMix")
        mix.data_type, mix.blend_type = "RGBA", "MULTIPLY"
        mix.inputs[0].default_value = 1.0
        mix.inputs[7].default_value = rgb(tint)
        links.new(out, mix.inputs[6])
        out = mix.outputs[2]
    links.new(out, bsdf.inputs["Base Color"])
    if alpha:
        a = nodes.new("ShaderNodeTexImage")
        a.image = bpy.data.images.load(str(tex_dir / alpha), check_existing=True)
        a.image.colorspace_settings.name = "Non-Color"
        links.new(a.outputs["Color"], bsdf.inputs["Alpha"])
        m.surface_render_method = "DITHERED"
    return m


def piece_material(piece, variant, tex_dir):
    sex, age, her = variant.split(".")
    grey = age == "senior"
    if piece == "body":
        skin = "kid" if age in KIDS else f"{sex}-{'old' if grey else 'young'}"
        return material(piece, tex_dir, f"skin-{her}-{skin}.jpg")
    if piece == "eyes":
        return material(piece, tex_dir, "eyes.jpg")
    if piece.endswith(".shell"):
        return material(piece, tex_dir, "hair-strands.jpg", GREY_HAIR if grey else HAIR[her])
    if piece.startswith("hair-"):
        return material(piece, tex_dir, f"hair-sculpt{'-grey' if grey else ''}.jpg", GREY_HAIR if grey else HAIR[her])
    tint = (GREY_BROW if grey else BROW[her]) if piece.startswith("brows") else \
        "#2A2522" if sex == "female" and age not in KIDS else "#4A4440"
    return material(piece, tex_dir, f"{piece}.jpg", tint, f"{piece}-alpha.png")


def figure_uvs():
    raw = FIGURE.read_bytes()
    n = int.from_bytes(raw[4:8], "little")
    payload = zlib.decompress(raw[12 + n:], -15)
    return lambda info: np.frombuffer(payload, np.uint16, info["render"] * 2, info["uv"]).reshape(-1, 2) / 65535


def topo_poly(piece):
    f = RAW / f"topo.{piece}.npz"
    return np.load(f)["poly"] if f.exists() else None


def load_targets():
    """[(slider name, vertex indices, MakeHuman offsets)] and the MakeHuman base mesh (body vertices only)"""
    tools = Path(os.environ.get("EVERYBODY_TOOLS") or ROOT / "tools")
    data = next(tools.glob("blender-user/extensions/**/mpfb/data/3dobjs/base.obj")).parents[1]
    base = np.array([ln.split()[1:4] for ln in open(data / "3dobjs" / "base.obj") if ln.startswith("v ")], float)
    targets = []
    for group in SLIDERS:
        for f in sorted((data / "targets" / group).glob("*.target.gz")):
            if group == "breast" and not f.name.startswith("breast-"):
                continue
            rows = np.array([ln.split() for ln in gzip.open(f, "rt") if ln.strip() and not ln.startswith("#")], float)
            keep = rows[:, 0] < 13380
            if keep.sum() >= 4:
                targets.append((f"{group}: {f.name[:-10]}", rows[keep, 0].astype(int), rows[keep, 1:]))
    return targets, base[:13380]


def region_fit(src, dst):
    """scale and rotation carrying the MakeHuman region onto the figure's (Kabsch)"""
    a, b = src - src.mean(0), dst - dst.mean(0)
    u, _, vt = np.linalg.svd(a.T @ b)
    r = (u @ np.diag([1, 1, np.sign(np.linalg.det(u @ vt))]) @ vt).T
    return np.sqrt((b ** 2).sum() / max((a ** 2).sum(), 1e-12)), r


def add_sliders(ob, pos, targets, base):
    ob.shape_key_add(name="Basis", from_mix=False)
    for name, idx, off in targets:
        scale, rot = region_fit(base[idx], pos[idx])
        p = pos.copy()
        p[idx] += scale * off @ rot.T
        key = ob.shape_key_add(name=name, from_mix=False)
        key.data.foreach_set("co", to_blender(np, p).ravel())


def export(out):
    if out.exists():
        old = Path("/tmp") / f"{out.name}-{time.strftime('%Y%m%d-%H%M%S')}"
        shutil.move(str(out), str(old))
        print(f"EXPORT previous {out} moved to {old}")
    tex_dir = out / "textures"
    tex_dir.mkdir(parents=True)
    for f in OUT.iterdir():
        if f.suffix in (".jpg", ".png"):
            shutil.copy2(f, tex_dir / f.name)
    (out / "figure").mkdir()
    header, block, piece = read_figure(np)
    uvs = figure_uvs()
    targets, base = load_targets()
    only = os.environ.get("MODELS_ONLY")
    for variant, pieces in sorted(header["variants"].items()):
        if only and variant != only:
            continue
        bpy.ops.wm.read_factory_settings(use_empty=True)
        for name, b in pieces.items():
            vmap, tris = piece(name)
            ob = mesh_object(name, block(b), uvs(header["pieces"][name]), vmap, tris, None if name.startswith("hair-") else topo_poly(name),
                             smooth=name != "eyes")
            ob.data.materials.append(piece_material(name, variant, tex_dir))
            if name == "body":
                add_sliders(ob, block(b), targets, base)
        bpy.ops.wm.save_as_mainfile(filepath=str(out / "figure" / f"{variant}.blend"), compress=True, relative_remap=True)
        print(f"EXPORT figure/{variant}.blend")
    if only:
        return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for name in ANATOMY:
        coll = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(coll)
        before = set(bpy.data.objects)
        bpy.ops.wm.usd_import(filepath=str(OUT / f"{name}.usdz"))
        for ob in set(bpy.data.objects) - before:
            for c in ob.users_collection:
                c.objects.unlink(ob)
            coll.objects.link(ob)
    bpy.ops.wm.save_as_mainfile(filepath=str(out / "anatomy.blend"), compress=True, relative_remap=True)
    print("EXPORT anatomy.blend")
    (out / "README.md").write_text(
        "# Every Body models\n\n"
        "- `figure/<sex>.<age>.<heritage>.blend`: skin figure, eyes, brows, lashes, hair (app scene units, Z up)\n"
        "- body sliders: MakeHuman targets as shape keys (Object Data → Shape Keys), e.g. `nose: nose-scale-horiz-incr`\n"
        "- `anatomy.blend`: skeleton, muscles, organs, vessels, nerves (view only; not imported back)\n"
        "- `textures/`: shared images\n\n"
        "Back into the app (`make models-import`): body, eyes, brows and lashes, moved vertices only.\n"
        "Keep vertex count and object names; apply modifiers. Hair is not imported.\n"
        "Licences: Resources/Models/LICENSE.md in the app repo.\n")


def group_of(variant):
    sex, age, her = variant.split(".")
    return (f"kid-{age}" if age in KIDS else f"{sex}-{age}"), her


def import_(src):
    header, block, _ = read_figure(np)
    edits = {}
    for f in sorted((src / "figure").glob("*.blend")):
        variant = f.stem
        if variant not in header["variants"]:
            print(f"IMPORT skip {f.name}: not a figure variant")
            continue
        if ".pregnant." in variant:
            print(f"IMPORT skip {f.name}: pregnant bodies are derived from the adult female")
            continue
        bpy.ops.wm.read_factory_settings(use_empty=True)
        with bpy.data.libraries.load(str(f)) as (lib, dst):
            dst.objects = lib.objects
        dg = None
        for ob in dst.objects:
            name = ob.get("piece") if ob else None
            if ob is None or ob.type != "MESH" or name not in header["variants"][variant]:
                continue
            if name.startswith("hair-"):
                continue
            bpy.context.scene.collection.objects.link(ob)
            dg = bpy.context.evaluated_depsgraph_get()
            me = ob.evaluated_get(dg).to_mesh()
            co = np.empty(len(me.vertices) * 3)
            me.vertices.foreach_get("co", co)
            ob.evaluated_get(dg).to_mesh_clear()
            orig = block(header["variants"][variant][name])
            if len(co) != orig.size:
                print(f"IMPORT skip {variant} {name}: {len(co) // 3} vertices, expected {len(orig)}")
                continue
            m = np.array(ob.matrix_world)
            co = co.reshape(-1, 3) @ m[:3, :3].T + m[:3, 3]
            d = to_scene(np, co) - orig
            d[np.linalg.norm(d, axis=1) < STILL] = 0
            if d.any():
                edits.setdefault(group_of(variant), {}).setdefault(name, []).append(d)
                print(f"IMPORT {variant} {name}: {int((d != 0).any(1).sum())} vertices moved")
    if not edits:
        print("IMPORT nothing moved")
        return
    backup = RAW / "backup" / time.strftime("%Y%m%d-%H%M%S")
    backup.mkdir(parents=True)
    for (gid, her), pieces in edits.items():
        # the body's shared files (neutral, pregnant, shapes) take the body edit, so it survives the heritage blend
        shared = [p.stem for p in RAW.glob(f"{gid}.*.npz") if p.stem.split(".", 1)[1] not in HERITAGES]
        for name, ds in pieces.items():
            d = np.sum(ds, axis=0)
            for stem in [f"{gid}.{her}"] + (shared if name == "body" else []):
                f = RAW / f"{stem}.npz"
                data = dict(np.load(f))
                if not (backup / f.name).exists():
                    shutil.copy2(f, backup / f.name)
                data[f"pos:{name}"] = (data[f"pos:{name}"] + d).astype(data[f"pos:{name}"].dtype)
                np.savez_compressed(f, **data)
                print(f"IMPORT → {f.name} pos:{name}")
    print(f"IMPORT originals kept in {backup}")


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:]
    mode, where = args[0], Path(args[1]).expanduser()
    export(where) if mode == "export" else import_(where)
