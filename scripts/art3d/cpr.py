"""CPR: rescuer and casualty per step (adult, pregnant, child, infant); compressions have up / half / down frames.
One camera per variant, so the casualty stays put from step to step.
"""

import math

import kit
from kit import *  # noqa: F401,F403
from mathutils import Vector

def push_pose(p, hands_at, facing, depth=0.0, one_hand=False, free_hand=None, thigh=20.0, standing=False, table=0.0):
    """kneel (or stand) with straight vertical arms, shoulders over the hands, heel of the hand(s) on `hands_at`"""
    f = Vector(facing).normalized()
    target = Vector(hands_at) - Z * depth
    wrist_up = 0.035 * p.scale()
    L = p.arm_length() * 0.99
    wrist = target + Z * wrist_up - f * 0.012
    sides = ("R",) if one_hand else ("R", "L")
    lo, hi = -20.0, 88.0
    shift = Vector()
    for _ in range(16):
        lean = (lo + hi) / 2
        side = stand(p, f, lean=lean, z=table) if standing else kneel(p, f, lean=lean, thigh=thigh)
        sh = sum((p.head(f"upperarm01.{s}") for s in sides), Vector()) / len(sides)
        if one_hand:
            sh = sh - side * 0.0
        shift = Vector((wrist.x - sh.x, wrist.y - sh.y, 0))
        d = max((p.head(f"upperarm01.{s}") + shift - wrist).length for s in sides)
        if d > L:
            lo = lean
        else:
            hi = lean
    p.rig.location += shift
    update()
    if one_hand:
        p.arm("R", wrist, p.head("upperarm01.R") - f * 0.3 + side)
        p.hand("R", f, -Z)
        p.curl("R", 10, thumb=5)
        if free_hand is not None:
            p.arm("L", free_hand + Z * 0.03, p.head("upperarm01.L") - f * 0.2 - side + Z * 0.2)
            p.hand("L", (free_hand - p.head("upperarm01.L")).normalized() * 0.3 + side * -1, -Z)
            p.curl("L", 15, thumb=10)
        return lean
    for s, sgn in (("R", 1), ("L", -1)):
        p.arm(s, wrist + (Z * 0.024 * p.scale() if s == "L" else Vector()) - (f * 0.004 if s == "L" else Vector()),
              p.head(f"upperarm01.{s}") - f * 0.3 + side * sgn)
    # lower (right) hand flat with the heel on the breastbone; the left on top, fingers laced round it
    p.hand("R", f + side * 0.35, -Z)
    p.hand("L", f - side * 0.35, -Z)
    p.curl("R", 6, thumb=5)
    p.curl("L", 48, thumb=25)
    return lean

# ------------------------------------------------------------------ shots

# step → frame names; compressions have up / half / down frames
SHOTS = {
    "adult": ["0", "1", "2", "3a", "3b", "3c", "4", "4i", "5"],
    "senior": ["0", "1", "2", "3a", "3b", "3c", "4", "4i", "5"],
    "woman": ["0", "1", "2", "3a", "3b", "3c", "4", "4i", "5"],
    "senior_woman": ["0", "1", "2", "3a", "3b", "3c", "4", "4i", "5"],
    "pregnant": ["0", "1", "2", "6", "3a", "3b", "3c", "4", "4i", "5"],
    "child": ["0", "1", "2", "3a", "3b", "3c", "4", "4i", "5"],
    "girl": ["0", "1", "2", "3a", "3b", "3c", "4", "4i", "5"],
    "infant": ["0", "1", "2", "3a", "3b", "3c", "4", "5"],
}
TABLE = (0.95, 0.62)
INSET = (450, 360)
DEPTH = {"adult": 0.055, "woman": 0.055, "senior": 0.055, "senior_woman": 0.055, "pregnant": 0.055, "child": 0.045, "girl": 0.045, "infant": 0.035}
PRESS = {"a": 0.0, "b": 0.5, "c": 1.0}


class Stage:
    """the casualty lying still, plus landmarks; a fresh one per shot"""

    def __init__(self, variant):
        self.variant = variant
        self.infant = variant == "infant"
        self.c = casualty(variant)
        self.top = 0.0
        if self.infant:
            self.top = 0.9
            table((0.0, 0.0), TABLE, self.top)
            self.top += 0.018
        self.head_dir = -X if self.infant else X
        self.down = lie_supine(self.c, head_dir=self.head_dir, z=self.top, arms_out=0.2 if self.infant else 0.12)
        c = self.c
        mid = (c.head("head") + (c.head("foot.L") + c.head("foot.R")) / 2) / 2
        if self.infant:
            mid.x = (c.head("foot.L").x + c.head("foot.R").x) / 2 - (TABLE[0] / 2 - 0.1)
        c.rig.location += Vector((-mid.x, -mid.y, 0))
        update()
        self.i_sternum = c.lm_sternum(drop=0.012 * c.scale() if self.infant else 0.0)
        self.i_mouth = c.lm_mouth()
        self.i_forehead = c.lm_forehead()
        self.i_chin = c.lm_chin()
        self.i_nose = c.lm_nose()
        self.sternum = c.at(self.i_sternum)
        self.rest_points = mesh_points(c.objects)

    def head_tilt(self, deg):
        side = Y  # lying along X; tilting the chin up turns about the body's left-right axis
        self.c.rotate("neck02", side, deg * 0.5)
        self.c.rotate("head", side, deg * 0.5)

    def points(self):
        """the casualty as first laid down (framing ignores later changes, so every step shares one camera)"""
        return self.rest_points


def shoot(shot, close=False):
    variant, step = shot.split("-")
    reset()
    kit.size(1080, 900)
    setup_render()
    st = Stage(variant)
    c = st.c
    s = st.sternum
    num = step[0]
    press = PRESS.get(step[1:], 0.0) if num == "3" else 0.0
    depth = DEPTH[variant] * press
    helper_on = variant == "pregnant" and num in "6345"
    f = -Y  # rescuer faces the camera side
    r = rescuer()
    marks = {"sternum": s}
    if st.infant:
        infant_pose(st, r, num, depth, marks)
    else:
        floor_pose(st, r, num, depth, marks, close_up=step.endswith("i"))
    if helper_on:
        lud(st, marks)
    if depth:
        c.warp(s, -Z * depth, 0.16 * c.scale(), garments=[GARMENT[variant]])
    # camera: fixed per variant, framed on the casualty plus a kneeling / standing rescuer's height
    if st.infant:
        center = Vector((0.0, 0.0, st.top + 0.15))
        cam = camera(center + Vector((0.5, -2.6, 2.0)), center + Vector((0.0, 0.1, 0.0)), 60)
        pts = [Vector((x, y, z)) for x in (-0.86, 0.8) for y in (-0.3, 0.3) for z in (st.top - 0.1,)] + \
            [Vector((x, 0.0, st.top + 0.88)) for x in (-0.86, 0.8)]
        rect = (0.02, 0.98, 0.0, 0.8)
    else:
        center = Vector((s.x - 0.3, 0.0, 0.3))
        # from the feet side at 3/4, so the compressor's straight arms read; with a helper, a little more from the front
        view = Vector((-2.6, -5.8, 5.0)) if variant == "pregnant" else Vector((-4.2, -4.8, 5.0))
        cam = camera(center + view, center + Vector((0.05, 0.12, 0.0)), 80)
        knee_x = c.head("lowerleg01.L").x
        pts = [q for q in st.points() if q.x > knee_x] + [Vector((s.x + dx, 0.42, 1.08)) for dx in (-0.35, 0.35)] + \
            [Vector((s.x + 0.62 + dx, -0.45 + dy, 0)) for dx in (-0.15, 0.15) for dy in (-0.15, 0.15)]
        if variant == "pregnant":
            pts.append(Vector((c.head("upperleg01.R").x - 0.75, 0.75, 0.9)))  # room for the helper
        rect = (0.02, 0.98, 0.03, 0.8)
    frame(cam, pts, rect)
    ground(Vector((s.x - 0.3, 0.1, 0)), 2.6)
    lights(center, 1.0)
    if close:
        cam.location = s + Vector((0.9, -1.1, 0.7))
        look_at(cam, s + Vector((0, 0.1, 0.2)))
        cam.data.lens, cam.data.shift_x, cam.data.shift_y = 40, 0, 0
    if step.endswith("i"):
        # close-up for the breaths card: side view of the head, the seal and the hands
        mouth = c.at(st.i_mouth)
        kit.size(*INSET)
        cam.data.shift_x = cam.data.shift_y = 0
        cam.data.lens = 50
        if st.infant:
            cam.location = mouth + Vector((0.1, -0.9, 0.08))
        else:
            cam.location = mouth - st.head_dir * 0.15 - Y * 0.85 + Z * 0.12
        look_at(cam, mouth)
        update()
        near = [q for q in mesh_points(c.objects + r.objects, step=3) if (q - mouth).length < 0.16 * c.scale() + 0.06]
        frame(cam, near, (0.04, 0.96, 0.04, 0.96))
    del f
    finish("cpr", f"{variant}-{step}{'-close' if close else ''}", marks)


def floor_pose(st, r, num, depth, marks, close_up=False):
    c, s = st.c, st.sternum
    f = -Y
    child = st.variant in KIDS
    if num in "0":
        # kneeling beside him at shoulder level, a hand on each shoulder, head up to watch his face
        shL, shR = c.at(c.lm_shoulder("L")), c.at(c.lm_shoulder("R"))
        k = c.scale()
        wr = {"L": shL + Z * 0.05 - Y * 0.0 - st.head_dir * 0.07 * k, "R": shR + Z * 0.05 + Y * 0.07 * k - st.head_dir * 0.07 * k}
        at = (shR.x - 0.08 * k, shR.y + 0.2 * k + 0.02)
        side = kneel_reach(r, f, at, wr, thigh=4, reach=0.99, sit=0.5)
        for h, sgn in (("L", -1), ("R", 1)):
            r.arm(h, wr[h], r.head(f"upperarm01.{h}") + side * sgn * 0.6 + Z * 0.2)
            r.hand(h, -Y + st.head_dir * 0.3 * sgn - Z * 0.3, -Z)
            r.curl(h, 18, thumb=10)
        # head up, calling to him: face turned toward his face from a hand's-breadth-plus away
        r.look(c.at(st.i_mouth) + Z * 0.02, amount=0.5, neck=0.5)
        r.rotate("neck01", side, 18)
        r.rotate("head", side, 12)
        marks.update(mouth=c.at(st.i_mouth), rescuer_head=r.head("head") + Z * 0.1, shoulder=shL)
    elif num == "1":
        side = kneel(r, f, at=(s.x + 0.05, 0.36), lean=4, thigh=4)
        call_pose(r, f, side, marks)
    elif num in "236":
        if child:
            free = c.at(st.i_forehead)
            push_pose(r, s, f, depth=depth, one_hand=True, free_hand=free, thigh=15)
        else:
            push_pose(r, s, f, depth=depth)
        r.look(c.at(st.i_mouth) + Z * 0.3 - f * 0.3, amount=0.4, neck=0.5)
        marks.update(hands=r.head("wrist.R"), shoulders=(r.head("upperarm01.L") + r.head("upperarm01.R")) / 2,
                     elbow=r.head("lowerarm01.L"), rescuer_head=r.head("head") + Z * 0.1)
    elif num == "4":
        st.head_tilt(-22 if not child else -14)
        mouth = c.at(st.i_mouth)
        fh, chin, nose = c.at(st.i_forehead), c.at(st.i_chin), c.at(st.i_nose)
        at = (mouth.x - 0.2, 0.36)

        def lips(p):
            p.look(mouth, amount=1.0, neck=0.5)
            if close_up:
                # face turned sideways (crown toward his feet), so the close-up shows her face, not her hair
                fd = p.face_dir()
                want = -st.head_dir - Y * 0.3
                crown = p.tail("head") - p.head("head")
                a, b = crown - fd * crown.dot(fd), want - fd * want.dot(fd)
                p.rotate("head", fd, math.degrees(a.angle(b)) * (1 if a.cross(b).dot(fd) > 0 else -1))
            return (p.head("oris05") + p.head("oris01")) / 2
        side = reach_pose(r, -Y + X * 0.35, mouth.z + 0.014, lips, at, thigh=0, sit=0.5)
        rm = lips(r)
        # the close-up only shows heads and hands: lips put right on his mouth, knees may sink out of view
        r.rig.location += Vector((mouth.x - rm.x + 0.012, mouth.y - rm.y + (0.01 if close_up else 0.03),
                                  mouth.z + 0.015 - rm.z if close_up else 0))
        update()
        # left hand on the forehead, finger and thumb pinching the nose; right fingertips lift the chin
        hd = st.head_dir
        r.arm("L", fh + Y * 0.075 * c.scale() + Z * 0.035 + hd * 0.015, r.head("upperarm01.L") + hd * 0.5 + Z * 0.3)
        r.hand("L", -Y + hd * 0.25, -Z)
        r.curl("L", 18, thumb=30)
        r.arm("R", chin + Vector((0.05, 0.07, 0.0)), r.head("upperarm01.R") - X * 0.3 - Z * 0.4)
        r.hand("R", Vector((0.6, -0.8, 0.1)), Vector((0.3, -0.2, 1)))
        r.curl("R", 35, thumb=10, fingers=(4, 5))
        marks.update(mouth=mouth, chest=s + Z * 0.03, rescuer_head=r.head("head"), forehead=fh, chin=chin, nose=nose)
    elif num == "5":
        # shirt off / open, pads on bare skin, rescuer sits up clear with open hands
        g = GARMENT[st.variant]
        woman = st.variant in ("pregnant", "woman", "senior_woman")
        if woman:
            c.strip_top(g)
            c.bra(PALETTE["gran-top" if st.variant == "senior_woman" else "woman-top"])
        elif st.variant == "girl":
            c.open_front(g, half=0.07, side=False)  # just the breastbone bared for the front pad
        else:
            c.open_front(g)
        if child:
            p1, _, _ = pad(c, c.lm_sternum(drop=0.02 * c.scale()), "pad-front", (0.1, 0.075))
            back_i = c.lm_back()
            marks["pad_back"] = c.at(back_i)
            pads = [p1]
        else:
            p1, a1, _ = pad(c, c.lm_infraclavicular("R"), "pad-right", turn=0)
            p2, a2, _ = pad(c, c.lm_side("L", drop=0.1 if woman else 0.05), "pad-left", turn=90)
            pads = [p1, p2]
        box_at = Vector((s.x + 0.62, -0.45, 0))
        unit = aed(box_at, Vector((-0.5, -1, 0)))
        for i, pd in enumerate(pads):
            a = pd.matrix_world.translation
            b = unit.matrix_world @ Vector((0.1 - 0.03 * i, 0.12, 0.03))
            mid = a.lerp(b, 0.5)
            wire(f"wire{i}", [a + Z * 0.004, a + Z * 0.05 + (b - a) * 0.15, Vector((mid.x, mid.y - 0.08, 0.02)), b + Z * 0.03 - (b - a).normalized() * 0.1, b])
        side = kneel(r, f, at=(s.x + 0.08, 0.38), lean=-2, thigh=2)
        clear_hands(r, f, side, marks)
        r.look(unit.location + Z * 0.3, amount=0.5)
        marks.update(aed=unit.location, rescuer_head=r.head("head") + Z * 0.12, pad_right=pads[0].location,
                     pad_left=pads[-1].location)

def lud(st, marks):
    """manual left uterine displacement: a helper at her right pushes the bump toward her left"""
    c = st.c
    hp = helper()
    top = c.at(c.lm_bump_top())
    side_r = c.at(c.lm_bump_side("R"))
    hip = c.head("upperleg01.R")
    # kneeling at her right hip, facing across her, both palms on the right side of the bump
    tg = {"L": side_r + Vector((0.07, 0.035, 0.03)), "R": side_r + Vector((-0.06, 0.035, 0.0))}
    side = kneel_reach(hp, -Y + X * 0.7, (hip.x - 0.3, hip.y + 0.3), tg, thigh=10, reach=0.95, sit=0.2)
    for h, sgn in (("L", -1), ("R", 1)):
        hp.arm(h, tg[h], hp.head(f"upperarm01.{h}") + side * sgn * 0.5 - Z * 0.1)
        hp.hand(h, Vector((0, -0.5, 1)) + X * 0.3 * -sgn, -Y + Z * 0.2)
        hp.curl(h, 10, thumb=5)
    hp.look(top + Z * 0.15 - Y * 0.2, amount=0.6)
    c.warp(top - Y * 0.04, -Y * 0.05, 0.2, garments=[GARMENT[st.variant]])
    marks.update(bump=top, helper_head=hp.head("head") + Z * 0.12, helper_hands=side_r)
    del side

def infant_pose(st, r, num, depth, marks):
    c, s = st.c, st.sternum
    feet = (c.head("foot.L") + c.head("foot.R")) / 2
    f = -X  # standing at the baby's feet, facing its head
    end = TABLE[0] / 2
    at = (end + 0.17, 0.0)
    if num == "0":
        sole = c.at(c.lm_sole("R"))
        side = stand(r, f, lean=22, at=at, knees=8)
        r.arm("R", sole + Vector((0.075, 0.0, 0.015)), r.head("upperarm01.R") + side * 0.4 - Z * 0.3)
        r.hand("R", Vector((-1, 0, -0.2)), Vector((-0.5, 0, -1)))
        r.curl("R", 15, thumb=40, fingers=(4, 5))
        r.arm("L", Vector((end - 0.02, -0.2, st.top + 0.03)), r.head("upperarm01.L") - side * 0.4 - Z * 0.1)
        r.hand("L", -X - Y * 0.3, -Z)
        r.curl("L", 12, thumb=8)
        r.look(c.at(st.i_mouth), amount=0.6)
        marks.update(sole=sole, mouth=c.at(st.i_mouth), rescuer_head=r.head("head") + Z * 0.12)
    elif num == "1":
        fc = (f - Y * 1.2).normalized()
        side = stand(r, fc, lean=4, at=(end + 0.2, 0.05))
        call_pose(r, fc, side, marks)
    elif num in "23":
        # two thumbs side by side on the breastbone, hands round the chest, fingers under the back
        target = s - Z * depth
        chest_w = abs(c.head("upperarm01.L").y - c.head("upperarm01.R").y) * 0.8
        lo, hi = 0.0, 80.0
        for _ in range(12):
            lean = (lo + hi) / 2
            side = stand(r, f, lean=lean, at=at, knees=10)
            sh = (r.head("upperarm01.L") + r.head("upperarm01.R")) / 2
            reach = (sh - target).length
            lo, hi = (lean, hi) if reach > r.arm_length() * 0.88 else (lo, lean)
        for h, sgn in (("L", -1), ("R", 1)):
            wrist = Vector((target.x + 0.07, sgn * (chest_w * 0.5 + 0.012), target.z - 0.025))
            r.arm(h, wrist, r.head(f"upperarm01.{h}") + side * sgn * 0.5 - Z * 0.3)
            r.hand(h, Vector((-0.6, -sgn * 0.3, -0.7)), Vector((0, -sgn, 0.2)))
            r.curl(h, 30, thumb=None)
            r.point_thumb(h, target + Y * sgn * 0.009 + Z * 0.012)
        r.look(c.at(st.i_mouth), amount=0.5)
        marks.update(hands=target, rescuer_head=r.head("head") + Z * 0.12)
    elif num == "4":
        mouth, nose = c.at(st.i_mouth), c.at(st.i_nose)
        seal = mouth.lerp(nose, 0.45)
        # at the baby's head end, bending down: mouth over its mouth and nose, head kept level
        fb = X

        def lips(p):
            p.look(seal, amount=1.0, neck=0.6)
            return (p.head("oris05") + p.head("oris01")) / 2
        side = reach_pose(r, fb, seal.z + 0.025, lips, (-end - 0.2, 0.0), standing=True, knees=18)
        rm = lips(r)
        r.rig.location += Vector((seal.x - rm.x - 0.005, seal.y - rm.y, 0))
        update()
        # a hand resting on the chest to feel it rise, the other on the table
        r.arm("L", s + Z * 0.03 + fb * 0.03 + Y * 0.06, r.head("upperarm01.L") - side * 0.5 - Z * 0.2)
        r.hand("L", fb - Y * 0.3, -Z)
        r.curl("L", 12, thumb=8)
        r.arm("R", Vector((s.x - 0.12, -TABLE[1] / 2 + 0.07, st.top + 0.03)), r.head("upperarm01.R") + side * 0.5 - Z * 0.2)
        r.hand("R", fb + side * 0.3, -Z)
        r.curl("R", 12, thumb=8)
        marks.update(mouth=seal, chest=s + Z * 0.02, rescuer_head=r.head("head"))
    elif num == "5":
        c.open_front(GARMENT["infant"])
        p1, _, _ = pad(c, c.lm_sternum(drop=0.01), "pad-front", (0.07, 0.05))
        marks["pad_back"] = c.at(c.lm_back())
        unit = aed(Vector((s.x - 0.05, 0.2, st.top)), Vector((0.1, -1, 0)))
        a = p1.matrix_world.translation
        b = unit.matrix_world @ Vector((0.1, 0.12, 0.03))
        wire("wire0", [a + Z * 0.004, a + Z * 0.05, a.lerp(b, 0.5) + Z * 0.04, b + Z * 0.03, b])
        fc = (f - Y * 0.8).normalized()
        side = stand(r, fc, lean=2, at=(end + 0.05, 0.42))
        clear_hands(r, fc, side, marks)
        r.look(c.at(st.i_mouth), amount=0.4)
        marks.update(aed=unit.location, pad_front=p1.location, rescuer_head=r.head("head") + Z * 0.12)
