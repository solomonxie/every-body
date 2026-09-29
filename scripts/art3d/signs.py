"""Pregnancy warning signs (body map): the pregnant woman standing in profile, facing right. Pictures: 0 hand on the
bump, 2 hand to the forehead (headache), 3 cradling the bump from below. The glows and sign icons stay vector art.
"""

import kit
from kit import *  # noqa: F401,F403
from mathutils import Vector

SHOTS = {"pregnant": ["0", "2", "3"]}
# stage disc in the app: centre x 94, floor at y 290; figure about 250 px tall
RECT = (0.05, 0.44, 0.033, 0.87)


def shoot(shot, close=False):
    variant, step = shot.split("-")
    reset()
    kit.size(1080, 900)
    setup_render()
    p = casualty(variant)
    f = X
    side = stand(p, f, at=(0.0, 0.0), stride=6)  # weight back, front knee soft
    hang_arms(p, f, side, forward=0.05, out=0.08, bend=0.25)
    k = p.scale()
    back = p.at(p.landmark(lambda v: abs(v.x) < 0.02 and abs(v.z - p.rest["spine04"][0].z) < 0.03, lambda v: v.y))
    # far hand on the small of the back
    p.arm("L", back - f * 0.03 + side * -0.06, p.head("upperarm01.L") - f * 0.5 - side * 0.2)
    p.hand("L", Z * 0.3 - side, -f)
    p.curl("L", 15, thumb=10)
    bump = p.at(p.lm_bump_top())
    if step == "2":
        brow = p.at(p.lm_forehead())
        p.arm("R", brow + f * 0.05 + Z * 0.02, p.head("upperarm01.R") + side * 0.3 - Z * 0.2)
        p.hand("R", -f + Z * 0.3, -f)
        p.curl("R", 15, thumb=10)
        p.close_eyes(0.5)
        p.look(p.head("head") + f - Z * 0.3, amount=0.5)
    elif step == "3":
        low = p.at(p.lm_bump_top()) - Z * 0.12 * k
        p.arm("R", low + f * 0.03 - Z * 0.03, p.head("upperarm01.R") + side * 0.4 - f * 0.2)
        p.hand("R", -f * 0.3 + Z, -f * 0.6 + Z * 0.8)
        p.curl("R", 20, thumb=10)
        p.look(bump, amount=0.4)
    else:
        top = bump + Z * 0.1 * k
        p.arm("R", top + f * 0.03, p.head("upperarm01.R") + side * 0.4 - Z * 0.2)
        p.hand("R", -Z + f * 0.2, -f)
        p.curl("R", 15, thumb=10)
        p.look(p.head("head") + f - Z * 0.1, amount=0.4)
    ankle = p.head("foot.R")
    marks = {"head": p.head("head").lerp(p.tail("head"), 0.35), "eye": p.head("eye.R"), "bump": bump,
             "crotch": (p.head("upperleg01.L") + p.head("upperleg01.R")) / 2 - Z * 0.05, "ribs": p.head("spine02") + f * 0.08,
             "ankle": ankle, "hand": p.head("finger3-1.L")}
    top = p.rest["head"][1].z + 0.03
    box = [Vector((x, y, z)) for x in (-0.3, 0.42) for y in (-0.2, 0.2) for z in (0.0, top)]
    cam = camera(Vector((0.05, -4.6, 1.0)), Vector((0.05, 0, 0.85)), 70)
    frame(cam, box, RECT)
    ground(Vector((0.05, 0.1, 0)), 1.2)
    lights(Vector((0, 0, 0.9)), 1.0)
    finish("signs", f"{variant}-{step}{'-close' if close else ''}", marks)
