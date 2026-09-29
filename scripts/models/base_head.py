"""Heads put on the MakeHuman figures by face_fit.py: Blender Studio's Snow and Rain characters (CC BY,
studio.blender.org), their sculpted hair too.

  Blender -b <character.blend> -P base_head.py -- <name>   # a character's head, eyes, hair → RAW/basehead-<name>.npz
  profile_marks(np, p, eye_l, eye_r) # midline marks (nose, mouth, chin, …) of a head
"""

import sys
from pathlib import Path

# name: (.blend under downloads/, head, eyes (both in one mesh), hair meshes)
CHARACTERS = {
    "snow": ("blender-studio/snow/snow_v02.blend", "GEO-snow_head", "GEO-snow_eyes", ["GEO-snow_hair_base"]),
    "rain": ("blender-studio/rain/rain_rig.blend", "GEO-rain_head", "GEO-rain_eyes",
             ["GEO-rain_hair_main", "GEO-rain_hair_ponytail"]),
}


def extract_character(np, raw, name):
    """(Blender, the character's file open) its evaluated head, eyes and hair in scene axes"""
    import bpy
    from build_models import to_scene
    _, head, eyes, hairs = CHARACTERS[name]
    bpy.context.scene.render.use_simplify = False
    for n in (head, eyes, *hairs):
        for m in bpy.data.objects[n].modifiers:
            if m.type == "SUBSURF":
                m.levels, m.show_viewport = 1, True
    dg = bpy.context.evaluated_depsgraph_get()

    def mesh(n):
        ob = bpy.data.objects[n]
        me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
        if len(me.vertices) == len(ob.data.vertices):
            # its own subdivision didn't run (driven off): one level added here
            tmp = bpy.data.objects.new(n + "-smooth", me)
            bpy.context.scene.collection.objects.link(tmp)
            tmp.modifiers.new("smooth", "SUBSURF").levels = 1
            me = bpy.data.meshes.new_from_object(tmp.evaluated_get(bpy.context.evaluated_depsgraph_get()))
        me.transform(ob.matrix_world)
        me.calc_loop_triangles()
        return np.array([x.co[:] for x in me.vertices]), np.array([lt.vertices[:] for lt in me.loop_triangles])
    v, t = mesh(head)
    e, _ = mesh(eyes)
    centres = [e[np.sign(e[:, 0]) == s].mean(0) for s in (1, -1)]
    rad = np.linalg.norm(e[e[:, 0] > 0] - centres[0], axis=1).max()
    got = dict(pos=to_scene(np, v), tri=t, eyes=to_scene(np, np.array(centres)), eye_radius=np.array(rad))
    for i, n in enumerate(hairs):
        hv, ht = mesh(n)
        got[f"hair{i}_pos"], got[f"hair{i}_tri"] = to_scene(np, hv), ht
    np.savez_compressed(raw / f"basehead-{name}.npz", **got)
    print("BASEHEAD", name, {k: v.shape for k, v in got.items()})


def profile_marks(np, p, eye_l, eye_r):
    e = (eye_l + eye_r) / 2
    U = np.linalg.norm(eye_l - eye_r)
    mid = p[np.abs(p[:, 0] - e[0]) < 0.15 * U]
    front = mid[mid[:, 2] > e[2] - 1.2 * U]

    def best(lo, hi, sign):
        s = front[(front[:, 1] > lo) & (front[:, 1] < hi)]
        # the surface: the front-most point per slice
        ys = np.linspace(lo, hi, 40)
        prof = []
        for y0, y1 in zip(ys[:-1], ys[1:]):
            q = s[(s[:, 1] >= y0) & (s[:, 1] < y1)]
            if len(q):
                prof.append(q[np.argmax(q[:, 2])])
        prof = np.array(prof)
        return prof[np.argmax(sign * prof[:, 2])]
    nose = best(e[1] - 1.4 * U, e[1] - 0.3 * U, 1)
    # bottom of the chin: the lowest midline point still in front (not the throat)
    under = mid[(mid[:, 2] > e[2] - 0.2 * U) & (mid[:, 1] > nose[1] - 2.6 * U) & (mid[:, 1] < nose[1] - 0.8 * U)]
    menton = under[np.argmin(under[:, 1])]
    # (the lips' front surface, not the mouth behind them)
    lip = best(menton[1] + 0.3 * U, nose[1] - 0.3 * U, 1)
    front = front[front[:, 2] > lip[2] - 0.6 * U]
    mouth = best(menton[1] + 0.6 * U, nose[1] - 0.35 * U, -1)
    chin = best(menton[1] + 0.1 * U, mouth[1] - 0.45 * U, 1)
    top = mid[np.argmax(mid[:, 1])]
    back_s = p[(np.abs(p[:, 1] - (e[1] + 0.4 * U)) < 0.3 * U) & (np.abs(p[:, 0] - e[0]) < 0.5 * U)]
    back = back_s[np.argmin(back_s[:, 2])] * np.array([0, 1, 1]) + np.array([e[0], 0, 0])
    band = p[np.abs(p[:, 1] - (e[1] + 1.1 * U)) < 0.08 * U]
    wide_l, wide_r = band[np.argmax(band[:, 0])], band[np.argmin(band[:, 0])]
    marks = dict(nose=nose, mouth=mouth, chin=chin, menton=menton, top=top, back=back)
    marks = {k: np.array([e[0], v[1], v[2]]) for k, v in marks.items()}
    return dict(eye_l=eye_l, eye_r=eye_r, wide_l=wide_l, wide_r=wide_r, **marks), U


def smooth(np, d, tris, n, k):
    """Laplacian smoothing of a per-vertex field over the mesh"""
    e = np.concatenate([tris[:, [0, 1]], tris[:, [1, 2]], tris[:, [2, 0]]])
    cnt = np.bincount(e.ravel(), minlength=n).astype(float)[:, None]
    for _ in range(k):
        acc = np.zeros_like(d)
        np.add.at(acc, e[:, 0], d[e[:, 1]])
        np.add.at(acc, e[:, 1], d[e[:, 0]])
        d = 0.5 * d + 0.5 * acc / np.maximum(cnt, 1)
    return d


if __name__ == "__main__":
    import numpy
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from build_figure import RAW
    extract_character(numpy, RAW, sys.argv[sys.argv.index("--") + 1])
