"""Severe bleeding from a cut on the shin: the casualty sits on the floor (a baby lies on its back), the rescuer kneels
past the feet. Steps: 0 sit down, 1 gloves on, 2 press on a pad, 3 second pad + bandage, 4 tourniquet (baby: more pads)
and a blanket. One camera per variant.
"""

import math

import kit
from kit import *  # noqa: F401,F403
from mathutils import Matrix, Vector

SHOTS = {v: ["0", "1", "2", "3", "4"] for v in ("adult", "woman", "senior", "senior_woman", "pregnant", "child", "girl", "infant")}
BLOOD, GLOVE, WRAP = "#6E0F18", "#8E86D8", "#E7A95E"


def shoot(shot, close=False):
    variant, step = shot.split("-")
    reset()
    kit.size(1080, 900)
    setup_render()
    st = int(step)
    infant = variant == "infant"
    c = casualty(variant)
    r = rescuer()
    k = c.scale()
    f = X
    if infant:
        lie_supine(c, head_dir=-X, arms_out=0.25)
        c.close_eyes(-1.0)  # awake
    else:
        sit_floor(c, f)
    near = "R"  # facing +X (or lying head −X), the right side is toward us (−Y)
    roll_up(c, variant, near)
    wound, n = c.at(shin_front(c, near, 0.6), normal=True)
    band_at = c.at(shin_front(c, near, 0.26))
    knee, ankle = c.head(f"lowerleg01.{near}"), c.head(f"foot.{near}")
    axis = (ankle - knee).normalized()
    shin_r = 0.045 * k
    blood_pool(wound, 0.12 * k if st == 0 else 0.16 * k)
    gash(wound, n, axis, k)
    if st >= 2:
        pad(wound + n * 0.006, n, axis, (0.075 * k, 0.05 * k), "pad1")
    if st >= 3:
        pad(wound + n * 0.014, n, axis, (0.07 * k, 0.048 * k), "pad2")
        sleeve(wound, axis, shin_r + 0.012, 0.09 * k, "#FBF8F2", "bandage", rough=0.95)
    if st == 4 and not infant:
        sleeve(band_at, axis, shin_r + 0.004, 0.03 * k, "#2F3136", "tourniquet")
        rod = cylinder("rod", 0.006, 0.12 * k, band_at + n * (shin_r * 0.9), "#5A5E66")
        rod.rotation_euler = (0, math.pi / 2, 0)
    if st == 4:
        # blanket round the shoulders and back (a baby: over the body)
        top = c.rest["spine03"][0].z
        if infant:
            keep = {i for i, p in enumerate(c.rest_co) if c.rest["root"][0].z - 0.02 < p.z < c.rest["neck01"][0].z}
        else:
            keep = {i for i, p in enumerate(c.rest_co) if p.z > top and p.z < c.rest["neck01"][0].z + 0.02 and (p.y > -0.03 or abs(p.x) > 0.12 * k)}
        c.shell("blanket", WRAP, keep, lift=0.05 if not infant else 0.03, thickness=0.016, rough=0.95)
    if st >= 1:
        r_gloves = r.weighted(("wrist", "finger", "metacarpal"))
        r.shell("gloves", GLOVE, r_gloves, lift=0.002, thickness=0.002, rough=0.4)
    marks = {"wound": wound, "band": band_at, "torso": c.head("spine02"), "head": c.head("head")}
    pose_rescuer(r, c, st, wound, n, axis, band_at, infant, marks)
    # camera from the side of the sitting casualty, a little above
    if infant:
        # close-up on the baby: our arms reach in, the rest of us is cut by the frame
        box = [Vector((x, y, z)) for x in (-0.5, 0.95) for y in (-0.25, 0.25) for z in (0.0, 0.9)]
    else:
        box = [Vector((x, y, z)) for x in (-0.55 * k - 0.15, 1.55 * k + 0.35) for y in (-0.3, 0.3) for z in (0.0, 1.05)]
    center = sum(box, Vector()) / len(box)
    cam = camera(center + Vector((0.2, -4.2, 1.6)), center + Vector((0, 0.1, -0.08)), 70)
    frame(cam, box, (0.02, 0.98, 0.0, 0.72))
    ground(Vector((center.x, 0.1, 0)), 2.6)
    lights(center, 1.0)
    finish("bleeding", f"{variant}-{step}{'-close' if close else ''}", marks)


def sit_floor(p, f):
    """sitting on the floor, legs out in front, leaning back on the hands"""
    p.reset_pose()
    p.rig.matrix_world = yaw(-Y, f)
    update()
    side = f.cross(Z).normalized()
    for s, sgn in (("L", -1), ("R", 1)):
        bend = 0.12 if s == "L" else 0.0
        for n in ("upperleg01", "upperleg02"):
            p.aim(f"{n}.{s}", direction=f + Z * bend + side * sgn * 0.08)
        for n in ("lowerleg01", "lowerleg02"):
            p.aim(f"{n}.{s}", direction=f - Z * bend * 1.2 + side * sgn * 0.05)
        p.aim(f"foot.{s}", direction=Z + f * 0.4 + side * sgn * 0.2)
    for n, k in (("spine05", 0.6), ("spine04", 0.4)):
        p.rotate(n, side, 16 * k)  # leaning back on the hands
    p.rotate("neck01", side, -10)
    p.ground(0.0)
    hip = p.head("root")
    for s, sgn in (("L", -1), ("R", 1)):
        hand = hip - f * 0.26 * p.scale() + side * sgn * 0.2 * p.scale()
        hand.z = 0.02
        p.arm(s, hand, p.head(f"upperarm01.{s}") - f * 0.5 + side * sgn * 0.3)
        p.hand(s, -f + side * sgn * 0.2, -Z)
        p.curl(s, 10, thumb=10)
    p.ground(0.0)
    p.look(p.head("head") + f * 1.5 - Z * 0.6, amount=0.5)


def shin_front(p, s, frac):
    """front of the shin, `frac` of the way from knee to ankle (rest landmark index)"""
    kn, an = p.rest[f"lowerleg01.{s}"][0], p.rest[f"foot.{s}"][0]
    q = kn.lerp(an, frac)
    return p.landmark(lambda v: abs(v.z - q.z) < 0.03 * p.scale() and abs(v.x - q.x) < 0.07 * p.scale(), lambda v: -v.y - abs(v.z - q.z))


def roll_up(p, variant, s):
    """trouser leg pushed up above the knee, so the cut shin is bare"""
    import bmesh
    g = GARMENT[variant]
    o = p.parts.get(g)
    if not o:
        return
    knee = p.rest[f"lowerleg01.{s}"][0]
    sx = -1 if s == "R" else 1
    bottom = set(p for p in range(len(o.data.polygons)) if o.data.polygons[p].material_index == 1)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.faces.ensure_lookup_table()
    gone = [f for f in bm.faces if f.index in bottom and f.calc_center_median().z < knee.z + 0.02 and f.calc_center_median().x * sx > 0]
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    bm.to_mesh(o.data)
    bm.free()
    p.unmask(lambda v: v.z < knee.z + 0.02 and v.x * sx > 0)


def blood_pool(at, radius):
    bpy.ops.mesh.primitive_circle_add(vertices=48, radius=radius, fill_type="NGON", location=(at.x + 0.02, at.y - 0.05, 0.006))
    o = bpy.context.object
    o.name = "pool"
    o.scale = (1.4, 0.8, 1)
    m = principled("pool", BLOOD, rough=0.7)
    m.node_tree.nodes["Principled BSDF"].inputs["Specular IOR Level"].default_value = 0.05  # no grazing glare
    set_material(o, m)


def gash(at, n, axis, k):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1, location=at)
    o = bpy.context.object
    o.name = "cut"
    frame_at(o, at + n * 0.002, axis, n.cross(axis))
    o.scale = (0.03 * k, 0.007 * k, 0.004)
    set_material(o, principled("cut", "#5E0E16", rough=0.3))
    bpy.ops.object.shade_smooth()


def pad(at, n, axis, size, name):
    o = box(name, (size[0], size[1], 0.006), (0, 0, 0), "#FFFFFF", bevel=0.003, rough=0.9)
    frame_at(o, at, axis, n.cross(axis))


def sleeve(at, axis, radius, length, color, name, rough=0.7):
    """a band round the leg (bandage, tourniquet)"""
    bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=radius, depth=length, location=at)
    o = bpy.context.object
    o.name = name
    o.rotation_euler = Vector((0, 0, 1)).rotation_difference(axis).to_euler()
    set_material(o, principled(name, color, rough=rough))
    bpy.ops.object.shade_smooth()
    return o


def pose_rescuer(r, c, st, wound, n, axis, band, infant, marks):
    f = -X  # kneeling past the feet, facing the casualty
    ankle = (c.head("foot.L") + c.head("foot.R")) / 2
    at = (ankle.x + 0.32, -0.08)
    if st == 0:
        side = kneel(r, f, at=at, lean=30 if infant else 8, thigh=6)
        sh = r.head("upperarm01.R")
        r.arm("R", sh + f * 0.34 - Z * 0.12 + side * 0.08, sh - Z * 0.4 + side * 0.3)
        r.hand("R", f * 0.3 + Z, f)
        r.curl("R", 6, thumb=0)
        relax_hand(r, "L", f, side)
        r.look(c.head("head"), amount=0.6)
    elif st == 1:
        side = kneel(r, f, at=at, lean=26 if infant else 6, thigh=4)
        chest = r.head("spine01") + f * 0.3 - Z * 0.12
        r.arm("R", chest + side * 0.04, r.head("upperarm01.R") - Z * 0.4 + side * 0.3)
        r.arm("L", chest - side * 0.02 + Z * 0.03, r.head("upperarm01.L") - Z * 0.4 - side * 0.3)
        r.hand("R", Z + f * 0.4, -side)
        r.hand("L", -side + Z * 0.3, -Z)
        r.curl("R", 10, thumb=5)
        r.curl("L", 30, thumb=20)
        r.look(chest, amount=0.5)
    else:
        if st == 2:
            tg = {"R": wound + n * 0.045, "L": wound + n * 0.07 + axis * 0.01}
        elif st == 3:
            tg = {"R": wound + n * 0.075 + axis * 0.03, "L": wound - Y * 0.06 + Z * 0.02}
        elif infant:
            tg = {"R": wound + n * 0.06, "L": wound + n * 0.08 + axis * 0.01}
        else:
            tg = {"R": band + n * 0.07 - Y * 0.02, "L": band + n * 0.07 + Y * 0.03 + axis * 0.02}
        side = kneel_reach(r, f, at, tg, thigh=12, reach=0.95, sit=0.2)
        for h, t in tg.items():
            sgn = 1 if h == "R" else -1
            r.arm(h, t, r.head(f"upperarm01.{h}") + side * sgn * 0.5 - Z * 0.3)
            r.hand(h, f + Y * 0.3 * sgn - n * 0.3, -n)
            r.curl(h, 12 if st == 2 else 35, thumb=10)
        r.look(wound, amount=0.7)
    marks.update(rescuer_head=r.tail("head"), hands=(r.head("wrist.L") + r.head("wrist.R")) / 2)


def relax_hand(r, h, f, side):
    sgn = 1 if h == "R" else -1
    thigh = r.head(f"upperleg01.{h}").lerp(r.head(f"lowerleg01.{h}"), 0.6) + Z * 0.06
    r.arm(h, thigh, r.head(f"upperarm01.{h}") + side * sgn - f * 0.3)
    r.hand(h, f, -Z)
    r.curl(h, 20, thumb=10)
