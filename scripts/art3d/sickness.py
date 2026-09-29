"""Morning sickness: early pregnancy (no bump yet), the woman faces us behind a table. Pictures: 0 queasy (hand over the
mouth, other hand on the tummy), 1 better (a cracker in one hand, ginger tea in the other; crackers on a plate).
"""

import math

import kit
from kit import *  # noqa: F401,F403
from mathutils import Vector

SHOTS = {"woman": ["0", "1"]}
# the round backdrop in the app: centre (84, 150), radius 78; table top at y 232
RECT = (0.03, 0.44, 0.227, 0.82)
TABLE_Z = 0.8


def shoot(shot, close=False):
    variant, step = shot.split("-")
    reset()
    kit.size(1080, 900)
    setup_render()
    p = casualty(variant)
    f = -Y
    side = stand(p, f, at=(0.0, 0.1))
    hang_arms(p, f, side, forward=0.1, out=0.1, bend=0.3)
    k = p.scale()
    marks = {"head": p.head("head").lerp(p.tail("head"), 0.4)}
    if step == "0":
        mouth = p.at(p.lm_mouth())
        p.arm("R", mouth + f * 0.05 - Z * 0.03 + side * 0.01, p.head("upperarm01.R") + side * 0.3 - Z * 0.3 + f * 0.2)
        p.hand("R", Z - side * 0.8, -f)
        p.curl("R", 20, thumb=15)
        belly = p.at(p.lm_navel(up=0.03 * k))
        p.arm("L", belly + f * 0.05, p.head("upperarm01.L") - side * 0.4 - Z * 0.2)
        p.hand("L", side, -f * 0.9 + Z * 0.1)
        p.curl("L", 12, thumb=8)
        p.close_eyes(0.35)
        p.look(p.head("head") + f * 2 - Z * 0.4, amount=0.4)
    else:
        sh_r, sh_l = p.head("upperarm01.R"), p.head("upperarm01.L")
        p.arm("R", sh_r + f * 0.26 - Z * 0.24 + side * 0.02, sh_r + side * 0.3 - Z * 0.4)
        p.hand("R", Z + f * 0.2, -side)
        p.curl("R", 30, thumb=20)
        cracker = box("cracker", (0.05, 0.004, 0.04), (0, 0, 0), "#EAC98A", bevel=0.002)
        cracker.location = p.head("finger2-2.R") + Z * 0.02 + f * 0.01
        cracker.rotation_euler = (0, math.radians(-20), 0)
        p.arm("L", sh_l + f * 0.28 - Z * 0.3 - side * 0.02, sh_l - side * 0.3 - Z * 0.4)
        p.hand("L", side + Z * 0.2, side * 0.2 + Z)
        p.curl("L", 55, thumb=30)
        mug = cylinder("mug", 0.04, 0.09, p.palm_point("L") + Z * 0.05 + f * 0.02, "#FFFFFF")
        tea = cylinder("tea", 0.036, 0.004, mug.location + Z * 0.043, "#D9B46A")
        del tea
        p.look(p.head("head") + f * 2, amount=0.4)
    # table in front, with a plate of crackers
    box("table", (1.1, 0.4, 0.04), (0.0, -0.2, TABLE_Z - 0.02), "table", bevel=0.01)
    box("table-front", (1.08, 0.36, TABLE_Z - 0.04), (0.0, -0.2, (TABLE_Z - 0.04) / 2), "#EFE6DA", bevel=0.01)
    plate = cylinder("plate", 0.1, 0.012, (-0.28, -0.25, TABLE_Z + 0.006), "#FFFFFF")
    del plate
    for i, (dx, dy) in enumerate(((-0.3, -0.26), (-0.25, -0.22))):
        c = box(f"cracker{i}", (0.06, 0.045, 0.006), (dx, dy, TABLE_Z + 0.016 + i * 0.006), "#EAC98A", bevel=0.002)
        c.rotation_euler = (0, 0, math.radians(20 * i))
    top_z = p.rest["head"][1].z + 0.03
    box_ = [Vector((x, y, z)) for x in (-0.36 * k, 0.36 * k) for y in (-0.4, 0.1) for z in (TABLE_Z, top_z)]
    cam = camera(Vector((0.0, -4.0, 1.35)), Vector((0.0, 0.0, (TABLE_Z + top_z) / 2)), 70)
    frame(cam, box_, RECT)
    lights(Vector((0, 0, 1.2)), 1.0)
    finish("sickness", f"{variant}-{step}{'-close' if close else ''}", marks)
