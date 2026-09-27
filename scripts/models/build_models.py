"""Real anatomy models → Resources/Models.

Skeleton from Z-Anatomy (CC BY-SA 4.0, from BodyParts3D), skin figures from MakeHuman via MPFB2 (CC0).
Both are warped onto the generated body's landmarks (scripts/gen_body.py: y up, +z front,
+x = figure's left, 1.86 units per metre, feet at y = -1.6) so organs, muscles and points still line up.

Run through scripts/models/build.sh (Blender headless):
  Blender -b Z-Anatomy/Startup.blend -P build_models.py -- skeleton
  Blender -b -P build_models.py -- skin
  venv/bin/python build_models.py report      # size table + budget check
"""

import json
import math
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Resources" / "Models"
INDEX = OUT / "models.json"
BUDGET_MB = 25.0
SKELETON_TRIS = (100_000, 150_000)
SKIN_TRIS = (20_000, 45_000)

# generated body landmarks (scene units), left side; right mirrors x
GEN = {
    "hip": (0.1674, 0.1205, 0.0), "knee": (0.1767, -0.6886, 0.0), "ankle": (0.1544, -1.4549, 0.0149),
    "toe": (0.1265, -1.5758, 0.383), "shoulder": (0.3441, 1.004, -0.0558), "elbow": (0.3906, 0.446, -0.0279),
    "wrist": (0.4408, -0.0144, 0.0075), "finger": (0.4473, -0.3448, 0.0372), "neck": (0.0, 1.335, -0.0226),
}
TOP = {"bone": 1.645, "skin": 1.655}
SOLE = -1.6

# ------------------------------------------------------------------ ids and names

BONE, CARTILAGE, TEETH, DISC = "#E9E2CF", "#C9D6E0", "#F7F4EA", "#B9C8D8"
ORD = {"first": 1, "second": 2, "third": 3, "fourth": 4, "fifth": 5, "sixth": 6, "seventh": 7, "eighth": 8,
       "ninth": 9, "tenth": 10, "eleventh": 11, "twelfth": 12}
FINGER = {1: "thumb", 2: "index", 3: "middle", 4: "ring", 5: "little"}
FINGER_ZH = {"index": "食指", "middle": "中指", "ring": "无名指", "little": "小指"}
TOE = {1: "big", 2: "2nd", 3: "3rd", 4: "4th", 5: "5th"}
# ids not in body.json: (name, 中文, colour)
NEW = {
    "frontal-bone": ("Frontal bone", "额骨", BONE), "parietal-bone": ("Parietal bone", "顶骨", BONE),
    "occipital-bone": ("Occipital bone", "枕骨", BONE), "temporal-bone": ("Temporal bone", "颞骨", BONE),
    "sphenoid-bone": ("Sphenoid bone", "蝶骨", BONE), "ethmoid-bone": ("Ethmoid bone", "筛骨", BONE),
    "vomer": ("Vomer", "犁骨", BONE), "nasal-bone": ("Nasal bone", "鼻骨", BONE), "lacrimal-bone": ("Lacrimal bone", "泪骨", BONE),
    "maxilla": ("Maxilla", "上颌骨", BONE), "palatine-bone": ("Palatine bone", "腭骨", BONE),
    "nasal-concha": ("Inferior nasal concha", "下鼻甲", BONE), "hyoid": ("Hyoid bone", "舌骨", BONE),
    "thyroid-cartilage": ("Thyroid cartilage", "甲状软骨", CARTILAGE), "cricoid-cartilage": ("Cricoid cartilage", "环状软骨", CARTILAGE),
    "nasal-cartilage": ("Nasal cartilages", "鼻软骨", CARTILAGE), "ossicles": ("Ear ossicles", "听小骨", BONE),
    "hip-bone": ("Hip bone", "髋骨", BONE), "calcaneus": ("Calcaneus (heel bone)", "跟骨", BONE),
    "tarsals": ("Tarsal bones", "跗骨", BONE), "meniscus-lateral": ("Lateral meniscus", "外侧半月板", CARTILAGE),
    "meniscus-medial": ("Medial meniscus", "内侧半月板", CARTILAGE),
}

SKIP = re.compile(r"^(Sinus of|Anterior cells|Middle cells|Posterior cells|Skeletal system\.g|Arytenoid|Corniculate)")
MERGED = {  # Z-Anatomy name → our id (side suffix added separately)
    "Atlas (C1)": "vertebra-C1", "Axis (C2)": "vertebra-C2", "Manubrium of sternum": "sternum", "Body of sternum": "sternum",
    "Xiphoid process": "sternum", "Hyoid bone": "hyoid", "Thyroid cartilage": "thyroid-cartilage", "Cricoid cartilage": "cricoid-cartilage",
    "Nasal septal cartilage": "nasal-cartilage", "Lateral process of nasal septal cartilage": "nasal-cartilage",
    "Major alar cartilage": "nasal-cartilage", "Interpubic disc": "pubic-symphysis", "Vomer": "vomer",
    "Inferior nasal concha bone": "nasal-concha", "Hip bone": "hip-bone", "Sesamoid bones of foot": "metatarsal-big",
    "Malleus": "ossicles", "Incus": "ossicles", "Stapes": "ossicles", "Calcaneus": "calcaneus", "Talus": "talus",
    "Navicular bone": "tarsals", "Cuboid bone": "tarsals", "Medial cuneiform bone": "tarsals",
    "Intermediate cuneiform bone": "tarsals", "Lateral cuneiform bone": "tarsals", "Lateral meniscus": "meniscus-lateral",
    "Medial meniscus": "meniscus-medial",
}
CARPALS = {"Scaphoid", "Lunate", "Triquetrum", "Pisiform", "Trapezium", "Trapezoid", "Capitate", "Hamate"}


def part_id(name):
    """Z-Anatomy object name → (our id, segment) or None to drop."""
    if SKIP.match(name):
        return None
    base, side = (name[:-2], name[-1]) if re.search(r"\.[lr]$", name) else (name, "")
    sfx = f"-{side}" if side else ""
    if m := re.match(r"Vertebra ([CTL]\d+)$", base):
        return f"vertebra-{m[1]}", None
    if m := re.match(r"Intervertebral disc ([CTL]\d+)-", base):
        return f"disc-{m[1]}", None
    if m := re.match(r"(\w+) rib$", base):
        return f"rib-{ORD[m[1].lower()]}{sfx}", None
    if m := re.match(r"Costal cartilage of (\w+) rib$", base):
        return f"costal-cartilage-{ORD[m[1]]}{sfx}", None
    if m := re.match(r"(Upper|Lower) .*(incisor|canine|premolar|molar)", base):
        return f"{m[1].lower()}-teeth", None
    if m := re.match(r"(\w+) metacarpal bone$", base):
        n = ORD[m[1].lower()]
        return (f"thumb-1{sfx}" if n == 1 else f"metacarpal-{FINGER[n]}{sfx}"), "hand"
    if m := re.match(r"(Proximal|Middle|Distal) phalanx of (\w+) finger of hand$", base):
        n = ORD[m[2]]
        if n == 1:
            return f"thumb-{2 if m[1] == 'Proximal' else 3}{sfx}", "hand"
        return f"phalanges-{FINGER[n]}{sfx}", "hand"
    if m := re.match(r"(\w+) metatarsal bone$", base):
        return f"metatarsal-{TOE[ORD[m[1].lower()]]}{sfx}", "foot"
    if m := re.match(r"(Proximal|Middle|Distal) phalanx of (\w+) finger of foot$", base):
        return f"toe-{TOE[ORD[m[2]]]}{sfx}", "foot"
    if base.split(" ")[0] in CARPALS and base.endswith("bone"):
        return f"carpals{sfx}", "hand"
    simple = {"Femur": "thigh", "Patella": "thigh", "Tibia": "shin", "Fibula": "shin", "Humerus": "uparm",
              "Radius": "forearm", "Ulna": "forearm", "Clavicle": None, "Scapula": None, "Mandible": None,
              "Sacrum": None, "Coccyx": None}
    if base in simple:
        return base.lower() + sfx, simple[base]
    if base in MERGED:
        pid = MERGED[base] + sfx
        seg = {"calcaneus": "foot", "talus": "foot", "tarsals": "foot", "metatarsal-big": "foot",
               "meniscus-lateral": "shin", "meniscus-medial": "shin"}.get(MERGED[base])
        return pid, seg
    if m := re.match(r"(Frontal|Parietal|Occipital|Temporal|Sphenoid|Ethmoid|Lacrimal|Palatine|Nasal|Zygomatic) bone$", base):
        pid = {"Nasal": "nasal-bone", "Zygomatic": "zygomatic"}.get(m[1], m[1].lower() + "-bone")
        return pid + sfx, None
    if base == "Maxilla":
        return "maxilla" + sfx, None
    return None


def names_for(pid, body_parts):
    """(name, 中文, colour) — body.json when the id exists, else NEW (+ side)."""
    if pid in body_parts:
        p = body_parts[pid]
        return p["name"], p["nameZh"], p["color"]
    base, side = (pid[:-2], pid[-1]) if re.search(r"-[lr]$", pid) else (pid, "")
    if m := re.match(r"phalanges-(\w+)$", base):
        name, zh, color = f"{m[1].capitalize()} finger phalanges", f"{FINGER_ZH[m[1]]}指骨", BONE
    elif m := re.match(r"disc-(\w+)$", base):
        name, zh, color = "Intervertebral disc", "椎间盘", DISC
    elif base in NEW:
        name, zh, color = NEW[base]
    else:
        raise KeyError(pid)
    if side:
        name += f" ({side.upper()})"
        zh = ("左" if side == "l" else "右") + zh
    return name, zh, color


JOINT = {"uparm": "shoulder", "forearm": "elbow", "hand": "elbow", "shin": "knee", "foot": "knee"}

# ------------------------------------------------------------------ fitting (numpy, scene coords)


def fitter(np, src, top_src, sole_src, kind):
    """Maps source points (raw scene axes, metres) onto the generated body.

    Trunk: piecewise-linear heights through hip / shoulder / neck / top, depth re-centred on the same
    landmarks, uniform width. Limbs: each segment maps its two joints exactly (rotate + stretch)."""
    V = lambda t: np.array(t, dtype=float)
    top_t = TOP[kind]
    s = (top_t - SOLE) / (top_src - sole_src)
    mid = lambda k: (src[k + "-l"] + src[k + "-r"]) / 2
    ys = [mid("hip")[1], mid("shoulder")[1], src["neck"][1], top_src]
    yt = [GEN["hip"][1], GEN["shoulder"][1], GEN["neck"][1], top_t]
    zs = [mid("hip")[2], mid("shoulder")[2], src["neck"][2]]
    zt = [GEN["hip"][2], GEN["shoulder"][2], GEN["neck"][2]]

    def height(y):
        out = np.interp(y, ys, yt)
        out = np.where(y < ys[0], yt[0] + (y - ys[0]) * s, out)
        return np.where(y > ys[-1], yt[-1] + (y - ys[-1]) * s, out)

    def trunk(p):
        p = np.atleast_2d(p)
        y2 = height(p[:, 1])
        zc = np.interp(p[:, 1], ys[:3], zs)
        zc2 = np.interp(y2, yt[:3], zt)
        return np.stack([p[:, 0] * s, y2, (p[:, 2] - zc) * s + zc2], axis=1)

    def rot(a, b):
        a, b = a / np.linalg.norm(a), b / np.linalg.norm(b)
        v, c = np.cross(a, b), float(np.dot(a, b))
        k = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
        return np.eye(3) + k + k @ k / (1 + c)

    def about(axis, angle):
        x, y, z = axis / np.linalg.norm(axis)
        k = np.array([[0, -z, y], [z, 0, -x], [-y, x, 0]])
        return np.eye(3) + math.sin(angle) * k + (1 - math.cos(angle)) * k @ k

    segs = {}
    for side, sx in (("l", 1), ("r", -1)):
        g = lambda k: V(GEN[k]) * V((sx, 1, 1))
        sh, hp = trunk(src["shoulder-" + side])[0], trunk(src["hip-" + side])[0]
        chain = {"uparm": ("shoulder", "elbow", sh, g("elbow")), "forearm": ("elbow", "wrist", g("elbow"), g("wrist")),
                 "hand": ("wrist", "finger", g("wrist"), g("finger")), "thigh": ("hip", "knee", hp, g("knee")),
                 "shin": ("knee", "ankle", g("knee"), g("ankle")), "foot": ("ankle", "toe", g("ankle"), g("toe"))}
        for name, (a, b, a2, b2) in chain.items():
            A, B = src[f"{a}-{side}"], src[f"{b}-{side}"]
            u, u2 = B - A, b2 - a2
            R = rot(u, u2)
            twist = 0.0
            lat = src.get(f"lateral-{side}")
            if name == "hand" and lat is not None:
                # palm forward: turn about the hand's axis until index→little lies along ∓x
                ax = u2 / np.linalg.norm(u2)
                l1 = R @ lat
                l1 -= ax * np.dot(l1, ax)
                l2 = V((sx, 0, 0)) - ax * np.dot(V((sx, 0, 0)), ax)
                twist = math.atan2(np.dot(np.cross(l1, l2), ax), np.dot(l1, l2))
            segs[f"{name}-{side}"] = (A, u / np.linalg.norm(u), np.linalg.norm(u2) / np.linalg.norm(u), a2, R, u2, twist)
        # forearm pieces share part of the hand's turn so the wrist doesn't twist like a sweet wrapper
        A, un, k, a2, R, u2, _ = segs[f"forearm-{side}"]
        t = segs[f"hand-{side}"][6]
        for name, frac in (("fore1", 0.35), ("fore2", 0.75), ("forearm", 0.6)):
            segs[f"{name}-{side}"] = (A, un, k, a2, R, u2, t * frac)

    def limb(p, key):
        A, un, k, a2, R, u2, twist = segs[key]
        d = np.atleast_2d(p) - A
        along = d @ un
        d = d * s + np.outer(along, un) * (k - s)
        m = R
        if twist:
            m = about(u2, twist) @ R
        return d @ m.T + a2

    def apply(p, key):
        return trunk(p) if key == "trunk" else limb(p, key)

    return apply, s


def to_scene(np, co):
    """Blender (x, y, z) world → raw scene axes (x, z, -y)."""
    return np.stack([co[:, 0], co[:, 2], -co[:, 1]], axis=1)


def to_blender(np, p):
    return np.stack([p[:, 0], -p[:, 2], p[:, 1]], axis=1)


# ------------------------------------------------------------------ Blender helpers


def mesh_coords(np, me):
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    return co.reshape(-1, 3)


def set_coords(np, me, co):
    me.vertices.foreach_set("co", co.reshape(-1).astype(np.float32))
    me.update()


def tris(me):
    me.calc_loop_triangles()
    return len(me.loop_triangles)


def prim(pid):
    return pid.replace("-", "_")


def export_usdz(bpy, objects, path, materials):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.wm.usd_export(filepath=str(path), selected_objects_only=True, export_materials=materials,
                          export_uvmaps=materials, export_normals=True, convert_world_material=False,
                          triangulate_meshes=True, export_textures=materials, export_animation=False,
                          export_armatures=False, export_shapekeys=False, author_blender_name=False,
                          generate_materialx_network=False, root_prim_path="/root", merge_parent_xform=True)


def load_index():
    return json.loads(INDEX.read_text()) if INDEX.exists() else {}


def save_index(index):
    INDEX.write_text(json.dumps(index, ensure_ascii=False, indent=1) + "\n")


# ------------------------------------------------------------------ skeleton


def build_skeleton():
    import bpy
    import numpy as np

    body_parts = {p["id"]: p for p in json.loads((ROOT / "Resources/Data/body.json").read_text())["parts"]}
    dg = bpy.context.evaluated_depsgraph_get()
    wanted = [o for c in ("1: Skeletal system", "3: Joints") for o in bpy.data.collections[c].objects
              if o.type == "MESH" and len(o.data.polygons)]
    pieces = {}  # id → [(object name, raw scene coords, mesh)]
    segment = {}
    for o in wanted:
        hit = part_id(o.name)
        if not hit and not o.hide_render:
            print("DROP", o.name)
        if not hit or (o.hide_render and not o.name.startswith(("Intervertebral disc", "Interpubic", "Lateral menisc", "Medial menisc"))):
            continue
        pid, seg = hit
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
        me.transform(o.matrix_world)
        pieces.setdefault(pid, []).append((o.name, to_scene(np, mesh_coords(np, me)), me))
        segment[pid] = seg

    def pts(pid):
        return np.concatenate([p[1] for p in pieces[pid]])

    src = {}
    for side in "lr":
        hum, fem, tib = pts(f"humerus-{side}"), pts(f"femur-{side}"), pts(f"tibia-{side}")
        top = hum[hum[:, 1] > hum[:, 1].max() - 0.04]
        src[f"shoulder-{side}"] = sphere_centre(np, top[np.abs(top[:, 0]) < np.abs(top[:, 0]).mean()])
        src[f"elbow-{side}"] = hum[hum[:, 1] < hum[:, 1].min() + 0.02].mean(0)
        wr = [pts(f"{b}-{side}") for b in ("radius", "ulna")]
        src[f"wrist-{side}"] = sum(w[w[:, 1] < w[:, 1].min() + 0.012].mean(0) for w in wr) / 2
        tip = pts(f"phalanges-middle-{side}")
        src[f"finger-{side}"] = tip[tip[:, 1].argmin()]
        head = fem[fem[:, 1] > fem[:, 1].max() - 0.05]
        src[f"hip-{side}"] = sphere_centre(np, head[np.abs(head[:, 0]) < np.abs(head[:, 0]).min() + 0.045])
        src[f"knee-{side}"] = (fem[fem[:, 1] < fem[:, 1].min() + 0.02].mean(0) + tib[tib[:, 1] > tib[:, 1].max() - 0.02].mean(0)) / 2
        src[f"ankle-{side}"] = tib[tib[:, 1] < tib[:, 1].min() + 0.01].mean(0)
        toe = pts(f"toe-big-{side}")
        src[f"toe-{side}"] = toe[toe[:, 2].argmax()]
        src[f"lateral-{side}"] = pts(f"metacarpal-index-{side}").mean(0) - pts(f"metacarpal-little-{side}").mean(0)
    src["neck"] = pts("vertebra-C1").mean(0)
    allp = np.concatenate([pts(k) for k in pieces])
    top_src, sole_src = allp[:, 1].max(), 0.0
    fit, s = fitter(np, src, top_src, sole_src, "bone")
    print("SKELETON scale", round(s, 4), {k: np.round(v, 3).tolist() for k, v in src.items()})

    col = bpy.data.collections.new("export")
    bpy.context.scene.collection.children.link(col)
    objects, parts, total = [], [], 0
    for pid in sorted(pieces):
        seg = segment[pid]
        key = "trunk" if seg is None else f"{seg}-{pid[-1]}"
        meshes = []
        for _, raw, me in pieces[pid]:
            set_coords(np, me, to_blender(np, fit(raw, key)))
            meshes.append(me)
        me = join_meshes(bpy, meshes, prim(pid))
        raw_tris = tris(me)
        ob = bpy.data.objects.new(prim(pid), me)
        col.objects.link(ob)
        ratio = min(1.0, max(0.18, 220 / max(raw_tris, 1)))
        if ratio < 1:
            mod = ob.modifiers.new("dec", "DECIMATE")
            mod.ratio = ratio
            mod.use_collapse_triangulate = True
            bpy.context.view_layer.objects.active = ob
            bpy.ops.object.modifier_apply(modifier="dec")
        for p in me.polygons:
            p.use_smooth = True
        n = tris(me)
        total += n
        objects.append(ob)
        name, zh, color = names_for(pid, body_parts)
        side = pid[-1] if re.search(r"-[lr]$", pid) else None
        joint = f"{JOINT[seg]}-{side}" if seg in JOINT and side else None
        parts.append({"id": pid, "name": name, "nameZh": zh, "layer": "skeletal", "color": color,
                      **({"joint": joint} if joint else {}), "tris": n})
    lo, hi = SKELETON_TRIS
    print(f"SKELETON {len(parts)} parts, {total} triangles")
    if not lo <= total <= hi:
        sys.exit(f"skeleton triangles {total} outside {lo}-{hi}")
    OUT.mkdir(parents=True, exist_ok=True)
    export_usdz(bpy, objects, OUT / "skeleton.usdz", materials=False)
    index = load_index()
    index["skeleton"] = {"file": "skeleton.usdz", "source": "Z-Anatomy", "license": "CC BY-SA 4.0", "triangles": total, "parts": parts}
    save_index(index)


def sphere_centre(np, p):
    """least-squares sphere through points"""
    A = np.c_[2 * p, np.ones(len(p))]
    b = (p ** 2).sum(1)
    c = np.linalg.lstsq(A, b, rcond=None)[0]
    return c[:3]


def join_meshes(bpy, meshes, name):
    import bmesh
    bm = bmesh.new()
    for me in meshes:
        bm.from_mesh(me)
    out = bpy.data.meshes.new(name)
    bm.to_mesh(out)
    bm.free()
    for me in meshes:
        bpy.data.meshes.remove(me)
    return out


# ------------------------------------------------------------------ skin (MakeHuman via MPFB2)

VARIANTS = {
    # id: (gender, extra targets, skin, hair, eyebrows)
    "male": (1.0, {}, "young_asian_male", "short02", "eyebrow001"),
    "female": (0.0, {}, "young_asian_female", "ponytail01", "eyebrow009"),
    "female-pregnant": (0.0, {"stomach/stomach-pregnant-incr": 1.0}, "young_asian_female", "ponytail01", "eyebrow009"),
}
LIMB_BONES = [(r"upperarm0[12]", "uparm"), (r"lowerarm01", "fore1"), (r"lowerarm02", "fore2"),
              (r"(wrist|metacarpal|finger)", "hand"), (r"upperleg0[12]", "thigh"), (r"lowerleg0[12]", "shin"),
              (r"(foot|toe)", "foot")]


def bone_segment(name):
    m = re.match(r"(.+)\.([LR])$", name)
    if not m:
        return "trunk"
    for pat, seg in LIMB_BONES:
        if re.match(pat, m[1]):
            return f"{seg}-{m[2].lower()}"
    return "trunk"


def build_skins(only=None):
    import bpy
    import numpy as np

    def imp(pkg, key):
        import importlib
        for m in list(sys.modules):
            if m.endswith(pkg):
                return getattr(importlib.import_module(m), key)
        raise ImportError(pkg)

    HumanService = imp("mpfb.services.humanservice", "HumanService")
    AssetService = imp("mpfb.services.assetservice", "AssetService")
    TargetService = imp("mpfb.services.targetservice", "TargetService")
    LocationService = imp("mpfb.services.locationservice", "LocationService")
    data = Path(AssetService.find_asset_absolute_path("low-poly.mhclo", asset_subdir="eyes")).parents[2]
    index = load_index()
    skins = index.get("skins", {})
    for vid, (gender, targets, skin, hair, brows) in VARIANTS.items():
        if only and vid != only:
            continue
        for o in list(bpy.data.objects):
            bpy.data.objects.remove(o)
        macros = TargetService.get_default_macro_info_dict()
        macros.update(gender=gender, age=0.5, muscle=0.55, weight=0.5, height=0.5, proportions=0.6)
        macros["race"] = {"asian": 0.6, "caucasian": 0.3, "african": 0.1}
        h = HumanService.create_human(macro_detail_dict=macros)
        for t, w in targets.items():
            TargetService.load_target(h, os.path.join(LocationService.get_mpfb_data("targets"), t + ".target.gz"), weight=w)
        rig = HumanService.add_builtin_rig(h, "default")
        assets = [("eyes", "low-poly.mhclo", "Eyes", "eyes"), ("eyebrows", f"{brows}.mhclo", "Eyebrows", "eyebrows"),
                  ("eyelashes", "eyelashes01.mhclo", "Eyelashes", "eyelashes"), ("hair", f"{hair}.mhclo", "Hair", "hair")]
        extra = {}
        for sub, f, kind, key in assets:
            before = set(bpy.data.objects)
            HumanService.add_mhclo_asset(AssetService.find_asset_absolute_path(f, asset_subdir=sub), h, asset_type=kind, subdiv_levels=0)
            extra[key] = next(iter(set(bpy.data.objects) - before))
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
        objs = {"body": h, **extra}
        meshes = {}
        for key, o in objs.items():
            me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
            me.transform(o.matrix_world)
            meshes[key] = (o, me)
        body_raw = to_scene(np, mesh_coords(np, meshes["body"][1]))
        fit, s = fitter(np, src, body_raw[:, 1].max(), body_raw[:, 1].min(), "skin")
        print("SKIN", vid, "scale", round(s, 4))

        col = bpy.data.collections.new("export-" + vid)
        bpy.context.scene.collection.children.link(col)
        out_objs, total, files = [], 0, []
        for key, (o, me) in meshes.items():
            raw = to_scene(np, mesh_coords(np, me))
            groups = {g.index: bone_segment(g.name) for g in o.vertex_groups if g.name in bones}
            keys = sorted(set(groups.values()) | {"trunk"})
            wts = np.zeros((len(me.vertices), len(keys)))
            for v in me.vertices:
                for g in v.groups:
                    if g.group in groups and g.weight > 0:
                        wts[v.index, keys.index(groups[g.group])] += g.weight
            none = wts.sum(1) == 0
            wts[none, keys.index("trunk")] = 1
            wts /= wts.sum(1, keepdims=True)
            out = np.zeros_like(raw)
            for i, k in enumerate(keys):
                sel = wts[:, i] > 0
                if sel.any():
                    out[sel] += fit(raw[sel], k) * wts[sel, i:i + 1]
            set_coords(np, me, to_blender(np, out))
            me.name = prim(key)
            ob = bpy.data.objects.new(prim(key), me)
            col.objects.link(ob)
            for p in me.polygons:
                p.use_smooth = True
            files.append(skin_material(bpy, data, ob, key, vid, skin, hair, brows))
            n = tris(me)
            total += n
            out_objs.append(ob)
        lo, hi = SKIN_TRIS
        print(f"SKIN {vid} {total} triangles")
        if not lo <= total <= hi:
            sys.exit(f"skin {vid} triangles {total} outside {lo}-{hi}")
        export_usdz(bpy, out_objs, OUT / f"skin-{vid}.usdz", materials=True)
        skins[vid] = {"file": f"skin-{vid}.usdz", "source": "MakeHuman (MPFB2)", "license": "CC0",
                      "skin": skin, "hair": hair, "triangles": total, "parts": [prim(k) for k in objs]}
    index = load_index()
    index["skins"] = skins
    save_index(index)


TEX_SIZE = {"body": 2048, "eyes": 512, "eyebrows": 256, "eyelashes": 256, "hair": 1024}


def skin_material(bpy, data, ob, key, vid, skin, hair, brows):
    """One simple textured material per piece (baked JPEG/PNG) instead of MPFB's node trees."""
    import numpy as np
    src = {
        "body": next((data / "skins" / skin).glob("*.png")),
        "eyes": data / "eyes" / "materials" / "brown_eye.png",
        "eyebrows": data / "eyebrows" / brows / f"{brows}.png",
        "eyelashes": data / "eyelashes" / "eyelashes01" / "eyelashes01.png",
        "hair": next((data / "hair" / hair).glob("*_diffuse.png")),
    }[key]
    alpha = key in ("eyebrows", "eyelashes", "hair")
    tex_dir = ROOT / "build" / "models"
    tex_dir.mkdir(parents=True, exist_ok=True)
    img = bpy.data.images.load(str(src))
    size = TEX_SIZE[key]
    if img.size[0] > size:
        img.scale(size, size * img.size[1] // img.size[0])
    if alpha:
        # see-through texels are white in the source: fill them with the mean strand colour so edges don't glow
        px = np.array(img.pixels[:]).reshape(-1, 4)
        solid = px[:, 3] > 0.5
        px[~solid, :3] = px[solid, :3].mean(0)
        img.pixels[:] = px.reshape(-1)
    if key == "eyes":
        # MakeHuman's "brown" iris reads red at phone size: tone it to a dark brown
        px = np.array(img.pixels[:]).reshape(-1, 4)
        lum = px[:, :3] @ np.array([0.3, 0.59, 0.11])
        iris = (lum < 0.45)[:, None]
        tone = np.where(iris, lum[:, None] * np.array([1.0, 0.72, 0.5]) * 0.8, lum[:, None] + 0.35 * (px[:, :3] - lum[:, None]))
        px[:, :3] = tone
        img.pixels[:] = px.reshape(-1)
    fmt = "PNG" if alpha else "JPEG"
    path = tex_dir / f"{vid}-{key}.{'png' if alpha else 'jpg'}"
    img.filepath_raw = str(path)
    img.file_format = fmt
    if not alpha:
        bpy.context.scene.render.image_settings.quality = 82
    img.save()
    img = bpy.data.images.load(str(path))
    mat = bpy.data.materials.new(f"{vid}_{key}")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = img
    nt.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
    if alpha:
        nt.links.new(t.outputs["Alpha"], bsdf.inputs["Alpha"])
    bsdf.inputs["Roughness"].default_value = 0.55 if key == "body" else 0.4 if key == "eyes" else 0.7
    me = ob.data
    me.materials.clear()
    me.materials.append(mat)
    for p in me.polygons:
        p.material_index = 0
    return path


# ------------------------------------------------------------------ report


def report():
    index = load_index()
    rows, total = [], 0
    for f in sorted(OUT.iterdir()):
        size = f.stat().st_size
        total += size
        rows.append((f.name, size))
    print(f"{'file':32} {'KB':>8}")
    for name, size in rows:
        print(f"{name:32} {size / 1024:8.0f}")
    print(f"{'total':32} {total / 1024:8.0f}  (budget {BUDGET_MB:.0f} MB)")
    if "skeleton" in index:
        print(f"skeleton: {len(index['skeleton']['parts'])} parts, {index['skeleton']['triangles']} triangles")
    for vid, s in index.get("skins", {}).items():
        print(f"skin {vid}: {s['triangles']} triangles")
    if total > BUDGET_MB * 1024 * 1024:
        sys.exit("over budget")


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    mode = args[0] if args else "report"
    if mode == "skeleton":
        build_skeleton()
    elif mode == "skin":
        build_skins(args[1] if len(args) > 1 else None)
    else:
        report()
