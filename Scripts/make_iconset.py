#!/usr/bin/env python3
"""Turn the AI-generated icon source (images/icon-source.png) into the macOS
AppIcon set: detect the orange squircle, round its corners to transparency, add
the standard margin, and emit every size + Contents.json.
"""

import json
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(__file__))
SRC = os.path.join(ROOT, "images/icon-source.png")
OUT_DIR = os.path.join(
    ROOT, "Sources/CCExportApp/Resources/Assets.xcassets/AppIcon.appiconset"
)
SIZES = [1024, 512, 256, 128, 64, 32, 16]
WORK = 1024
MARGIN = 0.04            # transparent margin around the squircle
TRIM = 0.03             # trim the squircle edge inward to drop the baked shadow
CORNER = 0.2235          # squircle corner radius as a fraction of its side


def orange_bbox(rgb):
    """Bounding box of the terracotta squircle (orange pixels)."""
    px = rgb.load()
    w, h = rgb.size
    minx, miny, maxx, maxy = w, h, 0, 0
    step = 2
    for y in range(0, h, step):
        for x in range(0, w, step):
            r, g, b = px[x, y]
            if r > 150 and r - b > 55 and r - g > 18 and g > 60:
                minx, miny = min(minx, x), min(miny, y)
                maxx, maxy = max(maxx, x), max(maxy, y)
    return minx, miny, maxx, maxy


def main():
    src = Image.open(SRC).convert("RGB")
    minx, miny, maxx, maxy = orange_bbox(src)
    cx, cy = (minx + maxx) / 2, (miny + maxy) / 2
    side = max(maxx - minx, maxy - miny) + 2
    half = side / 2
    crop = src.crop((round(cx - half), round(cy - half),
                     round(cx + half), round(cy + half))).resize((WORK, WORK), Image.LANCZOS)

    # Round the squircle corners to transparency, trimming the edge inward a
    # little so the AI's baked drop shadow / outer rim is cut away cleanly.
    mask = Image.new("L", (WORK, WORK), 0)
    pad = round(WORK * TRIM)
    ImageDraw.Draw(mask).rounded_rectangle(
        [pad, pad, WORK - 1 - pad, WORK - 1 - pad],
        radius=round((WORK - 2 * pad) * CORNER), fill=255
    )
    squircle = crop.convert("RGBA")
    squircle.putalpha(mask)

    # Place onto a transparent canvas with margin.
    inner = round(WORK * (1 - 2 * MARGIN))
    canvas = Image.new("RGBA", (WORK, WORK), (0, 0, 0, 0))
    resized = squircle.resize((inner, inner), Image.LANCZOS)
    off = (WORK - inner) // 2
    canvas.paste(resized, (off, off), resized)

    os.makedirs(OUT_DIR, exist_ok=True)
    for size in SIZES:
        canvas.resize((size, size), Image.LANCZOS).save(
            os.path.join(OUT_DIR, f"appicon_{size}.png")
        )

    with open(os.path.join(OUT_DIR, "Contents.json"), "w") as f:
        json.dump({
            "images": [
                {"filename": f"appicon_{s}.png", "idiom": "mac",
                 "size": f"{s}x{s}", "scale": "1x"} for s in SIZES
            ],
            "info": {"author": "xcode", "version": 1},
        }, f, indent=2)

    catalog = os.path.dirname(os.path.dirname(OUT_DIR))
    with open(os.path.join(catalog, "Contents.json"), "w") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)

    print(f"squircle bbox=({minx},{miny},{maxx},{maxy}) → {OUT_DIR}")


if __name__ == "__main__":
    main()
