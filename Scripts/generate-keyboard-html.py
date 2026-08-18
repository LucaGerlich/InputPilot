import json
d = json.load(open("kbd3.json"))
COLS, ROWS = d["cols"], d["rows"]

def esc(t):
    return t.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;")

def markup(layout):
    grid, owner = layout["grid"], layout["owner"]
    lines = []
    for r in range(ROWS):
        out, i = [], 0
        while i < COLS:
            k = owner[r][i]
            j = i
            while j < COLS and owner[r][j] == k:
                j += 1
            seg = esc(grid[r][i:j])
            out.append(seg if k is None else f'<i data-key="{k}">{seg}</i>')
            i = j
        lines.append("".join(out))
    return "\n".join(lines)

arts = {n: markup(l) for n, l in d["layouts"].items()}
keys = {n: l["keys"] for n, l in d["layouts"].items()}
json.dump({"arts": arts, "keys": keys}, open("emit3.json","w"))
for n, a in arts.items():
    print(n, len(a), "bytes,", a.count("<i "), "segments")
