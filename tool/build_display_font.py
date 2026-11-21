"""Builds the Iron plate display font (feature 034).

Big Shoulders Display (SIL OFL 1.1, no reserved font name) is pinned to static
weights and every lowercase letter is mapped to its capital glyph, so any text
set in the "PlateDisplay" family renders in capitals without changing strings
(semantics and tests keep the original case).

Usage: python3 tool/build_display_font.py <variable.ttf> <out_dir>
Needs fontTools (pip install fonttools).
"""
import sys
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

FAMILY = "PlateDisplay"
WEIGHTS = {800: "ExtraBold", 900: "Black"}


def build(src, out_dir):
    for wght, style in WEIGHTS.items():
        font = instantiateVariableFont(TTFont(src), {"wght": wght})
        for table in font["cmap"].tables:
            if not table.isUnicode():
                continue
            cmap = table.cmap
            for cp in list(cmap):
                upper = chr(cp).upper()
                if len(upper) == 1 and ord(upper) != cp and ord(upper) in cmap:
                    cmap[cp] = cmap[ord(upper)]
        names = font["name"]
        full = f"{FAMILY} {style}"
        ps = f"{FAMILY}-{style}"
        for rec in names.names:
            if rec.nameID in (1, 16):
                rec.string = FAMILY
            elif rec.nameID in (2, 17):
                rec.string = style
            elif rec.nameID == 4:
                rec.string = full
            elif rec.nameID == 6:
                rec.string = ps
            elif rec.nameID == 3:
                rec.string = f"{ps};fitapp"
        font["OS/2"].usWeightClass = wght
        font.save(f"{out_dir}/{ps}.ttf")


if __name__ == "__main__":
    build(sys.argv[1], sys.argv[2])
