"""Sleeping position in pregnancy, seen from above: on her back, or curled on her left side (with pillows between the
knees and under the bump). Framed for the bed card at the top left of the scene (the diagrams stay vector art).
"""

import math

import kit
from kit import *  # noqa: F401,F403
from mathutils import Matrix, Vector

SHOTS = {"pregnant": ["back", "side", "pillows"]}
# bed card in the app: x 6…208, y 8…112
RECT = (0.017, 0.578, 0.627, 0.973)
BED = (2.05, 1.05, 0.3)  # length, width, mattress top


def shoot(shot, close=False):
    variant, step = shot.split("-")
    reset()
    kit.size(1080, 900)
    setup_render()
    p = casualty(variant)
    L, Wd, top = BED
    box("mattress", (L, Wd, top), (0, 0, top / 2), "#D9E3EE", bevel=0.05, rough=0.95)
    box("pillow", (0.4, 0.7, 0.1), (-L / 2 + 0.25, 0, top + 0.05), "#FFFFFF", bevel=0.05, rough=0.95)
    lie_supine(p, head_dir=-X, z=top, arms_out=0.08)
    hd = p.head("head")
    p.rig.location += Vector((-L / 2 + 0.3 - hd.x, -hd.y, 0))
    update()
    p.close_eyes(-1.0)
    marks = {}
    if step == "back":
        bump = p.at(p.lm_bump_top())
        for h in "LR":
            p.arm(h, bump + (Y * 0.09 if h == "L" else -Y * 0.09) + Z * 0.02, p.head(f"upperarm01.{h}") + Z * 0.3)
            p.hand(h, X, -Z)
            p.curl(h, 12, thumb=8)
        p.look(p.head("head") + Z * 2 + X * 0.3, amount=0.3)
    else:
        # onto her left side: the left side goes down, her front turns to face +Y
        pivot = p.head("spine03") * 1.0
        pivot.z = top
        p.rig.matrix_world = Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(-90), 4, "X") @ Matrix.Translation(-pivot) @ p.rig.matrix_world
        update()
        for h, fwd in (("R", 0.95), ("L", 0.7)):
            for b in ("upperleg01", "upperleg02"):
                p.aim(f"{b}.{h}", direction=X * 0.5 + Y * fwd + Z * (0.08 if h == "R" else 0))
            for b in ("lowerleg01", "lowerleg02"):
                p.aim(f"{b}.{h}", direction=X * 0.95 - Y * 0.25)
            p.aim(f"foot.{h}", direction=X * 0.6 - Y * 0.2 - Z * 0.4)
        bump = p.at(p.lm_bump_top())
        p.arm("R", bump + Z * 0.06 - X * 0.05, p.head("upperarm01.R") + Z * 0.4)
        p.hand("R", Y + X * 0.3, -Z)
        p.curl("R", 15, thumb=8)
        for b in ("upperarm01", "upperarm02"):
            p.aim(f"{b}.L", direction=Y * 0.7 - X * 0.3)
        for b in ("lowerarm01", "lowerarm02"):
            p.aim(f"{b}.L", direction=-X * 0.85 + Y * 0.15)
        p.hand("L", -X + Y * 0.3, -Z)
        p.curl("L", 25, thumb=10)
        p.ground(top)
        if step == "pillows":
            kn = (p.head("lowerleg01.L") + p.head("lowerleg01.R")) / 2
            box("knee-pillow", (0.35, 0.25, 0.12), (kn.x - 0.08, kn.y, top + 0.11), "#D3DDEA", bevel=0.04, rough=0.95)
            box("bump-pillow", (0.3, 0.2, 0.12), (bump.x + 0.02, bump.y + 0.12, top + 0.06), "#D3DDEA", bevel=0.04, rough=0.95)
            marks.update(knee_pillow=kn, bump_pillow=bump + Y * 0.12)
    # blanket over the lower legs
    box("blanket", (0.62, Wd + 0.02, 0.05), (L / 2 - 0.3, 0, top + (0.32 if step != "back" else 0.26)), "#9FB6D6", bevel=0.02, rough=0.95)
    marks.update(head=p.head("head"), bump=p.at(p.lm_bump_top()))
    bed = [Vector((x, y, top)) for x in (-L / 2, L / 2) for y in (-Wd / 2, Wd / 2)]
    cam = camera(Vector((0, -0.4, 9.0)), Vector((0, 0, top)), 200)
    frame(cam, bed, RECT)
    lights(Vector((0, 0, top)), 1.0)
    finish("sleep", f"{variant}-{step}{'-close' if close else ''}", marks)
