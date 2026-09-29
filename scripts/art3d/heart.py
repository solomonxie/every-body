"""Heart attack: the person faces us; in pain, a fist pressed to the middle of the chest, face tight. Two pictures per
variant (0 well, 1 pain), framed like the stroke portrait (the heart diagram stays vector art on the right).
"""

import kit
from kit import *  # noqa: F401,F403
from mathutils import Vector
from stroke import portrait

SHOTS = {v: ["0", "1"] for v in ("adult", "woman", "senior", "senior_woman", "pregnant")}
# portrait disc in the app: centre (88, 189)
RECT = (0.03, 0.46, 0.0, 0.72)


def shoot(shot, close=False):
    variant, step = shot.split("-")
    reset()
    kit.size(1080, 900)
    setup_render()
    p = casualty(variant)
    f = -Y
    side = stand(p, f, at=(0.0, 0.0))
    hang_arms(p, f, side, forward=0.08, out=0.1, bend=0.2)
    k = p.scale()
    marks = {"head": p.tail("head")}
    if step == "1":
        chest = p.at(p.lm_sternum(drop=-0.03 * k))
        p.arm("R", chest - Y * 0.07 * k - side * 0.02, p.head("upperarm01.R") + side * 0.4 - Z * 0.3)
        p.hand("R", -side + Z * 0.2, Y)
        p.curl("R", 95, thumb=60)
        p.arm("L", p.head("upperleg01.L") - Y * 0.12 + Z * 0.08 - side * 0.02, p.head("upperarm01.L") - side * 0.4)
        p.hand("L", -Z - Y * 0.2, side)
        p.curl("L", 40, thumb=20)
        p.open_mouth(5)
        p.close_eyes(0.45)
        p.look(p.head("head") + f * 2 - Z * 0.35, amount=0.5)
        marks.update(chest=chest, fist=p.head("wrist.R"))
    else:
        p.look(p.head("head") + f * 2, amount=0.4)
    marks.update(jaw=p.at(p.lm_chin()), elbow_l=p.head("lowerarm01.L"), shoulder_l=p.head("upperarm01.L"))
    portrait(p, "heart", f"{variant}-{step}{'-close' if close else ''}", marks, RECT)
