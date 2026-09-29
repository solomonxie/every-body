"""Render scene pictures in Blender: MakeHuman (MPFB2, CC0) people posed per step → build/art3d/<scene>/<style>/*.png

  Blender -b -P scripts/art3d/render.py -- <scene>[:<shot>…] … [style=ink|soft|toon] [close]
  e.g. cpr   cpr:adult   cpr:adult-3a   choking:infant-1   (MARKS=1 shows the overlay anchor points)
  then venv/bin/python scripts/art3d/pack.py (→ Resources/Illustrations/<scene>/*.webp + SceneMarks.swift)

Each scene module has SHOTS {variant: [step, …]} and shoot("<variant>-<step>", close).
"""

import importlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import kit  # noqa: E402

SCENES = ["cpr", "choking", "recovery", "stroke", "bleeding", "heart", "signs", "sickness", "sleep"]


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    kit.STYLE = next((a.split("=")[1] for a in args if a.startswith("style=")), "ink")
    close = "close" in args
    for arg in [a for a in args if "=" not in a and a != "close"] or SCENES:
        name, _, shot = arg.partition(":")
        scene = importlib.import_module(name)
        if "-" in shot:
            shots = [shot]
        else:
            shots = [f"{v}-{k}" for v in ([shot] if shot else scene.SHOTS) for k in scene.SHOTS[v]]
        for one in shots:
            scene.shoot(one, close=close)


main()
