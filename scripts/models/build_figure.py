"""Skin figures (MakeHuman via MPFB2, CC0) → Resources/Models/figure.bin + skin/hair textures.

All MakeHuman humans share one topology, so every body (sex × age × heritage, pregnant) ships as positions
for the same meshes: one base per piece plus small int16 deltas, deflated. The app picks one and builds the mesh.
Heritage changes the head (face) and the skin texture only; the body shape is fixed per sex.
Children are fitted to the app's age reshaping (BodyScene.proportions) so bones and organs sit inside.

  Blender -b -P build_figure.py -- fit [group]   # MPFB humans → build/models/figure/*.npz
  venv/bin/python build_figure.py pack           # npz → figure.bin, garments, textures
"""

import json
import math
import sys
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from skin_textures import STYLIZED  # noqa: E402
from build_models import GEN, OUT, ROOT, TOP, SOLE, fitter, load_index, mesh_coords, save_index, to_scene  # noqa: E402

RAW = ROOT / "build" / "models" / "figure"
FIGURE = OUT / "figure.bin"

HERITAGES = {
    # id: (MakeHuman race macro, skin texture blend)
    "east-asian": ({"asian": 0.85, "caucasian": 0.15}, {"asian": 0.8, "caucasian": 0.2}),
    "southeast-asian": ({"asian": 0.7, "african": 0.15, "caucasian": 0.15}, {"asian": 0.62, "african": 0.38}),
    "south-asian": ({"caucasian": 0.5, "asian": 0.2, "african": 0.3}, {"asian": 0.42, "african": 0.58}),
    "hispanic": ({"caucasian": 0.6, "asian": 0.25, "african": 0.15}, {"caucasian": 0.5, "asian": 0.5}),
    "white": ({"caucasian": 1.0}, {"caucasian": 1.0}),
    "black": ({"african": 1.0}, {"african": 1.0}),
}
NEUTRAL = {"asian": 1 / 3, "caucasian": 1 / 3, "african": 1 / 3}
# MakeHuman age macro: 0 = 1 year, 0.1875 = 11, 0.5 = 25, 1 = 90
AGE = {"infant": 0.01, "toddler": 0.02, "child": 0.11, "adult": 0.5, "senior": 0.85}
BUILD = {
    # sex: (macros, extra targets)
    "male": ({"gender": 1.0, "muscle": 0.95, "weight": 0.56, "proportions": 0.9, "height": 0.6},
             {"torso/torso-vshape-incr": 0.35, "torso/torso-muscle-pectoral-incr": 0.25}),
    # the adult woman's default build
    "female": ({"gender": 0.0, "muscle": 0.55, "weight": 0.5, "proportions": 0.9, "height": 0.5, "cupsize": 0.82, "firmness": 0.74},
               {"hip/hip-scale-horiz-incr": 0.45, "buttocks/buttocks-volume-incr": 0.75, "torso/measure-hips-circ-incr": 0.3,
                "torso/measure-waist-circ-decr": 0.3,
                "breast/nipple-point-incr": 0.5, "breast/nipple-size-decr": 0.4}),
    # a child's chest
    "kid": ({"gender": 0.5, "muscle": 0.5, "weight": 0.6, "proportions": 0.5, "height": 0.5, "cupsize": 0.0, "firmness": 1.0},
            {"breast/nipple-size-decr": 0.6, "breast/nipple-point-decr": 0.25}),
}
# by (sex, age): changes to the sex's build
AGE_BUILD = {("female", "senior"): {"cupsize": 0.7, "firmness": 0.8}}
# adult body options, shipped as deltas from BUILD["female"] (the large chest)
_F_MACROS, _F_TARGETS = BUILD["female"]
_HIPS = ("hip/hip-scale-horiz-incr", "buttocks/buttocks-volume-incr", "torso/measure-hips-circ-incr")
# the lower body grows evenly with each size, small to the fullest (XXL = the old large width): wider hips, rounder
# fuller buttocks projecting further back (depth, a little set back) and lifted (pelvis tone)
_HIP_TARGETS = _HIPS + ("pelvis/pelvis-tone-incr", "hip/hip-scale-depth-incr", "hip/hip-trans-backward")
_HIP_RANGE = ((0.1, 0.1, 0.0, 0.0, 0.0, 0.0), (0.8, 1.0, 0.65, 0.7, 0.3, 0.12))
_hips = lambda t: {**_F_TARGETS, **{k: a + t * (b - a) for k, a, b in zip(_HIP_TARGETS, *_HIP_RANGE)}}
SHAPES = {
    "chest-small": ({**_F_MACROS, "cupsize": 0.15, "firmness": 0.85}, _F_TARGETS),
    "chest-medium": ({**_F_MACROS, "cupsize": 0.6}, _F_TARGETS),
    "chest-xlarge": ({**_F_MACROS, "cupsize": 1.0, "firmness": 0.45}, {**_F_TARGETS, "breast/breast-volume-vert-down": 0.2,
                                                                    "breast/nipple-size-decr": 0.9}),
    "chest-xxlarge": ({**_F_MACROS, "cupsize": 1.0, "firmness": 0.25},
                      {**_F_TARGETS, "breast/breast-volume-vert-down": 0.3, "breast/breast-dist-incr": 0.2,
                       "breast/nipple-size-decr": 0.9}),
    **{f"hips-{size}": (_F_MACROS, _hips(t)) for size, t in
       (("small", 0.0), ("medium", 0.25), ("large", 0.5), ("xlarge", 0.75), ("xxlarge", 1.0))},
}
# smoothing passes over the hips shapes' change about the waist
HIP_EASE = 40
# arm swing (radians, out from the body) that goes with a shape
ARM_OUT = {"hips-large": 0.03, "hips-xlarge": 0.065, "hips-xxlarge": 0.1}
# group: (sex build, age, hair styles (hair.STYLES), eyebrows, eyelashes)
GROUPS = {
    "male-adult": ("male", "adult", ["man"], "eyebrow012", "eyelashes02"),
    "female-adult": ("female", "adult", ["woman"], "eyebrow002", "eyelashes02"),
    "male-senior": ("male", "senior", ["man-senior"], "eyebrow012", "eyelashes02"),
    "kid-infant": ("kid", "infant", [], "eyebrow002", "eyelashes01"),
    "female-senior": ("female", "senior", ["woman-senior"], "eyebrow002", "eyelashes02"),
    "kid-toddler": ("kid", "toddler", ["boy-toddler", "girl-toddler"], "eyebrow002", "eyelashes01"),
    "kid-child": ("kid", "child", ["boy", "girl"], "eyebrow002", "eyelashes02"),
}
# a kid group's hairs, split by sex in pack
HAIR_SEX = {"boy": "male", "boy-toddler": "male", "girl": "female", "girl-toddler": "female", "rain-girl": "female", "rain-toddler": "female"}
# face modifiers (MakeHuman targets, CC0); cheek/eye targets apply to both sides. Both sexes get a modern profile:
# upright forehead, low brow ridge, mouth and jaw not pushed forward, a chin that holds.
FACE = {
    # defined, friendly: squarer jaw and chin, open eyes, straight nose
    "male": {"forehead/forehead-nubian-decr": 0.5, "forehead/forehead-scale-vert-incr": 0.2,
             "mouth/mouth-scale-depth-decr": 0.3, "mouth/mouth-trans-backward": 0.2,
             "chin/chin-width-incr": 0.3, "chin/chin-prominent-incr": 0.6, "chin/chin-height-incr": 0.25, "chin/chin-prognathism-incr": 0.2,
             "head/head-square": 0.1, "head/head-fat-decr": 0.6, "head/head-scale-horiz-decr": 0.1, "cheek/cheek-volume-decr": 0.45, "cheek/cheek-bones-incr": 0.2,
             "eyebrows/eyebrows-angle-up": 0.5, "eyes/eye-bag-decr": 0.5, "eyes/eye-scale-incr": 0.3, "eyes/eye-push1-out": 0.2,
             "nose/nose-point-width-decr": 0.5, "nose/nose-hump-decr": 0.4, "nose/nose-width1-decr": 0.3,
             "nose/nose-scale-horiz-decr": 0.25, "nose/nose-scale-vert-decr": 0.15, "nose/nose-flaring-decr": 0.3, "head/head-scale-vert-decr": 0.08,
             "mouth/mouth-lowerlip-middle-up": 0.3,
             "mouth/mouth-lowerlip-volume-decr": 0.3, "mouth/mouth-upperlip-volume-decr": 0.15, "mouth/mouth-scale-horiz-decr": 0.1, "mouth/mouth-angles-up": 0.2,
             "neck/measure-neck-circ-incr": 0.5},
    # female face targets
    "female": {"head/head-oval": 0.6, "head/head-fat-decr": 0.6, "head/head-scale-horiz-decr": 0.2, "chin/chin-width-decr": 0.35,
               "head/head-age-decr": 0.35, "mouth/mouth-laugh-lines-in": 0.4, "cheek/cheek-trans-up": 0.2,
               "chin/chin-prominent-incr": 0.75, "chin/chin-bones-decr": 0.5, "chin/chin-prognathism-incr": 0.4, "chin/chin-height-decr": 0.15,
               "cheek/cheek-bones-incr": 0.3, "cheek/cheek-volume-decr": 0.1, "forehead/forehead-nubian-decr": 0.6, "forehead/forehead-scale-vert-incr": 0.2,
               "eyebrows/eyebrows-angle-up": 0.9, "eyes/eye-scale-incr": 0.42, "eyes/eye-corner2-up": 0.35, "eyes/eye-height2-incr": 0.05,
               "eyes/eye-bag-decr": 0.5, "nose/nose-scale-horiz-decr": 0.3, "nose/nose-point-width-decr": 0.5, "nose/nose-point-up": 0.2,
               "nose/nose-width1-decr": 0.3, "nose/nose-volume-decr": 0.3, "mouth/mouth-upperlip-volume-decr": 0.15, "mouth/mouth-upperlip-height-incr": 0.2,
               "mouth/mouth-scale-depth-decr": 0.5, "mouth/mouth-upperlip-middle-down": 0.3, "mouth/mouth-upperlip-ext-down": 0.3, "mouth/mouth-lowerlip-volume-decr": 0.7,
               "mouth/mouth-lowerlip-height-decr": 0.3, "mouth/mouth-lowerlip-middle-up": 0.15, "mouth/mouth-cupidsbow-incr": 0.5, "mouth/mouth-angles-up": 0.45, "mouth/mouth-scale-horiz-decr": 0.25,
               "neck/measure-neck-circ-decr": 0.5, "mouth/mouth-trans-backward": 0.45},
    "kid": {"forehead/forehead-nubian-decr": 0.5, "eyebrows/eyebrows-angle-up": 0.4, "eyes/eye-bag-decr": 0.5,
            "mouth/mouth-angles-up": 0.3},
}
# each heritage keeps its own nose and lips: the narrowing targets are toned down where they'd erase them
FACE_SCALE = {"black": {"nose/": 0.2, "mouth/mouth-upperlip-volume": 0.3, "mouth/mouth-lowerlip-volume": 0.3, "mouth/mouth-upperlip-middle": 0.0, "mouth/mouth-cupidsbow": 0.3}, "southeast-asian": {"nose/": 0.5}, "east-asian": {"nose/": 0.6}, "south-asian": {"nose/": 0.8}}
# on top of the race macro: features typical of each heritage at natural strength (both sexes, every age)
HERITAGE_FACE = {
    "east-asian": {"nose/nose-scale-depth-decr": 0.2, "nose/nose-hump-decr": 0.3, "head/head-scale-horiz-incr": 0.05},
    "southeast-asian": {"eyes/eye-epicanthus-out": 0.35, "nose/nose-flaring-incr": 0.35, "nose/nose-scale-depth-decr": 0.3,
                        "mouth/mouth-lowerlip-volume-incr": 0.25, "head/head-scale-horiz-incr": 0.15},
    "south-asian": {"eyes/eye-scale-incr": 0.15, "nose/nose-point-down": 0.25, "nose/nose-scale-vert-incr": 0.2,
                    "eyebrows/eyebrows-trans-down": 0.15},
    "hispanic": {"nose/nose-hump-incr": 0.2, "cheek/cheek-bones-incr": 0.15, "nose/nose-flaring-incr": 0.15},
    "white": {"nose/nose-scale-depth-incr": 0.2, "nose/nose-width1-decr": 0.2, "eyes/eye-push1-in": 0.2},
    "black": {"nose/nose-flaring-incr": 0.5, "nose/nose-scale-horiz-incr": 0.35, "nose/nose-scale-depth-decr": 0.2,
              "mouth/mouth-upperlip-volume-incr": 0.1, "mouth/mouth-lowerlip-volume-incr": 0.1},
}

# per sex on top of HERITAGE_FACE (adults and seniors)
SEX_HERITAGE_FACE = {
    # this appearance's own look for women
    ("female", "east-asian"): {"head/head-round": 0.3, "head/head-scale-horiz-decr": 0.15, "cheek/cheek-bones-decr": 0.9,
                               "eyes/eye-scale-incr": 0.25, "eyes/eye-height2-incr": 0.3, "eyes/eye-epicanthus-out": -0.25,
                               "eyes/eye-eyefold-up": 0.3, "eyes/eye-push1-in": 0.1,
                               "eyebrows/eyebrows-trans-up": 0.15, "eyebrows/eyebrows-angle-up": 0.05,
                               "nose/nose-scale-horiz-decr": 0.2, "nose/nose-flaring-decr": 0.2, "nose/nose-point-width-decr": 0.2,
                               "mouth/mouth-cupidsbow-incr": 0.2},
    ("female", "southeast-asian"): {"eyebrows/eyebrows-trans-up": 0.3, "eyes/eye-epicanthus-out": -0.3, "eyes/eye-epicanthus-in": 0.1,
                                    "eyes/eye-push1-in": 0.25, "eyes/eye-scale-incr": 0.2, "nose/nose-scale-horiz-incr": 0.35, "nose/nose-flaring-incr": 0.25,
                                    "nose/nose-point-width-incr": 0.45, "nose/nose-scale-depth-decr": 0.3, "nose/nose-width1-incr": 0.35,
                                    "nose/nose-base-down": 0.15, "mouth/mouth-upperlip-volume-incr": 0.3, "mouth/mouth-lowerlip-volume-incr": 0.3,
                                    "mouth/mouth-scale-horiz-incr": 0.1, "head/head-round": 0.5, "cheek/cheek-volume-incr": 0.15,
                                    "cheek/cheek-trans-up": 0.15, "mouth/mouth-laugh-lines-in": 0.2,
                                    "cheek/cheek-bones-incr": 0.2, "chin/chin-height-decr": 0.1, "eyes/eye-height2-incr": 0.15,
                                    "eyebrows/eyebrows-angle-up": 0.1},
    ("female", "south-asian"): {"eyes/eye-scale-incr": 0.2, "eyes/eye-epicanthus-in": 0.3, "eyes/eye-height2-incr": 0.2,
                                "eyes/eye-push1-in": 0.25, "eyes/eye-corner1-down": 0.2, "eyebrows/eyebrows-trans-down": 0.15,
                                "eyebrows/eyebrows-trans-forward": 0.15, "nose/nose-scale-vert-incr": 0.25, "nose/nose-scale-depth-incr": 0.35,
                                "nose/nose-hump-incr": 0.2, "nose/nose-point-down": 0.15, "nose/nose-point-width-decr": 0.1,
                                "mouth/mouth-upperlip-volume-incr": 0.3, "mouth/mouth-lowerlip-volume-incr": 0.3, "mouth/mouth-cupidsbow-incr": 0.3,
                                "head/head-oval": 0.4, "chin/chin-height-incr": 0.15, "cheek/cheek-volume-incr": 0.35},
    ("female", "hispanic"): {"nose/nose-nostrils-width-decr": 0.15, "nose/nose-scale-horiz-decr": 0.1, "cheek/cheek-bones-incr": 0.3,
                             "mouth/mouth-upperlip-volume-incr": 0.25, "mouth/mouth-lowerlip-volume-incr": 0.35, "mouth/mouth-scale-horiz-incr": 0.1,
                             "eyes/eye-scale-incr": 0.15, "eyes/eye-height2-incr": 0.15, "eyes/eye-epicanthus-in": 0.1,
                             "eyebrows/eyebrows-angle-up": 0.2, "eyebrows/eyebrows-trans-down": 0.1, "head/head-oval": 0.3, "chin/chin-triangle": 0.15},
    ("female", "white"): {"nose/nose-nostrils-width-decr": 0.15},
    ("female", "black"): {"mouth/mouth-lowerlip-volume-decr": 0.25, "mouth/mouth-upperlip-volume-decr": 0.1, "nose/nose-flaring-incr": -0.4,
                          "nose/nose-scale-horiz-incr": -0.2, "nose/nose-nostrils-width-decr": 0.35, "nose/nose-point-width-decr": 0.3,
                          "nose/nose-width2-decr": 0.25},
    ("male", "southeast-asian"): {"eyes/eye-epicanthus-out": -0.2, "eyes/eye-scale-incr": 0.1, "eyes/eye-push1-in": 0.2,
                                  "nose/nose-scale-horiz-incr": 0.3, "nose/nose-flaring-incr": 0.2, "nose/nose-point-width-incr": 0.3,
                                  "nose/nose-width1-incr": 0.3, "mouth/mouth-upperlip-volume-incr": 0.3, "mouth/mouth-lowerlip-volume-incr": 0.3,
                                  "head/head-round": 0.3, "cheek/cheek-bones-incr": 0.2},
    ("male", "south-asian"): {"eyes/eye-scale-incr": 0.15, "eyes/eye-epicanthus-in": 0.3, "eyes/eye-push1-in": 0.25,
                              "eyebrows/eyebrows-trans-down": 0.15, "nose/nose-scale-vert-incr": 0.25, "nose/nose-scale-depth-incr": 0.3,
                              "nose/nose-hump-incr": 0.25, "nose/nose-point-down": 0.1, "mouth/mouth-upperlip-volume-incr": 0.2,
                              "mouth/mouth-lowerlip-volume-incr": 0.2, "head/head-oval": 0.3, "chin/chin-height-incr": 0.1},
}

# drawn-clean women's faces (skin_textures.STYLIZED), as changes to FACE["female"]: larger eyes, a small nose,
# the resting expression
STYLIZED_FACE = {"cheek/cheek-bones-decr": 0.15, "cheek/cheek-volume-decr": -0.3, "chin/chin-height-decr": 0.25,
                 "chin/chin-prognathism-incr": -0.4, "chin/chin-prominent-incr": -0.3, "chin/chin-width-incr": 0.1,
                 "eyes/eye-height2-incr": 0.2, "eyes/eye-scale-incr": 0.45, "head/head-fat-decr": 0.3,
                 "head/head-scale-horiz-decr": 0.25, "head/head-scale-vert-decr": 0.12, "mouth/mouth-cupidsbow-incr": -0.5,
                 "mouth/mouth-lowerlip-height-decr": 0.3, "mouth/mouth-lowerlip-volume-decr": 0.7, "mouth/mouth-scale-horiz-decr": -0.15,
                 "mouth/mouth-trans-backward": -0.2, "mouth/mouth-trans-up": 0.25, "mouth/mouth-upperlip-ext-down": -0.5,
                 "mouth/mouth-upperlip-height-decr": 0.3, "mouth/mouth-upperlip-height-incr": -0.3, "mouth/mouth-upperlip-middle-down": -0.5,
                 "mouth/mouth-upperlip-volume-decr": 0.6, "nose/nose-base-up": 0.2,
                 "nose/nose-greek-decr": 0.3, "nose/nose-hump-decr": 0.5, "nose/nose-point-width-decr": 0.3,
                 "nose/nose-scale-horiz-decr": 0.2, "nose/nose-scale-vert-decr": 0.25}
# resting face: upper lids a little lowered over the iris, lips together, the corners lifted into a faint smile
EXPRESSION = {"female": {"eye-closure": 0.12, "mouth-compression": 0.15, "mouth-corner-puller": 0.1},
              "male": {"mouth-compression": 0.3, "mouth-corner-puller": 0.12},
              "kid": {"eye-closure": 0.15, "mouth-compression": 0.35, "mouth-corner-puller": 0.2}}
# a child's face targets
_CHILD_FACE = {"head/head-fat-decr": 0.2, "head/head-round": 0.15, "cheek/cheek-volume-decr": 0.15,
               "chin/chin-prominent-incr": 0.25, "chin/chin-width-decr": 0.2, "chin/chin-height-decr": 0.1,
               "eyes/eye-scale-incr": 0.2, "eyes/eye-height2-incr": 0.1, "eyebrows/eyebrows-angle-up": -0.2,
               "nose/nose-scale-vert-decr": 0.2, "nose/nose-scale-depth-decr": 0.15, "nose/nose-scale-horiz-decr": 0.1,
               "nose/nose-point-up": 0.2, "nose/nose-hump-decr": 0.3,
               "mouth/mouth-lowerlip-volume-decr": 0.65, "mouth/mouth-upperlip-volume-decr": 0.4, "mouth/mouth-scale-horiz-decr": 0.3,
               "mouth/mouth-scale-vert-decr": 0.2, "mouth/mouth-scale-depth-decr": 0.4, "mouth/mouth-trans-backward": 0.15}
# a baby's face targets
_INFANT_FACE = {"eyebrows/eyebrows-angle-up": -0.4, "forehead/forehead-nubian-decr": -0.5, "mouth/mouth-angles-up": -0.3,
                "eyes/eye-bag-decr": -0.5,
                "forehead/forehead-nubian-incr": 0.2, "forehead/forehead-scale-vert-incr": 0.1, "head/head-round": 0.3, "head/head-fat-incr": 0.05,
                "head/head-scale-vert-decr": 0.15, "head/head-scale-horiz-incr": 0.1,
                "eyes/eye-scale-incr": 0.2, "eyes/eye-trans-out": 0.2, "eyes/eye-height2-incr": 0.2, "eyes/eye-eyefold-down": 0.4,
                "nose/nose-scale-vert-decr": 0.3, "nose/nose-point-up": 0.25, "nose/nose-point-width-incr": 0.2,
                "nose/nose-width1-incr": 0.3, "nose/nose-greek-incr": 0.15, "nose/nose-hump-incr": 0.35, "nose/nose-curve-convex": 0.3,
                "mouth/mouth-scale-horiz-decr": 0.3, "mouth/mouth-scale-depth-decr": 0.2, "mouth/mouth-upperlip-volume-incr": 0.05,
                "mouth/mouth-lowerlip-volume-incr": 0.05,
                "cheek/cheek-volume-incr": 0.1,
                "chin/chin-prominent-decr": 0.4, "chin/chin-height-decr": 0.25,
                "ears/ear-trans-down": 0.3}
# a toddler's: most of the baby's face still, the eyes bigger and the chin a little further along
_TODDLER_FACE = {**{t: w * 0.65 for t, w in _INFANT_FACE.items()},
                 "eyes/eye-scale-incr": 0.3, "eyes/eye-height2-incr": 0.25, "eyes/eye-trans-out": 0.15,
                 "chin/chin-prominent-decr": 0.2, "chin/chin-height-decr": 0.15, "head/head-round": 0.3,
                 "cheek/cheek-volume-incr": 0.15, "mouth/mouth-scale-horiz-decr": 0.3, "nose/nose-scale-vert-decr": 0.3}
KID_FACE = {"child": _CHILD_FACE, "toddler": _TODDLER_FACE, "infant": _INFANT_FACE}
# a baby's and a toddler's face at rest (the 'kid' expression is a child's slight smile)
EXPRESSION_AGE = {"infant": {"eye-closure": 0.05}, "toddler": {"eye-closure": 0.06, "mouth-compression": 0.15},
                  "child": {"eye-closure": 0.1, "mouth-compression": 0.3, "mouth-corner-puller": 0.05}}


def face_targets(sex, age, heritage=None):
    """face modifier targets for this sex/age/heritage; a senior's are softened, a child's heritage features too"""
    out = {}

    def add(t, w):
        d, name = t.split("/")
        for n in [f"l-{name}", f"r-{name}"] if d in ("cheek", "eyes", "ears") else [name]:
            out[f"{d}/{n}"] = out.get(f"{d}/{n}", 0) + w
    for t, w in FACE[sex].items():
        w *= 0.7 if age == "senior" else 1.0
        for pre, s in FACE_SCALE.get(heritage, {}).items():
            if t.startswith(pre):
                w *= s
        add(t, w)
    for t, w in HERITAGE_FACE.get(heritage, {}).items():
        add(t, w * (0.6 if sex == "kid" else 1.0))
    for t, w in SEX_HERITAGE_FACE.get((sex, heritage), {}).items():
        add(t, w)
    if sex == "female" and heritage in STYLIZED:
        for t, w in STYLIZED_FACE.items():
            add(t, w * (0.7 if age == "senior" else 1.0))
    for t, w in KID_FACE.get(age, {}).items():
        add(t, w)
    # expression units (per race set): both eyes / the mouth
    units = "african" if heritage == "black" else "asian" if heritage in ("east-asian", "southeast-asian") else "caucasian"
    for t, w in EXPRESSION_AGE.get(age, EXPRESSION.get(sex, {})).items():
        if t == "mouth-compression" and sex == "female" and heritage in STYLIZED:
            continue
        for n in ([t.replace("eye-", "eye-left-"), t.replace("eye-", "eye-right-")] if t.startswith("eye-") else [t]):
            out[f"expression/units/{units}/{n}"] = w * (0.7 if age == "senior" else 1.0)
    return {t: min(w, 1.0) for t, w in out.items()}


PREGNANT = {"stomach/stomach-pregnant-incr": 1.0, "stomach/stomach-navel-out": 0.6}
# MakeHuman's full "pregnant" is about 30 weeks: the bump is scaled up to term (fundus under the ribs)
PREGNANT_GAIN = 1.45

# BodyScene.proportions / reshape, mirrored: children's bodies are reshaped adults
PROPS = {  # body, head, leg length, leg girth, arm length, arm girth, trunk width, trunk depth, neck
    "infant": (0.4, 1.85, 0.72, 1.4, 0.85, 1.3, 1.12, 1.3, 0.3),
    "toddler": (0.5, 1.5, 0.82, 1.25, 0.9, 1.2, 1.08, 1.2, 0.45),
    "child": (0.68, 1.25, 0.95, 1.05, 0.97, 1.05, 1.0, 1.05, 0.75),
}
CHIN_Y, NECK_BASE_Y, LEG_TOP = 1.25, 1.05, -0.04
# a baby's skin head sits lower and further back on the (scaled adult) skull than the landmarks alone put it
HEAD_SHIFT = {"infant": (0.0, -0.025, -0.035), "toddler": (0.0, -0.015, -0.02)}
# MakeHuman's skull base sits higher in the head than the skeleton's: mapped piecewise at it, the face stretches above
# (tall eyes and brow) and squashes below (wide jaw); evened out this much, the eyes stay close to the orbits
HEAD_EVEN = 0.6
# adults' heads move as one piece instead (no warp at all): eyes at the skull's orbits, set back a little onto it
HEAD_RIGID = {"female": (1.45, 0.0), "male": (1.45, 0.0)}
# a child's rigid head reaches this far below the neck landmark (of the neck-to-crown height): below the chin
KID_HEAD_BASE = 0.5
# the short neck zone between the shoulders and that base is squashed about twice as much as the trunk: its height map
# bends over these half-bands (source metres) at the shoulders and at the head base, not at a line (fitter soften)
NECK_SOFTEN = {"infant": (0.022, 0.008), "toddler": (0.022, 0.008), "child": (0.024, 0.01)}
HIP, SHOULDER =(0.167, 0.12, 0.0), (0.344, 1.004, -0.056)


def reshape(p, age):
    """adult body point → the same point on this age's body (before the overall scale), as BodyScene.agePoint"""
    if age not in PROPS:
        return tuple(p)
    _, head, leg_l, leg_g, arm_l, arm_g, tw, td, neck = PROPS[age]
    x, y, z = p

    def about(c, s):
        return tuple(c[i] + (p[i] - c[i]) * s[i] for i in range(3))
    side = -1 if x < 0 else 1
    if y > CHIN_Y:
        return (x * head, NECK_BASE_Y + (CHIN_Y - NECK_BASE_Y) * neck + (y - CHIN_Y) * head, z * head)
    if abs(x) > 0.316:
        return about((SHOULDER[0] * side, SHOULDER[1], SHOULDER[2]), (arm_g, arm_l, arm_g))
    if y < LEG_TOP:
        return about((HIP[0] * side, HIP[1], HIP[2]), (leg_g, leg_l, leg_g))
    if y > NECK_BASE_Y:
        return (x * tw, NECK_BASE_Y + (y - NECK_BASE_Y) * neck, z * td)
    return (x * tw, y, z * td)


# ------------------------------------------------------------------ Blender: fit MPFB humans


LIMB_BONES = [(r"upperarm0[12]", "uparm"), (r"lowerarm01", "fore1"), (r"lowerarm02", "fore2"),
              (r"(wrist|metacarpal|finger)", "hand"), (r"upperleg0[12]", "thigh"), (r"lowerleg0[12]", "shin"),
              (r"(foot|toe)", "foot")]


def bone_segment(name):
    import re
    m = re.match(r"(.+)\.([LR])$", name)
    if not m:
        return "trunk"
    for pat, seg in LIMB_BONES:
        if re.match(pat, m[1]):
            return f"{seg}-{m[2].lower()}"
    return "trunk"


def fit_all(only=None):
    import numpy as np
    RAW.mkdir(parents=True, exist_ok=True)
    for gid, (sex, age, hairs, brows, lashes) in GROUPS.items():
        if only and gid != only:
            continue
        # heritage and pregnancy builds reuse the neutral body's fit (heads aligned at the skull base):
        # the same map for every variant, and a child's odd landmarks can't fold the mesh
        look = (hairs, brows, lashes)
        for old in (RAW / "prefit").glob(f"{gid}.*.npz"):
            old.unlink()
        pieces, topo, ref = fit_one(np, sex, age, NEUTRAL, face_targets(sex, age), look)
        save_raw(np, f"{gid}.neutral", pieces, topo)
        for rid, (race, _) in HERITAGES.items():
            pieces, topo, _ = fit_one(np, sex, age, race, face_targets(sex, age, rid), look, ref)
            save_raw(np, f"{gid}.{rid}", pieces, topo)
        if gid == "female-adult":
            pieces, topo, _ = fit_one(np, sex, age, NEUTRAL, {**face_targets(sex, age), **PREGNANT}, look, ref)
            save_raw(np, f"{gid}.pregnant", pieces, topo)
            for name, (macros, targets) in SHAPES.items():
                pieces, topo, _ = fit_one(np, sex, age, NEUTRAL, face_targets(sex, age), look, ref, build=(macros, targets))
                save_raw(np, f"{gid}.shape-{name}", {"body": pieces["body"]}, {})


def sculpt_hair(np, gid):
    """(after face_fit.py) the group's sculpted hair styles: strands grown on its neutral figure as round tubes, fused into one solid
    (voxel remesh), smoothed and thinned → RAW sculpt.<style>.npz (Blender)"""
    import bpy
    import hair
    import os
    names = {n for her in HERITAGES for n in hair.styles_for(GROUPS[gid][2], her) if hair.STYLES[n].get("sculpt")}
    if os.environ.get("HAIR_STYLE"):
        names &= set(os.environ["HAIR_STYLE"].split(","))
    if not names:
        return
    got = {k[4:]: v.astype(np.float64) for k, v in np.load(RAW / f"{gid}.neutral.npz").items()}
    t = np.load(RAW / "topo.body.npz")
    tris = t["vmap"][t["index"].reshape(-1, 3)]
    for name in sorted(names):
        cfg = hair.STYLES[name]["sculpt"]
        style = {**hair.STYLES[name], **cfg.get("style", {})}
        head, strands, lengths, layer, edge = hair.grown(np, np.random.default_rng(7), style, got["body"], got["eyes"], tris)
        U = head.U
        cu = bpy.data.curves.new(name, "CURVE")
        cu.dimensions = "3D"
        cu.bevel_depth = U
        cu.bevel_resolution = 2
        cu.use_fill_caps = True
        # finer at the hairline and on short (tapered) hair: a soft edge, close-cut sides
        k = (1 - cfg.get("edge", 0.5) * edge) * (1 - cfg.get("short", 0.0) * (1 - smoothstep(1.0, 4.0, lengths)))
        if style.get("part_line"):
            # a groove along the part: thinner tubes either side of it, on top of the head and back from the hairline
            y0, _, _ = head.local(strands[:, 0])
            d = np.abs(strands[:, 0, 0] - style["part"] * 5.5 * U) / U
            inside = head.scalp(strands[:, 0] + np.array([0, 0, 1.5 * U]), style.get("recede", 0.0), style.get("sideburns", True), style.get("ear"))
            k = k * (1 - 0.6 * (1 - smoothstep(0.2, 0.6, d)) * smoothstep(3.0, 6.0, y0) * inside * (strands[:, 0, 2] > head.C[2] - 3 * U))
        locks, lock = (front_locks(np, head, strands) if cfg.get("locks") else (strands, np.zeros(len(strands), bool)))
        # the face-framing locks are finer than the mass behind them
        k = k * np.where(lock, cfg.get("lock_thin", 0.4), 1.0)
        if cfg.get("trim"):
            # short cuts start and end inside the hairline (the rim lines make the edge: no rounded tube ends along it)
            inside = lambda s: head.scalp(s, style.get("recede", 0.0), style.get("sideburns", True), style.get("ear")) > cfg["trim"]

            def clip(s):
                ins = inside(s)
                if not ins.any():
                    return s[:2]
                a = int(np.argmax(ins))
                b = a + int(np.argmin(np.append(ins[a + 1:], False))) + 1
                return s[a:max(b, a + 2)]
            locks = [clip(s) for s in locks]
        tubes = [(s, cfg["root"] * q, cfg["tip"] * q) for s, q in list(zip(locks, k))[::cfg["every"]]]
        if cfg.get("taper"):
            # close-cut sides and nape: thinning toward the lower hairline
            thin = lambda s: 0.45 + 0.55 * head.scalp(s - cfg["taper"] * U * np.array([0, 1, 0]), style.get("recede", 0.0), style.get("sideburns", True), style.get("ear"))
            tubes = [(s, r0 * thin(s), r1 * thin(s)) for s, r0, r1 in tubes]
        if cfg.get("bangs"):
            b = cfg["bangs"]
            tubes += [(s, b["radius"], b["radius"] * 0.5) for s in hair.bangs(np, np.random.default_rng(3), head, b)]
        if cfg.get("pigtails"):
            b = cfg["pigtails"]
            tubes += [(s, b["radius"], b["radius"] * 0.4) for s in hair.pigtails(np, np.random.default_rng(5), head, b)]
        tubes = [(s, r0, r1, 0.35) for s, r0, r1 in tubes]
        if cfg.get("rim"):
            # an even edge along the hairline: a band of lines just inside it, thin at the edge and filling out inward
            for inset in np.arange(0.3, 1.9, 0.3):
                line = head.rim(np, style, inset)
                r = cfg["rim"] * (0.6 + 0.4 * smoothstep(0.3, 1.5, inset))
                tubes.append((line + head.depth(np, line)[1] * style["base"] * U, r, r, 1.0))
        for s, r0, r1, root in tubes:
            f = np.linspace(0, 1, len(s))
            # thin at the root (a soft hairline), full a little way out, tapering to the tip
            r = (r0 + (r1 - r0) * f ** 1.5) * (root + (1 - root) * smoothstep(0.0, 0.12, f))
            sp = cu.splines.new("POLY")
            sp.points.add(len(s) - 1)
            for i, q in enumerate(s):
                sp.points[i].co = (*q, 1)
                sp.points[i].radius = r[i]
        ob = bpy.data.objects.new(name, cu)
        bpy.context.scene.collection.objects.link(ob)
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
        mo = bpy.data.objects.new(name + "-mesh", me)
        bpy.context.scene.collection.objects.link(mo)
        rm = mo.modifiers.new("remesh", "REMESH")
        rm.mode, rm.voxel_size = "VOXEL", cfg.get("voxel", 0.2) * U
        sm = mo.modifiers.new("smooth", "SMOOTH")
        sm.iterations, sm.factor = cfg.get("smooth", 40), 1.0
        cs = mo.modifiers.new("relax", "LAPLACIANSMOOTH")
        cs.iterations, cs.lambda_factor = 20, 0.8
        if cfg.get("bumps"):
            # coils: a soft lumpy surface (noise along the normal), not a smooth cap
            amp, size = cfg["bumps"]
            tex = bpy.data.textures.new(name + "-bumps", "CLOUDS")
            tex.noise_scale, tex.noise_depth = size * U, 1
            dp = mo.modifiers.new("bumps", "DISPLACE")
            dp.texture, dp.direction, dp.mid_level, dp.strength = tex, "NORMAL", 0.5, amp * U
        dc = mo.modifiers.new("decimate", "DECIMATE")
        dc.ratio = cfg.get("decimate", 0.25)
        dg = bpy.context.evaluated_depsgraph_get()
        out = bpy.data.meshes.new_from_object(mo.evaluated_get(dg))
        out.calc_loop_triangles()
        pos = np.array([v.co[:] for v in out.vertices])
        tri = np.array([lt.vertices[:] for lt in out.loop_triangles])
        pos, tri = main_pieces(np, pos, tri)
        np.savez_compressed(RAW / f"sculpt.{name}.npz", pos=pos.astype(np.float32), tri=tri.astype(np.uint32))
        print("FIGURE sculpt", name, len(pos), len(tri))
        for o in (ob, mo):
            bpy.data.objects.remove(o)


def main_pieces(np, pos, tri, least=0.05):
    """the mesh without its small loose bits (stray locks the smoothing cut off)"""
    lab = np.arange(len(pos))
    a, b = np.concatenate([tri[:, 0], tri[:, 1], tri[:, 2]]), np.concatenate([tri[:, 1], tri[:, 2], tri[:, 0]])
    while True:
        m = np.minimum(lab[a], lab[b])
        new = lab.copy()
        np.minimum.at(new, a, m)
        np.minimum.at(new, b, m)
        new = new[new]
        if (new == lab).all():
            break
        lab = new
    size = np.bincount(lab, minlength=len(pos))
    keep = size[lab] >= least * len(pos)
    remap = np.cumsum(keep) - 1
    return pos[keep], remap[tri[keep[tri].all(1)]]


def front_locks(np, head, strands):
    """long strands in front of the ears end about the jaw (a face-framing layer, its ends staggered), not falling
    over the shoulders; returns the strands and which were cut"""
    U, out, cut = head.U, [], []
    ends = head.eye[1] - (12.5 + np.random.default_rng(9).uniform(-1.5, 1.5, len(strands))) * U
    for s, jaw in zip(strands, ends):
        front = (s[:, 2] > head.C[2] + 1.0 * U) & (s[:, 1] < jaw)
        if front.any():
            s = s[:max(int(np.argmax(front)), 2)]
        out.append(s)
        cut.append(bool(front.any()))
    return out, np.array(cut)


def save_raw(np, name, pieces, topo):
    np.savez_compressed(RAW / f"{name}.npz", **{f"pos:{k}": v for k, v in pieces.items()})
    for k, (uv, vmap, index, poly) in topo.items():
        old = RAW / f"topo.{k}.npz"
        if old.exists():
            was = np.load(old)["index"]
            if was.shape != index.shape or (was != index).any():
                print(f"FIGURE WARNING: {k} topology changed at {name} (every group needs refitting)")
        np.savez_compressed(old, uv=uv, vmap=vmap, index=index, poly=poly)
    print("FIGURE", name, {k: len(v) for k, v in pieces.items()})


def fit_one(np, sex, age, race, extra, look, ref=None, build=None):
    import importlib
    import os
    import bpy

    def imp(pkg, key):
        for m in list(sys.modules):
            if m.endswith(pkg):
                return getattr(importlib.import_module(m), key)
        raise ImportError(pkg)

    HumanService = imp("mpfb.services.humanservice", "HumanService")
    AssetService = imp("mpfb.services.assetservice", "AssetService")
    TargetService = imp("mpfb.services.targetservice", "TargetService")
    LocationService = imp("mpfb.services.locationservice", "LocationService")

    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)
    macros, targets = build or BUILD[sex]
    macros = {**macros, **AGE_BUILD.get((sex, age), {})}
    m = TargetService.get_default_macro_info_dict()
    m.update(macros, age=AGE[age])
    # exact 0 / 1 race weights on a baby collapse the mesh in MPFB: keep a trace of every race
    total = sum(max(race.get(r, 0), 0.02) for r in ("asian", "caucasian", "african"))
    m["race"] = {r: max(race.get(r, 0), 0.02) / total for r in ("asian", "caucasian", "african")}
    h = HumanService.create_human(macro_detail_dict=m)
    for t, w in {**targets, **extra}.items():
        TargetService.load_target(h, os.path.join(LocationService.get_mpfb_data("targets"), t + ".target.gz"), weight=w)
    rig = HumanService.add_builtin_rig(h, "default")
    hairs, brows, lashes = look
    assets = [("eyes", "low-poly.mhclo", "Eyes", "eyes"), ("eyebrows", f"{brows}.mhclo", "Eyebrows", f"brows-{brows}"),
              ("eyelashes", f"{lashes}.mhclo", "Eyelashes", f"lashes-{lashes}")]
    objs = {"body": h}
    for sub, f, kind, key in assets:
        before = set(bpy.data.objects)
        HumanService.add_mhclo_asset(AssetService.find_asset_absolute_path(f, asset_subdir=sub), h, asset_type=kind, subdiv_levels=0)
        objs[key] = next(iter(set(bpy.data.objects) - before))
    bones = {b.name: b for b in rig.data.bones}
    W = lambda n: to_scene(np, np.array([rig.matrix_world @ bones[n].head_local]))[0]
    Wt = lambda n: to_scene(np, np.array([rig.matrix_world @ bones[n].tail_local]))[0]
    src = {"neck": W("head")}
    for side, S in (("l", "L"), ("r", "R")):
        src.update({f"shoulder-{side}": W(f"upperarm01.{S}"), f"elbow-{side}": W(f"lowerarm01.{S}"),
                    f"wrist-{side}": W(f"wrist.{S}"), f"finger-{side}": Wt(f"finger3-3.{S}"),
                    f"hip-{side}": W(f"upperleg01.{S}"), f"knee-{side}": W(f"lowerleg01.{S}"),
                    f"ankle-{side}": W(f"foot.{S}"), f"toe-{side}": Wt(f"toe1-2.{S}"),
                    f"lateral-{side}": W(f"finger2-1.{S}") - W(f"finger5-1.{S}")})
    dg = bpy.context.evaluated_depsgraph_get()
    meshes = {}
    for key, o in objs.items():
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
        me.transform(o.matrix_world)
        if key == "body":
            refine_chest(np, me, o)
        meshes[key] = (o, me)
    body_raw = to_scene(np, mesh_coords(np, meshes["body"][1]))
    if os.environ.get("FIGURE_DEBUG"):
        print("FIGURE src", age, {k: np.round(v, 3).tolist() for k, v in src.items() if k[-1] != "r"}, round(body_raw[:, 1].max(), 3), round(body_raw[:, 1].min(), 3))
        print("FIGURE target", age, age_target(np, src, body_raw[:, 1].max(), age))
    src["eye"] = to_scene(np, mesh_coords(np, meshes["eyes"][1])).mean(0)
    shift = np.zeros(3)
    if ref is None:
        ref = (src, body_raw[:, 1].max(), body_raw[:, 1].min())
    else:
        shift = ref[0]["neck"] - src["neck"]
    rsrc, rtop, rsole = ref
    head = None
    target = age_target(np, rsrc, rtop, age)
    if age in PROPS:
        # a child's head scales as one piece too, as wide and deep as tall (no flattened crown or occiput): its height
        # and eyes as the evened-out map puts them
        even = fitter(np, rsrc, rtop, rsole, "skin", head_even=HEAD_EVEN, **target)[0]
        (_, top_y, _), (_, eye_y, _) = even(np.array([[0, rtop, 0], rsrc["eye"]]), "trunk")
        k = (top_y - eye_y) / (rtop - rsrc["eye"][1])
        target["widths"] = target["widths"][:2] + [(k, k), (k, k)]
        head = (rsrc["neck"][1] - KID_HEAD_BASE * (rtop - rsrc["neck"][1]), rsrc["eye"][1], eye_y, 0.0, k)
    elif sex in HEAD_RIGID:
        eye_y, dz = HEAD_RIGID[sex]
        head = (rsrc["neck"][1] - 0.1, rsrc["eye"][1], eye_y, dz)
    fit = fitter(np, rsrc, rtop, rsole, "skin", head_even=HEAD_EVEN, head=head, **target)[0]

    pieces, topo = {}, {}
    for key, (o, me) in meshes.items():
        raw = to_scene(np, mesh_coords(np, me)) + shift
        groups = {g.index: bone_segment(g.name) for g in o.vertex_groups if g.name in bones}
        keys = sorted(set(groups.values()) | {"trunk"})
        wts = np.zeros((len(me.vertices), len(keys)))
        for v in me.vertices:
            for g in v.groups:
                if g.group in groups and g.weight > 0:
                    wts[v.index, keys.index(groups[g.group])] += g.weight
        wts[wts.sum(1) == 0, keys.index("trunk")] = 1
        wts /= wts.sum(1, keepdims=True)
        if key == "body":
            # the rig's weights aren't quite mirrored (a crease under one side of the jaw): evened out
            twin = mirror_map(np, raw)
            swap = [keys.index(k[:-1] + {"l": "r", "r": "l"}[k[-1]]) if k[-2:] in ("-l", "-r") else i for i, k in enumerate(keys)]
            paired = twin != np.arange(len(twin))
            wts[paired] = (wts[paired] + wts[twin[paired]][:, swap]) / 2
            ears = np.zeros(len(me.vertices), np.float32)
            g_ear = o.vertex_groups.get("ears")
            if g_ear is not None:
                for v in me.vertices:
                    if any(g.group == g_ear.index for g in v.groups):
                        ears[v.index] = 1
            np.savez_compressed(RAW / "body-groups.npz", mirror=twin.astype(np.uint32), ears=ears)
        if age in PROPS and key == "body":
            # a child's trunk and limb maps differ: MakeHuman's speckled low weights (an arm's on the back) would
            # print as ridges, so the blend is spread over the mesh
            wts = diffuse(np, wts, np.array([e.vertices[:] for e in me.edges]), WEIGHT_SPREAD)
        out = np.zeros_like(raw)
        for i, k in enumerate(keys):
            sel = wts[:, i] > 0
            if sel.any():
                out[sel] += fit(raw[sel], k) * wts[sel, i:i + 1]
        if age in HEAD_SHIFT:
            sh, nk = reshape(GEN["shoulder"], age)[1], reshape(GEN["neck"], age)[1]
            t = np.clip((out[:, 1] - sh) / (nk - sh), 0, 1)
            out += (t * t * (3 - 2 * t))[:, None] * np.array(HEAD_SHIFT[age])
        if key == "body" and sex in CLOSE_LIPS:
            out = close_lips(np, out, lip_weights(np, o, me), CLOSE_LIPS[sex])
        pieces[key] = out.astype(np.float32)
        topo[key] = topology(np, me)
        if key == "body" and age == "adult" and sex == "female" and ref[0] is src:
            # the arms, kept out of the garments
            arms = [g.name for g in o.vertex_groups if g.name.startswith(("upperarm", "lowerarm", "wrist", "finger", "metacarpal"))]
            regions = {"arms": arms}
            gi = {g.name: g.index for g in o.vertex_groups}
            masks = {k: np.zeros(len(me.vertices), np.float32) for k in regions}
            for v in me.vertices:
                for g in v.groups:
                    for k, names in regions.items():
                        if g.group in (gi.get(n) for n in names):
                            masks[k][v.index] = max(masks[k][v.index], g.weight)
            np.savez_compressed(RAW / "regions.npz", **masks)
    if age in PROPS:
        pieces["body"] = flat_nipples(np, pieces["body"].astype(np.float64), topo["body"], age).astype(np.float32)
    if age in CRANIUM:
        edges = np.array([e.vertices[:] for e in meshes["body"][1].edges])
        pieces["body"] = round_cranium(np, pieces["body"].astype(np.float64), pieces["eyes"].mean(0), CRANIUM[age], edges).astype(np.float32)
    return pieces, topo, ref


def mirror_map(np, p, step=1e-3, tol=2e-4):
    """each vertex's twin across x = 0 (itself where none lies within tol): the mesh is symmetric before the fit"""
    q = np.round(p / step).astype(np.int64)
    cells = {}
    for i, k in enumerate(map(tuple, q)):
        cells.setdefault(k, []).append(i)
    twin = np.arange(len(p))
    m = q * np.array([-1, 1, 1])
    pm = p * np.array([-1, 1, 1])
    for i in range(len(p)):
        x0, y0, z0 = m[i]
        near = [j for dx in (0, -1, 1) for dy in (0, -1, 1) for dz in (0, -1, 1) for j in cells.get((x0 + dx, y0 + dy, z0 + dz), ())]
        if near:
            d = np.abs(p[near] - pm[i]).max(1)
            k = int(np.argmin(d))
            if d[k] < tol:
                twin[i] = near[k]
    return twin


WEIGHT_SPREAD = 20


def diffuse(np, w, edges, passes):
    """per-vertex weights averaged with their neighbours' `passes` times (rows still sum to 1)"""
    n = np.bincount(edges.ravel(), minlength=len(w)).astype(np.float64)[:, None]
    for _ in range(passes):
        acc = np.zeros_like(w)
        np.add.at(acc, edges[:, 0], w[edges[:, 1]])
        np.add.at(acc, edges[:, 1], w[edges[:, 0]])
        w = 0.5 * w + 0.5 * acc / np.maximum(n, 1)
    return w / w.sum(1, keepdims=True)


# lips together: the gap between them squeezed shut (strength, band in scene units); the lower lip's top is tucked
# under the upper lip after the face fit (face_fit.tuck_lips)
CLOSE_LIPS = {"female": (1.0, 0.005)}


def lip_weights(np, o, me):
    """per vertex: upper-lip and lower-lip weights (MakeHuman's oris bones)"""
    upper, lower = ("oris03", "oris05"), ("oris01", "oris07")
    gi = {g.index: g.name for g in o.vertex_groups}
    w = np.zeros((len(me.vertices), 2))
    for v in me.vertices:
        for g in v.groups:
            n = gi.get(g.group, "")
            if n.startswith(upper):
                w[v.index, 0] = max(w[v.index, 0], g.weight)
            elif n.startswith(lower):
                w[v.index, 1] = max(w[v.index, 1], g.weight)
    return w


def close_lips(np, p, w, shape):
    k, band = shape
    up, lo = w[:, 0] > 0.3, w[:, 1] > 0.3
    lip = w.max(1)
    half = np.abs(p[up | lo, 0]).max()
    bins = np.linspace(-half, half, 25)
    xs, seam = [], []
    for a, b in zip(bins[:-1], bins[1:]):
        u = up & (p[:, 0] >= a) & (p[:, 0] < b)
        l = lo & (p[:, 0] >= a) & (p[:, 0] < b)
        if u.any() and l.any():
            # the lips' front surfaces only (not the lining inside the mouth)
            uf = u & (p[:, 2] > p[u, 2].max() - 0.008)
            lf = l & (p[:, 2] > p[l, 2].max() - 0.008)
            xs.append((a + b) / 2)
            seam.append((p[uf, 1].min() + p[lf, 1].max()) / 2)
    y0 = np.interp(p[:, 0], xs, seam)
    inside = np.abs(p[:, 0]) < half
    d = p[:, 1] - y0
    t = np.clip(np.abs(d) / band, 0, 1)
    near = 1 - t * t * (3 - 2 * t)
    out = p.copy()
    out[:, 1] = y0 + d * (1 - k * near * np.clip(lip * 2, 0, 1) * inside)
    return out


# a child's chest relief: (height, radius) in scene units before the app's age scale
NIPPLE_DOME = {"child": (0.0025, 0.012)}
# round each chest centre (scene units): the chest is re-laid this far out (MakeHuman's relief reaches ~0.03), on a quadric
# fitted to the ring this much wider
NIPPLE_FLUSH, NIPPLE_RING = 0.05, 0.03


def flat_nipples(np, p, topo, age=None):
    """a child's chest: the relief at its centres laid flush with the chest around them. The vertices within
    NIPPLE_FLUSH of a nipple are spread over the chest's plane again (a harmonic map from the ring round them: no
    folds where MakeHuman's relief doubled back) and set onto a quadric fitted to that ring, the ring's own
    offset from the quadric carried in so there's no seam. (A plain Laplacian shrinks a convex surface into a dimple.)
    The older child then gets a low dome."""
    from skin_textures import NIPPLE_UV
    uv, vmap, index = topo[0], topo[1], topo[2]
    vuv = np.zeros((len(p), 2))
    vuv[vmap] = uv
    tris = vmap[index.reshape(-1, 3)]
    e = np.unique(np.sort(np.concatenate([tris[:, [0, 1]], tris[:, [1, 2]], tris[:, [2, 0]]]), axis=1), axis=0)
    nrm = vertex_normals(np, p, tris)
    front = p[:, 2] > np.median(p[:, 2])
    out = p.copy()
    for c in NIPPLE_UV:
        d = np.linalg.norm(vuv - np.array(c), axis=1)
        centre = p[(d < 0.003) & front].mean(0)
        r = np.linalg.norm(p - centre, axis=1)
        inner = (r < NIPPLE_FLUSH) & front
        ring = (r >= NIPPLE_FLUSH) & (r < NIPPLE_FLUSH + NIPPLE_RING) & front
        n = nrm[ring].mean(0)
        n /= np.linalg.norm(n)
        e1 = np.cross(n, [0, 1, 0])
        e1 /= np.linalg.norm(e1)
        e2 = np.cross(n, e1)
        o = p[ring].mean(0)
        q = p - o
        u, v, h = q @ e1, q @ e2, q @ n
        A = np.stack([np.ones(len(p)), u, v, u * u, u * v, v * v], 1)
        coef = np.linalg.lstsq(A[ring], h[ring], rcond=None)[0]
        # the patch: the inner vertices and the ring of neighbours they hang from
        patch = inner.copy()
        patch[e[inner[e[:, 0]], 1]] = True
        patch[e[inner[e[:, 1]], 0]] = True
        ids = np.flatnonzero(patch)
        local = -np.ones(len(p), np.int64)
        local[ids] = np.arange(len(ids))
        pe = e[patch[e].all(1)]
        m = len(ids)
        W = np.zeros((m, m))
        W[local[pe[:, 0]], local[pe[:, 1]]] = 1
        W[local[pe[:, 1]], local[pe[:, 0]]] = 1
        L = np.eye(m) - W / np.maximum(W.sum(1, keepdims=True), 1)
        i, b = local[np.flatnonzero(inner)], local[ids[~inner[ids]]]
        X = np.stack([u, v, h - A @ coef], 1)
        X[np.flatnonzero(inner)] = np.linalg.solve(L[np.ix_(i, i)], -L[np.ix_(i, b)] @ X[ids[~inner[ids]]])
        ui, vi, res = X[inner].T
        hi = np.stack([np.ones(len(ui)), ui, vi, ui * ui, ui * vi, vi * vi], 1) @ coef + res
        if age in NIPPLE_DOME:
            height, radius = NIPPLE_DOME[age]
            uc, vc = u[(d < 0.003) & front].mean(), v[(d < 0.003) & front].mean()
            hi += height * np.exp(-((ui - uc) ** 2 + (vi - vc) ** 2) / radius ** 2)
        out[inner] = o + np.outer(ui, e1) + np.outer(vi, e2) + np.outer(hi, n)
    return out


# MakeHuman's young heads have a flat crown and a steep, flat occiput: the cranium is pushed out toward an ellipsoid
# (never in: the skull stays inside) — (strength, crown lift, back, brow and side bulge) as fractions of the half-axes
LONG = 1.15
CRANIUM = {"infant": (1.0, 0.08, 0.35, 0.1, 0.3, True, 1.05), "toddler": (1.0, 0.2, 0.1, 0.1, 0.15, True, 1.15), "child": (1.0, 0.12, 0.1, 0.04, 0.03)}


def round_cranium(np, p, eye, shape, edges):
    """k: how far toward the rounder shape; snap: the whole cranium onto it (in and out), else only pushed out"""
    k, lift, back, brow, side, *snap = shape
    long = snap[1] if len(snap) > 1 else LONG
    snap = snap[:1]
    top = p[:, 1].max()
    head = p[p[:, 1] > eye[1]]
    # its width above the ears
    ax = np.abs(p[p[:, 1] > eye[1] + 0.35 * (top - eye[1])][:, 0]).max()
    z0, z1 = head[:, 2].min(), head[:, 2].max()
    # its length from the forehead back: at most LONG × its width (a long, sloping back is drawn in)
    az = min((z1 - z0) / 2, long * ax)
    cz = z1 - az
    ay = top - eye[1]
    c = np.array([0.0, eye[1], cz])
    d = p - c
    # outward half-axes: taller, deeper behind and a little in front
    ey = ay * (1 + lift)
    ez = np.where(d[:, 2] < 0, az * (1 + back), az * (1 + brow))
    q = np.sqrt((d[:, 0] / (ax * (1 + side))) ** 2 + (d[:, 1] / ey) ** 2 + (d[:, 2] / ez) ** 2)
    want = d / np.maximum(q, 1e-9)[:, None]
    # where: the cranium above the brow in front, above the nape behind, not the face, ears or neck
    front = smoothstep(eye[1] + 0.15 * ay, eye[1] + 0.45 * ay, p[:, 1])
    rear = smoothstep(eye[1] - 0.6 * ay, eye[1] + 0.1 * ay, p[:, 1]) * smoothstep(cz - 0.2 * az, cz - 0.6 * az, p[:, 2])
    # out to the rounder shape; a skull reaching past it behind (a long, sloping back) drawn in part way
    w = np.maximum(front, rear) * (k if snap else np.where(q < 1, k, 0.6 * (d[:, 2] < 0)))
    move = w[:, None] * (want - d)
    # spread over the mesh: no ridge where the push starts
    n = np.bincount(edges.ravel(), minlength=len(p)).astype(np.float64)[:, None]
    for _ in range(30):
        acc = np.zeros_like(move)
        np.add.at(acc, edges[:, 0], move[edges[:, 1]])
        np.add.at(acc, edges[:, 1], move[edges[:, 0]])
        move = 0.5 * move + 0.5 * acc / np.maximum(n, 1)
    return p + move


def age_target(np, src, top_src, age):
    """Fitter landmarks for a child: the adult landmarks pushed through the app's reshape."""
    if age not in PROPS:
        return {}
    gen = {k: reshape(v, age) for k, v in GEN.items()}
    top = reshape((0, TOP["skin"], 0), age)[1]
    sole = reshape((HIP[0], SOLE, 0), age)[1]
    tw, td = PROPS[age][6], PROPS[age][7]
    mid = lambda k: (src[k + "-l"] + src[k + "-r"]) / 2
    hx = gen["hip"][0] / abs(src["hip-l"][0])
    sx = gen["shoulder"][0] / abs(src["shoulder-l"][0])
    head = (top - gen["neck"][1]) / (top_src - src["neck"][1])
    del mid
    # limbs as wide as the app's reshape makes them (arm and leg girth): else they'd meet the trunk with a step
    leg_g, arm_g = PROPS[age][3], PROPS[age][5]
    girth = {**{k: arm_g for k in ("uparm", "forearm", "fore1", "fore2", "hand")}, **{k: leg_g for k in ("thigh", "shin", "foot")}}
    return dict(gen=gen, top=top, sole=sole, widths=[(hx, hx * td / tw), (sx, sx * td / tw), (head, head), (head, head)], girth=girth,
                soften=NECK_SOFTEN[age])


# the chest's faces (chest_faces.npy: MakeHuman's polygons round the chest centres, found on the female builds with
# FIGURE_CHEST_FACES=1 fit female-adult): its coarse quads facet over the larger options, so each is split in four
# twice with the new vertices on a smooth curve. The same faces on every figure, so every variant keeps one topology
# (new vertices after the original ones).
CHEST_FACES = ROOT / "scripts" / "models" / "chest_faces.npy"
NIPPLE_VERTS = (8456, 1784)
CHEST_REACH = 0.21
# how far each new vertex goes from the flat split toward the corners' tangent planes (Phong tessellation): Blender's
# own smooth split pushes edge points and face points out by different amounts, which ridges along the edge loops
CHEST_ROUND = 0.75


def refine_chest(np, me, o, levels=2):
    import bmesh
    import os
    if os.environ.get("FIGURE_CHEST_FACES"):
        return collect_chest_faces(np, me, o)
    faces = np.load(CHEST_FACES)
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    sel = [bm.faces[int(i)] for i in faces]
    for _ in range(levels):
        keep = {v.index for f in sel for v in f.verts}
        n0 = len(bm.verts)
        bm.normal_update()
        pos = np.array([v.co[:] for v in bm.verts])
        nrm = np.array([v.normal[:] for v in bm.verts])
        edges = sorted({e for f in sel for e in f.edges}, key=lambda e: e.index)
        # (neighbours that share an edge are split through its new vertex too: no fanned slivers along the boundary)
        bmesh.ops.subdivide_edges(bm, edges=edges, cuts=1, use_grid_fill=True, use_single_edge=True)
        bm.verts.ensure_lookup_table()
        bm.faces.ensure_lookup_table()
        bm.verts.index_update()
        round_split(np, bm, n0, pos, nrm)
        # the split faces (not the neighbours that only gained a vertex on a shared edge)
        sel = [f for f in bm.faces if all(v.index in keep or v.index >= n0 for v in f.verts)]
    bm.to_mesh(me)
    bm.free()
    me.update()


def round_split(np, bm, n0, pos, nrm):
    """new vertices (index >= n0) moved toward the mean of their projections onto the tangent planes of the old
    vertices they were split from (an edge point's two ends, a face point's corners)"""
    def parents(v):
        old = [e.other_vert(v) for e in v.link_edges if e.other_vert(v).index < n0]
        if not old:
            old = [p for e in v.link_edges for p in parents(e.other_vert(v))]
        return old
    for v in bm.verts:
        if v.index < n0:
            continue
        ps = {p.index for p in parents(v)}
        if not ps:
            continue
        q = np.array(v.co[:])
        on = [q - np.dot(q - pos[i], nrm[i]) * nrm[i] for i in ps]
        v.co = tuple(q + CHEST_ROUND * (np.mean(on, axis=0) - q))


def collect_chest_faces(np, me, o):
    """the polygons within CHEST_REACH of a chest centre (none of the arms), added to chest_faces.npy"""
    co = mesh_coords(np, me)
    arms = {g.index for g in o.vertex_groups if g.name.startswith(("upperarm", "lowerarm", "wrist", "finger", "metacarpal"))}
    arm = np.zeros(len(me.vertices))
    for v in me.vertices:
        arm[v.index] = max([g.weight for g in v.groups if g.group in arms], default=0.0)
    near = np.min([np.linalg.norm(co - co[i], axis=1) for i in NIPPLE_VERTS], axis=0) < CHEST_REACH
    keep = set(np.load(CHEST_FACES).tolist()) if CHEST_FACES.exists() else set()
    for f in me.polygons:
        vs = list(f.vertices)
        if near[vs].all() and arm[vs].max() < 0.3:
            keep.add(f.index)
    np.save(CHEST_FACES, np.array(sorted(keep), np.int32))
    print("FIGURE chest faces", len(keep))


def topology(np, me):
    """render vertices = unique (vertex, uv) corners; returns uv, render→vertex map, triangle indices, source face.
    Polygons are fanned from their first corner (Blender's own triangulation follows each variant's shape)."""
    start = np.empty(len(me.polygons), dtype=np.int64)
    me.polygons.foreach_get("loop_start", start)
    total = np.empty(len(me.polygons), dtype=np.int64)
    me.polygons.foreach_get("loop_total", total)
    tri, poly = [], []
    for k in range(3, total.max() + 1):
        p = np.flatnonzero(total >= k)
        tri.append(np.stack([start[p], start[p] + k - 2, start[p] + k - 1], 1))
        poly.append(p)
    tri, poly = np.concatenate(tri), np.concatenate(poly)
    order = np.lexsort((tri[:, 1], poly))
    tri, poly = tri[order].reshape(-1), poly[order]
    lv = np.empty(len(me.loops), dtype=np.int64)
    me.loops.foreach_get("vertex_index", lv)
    uv = np.empty(len(me.loops) * 2)
    me.uv_layers.active.data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    key = np.stack([lv, np.round(uv[:, 0] * 16384).astype(np.int64), np.round(uv[:, 1] * 16384).astype(np.int64)], 1)
    uniq, first, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
    return uv[first].astype(np.float32), lv[first].astype(np.uint32), inv.reshape(-1)[tri].astype(np.uint32), poly.astype(np.uint32)


# ------------------------------------------------------------------ pack (plain Python + numpy + PIL)


def smoothstep(a, b, x):
    import numpy as np
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


class Packer:
    def __init__(self, np):
        self.np, self.chunks, self.size, self.blocks = np, [], 0, []

    def add(self, arr):
        arr = self.np.ascontiguousarray(arr)
        pad = (-self.size) % 4
        if pad:
            self.chunks.append(b"\0" * pad)
            self.size += pad
        off = self.size
        self.chunks.append(arr.tobytes())
        self.size += arr.nbytes
        return off

    def block(self, pos, ref=None, ref_pos=None, fine=2e-5):
        """positions as int16 steps from a reference block (or from zero)"""
        np = self.np
        d = pos - (ref_pos if ref is not None else 0)
        # fixed fine step (≈0.01 mm): small deltas stay small integers and deflate well
        step = np.maximum(np.abs(d).max(0) / 32000, fine)
        lo = -32767 * step
        q = np.round((d - lo) / step - 32767).astype(np.int16)
        self.blocks.append({"ref": ref, "offset": self.add(q), "count": len(pos), "lo": lo.tolist(), "step": step.tolist()})
        return len(self.blocks) - 1

    def decode(self, i):
        b = self.blocks[i]
        np = self.np
        raw = b"".join(self.chunks)[b["offset"]:b["offset"] + b["count"] * 6]
        q = np.frombuffer(raw, dtype=np.int16).reshape(-1, 3).astype(np.float64)
        p = (q + 32767) * np.array(b["step"]) + np.array(b["lo"])
        return p + (self.decode(b["ref"]) if b["ref"] is not None else 0)


def pack():
    import numpy as np
    import hair
    topo = {p.name.split(".")[1]: dict(np.load(p)) for p in RAW.glob("topo.*.npz") if not p.name.startswith("topo.hair-")}
    body_tris = topo["body"]["vmap"][topo["body"]["index"].reshape(-1, 3)]
    loaded = {}

    def load(n):
        if n not in loaded:
            got = {k[4:]: v.astype(np.float64) for k, v in np.load(RAW / f"{n}.npz").items()}
            eyes = got["eyes"] if "eyes" in got else load(f"{n.split('.')[0]}.neutral")["eyes"]
            loaded[n] = dict(got, body=smooth_skin(np, got["body"], eyes, body_tris))
        return {k: v.copy() for k, v in loaded[n].items()}
    grooms = grow_hair(np, load, topo["body"])
    for gid, styles in grooms.items():
        for name, g in styles.items():
            topo[f"hair-{name}"] = g.topo
            if len(g.shell_pos):
                topo[f"hair-{name}.shell"] = g.shell_topo
    pk = Packer(np)
    header = {"pieces": {}, "blocks": pk.blocks, "variants": {}, "garments": {}, "shapes": {}}
    for k, t in topo.items():
        header["pieces"][k] = {"vertices": int(t["vmap"].max()) + 1, "render": len(t["vmap"]), "triangles": len(t["index"]) // 3,
                               "uv": pk.add(np.round(t["uv"].clip(0, 1) * 65535).astype(np.uint16)),
                               "vmap": pk.add(t["vmap"].astype(np.uint32)), "index": pk.add(t["index"].astype(np.uint32))}
    base_block = {}

    def put(piece, pos, ref_key=None):
        """deltas against the group's neutral piece; the neutral piece itself is absolute"""
        if ref_key is None:
            i = pk.block(pos)
        else:
            ref = base_block[ref_key]
            # hair follows the head to a few tenths of a millimetre (coarser steps deflate far better)
            i = pk.block(pos, ref, pk.decode(ref), 4e-4 if piece.startswith("hair-") else 2e-5)
        return i

    variants = header["variants"]
    for gid, (sex, age, hairs, _, _) in GROUPS.items():
        neutral = load(f"{gid}.neutral")
        neutral = {k: v for k, v in neutral.items() if not k.startswith("hair-")}
        for name, g in grooms[gid].items():
            neutral[f"hair-{name}"] = g.pos
            if len(g.shell_pos):
                neutral[f"hair-{name}.shell"] = g.shell_pos
        for k, v in neutral.items():
            base_block[(gid, k)] = put(k, v)
            neutral[k] = pk.decode(base_block[(gid, k)])
        body0 = neutral["body"]
        y = body0[:, 1]
        # heritage reaches from the neck up; the body below keeps the sex's shape
        gen = {k: reshape(v, age) for k, v in GEN.items()}
        sh, nk = gen["shoulder"][1], gen["neck"][1]
        w = smoothstep(sh + 0.3 * (nk - sh), sh + 0.8 * (nk - sh), y)[:, None]
        preg = load(f"{gid}.pregnant") if gid == "female-adult" else None
        for her in HERITAGES:
            got = {k: v for k, v in load(f"{gid}.{her}").items() if not k.startswith("hair-")}
            body = body0 + w * (got["body"] - body0)
            for name in hair.styles_for(hairs, her):
                got[f"hair-{name}"] = grooms[gid][name].follow(np, body)
                if len(grooms[gid][name].shell_pos):
                    got[f"hair-{name}.shell"] = grooms[gid][name].follow_shell(np, body)
            entry = {"body": put("body", body, (gid, "body"))}
            for k, v in got.items():
                if k != "body":
                    entry[k] = put(k, v, (gid, k))
            sexes = ["male", "female"] if sex == "kid" else [sex]
            for s in sexes:
                mine = hair.styles_for([h for h in hairs if HAIR_SEX[h] == s] if sex == "kid" else hairs, her)
                pieces = {k: v for k, v in entry.items() if not k.startswith("hair-") or k[5:].split(".")[0] in mine}
                variants[f"{s}.{age}.{her}"] = pieces
            if preg is not None:
                pb = body + PREGNANT_GAIN * (1 - w) * (preg["body"] - body0)
                variants[f"female.pregnant.{her}"] = {**entry, "body": put("body", pb, (gid, "body"))}
    # body options: deltas on the adult female body (not the head)
    f0 = load("female-adult.neutral")["body"]
    y = f0[:, 1]
    gen = {k: reshape(v, "adult") for k, v in GEN.items()}
    below = 1 - smoothstep(gen["shoulder"][1] + 0.3 * (gen["neck"][1] - gen["shoulder"][1]), gen["neck"][1], y)[:, None]
    arms = np.load(RAW / "regions.npz")["arms"]

    edges = np.unique(np.sort(np.concatenate([body_tris[:, [0, 1]], body_tris[:, [1, 2]], body_tris[:, [2, 0]]]), axis=1), axis=0)
    degree = np.maximum(np.bincount(edges.ravel(), minlength=len(f0)), 1)[:, None]
    # the hips' change eased into the waist (no shelf across the small of the back)
    waist = (smoothstep(0.2, 0.32, y) * (1 - smoothstep(0.6, 0.75, y)))[:, None]

    def shape_delta(name):
        d = below * (load(f"female-adult.shape-{name}")["body"] - f0)
        if name.startswith("hips-"):
            for _ in range(HIP_EASE):
                acc = np.zeros_like(d)
                np.add.at(acc, edges[:, 0], d[edges[:, 1]])
                np.add.at(acc, edges[:, 1], d[edges[:, 0]])
                d += 0.5 * waist * (acc / degree - d)
            # nothing of it reaches the chest (the bra's band sits there)
            d *= 1 - smoothstep(0.62, 0.78, y)[:, None]
        # wider hips: the arms swing out about the shoulders just enough that the hands and forearms clear them
        angle = ARM_OUT.get(name, 0.0)
        if angle:
            for side in (1, -1):
                c = np.array(gen["shoulder"]) * np.array([side, 1, 1])
                # the whole arm turns as one (full below the armpit, fading in above it), by its own weight: the side
                # of the chest under it stays put
                arm = np.maximum(smoothstep(0.2, 0.7, arms), (arms > 0.02) * smoothstep(c[1] - 0.2, c[1] - 0.35, f0[:, 1]))
                sel = arm * (np.sign(f0[:, 0]) == side) * smoothstep(c[1] - 0.02, c[1] - 0.25, f0[:, 1])
                q = f0 - c
                a = -side * angle * sel
                rot = np.stack([q[:, 0] * np.cos(a) + q[:, 1] * np.sin(a), -q[:, 0] * np.sin(a) + q[:, 1] * np.cos(a), q[:, 2]], 1)
                d += rot - q
        return d
    header["shapes"] = {name: pk.block(shape_delta(name)) for name in SHAPES}
    # each size's garments fit the body the app shows: that chest with its matching hips
    chests = {n[6:]: f0 + shape_delta(n) + shape_delta(f"hips-{n[6:]}") for n in SHAPES if n.startswith("chest-")}
    chests["senior"] = load("female-senior.neutral")["body"]
    header["garments"] = garments(np, pk, topo["body"], load("male-adult.neutral")["body"], f0 + shape_delta("hips-large"),
                                  load("kid-toddler.neutral")["body"], chests, load("kid-child.neutral")["body"],
                                  nipple_ids(np, load("female-adult.neutral")))
    payload = b"".join(pk.chunks)
    comp = zlib.compressobj(9, zlib.DEFLATED, -15)
    data = comp.compress(payload) + comp.flush()
    head = json.dumps(header, separators=(",", ":")).encode()
    FIGURE.write_bytes(b"EBF1" + len(head).to_bytes(4, "little") + len(payload).to_bytes(4, "little") + head + data)
    print(f"FIGURE {FIGURE.name}: {len(variants)} variants, {len(pk.blocks)} blocks, payload {len(payload) // 1024} KB → {FIGURE.stat().st_size // 1024} KB")
    textures(scalp_masks(np, topo["body"], grooms))
    index = load_index()
    index.pop("skins", None)
    index["figure"] = {"file": FIGURE.name, "source": "MakeHuman (MPFB2)", "license": "CC0",
                       "variants": sorted(variants), "triangles": {k: v["triangles"] for k, v in header["pieces"].items()}}
    save_index(index)


# ------------------------------------------------------------------ underwear: body triangles, pushed out along the normal


# a garment's cut: about this long between the points it's cut at (m)
CELL = 0.009


# the bra's side wing falls to the band over this depth (z, m: back, front)
WING = (-0.08, 0.12)


def garments(np, pk, topo, male, female, kid, chests=None, child=None, nipples=None, only_bra=False):
    """Underwear as the parts of the body where a smooth field is positive, cut exactly along its zero line.
    Each garment vertex is a point in a body triangle, so it follows every sex/age/heritage variant.
    Fields are written on the neutral adult male / female and the toddler (children share them: same topology); the
    child's top on the child."""
    vmap, index = topo["vmap"], topo["index"].reshape(-1, 3)
    tris = np.unique(vmap[index], axis=0)  # position-vertex triangles (seams collapse)

    def ramp(v, a, b):
        t = np.clip((v - a) / (b - a), 0, 1)
        return t * t * (3 - 2 * t)

    def smin(a, b, k):
        h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
        return b + (a - b) * h - k * h * (1 - h)

    def smax(a, b, k):
        return -smin(-a, -b, k)

    def legs(x, y, z, front_y, front_slope, back_y, back_slope, cap):
        """leg openings: rise from the crotch to the hip, lower at the back over the buttocks; a band stays at the side"""
        ax = np.abs(x)
        front = smin(front_y + front_slope * np.clip(ax - 0.025, 0, None), cap, 0.04)
        back = smin(back_y + back_slope * np.clip(ax - 0.02, 0, None), cap, 0.04)
        w = ramp(z, -0.05, 0.05)
        return y - (w * front + (1 - w) * back)

    def briefs_male(p):
        x, y, z = p.T
        return np.minimum.reduce([0.24 - y, legs(x, y, z, -0.045, 0.9, -0.085, 0.5, 0.15), 0.31 - np.abs(x)])

    def briefs_female(p):
        x, y, z = p.T
        return np.minimum.reduce([0.25 - y, legs(x, y, z, -0.05, 1.0, -0.075, 0.5, 0.15), 0.46 - np.abs(x)])

    def briefs_pregnant(p):
        """maternity cut: the front waistband dips under the bump"""
        x, y, z = p.T
        dip = 0.12 * ramp(z, 0.0, 0.08) * (1 - ramp(np.abs(x), 0.06, 0.2))
        return np.minimum.reduce([0.25 - dip - y, legs(x, y, z, -0.05, 1.0, -0.075, 0.5, 0.15), 0.46 - np.abs(x)])

    def bra_for(body):
        """the bra cut on this body"""
        if nipples:
            i = max(nipples, key=lambda i: body[i, 0])
            return lambda p: bra(p, body[i], body[i, 1] - breast_depth(np, body, i))
        apex = body[(body[:, 1] > 0.6) & (body[:, 1] < 0.95) & (body[:, 0] > 0.02) & (body[:, 0] < 0.32)]
        apex = apex[np.argmax(apex[:, 2])]
        return lambda p: bra(p, apex, apex[1] - 0.1)

    def bra(p, apex, fold):
        """a soft bralette: the band under the breasts' fold all round, each cup round its breast down to the band (no
        gap between them at any size), the front between the cups up to a neckline rising to the straps, a low V"""
        x, y, z = p.T
        ax = np.abs(x)
        ay = apex[1]
        sx = apex[0] - 0.01 - 0.02 * ramp(-z, -0.03, 0.03)  # strap line: over the cup in front, a little inward at the back
        lo, hi = fold - 0.055, fold + 0.012
        top = ay - 0.005 + 0.11 * np.clip((ax - 0.03) / (sx - 0.03), 0, 1.2)
        # past the strap, kept low (the arm meets the chest in a tight crease above)
        top = top - 0.9 * np.clip(0.03 - ax, 0, None) - ramp(ax, sx + 0.03, sx + 0.07) * np.maximum(top - ay - 0.05, 0)
        reach = ay - fold + 0.035
        cups = smin(smin(y - lo, top - y, 0.012), reach - np.hypot(1.1 * (ax - apex[0]), y - ay), 0.02)
        gore = smin(smin(y - lo, top - y, 0.012), apex[0] - ax, 0.02)
        # the side wing: its top sweeps down from the cup's side to the band toward the back (no corner)
        wing = hi + (ay + 0.05 - hi) * ramp(z, WING[0], WING[1]) - y
        front = smin(smin(smax(cups, gore, 0.02), wing, 0.01), ay + 0.05 - y + 10 * np.clip(sx + 0.03 - ax, 0, None), 0.01)
        band = smin(smin(y - lo, hi - y, 0.01), 0.3 - ax, 0.01)
        # (at the back it runs on down into the band at every size)
        strap = smin(smin(0.02 - np.abs(ax - sx), 1.2 - y, 0.01), y - (ay + 0.06) + ramp(-z, 0, 0.02) * (ay + 0.08 - hi), 0.01)
        return smax(smax(front, band, 0.015), strap, 0.03)

    kid_hip, kid_crotch = reshape(GEN["hip"], "toddler")[1], -0.075

    def nappy(p):
        x, y, z = p.T
        return np.minimum.reduce([kid_hip + 0.17 - y, legs(x, y, z, kid_crotch - 0.03, 0.55, kid_crotch - 0.04, 0.4, kid_hip + 0.09), 0.36 - np.abs(x)])

    def briefs_kid(p):
        x, y, z = p.T
        return np.minimum.reduce([kid_hip + 0.14 - y, legs(x, y, z, kid_crotch - 0.01, 0.9, kid_crotch - 0.03, 0.5, kid_hip + 0.07), 0.36 - np.abs(x)])

    def top_kid(p):
        """a plain tank top: a straight hem, a shallow round scoop in front and a higher back, straight straps over the
        shoulders with the armholes cut down from their outer edge (the arms are cut away in clip)"""
        x, y, z = p.T
        ax = np.abs(x)
        sx, hw = 0.165, 0.03
        t = np.clip(ax / (sx - hw), 0, 1) ** 2
        neck = (0.95 + 0.09 * t) + ((1.05 + 0.02 * t) - (0.95 + 0.09 * t)) * ramp(-z, -0.03, 0.03)
        armhole = np.maximum(1.15 - 2.1 * (ax - sx - hw), 0.94)
        top = neck + (armhole - neck) * ramp(ax, sx - hw, sx + hw)
        body = np.minimum(y - 0.36, top - y)
        strap = np.minimum.reduce([hw - np.abs(ax - sx), 1.2 - y, y - 0.9])
        return np.maximum(body, strap)

    arms = np.load(RAW / "regions.npz")["arms"]

    def clip(field, pos, arms_anywhere=False):
        """positive part of the body, each triangle split so the cut follows the field smoothly: every edge into
        segments about CELL long (the same on both sides, so neighbours share their points), fanned from the middle.
        A vertex is a barycentric point of a body triangle ((a, b, c), weights of a and b) plus its field value:
        about its distance to the garment's edge (hem shading, a softer lift at the edge)."""
        cand = tris[field(pos)[tris].max(1) > -0.04]
        segs = np.clip(np.ceil(np.linalg.norm(pos[cand] - np.roll(pos[cand], -1, axis=1), axis=2) / CELL), 1, 4).astype(int)
        # never onto the arms (a hanging hand lies against the hip)
        arm = np.clip(arms * 2 - 0.4, 0, 1)
        verts, fval, out = {}, [], []

        def vid(tri, w, f):
            ws = {}
            for i, x in zip(tri, w):
                if x > 1e-6:
                    ws[int(i)] = ws.get(int(i), 0.0) + float(x)
            key = tuple(sorted((i, round(x, 5)) for i, x in ws.items()))
            if key not in verts:
                verts[key] = len(verts)
                fval.append(max(float(f), 0.0))
            return verts[key]

        for tri, n3 in zip(cand, segs):
            bary = []
            for e, (i, j) in enumerate(((0, 1), (1, 2), (2, 0))):
                for k in range(n3[e]):
                    b = np.zeros(3)
                    b[i], b[j] = 1 - k / n3[e], k / n3[e]
                    bary.append(b)
            m = len(bary)
            if m > 3:
                bary.append(np.full(3, 1 / 3))
                cells = [(m, k, (k + 1) % m) for k in range(m)]
            else:
                cells = [(0, 1, 2)]
            bary = np.array(bary)
            pts = bary @ pos[tri]
            f = field(pts) - bary @ (arm[tri] * (pos[tri][:, 1] < 0.6))
            if arms_anywhere:
                # (the shoulder tops under the straps are partly arm too: only out at the sides)
                f -= (bary @ arm[tri]) * ramp(np.abs(pts[:, 0]), 0.21, 0.24)
            if f.max() <= 0:
                continue
            for cell in cells:
                if f[list(cell)].max() <= 0:
                    continue
                poly = []
                for k in range(3):
                    a, b = cell[k], cell[(k + 1) % 3]
                    fa, fb = f[a], f[b]
                    if fa > 0:
                        poly.append(vid(tri, bary[a], fa))
                    if (fa > 0) != (fb > 0):
                        t = fa / (fa - fb)
                        poly.append(vid(tri, bary[a] + t * (bary[b] - bary[a]), 0.0))
                for k in range(1, len(poly) - 1):
                    if len({poly[0], poly[k], poly[k + 1]}) == 3:
                        out.append((poly[0], poly[k], poly[k + 1]))
        keys = sorted(verts, key=verts.get)
        abc = np.array([[k[min(i, len(k) - 1)][0] for i in range(3)] for k in keys], dtype=np.uint32)
        w = np.array([[k[i][1] if i < len(k) else 0.0 for i in range(2)] for k in keys], dtype=np.float32)
        return abc, w, np.array(fval, dtype=np.float32), np.array(out, dtype=np.uint32)

    out = {}
    for name, pos, field, lift, color in (
            ("briefs-male", male, briefs_male, 0.004, "#2F3947"),
            ("briefs-female", female, briefs_female, 0.004, "#D4B2AA"),
            ("briefs-pregnant", female, briefs_pregnant, 0.004, "#D4B2AA"),
            ("bra", female, bra_for(female), 0.0065, "#D4B2AA"),
            *[(f"bra-{n}", body, bra_for(body), 0.0065, "#D4B2AA") for n, body in (chests or {}).items()],
            ("nappy", kid, nappy, 0.014, "#F4F2EE"),
            ("briefs-kid", kid, briefs_kid, 0.004, "#7FA6CF"),
            ("top-kid", kid if child is None else child, top_kid, 0.006, "#7FA6CF")):
        if only_bra and name != "bra":
            continue
        abc, w, f, tri = clip(field, pos, arms_anywhere=name == "top-kid" or name.startswith("bra"))
        # the field isn't a distance: measure each vertex's distance to the cut edge on the neutral body instead
        wc = 1 - w.sum(1)
        p = w[:, :1] * pos[abc[:, 0]] + w[:, 1:] * pos[abc[:, 1]] + wc[:, None] * pos[abc[:, 2]]
        rim = p[f == 0]
        f = np.concatenate([np.linalg.norm(p[i:i + 512, None] - rim[None], axis=2).min(1)
                            for i in range(0, len(p), 512)]).astype(np.float32)
        offset = None
        if name.startswith("bra") and nipples:
            abc, w, offset = cup(np, pos, tris, p, abc, w, tri, nipples, lift * (0.8 + 0.2 * np.minimum(f / 0.01, 1)))
        out[name] = {"vertices": len(f), "triangles": len(tri), "abc": pk.add(abc), "w": pk.add(w), "f": pk.add(f),
                     "index": pk.add(tri), "lift": lift, "color": color}
        if offset is not None:
            out[name]["offset"] = pk.add(offset)
        print("GARMENT", name, len(f), len(tri))
    return out


def nipple_ids(np, got):
    """the chest centre vertices (the most forward point each side; same topology on every variant)"""
    body, eyes = got["body"], got["eyes"]
    U = np.linalg.norm(eyes[eyes[:, 0] > 0].mean(0) - eyes[eyes[:, 0] < 0].mean(0))
    ey = eyes[:, 1].mean()
    out = []
    for side in (1, -1):
        band = (side * body[:, 0] > 0.5 * U) & (side * body[:, 0] < 2.8 * U) & (body[:, 1] < ey - 3.2 * U) & (body[:, 1] > ey - 7 * U)
        out.append(int(np.flatnonzero(band)[np.argmax(body[band][:, 2])]))
    return out


def tri_frame(np, a, b, c, n):
    """a triangle's own frame from its corners: first edge, across, its normal (turned to the skin's side `n`); the
    app rebuilds it from the posed corners alone"""
    t1 = b - a
    t1 /= np.maximum(np.linalg.norm(t1, axis=1, keepdims=True), 1e-12)
    nt = np.cross(b - a, c - a)
    nt /= np.maximum(np.linalg.norm(nt, axis=1, keepdims=True), 1e-12)
    nt[(nt * n).sum(1) < 0] *= -1
    return t1, np.cross(nt, t1), nt


def breast_depth(np, body, i):
    """how far below the chest centre the breast's underside meets the chest wall (its front falls back there)"""
    a = body[i]
    s = (np.abs(body[:, 0] - a[0]) < 0.02) & (body[:, 2] > 0) & (body[:, 1] < a[1]) & (body[:, 1] > a[1] - 0.3)
    q = body[s]
    wall = np.median(q[q[:, 1] < a[1] - 0.25, 2])
    for d in np.arange(0.0, 0.3, 0.005):
        near = np.abs(q[:, 1] - (a[1] - d)) < 0.004
        if near.any() and q[near, 2].max() < wall + 0.25 * (a[2] - wall):
            return d
    return 0.1


def tutte(np, x, free, se):
    """x with its `free` rows moved to the average of their neighbours (solved: no folds)"""
    from scipy import sparse
    from scipy.sparse.linalg import spsolve
    n = len(x)
    A = sparse.csr_matrix((np.ones(len(se)), (se[:, 0], se[:, 1])), shape=(n, n))
    A.data[:] = 1
    L = sparse.diags(np.asarray(A.sum(1)).ravel()) - A
    U, K = np.flatnonzero(free), np.flatnonzero(~free)
    out = x.copy()
    out[U] = spsolve(L[U][:, U].tocsc(), -(L[U][:, K] @ x[K]))
    return out


def cup(np, body, tris, p, abc, w, gtri, nipples, lift, inner=0.03):
    from scipy.spatial import cKDTree
    """a cup over each chest centre: the skin's height (along the cup's axis) evened out over the cup, raised to
    clear the tip and easing back onto the skin by `outer`; the fabric lies on the higher of that and the skin. The
    stand-off is found per skin vertex and carried to the fabric's points with their weights, so the fabric follows
    the skin's facets; per fabric point, its whole move off the skin (the garment's lift included, turning from the
    skin's normal to the cup's axis) in its triangle's frame (see tri_frame)"""
    f = np.cross(body[tris[:, 1]] - body[tris[:, 0]], body[tris[:, 2]] - body[tris[:, 0]])
    vn = np.zeros_like(body)
    for k in range(3):
        np.add.at(vn, tris[:, k], f)
    vn /= np.maximum(np.linalg.norm(vn, axis=1, keepdims=True), 1e-12)
    se = np.concatenate([tris[:, [0, 1]], tris[:, [1, 2]], tris[:, [2, 0]]]).astype(np.int64)
    se = np.concatenate([se, se[:, ::-1]])
    deg = np.maximum(np.bincount(se[:, 0], minlength=len(body)), 1)
    wc = 1 - w.sum(1)
    carry = lambda field: w[:, :1] * field[abc[:, 0]] + w[:, 1:] * field[abc[:, 1]] + wc[:, None] * field[abc[:, 2]]
    n = carry(vn)
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)
    target, weight = p + lift[:, None] * n, np.zeros(len(p))
    tipzone = np.zeros(len(body), bool)
    # (the skin's normals evened out: the areola's own little slopes left out)
    vs = vn.copy()
    for _ in range(40):
        acc = np.zeros_like(vs)
        np.add.at(acc, se[:, 0], vs[se[:, 1]])
        vs = acc / deg[:, None]
    ns = carry(vs)
    ns /= np.maximum(np.linalg.norm(ns, axis=1, keepdims=True), 1e-12)
    outers, axes = [], []
    for i in nipples:
        # the cup reaches over the whole breast
        outer = float(np.clip(0.75 * breast_depth(np, body, i), 0.075, 0.13))
        outers.append(outer)
        t = body[i]
        d = body - t
        close = np.linalg.norm(d, axis=1) < 2 * outer
        axis = vn[np.linalg.norm(d, axis=1) < 1.3 * outer].sum(0)
        axis /= np.linalg.norm(axis)
        axes.append(axis)
        h = d @ axis
        rho = np.linalg.norm(d - h[:, None] * axis, axis=1)
        # the skin with its centre left out: the breast's own surface carried on smoothly over it
        # (a cubic over the cup's own plane, fitted on the ring round the centre)
        e1 = np.cross(axis, [0.0, 1.0, 0.0])
        e1 /= np.linalg.norm(e1)
        e2 = np.cross(axis, e1)
        zone = close & (rho < 1.3 * inner) & (h > -inner)
        uv = np.stack([d @ e1, d @ e2], 1)
        src = close & ~zone & (h > -outer) & (vn @ axis > 0.25)
        tree, suv, sh = cKDTree(uv[src]), uv[src], h[src]

        def surf(Q, sig=0.045):
            """the breast's front without its centre, as one smooth surface over the cup's plane (moving least squares)"""
            out = np.empty(len(Q))
            for k, (qq, nb) in enumerate(zip(Q, tree.query_ball_point(Q, 2.5 * sig))):
                du = suv[nb] - qq
                sw = np.exp(-0.5 * (du ** 2).sum(1) / sig ** 2)[:, None]
                A = np.stack([np.ones(len(du)), du[:, 0], du[:, 1], du[:, 0] ** 2, du[:, 0] * du[:, 1], du[:, 1] ** 2], 1)
                out[k] = np.linalg.lstsq(A * sw, sh[nb] * sw[:, 0], rcond=None)[0][0]
            return out
        hf = h.copy()
        hf[zone] = surf(uv[zone])
        near = (1 - smoothstep(outer, 1.4 * outer, rho)) * smoothstep(-1.2 * outer, -0.9 * outer, h) * close
        cupm = (1 - smoothstep(0, 1.3 * outer, rho)) * smoothstep(-outer, -0.8 * outer, h) * close
        # the cup clears the centre by one even stand-off over its middle (a moulded cup), easing off to its edge
        prof = cupm
        amp = max(float(((h - hf) / np.maximum(prof, 1e-6))[zone].max()), 0.002)
        s_v = prof
        up_v = np.maximum(hf + amp * prof - h, 0) * cupm
        dirn_v = vn * (1 - s_v)[:, None] + axis * s_v[:, None]
        # the centre's steep little walls spread evenly over the cup (laid flat they'd fold over each other)
        lat = d - h[:, None] * axis
        inside = close & (rho < 1.6 * inner) & (h > -inner)
        tipzone |= inside
        flat = tutte(np, lat, inside, se)
        dirn_v[inside] = axis
        up, dirn, shift = carry(up_v[:, None])[:, 0], carry(dirn_v), carry(flat - lat)
        dirn /= np.maximum(np.linalg.norm(dirn, axis=1, keepdims=True), 1e-12)
        reach = carry(near[:, None])[:, 0]
        mine = reach > weight
        target[mine] = (p + lift[:, None] * dirn + up[:, None] * axis)[mine]
        # the cup's front: that smooth surface, raised, where each point now lies (not the skin's facets)
        q = p + shift - t
        qu = np.stack([q @ e1, q @ e2], 1)
        rq = np.linalg.norm(qu, axis=1)
        wm = (1 - smoothstep(0.55 * outer, 0.85 * outer, rq)) * (q @ axis > -outer) * np.maximum(
            smoothstep(0.35, 0.6, ns @ axis), np.clip(2 * carry(inside[:, None].astype(np.float64))[:, 0], 0, 1))
        sel = mine & (wm > 0)
        fq = surf(qu[sel])
        hq = fq + amp * (1 - smoothstep(0, 1.3 * outer, rq[sel])) + lift[sel]
        front = t + q[sel] - (q[sel] @ axis)[:, None] * axis + hq[:, None] * axis
        target[sel] += wm[sel, None] * (front - target[sel])
        weight = np.maximum(weight, reach)
    # the fabric is one smooth sheet over the breast and round it (it bridges the creases at the breast's edge): smoothed
    # over its own mesh without shrinking (Taubin), its cut edge held, then pushed back off the skin along its own
    # normal where it sank in (not over the chest centre: its walls face sideways, and the cup clears it)
    ge = np.unique(np.sort(np.concatenate([gtri[:, [0, 1]], gtri[:, [1, 2]], gtri[:, [2, 0]]]), axis=1), axis=0)
    gdeg = np.maximum(np.bincount(ge.ravel(), minlength=len(p)), 1)[:, None]
    te = np.sort(np.concatenate([gtri[:, [0, 1]], gtri[:, [1, 2]], gtri[:, [2, 0]]]), axis=1)
    uniq, count = np.unique(te, axis=0, return_counts=True)
    rim = np.zeros(len(p), bool)
    rim[uniq[count == 1].ravel()] = True
    around = np.zeros(len(p))
    for i, outer in zip(nipples, outers):
        around = np.maximum(around, 1 - smoothstep(1.4 * outer, 2.2 * outer, np.linalg.norm(p - body[i], axis=1)))
    open_ = 1 - np.clip(4 * carry(tipzone[:, None].astype(np.float64))[:, 0], 0, 1)
    hold = (np.maximum(np.clip(weight * 3, 0, 1), around) * ~rim)[:, None]
    moved = (weight > 0) | (around > 0)

    def taubin(q, k, passes):
        for _ in range(passes):
            for step in (0.5, -0.53):
                acc = np.zeros_like(q)
                np.add.at(acc, ge[:, 0], q[ge[:, 1]])
                np.add.at(acc, ge[:, 1], q[ge[:, 0]])
                q = q + step * k * (acc / gdeg - q)
        return q
    for _ in range(3):
        target = taubin(target, hold, 40)
        gn = np.zeros_like(target)
        fn = np.cross(target[gtri[:, 1]] - target[gtri[:, 0]], target[gtri[:, 2]] - target[gtri[:, 0]])
        for k in range(3):
            np.add.at(gn, gtri[:, k], fn)
        gn /= np.maximum(np.linalg.norm(gn, axis=1, keepdims=True), 1e-12)
        gn[(gn * n).sum(1) < 0] *= -1
        h = ((target - p) * n).sum(1)
        target += (np.maximum(lift - h, 0) * moved * open_ / np.maximum((gn * n).sum(1), 0.3))[:, None] * gn
    # the cup clears the tip for sure: the most the skin there comes through, as one broad rise over the whole cup
    for i, outer, axis in zip(nipples, outers, axes):
        t = body[i]
        e1 = np.cross(axis, [0.0, 1.0, 0.0])
        e1 /= np.linalg.norm(e1)
        e2 = np.cross(axis, e1)
        sk = body[np.linalg.norm(body - t, axis=1) < 0.5 * outer] - t
        ft = target - t
        fh, fuv = ft @ axis, np.stack([ft @ e1, ft @ e2], 1)
        fr = np.linalg.norm(fuv, axis=1)
        front = moved & (fr < outer) & (fh > -0.5 * outer)
        if not front.any():
            continue
        got = cKDTree(fuv[front]).query(np.stack([sk @ e1, sk @ e2], 1))[1]
        rise = max(float((sk @ axis + 0.004 - fh[front][got]).max()), 0.0)
        target += (rise * (1 - smoothstep(0, 1.3 * outer, fr)) * moved * (fh > -outer))[:, None] * axis
    # folded-over facets (the tip's walls laid out, the cup's edge) are smoothed out locally until none is left
    nn = n[gtri].sum(1)
    for _ in range(150):
        fn = np.cross(target[gtri[:, 1]] - target[gtri[:, 0]], target[gtri[:, 2]] - target[gtri[:, 0]])
        bad = np.zeros(len(p), bool)
        bad[gtri[(fn * nn).sum(1) <= 0].ravel()] = True
        if not bad.any():
            break
        for _ in range(2):
            bad[ge[bad[ge[:, 0]], 1]] = True
            bad[ge[bad[ge[:, 1]], 0]] = True
        acc = np.zeros_like(target)
        np.add.at(acc, ge[:, 0], target[ge[:, 1]])
        np.add.at(acc, ge[:, 1], target[ge[:, 0]])
        target[bad] = (acc / gdeg)[bad]
    # as offsets in each point's triangle frame: a moved point on a sliver (a corner or an edge stored with a corner
    # repeated) or on the chest centre's small steep facets is re-bound to the nearest well-sized triangle round it,
    # at the closest point on it (the cup there no longer hangs off the centre's own shape)
    abc, w = abc.copy(), w.copy()
    area = np.linalg.norm(np.cross(body[tris[:, 1]] - body[tris[:, 0]], body[tris[:, 2]] - body[tris[:, 0]]), axis=1)
    own = {frozenset(t.tolist()): k for k, t in enumerate(tris)}
    small = np.array([area[own[frozenset(t.tolist())]] < 1e-6 or tipzone[t].any() if len(set(t.tolist())) == 3 else True
                      for t in abc])
    big = tris[(area >= 1e-6) & ~tipzone[tris].any(1)]
    cent = body[big].mean(1)
    for v in np.flatnonzero(moved & small):
        x = p[v]
        near = np.argsort(np.linalg.norm(cent - x, axis=1))[:8]
        best = None
        for k in near:
            a, b, c = body[big[k]]
            v0, v1, v2 = b - a, c - a, x - a
            d00, d01, d11, d20, d21 = v0 @ v0, v0 @ v1, v1 @ v1, v2 @ v0, v2 @ v1
            den = max(d00 * d11 - d01 * d01, 1e-18)
            bv, bw = (d11 * d20 - d01 * d21) / den, (d00 * d21 - d01 * d20) / den
            bary = np.clip([1 - bv - bw, bv, bw], 0, None)
            bary /= bary.sum()
            q = bary @ np.stack([a, b, c])
            err = np.linalg.norm(q - x)
            if best is None or err < best[0]:
                best = (err, big[k], bary)
        abc[v], w[v] = best[1], best[2][:2]
    wc = 1 - w.sum(1)
    base = w[:, :1] * body[abc[:, 0]] + w[:, 1:] * body[abc[:, 1]] + wc[:, None] * body[abc[:, 2]]
    n = w[:, :1] * vn[abc[:, 0]] + w[:, 1:] * vn[abc[:, 1]] + wc[:, None] * vn[abc[:, 2]]
    t1, t2, nt = tri_frame(np, body[abc[:, 0]], body[abc[:, 1]], body[abc[:, 2]], n)
    d = (target - base) * moved[:, None]
    return abc, w, np.stack([(d * t1).sum(1), (d * t2).sum(1), (d * nt).sum(1)], 1).astype(np.float32)


# ------------------------------------------------------------------ textures


def mpfb_data():
    import os
    tools = Path(os.environ.get("EVERYBODY_TOOLS") or ROOT / "tools")
    return tools / "blender-user" / "extensions" / ".user" / "user_default" / "mpfb" / "data"


SKIN_TEX = 1536


# hair colour per heritage at the roots (sRGB), for the scalp under the hair; the strands' tint is Figure.hairColor
HAIR_COLOR = {"white": (168, 132, 88), "hispanic": (52, 39, 30), "south-asian": (46, 37, 32), "southeast-asian": (46, 37, 32), "east-asian": (30, 26, 25),
              "black": (38, 32, 29), "grey": (196, 194, 190)}
# which groups' hair lies on each skin texture (children: the young female skin with their own scalp)
SCALP = {("male", "young"): ["male-adult"], ("male", "old"): ["male-senior"],
         ("female", "young"): ["female-adult"], ("female", "old"): ["female-senior"], ("kid", "young"): ["kid-toddler", "kid-child"]}


def vertex_normals(np, p, tris):
    f = np.cross(p[tris[:, 1]] - p[tris[:, 0]], p[tris[:, 2]] - p[tris[:, 0]])
    n = np.zeros_like(p)
    for k in range(3):
        np.add.at(n, tris[:, k], f)
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)


# the fit leaves the skin crinkled between the chin and the chest (MakeHuman's coarse shoulder ridge and the arm
# pressed into the armpit): where it folds or ripples it is smoothed without shrinking (Taubin), the chest centres kept
SKIN_RELAX = (4, 25)
# (and lightly all over that band)
SKIN_EVEN = 0.7


def smooth_skin(np, p, eyes, tris):
    e = np.unique(np.sort(np.concatenate([tris[:, [0, 1]], tris[:, [1, 2]], tris[:, [2, 0]]]), axis=1), axis=0)
    cnt = np.maximum(np.bincount(e.ravel(), minlength=len(p)), 1).astype(np.float64)

    def mean(q):
        acc = np.zeros_like(q)
        np.add.at(acc, e[:, 0], q[e[:, 1]])
        np.add.at(acc, e[:, 1], q[e[:, 0]])
        return acc / (cnt if q.ndim == 1 else cnt[:, None])

    # pairs of triangles across each edge, for the fold between them
    te = np.concatenate([np.sort(tris[:, [0, 1]], 1), np.sort(tris[:, [1, 2]], 1), np.sort(tris[:, [2, 0]], 1)])
    ti = np.tile(np.arange(len(tris)), 3)
    o = np.lexsort((te[:, 1], te[:, 0]))
    te, ti = te[o], ti[o]
    same = (te[1:] == te[:-1]).all(1)
    ta, tb, tv = ti[:-1][same], ti[1:][same], te[:-1][same]

    def fold(q):
        fn = np.cross(q[tris[:, 1]] - q[tris[:, 0]], q[tris[:, 2]] - q[tris[:, 0]])
        fn /= np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-12)
        ang = np.degrees(np.arccos(np.clip((fn[ta] * fn[tb]).sum(1), -1, 1)))
        out = np.zeros(len(q))
        np.maximum.at(out, tv[:, 0], ang)
        np.maximum.at(out, tv[:, 1], ang)
        return out

    U = np.linalg.norm(eyes[eyes[:, 0] > 0].mean(0) - eyes[eyes[:, 0] < 0].mean(0))
    ey, ny = eyes[:, 1].mean(), p[list(NIPPLE_VERTS), 1].mean()
    band = smoothstep(ny - 0.4, ny - 0.3, p[:, 1]) * (1 - smoothstep(ey - 1.9 * U, ey - 1.5 * U, p[:, 1]))
    for i in NIPPLE_VERTS:
        band *= smoothstep(0.04, 0.07, np.linalg.norm(p - p[i], axis=1))
    rounds, passes = SKIN_RELAX
    q = p.copy()
    for _ in range(rounds):
        ripple = np.linalg.norm(mean(mean(q) - q) - (mean(q) - q), axis=1)
        w = np.maximum.reduce([np.full(len(q), SKIN_EVEN), smoothstep(15, 35, fold(q)), smoothstep(0.004, 0.012, ripple)])
        for _ in range(5):
            w = np.maximum(w, 0.5 * w + 0.5 * mean(w))
        w = (w * band)[:, None]
        for _ in range(passes):
            for step in (0.5, -0.53):
                q = q + step * w * (mean(q) - q)
    for _ in range(ARMPIT_FILL[2]):
        q = soften_armpits(np, q, tris)
    return q


# the arm swung down by the fit meets the chest in a step at the front of the armpit (a nub, a pocket below it):
# skin vertices on that step (each side) and (reach, Gaussian width, passes), scene units
ARMPIT_VERTS = (8124, 1436)
ARMPIT_FILL = (0.08, 0.03, 3)


def soften_armpits(np, p, tris):
    """a Gaussian in space (not along the mesh, so arm and chest blend across the gap) round each armpit's front,
    feathered from full at half the reach to none at the reach"""
    reach, sigma, _ = ARMPIT_FILL
    fn = np.linalg.norm(np.cross(p[tris[:, 1]] - p[tris[:, 0]], p[tris[:, 2]] - p[tris[:, 0]]), axis=1)
    area = np.zeros(len(p))
    for k in range(3):
        np.add.at(area, tris[:, k], fn / 6)
    out = p.copy()
    for s in ARMPIT_VERTS:
        d = np.linalg.norm(p - p[s], axis=1)
        near = np.flatnonzero(d < reach + 3 * sigma)
        mine = near[d[near] < reach]
        w = np.exp(-np.sum((p[mine, None] - p[None, near]) ** 2, -1) / sigma ** 2) * area[near]
        k = 1 - smoothstep(0.5, 1.0, d[mine] / reach)[:, None]
        out[mine] += k * (w @ p[near] / w.sum(1, keepdims=True) - p[mine])
    return out


def grow_hair(np, load, body_topo):
    """group → {style: hair.Groom} grown on the group's neutral body"""
    import hair
    tris = body_topo["vmap"][body_topo["index"].reshape(-1, 3)]
    out = {}
    for gid, (_, _, styles, _, _) in GROUPS.items():
        if not styles:
            out[gid] = {}
            continue
        neutral = load(f"{gid}.neutral")
        names = {n for her in HERITAGES for n in hair.styles_for(styles, her)}
        out[gid] = {name: (hair.Sculpt(np, name, neutral["body"], neutral["eyes"], tris, RAW) if hair.STYLES[name].get("sculpt") or hair.STYLES[name].get("character")
                           else hair.Groom(np, name, neutral["body"], neutral["eyes"], tris)) for name in sorted(names)}
        print("HAIR", gid, {k: len(g.pos) for k, g in out[gid].items()})
    return out


def scalp_masks(np, topo, grooms):
    """(sex, young/old) → how much of each skin texel lies under that skin's hair: the scalp takes the hair's colour,
    so the skin between strand cards and the see-through hair of the acupuncture view read as hair, not a bald head"""
    import hair
    from PIL import Image, ImageDraw, ImageFilter
    uv, vmap, index = topo["uv"], topo["vmap"], topo["index"].reshape(-1, 3)
    tris = vmap[index]
    out = {}
    for key, groups in SCALP.items():
        under = np.zeros(int(vmap.max()) + 1)
        for gid in groups:
            got = {k[4:]: v for k, v in np.load(RAW / f"{gid}.neutral.npz").items()}
            head = hair.Head(np, got["body"], got["eyes"], tris)
            for name in GROUPS[gid][2]:
                under = np.maximum(under, head.scalp(got["body"], hair.STYLES[name].get("recede", 0.0)))
        im = Image.new("L", (SKIN_TEX, SKIN_TEX), 0)
        draw = ImageDraw.Draw(im)
        w = under[vmap]
        for tri in index:
            v = w[tri].mean()
            if v > 0.02:
                draw.polygon([(uv[i, 0] * SKIN_TEX, (1 - uv[i, 1]) * SKIN_TEX) for i in tri], fill=int(v * 255))
        # a child's (and a baby's bare) scalp: a soft, lighter wash of hair colour
        soft = key[0] == "kid"
        im = im.filter(ImageFilter.GaussianBlur(12 if soft else 4))
        out[key] = np.asarray(im).astype(np.float32)[..., None] / 255 * (0.35 if soft else 0.85)
    return out


def textures(scalp=None):
    import numpy as np
    from PIL import Image
    import skin_textures
    data = mpfb_data()
    regions = skin_textures.regions(np, RAW, data.parents[3] / "user_default" / "mpfb", SKIN_TEX)

    def skin(age, race, sex):
        f = next((data / "skins" / f"{age}_{race}_{sex}").glob("*diffuse*.png"))
        return np.asarray(Image.open(f).convert("RGB").resize((SKIN_TEX, SKIN_TEX), Image.LANCZOS)).astype(np.float32)

    cache = {}
    for her, (_, blend) in HERITAGES.items():
        # children wear the young female skin (no stubble or body hair)
        for sex, age, name in (("male", "young", "male-young"), ("male", "old", "male-old"), ("female", "young", "female-young"),
                               ("female", "old", "female-old"), ("kid", "young", "kid")):
            src = "female" if sex == "kid" else sex
            px = sum(w * cache.setdefault((age, r, src), skin(age, r, src)) for r, w in blend.items())
            px = skin_textures.finish(np, px, her, name, regions)
            if scalp:
                m = scalp[(sex, age)]
                hair = np.array(HAIR_COLOR["grey" if age == "old" else her], dtype=np.float32)
                lum = px @ np.array([0.3, 0.59, 0.11])
                grain = (lum / max(float(np.median(lum)), 1))[..., None] ** 0.5
                px = px * (1 - 0.92 * m) + hair * grain * 0.92 * m
            px = skin_textures.level_seams(np, px, regions)
            skin_textures.save(np, px, OUT / f"skin-{her}-{name}.jpg")
    for old in list(OUT.glob("brows-*")) + list(OUT.glob("lashes*")) + list(OUT.glob("hair-*")):
        old.unlink()
    for name in sorted({g[3] for g in GROUPS.values()}):
        soft = name in SOFT_BROWS
        alpha_pair(Image.open(data / "eyebrows" / name / f"{name}.png"), f"brows-{name}", 512, grey=True, alpha_gain=1.4 if soft else 1.3,
                   soften=soft)
    for name in sorted({g[4] for g in GROUPS.values()}):
        alpha_pair(Image.open(data / "eyelashes" / name / f"{name}.png"), f"lashes-{name}", 256)
    hair_texture(np)
    sculpt_texture(np)
    # underwear shade across its hem: u = distance from the edge / Figure.hem; the edge rolls a little darker
    u = (np.arange(128) + 0.5) / 128
    shade = 0.8 + 0.2 * smoothstep(0.0, 0.3, u)
    Image.fromarray(np.repeat((np.clip(shade, 0, 1) * 255).astype(np.uint8)[None], 4, 0), "L").save(OUT / "fabric.png", optimize=True)
    eye_texture(np, data)
    for old in list(OUT.glob("skin-*.usdz")):
        old.unlink()


IRIS_R, IRIS_SCALE, PUPIL_SCALE = 60 / 512, 1.1, 0.8


def eye_texture(np, data=None):
    """MakeHuman's brown eye, re-cut: a smaller iris (more white shows), a smaller pupil, a warm mid brown with a darker rim"""
    from PIL import Image
    data = data or mpfb_data()
    n = 512
    src = np.asarray(Image.open(data / "eyes" / "materials" / "brown_eye.png").convert("RGB").resize((n, n), Image.LANCZOS)).astype(np.float32) / 255
    lum = src @ np.array([0.3, 0.59, 0.11])
    yy, xx = np.mgrid[:n, :n].astype(np.float32)
    dark = lum < 0.45
    out = src.copy()
    R = IRIS_R * n
    for side in (xx > yy, xx <= yy):
        m = dark & side
        cy, cx = yy[m].mean(), xx[m].mean()
        r = np.hypot(xx - cx, yy - cy)
        pupil = 0.33 * R
        r_new, p_new, outer = IRIS_SCALE * R, PUPIL_SCALE * 0.33 * R, 2.1 * R
        # target radius → source radius
        rs = np.where(r < p_new, r / p_new * pupil,
                      np.where(r < r_new, pupil + (r - p_new) / (r_new - p_new) * (R - pupil),
                               np.where(r < outer, R + (r - r_new) / (outer - r_new) * (outer - R), r)))
        k = rs / np.maximum(r, 1e-6)
        sx = np.clip(cx + (xx - cx) * k, 0, n - 1).astype(int)
        sy = np.clip(cy + (yy - cy) * k, 0, n - 1).astype(int)
        sel = side & (r < outer)
        out[sel] = src[sy[sel], sx[sel]]
        # iris colour: warm mid brown, lighter toward the pupil, a soft dark limbal ring
        l = out @ np.array([0.3, 0.59, 0.11])
        iris = sel & (r < r_new) & (r > p_new)
        t = ((r - p_new) / (r_new - p_new))[iris]
        tone = np.array([0.40, 0.25, 0.15]) * (0.35 + 1.9 * l[iris])[:, None]
        tone *= (1 - 0.55 * np.clip((t - 0.78) / 0.22, 0, 1) ** 1.5)[:, None]
        out[iris] = tone
        pup = sel & (r <= p_new)
        out[pup] = np.array([0.05, 0.04, 0.035])
    lum = out @ np.array([0.3, 0.59, 0.11])
    white = (lum[..., None] + 0.35 * (out - lum[..., None])) * np.array([0.97, 0.95, 0.93])
    white *= 0.9 / max(float(np.median(lum[lum > 0.45])), 0.3)
    keep = np.zeros((n, n), bool)
    for side in (xx > yy, xx <= yy):
        m = (src @ np.array([0.3, 0.59, 0.11]) < 0.45) & side
        cy, cx = yy[m].mean(), xx[m].mean()
        keep |= side & (np.hypot(xx - cx, yy - cy) < IRIS_SCALE * R + 0.5)
    out = np.where(keep[..., None], out, white)
    Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).save(OUT / "eyes.jpg", quality=88)


def sculpt_texture(np, out=OUT):
    """the sculpted hair's shading: soft streaks down the hair round a light grey (tinted in the app); for seniors,
    salt and pepper: dark and white strands mixed through the grey"""
    from PIL import Image, ImageFilter
    w, h = 1024, 256
    x = np.arange(w)[None, :] / w
    streak = lambda c, sw: np.exp(-(((x - c + 0.5) % 1 - 0.5) / sw) ** 2)
    # (count, darkest, lightest, width lo, width hi): broad soft locks, then finer strands within them
    for name, base, strands in (("hair-sculpt.jpg", 0.88, ((28, -0.045, 0.035, 0.008, 0.03), (110, -0.03, 0.012, 0.0012, 0.003))),
                                ("hair-sculpt-grey.jpg", 0.84, ((28, -0.07, 0.05, 0.008, 0.03), (150, -0.1, 0.03, 0.0012, 0.003),
                                                                (60, 0.02, 0.06, 0.001, 0.002)))):
        rng = np.random.default_rng(5)
        img = np.zeros((1, w))
        for n, lo, hi, w0, w1 in strands:
            for _ in range(n):
                img += rng.uniform(lo, hi) * streak(rng.random(), rng.uniform(w0, w1))
        # plain at both ends: u is mirrored at the front and back of the head, where a streak would smear
        # across the triangles straddling the seam
        img = base + img * smoothstep(0.0, 0.03, x) * smoothstep(1.0, 0.97, x)
        img = np.repeat(img, h, 0)
        # v runs from the crown (top rows, in the light) down to the ends under the head (in shadow)
        f = np.arange(h)[:, None] / h
        img *= 1.03 - 0.03 * smoothstep(0.0, 0.3, f) - 0.14 * smoothstep(0.45, 1.0, f)
        im = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))
        im.convert("RGB").save(out / name, quality=85, optimize=True)


def hair_texture(np):
    """the strand cards' texture: grey strands (the app tints them), darker roots, lighter tips, inner strips shaded"""
    import hair
    from PIL import Image, ImageFilter
    rgb, alpha = hair.strand_texture(np)
    solid = alpha > 0.3
    # see-through texels take the colour of the strands near them (no dark fringes when mipmapped)
    fill = np.stack([np.asarray(Image.fromarray((rgb[..., c] * solid * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6)))
                     for c in range(3)], -1).astype(np.float32) / 255
    cover = np.asarray(Image.fromarray((solid * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6))).astype(np.float32)[..., None] / 255
    fill = np.where(cover > 0.02, fill / np.maximum(cover, 1e-3), rgb[solid].mean(0))
    rgb = np.where(solid[..., None], rgb, fill)
    # thin coverage is the shadowed gap between strands
    rgb = rgb * (0.6 + 0.4 * np.clip(alpha / 0.8, 0, 1))[..., None]
    Image.fromarray(np.clip(rgb * 255, 0, 255).astype(np.uint8)).save(OUT / "hair-strands.jpg", quality=85, optimize=True)
    # a little denser than drawn: mipmaps thin the strands out at a distance and at grazing angles
    Image.fromarray(np.clip(alpha ** 0.75 * 255, 0, 255).astype(np.uint8), "L").save(OUT / "hair-strands-alpha.jpg", quality=90, optimize=True)


# brows drawn as a soft filled shape (no strand outline): the women's
SOFT_BROWS = {"eyebrow002"}


def brow_density(np, a):
    """along each brow (the texture's upper and lower halves): full through the body, fading along the tail"""
    out = np.ones_like(a)
    h = a.shape[0] // 2
    for rows in (slice(0, h), slice(h, None)):
        part = a[rows] > 40
        cols = np.nonzero(part.any(0))[0]
        if not len(cols):
            continue
        x0, x1 = cols.min(), cols.max()
        thick = part.sum(0).astype(float)
        head_left = thick[x0:x0 + (x1 - x0) // 3].mean() > thick[x1 - (x1 - x0) // 3:x1 + 1].mean()
        t = np.clip((np.arange(a.shape[1]) - x0) / max(x1 - x0, 1), 0, 1)
        if not head_left:
            t = 1 - t
        d = 1 - 0.3 * smoothstep(0.75, 1.0, t)
        out[rows] = d[None, :]
    return out


def alpha_pair(im, name, size, grey=False, alpha_gain=1.0, soften=False):
    """colour as JPEG (see-through texels filled with the mean strand colour) + alpha as a grey PNG;
    grey: strand detail only, the large-scale colour and shading evened out, around a light mean for tinting"""
    import numpy as np
    from PIL import Image, ImageFilter
    im = im.convert("RGBA")
    if im.width > size:
        im = im.resize((size, size * im.height // im.width), Image.LANCZOS)
    px = np.asarray(im).astype(np.float32)
    solid = px[..., 3] > 127
    rgb = px[..., :3]
    rgb[~solid] = rgb[solid].mean(0)
    if grey:
        lum = rgb @ np.array([0.3, 0.59, 0.11])
        broad = np.asarray(Image.fromarray(np.clip(lum, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(size / 24))).astype(np.float32)
        detail = np.clip(lum / np.maximum(broad, 8), 0.4, 1.6)
        rgb = np.repeat((200 * (1 + 0.8 * (detail - 1)))[..., None], 3, -1)
    a = px[..., 3]
    if soften:
        # a solid, evenly filled shape with a short soft edge (mid alphas dither on the device): the strands' gaps
        # closed by the blurred coverage, their grain kept faintly in the colour, not the alpha
        blur = lambda x, r: np.asarray(Image.fromarray(np.clip(x, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r))).astype(np.float32) / 255
        cover = blur(a, size / 48)
        fill = smoothstep(0.06, 0.34, cover)
        grain = blur(a, size / 170) - blur(a, size / 40)
        rgb = np.full_like(rgb, 225.0) * (1 + 0.05 * np.clip(grain / 0.3, -1, 1))[..., None]
        a = fill * brow_density(np, fill * 255) * 255 * 0.88
        alpha_gain = 1.0
    Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).save(OUT / f"{name}.jpg", quality=82, optimize=True)
    Image.fromarray(np.clip(a * alpha_gain, 0, 255).astype(np.uint8), "L").save(OUT / f"{name}-alpha.png", optimize=True)


# ------------------------------------------------------------------ reading figure.bin back (points, checks)


def read_figure(np, path=FIGURE):
    raw = path.read_bytes()
    n = int.from_bytes(raw[4:8], "little")
    header = json.loads(raw[12:12 + n])
    payload = zlib.decompress(raw[12 + n:], -15)

    def arr(off, dtype, count):
        return np.frombuffer(payload, dtype=dtype, count=count, offset=off)

    def block(i):
        b = header["blocks"][i]
        q = arr(b["offset"], np.int16, b["count"] * 3).reshape(-1, 3).astype(np.float64)
        p = (q + 32767) * np.array(b["step"]) + np.array(b["lo"])
        return p + (block(b["ref"]) if b["ref"] is not None else 0)

    def piece(name):
        info = header["pieces"][name]
        return (arr(info["vmap"], np.uint32, info["render"]), arr(info["index"], np.uint32, info["triangles"] * 3).reshape(-1, 3))
    return header, block, piece


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    mode = args[0] if args else "pack"
    if mode == "fit":
        fit_all(args[1] if len(args) > 1 else None)
    elif mode == "hair":
        import numpy as np
        for gid in GROUPS:
            if len(args) < 2 or args[1] == gid:
                sculpt_hair(np, gid)
    elif mode == "textures":
        import numpy as np
        body_topo = dict(np.load(RAW / "topo.body.npz"))
        load = lambda n: {k[4:]: v.astype(np.float64) for k, v in np.load(RAW / f"{n}.npz").items()}
        textures(scalp_masks(np, body_topo, grow_hair(np, load, body_topo)))
    else:
        pack()
