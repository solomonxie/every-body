"""Shared pieces for the pre-rendered scene pictures: MakeHuman (MPFB2, CC0) people on the default rig, posing by
aiming bones at world points, props, EEVEE light / camera / style, framing and the anchor points for overlays.

Scenes (cpr.py, choking.py, …) build on this; scripts/art3d/render.py runs them in Blender.
"""

import importlib
import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build" / "art3d"
W, H = 1080, 900
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))


def mpfb(key):
    pkg = {"HumanService": "humanservice", "TargetService": "targetservice", "AssetService": "assetservice",
           "LocationService": "locationservice"}[key]
    for m in list(sys.modules):
        if m.endswith(f"mpfb.services.{pkg}"):
            return getattr(importlib.import_module(m), key)
    raise ImportError(key)


def hexcol(s, a=1.0):
    s = s.lstrip("#")
    srgb = [int(s[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
    return (*lin, a)


def update():
    bpy.context.view_layer.update()


def yaw(a, b):
    """turn about the vertical that takes horizontal direction `a` to `b` (well defined even when they are opposite)"""
    ang = math.atan2(b[1], b[0]) - math.atan2(a[1], a[0])
    return Matrix.Rotation(ang, 4, "Z")


# ------------------------------------------------------------------ materials

PALETTE = {
    "rescuer-top": "#3F8F8B", "rescuer-bottom": "#353F57", "rescuer-hair": "#3B2A22", "rescuer-shoes": "#E9E6E1",
    "man-top": "#8EA2BC", "man-bottom": "#59627A", "man-hair": "#4A3A30", "man-shoes": "#6B5446",
    "helper-top": "#E0A340", "helper-bottom": "#3B3F4C", "helper-hair": "#221B17", "helper-shoes": "#3A3A3A",
    "woman-top": "#9A7FB0", "woman-bottom": "#4A4E5E", "woman-hair": "#2E2019", "woman-shoes": "#E9E6E1",
    "child-top": "#E3B45C", "child-bottom": "#4F6D8F", "child-hair": "#2A1E17", "child-shoes": "#D9504E",
    "girl-top": "#E08A9C", "girl-bottom": "#4F6D8F", "girl-hair": "#3A2419", "girl-shoes": "#8E7CC3",
    "senior-top": "#8FB39D", "senior-bottom": "#555A68", "senior-hair": "#D6D3CE", "senior-shoes": "#5E4B3F",
    "gran-top": "#C98F8F", "gran-bottom": "#4F5363", "gran-hair": "#DAD7D2", "gran-shoes": "#6B5446",
    "baby-top": "#F2DFA0", "baby-bottom": "#F2DFA0", "baby-hair": "#8A6A4E",
    "skin-light": "#EDBF9C", "skin-mid": "#D29067", "skin-tan": "#B5764E", "skin-deep": "#7E4F33",
    "ground": "#A29F9A", "table": "#E2D2BD", "table-leg": "#C9B79F", "blanket": "#BFD8E6",
    "aed": "#3E9C66", "aed-panel": "#F2F4F2", "aed-button": "#F08A32", "pad": "#F6F7F8", "pad-edge": "#E0524E",
    "phone": "#2B2E35", "screen": "#8FB8E8", "wire": "#39404C",
}


def principled(name, color, rough=0.6, sss=0.0, tex=None, tex_mix=0.0, alpha_tex=False, desat=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = hexcol(color) if isinstance(color, str) else color
    bsdf.inputs["Roughness"].default_value = rough
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.2
    if sss:
        bsdf.inputs["Subsurface Weight"].default_value = sss
        bsdf.inputs["Subsurface Radius"].default_value = (1.0, 0.35, 0.2)
        bsdf.inputs["Subsurface Scale"].default_value = 0.008
    if tex:
        img = nt.nodes.new("ShaderNodeTexImage")
        img.image = bpy.data.images.load(tex, check_existing=True)
        src = img.outputs["Color"]
        if desat is not None:
            hsv = nt.nodes.new("ShaderNodeHueSaturation")
            hsv.inputs["Saturation"].default_value = desat
            nt.links.new(src, hsv.inputs["Color"])
            src = hsv.outputs["Color"]
        if tex_mix:
            mix = nt.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY" if tex_mix < 0 else "MIX"
            mix.inputs["Factor"].default_value = abs(tex_mix)
            mix.inputs["A"].default_value = hexcol(color)
            nt.links.new(src, mix.inputs["B"])
            src = mix.outputs["Result"]
        nt.links.new(src, bsdf.inputs["Base Color"])
        if alpha_tex:
            nt.links.new(img.outputs["Alpha"], bsdf.inputs["Alpha"])
    return m


def set_material(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def image_of(o, avoid="normal"):
    for mat in o.data.materials:
        for n in mat.node_tree.nodes if mat and mat.node_tree else []:
            if n.type == "TEX_IMAGE" and n.image and avoid not in n.image.name.lower():
                return bpy.path.abspath(n.image.filepath)
    return None


# ------------------------------------------------------------------ people

AGE = {"infant": 0.0, "child": 0.115, "adult": 0.5, "senior": 0.86}


class Person:
    """an MPFB human on the default rig; posed by aiming bones at world points"""

    def __init__(self, name, sex, age, *, look, clothes=(), hair=None, skin="skin-mid", targets=None, macros=None,
                 brows="eyebrow010", lashes="eyelashes02", shoes=None):
        HS, TS, AS, LS = (mpfb(k) for k in ("HumanService", "TargetService", "AssetService", "LocationService"))
        self.name = name
        m = TS.get_default_macro_info_dict()
        m.update({"gender": {"male": 1.0, "female": 0.0}.get(sex, 0.5), "age": AGE[age], "muscle": 0.5,
                  "weight": 0.5, "proportions": 0.6, "height": 0.5}, **(macros or {}))
        m["race"] = {"asian": 0.34, "caucasian": 0.33, "african": 0.33}
        before = set(bpy.data.objects)
        self.body = HS.create_human(macro_detail_dict=m)
        for t, w in (targets or {}).items():
            TS.load_target(self.body, os.path.join(LS.get_mpfb_data("targets"), t + ".target.gz"), weight=w)
        self.rig = HS.add_builtin_rig(self.body, "default")
        self.parts = {}
        assets = [("eyes", "low-poly.mhclo", "Eyes"), ("eyebrows", f"{brows}.mhclo", "Eyebrows"),
                  ("eyelashes", f"{lashes}.mhclo", "Eyelashes")]
        assets += [("hair", f"{hair}.mhclo", "Hair")] if hair else []
        assets += [("clothes", f"{c}.mhclo", "Clothes") for c in list(clothes) + ([shoes] if shoes else [])]
        for sub, f, kind in assets:
            got = set(bpy.data.objects)
            HS.add_mhclo_asset(AS.find_asset_absolute_path(f, asset_subdir=sub), self.body, asset_type=kind, subdiv_levels=0)
            self.parts[f.split(".")[0]] = next(iter(set(bpy.data.objects) - got))
        self.objects = list(set(bpy.data.objects) - before)
        self.hair = hair
        for o in self.objects:
            o.name = f"{name}.{o.name}"
        self.rest = {b.name: (self.rig.matrix_world @ b.head_local, self.rig.matrix_world @ b.tail_local) for b in self.rig.data.bones}
        self.rest_co = self.skin_points()

        set_material(self.body, principled(f"{name}.skin", PALETTE[skin], rough=0.5, sss=0.15, tex=image_of(self.body, "normal"),
                                           tex_mix=-0.35, desat=0.0))
        eyes = self.parts["low-poly"]
        set_material(eyes, principled(f"{name}.eyes", "#FFFFFF", rough=0.15, tex=image_of(eyes), desat=0.35))
        for key in (brows, lashes):
            o = self.parts[key]
            set_material(o, principled(f"{name}.{key}", PALETTE[f"{look}-hair"], rough=0.8, tex=image_of(o), tex_mix=-0.4,
                                       alpha_tex=True))
        if hair:
            o = self.parts[hair]
            set_material(o, principled(f"{name}.hair", PALETTE[f"{look}-hair"], rough=0.45, tex=image_of(o), tex_mix=-0.55,
                                       alpha_tex=True))
        for c in clothes:
            self.two_tone(self.parts[c], PALETTE[f"{look}-top"], PALETTE[f"{look}-bottom"])
        if shoes:
            o = self.parts[shoes]
            set_material(o, principled(f"{name}.shoes", PALETTE[f"{look}-shoes"], rough=0.6, tex=image_of(o), tex_mix=-0.3))
            # the socks above the shoe would poke through trouser hems: keep only the shoe
            import bmesh
            ankle = self.rest["foot.L"][0].z + 0.01 * self.scale()
            bm = bmesh.new()
            bm.from_mesh(o.data)
            bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().z > ankle], context="FACES")
            bm.to_mesh(o.data)
            bm.free()
            # and bring back the bare ankle the socks hid (seen below shorts)
            g = self.body.vertex_groups.get(f"Delete.{shoes}")
            if g:
                g.remove([i for i, p in enumerate(self.rest_co) if p.z > ankle - 0.005 * self.scale()])
        for pb in self.rig.pose.bones:
            pb.rotation_mode = "QUATERNION"

    def two_tone(self, o, top, bottom):
        """garment (MakeHuman casual suits: top in the upper half of the UV map, sleeves at the right edge):
        the top gets one colour, the trousers another; the texture only adds its folds"""
        img = image_of(o)
        o.data.materials.clear()
        o.data.materials.append(principled(f"{self.name}.top", top, rough=0.85, tex=img, tex_mix=-0.1, desat=0.0))
        o.data.materials.append(principled(f"{self.name}.bottom", bottom, rough=0.9, tex=img, tex_mix=-0.25, desat=0.0))
        # whole UV islands (one cut pattern piece each) take one colour, so the hem line follows the garment's own edge
        import bmesh
        bm = bmesh.new()
        bm.from_mesh(o.data)
        lay = bm.loops.layers.uv.active
        parent = list(range(len(bm.faces)))

        def root(i):
            while parent[i] != i:
                parent[i] = parent[parent[i]]
                i = parent[i]
            return i
        for e in bm.edges:
            if len(e.link_faces) != 2:
                continue
            f1, f2 = e.link_faces
            uv1 = {l.vert.index: l[lay].uv.copy() for l in f1.loops if l.vert in e.verts}
            uv2 = {l.vert.index: l[lay].uv.copy() for l in f2.loops if l.vert in e.verts}
            if all((uv1[k] - uv2[k]).length < 1e-5 for k in uv1):
                parent[root(f1.index)] = root(f2.index)
        pieces = {}
        for f in bm.faces:
            c = sum((l[lay].uv for l in f.loops), Vector((0, 0))) / len(f.loops)
            pieces.setdefault(root(f.index), []).append((f, c))
        for faces in pieces.values():
            u = sum(c.x for _, c in faces) / len(faces)
            v = sum(c.y for _, c in faces) / len(faces)
            top = v > 0.5 or u > 0.78
            for f, _ in faces:
                f.material_index = 0 if top else 1
        bm.to_mesh(o.data)
        bm.free()
        o["top_faces"] = [p.index for p in o.data.polygons if p.material_index == 0]
        # trouser tops under the shirt sit a little further in, so they never poke through when the body bends
        if "sportsuit01" in o.name:
            return  # a crop top: the waistband shows, nothing to tuck under
        hip = self.rest["upperleg01.L"][0].z + 0.02 * self.scale()
        tuck = o.vertex_groups.new(name="tuck")
        tuck.add([i for p in o.data.polygons if p.material_index == 1 for i in p.vertices if o.data.vertices[i].co.z > hip], 1.0, "REPLACE")
        d = o.modifiers.new("tuck", "DISPLACE")
        d.vertex_group = "tuck"
        d.strength = -0.012 * self.scale()
        d.mid_level = 0.0

    # --- skin points by vertex index (the helper mask is off while sampling, so indices stay the base mesh's)

    def skin_points(self, normals=False):
        mask = [m for m in self.body.modifiers if m.type == "MASK"]
        for m in mask:
            m.show_viewport = False
        update()
        dg = bpy.context.evaluated_depsgraph_get()
        ev = self.body.evaluated_get(dg)
        me = ev.to_mesh()
        mw = ev.matrix_world
        co = [mw @ v.co for v in me.vertices]
        nr = [(mw.to_3x3() @ v.normal).normalized() for v in me.vertices] if normals else None
        ev.to_mesh_clear()
        for m in mask:
            m.show_viewport = True
        update()
        return (co, nr) if normals else co

    def landmark(self, test, key):
        """index of the rest-pose skin vertex passing `test` that maximises `key` (rest coordinates)"""
        body = set(self.body_vertices())
        best = max((i for i, p in enumerate(self.rest_co) if i in body and test(p)), key=lambda i: key(self.rest_co[i]))
        return best

    def body_vertices(self):
        if not hasattr(self, "_body_v"):
            g = self.body.vertex_groups.get("body")
            self._body_v = [v.index for v in self.body.data.vertices if g and any(e.group == g.index and e.weight > 0.5 for e in v.groups)]
        return self._body_v

    def at(self, *idx, normal=False):
        co, nr = self.skin_points(normals=True)
        if normal:
            return [(co[i], nr[i]) for i in idx] if len(idx) > 1 else (co[idx[0]], nr[idx[0]])
        return [co[i] for i in idx] if len(idx) > 1 else co[idx[0]]

    # rest landmarks (front = −Y, left = +X)
    def lm_sternum(self, drop=0.0):
        z = (self.rest["breast.L"][1].z + self.rest["breast.R"][1].z) / 2 - drop
        return self.landmark(lambda p: abs(p.x) < 0.012 and abs(p.z - z) < 0.012, lambda p: -p.y)

    def lm_back(self, drop=0.0):
        z = (self.rest["breast.L"][1].z + self.rest["breast.R"][1].z) / 2 - drop
        return self.landmark(lambda p: abs(p.x) < 0.02 and abs(p.z - z) < 0.015, lambda p: p.y)

    def lm_mouth(self):
        z = (self.rest["oris05"][1].z + self.rest["oris01"][1].z) / 2
        return self.landmark(lambda p: abs(p.x) < 0.004 and abs(p.z - z) < 0.004, lambda p: -p.y)

    def lm_nose(self):
        z = self.rest["oris06"][0].z + 0.012
        return self.landmark(lambda p: abs(p.x) < 0.006 and abs(p.z - z) < 0.02, lambda p: -p.y)

    def lm_forehead(self):
        z = self.rest["eye.L"][0].z + 0.045 * self.scale()
        return self.landmark(lambda p: abs(p.x) < 0.01 and abs(p.z - z) < 0.01, lambda p: -p.y)

    def lm_chin(self):
        z = self.rest["special04"][0].z
        return self.landmark(lambda p: abs(p.x) < 0.01 and abs(p.z - z) < 0.012, lambda p: -p.y)

    def lm_shoulder(self, s):
        """front of the shoulder, just inside the joint"""
        sx = 1 if s == "L" else -1
        c = self.rest[f"upperarm01.{s}"][0]
        k = self.scale()
        return self.landmark(lambda p: abs(p.x - c.x + sx * 0.035 * k) < 0.015 * k and abs(p.z - c.z + 0.01 * k) < 0.015 * k, lambda p: -p.y)

    def lm_side(self, s, drop=0.05):
        """mid-axillary line below the armpit"""
        sx = 1 if s == "L" else -1
        z = (self.rest["breast.L"][1].z + self.rest["breast.R"][1].z) / 2 - drop * self.scale()
        yc = self.rest["spine02"][0].y - 0.03 * self.scale()
        return self.landmark(lambda p: abs(p.z - z) < 0.012 and abs(p.y - yc) < 0.03 and abs(p.x) < 0.25, lambda p: p.x * sx)

    def lm_infraclavicular(self, s):
        sx = 1 if s == "L" else -1
        z = self.rest["clavicle.L"][0].z - 0.075 * self.scale()
        return self.landmark(lambda p: abs(p.z - z) < 0.012 and abs(p.x - sx * 0.075 * self.scale()) < 0.012, lambda p: -p.y)

    def lm_bump_side(self, s, up=0.0):
        """side of the pregnant belly"""
        sx = 1 if s == "L" else -1
        z = self.rest["spine04"][0].z + 0.02 + up
        return self.landmark(lambda p: abs(p.z - z) < 0.015 and p.y < -0.05 and p.x * sx > 0, lambda p: -p.y * 0.5 + p.x * sx * 0.9)

    def lm_throat(self):
        """front of the neck, between chin and collarbones"""
        z = (self.rest["special04"][0].z * 0.45 + self.rest["clavicle.L"][0].z * 0.55)
        return self.landmark(lambda p: abs(p.x) < 0.012 and abs(p.z - z) < 0.012, lambda p: -p.y)

    def lm_navel(self, up=0.0):
        """front of the belly at navel height (+ `up` metres)"""
        z = self.rest["spine04"][0].z - 0.03 * self.scale() + up
        return self.landmark(lambda p: abs(p.x) < 0.015 and abs(p.z - z) < 0.012, lambda p: -p.y)

    def lm_blades(self):
        """back, between the shoulder blades"""
        z = self.rest["spine01"][0].z - 0.02 * self.scale()
        return self.landmark(lambda p: abs(p.x) < 0.015 and abs(p.z - z) < 0.015, lambda p: p.y)

    def open_mouth(self, deg=10.0):
        side = self.rig.matrix_world.to_3x3() @ X
        self.rotate("jaw", side, deg)

    def lm_bump_top(self):
        z = self.rest["spine04"][0].z + 0.02
        return self.landmark(lambda p: abs(p.x) < 0.012 and abs(p.z - z) < 0.02, lambda p: -p.y)

    def lm_sole(self, s):
        f = self.rest[f"foot.{s}"][0]
        return self.landmark(lambda p: abs(p.x - f.x) < 0.03 and p.z < f.z, lambda p: p.y - p.z * 0.2)

    def scale(self):
        return (self.rest["head"][0].z - self.rest["foot.L"][0].z) / 1.5

    # --- posing (world space)

    def pb(self, n):
        return self.rig.pose.bones[n]

    def head(self, n):
        return self.rig.matrix_world @ self.pb(n).head

    def tail(self, n):
        return self.rig.matrix_world @ self.pb(n).tail

    def to_arm(self, v, point=True):
        mi = self.rig.matrix_world.inverted()
        return mi @ Vector(v) if point else (mi.to_3x3() @ Vector(v))

    def rotate(self, n, axis, deg):
        """rotate a bone (and its children) about its head around a world axis"""
        pb = self.pb(n)
        a = self.to_arm(axis, point=False).normalized()
        h = pb.head.copy()
        pb.matrix = Matrix.Translation(h) @ Matrix.Rotation(math.radians(deg), 4, a) @ Matrix.Translation(-h) @ pb.matrix
        update()

    def turn(self, n, q):
        pb = self.pb(n)
        r = self.rig.matrix_world.to_3x3().inverted() @ q.to_matrix() @ self.rig.matrix_world.to_3x3()
        h = pb.head.copy()
        pb.matrix = Matrix.Translation(h) @ r.to_4x4() @ Matrix.Translation(-h) @ pb.matrix
        update()

    def aim(self, n, target=None, direction=None):
        """turn a bone (minimal twist) so it points at a world point / along a world direction"""
        d = Vector(direction) if direction is not None else Vector(target) - self.head(n)
        y = (self.tail(n) - self.head(n)).normalized()
        self.turn(n, y.rotation_difference(d.normalized()))

    def limb(self, upper, lower, end, target, pole):
        """two-segment IK: aims the segments so bone `end` starts at `target`, bending toward `pole`"""
        s = self.head(upper[0])
        a = (self.rest[lower[0]][0] - self.rest[upper[0]][0]).length
        b = (self.rest[end][0] - self.rest[lower[0]][0]).length
        t = Vector(target)
        d = min((t - s).length, (a + b) * 0.9995)
        n = (t - s).normalized()
        p = Vector(pole) - s
        p = (p - n * p.dot(n)).normalized()
        cos_a = max(-1, min(1, (a * a + d * d - b * b) / (2 * a * d)))
        e = s + n * a * cos_a + p * a * math.sqrt(1 - cos_a * cos_a)
        for bn in upper:
            self.aim(bn, e)
        for bn in lower:
            self.aim(bn, s + n * d)

    def arm(self, s, target, pole):
        self.limb([f"upperarm01.{s}", f"upperarm02.{s}"], [f"lowerarm01.{s}", f"lowerarm02.{s}"], f"wrist.{s}", target, pole)

    def leg(self, s, target, pole):
        self.limb([f"upperleg01.{s}", f"upperleg02.{s}"], [f"lowerleg01.{s}", f"lowerleg02.{s}"], f"foot.{s}", target, pole)

    def arm_length(self, s="L"):
        r = self.rest
        return (r[f"lowerarm01.{s}"][0] - r[f"upperarm01.{s}"][0]).length + (r[f"wrist.{s}"][0] - r[f"lowerarm01.{s}"][0]).length

    def hand_frame(self, s, rest=False):
        """(fingers direction, palm normal) of a hand, world space"""
        g = (lambda n: self.rest[n][0]) if rest else self.head
        fwd = (g(f"finger3-1.{s}") - g(f"wrist.{s}")).normalized()
        across = g(f"finger2-1.{s}") - g(f"finger5-1.{s}")
        palm = fwd.cross(across).normalized()
        return fwd, -palm if s == "R" else palm

    def hand(self, s, fingers, palm):
        """orient the wrist: fingers along a world direction, palm facing a world direction"""
        f0, p0 = self.hand_frame(s)
        f1 = Vector(fingers).normalized()
        p1 = Vector(palm)
        p1 = (p1 - f1 * p1.dot(f1)).normalized()
        a = Matrix((f0, p0, f0.cross(p0))).transposed()
        b = Matrix((f1, p1, f1.cross(p1))).transposed()
        self.turn(f"wrist.{s}", (b @ a.transposed()).to_quaternion())

    def palm_point(self, s, out=0.012):
        f, p = self.hand_frame(s)
        return self.head(f"wrist.{s}").lerp(self.head(f"finger3-1.{s}"), 0.45) + p * out

    def curl(self, s, deg, thumb=None, fingers=(2, 3, 4, 5), spread=0.0):
        """bend finger joints toward the palm"""
        for i in fingers:
            for j in (1, 2, 3):
                self.bend(f"finger{i}-{j}.{s}", deg * (0.7 if j == 1 else 1.0), s)
        if thumb is not None:
            for j in (2, 3):
                self.bend(f"finger1-{j}.{s}", thumb, s)

    def bend(self, n, deg, s):
        fwd, palm = self.hand_frame(s)
        axis = (self.tail(n) - self.head(n)).normalized().cross(palm)
        self.rotate(n, axis, deg)

    def point_thumb(self, s, target):
        for n in (f"finger1-1.{s}", f"finger1-2.{s}", f"finger1-3.{s}"):
            self.aim(n, target)

    def face_dir(self):
        """where the face looks (world)"""
        r = self.rest["head"]
        m = self.rig.matrix_world.to_3x3() @ self.pb("head").matrix.to_3x3() @ self.rig.data.bones["head"].matrix_local.to_3x3().inverted()
        del r
        return (m @ -Y).normalized()

    def look(self, target, amount=1.0, neck=0.4):
        """turn neck and head so the face points at a world point"""
        eyes = (self.head("eye.L") + self.head("eye.R")) / 2
        q = self.face_dir().rotation_difference((Vector(target) - eyes).normalized())
        q = Matrix.Identity(3).to_quaternion().slerp(q, amount)
        self.turn("neck01", Matrix.Identity(3).to_quaternion().slerp(q, neck))
        eyes = (self.head("eye.L") + self.head("eye.R")) / 2
        q2 = self.face_dir().rotation_difference((Vector(target) - eyes).normalized())
        self.turn("head", Matrix.Identity(3).to_quaternion().slerp(q2, amount))

    def close_eyes(self, amount=1.0):
        side = self.rig.matrix_world.to_3x3() @ X
        for s in "LR":
            self.rotate(f"orbicularis03.{s}", side, 25 * amount)
            self.rotate(f"orbicularis04.{s}", side, -8 * amount)

    def ground(self, z=0.0):
        """move the whole person so their lowest point touches z"""
        update()
        dg = bpy.context.evaluated_depsgraph_get()
        low = 1e9
        for o in [self.body] + [o for k, o in self.parts.items() if k.startswith("shoes")]:
            ev = o.evaluated_get(dg)
            me = ev.to_mesh()
            low = min([low] + [(ev.matrix_world @ v.co).z for v in me.vertices])
            ev.to_mesh_clear()
        self.rig.location.z += z - low
        update()

    def reset_pose(self):
        for pb in self.rig.pose.bones:
            pb.matrix_basis = Matrix()
        self.rig.matrix_world = Matrix()
        update()

    def strip_top(self, garment, keep=None, unmask=None):
        """take the top off (or cut its front open when `keep` says which faces stay)"""
        import bmesh
        o = self.parts[garment]
        top = set(o["top_faces"])
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bm.faces.ensure_lookup_table()
        gone = [f for f in bm.faces if f.index in top and (keep is None or not keep(f.calc_center_median()))]
        bmesh.ops.delete(bm, geom=gone, context="FACES")
        bm.to_mesh(o.data)
        bm.free()
        self.unmask(unmask or (lambda p: p.z > self.rest["upperleg01.L"][0].z + 0.08 * self.scale()))

    def open_front(self, garment, half=0.19, side=True):
        """cut the top open over the chest (and under the left arm), keeping sleeves, back and the lower hem"""
        k = self.scale()
        nz = (self.rest["breast.L"][1].z + self.rest["breast.R"][1].z) / 2
        zc = nz - 0.12 * k

        def cut(c, m=0.0):
            front = c.z > zc - m and c.y < (0.03 + m) * k and abs(c.x) < (half + m) * k
            under = side and c.x > 0.05 * k and nz - (0.16 + m) * k < c.z < nz + 0.06 * k and c.y < (0.09 + m) * k
            return front or under
        self.strip_top(garment, keep=lambda c: not cut(c), unmask=lambda p: cut(p, 0.02))

    def unmask(self, where):
        """bring back skin that a garment's mask hides, where `where(rest point)` holds"""
        for m in self.body.modifiers:
            if m.type == "MASK" and m.name.startswith("Delete.") and m.vertex_group:
                g = self.body.vertex_groups[m.vertex_group]
                g.remove([i for i, p in enumerate(self.rest_co) if where(p)])
        update()

    def bra(self, color):
        """a plain sports-bra band cut from the skin, standing just off it"""
        nz = (self.rest["breast.L"][1].z + self.rest["breast.R"][1].z) / 2
        k = self.scale()
        lo, hi = nz - 0.075 * k, nz + 0.075 * k
        keep = {i for i, p in enumerate(self.rest_co) if lo < p.z < hi and (p.y < 0.02 or lo + 0.02 * k < p.z < hi - 0.03 * k)}
        return self.shell("bra", color, keep)

    def weighted(self, prefixes, least=0.3):
        """skin vertices driven by bones whose names start with any of `prefixes`"""
        gi = {g.index for g in self.body.vertex_groups if g.name.startswith(tuple(prefixes))}
        return {v.index for v in self.body.data.vertices if any(e.group in gi and e.weight >= least for e in v.groups)}

    def shell(self, key, color, keep, lift=0.003, thickness=0.004, rough=0.8):
        """a layer cut from the skin (vertex indices `keep`), standing just off it and moving with it: gloves, a band, a wrap"""
        import bmesh
        o = self.body.copy()
        o.data = self.body.data.copy()
        bpy.context.collection.objects.link(o)
        o.name = f"{self.name}.{key}"
        for m in list(o.modifiers):
            if m.type == "MASK":
                o.modifiers.remove(m)
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bm.faces.ensure_lookup_table()
        body = set(self.body_vertices())
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if not all(v.index in keep and v.index in body for v in f.verts)], context="FACES")
        bm.to_mesh(o.data)
        bm.free()
        sol = o.modifiers.new("thick", "SOLIDIFY")
        sol.thickness = -thickness
        sol.offset = 1.0
        d = o.modifiers.new("lift", "DISPLACE")
        d.strength = lift
        o.modifiers.move(len(o.modifiers) - 1, 0)
        o.modifiers.move(len(o.modifiers) - 1, 0)
        set_material(o, principled(f"{self.name}.{key}", color, rough=rough))
        self.parts[key] = o
        self.objects.append(o)
        return o

    def cut_under(self, garment, points, radius):
        """remove garment faces near world points (where a pad sits on the skin)"""
        import bmesh
        o = self.parts[garment]
        dg = bpy.context.evaluated_depsgraph_get()
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        near = {p.index for p in me.polygons if any((ev.matrix_world @ p.center - q).length < radius for q in points)}
        ev.to_mesh_clear()
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index in near], context="FACES")
        bm.to_mesh(o.data)
        bm.free()
        for m in self.body.modifiers:
            if m.type == "MASK" and m.name.startswith("Delete."):
                m.show_viewport = m.show_render = False

    def hang_hair(self, amount=1.0):
        """let long hair fall with gravity (it is skinned to the head, so it stays stiff when bending over);
        freezes the hair, so call it after the last pose change"""
        o = self.parts[self.hair]
        dg = bpy.context.evaluated_depsgraph_get()
        ev = o.evaluated_get(dg)
        posed = [v.co.copy() for v in ev.to_mesh().vertices]
        ev.to_mesh_clear()
        b, pb = self.rig.data.bones["head"], self.pb("head")
        rest_c, rest_down = b.head_local.lerp(b.tail_local, 0.5), (b.head_local - b.tail_local).normalized()
        c, down = pb.head.lerp(pb.tail, 0.5), (pb.head - pb.tail).normalized()
        g = (self.rig.matrix_world.to_3x3().inverted() @ -Z).normalized()
        q = down.rotation_difference(g)
        reach = (b.tail_local - b.head_local).length
        for m in [m for m in o.modifiers if m.type == "ARMATURE"]:
            o.modifiers.remove(m)
        one = Matrix.Identity(3).to_quaternion()
        for v, p in zip(o.data.vertices, posed):
            t = min(1.0, max(0.0, (v.co - rest_c).dot(rest_down) / reach))
            v.co = c + one.slerp(q, t * t * (3 - 2 * t) * amount) @ (p - c)
        update()

    def warp(self, center, offset, radius, garments=()):
        """push the skin (and garments) near a world point by an offset with a smooth falloff"""
        a = bpy.data.objects.new(f"{self.name}.warp-from", None)
        b = bpy.data.objects.new(f"{self.name}.warp-to", None)
        for e in (a, b):
            bpy.context.collection.objects.link(e)
        a.location = center
        b.location = Vector(center) + Vector(offset)
        for o in [self.body] + [self.parts[g] for g in garments]:
            m = o.modifiers.new("warp", "WARP")
            m.object_from, m.object_to = a, b
            m.falloff_radius = radius
            m.falloff_type = "SMOOTH"
            m.use_volume_preserve = False
        update()


# ------------------------------------------------------------------ cast


def rescuer():
    return Person("rescuer", "female", "adult", look="rescuer", clothes=["female_casualsuit01"], hair="short03",
                  skin="skin-mid", shoes="shoes06", macros={"cupsize": 0.5, "muscle": 0.55, "height": 0.62, "proportions": 0.85},
                  brows="eyebrow010", lashes="eyelashes03")


def helper():
    return Person("helper", "male", "adult", look="helper", clothes=["male_casualsuit04"], hair="short04", skin="skin-tan",
                  shoes="shoes03", macros={"muscle": 0.6, "height": 0.55}, brows="eyebrow012", lashes="eyelashes01")


def casualty(variant):
    if variant == "pregnant":
        return Person("casualty", "female", "adult", look="woman", clothes=["female_sportsuit01"], hair="bob02", skin="skin-tan",
                      shoes=None, macros={"cupsize": 0.6, "weight": 0.6},
                      targets={"stomach/stomach-pregnant-incr": 1.4, "stomach/stomach-navel-out": 0.5},
                      brows="eyebrow010", lashes="eyelashes03")
    if variant == "woman":
        return Person("casualty", "female", "adult", look="woman", clothes=["female_casualsuit02"], hair="bob02", skin="skin-tan",
                      shoes="shoes03", macros={"cupsize": 0.6, "weight": 0.55}, brows="eyebrow010", lashes="eyelashes03")
    if variant == "child":
        return Person("casualty", "male", "child", look="child", clothes=["male_casualsuit04"], hair="short02", skin="skin-deep",
                      shoes="shoes05", brows="eyebrow006", lashes="eyelashes01")
    if variant == "girl":
        return Person("casualty", "female", "child", look="girl", clothes=["male_casualsuit04"], hair="long01", skin="skin-mid",
                      shoes="shoes05", brows="eyebrow010", lashes="eyelashes03")
    if variant == "senior":
        return Person("casualty", "male", "senior", look="senior", clothes=["male_casualsuit06"], hair="short02", skin="skin-light",
                      shoes="shoes02", macros={"muscle": 0.4, "weight": 0.6, "height": 0.45}, brows="eyebrow012", lashes="eyelashes02")
    if variant == "senior_woman":
        return Person("casualty", "female", "senior", look="gran", clothes=["female_casualsuit02"], hair="bob02", skin="skin-light",
                      shoes="shoes03", macros={"cupsize": 0.5, "weight": 0.6, "height": 0.4}, brows="eyebrow010", lashes="eyelashes03")
    if variant == "infant":
        return Person("casualty", "neutral", "infant", look="baby", clothes=["female_casualsuit02"], skin="skin-light",
                      brows="eyebrow006", lashes="eyelashes01", macros={"weight": 0.7})
    return Person("casualty", "male", "adult", look="man", clothes=["male_casualsuit06"], hair="short02", skin="skin-light",
                  shoes="shoes02", macros={"muscle": 0.55, "weight": 0.55}, brows="eyebrow012", lashes="eyelashes02")


KIDS = ("child", "girl")
GARMENT = {"adult": "male_casualsuit06", "senior": "male_casualsuit06", "senior_woman": "female_casualsuit02", "pregnant": "female_sportsuit01", "woman": "female_casualsuit02", "child": "male_casualsuit04", "girl": "male_casualsuit04", "infant": "female_casualsuit02"}


# ------------------------------------------------------------------ poses


def lie_supine(p, head_dir=X, z=0.0, arms_out=0.12):
    """on the back, head toward `head_dir` (world, horizontal), arms by the sides, eyes closed"""
    rot = Matrix.Rotation(math.radians(-90), 4, "X")  # front (−Y) → up
    p.rig.matrix_world = yaw(Y, head_dir) @ rot
    update()
    down = ((p.head("upperleg01.L") + p.head("upperleg01.R")) / 2 - p.head("neck01")).normalized()
    for s in "LR":
        out = p.head(f"upperarm01.{s}") - p.head("neck01")
        out = (out - down * out.dot(down)).normalized()
        for n in ("upperarm01", "upperarm02"):
            p.aim(f"{n}.{s}", direction=down + out * arms_out)
        for n in ("lowerarm01", "lowerarm02"):
            p.aim(f"{n}.{s}", direction=down + out * (arms_out + 0.08) + Z * 0.06)
        p.hand(s, down + out * 0.1, -out * 0.5 - Z)
        p.curl(s, 18, thumb=5)
    # legs a little apart, feet relaxed outward
    for s in "LR":
        out = p.head(f"upperleg01.{s}") - p.head("root")
        out = (out - down * out.dot(down)).normalized()
        for n in ("upperleg01", "upperleg02", "lowerleg01", "lowerleg02"):
            p.aim(f"{n}.{s}", direction=down + out * 0.05)
        p.rotate(f"upperleg01.{s}", down, 10 if s == "L" else -10)
    p.close_eyes()
    p.ground(z)
    return down


def kneel(p, facing, at=None, lean=0.0, thigh=10.0, spread=0.05, sit=0.0, gaze=True):
    """kneel facing a world direction: thighs `thigh` deg forward, shins flat behind, feet pointed;
    `lean` bends the trunk forward (deg) from the hips; `sit` drops the hips toward the heels (0..1)"""
    f = Vector(facing).normalized()
    p.reset_pose()
    p.rig.matrix_world = yaw(-Y, f)
    update()
    side = f.cross(Z).normalized()  # the person's right
    t = math.radians(thigh + sit * 75)
    for s, sgn in (("L", -1), ("R", 1)):
        d = -Z * math.cos(t) + f * math.sin(t) + side * sgn * spread
        p.aim(f"upperleg01.{s}", direction=d)
        p.aim(f"upperleg02.{s}", direction=d)
        # shins and the tops of the feet flat on the floor, so knees, shins and feet all carry weight
        back = (-f + Z * 0.03 + side * sgn * 0.04).normalized()
        p.aim(f"lowerleg01.{s}", direction=back)
        p.aim(f"lowerleg02.{s}", direction=back)
        p.aim(f"foot.{s}", direction=(-f - Z * 0.12))
    trunk = lean + thigh + sit * 75
    for n, k in (("spine05", 0.72), ("spine04", 0.1), ("spine03", 0.07), ("spine02", 0.06), ("spine01", 0.05)):
        p.rotate(n, side, -trunk * k)
    if gaze:
        p.rotate("neck01", side, min(lean, 60) * 0.35)
        p.rotate("head", side, min(lean, 60) * 0.25)
    p.ground(0.0)
    if at is not None:
        c = (p.head("lowerleg01.L") + p.head("lowerleg01.R")) / 2
        p.rig.location += Vector((at[0] - c.x, at[1] - c.y, 0))
        update()
    return side


def stand(p, facing, lean=0.0, at=None, z=0.0, knees=0.0, stride=0.0, wide=0.05):
    """stand facing a world direction, trunk bent `lean` deg from the hips, knees bent `knees` deg;
    `stride` deg puts the left foot forward and the right back"""
    f = Vector(facing).normalized()
    p.reset_pose()
    p.rig.matrix_world = yaw(-Y, f)
    update()
    side = f.cross(Z).normalized()
    a = math.radians(knees)
    for s, sgn in (("L", -1), ("R", 1)):
        b = a + math.radians(stride) * (1 if s == "L" else -1)
        for n in ("upperleg01", "upperleg02"):
            p.aim(f"{n}.{s}", direction=-Z * math.cos(b) + f * math.sin(b) + side * sgn * wide)
        for n in ("lowerleg01", "lowerleg02"):
            p.aim(f"{n}.{s}", direction=-Z * math.cos(a) - f * math.sin(a) * (0 if stride else 1) + side * sgn * 0.02)
        p.aim(f"foot.{s}", direction=f - Z * 0.25)
    for n, k in (("spine05", 0.55), ("spine04", 0.15), ("spine03", 0.12), ("spine02", 0.1), ("spine01", 0.08)):
        p.rotate(n, side, -(lean + knees) * k)
    p.ground(z)
    if at is not None:
        c = (p.head("foot.L") + p.head("foot.R")) / 2
        p.rig.location += Vector((at[0] - c.x, at[1] - c.y, 0))
        update()
    return side


def hang_arms(p, f, side, forward=0.1, out=0.12, bend=0.25):
    """arms hanging loosely at the sides"""
    for s, sgn in (("L", -1), ("R", 1)):
        p.aim(f"upperarm01.{s}", direction=-Z + side * sgn * out + f * forward)
        p.aim(f"upperarm02.{s}", direction=-Z + side * sgn * out + f * forward)
        for n in ("lowerarm01", "lowerarm02"):
            p.aim(f"{n}.{s}", direction=-Z + side * sgn * out * 0.5 + f * (forward + bend))
        p.hand(s, -Z + f * (forward + bend), -side * sgn)
        p.curl(s, 22, thumb=10)


def sit(p, facing, at=None, lean=0.0):
    """sit with thighs level, shins down, feet flat (the seat goes under the hips afterwards)"""
    f = Vector(facing).normalized()
    p.reset_pose()
    p.rig.matrix_world = yaw(-Y, f)
    update()
    side = f.cross(Z).normalized()
    for s, sgn in (("L", -1), ("R", 1)):
        for n in ("upperleg01", "upperleg02"):
            p.aim(f"{n}.{s}", direction=f + side * sgn * 0.12)
        for n in ("lowerleg01", "lowerleg02"):
            p.aim(f"{n}.{s}", direction=-Z + f * 0.1 + side * sgn * 0.03)
        p.aim(f"foot.{s}", direction=f - Z * 0.3)
    for n, k in (("spine05", 0.5), ("spine04", 0.2), ("spine03", 0.12), ("spine02", 0.1), ("spine01", 0.08)):
        p.rotate(n, side, -lean * k)
    p.ground(0.0)
    if at is not None:
        c = (p.head("upperleg01.L") + p.head("upperleg01.R")) / 2
        p.rig.location += Vector((at[0] - c.x, at[1] - c.y, 0))
    update()
    return side


def relax_arms(p, f, side):
    """hands resting on the thighs"""
    for s, sgn in (("L", -1), ("R", 1)):
        knee = p.head(f"lowerleg01.{s}")
        hip = p.head(f"upperleg01.{s}")
        p.arm(s, hip.lerp(knee, 0.6) + Z * 0.06 + side * sgn * 0.02, p.head(f"upperarm01.{s}") - f * 0.3 + side * sgn)
        p.hand(s, knee - hip, -Z + side * sgn * 0.3)
        p.curl(s, 20, thumb=10)

def reach_pose(p, facing, targets, lean_for, at_xy, thigh=10.0, standing=False, table=0.0, knees=0.0, sit=0.0):
    """kneel/stand at a spot and lean until a point on the body (lean_for(p) → world point) reaches a target height"""
    f = Vector(facing).normalized()
    goal = targets
    lo, hi = -10.0, 88.0
    for _ in range(14):
        lean = (lo + hi) / 2
        side = stand(p, f, lean=lean, at=at_xy, z=table, knees=knees) if standing else kneel(p, f, lean=lean, thigh=thigh, at=at_xy, sit=sit)
        if lean_for(p).z > goal:
            lo = lean
        else:
            hi = lean
    return side


# ------------------------------------------------------------------ props


def box(name, size, loc, color, bevel=0.01, rot=None, rough=0.5):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if rot is not None:
        o.rotation_euler = rot
    if bevel:
        m = o.modifiers.new("bevel", "BEVEL")
        m.width = bevel
        m.segments = 4
    set_material(o, principled(name, PALETTE.get(color, color), rough=rough))
    bpy.ops.object.shade_smooth()
    return o


def cylinder(name, r, h, loc, color, rot=None, verts=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc)
    o = bpy.context.object
    o.name = name
    if rot is not None:
        o.rotation_euler = rot
    set_material(o, principled(name, PALETTE.get(color, color), rough=0.45))
    bpy.ops.object.shade_smooth()
    return o


def frame_at(o, origin, x_axis, y_axis):
    """place an object with its local X/Y along world axes (Z = X × Y)"""
    xa = Vector(x_axis).normalized()
    ya = Vector(y_axis)
    ya = (ya - xa * ya.dot(xa)).normalized()
    m = Matrix((xa, ya, xa.cross(ya))).transposed().to_4x4()
    m.translation = origin
    o.matrix_world = m
    return o


def phone_in(p, s):
    """a phone lying in the palm, screen up out of the hand"""
    f, palm = p.hand_frame(s)
    c = p.palm_point(s, out=0.012)
    o = box("phone", (0.072, 0.15, 0.009), (0, 0, 0), "phone", bevel=0.006)
    scr = box("screen", (0.064, 0.13, 0.002), (0, 0, 0.0048), "screen", bevel=0.002)
    scr.parent = o
    scr.data.materials[0].node_tree.nodes["Principled BSDF"].inputs["Emission Color"].default_value = hexcol(PALETTE["screen"])
    scr.data.materials[0].node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 0.6
    frame_at(o, c + palm * 0.002, f.cross(palm), f)
    # screen faces away from the palm
    o.matrix_world = o.matrix_world @ Matrix.Rotation(math.pi, 4, "Y")
    o.location = c
    return o


def aed(loc, facing, open_lid=True):
    """AED case on the floor: green body, white panel with the shock button, carry handle"""
    f = Vector(facing).normalized()
    body = box("aed", (0.30, 0.24, 0.085), (0, 0, 0), "aed", bevel=0.02)
    panel = box("aed-panel", (0.22, 0.15, 0.01), (0.0, 0.0, 0.043), "aed-panel", bevel=0.004)
    btn = cylinder("aed-button", 0.022, 0.012, (0.055, -0.02, 0.05), "aed-button")
    led = cylinder("aed-on", 0.012, 0.01, (-0.06, -0.035, 0.05), "#4CC27A")
    scr = box("aed-screen", (0.075, 0.05, 0.004), (-0.045, 0.03, 0.049), "#2E3440", bevel=0.002)
    handle = box("aed-handle", (0.14, 0.025, 0.03), (0, 0.105, 0.06), "#2F7A50", bevel=0.01)
    bpy.ops.object.text_add(location=(0.055, 0.035, 0.049))
    t = bpy.context.object
    t.data.body = "AED"
    t.data.size = 0.036
    t.data.align_x = "CENTER"
    t.data.extrude = 0.001
    t.data.materials.append(principled("aed-text", "#2E7D55", rough=0.5))
    for c in (panel, btn, led, scr, handle, t):
        c.parent = body
    body.matrix_world = Matrix.Translation(Vector(loc) + Z * 0.0425) @ yaw(-Y, f)
    del open_lid
    return body


def pad(p, idx, name, size=(0.12, 0.085), turn=0.0):
    """electrode pad on the skin at a landmark vertex"""
    co, n = p.at(idx, normal=True)
    o = box(name, (size[0], size[1], 0.004), (0, 0, 0), "pad", bevel=0.012)
    edge = box(name + "-edge", (size[0] * 0.8, size[1] * 0.7, 0.002), (0, 0, 0.0025), "pad-edge", bevel=0.008)
    heart = box(name + "-mark", (size[0] * 0.66, size[1] * 0.54, 0.0022), (0, 0, 0.0028), "pad", bevel=0.006)
    edge.parent = o
    heart.parent = o
    xa = n.cross(Z) if abs(n.dot(Z)) < 0.95 else X
    xa = Matrix.Rotation(math.radians(turn), 3, n) @ xa
    frame_at(o, co + n * 0.006, xa, n.cross(xa))
    return o, co, n


def wire(name, pts, r=0.005):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r
    cu.bevel_resolution = 3
    sp = cu.splines.new("NURBS")
    sp.points.add(len(pts) - 1)
    for i, q in enumerate(pts):
        sp.points[i].co = (*q, 1)
    sp.use_endpoint_u = True
    sp.order_u = 4
    o = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(o)
    cu.materials.append(principled(name, PALETTE["wire"], rough=0.4))
    return o


def table(center, size, height):
    top = box("table", (size[0], size[1], 0.04), (center[0], center[1], height - 0.02), "table", bevel=0.012)
    box("table-body", (size[0] - 0.06, size[1] - 0.06, height - 0.05), (center[0], center[1], (height - 0.05) / 2), "table-leg",
        bevel=0.01)
    pad_ = box("blanket", (size[0] * 0.62, size[1] * 0.78, 0.018), (center[0] - size[0] * 0.08, center[1], height + 0.009),
               "blanket", bevel=0.008, rough=0.95)
    return top, pad_


# ------------------------------------------------------------------ scene, light, camera, style


def reset():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    for c in (bpy.data.meshes, bpy.data.materials, bpy.data.armatures, bpy.data.cameras, bpy.data.lights, bpy.data.curves,
              bpy.data.images):
        for x in list(c):
            c.remove(x)


STYLE = "ink"  # ink: soft EEVEE shading + thin outlines; soft: no outlines; toon: banded, emission-only


def setup_render():
    sc = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = W, H
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    ee = sc.eevee
    opts = {"taa_render_samples": 48, "use_gtao": True, "gtao_distance": 0.25, "use_shadows": True,
            "shadow_ray_count": 3, "shadow_step_count": 12, "use_raytracing": False, "fast_gi_method": "GLOBAL_ILLUMINATION"}
    for k, v in opts.items():
        if hasattr(ee, k):
            try:
                setattr(ee, k, v)
            except TypeError:
                pass
    # plain sRGB with a little extra contrast: clean, saturated colours rather than a filmic render
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None" if STYLE == "toon" else "Medium High Contrast"
    sc.view_settings.exposure = 0.0 if STYLE == "toon" else -0.65
    world = sc.world or bpy.data.worlds.new("w")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = hexcol("#E8EDF4")
    bg.inputs["Strength"].default_value = 0.28
    sc.render.use_freestyle = STYLE in ("ink", "toon")
    if sc.render.use_freestyle:
        sc.render.line_thickness_mode = "RELATIVE"
        vl = sc.view_layers[0]
        vl.use_freestyle = True
        fs = vl.freestyle_settings
        fs.crease_angle = math.radians(120)
        ls = fs.linesets[0] if len(fs.linesets) else fs.linesets.new("lines")
        ls.select_by_visibility = True
        ls.select_silhouette, ls.select_border, ls.select_crease, ls.select_contour = True, False, False, True
        ls.select_external_contour = True
        ls.select_by_collection = True
        ls.collection_negation = "EXCLUSIVE"
        ls.collection = bpy.data.collections.get("no-lines") or bpy.data.collections.new("no-lines")
        st = ls.linestyle
        st.color = (0.16, 0.13, 0.15)
        st.alpha = 0.55
        st.thickness = 2.4
        st.chaining = "PLAIN"


def toonify():
    """shader-to-RGB banding on every BSDF: a lit tone, a soft shade and a deep shade"""
    for m in bpy.data.materials:
        if not m.use_nodes or m.name == "ground":
            continue
        nt = m.node_tree
        bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
        out = next((n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"), None)
        if not bsdf or not out:
            continue
        base = bsdf.inputs["Base Color"]
        src = base.links[0].from_socket if base.links else None
        diff = nt.nodes.new("ShaderNodeBsdfDiffuse")
        diff.inputs["Color"].default_value = (0.8, 0.8, 0.8, 1)
        s2r = nt.nodes.new("ShaderNodeShaderToRGB")
        nt.links.new(diff.outputs["BSDF"], s2r.inputs["Shader"])
        bw = nt.nodes.new("ShaderNodeRGBToBW")
        nt.links.new(s2r.outputs["Color"], bw.inputs["Color"])
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        cr = ramp.color_ramp
        cr.interpolation = "EASE"
        t = (0.08, 0.14, 0.3, 0.4)
        cr.elements[0].position, cr.elements[0].color = t[0], (0.5, 0.5, 0.58, 1)
        cr.elements[1].position, cr.elements[1].color = t[1], (0.78, 0.78, 0.84, 1)
        e = cr.elements.new(t[2])
        e.color = (0.8, 0.8, 0.86, 1)
        e = cr.elements.new(t[3])
        e.color = (1, 1, 1, 1)
        nt.links.new(bw.outputs["Val"], ramp.inputs["Fac"])
        mul = nt.nodes.new("ShaderNodeMix")
        mul.data_type = "RGBA"
        mul.blend_type = "MULTIPLY"
        mul.inputs["Factor"].default_value = 1.0
        if src:
            nt.links.new(src, mul.inputs["A"])
        else:
            mul.inputs["A"].default_value = base.default_value
        nt.links.new(ramp.outputs["Color"], mul.inputs["B"])
        emit = nt.nodes.new("ShaderNodeEmission")
        nt.links.new(mul.outputs["Result"], emit.inputs["Color"])
        alpha = bsdf.inputs["Alpha"]
        if alpha.links:
            tr = nt.nodes.new("ShaderNodeBsdfTransparent")
            mix = nt.nodes.new("ShaderNodeMixShader")
            nt.links.new(alpha.links[0].from_socket, mix.inputs["Fac"])
            nt.links.new(tr.outputs["BSDF"], mix.inputs[1])
            nt.links.new(emit.outputs["Emission"], mix.inputs[2])
            nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])
        else:
            nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])


def light(name, kind, loc, target, energy, color="#FFFFFF", size=1.0, shadow=True):
    ld = bpy.data.lights.new(name, kind)
    ld.energy = energy
    ld.color = hexcol(color)[:3]
    ld.use_shadow = shadow
    if kind == "AREA":
        ld.size = size
    elif kind == "SUN":
        ld.angle = math.radians(size)
    o = bpy.data.objects.new(name, ld)
    bpy.context.collection.objects.link(o)
    o.location = loc
    look_at(o, target)
    return o


def look_at(o, target):
    d = Vector(target) - Vector(o.location)
    o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def lights(center, scale=1.0):
    c = Vector(center)
    k = scale * scale
    # soft key from the upper front left, cool fill from the right, a rim from behind to lift the silhouettes
    # key from the upper right: shadows fall toward the viewer's left, where they read as contact
    light("key", "AREA", c + Vector((2.2, -1.2, 3.8)) * scale, c, 520 * k, "#FFF1E0", 2.0 * scale)
    light("fill", "AREA", c + Vector((3.2, -2.2, 1.4)) * scale, c, 120 * k, "#DDE8FF", 3.5 * scale, shadow=False)
    light("rim", "AREA", c + Vector((0.6, 3.4, 2.4)) * scale, c, 420 * k, "#FFFFFF", 2.0 * scale, shadow=False)


def ground(center, radius=2.2, color="ground"):
    """soft floor patch: opaque in the middle, fading out, so shadows land on something and the app's backdrop shows round it"""
    bpy.ops.mesh.primitive_circle_add(vertices=96, radius=radius, fill_type="TRIFAN", location=(center[0], center[1], 0))
    o = bpy.context.object
    o.name = "ground"
    o.visible_shadow = False  # receives shadows only (no self-shadow acne)
    nl = bpy.data.collections.get("no-lines") or bpy.data.collections.new("no-lines")
    nl.objects.link(o)
    o.scale.y = 0.62
    m = bpy.data.materials.new("ground")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = hexcol(PALETTE[color])
    bsdf.inputs["Roughness"].default_value = 0.95
    tc = nt.nodes.new("ShaderNodeTexCoord")
    grad = nt.nodes.new("ShaderNodeTexGradient")
    grad.gradient_type = "SPHERICAL"
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1 / radius, 1 / radius, 1)
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "EASE"
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
    ramp.color_ramp.elements[1].position = 0.6
    ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    nt.links.new(mp.outputs["Vector"], grad.inputs["Vector"])
    nt.links.new(grad.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Alpha"])
    if hasattr(m, "surface_render_method"):
        m.surface_render_method = "BLENDED"
    o.data.materials.append(m)
    return o


def camera(loc, target, lens=50):
    cd = bpy.data.cameras.new("cam")
    cd.lens = lens
    cd.sensor_width = 36
    o = bpy.data.objects.new("cam", cd)
    bpy.context.collection.objects.link(o)
    o.location = loc
    look_at(o, target)
    bpy.context.scene.camera = o
    update()
    return o


def frame(cam, pts, rect):
    """zoom and shift the camera so the points fill `rect` (x0, x1, y0, y1 as fractions of the frame, y up)"""
    from bpy_extras.object_utils import world_to_camera_view
    sc = bpy.context.scene
    aspect = W / H

    def bounds():
        uv = [world_to_camera_view(sc, cam, p) for p in pts]
        return min(q.x for q in uv), max(q.x for q in uv), min(q.y for q in uv), max(q.y for q in uv)
    for _ in range(8):
        u0, u1, v0, v1 = bounds()
        k = min((rect[1] - rect[0]) / (u1 - u0), (rect[3] - rect[2]) / (v1 - v0))
        cam.data.lens *= k
        cam.data.shift_x *= k
        cam.data.shift_y *= k
        u0, u1, v0, v1 = bounds()
        cam.data.shift_x += (u0 + u1) / 2 - (rect[0] + rect[1]) / 2
        cam.data.shift_y += ((v0 + v1) / 2 - (rect[2] + rect[3]) / 2) / aspect


def mesh_points(objs, step=9):
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in objs:
        if o.type != "MESH" or o.hide_render:
            continue
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        vs = me.vertices
        pts += [ev.matrix_world @ vs[i].co for i in range(0, len(vs), step)]
        ev.to_mesh_clear()
    return pts


def render(path):
    if STYLE == "toon":
        toonify()
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    print("RENDERED", path)


def size(w, h):
    """output size in pixels (framing uses the same aspect)"""
    global W, H
    W, H = w, h
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = W, H


def finish(scene, name, marks):
    """render build/art3d/<scene>/<style>/<name>.png plus its overlay anchor points (viewBox coordinates) as .json"""
    import json
    if os.environ.get("MARKS"):
        for v in marks.values():
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.015, location=v)
            set_material(bpy.context.object, principled("mark", "#FF0000"))
    out = OUT / scene / STYLE / f"{name}.png"
    render(out)
    pts = {k: to_screen(v) for k, v in marks.items()}
    out.with_suffix(".json").write_text(json.dumps(pts))
    print("MARKS", scene, name, json.dumps(pts))


def to_screen(p):
    """world point → (x, y) in the app's 360 × 300 viewBox"""
    from bpy_extras.object_utils import world_to_camera_view
    sc = bpy.context.scene
    q = world_to_camera_view(sc, sc.camera, Vector(p))
    return round(q.x * 360, 1), round((1 - q.y) * 300, 1)

def call_pose(r, f, side, marks):
    """phone on speaker held up in the left hand, the right arm sends someone for the AED"""
    f = Vector(f).normalized()
    shl, shr = r.head("upperarm01.L"), r.head("upperarm01.R")
    k = r.scale()
    r.arm("L", shl + f * 0.26 * k + side * 0.14 * k - Z * 0.2 * k, shl - side * 0.4 - Z * 0.3)
    r.hand("L", f * 0.3 + side * 0.45 + Z * 0.55, f - Z * 0.4)
    r.curl("L", 28, thumb=18)
    ph = phone_in(r, "L")
    aim = (side * 0.75 + f * 0.45 + Z * 0.12).normalized()
    r.arm("R", shr + aim * r.arm_length() * 0.97, shr - Z)
    r.hand("R", aim, -Z + f * 0.2)
    r.curl("R", 85, thumb=40, fingers=(3, 4, 5))
    r.look(shr + aim * 2.0 + Z * 0.2, amount=0.75)
    marks.update(phone=ph.location, rescuer_head=r.head("head") + Z * 0.12 * k, point=r.head("finger2-3.R"))


def kneel_reach(p, f, at, targets, thigh=12.0, reach=0.9, sit=0.0):
    """kneel at a spot and lean just enough for each hand (side → world point) to reach its target"""
    lo, hi = -10.0, 85.0
    side = None
    for _ in range(13):
        lean = (lo + hi) / 2
        side = kneel(p, f, at=at, lean=lean, thigh=thigh, sit=sit)
        far = max((p.head(f"upperarm01.{h}") - t).length for h, t in targets.items())
        lo, hi = (lean, hi) if far > p.arm_length() * reach else (lo, lean)
    return side

def clear_hands(r, f, side, marks):
    """"stand clear": open hands raised in front, palms out"""
    for h, sgn in (("L", -1), ("R", 1)):
        sh = r.head(f"upperarm01.{h}")
        # "hands up": open palms beside the head, elbows down and out
        r.arm(h, sh + f * 0.08 + side * sgn * 0.2 + Z * 0.24, sh + side * sgn * 0.5 - Z * 0.6)
        r.hand(h, Z + side * sgn * 0.15, f)
        r.curl(h, 4, thumb=0)
    marks["hands_up"] = (r.head("wrist.L") + r.head("wrist.R")) / 2
