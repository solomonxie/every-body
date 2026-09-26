"""Render the app icon into the asset catalog."""
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"
BG_TOP = (84, 62, 158)
BG_BOTTOM = (40, 28, 92)
FIGURE = (255, 255, 255)
POINT = (255, 209, 102)
TARGET = (78, 203, 113)
SS = 4


def gradient(size):
    img = Image.new("RGB", (size, size))
    draw = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        draw.line([(0, y), (size, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(BG_TOP, BG_BOTTOM)))
    return img


def figure(size, scale=1.0):
    """White person with a gold foot point, dotted pulse path and green target."""
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    u = s * scale / 1024
    cx = s / 2

    def box(x0, y0, x1, y1):
        return [cx + x0 * u, s / 2 + y0 * u, cx + x1 * u, s / 2 + y1 * u]

    d.ellipse(box(-78, -380, 78, -224), fill=FIGURE)
    d.rounded_rectangle(box(-120, -196, 120, 90), radius=70 * u, fill=FIGURE)
    d.rounded_rectangle(box(-210, -186, -140, 60), radius=35 * u, fill=FIGURE)
    d.rounded_rectangle(box(140, -186, 210, 60), radius=35 * u, fill=FIGURE)
    d.rounded_rectangle(box(-112, 60, -16, 380), radius=48 * u, fill=FIGURE)
    d.rounded_rectangle(box(16, 60, 112, 380), radius=48 * u, fill=FIGURE)

    foot, organ = (64, 340), (0, -90)
    for i in range(1, 6):
        t = i / 6
        x = foot[0] + (organ[0] + 170 - foot[0]) * t * (1 - t) * 1.2 + (organ[0] - foot[0]) * t
        y = foot[1] + (organ[1] - foot[1]) * t
        d.ellipse(box(x - 13, y - 13, x + 13, y + 13), fill=POINT)
    d.ellipse(box(foot[0] - 34, foot[1] - 34, foot[0] + 34, foot[1] + 34), fill=POINT)
    d.ellipse(box(organ[0] - 46, organ[1] - 46, organ[0] + 46, organ[1] + 46), fill=TARGET)
    return img.resize((size, size), Image.LANCZOS)


def main():
    icon = gradient(1024).convert("RGBA")
    icon.alpha_composite(figure(1024, 0.82))
    icon.convert("RGB").save(OUT / "icon.png")


if __name__ == "__main__":
    main()
