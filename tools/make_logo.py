#!/usr/bin/env python3
"""Draw the CCAlarm project logo.

The logo is kept as a script rather than only as a binary so colours and
proportions stay adjustable. Run it after changing anything here:

    python3 tools/make_logo.py

The motif is built from World of Warcraft's own vocabulary, so a player reads
it without any text: a shield carrying a cross stands for the two roles the
addon watches -- tank and healer -- and the three stars above are the universal
picture for being stunned.

Colours are not invented. The gold is taken from Media/icon.tga, the red is the
warning colour CCAlarm itself uses by default (Config.lua: r=1, g=0.1, b=0.1).

Everything is drawn at four times the target size and scaled down afterwards.
Pillow has no antialiasing for polygons, so without that supersampling every
diagonal -- the shield's point, all fifteen star edges -- would come out as a
staircase.

Nothing may touch the ring: an earlier draft had the shield and stars butting
into it, which reads as a cropping mistake rather than a design.
"""
from PIL import Image, ImageDraw
import math
import os

KANTE = 400          # CurseForge shows project logos around this size
UEBER = 4            # supersampling factor
W = KANTE * UEBER

DUNKEL = (18, 20, 28, 255)    # background, from the original icon
GOLD   = (255, 184, 32, 255)  # shield, from the original icon
HELL   = (255, 232, 150, 255) # stars, from the original icon
ROT    = (228, 42, 38, 255)   # ring -- CCAlarm's own warning colour


def ring(d, farbe=ROT, staerke=0.055):
    rand = int(W * 0.025)
    d.ellipse([rand, rand, W - rand, W - rand], fill=farbe)
    i = rand + int(W * staerke)
    d.ellipse([i, i, W - i, W - i], fill=DUNKEL)


def stern(d, cx, cy, r, farbe=HELL, zacken=5, dreh=-90):
    pts = []
    for k in range(zacken * 2):
        rad = r if k % 2 == 0 else r * 0.45
        a = math.radians(dreh + k * 180.0 / zacken)
        pts.append((cx + rad * math.cos(a), cy + rad * math.sin(a)))
    d.polygon(pts, fill=farbe)


def schild(d, cx, cy, b, h, farbe):
    l, r = cx - b / 2, cx + b / 2
    o = cy - h / 2
    d.polygon([(l, o), (r, o), (r, o + h * 0.50),
               (cx + b * 0.32, o + h * 0.83), (cx, o + h),
               (cx - b * 0.32, o + h * 0.83), (l, o + h * 0.50)], fill=farbe)


def kreuz(d, cx, cy, laenge, dicke, farbe):
    d.rectangle([cx - dicke / 2, cy - laenge / 2,
                 cx + dicke / 2, cy + laenge / 2], fill=farbe)
    d.rectangle([cx - laenge / 2, cy - dicke / 2,
                 cx + laenge / 2, cy + dicke / 2], fill=farbe)


def zeichnen():
    im = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    ring(d)
    schild(d, W * 0.50, W * 0.635, W * 0.44, W * 0.50, GOLD)
    kreuz(d,  W * 0.50, W * 0.610, W * 0.26, W * 0.090, DUNKEL)
    stern(d, W * 0.268, W * 0.300, W * 0.088)
    stern(d, W * 0.500, W * 0.238, W * 0.075)
    stern(d, W * 0.732, W * 0.300, W * 0.088)
    return im.resize((KANTE, KANTE), Image.LANCZOS)


if __name__ == "__main__":
    wurzel = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ziel = os.path.join(wurzel, "Media", "logo.png")
    zeichnen().save(ziel)
    print(f"{ziel} written ({KANTE}x{KANTE})")
