"""Recovery position: roll an unresponsive, breathing person onto their side (adult, child; pregnant onto her LEFT side),
plus the baby version (held face down along the forearm). The roll has four frames (5a–5d) for the drag.
One camera per variant: from above the rescuer's shoulder, the rescuer kneeling on the near side.
"""

import math

import kit
from kit import *  # noqa: F401,F403
from mathutils import Matrix, Vector

SHOTS = {v: ["0", "1", "2", "3", "4", "5a", "5b", "5c", "5d", "6", "7"] for v in ("adult", "woman", "senior", "senior_woman", "pregnant", "child", "girl")}
SHOTS["infant"] = ["0", "1", "2a", "2b"]
ROLL = {"a": 0.25, "b": 0.5, "c": 0.75, "d": 1.0}
TABLE = (0.95, 0.62)


def shoot(shot, close=False):
    variant, step = shot.split("-")
    reset()
    kit.size(1080, 900)
    setup_render()
    if variant == "infant":
        baby(step, close)
        return
    c = casualty(variant)
    r = rescuer()
    # pregnant: head to the right so the roll toward us puts her on her LEFT side
    hd = X if variant == "pregnant" else -X
    lie_supine(c, head_dir=hd, arms_out=0.1)
    mid = (c.head("head") + (c.head("foot.L") + c.head("foot.R")) / 2) / 2
    c.rig.location += Vector((-mid.x, -mid.y, 0))
    update()
    kc = c.scale()
    near = -0.62 * kc - 0.08 if variant not in KIDS else -0.5 * kc
    box = [Vector((x, y, z)) for x in (-0.98 * kc, 0.98 * kc) for y in (near, 0.42 * kc) for z in (0.0, 0.3 * kc)]
    num = step[0]
    roll = ROLL.get(step[1:], 0.0) if num == "5" else (1.0 if num in "67" else 0.0)
    marks = pose_casualty(c, hd, num, roll)
    # child: kneel toward the feet, but level with the chest for the knee pull so our head leaves the knee in view
    SHIFT["x"] = -hd.x * 0.28 if variant in KIDS and num not in "45" else 0.0
    pose_rescuer(r, c, hd, num, marks)
    center = sum(box, Vector()) / len(box)
    # steeply from above our shoulder: we kneel at the bottom edge, only head, shoulders and arms in view
    view = Vector((-hd.x * 0.6, -3.2, 7.4)) if variant not in KIDS else Vector((-hd.x * 0.4, -1.6, 8.0))
    cam = camera(center + view, center + Vector((0, 0.05, 0)), 120)
    frame(cam, box, (0.02, 0.98, 0.0, 0.88))
    ground(Vector((center.x, 0.0, 0)), 2.4)
    lights(center, 1.0)
    finish("recovery", f"{variant}-{step}{'-close' if close else ''}", marks)


def near_far(c):
    """(near arm/leg side, far side) letters: near = toward us (−Y)"""
    return ("L", "R") if c.head("upperarm01.L").y < c.head("upperarm01.R").y else ("R", "L")


def pose_casualty(c, hd, num, roll):
    k = c.scale()
    n, fs = near_far(c)
    marks = {}
    lat = hd.cross(Z)  # the body's left-right axis for tilting the head back
    if num in "16":
        c.rotate("neck02", lat, 12)
        c.rotate("head", lat, 14)
    if num >= "2":
        # near arm out at a right angle, elbow bent, palm up
        for b in ("upperarm01", "upperarm02"):
            c.aim(f"{b}.{n}", direction=-Y - hd * 0.05 - Z * 0.08)
        for b in ("lowerarm01", "lowerarm02"):
            c.aim(f"{b}.{n}", direction=hd - Z * 0.05)
        c.hand(n, hd, Z)
        c.curl(n, 15, thumb=5)
    marks["near_elbow"] = c.head(f"lowerarm01.{n}")
    marks["near_palm"] = c.head(f"finger3-1.{n}")
    cheek = c.at(c.lm_mouth()) - Y * 0.055 * k - hd * 0.03 * k
    if num >= "3":
        # back of the far hand against the near cheek
        c.arm(fs, cheek + Z * 0.02 - hd * 0.05 * k, c.head(f"upperarm01.{fs}") + Z * 0.5 - hd * 0.3)
        c.hand(fs, hd - Y * 0.3, -Y - Z * 0.4)
        c.curl(fs, 20, thumb=10)
    if num >= "4":
        # far knee up, foot flat
        hip = c.head(f"upperleg01.{fs}")
        ankle = c.head(f"foot.{fs}")
        c.leg(fs, ankle.lerp(hip, 0.42) + Z * 0.0, hip + (ankle - hip) * 0.5 + Z * 0.8)
        c.aim(f"foot.{fs}", direction=-hd - Z * 0.35)
    floor_hand = c.head(f"wrist.{n}")
    if roll:
        # roll toward us about a line on the floor under the near side
        pivot = Vector((0, -0.14 * k, 0))
        rot = Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(88 * roll), 4, X * (1 if hd.x > 0 else 1)) @ Matrix.Translation(-pivot)
        # rotating +Y toward +Z brings the far side up and over toward us
        c.rig.matrix_world = rot @ c.rig.matrix_world
        update()
        # the near arm stays on the floor, out in front
        c.arm(n, Vector((floor_hand.x, floor_hand.y - 0.05 * roll, 0.04)), c.head(f"upperarm01.{n}") + Z * 0.4 - Y * 0.3)
        c.hand(n, hd - Y * 0.3 * roll, Z * (1 - roll) - Y * roll + Z * 0.2)
        if roll >= 1.0:
            # top leg: hip and knee bent at right angles, knee on the floor in front
            hip = c.head(f"upperleg01.{fs}")
            knee_at = hip - Y * 0.42 * k - hd * 0.06 * k
            knee_at.z = 0.09 * k
            thigh = (knee_at - hip).normalized()
            for b in ("upperleg01", "upperleg02"):
                c.aim(f"{b}.{fs}", knee_at)
            for b in ("lowerleg01", "lowerleg02"):
                c.aim(f"{b}.{fs}", direction=-hd - thigh * 0.05 - Z * 0.1)
            c.aim(f"foot.{fs}", direction=-hd - Y * 0.3 - Z * 0.3)
        c.ground(0.0)
    marks.update(head=c.head("head"), far_knee=c.head(f"lowerleg01.{fs}"), mouth=c.at(c.lm_mouth()), forehead=c.at(c.lm_forehead()),
                 chin=c.at(c.lm_chin()), far_hand=c.head(f"wrist.{fs}"), near_shoulder=c.at(c.lm_shoulder(n)), far_shoulder=c.at(c.lm_shoulder(fs)))
    return marks


def pose_rescuer(r, c, hd, num, marks):
    """kneeling on the near side, facing across them (+Y)"""
    f = Y
    k = c.scale()
    chest_x = c.head("spine02").x
    hip_x = c.head("root").x
    if num == "0":
        tg = {"L": marks["far_shoulder"] + Z * 0.05 - Y * 0.05, "R": marks["near_shoulder"] + Z * 0.05}
        if hd.x > 0:
            tg = {"L": marks["near_shoulder"] + Z * 0.05, "R": marks["far_shoulder"] + Z * 0.05 - Y * 0.05}
        _reach(r, f, (chest_x - hd.x * 0.02, -0.72 * k - 0.1), tg)
        r.look(marks["mouth"] + Z * 0.05, amount=0.6)
    elif num in "16":
        head_side = "L" if hd.x > 0 else "R"  # her hand nearer their head
        other = "R" if head_side == "L" else "L"
        tg = {head_side: marks["forehead"] + Z * 0.035, other: marks["chin"] + Z * 0.02 - hd * 0.02}
        # on their side: kneel level with the chest, so the face stays in view
        at_x = marks["head"].x - hd.x * (0.32 if num == "1" else 0.5) * k
        _reach(r, f, (at_x, -0.72 * k - (0.1 if num == "1" else 0.2)), tg, sit=0.35)
        r.look(marks["mouth"] + (Z * 0.02 if num == "1" else Z * 0.2), amount=0.8 if num == "1" else 0.5)
    elif num == "2":
        hand_side = "R" if hd.x < 0 else "L"
        tg = {hand_side: marks["near_elbow"].lerp(marks["near_palm"], 0.5) + Z * 0.05}
        _reach(r, f, (marks["near_elbow"].x - hd.x * 0.1, -0.72 * k - 0.1), tg, rest=True)
        r.look(tg[hand_side], amount=0.6)
    elif num in "345":
        head_side = "L" if hd.x > 0 else "R"
        other = "R" if head_side == "L" else "L"
        tg = {head_side: marks["far_hand"] + Z * 0.04 - Y * 0.03}
        if num != "3":
            tg[other] = marks["far_knee"] + Z * 0.05 - Y * 0.04
        at_x = chest_x if num == "3" else (chest_x + hip_x) / 2
        _reach(r, f, (at_x, -0.72 * k - 0.1), tg, rest=num == "3")
        r.look(marks["far_knee"] if num != "3" else marks["far_hand"], amount=0.6)
    else:
        # sitting up beside them, phone on speaker, watching the breathing
        side = kneel(r, f, at=(hip_x - hd.x * 0.1, -0.72 * k - 0.2), lean=0, thigh=0, sit=0.45)
        shl = r.head("upperarm01.L")
        r.arm("L", shl + f * 0.26 - Z * 0.18 - side * 0.12, shl - side * 0.4 - Z * 0.3)
        r.hand("L", f * 0.3 - side * 0.45 + Z * 0.55, f - Z * 0.4)
        r.curl("L", 28, thumb=18)
        phone_in(r, "L")
        relax = r.head("upperleg01.R").lerp(r.head("lowerleg01.R"), 0.6) + Z * 0.06
        r.arm("R", relax, r.head("upperarm01.R") + side - f * 0.3)
        r.hand("R", f, -Z)
        r.curl("R", 20, thumb=10)
        r.look(marks["mouth"], amount=0.6)
    marks["rescuer_head"] = r.tail("head")


SHIFT = {"x": 0.0}


def _reach(r, f, at, targets, sit=0.2, rest=False):
    at = (at[0] + SHIFT["x"], at[1])
    side = kneel_reach(r, f, at, targets, thigh=10, reach=0.98, sit=sit)
    for h, t in targets.items():
        sgn = 1 if h == "R" else -1
        r.arm(h, t, r.head(f"upperarm01.{h}") + side * sgn * 0.5 - Z * 0.3)
        r.hand(h, f + Z * -0.3, -Z)
        r.curl(h, 18, thumb=10)
    if rest:
        h = "L" if "R" in targets else "R"
        sgn = 1 if h == "R" else -1
        thigh = r.head(f"upperleg01.{h}").lerp(r.head(f"lowerleg01.{h}"), 0.6) + Z * 0.06
        r.arm(h, thigh, r.head(f"upperarm01.{h}") + side * sgn - f * 0.3)
        r.hand(h, f, -Z)
        r.curl(h, 20, thumb=10)
    return side


# ------------------------------------------------------------------ baby


def baby(step, close):
    c = casualty("infant")
    r = rescuer()
    marks = {}
    if step in ("0", "1"):
        top = 0.9
        table((0.0, 0.0), TABLE, top)
        top += 0.018
        lie_supine(c, head_dir=-X, z=top, arms_out=0.2)
        feet = (c.head("foot.L") + c.head("foot.R")) / 2
        c.rig.location.x += (TABLE[0] / 2 - 0.1) - feet.x
        update()
        end = TABLE[0] / 2
        if step == "0":
            sole = c.at(c.lm_sole("R"))
            side = stand(r, -X, lean=22, at=(end + 0.17, 0.0), knees=8)
            r.arm("R", sole + Vector((0.075, 0.0, 0.015)), r.head("upperarm01.R") + side * 0.4 - Z * 0.3)
            r.hand("R", Vector((-1, 0, -0.2)), Vector((-0.5, 0, -1)))
            r.curl("R", 15, thumb=40, fingers=(4, 5))
            r.arm("L", Vector((end - 0.02, -0.2, top + 0.01)), r.head("upperarm01.L") - side * 0.4 - Z * 0.1)
            r.hand("L", -X - Y * 0.3, -Z)
            r.curl("L", 12, thumb=8)
            r.look(c.at(c.lm_mouth()), amount=0.6)
            marks.update(sole=sole)
        else:
            # cheek just above the mouth, eyes along the chest
            mouth = c.at(c.lm_mouth())
            chest = c.at(c.lm_sternum())

            def cheek(p):
                p.look(chest + Z * 0.05, amount=1.0, neck=0.6)
                return (p.head("oris05") + p.head("oris01")) / 2 + (p.rig.matrix_world.to_3x3() @ Vector((-0.07, 0, 0)))
            side = reach_pose(r, X, mouth.z + 0.06, cheek, (-end - 0.2, 0.0), standing=True, knees=16)
            rm = cheek(r)
            r.rig.location += Vector((mouth.x - rm.x + 0.02, mouth.y - rm.y, 0))
            update()
            r.arm("L", chest + Z * 0.03 + X * 0.04, r.head("upperarm01.L") - side * 0.5 - Z * 0.2)
            r.hand("L", X - Y * 0.2, -Z)
            r.curl("L", 12, thumb=8)
            r.arm("R", Vector((-end + 0.1, -TABLE[1] / 2 + 0.07, top + 0.02)), r.head("upperarm01.R") + side * 0.5 - Z * 0.2)
            r.hand("R", X + side * 0.3, -Z)
            r.curl("R", 12, thumb=8)
            marks.update(chest=chest)
        marks.update(head=c.head("head"), mouth=c.at(c.lm_mouth()), rescuer_head=r.tail("head"))
        box = [Vector((x, y, z)) for x in (-0.86, 0.8) for y in (-0.3, 0.3) for z in (top - 0.1, top + 0.88)]
        center = Vector((0.0, 0.0, top + 0.15))
        cam = camera(center + Vector((0.5, -2.6, 2.0)), center + Vector((0.0, 0.1, 0.0)), 60)
        frame(cam, box, (0.02, 0.98, 0.0, 0.84))
        ground(Vector((0, 0.1, 0)), 2.4)
        lights(center, 1.0)
    else:
        # standing, baby face down along the left forearm, hand holding the jaw; tilt: the head end lower
        tilt = 1.0 if step == "2b" else 0.0
        f = X
        side = stand(r, f, lean=6, at=(-0.1, 0.0))
        sh = r.head("upperarm01.L")
        slope = math.radians(4 + tilt * 22)
        d = (f * math.cos(slope) - Z * math.sin(slope)).normalized()
        elbow = sh + Z * -0.27 + f * 0.06 + Y * 0.02
        palm = elbow + d * 0.33
        r.limb(["upperarm01.L", "upperarm02.L"], ["lowerarm01.L", "lowerarm02.L"], "wrist.L", elbow + d * 0.24, sh - Z * 0.3 - f * 0.5)
        r.hand("L", d + Y * 0.15, Z)
        r.curl("L", 30, thumb=20)
        # baby: face down along the forearm, head just past the hand
        c.rig.matrix_world = (-Y).rotation_difference(-Z).to_matrix().to_4x4()
        update()
        up_now = (c.head("head") - c.head("root")).normalized()
        c.rig.matrix_world = up_now.rotation_difference(d).to_matrix().to_4x4() @ c.rig.matrix_world
        update()
        for h in "LR":
            c.aim(f"upperarm01.{h}", direction=-Z + d * 0.3)
            c.aim(f"upperarm02.{h}", direction=-Z + d * 0.3)
            c.curl(h, 30, thumb=15)
            for b in ("upperleg01", "upperleg02"):
                c.aim(f"{b}.{h}", direction=-d - Z * 0.8 + (Y if h == "L" else -Y) * 0.25)
            for b in ("lowerleg01", "lowerleg02"):
                c.aim(f"{b}.{h}", direction=-Z - d * 0.2)
        c.close_eyes()
        chest = c.head("spine02")
        c.rig.location += (palm - d * 0.13 + Z * 0.075) - chest
        update()
        # other hand steadies the back
        back = c.at(c.lm_blades())
        r.arm("R", back + Z * 0.04 - d * 0.08, r.head("upperarm01.R") - Z * 0.4 - Y * 0.3)
        r.hand("R", d, -Z)
        r.curl("R", 12, thumb=8)
        r.look(c.head("head"), amount=0.7)
        marks.update(baby_head=c.head("head"), hip=c.head("root"), jaw=palm, rescuer_head=r.tail("head"))
        box = [Vector((x, y, z)) for x in (-0.45, 0.75) for y in (-0.3, 0.3) for z in (0.55, 1.8)]
        center = sum(box, Vector()) / len(box)
        cam = camera(center + Vector((0.4, -3.0, 0.5)), center + Vector((0.05, 0.1, -0.05)), 60)
        frame(cam, box, (0.02, 0.7, 0.0, 0.96))
        lights(center, 1.0)
    finish("recovery", f"infant-{step}{'-close' if close else ''}", marks)
