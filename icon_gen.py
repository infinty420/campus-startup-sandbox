# -*- coding: utf-8 -*-
"""Generate HarmonyOS layered app icon: background gradient + foreground glyph."""
import math
from PIL import Image, ImageDraw

S = 1024
OUT = r"C:/Users/infinty/DevEcoStudioProjects/xiaoyuanchuangye/icon_out"

# ---------- background: diagonal indigo -> violet gradient + soft glow circles ----------
W = 256
img = Image.new("RGB", (W, W))
px = img.load()
c1 = (67, 56, 202)    # indigo-700
c2 = (168, 85, 247)   # purple-500
for y in range(W):
    for x in range(W):
        t = (x + y) / (2.0 * (W - 1))
        px[x, y] = (
            int(c1[0] + (c2[0] - c1[0]) * t),
            int(c1[1] + (c2[1] - c1[1]) * t),
            int(c1[2] + (c2[2] - c1[2]) * t),
        )
bg = img.resize((S, S), Image.BICUBIC).convert("RGBA")

overlay = Image.new("RGBA", (S, S), (0, 0, 0, 0))
od = ImageDraw.Draw(overlay)
od.ellipse([620, 80, 1120, 580], fill=(255, 255, 255, 16))
od.ellipse([-180, 620, 320, 1120], fill=(255, 255, 255, 12))
bg = Image.alpha_composite(bg, overlay)

# ---------- foreground: white rising bars + amber trend arrow (transparent bg) ----------
fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(fg)
WHITE = (255, 255, 255, 240)
AMBER = (252, 211, 77, 255)

# three rounded bars, rising left -> right
d.rounded_rectangle([300, 610, 415, 745], radius=30, fill=WHITE)
d.rounded_rectangle([455, 525, 570, 745], radius=30, fill=(255, 255, 255, 255))
d.rounded_rectangle([610, 425, 725, 745], radius=30, fill=WHITE)

# trend polyline
pts = [(305, 545), (485, 420), (575, 472)]
d.line(pts + [(720, 312)], fill=AMBER, width=36, joint="curve")
for p in pts:
    d.ellipse([p[0]-18, p[1]-18, p[0]+18, p[1]+18], fill=AMBER)

# arrowhead at (720,312), direction from (575,472)->(720,312)
dx, dy = 720 - 575, 312 - 472
L = math.hypot(dx, dy)
ux, uy = dx / L, dy / L
tipx, tipy = 720 + ux * 55, 312 + uy * 55      # extend beyond line end
basex, basey = 720 - ux * 15, 312 - uy * 15
perpx, perpy = -uy, ux
head = [
    (tipx, tipy),
    (basex + perpx * 46, basey + perpy * 46),
    (basex - perpx * 46, basey - perpy * 46),
]
d.polygon(head, fill=AMBER)

# ---------- save ----------
import os
os.makedirs(OUT, exist_ok=True)
bg.convert("RGB").save(OUT + "/background.png")
fg.save(OUT + "/foreground.png")

start = bg.copy()
start.alpha_composite(fg)
start.convert("RGB").save(OUT + "/startIcon.png")
print("done", os.listdir(OUT))
