"""Render docs/og-card.png, the 1280x640 link-preview card, from the hero art.

    python3 Scripts/generate-keyboard-art.py        # writes kbd3.json here
    python3 Scripts/generate-og-card.py kbd3.json docs/og-card.png

Draws the ISO keyboard as ASCII in the site's palette, so the card changes
with the art instead of being redrawn by hand.
"""
import json
import sys

from PIL import Image, ImageDraw, ImageFont

src, out = sys.argv[1], sys.argv[2]
grid = json.load(open(src))["layouts"]["iso"]["grid"]

W, H = 1280, 640
BG, FG, DIM, ORANGE = "#08090B", "#D6DAE1", "#727A86", "#FF6B2C"
MONO = "/System/Library/Fonts/Menlo.ttc"

img = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(img)

title = ImageFont.truetype(MONO, 64, index=1)  # Menlo Bold
tagline = ImageFont.truetype(MONO, 26)
footer = ImageFont.truetype(MONO, 20)
art = ImageFont.truetype(MONO, 10)

d.text((80, 64), "InputPilot", font=title, fill=ORANGE)
d.text((82, 146), "The layout follows the keyboard.", font=tagline, fill=FG)

# The art was sampled at the browser's 1:1.67 monospace aspect; keep it.
char_w = art.getlength("@")
line_h = round(char_w * 1.67)
x0 = (W - char_w * len(grid[0])) / 2
for i, row in enumerate(grid):
    d.text((x0, 212 + i * line_h), row, font=art, fill=DIM)

d.text((82, H - 58), "macOS menu bar app · free · open source · inputpilot.lucagerlich.dev",
       font=footer, fill=DIM)
img.save(out, optimize=True)
