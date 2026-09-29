"""Choking: back blows and thrusts (adult, pregnant: chest thrusts, child: rescuer kneels, infant: on the forearm).
Blows and thrusts have a ready (a) and a contact (b) frame. One camera per variant.
"""

import kit
from kit import *  # noqa: F401,F403
from mathutils import Vector

SHOTS = {v: ["0", "1a", "1b", "2a", "2b", "3"] for v in ("adult", "woman", "senior", "senior_woman", "pregnant", "child", "girl", "infant")}
# figures fill the left two thirds; the right third and the top strip hold the captions and cards
RECT = (0.02, 0.68, 0.0, 0.88)


def shoot(shot, close=False):
    variant, step = shot.split("-")
    reset()
    kit.size(1080, 900)
    setup_render()
    num, hit = step[0], step[1:] == "b"
    c = casualty(variant)
    r = rescuer()
    marks = {}
    if variant == "infant":
        box = infant(c, r, num, hit, marks)
    else:
        box = standing(c, r, variant, num, hit, marks)
        if variant == "girl" and num == "1":
            c.hang_hair()
    center = sum(box, Vector()) / len(box)
    cam = camera(center + Vector((1.0, -3.8, 0.9)), center + Vector((0.0, 0.15, -0.05)), 60)
    frame(cam, box, RECT)
    ground(Vector((center.x, 0.1, 0)), 2.4)
    lights(center, 1.0)
    if close:
        cam.data.lens *= 2.2
    finish("choking", f"{variant}-{step}{'-close' if close else ''}", marks)


def standing(c, r, variant, num, hit, marks):
    """casualty stands facing +X (their right side toward us); the rescuer is behind them"""
    child, chest = variant in KIDS, variant == "pregnant"
    f = X
    k = c.scale()
    if num == "0":
        cs = stand(c, f, lean=6, at=(0.1, 0.0))
        throat = c.at(c.lm_throat())
        for h, sgn in (("L", -1), ("R", 1)):
            c.arm(h, throat + cs * sgn * 0.035 * k + f * 0.03 - Z * 0.02, c.head(f"upperarm01.{h}") + cs * sgn * 0.3 + f * 0.2 - Z * 0.4)
            c.hand(h, Z * 0.4 - f + (-cs * sgn) * 0.6, -f + (-cs * sgn) * 0.3)
            c.curl(h, 30, thumb=15)
        c.open_mouth(9)
        c.look(c.head("head") + f * 1.0 - Z * 0.1, amount=0.3)
        back = c.at(c.lm_blades())
        _place_rescuer(r, child, f, (back.x - 0.42 * k, 0.22), lean=6)
        hang_arms(r, (f - Y * 0.4).normalized(), (f - Y * 0.4).normalized().cross(Z), forward=0.15)
        _fix_right_hand(r, back + Y * 0.06 - f * 0.03 + Z * 0.02, f)
        r.look(c.head("head") + Z * 0.05, amount=0.7)
        marks.update(throat=throat, casualty_head=c.head("head"), rescuer_head=r.tail("head"))
    elif num == "1":
        # bent well forward, head below the chest; rescuer beside and behind, one hand under the chest
        cs = stand(c, f, lean=78, at=(0.1, 0.0), knees=6, wide=0.07)
        hang_arms(c, f, cs, forward=0.25, out=0.1, bend=0.1)
        c.open_mouth(8)
        blades, n = c.at(c.lm_blades(), normal=True)
        chest_i = c.lm_sternum(drop=-0.03 * k)
        chest = c.at(chest_i)
        fr = (f * 0.45 - Y).normalized()
        _place_rescuer(r, child, fr, (blades.x - 0.2 * k, 0.5 * k), lean=26)
        r.arm("L", chest - Z * 0.05 + Y * 0.02, r.head("upperarm01.L") + f * 0.3 - Z * 0.5)
        r.hand("L", -Y + f * 0.3, Z)
        r.curl("L", 15, thumb=5)
        gap = 0.03 if hit else 0.2
        wrist = blades + n * (gap + 0.035) - f * 0.05 * k
        r.arm("R", wrist, r.head("upperarm01.R") + Y * 0.4 - Z * 0.3)
        r.hand("R", f + Z * 0.1, -n)
        r.curl("R", 8, thumb=5)
        r.look(blades, amount=0.6)
        marks.update(blades=blades, support=chest - Z * 0.05, casualty_head=c.head("head"), strike=wrist)
    elif num == "2":
        # rescuer right behind, arms round the waist: fist above the navel (pregnant: on the breastbone, arms under the armpits)
        cs = stand(c, f, lean=14, at=(0.1, 0.0), wide=0.07)
        hang_arms(c, f, cs, forward=0.55, out=0.55, bend=0.35)
        c.open_mouth(8)
        target_i = c.lm_sternum(drop=0.04 * k) if chest else c.lm_navel(up=0.045 * k)
        spot, n = c.at(target_i, normal=True)
        if hit:
            c.warp(spot, -f * 0.03 + (Z * 0.02 if not chest else Vector()), 0.12 * k, garments=[GARMENT[variant]])
        back = c.at(c.lm_blades())
        _place_rescuer(r, child, f, (back.x - 0.17 * k, 0.0), lean=14, stride=16)
        push = (-f * 0.03 + Z * (0 if chest else 0.025)) if hit else Vector()
        fist = spot + n * 0.035 + push
        rs = r.head("upperarm01.R").cross(Z)
        for h, sgn in (("R", 1), ("L", -1)):
            side = r.rig.matrix_world.to_3x3() @ Vector((-1 if h == "R" else 1, 0, 0))
            pole = r.head(f"upperarm01.{h}") + side * 0.6 - Z * (0.5 if chest else 0.25)
            r.arm(h, fist + (n * 0.035 if h == "L" else Vector()) - Y * 0.02 * sgn, pole)
            r.hand(h, (-n - Y * 0.6) if h == "L" else Y, -Z if h == "R" else -n)
            r.curl(h, 95 if h == "R" else 45, thumb=60 if h == "R" else 30)
        del rs
        r.look(c.head("head") + f * 0.2, amount=0.5)
        marks.update(fist=spot, casualty_head=c.head("head"))
    else:
        # coughing it up; rescuer's hand on the back
        cs = stand(c, f, lean=24, at=(0.1, 0.0), knees=4)
        hang_arms(c, f, cs, forward=0.2)
        mouth = c.at(c.lm_mouth())
        c.arm("R", mouth + f * 0.05 - Z * 0.07, c.head("upperarm01.R") - Z * 0.4 + cs * 0.3)
        c.hand("R", Z - f * 0.3, -f)
        c.curl("R", 80, thumb=40)
        c.open_mouth(12)
        back = c.at(c.lm_blades())
        _place_rescuer(r, child, (f - Y * 0.3).normalized(), (back.x - 0.4 * k, 0.24), lean=8)
        hang_arms(r, f, r.rig.matrix_world.to_3x3() @ Vector((-1, 0, 0)), forward=0.15)
        _fix_right_hand(r, back + Y * 0.07 + Z * 0.03 - f * 0.02, f)
        r.look(c.head("head"), amount=0.6)
        marks.update(mouth=mouth, casualty_head=c.head("head"), rescuer_head=r.tail("head"))
    marks["floor"] = Vector((0.9, -0.1, 0))
    top = 1.42 if child else 1.86
    return [Vector((x, y, z)) for x in (-0.8, 0.72) for y in (-0.25, 0.45) for z in (0.0, top)]


def _place_rescuer(r, child, f, at, lean=0.0, stride=0.0):
    """child: kneel upright to the child's height; otherwise stand"""
    if child:
        kneel(r, f, at=at, lean=lean, thigh=0)
    else:
        stand(r, f, lean=lean, at=at, stride=stride)


def _fix_right_hand(r, target, f):
    r.arm("R", target, r.head("upperarm01.R") - Z * 0.5 - Y * 0.1)
    r.hand("R", Z * 0.6 + Y * 0.3, f)
    r.curl("R", 10, thumb=5)


def infant(c, r, num, hit, marks):
    """rescuer sits facing +X, baby along the left forearm resting on the left thigh, head low"""
    f = X
    side = sit(r, f, at=(0.0, 0.0), lean=22)
    hip = (r.head("upperleg01.L") + r.head("upperleg01.R")) / 2
    seat = hip.z - 0.08
    chair(Vector((hip.x - 0.05, hip.y, 0)), seat, f)
    knee = r.head("lowerleg01.L")
    thigh = r.head("upperleg01.L")
    prone = num == "1"
    # the forearm runs along the thigh toward the knee, tipped down; the baby's head is past the hand
    down = (f - Z * 0.35).normalized()
    arm_top = thigh.lerp(knee, 0.35) + Z * 0.12
    palm = thigh.lerp(knee, 0.95) + Z * 0.07
    # baby: body along `down`, face down (1) or face up (0, 2, 3)
    head_dir = down
    face = -Z if prone else Z
    rot = (-Y).rotation_difference(face).to_matrix().to_4x4()
    c.rig.matrix_world = rot
    update()
    up_now = (c.head("head") - c.head("root")).normalized()
    c.rig.matrix_world = up_now.rotation_difference(head_dir).to_matrix().to_4x4() @ c.rig.matrix_world
    update()
    kc = c.scale()
    for h, sgn in (("L", 1), ("R", -1)):
        c.aim(f"upperarm01.{h}", direction=-Z + c.rig.matrix_world.to_3x3() @ Vector((sgn * 0.5, 0, 0)))
        c.aim(f"upperarm02.{h}", direction=-Z + c.rig.matrix_world.to_3x3() @ Vector((sgn * 0.5, 0, 0)))
        c.curl(h, 30, thumb=15)
    for h in "LR":
        for n in ("upperleg01", "upperleg02"):
            c.aim(f"{n}.{h}", direction=-head_dir - Z * 0.5)
    chest = c.head("spine02")
    c.rig.location += (palm - head_dir * 0.1 * kc + Z * 0.06) - chest
    update()
    c.open_mouth(10)
    r.arm("L", palm, arm_top + Y * 0.3 - Z * 0.2)
    r.hand("L", head_dir + Y * 0.1, Z)
    r.curl("L", 30, thumb=20)
    k = r.scale()
    del k
    if prone:
        blades, n = c.at(c.lm_blades(), normal=True)
        gap = 0.02 if hit else 0.14
        wrist = blades + n * (gap + 0.03) - head_dir * 0.06
        r.arm("R", wrist, r.head("upperarm01.R") - Y * 0.4 - Z * 0.3)
        r.hand("R", head_dir, -n)
        r.curl("R", 8, thumb=5)
        marks.update(blades=blades, strike=wrist)
    elif num == "2":
        spot, n = c.at(c.lm_sternum(drop=0.01 * kc), normal=True)
        if hit:
            c.warp(spot, -n * 0.025, 0.08, garments=[GARMENT["infant"]])
        wrist = spot + n * (0.03 if hit else 0.1) - head_dir * 0.045
        r.arm("R", wrist, r.head("upperarm01.R") - Y * 0.4 - Z * 0.3)
        r.hand("R", head_dir, -n)
        r.curl("R", -10, thumb=0)
        marks.update(chest=spot, strike=wrist)
    else:
        belly = c.at(c.lm_navel())
        r.arm("R", belly + Z * 0.05, r.head("upperarm01.R") - Y * 0.4 - Z * 0.3)
        r.hand("R", head_dir - Y * 0.3, -Z)
        r.curl("R", 15, thumb=10)
    r.look(c.head("head"), amount=0.7)
    marks.update(mouth=c.at(c.lm_mouth()), baby_head=c.head("head"), jaw=palm, rescuer_head=r.tail("head"))
    del side
    return [Vector((x, y, z)) for x in (-0.45, 0.85) for y in (-0.3, 0.35) for z in (0.0, 1.4)]


def chair(at, seat, f):
    """a plain wooden chair under the sitter, back behind them"""
    w = 0.44
    box("seat", (w, w, 0.04), (at.x, at.y, seat - 0.02), "#B98E62", bevel=0.01)
    for dx in (-1, 1):
        for dy in (-1, 1):
            box("leg", (0.04, 0.04, seat - 0.04), (at.x + dx * (w / 2 - 0.03), at.y + dy * (w / 2 - 0.03), (seat - 0.04) / 2), "#9E7650", bevel=0.005)
    back_x = at.x - f.x * (w / 2 - 0.02)
    for dy in (-1, 1):
        box("post", (0.04, 0.04, 0.46), (back_x, at.y + dy * (w / 2 - 0.03), seat + 0.23), "#9E7650", bevel=0.005)
    box("rail", (0.04, w, 0.14), (back_x, at.y, seat + 0.4), "#B98E62", bevel=0.01)
