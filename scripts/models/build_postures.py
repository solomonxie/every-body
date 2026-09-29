"""Posture scenes → Resources/Models/postures/<topic>.bin (see Sources/Posture/PostureModel.swift).

The shipped figure (figure.bin) and inner models (skeleton / muscles / nerves .usdz) are posed with a small rig in
scene coordinates: a vertebra-by-vertebra spine (joints at the Z-Anatomy disc centres), pelvis, shoulder girdle and
limbs (joints at the generated body landmarks). Skin weights come from MakeHuman's default rig (CC0), with its spine
weights spread over the vertebrae. Bones move rigidly with their rig bone; discs wedge between their two vertebrae.
Each posture key is stored as positions (int16 deltas from the first key); the app blends two keys.

Re-runnable after figure.bin / the usdz files are rebuilt (same MakeHuman topology):
  Blender -b -P build_postures.py -- extract     # usdz → build/postures/inner.npz   (build.sh postures)
  venv/bin/python build_postures.py pack [topic]  # → Resources/Models/postures/*.bin
"""

import json
import math
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODELS = ROOT / "Resources" / "Models"
OUT = MODELS / "postures"
RAW = ROOT / "build" / "postures"
M = 1.86  # scene units per metre

# inner pieces kept for the posture scenes: (usdz, ids or prefixes)
INNER = {
    "skeleton.usdz": None,  # all bones
    "muscles.usdz": ["erector-spinae-l", "erector-spinae-r", "transversospinales-l", "transversospinales-r",
                     "splenius-l", "splenius-r", "levator-scapulae-l", "levator-scapulae-r"],
}


def extract():
    """Blender's Python (pxr): inner meshes in scene coordinates → build/postures/inner.npz"""
    import numpy as np
    from pxr import Usd, UsdGeom
    RAW.mkdir(parents=True, exist_ok=True)
    out = {}
    for file, keep in INNER.items():
        stage = Usd.Stage.Open(str(MODELS / file))
        for p in stage.Traverse():
            if not p.IsA(UsdGeom.Mesh):
                continue
            pid = p.GetName().replace("_", "-")
            if keep is not None and pid not in keep:
                continue
            mesh = UsdGeom.Mesh(p)
            m = np.array(UsdGeom.Xformable(p).ComputeLocalToWorldTransform(0), dtype=np.float64)
            pts = np.array(mesh.GetPointsAttr().Get(), dtype=np.float64)
            pts = pts @ m[:3, :3] + m[3, :3]
            counts = np.array(mesh.GetFaceVertexCountsAttr().Get())
            idx = np.array(mesh.GetFaceVertexIndicesAttr().Get())
            tris, k = [], 0
            for c in counts:
                for j in range(1, c - 1):
                    tris.append((idx[k], idx[k + j], idx[k + j + 1]))
                k += c
            out[f"pos:{pid}"] = pts.astype(np.float32)
            out[f"tri:{pid}"] = np.array(tris, dtype=np.uint32)
    np.savez_compressed(RAW / "inner.npz", **out)
    print("POSTURES extract", len(out) // 2, "pieces")


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    if args and args[0] == "extract":
        extract()
    else:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import posture_rig
        posture_rig.pack(args[1:] if args[:1] == ["pack"] else args)
