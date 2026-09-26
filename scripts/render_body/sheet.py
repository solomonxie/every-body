"""Side-by-side contact sheet: venv/bin/python scripts/render_body/sheet.py out.png a.png b.png …"""
import sys
from PIL import Image

ims = [Image.open(p) for p in sys.argv[2:]]
out = Image.new("RGB", (sum(i.width for i in ims), max(i.height for i in ims)), "white")
x = 0
for i in ims:
    out.paste(i, (x, 0))
    x += i.width
out.resize((out.width // 2, out.height // 2)).save(sys.argv[1])
