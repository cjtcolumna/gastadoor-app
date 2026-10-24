"""Resize the downloaded App Store icons into the app's assets/banks folder.

Usage: python -I make_bank_icons.py DOWNLOAD_DIR OUT_DIR
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 192
PICK = {"pbcom": "app1.jpg"}  # "PBCOM Mobile" says the bank's name


def fill_white_corners(im, color, reach=0.25):
    """Paints near-white pixels in the four corners with [color]."""
    w, h = im.size
    px = im.load()
    r = int(w * reach)
    for y in range(h):
        for x in range(w):
            near_corner = (x < r or x >= w - r) and (y < r or y >= h - r)
            if near_corner and min(px[x, y][:3]) > 225:
                px[x, y] = color
    return im


def main(src, out):
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    for folder in sorted(Path(src).iterdir()):
        name = PICK.get(folder.name, "app0.jpg")
        im = Image.open(folder / name).convert("RGB")
        if folder.name == "securitybank":
            im = fill_white_corners(im, im.getpixel((im.width // 6, im.height // 2)))
        im = im.resize((SIZE, SIZE), Image.LANCZOS)
        target = out / f"{folder.name}.png"
        im.save(target, optimize=True)
        print(target.name, target.stat().st_size)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
