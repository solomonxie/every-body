"""Alpha from a white/black render pair, square-cropped to a home tile.
venv/bin/python scripts/render_body/matte.py white.png black.png out.png [top-fraction]"""
import sys

import numpy as np
from PIL import Image

w = np.asarray(Image.open(sys.argv[1]).convert("RGB")).astype(float)
b = np.asarray(Image.open(sys.argv[2]).convert("RGB")).astype(float)
a = np.clip(1 - (w - b).mean(axis=2) / 255, 0, 1)
rgb = b / np.maximum(a[..., None], 1 / 255)
im = Image.fromarray(np.dstack([np.clip(rgb, 0, 255), a * 255]).astype(np.uint8), "RGBA")
W, H = im.size
y0 = int(H * (float(sys.argv[4]) if len(sys.argv) > 4 else 0))
im.crop((0, y0, W, y0 + W)).resize((360, 360), Image.LANCZOS).save(sys.argv[3])
print(sys.argv[3])
