# Build a 60% keyboard from box-drawing keycaps. Each unit is 5 chars wide;
# wide keys span multiples of that. Keys touch, so junctions read as a board.
U = 5
def key(label, units=1):
    w = U * units
    inner = w - 2
    top = "╭" + "─" * inner + "╮"
    mid = "│" + label.center(inner) + "│"
    bot = "╰" + "─" * inner + "╯"
    return top, mid, bot, label

ROWS = [
    [("`",1),("1",1),("2",1),("3",1),("4",1),("5",1),("6",1),("7",1),("8",1),("9",1),("0",1),("ß",1),("´",1),("⌫",2)],
    [("⇥",2),("Q",1),("W",1),("E",1),("R",1),("T",1),("Z",1),("U",1),("I",1),("O",1),("P",1),("Ü",1),("+",1),("#",1)],
    [("⇪",2),("A",1),("S",1),("D",1),("F",1),("G",1),("H",1),("J",1),("K",1),("L",1),("Ö",1),("Ä",1),("⏎",2)],
    [("⇧",2),("Y",1),("X",1),("C",1),("V",1),("B",1),("N",1),("M",1),(",",1),(".",1),("-",1),("⇧",3)],
    [("⌃",2),("⌥",2),("⌘",2),("",5),("⌘",2),("⌥",1),("⌃",1)],
]

# keys whose position or legend differs between the German and US layouts
DIFF = {"Z","Y","Ü","Ö","Ä","+","ß","´","#","-"}

lines = []
for row in ROWS:
    tops, mids, bots = "", "", ""
    for label, units in row:
        t, m, b, lab = key(label, units)
        tops += t; bots += b
        if lab in DIFF:
            m = m.replace(lab, f"\x00{lab}\x01", 1)
        mids += m
    lines += [tops, mids, bots]

widths = {len(l.replace('\x00','').replace('\x01','')) for l in lines}
print("row widths:", widths)
art = "\n".join(lines)
open("kbd.txt","w").write(art)
print(art.replace('\x00','').replace('\x01',''))
