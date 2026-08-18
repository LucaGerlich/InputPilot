# 60% keyboard in box-drawing keycaps. Every label is wrapped in a span so the
# page can light individual keys and swap legends when the layout changes.
U = 5
# German legend -> US legend for the keys that differ between the two layouts
SWAP = {"ß":"-", "´":"=", "Z":"Y", "Ü":"[", "+":"]", "#":"\\",
        "Ö":";", "Ä":"'", "Y":"Z", "-":"/"}

ROWS = [
    [("`",1),("1",1),("2",1),("3",1),("4",1),("5",1),("6",1),("7",1),("8",1),("9",1),("0",1),("ß",1),("´",1),("⌫",2)],
    [("⇥",2),("Q",1),("W",1),("E",1),("R",1),("T",1),("Z",1),("U",1),("I",1),("O",1),("P",1),("Ü",1),("+",1),("#",1)],
    [("⇪",2),("A",1),("S",1),("D",1),("F",1),("G",1),("H",1),("J",1),("K",1),("L",1),("Ö",1),("Ä",1),("⏎",2)],
    [("⇧",2),("Y",1),("X",1),("C",1),("V",1),("B",1),("N",1),("M",1),(",",1),(".",1),("-",1),("⇧",3)],
    [("⌃",2),("⌥",2),("⌘",2),(" ",5),("⌘",2),("⌥",1),("⌃",1)],
]

def esc(c):
    return c.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;")

tops, mids, bots, plain = [], [], [], []
for ri, row in enumerate(ROWS):
    t = m = b = ""
    pm = ""
    for ci, (label, units) in enumerate(row):
        w, inner = U*units, U*units - 2
        t += "╭" + "─"*inner + "╮"
        b += "╰" + "─"*inner + "╯"
        pad = inner - len(label)
        left, right = pad//2, pad - pad//2
        attrs = f' id="k{ri}-{ci}"'
        if label in SWAP:
            attrs += f' data-us="{esc(SWAP[label])}" class="d"'
        cell = f'<i{attrs}>{esc(label)}</i>' if label.strip() else esc(label)
        m += "│" + " "*left + cell + " "*right + "│"
        pm += "│" + " "*left + label + " "*right + "│"
    tops.append(t); mids.append(m); bots.append(b); plain.append(pm)

html = "\n".join(f"{tops[i]}\n{mids[i]}\n{bots[i]}" for i in range(len(ROWS)))
widths = {len(p) for p in plain} | {len(t) for t in tops}
print("row widths (must be one value):", widths)
print("addressable keys:", html.count("<i "), "| swappable:", html.count("data-us"))
open("kbd2.html","w").write(html)
