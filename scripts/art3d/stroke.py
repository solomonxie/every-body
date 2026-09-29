"""Stroke (F.A.S.T.): the person faces us with both arms held out, palms up; with the stroke, the right arm drifts down and
turns in and the right side of the mouth droops. Two pictures per variant: 0 well, 1 stroke. Framed for the round
portrait on the left of the scene (the brain diagram stays vector art on the right).
"""

import kit
from kit import *  # noqa: F401,F403
from mathutils import Vector

SHOTS = {v: ["0", "1"] for v in ("adult", "woman", "senior", "senior_woman", "pregnant", "child", "girl")}
# the portrait disc in the app: centre (92, 189), radius 84, body cut at the disc
RECT = (0.035, 0.475, 0.0, 0.72)


def shoot(shot, close=False):
    variant, step = shot.split("-")
    reset()
    kit.size(1080, 900)
    setup_render()
    p = casualty(variant)
    f = -Y
    side = stand(p, f, at=(0.0, 0.0))
    k = p.scale()
    weak = step == "1"
    for h, sgn in (("L", -1), ("R", 1)):
        drift = weak and h == "R"
        d = f + side * sgn * 0.08 - Z * (0.4 if drift else 0.02) - side * sgn * (0.14 if drift else 0)
        for n in ("upperarm01", "upperarm02", "lowerarm01", "lowerarm02"):
            p.aim(f"{n}.{h}", direction=d + (Z * 0.05 if n.startswith("lower") and not drift else Vector()))
        # palms up; the weak hand turns in and down
        p.hand(h, d, (-side * sgn * 0.8 - Z * 0.4) if drift else Z)
        p.curl(h, 25 if drift else 12, thumb=10)
    if weak:
        droop(p)
        p.look(p.head("head") + f * 2 - Z * 0.1 + side * 0.2, amount=0.4)
    else:
        p.look(p.head("head") + f * 2, amount=0.4)
    marks = {"head": p.tail("head"), "face_r": p.at(p.lm_mouth()) + side * 0.06 * k, "hand_r": p.head("finger3-1.R"),
             "hand_l": p.head("finger3-1.L")}
    portrait(p, "stroke", f"{variant}-{step}{'-close' if close else ''}", marks)


def portrait(p, scene, name, marks, rect=RECT):
    """framed as the round portrait on the left of the scene: head to below the waist, arms out front"""
    k = p.scale()
    top = p.rest["head"][1].z + 0.04 * k
    waist = p.rest["spine05"][0].z - 0.12 * k
    box = [Vector((x, y, z)) for x in (-0.3 * k, 0.3 * k) for y in (-0.55 * k, 0.1 * k) for z in (waist, top)]
    cam = camera(Vector((0.0, -3.4 * k, top - 0.1 * k)), Vector((0.0, 0.0, (top + waist) / 2)), 70)
    frame(cam, box, rect)
    lights(Vector((0, 0, (top + waist) / 2)), 1.0)
    finish(scene, name, marks)


def droop(p):
    """right side of the face slack: mouth corner and lower lip pulled down, eyelid a little lower"""
    side = p.rig.matrix_world.to_3x3() @ X
    for n, deg in (("oris03.R", -18), ("oris04.R", -14), ("oris07.R", -10), ("risorius02.R", -14), ("risorius03.R", -14)):
        if n in p.rig.pose.bones:
            p.rotate(n, side, deg)
    p.rotate("orbicularis03.R", side, 9)
