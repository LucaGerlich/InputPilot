"""Render ANSI (US) and ISO (German) keyboards as dense ASCII art.

Cells are sampled at the same 1:1.67 aspect the browser renders monospace at,
so the board keeps its real proportions and legends get enough vertical
resolution to stay readable.
"""
from PIL import Image, ImageDraw, ImageFont
import json

COLS, CELL_W, CELL_H = 168, 6, 10
W = COLS * CELL_W                 # 1008
UNITS, KEY_ROWS = 15.0, 5
UNIT = W / UNITS                  # 67.2 px
H = int(UNIT * KEY_ROWS)          # 336
ROWS = round(H / CELL_H)          # 34
SS = 3                            # supersample for clean edges
RAMP = " .:-=+*#%@"
FONT_B = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

# (label, units) — ISO gains a key beside left Shift and a tall L-shaped Enter
ANSI = [
    [("`",1),("1",1),("2",1),("3",1),("4",1),("5",1),("6",1),("7",1),("8",1),("9",1),("0",1),("-",1),("=",1),("BACK",2)],
    [("TAB",1.5),("Q",1),("W",1),("E",1),("R",1),("T",1),("Y",1),("U",1),("I",1),("O",1),("P",1),("[",1),("]",1),("\\",1.5)],
    [("CAPS",1.75),("A",1),("S",1),("D",1),("F",1),("G",1),("H",1),("J",1),("K",1),("L",1),(";",1),("'",1),("ENTER",2.25)],
    [("SHIFT",2.25),("Z",1),("X",1),("C",1),("V",1),("B",1),("N",1),("M",1),(",",1),(".",1),("/",1),("SHIFT",2.75)],
    [("CTRL",1.25),("OPT",1.25),("CMD",1.25),("",6.25),("CMD",1.25),("OPT",1.25),("CTRL",1.25),("FN",1.25)],
]
ISO = [
    [("^",1),("1",1),("2",1),("3",1),("4",1),("5",1),("6",1),("7",1),("8",1),("9",1),("0",1),("ß",1),("´",1),("BACK",2)],
    [("TAB",1.5),("Q",1),("W",1),("E",1),("R",1),("T",1),("Z",1),("U",1),("I",1),("O",1),("P",1),("Ü",1),("+",1),("ENTER",1.5)],
    [("CAPS",1.75),("A",1),("S",1),("D",1),("F",1),("G",1),("H",1),("J",1),("K",1),("L",1),("Ö",1),("Ä",1),("#",1),("ENTER",1.25)],
    [("SHIFT",1.25),("<",1),("Y",1),("X",1),("C",1),("V",1),("B",1),("N",1),("M",1),(",",1),(".",1),("-",1),("SHIFT",2.75)],
    [("CTRL",1.25),("OPT",1.25),("CMD",1.25),("",6.25),("CMD",1.25),("OPT",1.25),("CTRL",1.25),("FN",1.25)],
]

def boxes(rows):
    out = []
    for ri, row in enumerate(rows):
        x = 0.0
        for ci, (label, u) in enumerate(row):
            w = u * UNIT
            # the two ENTER halves in ISO share one id so they light together
            kid = "enter" if label == "ENTER" else f"{ri}-{ci}"
            out.append((kid, label, x, ri*UNIT, x+w, ri*UNIT+UNIT))
            x += w
    return out

def render(rows):
    img = Image.new("L", (W*SS, H*SS), 0)
    d = ImageDraw.Draw(img)
    pad, rad = 3*SS, 7*SS
    for kid, label, x0, y0, x1, y1 in boxes(rows):
        d.rounded_rectangle([x0*SS+pad, y0*SS+pad, x1*SS-pad, y1*SS-pad], radius=rad, fill=255)
    # bridge the ISO enter halves so the L reads as one cap
    ents = [b for b in boxes(rows) if b[0] == "enter"]
    if len(ents) == 2:
        (_,_,ax0,ay0,ax1,ay1), (_,_,bx0,by0,bx1,by1) = ents
        d.rectangle([max(ax0,bx0)*SS+pad, ay0*SS+pad, min(ax1,bx1)*SS-pad, by1*SS-pad], fill=255)
    for kid, label, x0, y0, x1, y1 in boxes(rows):
        if not label.strip() or (kid == "enter" and y0 > UNIT*1.5):
            continue
        size = int((46 if len(label) == 1 else 20 if len(label) <= 5 else 17) * SS)
        f = ImageFont.truetype(FONT_B, size)
        bb = d.textbbox((0,0), label, font=f)
        cx, cy = (x0+x1)/2*SS, (y0+y1)/2*SS
        d.text((cx-(bb[2]-bb[0])/2-bb[0], cy-(bb[3]-bb[1])/2-bb[1]), label, font=f, fill=0)
    return img.resize((W, H), Image.LANCZOS)

def grid(img):
    px = img.load()
    g = []
    for r in range(ROWS):
        line = []
        for c in range(COLS):
            tot = n = 0
            for y in range(r*CELL_H, min((r+1)*CELL_H, H)):
                for x in range(c*CELL_W, (c+1)*CELL_W):
                    tot += px[x, y]; n += 1
            v = (tot/n/255.0) ** 2.2 if n else 0
            line.append(RAMP[min(len(RAMP)-1, int(v*len(RAMP)))])
        g.append("".join(line))
    return g

def owners(rows):
    bs = boxes(rows)
    o = []
    for r in range(ROWS):
        cy = r*CELL_H + CELL_H/2
        line = []
        for c in range(COLS):
            cx = c*CELL_W + CELL_W/2
            hit = next((k for k,l,x0,y0,x1,y1 in bs if x0+2 <= cx <= x1-2 and y0+2 <= cy <= y1-2), None)
            line.append(hit)
        o.append(line)
    return o

def keymap(rows):
    m = {}
    for ri, row in enumerate(rows):
        x = 0
        for ci, (label, u) in enumerate(row):
            if len(label) == 1 and label.strip():
                m[label.upper()] = f"{ri}-{ci}"
    return m

data = {"cols": COLS, "rows": ROWS, "layouts": {}}
for name, rows in (("ansi", ANSI), ("iso", ISO)):
    data["layouts"][name] = {"grid": grid(render(rows)), "owner": owners(rows), "keys": keymap(rows)}
json.dump(data, open("kbd3.json","w"))
print(f"{COLS}x{ROWS} cells, aspect {COLS*CELL_W/(ROWS*CELL_H):.2f} (keyboard is 3.00)")
for l in data["layouts"]["iso"]["grid"][12:19]: print(l)
