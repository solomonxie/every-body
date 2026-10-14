"""3D body checkpoints: the cartesian product of testing/body-checkpoints.md's dimensions.

venv/bin/python testing/checkpoints.py [--count] [--filter SUBSTR ...] [--sample N]
"""
import argparse
import itertools
import random

HERITAGE = ["white", "black", "hispanic", "south-asian", "southeast-asian", "east-asian"]
# (sex, age); pregnant only as an adult woman
PERSON = [(s, a) for a in ["infant", "toddler", "child", "adult", "senior"] for s in ["female", "male"]
          if not (a == "infant" and s == "male")] + [("female", "pregnant")]
CLOTHING = ["dressed", "bare"]
SIZES = ["S", "M", "L", "XL", "XXL"]
VIEW = ["front", "back", "left", "right", "front-3q-left", "front-3q-right", "back-3q-left", "back-3q-right",
        "top-down", "low-up", "face-front", "face-side"]
POSE = ["rest", "back-30", "back-60", "back-90", "neck-turn-70", "shoulder-90", "shoulder-160", "elbow-90",
        "elbow-145", "knee-90", "knee-135", "back-60+shoulder-90", "back-90+elbow-90", "sitting"]


def shapes(sex, age):
    """chest × hips: adult women only; everyone else one shape"""
    return [f"{c}-{h}" for c in SIZES for h in SIZES] if (sex, age) == ("female", "adult") else ["base"]


def checkpoints():
    for her, (sex, age), wear in itertools.product(HERITAGE, PERSON, CLOTHING):
        for shape, view, pose in itertools.product(shapes(sex, age), VIEW, POSE):
            yield ".".join((her, sex, age, wear, shape, view, pose))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--count", action="store_true")
    ap.add_argument("--filter", nargs="*", default=[])
    ap.add_argument("--sample", type=int)
    a = ap.parse_args()
    ids = [c for c in checkpoints() if all(f in c for f in a.filter)]
    if a.sample:
        ids = random.sample(ids, min(a.sample, len(ids)))
    if a.count:
        print(len(ids))
    else:
        print("\n".join(ids))


if __name__ == "__main__":
    main()
