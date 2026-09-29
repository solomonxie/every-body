"""Face landmarks (MediaPipe Face Landmarker, 478 points) and their per-group averages.

  venv/bin/python scripts/models/face_landmarks.py average <photo dir> [out.npz]
      each subfolder (a group) → its faces aligned (similarity) and averaged → scripts/models/faces.npz
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
MODEL = HERE.parents[1] / "tools" / "downloads" / "face" / "face_landmarker.task"
AVERAGES = HERE / "faces.npz"
_landmarker = None


def landmarker():
    global _landmarker
    if _landmarker is None:
        from mediapipe.tasks.python import BaseOptions, vision
        opts = vision.FaceLandmarkerOptions(base_options=BaseOptions(model_asset_path=str(MODEL), delegate=BaseOptions.Delegate.CPU), num_faces=4,
                                            output_face_blendshapes=True, min_face_detection_confidence=0.3)
        _landmarker = vision.FaceLandmarker.create_from_options(opts)
    return _landmarker


def detect(rgb):
    """the largest face in an RGB array: (478×3 points in pixels, z in the same scale), blendshapes; or None"""
    import mediapipe as mp
    h, w = rgb.shape[:2]
    res = landmarker().detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=np.ascontiguousarray(rgb)))
    best = None
    for i, lm in enumerate(res.face_landmarks):
        p = np.array([(q.x * w, q.y * h, q.z * w) for q in lm])
        size = np.ptp(p[:, 0]) * np.ptp(p[:, 1])
        if best is None or size > best[0]:
            shapes = {b.category_name: b.score for b in res.face_blendshapes[i]} if res.face_blendshapes else {}
            best = (size, p, shapes)
    return None if best is None else best[1:]


def similarity(src, dst, w=None):
    """s, R, t minimising |s R src + t - dst| (weighted)"""
    w = np.ones(len(src)) if w is None else w
    w = w / w.sum()
    ms, md = w @ src, w @ dst
    a, b = src - ms, dst - md
    u, sv, vt = np.linalg.svd((b * w[:, None]).T @ a)
    d = np.sign(np.linalg.det(u @ vt))
    D = np.diag([1, 1, d])
    R = u @ D @ vt
    s = (sv * np.diag(D)).sum() / (w @ (a ** 2).sum(1))
    return s, R, md - s * R @ ms


def align(src, dst, w=None):
    s, R, t = similarity(src, dst, w)
    return src @ (s * R).T + t


def to_up(p):
    """image axes (x right, y down, z toward the camera negative) → x right, y up, z toward the viewer"""
    return p * np.array([1, -1, -1])


def mean_shape(faces, iters=5):
    ref = faces[0]
    for _ in range(iters):
        al = np.array([align(f, ref) for f in faces])
        ref = al.mean(0)
        ref = (ref - ref.mean(0)) / np.sqrt(((ref - ref.mean(0)) ** 2).sum(1).mean())
    return ref, al


def average(root, out=AVERAGES):
    got = {}
    for d in sorted(Path(root).iterdir()):
        if not d.is_dir():
            continue
        faces, used = [], []
        for f in sorted(d.iterdir()):
            try:
                im = np.array(Image.open(f).convert("RGB"))
            except Exception:
                continue
            r = detect(im)
            if r is None:
                print("  no face", f.name)
                continue
            p, shapes = r
            width = np.ptp(p[:, 0])
            yaw = abs(p[454, 2] - p[234, 2]) / width
            smile, jaw = shapes.get("mouthSmileLeft", 0), shapes.get("jawOpen", 0)
            if width < 80 or yaw > 0.6 or smile > 0.5 or jaw > 0.2:
                print("  skipped", f.name, int(width), round(float(yaw), 2), round(smile, 2))
                continue
            if any(np.sqrt(((align(to_up(p), g) - g) ** 2).sum(1).mean()) < 1e-3 * width for g in faces):
                print("  duplicate", f.name)
                continue
            faces.append(to_up(p))
            used.append((f.name, int(width), round(float(yaw), 2), round(shapes.get("mouthSmileLeft", 0), 2),
                         round(shapes.get("jawOpen", 0), 2)))
        if not faces:
            continue
        ref, al = mean_shape(np.array(faces))
        got[d.name] = ref
        got[d.name + ":n"] = np.array(len(faces))
        print(d.name, len(faces), "faces")
        for u in used:
            print("   ", *u)
    np.savez_compressed(out, **got)
    print("→", out)


if __name__ == "__main__":
    if sys.argv[1] == "average":
        average(sys.argv[2], *(sys.argv[3:4]))
