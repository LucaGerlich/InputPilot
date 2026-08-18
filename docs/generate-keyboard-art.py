"""Render a keyboard as dense ASCII art.

Draws the board as a bitmap (bright keycaps, legends punched out), then
samples it per character cell and maps brightness onto a density ramp.
Emits one grid per layout plus the cell->key map, so the page can light
individual caps and swap legends without the art shifting.
"""
from PIL import Image, ImageDraw, ImageFont
import json

COLS, CELL_W, CELL_H = 168, 6, 13          # 120 chars wide, cells 8x16 px
UNITS = 15                                  # keyboard is 15 units wide
W = COLS * CELL_W                           # 960 px
UNIT = W // UNITS                           # 64 px per unit
ROWS_KEYS = 5
H = int(UNIT * ROWS_KEYS * 1.02)            # a touch of breathing room
ROWS = H // CELL_H                          # 20 character rows
RAMP = " .:-=+*#%@"                         # dark -> bright

FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

LAYOUTS = {
    "de": [
        [("`",1),("1",1),("2",1),("3",1),("4",1),("5",1),("6",1),("7",1),("8",1),("9",1),("0",1),("ß",1),("´",1),("<-",2)],
        [("->",2),("Q",1),("W",1),("E",1),("R",1),("T",1),("Z",1),("U",1),("I",1),("O",1),("P",1),("Ü",1),("+",1),("#",1)],
        [("CAP",2),("A",1),("S",1),("D",1),("F",1),("G",1),("H",1),("J",1),("K",1),("L",1),("Ö",1),("Ä",1),("RET",2)],
        [("SHF",2),("Y",1),("X",1),("C",1),("V",1),("B",1),("N",1),("M",1),(",",1),(".",1),("-",1),("SHIFT",3)],
        [("CTL",2),("ALT",2),("CMD",2),("",5),("CMD",2),("ALT",1),("CTL",1)],
    ],
    "us": [
        [("`",1),("1",1),("2",1),("3",1),("4",1),("5",1),("6",1),("7",1),("8",1),("9",1),("0",1),("-",1),("=",1),("<-",2)],
        [("->",2),("Q",1),("W",1),("E",1),("R",1),("T",1),("Y",1),("U",1),("I",1),("O",1),("P",1),("[",1),("]",1),("\\",1)],
        [("CAP",2),("A",1),("S",1),("D",1),("F",1),("G",1),("H",1),("J",1),("K",1),("L",1),(";",1),("'",1),("RET",2)],
        [("SHF",2),("Z",1),("X",1),("C",1),("V",1),("B",1),("N",1),("M",1),(",",1),(".",1),("/",1),("SHIFT",3)],
        [("CTL",2),("ALT",2),("CMD",2),("",5),("CMD",2),("ALT",1),("CTL",1)],
    ],
}

def key_boxes(rows):
    """(key_id, label, x0,y0,x1,y1) for every cap, in pixels."""
    out = []
    for ri, row in enumerate(rows):
        x = 0
        for ci, (label, units) in enumerate(row):
            w = units * UNIT
            out.append((f"{ri}-{ci}", label, x, ri*UNIT, x+w, ri*UNIT+UNIT))
            x += w
    return out

def render(rows):
    img = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(img)
    for kid, label, x0, y0, x1, y1 in key_boxes(rows):
        pad, r = 4, 8
        d.rounded_rectangle([x0+pad, y0+pad, x1-pad, y1-pad], radius=r, fill=255)
        if not label.strip():
            continue
        size = 46 if len(label) == 1 else (22 if len(label) <= 3 else 18)
        try:
            font = ImageFont.truetype(FONT, size)
        except OSError:
            font = ImageFont.load_default()
        bb = d.textbbox((0, 0), label, font=font)
        tx = (x0 + x1)/2 - (bb[2]-bb[0])/2 - bb[0]
        ty = (y0 + y1)/2 - (bb[3]-bb[1])/2 - bb[1]
        d.text((tx, ty), label, font=font, fill=0)   # legend punched out
    return img

def to_grid(img):
    px = img.load()
    grid = []
    for r in range(ROWS):
        line = []
        for c in range(COLS):
            tot = 0
            for y in range(r*CELL_H, (r+1)*CELL_H):
                for x in range(c*CELL_W, (c+1)*CELL_W):
                    tot += px[x, y]
            mean = tot / (CELL_W*CELL_H) / 255.0
            v = mean ** 1.9          # push partial coverage toward the dark end
            line.append(RAMP[min(len(RAMP)-1, int(v * len(RAMP)))])
        grid.append("".join(line))
    return grid

def cell_owner(rows):
    """key id owning each character cell, or None for the gaps between caps."""
    boxes = key_boxes(rows)
    owner = []
    for r in range(ROWS):
        line = []
        cy = r*CELL_H + CELL_H/2
        for c in range(COLS):
            cx = c*CELL_W + CELL_W/2
            hit = None
            for kid, label, x0, y0, x1, y1 in boxes:
                if x0+3 <= cx <= x1-3 and y0+3 <= cy <= y1-3:
                    hit = kid; break
            line.append(hit)
        owner.append(line)
    return owner

grids = {name: to_grid(render(rows)) for name, rows in LAYOUTS.items()}
owner = cell_owner(LAYOUTS["de"])
json.dump({"grids": grids, "owner": owner, "cols": COLS, "rows": ROWS},
          open("ascii_grids.json", "w"))

print(f"grid {COLS}x{ROWS}")
for line in grids["de"][:8]:
    print(line)
