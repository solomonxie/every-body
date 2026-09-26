"""Quick front/side projection of Resources/Data/body.json for checking anatomy without the phone.

Run: venv/bin/python scripts/preview_body.py /tmp/body.png [layers...]
"""

import json
import os
import math
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

DATA = Path(__file__).resolve().parent.parent / "Resources" / "Data" / "body.json"


def sub(a, b):
    return [a[i] - b[i] for i in range(3)]


def samples(s):
    """Point cloud on the shape's surface (enough for a silhouette)."""
    k = s["kind"]
    out = []
    if k == "sphere":
        sc = s.get("scale", [1, 1, 1])
        for i in range(12):
            for j in range(12):
                th, ph = math.pi * i / 11, 2 * math.pi * j / 12
                p = [math.sin(th) * math.cos(ph) * sc[0], math.cos(th) * sc[1], math.sin(th) * math.sin(ph) * sc[2]]
                out.append([s["center"][n] + s["radius"] * p[n] for n in range(3)])
    elif k in ("segment", "spindle", "lathe"):
        a, b = s["from"], s["to"]
        radii = s.get("radii") or ([s["radius"]] * 3 if k == "segment" else [0, s["radius"], 0])
        d = sub(b, a)
        length = math.sqrt(sum(x * x for x in d)) or 1e-6
        u = [x / length for x in d]
        ref = [0, 1, 0] if abs(u[1]) < 0.9 else [1, 0, 0]
        v = [u[1] * ref[2] - u[2] * ref[1], u[2] * ref[0] - u[0] * ref[2], u[0] * ref[1] - u[1] * ref[0]]
        vl = math.sqrt(sum(x * x for x in v)) or 1
        v = [x / vl for x in v]
        w = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]]
        for i in range(16):
            t = i / 15
            f = t * (len(radii) - 1)
            r = radii[min(len(radii) - 1, int(f))] if len(radii) == 1 else radii[int(min(f, len(radii) - 1.001))] + (radii[min(len(radii) - 1, int(f) + 1)] - radii[int(min(f, len(radii) - 1.001))]) * (f - int(f))
            c = [a[n] + d[n] * t for n in range(3)]
            for j in range(10):
                ph = 2 * math.pi * j / 10
                out.append([c[n] + r * (math.cos(ph) * v[n] + math.sin(ph) * w[n]) for n in range(3)])
    elif k == "tube":
        pts = s["points"]
        for i in range(len(pts) - 1):
            for t in range(6):
                out.append([pts[i][n] + (pts[i + 1][n] - pts[i][n]) * t / 5 for n in range(3)])
    elif k == "plate":
        pts = s["points"]
        c = [sum(p[n] for p in pts) / len(pts) for n in range(3)]
        for p in pts:
            for t in range(6):
                out.append([c[n] + (p[n] - c[n]) * t / 5 for n in range(3)])
    elif k == "loft":
        secs = s["sections"]
        rows = []
        for a, b in zip(secs, secs[1:]):
            for t in range(6):
                rows.append([a[n] + (b[n] - a[n]) * t / 6 for n in range(5)])
        rows.append(secs[-1])
        for i, (x, y, z, rx, rz) in enumerate(rows):
            p, q = rows[max(0, i - 1)], rows[min(len(rows) - 1, i + 1)]
            t = [q[n] - p[n] for n in range(3)]
            tl = math.sqrt(sum(c * c for c in t)) or 1e-6
            t = [c / tl for c in t]
            # same frame as Meshes.loft: sections measured against x, or y when the loft runs sideways
            ref = [0, 1, 0] if abs(t[0]) > 0.8 else [1, 0, 0]
            d = sum(ref[n] * t[n] for n in range(3))
            side = [ref[n] - d * t[n] for n in range(3)]
            sl = math.sqrt(sum(c * c for c in side)) or 1e-6
            side = [c / sl for c in side]
            depth = [side[1] * t[2] - side[2] * t[1], side[2] * t[0] - side[0] * t[2], side[0] * t[1] - side[1] * t[0]]
            for j in range(18):
                ph = 2 * math.pi * j / 18
                out.append([[x, y, z][n] + rx * math.cos(ph) * side[n] + rz * math.sin(ph) * depth[n] for n in range(3)])
    elif k == "box":
        out.append(s["center"])
    return out


def main():
    body = json.loads(DATA.read_text())
    layers = sys.argv[2:] or ["skeletal"]
    colors = {"skin": "#F2C9A5", "skeletal": "#9A8F75", "muscular": "#C1443C", "circulatory": "#D23A3A", "nervous": "#E8B923", "organs": "#8C3B2E"}
    fig, axes = plt.subplots(1, 2, figsize=(8, 9))
    shapes = [(p["shape"], colors[p["layer"]]) for p in body["parts"] if p["layer"] in layers and p.get("sex") != "female"]
    if "organs" in layers:
        shapes += [(s, o["color"]) for o in body["organs"] if not o.get("region") for s in o["shapes"]]
    for ax, (i, j), title in ((axes[0], (0, 1), "front"), (axes[1], (2, 1), "side (front →)")):
        for s, color in shapes:
            pts = samples(s)
            ax.scatter([p[i] for p in pts], [p[1] for p in pts], s=0.4, c=color, alpha=0.5 if s["kind"] in ("tube", "loft") else 0.25)
        ax.set_aspect("equal")
        ax.set_title(title)
        lo, hi = map(float, os.environ.get("YLIM", "-1.7,1.8").split(","))
        ax.set_ylim(lo, hi)
        if "XLIM" in os.environ:
            ax.set_xlim(*map(float, os.environ["XLIM"].split(",")))
    fig.savefig(sys.argv[1], dpi=110, bbox_inches="tight")


if __name__ == "__main__":
    main()
