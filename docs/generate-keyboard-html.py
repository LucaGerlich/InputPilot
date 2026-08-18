import json
d = json.load(open("ascii_grids.json"))
de, us, owner = d["grids"]["de"], d["grids"]["us"], d["owner"]
ROWS, COLS = d["rows"], d["cols"]

def esc(t):
    return t.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;")

out = []
for r in range(ROWS):
    line, i = [], 0
    while i < COLS:
        k = owner[r][i]
        j = i
        while j < COLS and owner[r][j] == k:
            j += 1
        seg_de, seg_us = de[r][i:j], us[r][i:j]
        if k is None:
            line.append(esc(seg_de))
        else:
            attr = f' data-key="{k}"'
            if seg_us != seg_de:
                attr += f' data-us="{esc(seg_us)}"'
            line.append(f"<i{attr}>{esc(seg_de)}</i>")
        i = j
    out.append("".join(line))
art = "\n".join(out)

# legend -> key id, per layout, for the typing animation
from asciikbd import LAYOUTS
maps = {}
for name, rows in LAYOUTS.items():
    m = {}
    for ri, row in enumerate(rows):
        for ci, (label, _) in enumerate(row):
            if len(label) == 1 and label.strip():
                m[label.upper()] = f"{ri}-{ci}"
    maps[name] = m

open("art.html","w").write(art)
open("keymap.json","w").write(json.dumps(maps))
print("art:", len(art), "bytes |", art.count("<i "), "key segments |",
      art.count("data-us"), "swap segments")
print("keymap de sample:", list(maps["de"].items())[:6])
