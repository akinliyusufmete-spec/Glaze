#!/usr/bin/env python3
"""Builds Glaze/Assets.xcassets/AppIcon.appiconset from Design/icon-source.png.

Usage: python3 scripts/make-icon.py   (needs Pillow)

The source is scaled into the standard macOS icon grid (824 px rounded square on a
1024 px canvas, corner radius ~22.4%) with a soft drop shadow, then exported at every
size the asset catalog wants.
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Design" / "icon-source.png"
OUT = ROOT / "Glaze" / "Assets.xcassets" / "AppIcon.appiconset"

CANVAS, BODY = 1024, 824
RADIUS = round(BODY * 0.2237)


def master() -> Image.Image:
    art = Image.open(SOURCE).convert("RGBA")
    side = min(art.size)  # centre-crop to a square first
    left, top = (art.width - side) // 2, (art.height - side) // 2
    art = art.crop((left, top, left + side, top + side)).resize((BODY, BODY), Image.LANCZOS)

    mask = Image.new("L", (BODY * 4, BODY * 4), 0)  # 4x supersampling for smooth corners
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, BODY * 4 - 1, BODY * 4 - 1), RADIUS * 4, fill=255)
    mask = mask.resize((BODY, BODY), Image.LANCZOS)

    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    offset = ((CANVAS - BODY) // 2, (CANVAS - BODY) // 2)

    shadow = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    shadow_mask = Image.new("L", (CANVAS, CANVAS), 0)
    shadow_mask.paste(mask, (offset[0], offset[1] + 10))
    shadow.putalpha(shadow_mask.point(lambda v: int(v * 0.30)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(14))
    canvas = Image.alpha_composite(canvas, shadow)

    body = Image.new("RGBA", (BODY, BODY), (0, 0, 0, 0))
    body.paste(art, (0, 0), mask)
    canvas.alpha_composite(body, offset)
    return canvas


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    big = master()
    images = []
    for points in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            px = points * scale
            name = f"icon_{points}x{points}{'@2x' if scale == 2 else ''}.png"
            big.resize((px, px), Image.LANCZOS).save(OUT / name)
            images.append({"idiom": "mac", "size": f"{points}x{points}", "scale": f"{scale}x", "filename": name})
    (OUT / "Contents.json").write_text(json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    (OUT.parent / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    big.save(ROOT / "Design" / "icon-1024.png")
    print(f"wrote {len(images)} icons to {OUT}")


if __name__ == "__main__":
    main()
