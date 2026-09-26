"""Generate Resources/Data/charts.json: anatomical outlines and reflex zones for hand, foot and ear.

Run: venv/bin/python scripts/render_charts/gen_charts.py   (needs shapely)
Then preview: scripts/render_charts/render.sh
Anchors are kept from the existing file (scripts/gen_body.py owns them).
"""
import json
import re
import sys
from pathlib import Path

from shapely.ops import unary_union

sys.path.insert(0, str(Path(__file__).parent))
import ear  # noqa: E402
import foot  # noqa: E402
import hand  # noqa: E402
from geom import clean, smooth_d, zone_d  # noqa: E402
from zone_text import GROUPS, TEXT  # noqa: E402

DATA = Path(__file__).resolve().parents[2] / "Resources" / "Data"


def resolve(zones):
    """Earlier zones win overlaps; side zones only compete with shared zones and their own side."""
    taken = {None: [], "left": [], "right": []}
    out = []
    for z in zones:
        zid, g = z[0], z[1]
        side = z[2] if len(z) > 2 else None
        prior = taken[None] + (taken[side] if side else taken["left"] + taken["right"])
        if prior:
            g = g.difference(unary_union(prior))
        g = clean(g)
        taken[side].append(g)
        out.append((zid, g, side))
    return out


def zone_json(zid, side, path=None, circles=None):
    t = TEXT.get(zid)
    if t is None:
        print("missing text:", zid)
        t = (zid, zid, "head", [], "", "")
    name, name_zh, group, organs, effect, effect_zh = t
    z = {"id": zid, "name": name, "nameZh": name_zh}
    if path is not None:
        z["path"] = path
    if circles is not None:
        z["shapes"] = [{"cx": x, "cy": y, "rx": r, "ry": r} for x, y, r in circles]
        z["point"] = True
    z.update({"group": group, "organIds": organs, "effect": effect, "effectZh": effect_zh})
    if side:
        z["side"] = side
    return z


def face(fid, label, label_zh, drawn, sil, tones, guides, bones, zones, points=None):
    resolved = resolve(zones)
    out = [zone_json(zid, side, path=d) for zid, g, side in resolved if (d := zone_d(g))]
    for zid, circles in (points or {}).items():
        side = None
        if isinstance(circles, tuple):
            circles, side = circles
        out.append(zone_json(zid, side, circles=circles))
    have = {z["id"] for z in out}
    prefix = out[0]["id"].split("-")[0] + "-"
    for zid in TEXT:
        if zid.startswith(prefix) and zid not in have:
            print("dropped:", zid)
    order = {k: i for i, k in enumerate(TEXT)}
    out.sort(key=lambda z: order.get(z["id"], 1e9))
    outline = [{"kind": "path", "d": smooth_d(sil, 4)}] + [{"kind": "path", "d": smooth_d(g, 2.5 if t == "nail" else 6), "tone": t} for t, g in tones]
    return {"id": fid, "label": label, "labelZh": label_zh, "drawnSide": drawn, "outline": outline,
            "guides": guides, "bones": bones, "zones": out}


def build():
    old = json.loads((DATA / "charts.json").read_text())
    anchors = {c["id"]: c["anchors"] for c in old["charts"]}

    sil, thumb, tp, gp, tb, gb, bb = hand.build()
    hand_chart = {
        "id": "hand", "title": "Hand reflex zones", "titleZh": "手部反射区",
        "viewBox": [-10, 14, 320, 420], "mirrorWidth": 300, "labelSize": 9,
        "faces": [
            face("palm", "Palm", "掌", "left", sil, tp, gp, [], hand.palm_zones(sil, thumb)),
            face("back", "Back", "背", "right", sil, tb, gb, bb, hand.back_zones(sil, thumb), hand.BACK_POINTS),
        ],
        "anchors": anchors["hand"],
    }
    charts = [hand_chart]
    for mod in (ear, foot):
        if hasattr(mod, "chart"):
            c = mod.chart(face)
            c["anchors"] = anchors[c["id"]]
            charts.append(c)
        else:
            charts.append(next(c for c in old["charts"] if c["id"] == mod.__name__))
    order = ["hand", "ear", "foot"]
    charts.sort(key=lambda c: order.index(c["id"]))
    return {"groups": GROUPS, "charts": charts}


if __name__ == "__main__":
    data = build()
    text = json.dumps(data, ensure_ascii=False, indent=1)
    # same layout as scripts/gen_body.py, so its anchor rewrite leaves no diff
    text = re.sub(r"\[\s*(-?[\d.e-]+(?:,\s*-?[\d.e-]+)*)\s*\]", lambda m: "[" + ", ".join(x.strip() for x in m.group(1).split(",")) + "]", text)
    (DATA / "charts.json").write_text(text + "\n")
    for c in data["charts"]:
        for f in c["faces"]:
            sides = {s: len([z for z in f["zones"] if z.get("side") in (None, s)]) for s in ("left", "right")}
            print(c["id"], f["id"], sides)
