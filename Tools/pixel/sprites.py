"""The cast and the foes as hand-built pixel art, drawn at their native size with a fixed night palette.

Shapes are shaded per pixel from a fixed light (upper left, a little in front) and banded into each material's
ramp, the way pixel artists shade by hand; faces, crowns, leaves and the bead are placed pixel by pixel on top.
Every frame is written to Game/Resources/Pixel/<name>.png.

  python3 Tools/pixel/sprites.py [--sheet preview.png]
"""
import math, os, sys
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "Game", "Resources", "Pixel")

def hexc(h, a=255):
    h = h.lstrip("#"); return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)

# ramps: darkest → lightest
RAMP = {
    "otto": ["#101c3c", "#1c3570", "#274f9e", "#3a6cc6", "#6b98e6"],
    "ottoLow": ["#0c1430", "#16275a", "#1e3c7c", "#2a5296", "#4a76b8"],
    "moss": ["#16301f", "#25492f", "#3a6a44", "#55905c", "#86bb84"],
    "mint": ["#2a6a52", "#46a07a", "#7fd3a8", "#bdf0d2"],
    "mosto": ["#24134a", "#3c2478", "#5a3cb0", "#7c5fd8", "#a68cf2"],
    "wing": ["#170c30", "#281850", "#3a2470"],
    "shade": ["#040509", "#0a0c16", "#141828", "#20263c"],
    "stone": ["#2c2a36", "#4a4658", "#6c6880", "#9a96aa", "#c4c0d0"],
    "moth": ["#140f22", "#241a3a", "#3a2c56"],
    "maw": ["#05060b", "#0c0e1a", "#171a2c", "#242a42"],
}
INK = hexc("#0b0a18"); WHITE = hexc("#f4f0e8"); CREAM = hexc("#f1e3c4"); PUPIL = hexc("#0e0d1a")
GOLD = [hexc(c) for c in ("#a86a18", "#e8a020", "#ffd36b", "#fff1c4")]
BLUSH = hexc("#e892a4"); FANG = hexc("#fbf6ec"); EYE_COLD = hexc("#cfd6ff"); EMBER = hexc("#ff7a30")
L = (-0.55, -0.62, 0.56)
ln = math.sqrt(sum(c * c for c in L)); L = tuple(c / ln for c in L)

class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[None] * w for _ in range(h)]
    def put(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h and c is not None: self.px[y][x] = c
    def get(self, x, y):
        return self.px[y][x] if 0 <= x < self.w and 0 <= y < self.h else None
    def blob(self, cx, cy, rx, ry, ramp, top=None, bottom_flat=None, squash=1.0, test=None):
        """A shaded rounded body: an ellipse (optionally flattened at the bottom), banded into the ramp."""
        cols = [hexc(c) for c in RAMP[ramp]] if isinstance(ramp, str) else ramp
        for y in range(self.h):
            for x in range(self.w):
                dx = (x + 0.5 - cx) / rx; dy = (y + 0.5 - cy) / ry
                if bottom_flat is not None and y + 0.5 > bottom_flat: continue
                if dx * dx + dy * dy > 1: continue
                if test and not test(x, y): continue
                nz = math.sqrt(max(0.0, 1 - dx * dx - dy * dy))
                d = -dx * L[0] - dy * L[1] + nz * L[2]
                d = max(0.0, d)
                k = d ** 0.9 * (len(cols) - 0.01)
                # a rim of reflected night light on the lower right edge
                if dx * dx + dy * dy > 0.82 and dx > 0.15 and dy > 0.0: k = max(k, 1.2)
                self.put(x, y, cols[min(len(cols) - 1, int(k))])
    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(self.h):
            for x in range(self.w):
                dx = (x + 0.5 - cx) / rx; dy = (y + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1: self.put(x, y, c)
    def line(self, pts, c):
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
            for i in range(n + 1):
                t = i / n; self.put(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, c)
    def outline(self, c=INK):
        src = [row[:] for row in self.px]
        for y in range(self.h):
            for x in range(self.w):
                if src[y][x] is None and any(0 <= x + dx < self.w and 0 <= y + dy < self.h and src[y + dy][x + dx] is not None
                                              for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    self.px[y][x] = c
    def image(self):
        im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x]: im.putpixel((x, y), self.px[y][x])
        return im

# ---------------------------------------------------------------- the cast

def otto(frame=0, blink=False, look=0, bob=0, glow=True, sleep=False):
    """Otto: a tall dome in deep blue, one big heavy-lidded eye, a thin stalk curling over to a gold bead."""
    c = Canvas(22, 32)
    by = 30 - bob
    top = by - 22
    def body(x, y): return True
    # the dome: a tall rounded body, the lower third a deeper blue
    c.blob(11, top + 11, 7.5, 12, "otto", bottom_flat=by - 1)
    for y in range(by - 8, by - 1):
        for x in range(22):
            if c.get(x, y) is not None:
                shade = RAMP["ottoLow"][min(4, max(0, int((14 - abs(x - 9)) / 3.2)))]
                c.put(x, y, hexc(shade))
    # feet
    for fx in (7, 13): c.ellipse(fx + 0.5, by - 0.5, 2, 1.2, hexc("#141a30"))
    # the eye: big, white, heavy lid (Otto is always tired)
    ey = top + 9
    if sleep or blink:
        c.line([(6, ey + 1), (8, ey + 2), (12, ey + 2), (14, ey + 1)], hexc("#0e1838"))
    else:
        c.ellipse(10.5, ey + 1, 4.2, 3.2, WHITE)
        # the lid: the top of the eye in body colour, a dark crease under it
        for x in range(5, 17):
            for y in range(ey - 3, ey):
                if c.get(x, y) == WHITE: c.put(x, y, hexc(RAMP["otto"][2]))
        c.line([(6.5, ey - 0.2), (14.5, ey - 0.2)], hexc("#0e1838"))
        px_ = 10 + look
        for dx in range(2):
            for dy in range(2): c.put(px_ + dx, ey + dy, PUPIL)
        c.put(px_, ey, hexc("#ffffff"))
    # the bag under the eye
    c.line([(7, ey + 5), (9, ey + 6), (12, ey + 6), (14, ey + 5)], hexc("#16275a"))
    # the stalk, curling up and over to the left, and the bead
    sway = [0, 1, 0, -1][frame % 4] * 0.5
    stalk = [(12, top + 0.5), (13, top - 2), (12, top - 4.5), (9, top - 5.5), (6 + sway, top - 4)]
    c.line(stalk, hexc("#2a4e98"))
    bx, by_ = 5 + sway, top - 2.5
    if glow:
        for (dx, dy, k) in ((0, 0, 3), (1, 0, 2), (0, 1, 2), (1, 1, 1)):
            c.put(bx + dx, by_ + dy, GOLD[k])
    else:
        for dx in range(2):
            for dy in range(2): c.put(bx + dx, by_ + dy, hexc("#4a4a5a"))
    c.outline()
    return c

def moss(frame=0, blink=False, look=1, squash=0, mine=False):
    """Moss: a plump moss-green pebble, two big curious eyes, a mint sprig with two pairs of leaves."""
    c = Canvas(20, 22)
    base = 20
    rx, ry = 7.6 + squash * 0.6, 7.0 - squash * 0.8 + (1.2 if mine else 0)
    cy = base - ry * 0.95
    c.blob(10, cy, rx, ry, "moss", bottom_flat=base)
    for fx in (6, 13): c.ellipse(fx + 0.5, base + 0.3, 1.8, 1.0, hexc("#14261a"))
    top = int(cy - ry)
    # sprig: stem, a pair of big leaves, a small young pair at the tip (closed up tight when it's "mine!")
    c.line([(10, top + 1), (10, top - 3)], hexc(RAMP["mint"][0]))
    m = [hexc(x) for x in RAMP["mint"]]
    if mine:
        for (x, y, k) in ((9, top - 4, 2), (11, top - 4, 2), (9, top - 5, 3), (11, top - 5, 3), (10, top - 6, 3), (10, top - 4, 1)): c.put(x, y, m[k])
    else:
        for (x, y, k) in ((7, top - 2, 1), (8, top - 2, 2), (8, top - 3, 3), (6, top - 1, 1),
                          (12, top - 2, 2), (13, top - 2, 1), (12, top - 3, 3), (14, top - 1, 1),
                          (9, top - 4, 2), (11, top - 4, 2), (9, top - 5, 3), (11, top - 5, 3)):
            c.put(x, y, m[k])
    ey = int(cy - 1)
    for ex in (6, 12):
        if blink:
            c.line([(ex, ey + 1), (ex + 2, ey + 1)], hexc("#10241a"))
        else:
            for dx in range(3):
                for dy in range(3): c.put(ex + dx, ey + dy, WHITE)
            p = ex + (1 if look == 0 else 2 if look > 0 else 0)
            c.put(p, ey + 1, PUPIL); c.put(p, ey + 2, PUPIL)
            if look == 0: c.put(ex + 1, ey + 2, PUPIL)
    for bx in (5, 14): c.put(bx, ey + 4, BLUSH)
    c.outline()
    return c

def mosto(frame=0, carry=False, caught=False):
    """Mosto: a round violet imp — one eye Moss's, one Otto's, a crooked gold crown, cream horns, bat wings, a fang."""
    c = Canvas(30, 26)
    cx, cy = 15, 15
    flap = frame % 2
    # wings behind
    w = [hexc(x) for x in RAMP["wing"]]
    for s in (-1, 1):
        tipy = cy - 6 - (2 if flap else -1)
        pts = [(cx + s * 7, cy - 1), (cx + s * 12, tipy), (cx + s * 13, cy + 1), (cx + s * 10, cy + 2)]
        for t in range(40):
            for u in range(40):
                a, b = t / 39, u / 39
                x = pts[0][0] + (pts[1][0] - pts[0][0]) * a + (pts[3][0] - pts[0][0]) * b * (1 - a)
                y = pts[0][1] + (pts[1][1] - pts[0][1]) * a + (pts[3][1] - pts[0][1]) * b * (1 - a)
                c.put(x, y, w[1] if b < 0.6 else w[2])
    c.blob(cx, cy, 8.4, 7.6, "mosto", bottom_flat=cy + 7)
    for fx in (11, 18): c.ellipse(fx + 0.5, cy + 7.2, 1.8, 1.0, hexc("#1c1038"))
    # horns
    for s in (-1, 1):
        c.line([(cx + s * 5, cy - 6), (cx + s * 7, cy - 9), (cx + s * 6, cy - 11)], CREAM)
        c.put(cx + s * 6, cy - 8, CREAM)
    # the crooked crown
    cr = [GOLD[2], GOLD[1], GOLD[3]]
    for x in range(cx - 3, cx + 3): c.put(x, cy - 8 + (1 if x > cx else 0), GOLD[1])
    for (x, y) in ((cx - 3, cy - 9), (cx - 1, cy - 10), (cx + 1, cy - 9), (cx + 2, cy - 9)): c.put(x, y, GOLD[2])
    c.put(cx - 1, cy - 9, GOLD[3])
    # eyes: the left one Moss's (round, cream ring), the right one Otto's (lidded); angry brows
    ey = cy - 2
    if caught:
        for (ex) in (cx - 5, cx + 2):
            c.line([(ex, ey), (ex + 2, ey + 2)], PUPIL); c.line([(ex + 2, ey), (ex, ey + 2)], PUPIL)
    else:
        for (ex, lid) in ((cx - 5, False), (cx + 2, True)):
            for dx in range(3):
                for dy in range(3): c.put(ex + dx, ey + dy, CREAM)
            c.put(ex + 1, ey + 1, PUPIL); c.put(ex + 1, ey + 2, PUPIL)
            if lid: c.line([(ex, ey), (ex + 2, ey)], hexc(RAMP["mosto"][2]))
        c.line([(cx - 6, ey - 2), (cx - 3, ey - 1)], hexc("#24134a"))
        c.line([(cx + 5, ey - 2), (cx + 2, ey - 1)], hexc("#24134a"))
    # the mouth: a zigzag grin and one fang
    my = cy + 3
    c.line([(cx - 2, my), (cx - 1, my + 1), (cx, my), (cx + 1, my + 1), (cx + 2, my)], hexc("#1a0a30"))
    c.put(cx + 1, my + 2, FANG)
    for bx in (cx - 6, cx + 6): c.put(bx, cy + 1, BLUSH)
    # the tail and its spade
    c.line([(cx + 8, cy + 4), (cx + 11, cy + 3), (cx + 12, cy)], hexc(RAMP["mosto"][3]))
    for (x, y) in ((cx + 11, cy - 1), (cx + 12, cy - 2), (cx + 13, cy - 1), (cx + 12, cy - 1)): c.put(x, y, CREAM)
    if carry:   # the stolen light in his arms
        for (dx, dy, k) in ((0, 0, 3), (1, 0, 2), (0, 1, 2), (1, 1, 2), (-1, 0, 1), (2, 1, 1), (0, -1, 1), (1, 2, 1)):
            c.put(cx - 1 + dx, cy + 4 + dy, GOLD[k])
    c.outline()
    return c

# ---------------------------------------------------------------- foes

def shade(frame=0, kind="shade"):
    c = Canvas(16, 18)
    wob = [0, 1][frame % 2]
    c.blob(8, 10 - wob * 0.5, 6.2, 7 + wob * 0.5, "shade", bottom_flat=17)
    # a ragged hem
    for x in range(3, 13):
        if (x + frame) % 3 == 0: c.put(x, 17, None)
    eye = EMBER if kind == "fang" else EYE_COLD
    ey = 8
    for ex in (5, 9):
        c.put(ex, ey, eye); c.put(ex + 1, ey, eye)
    if kind == "fang":
        c.line([(6, 12), (9, 12)], hexc("#3a0a12")); c.put(6, 13, FANG); c.put(9, 13, FANG)
        for x in (4, 7, 10): c.put(x, 2 + (x % 2), hexc("#14080c")); c.put(x, 3, hexc("#14080c"))
    c.outline(hexc("#000000"))
    return c

def shell(frame=0):
    c = Canvas(18, 18)
    c.blob(9, 11, 6.5, 6, "shade", bottom_flat=17)
    c.blob(9, 8, 8, 5.5, "stone", bottom_flat=10.5)
    for (x, y) in ((6, 5), (7, 6), (11, 4), (12, 5), (9, 7)): c.put(x, y, hexc("#2c2a36"))
    for ex in (6, 10): c.put(ex, 12, EYE_COLD); c.put(ex + 1, 12, EYE_COLD)
    c.outline(hexc("#000000"))
    return c

def moth(frame=0):
    c = Canvas(20, 14)
    up = frame % 2
    m = [hexc(x) for x in RAMP["moth"]]
    for s in (-1, 1):
        c.ellipse(10 + s * 5, 6 - up, 4.5, 3.6 + up * 0.6, m[1])
        c.ellipse(10 + s * 4, 10, 3, 2.2, m[2])
        c.put(10 + s * 5, 6 - up, hexc("#e8e2ff")); c.put(10 + s * 6, 6 - up, hexc("#bfb4ff"))
    c.ellipse(10, 8, 1.6, 4, m[2])
    c.put(9, 5, hexc("#ffd27a")); c.put(11, 5, hexc("#ffd27a"))
    c.outline(hexc("#000000"))
    return c

def maw(frame=0, glow=0):
    c = Canvas(44, 42)
    c.blob(22, 22, 19, 18, "maw", bottom_flat=40)
    for s in (-1, 1): c.line([(22 + s * 10, 6), (22 + s * 13, 1), (22 + s * 14, 4)], hexc("#0c0e1a"))
    # eyes and a long jagged mouth
    for ex in (14, 27):
        for dx in range(3): c.put(ex + dx, 15, hexc("#ffe2a0")); c.put(ex + dx, 16, hexc("#ffd27a"))
    for x in range(14, 31): c.put(x, 21, hexc("#2a0810"))
    for x in range(15, 30, 3): c.put(x, 22, FANG); c.put(x + 1, 22, FANG)
    # the belly window: the stolen light glows brighter the more it has swallowed
    belly = [hexc("#3a2010"), hexc("#a85a20"), hexc("#ffb050"), hexc("#ffe0a0")][min(3, glow)]
    c.ellipse(22, 30, 7.5 - frame * 0.3, 5.5, hexc("#120a10"))
    c.ellipse(22, 30, 6.4 - frame * 0.3, 4.5, belly)
    if glow >= 2: c.ellipse(21, 29, 2.5, 1.6, hexc("#fff4d0"))
    c.outline(hexc("#000000"))
    return c

def mote(frame=0):
    c = Canvas(5, 5)
    k = [3, 2, 3, 2][frame % 4]
    c.put(2, 2, GOLD[k]);
    for (x, y) in ((2, 1), (1, 2), (3, 2), (2, 3)): c.put(x, y, GOLD[1] if frame % 2 else GOLD[2])
    return c

# ---------------------------------------------------------------- write


# ---------------------------------------------------------------- the townsfolk (portraits for the talk box)

def eyes(c, y, xs, color=PUPIL, shine=True):
    for x in xs:
        c.put(x, y, color); c.put(x, y + 1, color)
        if shine: c.put(x, y - 1, hexc("#ffffff"))

def hank():
    """Hank, the old gatekeeper: a squat grey boulder of a man, flat cap, a big white moustache, cross brows."""
    c = Canvas(22, 24)
    c.blob(11, 15, 9, 8.5, "stone", bottom_flat=23)
    for x in range(3, 20):
        for y in range(4, 9):
            if (x - 11) ** 2 / 64 + (y - 8.5) ** 2 / 16 <= 1: c.put(x, y, hexc("#3a2c30") if y > 5 else hexc("#4e3c40"))
    c.line([(2, 9), (20, 9)], hexc("#2a1e22"))
    eyes(c, 12, (8, 14), shine=False)
    c.line([(6, 10.5), (9, 11.2)], INK); c.line([(13, 11.2), (16, 10.5)], INK)
    for (x, y) in ((7, 16), (8, 15), (9, 15), (10, 16), (12, 16), (13, 15), (14, 15), (15, 16), (11, 15), (6, 17), (16, 17)):
        c.put(x, y, hexc("#eeeaf0"))
    c.put(11, 14, hexc("#6c6880"))
    c.outline(); return c

def dora():
    """Dora: a little cream round with two short braids, holding up her paper lantern."""
    c = Canvas(22, 24)
    c.blob(9, 16, 7, 7, [hexc(x) for x in ("#6a5048", "#a07c6a", "#d6b49a", "#f0d8c0")], bottom_flat=23)
    for (x, y) in ((2, 13), (2, 14), (3, 15), (15, 13), (16, 14), (15, 15)): c.put(x, y, hexc("#5a3020"))
    for x in range(4, 15):
        for y in range(9, 12):
            if (x - 9) ** 2 / 30 + (y - 12) ** 2 / 9 <= 1: c.put(x, y, hexc("#6a3a24"))
    eyes(c, 15, (7, 11))
    c.put(5, 18, BLUSH); c.put(13, 18, BLUSH); c.put(9, 18, hexc("#7a3a30"))
    # the lantern on a stick
    c.line([(15, 18), (18, 8)], hexc("#4a3428"))
    for y in range(8, 15):
        w = 3 if 9 < y < 13 else 2
        for x in range(18 - w + 1, 18 + w): c.put(x, y, hexc("#e8d8c0") if (x + y) % 3 else hexc("#c8b8a0"))
    c.put(18, 7, hexc("#4a3428"))
    c.outline(); return c

def lynn():
    """Lynn, who mends nets on the dock: a tall teal pebble in a knotted headscarf, a loop of net over her arm."""
    c = Canvas(22, 24)
    c.blob(11, 14, 8, 9.5, [hexc(x) for x in ("#10302e", "#1c4a46", "#2c6a62", "#4a8e84", "#7ab8aa")], bottom_flat=23)
    for x in range(2, 21):
        for y in range(3, 10):
            if (x - 11) ** 2 / 80 + (y - 9) ** 2 / 30 <= 1 and y < 10: c.put(x, y, hexc("#b8503a") if (x + y) % 4 else hexc("#d87050"))
    c.put(19, 9, hexc("#b8503a")); c.put(20, 10, hexc("#b8503a")); c.put(20, 8, hexc("#d87050"))
    eyes(c, 13, (8, 13))
    c.line([(7, 11.5), (9, 11)], INK); c.line([(12, 11), (14, 11.5)], INK)
    c.put(10, 17, hexc("#0e2422")); c.put(11, 17, hexc("#0e2422"))
    for (x, y) in ((3, 18), (4, 20), (5, 18), (6, 20), (7, 18), (4, 19), (6, 19)): c.put(x, y, hexc("#d6c8a0"))
    c.outline(); return c

def jobs():
    for f in range(4):
        yield f"otto_idle_{f}", otto(f, bob=1 if f in (1, 2) else 0)
    yield "otto_blink", otto(0, blink=True)
    yield "otto_sleep", otto(0, sleep=True, glow=False)
    yield "otto_dim", otto(0, glow=False)
    for f in range(4):
        yield f"moss_run_{f}", moss(f, look=1, squash=[0, 1, 0, -1][f])
    for f in range(2):
        yield f"moss_idle_{f}", moss(f, look=0, squash=f)
    yield "moss_blink", moss(0, blink=True)
    yield "moss_mine", moss(0, mine=True, look=0)
    for f in range(2):
        yield f"mosto_fly_{f}", mosto(f)
        yield f"mosto_carry_{f}", mosto(f, carry=True)
    yield "mosto_caught", mosto(0, caught=True)
    for f in range(2):
        yield f"shade_{f}", shade(f)
        yield f"fang_{f}", shade(f, kind="fang")
        yield f"shell_{f}", shell(f)
        yield f"moth_{f}", moth(f)
        for g in range(4): yield f"maw_{f}_{g}", maw(f, g)
    for f in range(4): yield f"mote_{f}", mote(f)
    yield "npc_hank", hank()
    yield "npc_dora", dora()
    yield "npc_lynn", lynn()

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    ims = []
    for name, cv in jobs():
        im = cv.image(); im.save(os.path.join(OUT, name + ".png")); ims.append((name, im))
    if "--sheet" in sys.argv:
        path = sys.argv[sys.argv.index("--sheet") + 1]
        W = sum(i.width + 3 for _, i in ims[:16]); rows = (len(ims) + 15) // 16
        H = max(i.height for _, i in ims) + 3
        sheet = Image.new("RGBA", (W + 60, H * rows), hexc("#1f2847"))
        for k, (_, i) in enumerate(ims):
            x = sum(j.width + 3 for _, j in ims[(k // 16) * 16:k]); y = (k // 16) * H
            sheet.alpha_composite(i, (x + 2, y + 2))
        sheet.resize((sheet.width * 5, sheet.height * 5), Image.NEAREST).save(path)
    print(len(ims), "sprites")
