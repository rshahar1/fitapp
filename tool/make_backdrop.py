"""Build the photo backdrop assets for the app.

Source photo: "Close-up shot of a barbell" by Tima Miroshnichenko
  Page:     https://www.pexels.com/photo/close-up-shot-of-a-barbell-6389516/
  Download: https://images.pexels.com/photos/6389516/pexels-photo-6389516.jpeg?auto=compress&cs=tinysrgb&w=1600
  License:  Pexels License, https://www.pexels.com/license/

Usage:  python tool/make_backdrop.py <source.jpg>

Processing (radii are for a 1600-px-wide source and scale with other widths):
  assets/images/backdrop_fill.jpg
    Gaussian blur r=30 -> brightness 30 % -> 8 % blend toward #1C1C1E
    -> downscale to 540 px wide (aspect kept) -> JPEG q75, progressive.
  assets/images/backdrop_band.jpg
    Gaussian blur r=6 -> brightness 55 % -> 8 % blend toward #1C1C1E
    -> resize to 1080 px wide (aspect kept) -> JPEG q80, progressive.
    No edge feathering is baked in; the app feathers the band at runtime.
"""
import os
import sys

from PIL import Image, ImageEnhance, ImageFilter

FOG = (0x1C, 0x1C, 0x1E)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "images")


def process(src, blur, brightness, fog, width, quality, name):
    scale = src.width / 1600
    img = src.filter(ImageFilter.GaussianBlur(blur * scale))
    img = ImageEnhance.Brightness(img).enhance(brightness)
    img = Image.blend(img, Image.new("RGB", img.size, FOG), fog)
    h = round(img.height * width / img.width)
    img = img.resize((width, h), Image.LANCZOS)
    path = os.path.join(OUT, name)
    img.save(path, "JPEG", quality=quality, progressive=True, optimize=True)
    return path, img.size


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    src = Image.open(sys.argv[1]).convert("RGB")
    os.makedirs(OUT, exist_ok=True)
    total = 0
    for args in (
        (30, 0.30, 0.08, 540, 75, "backdrop_fill.jpg"),
        (6, 0.55, 0.08, 1080, 80, "backdrop_band.jpg"),
    ):
        path, size = process(src, *args)
        n = os.path.getsize(path)
        total += n
        print(f"{os.path.basename(path)}: {size[0]}x{size[1]}, {n} bytes")
    print(f"total: {total} bytes")


if __name__ == "__main__":
    main()
