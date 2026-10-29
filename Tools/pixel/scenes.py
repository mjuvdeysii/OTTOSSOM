"""The places of chapter one as pixel pictures (200 × 440, a little bigger than any phone's game area so it can be
centred), plus the title and the town between nights. Drawn by hand in code: a fixed night palette, hard-edged
shapes, ordered dithering only where two values meet, and a 1-pixel ink line where a form ends.

The play happens on the ground in the middle; the top quarter is the far side (sky, roofs, the lamp), so the
foes come out of something. Otto stands at about y = 245 in these pictures.

  python3 Tools/pixel/scenes.py [--sheet preview.png]
"""
import math, os, random, sys
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "Game", "Resources", "Pixel")
W, H = 200, 440
OTTO_Y = 245

def hx(h):
    h = h.lstrip("#"); return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))

INK = hx("#0b0a18")
SKY = [hx(c) for c in ("#070a18", "#0c1226", "#131b36", "#1b2648", "#26345c")]
SEA = [hx(c) for c in ("#060d1e", "#0b1830", "#122444", "#1c3458", "#2c4a74")]
STONE = [hx(c) for c in ("#15131f", "#221f30", "#302c42", "#423d56", "#57516c", "#706a86")]
WOOD = [hx(c) for c in ("#160f14", "#24181c", "#352428", "#4a3434", "#604642")]
BRICK = [hx(c) for c in ("#1a1220", "#2a1a2c", "#3c2638", "#503446")]
ROOF = [hx(c) for c in ("#0e1022", "#181a34", "#242848", "#323a5e")]
MOSS = [hx(c) for c in ("#12241c", "#1d3a2a", "#2c543a")]
GOLD = [hx(c) for c in ("#5a3a14", "#a86a18", "#e8a020", "#ffd36b", "#fff1c4")]
WARM = hx("#3a2a30")
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

class Pic:
    def __init__(self, w=W, h=H, fill=SKY[0]):
        self.w, self.h = w, h
        self.im = Image.new("RGB", (w, h), fill)
        self.p = self.im.load()
    def put(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h: self.p[x, y] = c
    def get(self, x, y):
        return self.p[int(x), int(y)] if 0 <= x < self.w and 0 <= y < self.h else None
    def rect(self, x, y, w, h, c):
        for j in range(int(y), int(y + h)):
            for i in range(int(x), int(x + w)): self.put(i, j, c)
    def grad(self, x, y, w, h, ramp, vertical=True, rev=False):
        """A banded gradient with a 4×4 Bayer dither between bands."""
        n = len(ramp) - 1
        for j in range(int(y), int(y + h)):
            for i in range(int(x), int(x + w)):
                t = (j - y) / max(1, h - 1) if vertical else (i - x) / max(1, w - 1)
                if rev: t = 1 - t
                v = t * n
                b = int(v); f = v - b
                if b >= n: b, f = n - 1, 1.0
                c = ramp[b + 1] if f * 16 > BAYER[j % 4][i % 4] + 0.5 else ramp[b]
                self.put(i, j, c)
    def ellipse(self, cx, cy, rx, ry, c, outline=None):
        for j in range(int(cy - ry - 1), int(cy + ry + 2)):
            for i in range(int(cx - rx - 1), int(cx + rx + 2)):
                d = ((i + 0.5 - cx) / rx) ** 2 + ((j + 0.5 - cy) / ry) ** 2
                if d <= 1: self.put(i, j, c)
        if outline: self.outline_ellipse(cx, cy, rx, ry, outline)
    def outline_ellipse(self, cx, cy, rx, ry, c):
        for k in range(int(8 * (rx + ry))):
            a = k / (8 * (rx + ry)) * 2 * math.pi
            self.put(cx + math.cos(a) * rx - 0.5, cy + math.sin(a) * ry - 0.5, c)
    def line(self, x0, y0, x1, y1, c):
        x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
        dx, dy = abs(x1 - x0), -abs(y1 - y0); sx = 1 if x0 < x1 else -1; sy = 1 if y0 < y1 else -1; err = dx + dy
        while True:
            self.put(x0, y0, c)
            if x0 == x1 and y0 == y1: break
            e2 = 2 * err
            if e2 >= dy: err += dy; x0 += sx
            if e2 <= dx: err += dx; y0 += sy
    def sprite(self, name, fx, fy, flip=False):
        """Paste one of the cast sprites with its feet at (fx, fy)."""
        s = Image.open(os.path.join(OUT, name + ".png")).convert("RGBA")
        if flip: s = s.transpose(Image.FLIP_LEFT_RIGHT)
        x0, y0 = fx - s.width // 2, fy - s.height + 1
        sp = s.load()
        for j in range(s.height):
            for i in range(s.width):
                r, g, b, a = sp[i, j]
                if a >= 128: self.put(x0 + i, y0 + j, (r, g, b))
    def save(self, name):
        self.im.save(os.path.join(OUT, name + ".png"))

def stars(p, y0, y1, n, seed, bright=0.15):
    r = random.Random(seed)
    for _ in range(n):
        x, y = r.randrange(p.w), r.randrange(y0, y1)
        c = SKY[4] if r.random() > bright else hx("#c8d0f0")
        p.put(x, y, c)
        if r.random() < 0.06:
            for d in (-1, 1): p.put(x + d, y, SKY[3]); p.put(x, y + d, SKY[3])

def far_sun(p, x, y):
    """The sun, far away and small, sinking behind the sea: a low half disc, short drooping rays. Mosto has its fire,
    so it's dim — readable as the sun only if you look."""
    for j in range(-6, 1):
        for i in range(-7, 8):
            if i * i + j * j * 1.1 <= 44: p.put(x + i, y + j, GOLD[1] if i * i + j * j > 22 else GOLD[2])
    for a in (-60, -30, 0, 30, 60):
        r = math.radians(a - 90)
        for k in range(9, 12):
            p.put(x + math.cos(r) * k, y + math.sin(r) * k + (k - 9) * 0.6, GOLD[1])

def sea(p, y0, y1, seed, glint_x=None):
    p.grad(0, y0, p.w, y1 - y0, SEA[1:4])
    r = random.Random(seed)
    for _ in range((y1 - y0) * 3):
        x, y = r.randrange(p.w), r.randrange(y0, y1)
        l = r.randrange(2, 6)
        for i in range(l): p.put(x + i, y, SEA[4] if r.random() < 0.3 else SEA[3])
    if glint_x is not None:
        for y in range(y0, y1, 2):
            w = max(1, int((y - y0) / 3) + 1)
            for i in range(-w, w + 1, 2): p.put(glint_x + i + (y // 2) % 2, y, GOLD[1] if abs(i) < w // 2 else SEA[4])

def cobbles(p, x0, y0, x1, y1, ramp, seed, size=(7, 4)):
    """Stones in staggered rows: each stone a flat colour with a light top edge and a dark gap."""
    r = random.Random(seed)
    sw, sh = size
    row = 0
    y = y0
    while y < y1:
        h = sh + (1 if y > (y0 + y1) / 2 else 0)
        x = x0 - (row % 2) * sw // 2
        while x < x1:
            w = sw + r.randrange(-1, 2)
            c = ramp[r.choice((1, 2, 2, 2))]
            for j in range(h):
                for i in range(w):
                    if x + i < x0 or x + i >= x1 or y + j >= y1: continue
                    if i == w - 1 or j == h - 1: p.put(x + i, y + j, ramp[0])
                    elif j == 0 and 0 < i < w - 3 and r.random() < 0.5: p.put(x + i, y + j, ramp[min(len(ramp) - 1, ramp.index(c) + 1)])
                    else: p.put(x + i, y + j, c)
            x += w
        y += h; row += 1

def planks(p, x0, y0, x1, y1, seed):
    r = random.Random(seed)
    pw = 9
    for x in range(x0, x1, pw):
        c = WOOD[r.choice((2, 2, 3))]
        seam = r.randrange(y0, y1)
        for y in range(y0, y1):
            for i in range(pw):
                X = x + i
                if X >= x1: continue
                if i == pw - 1: p.put(X, y, WOOD[0])
                elif i == 0: p.put(X, y, WOOD[min(4, WOOD.index(c) + 1)])
                elif abs(y - seam) == 0 or (y - seam) % 61 == 0: p.put(X, y, WOOD[0])
                else:
                    grain = (y * 7 + X * 3 + seam) % 23 == 0
                    p.put(X, y, WOOD[1] if grain else c)
        for y in range(y0 + 4, y1, 30):
            if r.random() < 0.6: p.put(x + 2, y + (seam % 7), INK); p.put(x + 6, y + (seam % 7), INK)

def window(p, x, y, w, h, lit=False, frame=None):
    frame = frame or STONE[0]
    p.rect(x - 1, y - 1, w + 2, h + 2, frame)
    p.grad(x, y, w, h, [hx("#5a3a14"), GOLD[1], GOLD[2]] if lit else [SKY[0], SKY[1], SKY[2]], rev=not lit)
    p.rect(x + w // 2, y, 1, h, frame)
    p.rect(x, y + h // 2, w, 1, frame)

def lamppost(p, x, ground, h=34, lit=False):
    p.rect(x, ground - h, 2, h, STONE[0]); p.rect(x + 1, ground - h, 1, h, STONE[2])
    p.rect(x - 2, ground - 2, 6, 2, STONE[0])
    p.rect(x - 3, ground - h - 7, 8, 7, INK)
    p.rect(x - 2, ground - h - 6, 6, 5, GOLD[3] if lit else hx("#1c2238"))
    if not lit: p.put(x - 1, ground - h - 5, hx("#3a4466"))
    p.rect(x - 4, ground - h - 8, 10, 1, INK)
    p.put(x + 1, ground - h - 9, INK)

def vignette_ground(p, y0, y1):
    """Soft darker band at the top of the ground so the far edge recedes."""
    for y in range(y0, min(y1, y0 + 10)):
        for x in range(p.w):
            if (BAYER[y % 4][x % 4] / 16) > (y - y0) / 10:
                c = p.get(x, y); p.put(x, y, tuple(int(v * 0.7) for v in c))

def moss_tufts(p, n, y0, y1, seed):
    r = random.Random(seed)
    for _ in range(n):
        x, y = r.randrange(p.w), r.randrange(y0, y1)
        for i in range(r.randrange(2, 5)):
            p.put(x + i, y, MOSS[r.randrange(1, 3)]);
            if r.random() < 0.5: p.put(x + i, y - 1, MOSS[2])

# ---------------------------------------------------------------- places

def place_top():
    """Night 1 — the gallery round the lamp at the top of the lighthouse. The great lamp behind is dark."""
    p = Pic()
    p.grad(0, 0, W, 120, SKY[0:4]); stars(p, 0, 110, 90, 1)
    sea(p, 104, 132, 2)
    # the lamp room: glass panes in a dark iron cage, the big lens unlit
    cx = W // 2
    p.rect(cx - 34, 40, 68, 70, INK)
    for i in range(5):
        x = cx - 32 + i * 13
        p.grad(x, 44, 12, 62, [hx("#121a30"), hx("#1a2440"), hx("#22305a")], vertical=False)
        p.line(x + 3, 46, x + 8, 56, hx("#2c3c6a"))
    p.ellipse(cx, 76, 13, 16, hx("#1a1c30"), INK)
    for k in range(6): p.outline_ellipse(cx, 76, 13 - k * 2, 16 - k * 2.5, hx("#252a44") if k % 2 else hx("#14162a"))
    p.rect(cx - 40, 32, 80, 8, ROOF[2]); p.rect(cx - 40, 32, 80, 1, ROOF[3]); p.rect(cx - 40, 39, 80, 1, INK)
    for y, w in ((24, 50), (18, 30), (13, 10)): p.rect(cx - w // 2, y, w, 32 - y if w == 50 else 6, ROOF[1]); p.rect(cx - w // 2, y, w, 1, ROOF[3])
    p.rect(cx - 1, 6, 2, 8, INK)
    # the floor of the gallery: a wide round of stone slabs, seen from above
    p.rect(0, 110, W, 330, STONE[1])
    cy = OTTO_Y - 6
    for y in range(110, H):
        for x in range(W):
            dx, dy = (x - cx) / 1.0, (y - cy) * 1.35
            d = math.hypot(dx, dy); a = math.atan2(dy, dx)
            ring = int(d / 22)
            seg = int((a + math.pi) / (2 * math.pi) * (10 + ring * 6))
            c = STONE[2 + (ring + seg) % 2]
            if int(d) % 22 == 0: c = STONE[0]
            elif (a + math.pi) * (10 + ring * 6) / (2 * math.pi) % 1 < 0.03 * (10 + ring * 6) / max(1, d / 6): c = STONE[0]
            elif int(d) % 22 == 1: c = STONE[4]
            p.put(x, y, c)
    vignette_ground(p, 110, 440)
    # the railing at the front and back
    for y0 in (112, 404):
        p.rect(0, y0, W, 2, INK); p.rect(0, y0 + 2, W, 1, STONE[4])
        for x in range(3, W, 11): p.rect(x, y0 + 2, 2, 16, INK); p.rect(x + 1, y0 + 3, 1, 14, STONE[3])
        p.rect(0, y0 + 18, W, 2, INK)
    moss_tufts(p, 20, 130, 400, 3)
    p.save("place_top"); return p

def house_row(p, y_base, seed, lit=()):
    """A row of narrow town houses whose fronts face us; roofs against the sky."""
    r = random.Random(seed)
    x = -6; k = 0
    while x < W:
        w = r.randrange(30, 44); h = r.randrange(58, 84)
        top = y_base - h
        wall = BRICK if k % 2 else STONE
        p.rect(x, top, w, h, wall[2])
        for j in range(top, y_base, 4):
            for i in range(x, x + w):
                if (i + (j // 4) * 3) % 8 == 0: p.put(i, j, wall[1])
                if j % 4 == 0: p.put(i, j, wall[1]) if (i // 3) % 3 == 0 else None
        p.rect(x, top, 1, h, wall[3]); p.rect(x + w - 1, top, 1, h, INK)
        # roof
        for j in range(14):
            p.rect(x - 2 + j, top - 14 + j, w + 4 - 2 * j, 1, ROOF[2] if j < 13 else ROOF[3]) if False else None
        for j in range(16):
            ww = int((w + 6) * (j / 16))
            p.rect(x + w // 2 - ww // 2, top - 16 + j, ww, 1, ROOF[1] if j % 3 else ROOF[2])
        p.rect(x - 3, top - 1, w + 6, 2, INK)
        if r.random() < 0.6: p.rect(x + w - 10, top - 20, 5, 10, BRICK[1]); p.rect(x + w - 10, top - 20, 5, 1, BRICK[3])
        for row in range(2):
            for col in range(2):
                wx = x + 6 + col * (w - 19); wy = top + 10 + row * 22
                window(p, wx, wy, 7, 10, lit=(k, row, col) in lit)
        p.rect(x + w // 2 - 4, y_base - 15, 9, 15, INK); p.rect(x + w // 2 - 3, y_base - 14, 7, 14, WOOD[2]); p.put(x + w // 2 + 1, y_base - 7, GOLD[2])
        x += w + r.randrange(0, 3); k += 1

def place_street():
    """Night 2 — the north street: house fronts at the back, cobbles, dark lamp posts."""
    p = Pic()
    p.grad(0, 0, W, 90, SKY[0:3]); stars(p, 0, 60, 50, 4)
    house_row(p, 118, 5, lit={(1, 0, 1), (3, 1, 0)})
    p.rect(0, 118, W, 3, STONE[0])
    cobbles(p, 0, 121, W, H, STONE, 6)
    # the gutter down the middle
    for y in range(121, H):
        p.put(W // 2 - 1 + (y // 9) % 2, y, STONE[0])
    vignette_ground(p, 121, 440)
    for x, gy in ((18, 190), (176, 300), (20, 380)): lamppost(p, x, gy)
    moss_tufts(p, 26, 130, 430, 7)
    # a cart and barrels at the side
    for (bx, by) in ((172, 160), (182, 168)):
        p.ellipse(bx, by, 6, 7, WOOD[2], INK); p.rect(bx - 6, by - 2, 12, 1, INK); p.rect(bx - 6, by + 3, 12, 1, INK); p.rect(bx - 3, by - 6, 3, 1, WOOD[4])
    p.save("place_street"); return p

def place_dock():
    """Night 3 — the dock: a pier of planks out into the black sea, bollards, a moored boat."""
    p = Pic()
    p.grad(0, 0, W, 70, SKY[0:3]); stars(p, 0, 60, 60, 8)
    sea(p, 60, H, 9)
    # the far shore: the town's lights
    for x in range(0, W, 3):
        h = 6 + int(4 * math.sin(x * 0.13) + 3 * math.sin(x * 0.41))
        p.rect(x, 62 - h, 3, h, ROOF[1])
    for x in (22, 61, 98, 140, 171): p.put(x, 58, GOLD[2])
    # the pier
    x0, x1 = 34, 166
    planks(p, x0, 96, x1, H, 10)
    p.rect(x0 - 2, 96, 2, H, INK); p.rect(x1, 96, 2, H, INK)
    p.rect(x0 - 3, 92, x1 - x0 + 6, 4, WOOD[1]); p.rect(x0 - 3, 92, x1 - x0 + 6, 1, WOOD[4])
    for y in range(110, H, 46):
        for x in (x0 - 5, x1 + 1):
            p.rect(x, y, 5, 8, WOOD[1]); p.rect(x, y, 5, 1, WOOD[4]); p.rect(x, y + 8, 5, 1, INK)
            for i in range(5): p.put(x + i, y + 9 + i % 2, SEA[4])
    # bollards and rope
    for (bx, by) in ((44, 160), (156, 230), (44, 330)):
        p.ellipse(bx, by, 4, 3, STONE[3], INK); p.rect(bx - 3, by, 7, 4, STONE[2]); p.rect(bx - 4, by + 4, 9, 1, INK)
    for t in range(40):
        p.put(44 + t * 0.3 + 4, 162 + t + 3 * math.sin(t / 6), hx("#8a7356"))
    # the boat on the right
    bx, by = 183, 180
    for j in range(40):
        w = int(9 * math.sin(math.pi * j / 40)) + 1
        p.rect(bx - w, by + j, 2 * w, 1, WOOD[2] if j % 6 else WOOD[3])
        p.put(bx - w - 1, by + j, INK); p.put(bx + w, by + j, INK)
    p.rect(bx - 1, by + 8, 2, 20, WOOD[0])
    p.save("place_dock"); return p

def place_square():
    """Night 4 — the market square: a ring of paving round where the fountain stands, stalls closed for the night."""
    p = Pic()
    p.grad(0, 0, W, 80, SKY[0:3]); stars(p, 0, 50, 40, 11)
    house_row(p, 96, 12, lit={(2, 0, 0)})
    p.rect(0, 96, W, 3, STONE[0])
    cobbles(p, 0, 99, W, H, STONE, 13, size=(6, 4))
    cx, cy = W // 2, OTTO_Y + 4
    for y in range(99, H):
        for x in range(W):
            d = math.hypot(x - cx, (y - cy) * 1.3)
            if 52 < d < 58: p.put(x, y, STONE[3] if int(d) % 2 else STONE[4])
            elif 57.5 < d < 59: p.put(x, y, STONE[0])
            elif d < 52 and (int(math.degrees(math.atan2(y - cy, x - cx)) / 15) + int(d / 10)) % 2 == 0 and int(d) % 10 == 0:
                p.put(x, y, STONE[0])
    vignette_ground(p, 99, 440)
    # the fountain at the back of the square, dry
    fx, fy = cx, 140
    p.ellipse(fx, fy, 24, 9, STONE[3], INK); p.ellipse(fx, fy, 20, 7, SEA[2]); p.ellipse(fx, fy - 1, 18, 5, SEA[3])
    p.rect(fx - 2, fy - 22, 4, 20, STONE[2]); p.rect(fx - 2, fy - 22, 1, 20, STONE[4]); p.ellipse(fx, fy - 22, 7, 3, STONE[3], INK)
    # stalls under cloth
    for (sx, sy, c) in ((22, 200, hx("#3a2440")), (176, 290, hx("#243a40")), (24, 360, hx("#403a24"))):
        p.rect(sx - 13, sy - 14, 26, 14, c); p.rect(sx - 13, sy - 14, 26, 1, tuple(min(255, v + 40) for v in c))
        for i in range(-13, 13, 4): p.rect(sx + i, sy, 2, 3, c)
        p.rect(sx - 14, sy - 15, 28, 1, INK); p.rect(sx - 12, sy + 3, 2, 8, WOOD[1]); p.rect(sx + 10, sy + 3, 2, 8, WOOD[1])
    lamppost(p, 178, 200); lamppost(p, 22, 290)
    moss_tufts(p, 18, 110, 430, 14)
    p.save("place_square"); return p

def place_cellar():
    """Night 5 — the old lamp cellar outside town: arches, a stone floor, broken lamps along the walls."""
    p = Pic(fill=hx("#06060c"))
    # back wall of big blocks with three arches
    for y in range(0, 120, 9):
        off = (y // 9) % 2 * 9
        for x in range(-off, W, 18):
            p.rect(x, y, 17, 8, BRICK[1] if (x + y) % 3 else BRICK[2]); p.rect(x, y, 17, 1, BRICK[3])
    for ax in (30, 100, 170):
        for y in range(30, 120):
            w = 18 if y > 52 else int(math.sqrt(max(0, 18 ** 2 - (52 - y) ** 2)))
            p.rect(ax - w, y, 2 * w, 1, hx("#030308"))
        p.outline_ellipse(ax, 52, 19, 22, INK)
    p.rect(0, 118, W, 4, INK)
    cobbles(p, 0, 122, W, H, STONE[:5], 15, size=(11, 6))
    vignette_ground(p, 122, 440)
    # broken lamps hanging on the wall, cold
    for lx in (65, 135):
        p.rect(lx, 20, 1, 22, INK); p.rect(lx - 4, 42, 9, 9, INK); p.rect(lx - 3, 43, 7, 7, hx("#1a1828"))
        p.line(lx - 3, 43, lx + 2, 49, hx("#3a3650"))
    # crates and old lamp glass on the floor
    for (cx, cy) in ((20, 170), (178, 340), (30, 400)):
        p.rect(cx - 9, cy - 10, 18, 12, WOOD[2]); p.rect(cx - 9, cy - 10, 18, 1, WOOD[4]); p.rect(cx - 9, cy + 2, 18, 1, INK)
        p.line(cx - 9, cy - 10, cx + 8, cy + 1, WOOD[1]); p.rect(cx - 10, cy - 11, 1, 14, INK); p.rect(cx + 9, cy - 11, 1, 14, INK)
    r = random.Random(16)
    for _ in range(26):
        x, y = r.randrange(W), r.randrange(140, 430)
        p.put(x, y, hx("#4a5a7a")); p.put(x + 1, y, hx("#2a3450"))
    p.save("place_cellar"); return p

# ---------------------------------------------------------------- title and town

def lighthouse(p, x, base, h, lit=False):
    """A slim lighthouse: banded tower, gallery, lamp room."""
    for j in range(h):
        y = base - j
        w = int(9 + (h - j) / h * 5)
        band = (j // 14) % 2
        for i in range(-w, w + 1):
            sh = (i + w) / (2 * w)
            ramp = [hx("#3a3a50"), hx("#5c5c78"), hx("#8a8aa6")] if band == 0 else [hx("#3a1c2a"), hx("#5a2a3a"), hx("#7a3c4c")]
            c = ramp[0] if sh > 0.75 else ramp[1] if sh > 0.3 else ramp[2]
            if sh > 0.62 and (i + y) % 2 == 0 and sh <= 0.75: c = ramp[0]
            p.put(x + i, y, c)
        p.put(x - w - 1, y, INK); p.put(x + w + 1, y, INK)
    top = base - h
    p.rect(x - 13, top - 3, 27, 3, INK); p.rect(x - 12, top - 2, 25, 1, STONE[3])
    for i in range(-12, 13, 3): p.rect(x + i, top - 8, 1, 5, INK)
    p.rect(x - 8, top - 18, 17, 15, INK)
    p.rect(x - 7, top - 17, 15, 13, GOLD[3] if lit else hx("#1c2440"))
    if not lit: p.line(x - 5, top - 15, x - 1, top - 8, hx("#34406a"))
    for y in range(-5, 0): p.rect(x - 9 - y, top - 18 + y, 19 + 2 * y, 1, ROOF[2])
    p.rect(x, top - 26, 1, 4, INK)
    for k in range(4): p.rect(x - 2, base - 30 - k * 26, 3, 5, INK); p.rect(x - 1, base - 29 - k * 26, 1, 3, GOLD[2] if k == 1 else hx("#202840"))

def title():
    """The title, drawn at half the resolution (shown twice as big) so the three of them fill the frame."""
    p = Pic(100, 220)
    p.grad(0, 0, 100, 128, SKY + [hx("#2c3060"), hx("#3a3466")])
    stars(p, 0, 100, 70, 20, bright=0.2)
    for i in range(0, 100):
        hh = 6 + 3 * math.sin(i * 0.09) + 2 * math.sin(i * 0.31)
        p.rect(i, 124 - hh, 1, hh, hx("#232a50")); p.put(i, 124 - int(hh), hx("#3a4478"))
    far_sun(p, 22, 128)
    sea(p, 128, 166, 21, glint_x=22)
    for x in range(100):
        top = 166 - int(26 * max(0, (x - 52) / 48) ** 0.7) - (x % 3 == 0)
        for y in range(top, 220): p.put(x, y, STONE[1] if y > top else STONE[3])
    cobbles(p, 0, 176, 100, 220, STONE[:5], 22, size=(7, 4))
    for x in range(100):
        for y in range(172, 178):
            if BAYER[y % 4][x % 4] < (178 - y) * 3: p.put(x, y, STONE[1])
    lighthouse(p, 82, 150, 64, lit=False)
    moss_tufts(p, 10, 166, 218, 23)
    p.sprite("mosto_carry_0", 64, 138, flip=True)
    p.sprite("otto_idle_0", 36, 206)
    p.sprite("moss_idle_0", 62, 210)
    p.line(30, 182, 62, 204, GOLD[3])
    p.save("title"); return p

def town():
    """The lighthouse town between nights: the lighthouse up the hill, the street down to the sea."""
    p = Pic()
    p.grad(0, 0, W, 160, SKY[0:4]); stars(p, 0, 120, 80, 30)
    sea(p, 120, 170, 31)
    lighthouse(p, 150, 150, 100, lit=False)
    house_row(p, 210, 32, lit={(0, 0, 1), (2, 1, 1), (4, 0, 0)})
    p.rect(0, 210, W, 3, STONE[0])
    cobbles(p, 0, 213, W, H, STONE, 33)
    vignette_ground(p, 213, 440)
    lamppost(p, 24, 260, lit=True); lamppost(p, 172, 250, lit=True)
    moss_tufts(p, 24, 220, 430, 34)
    p.save("town"); return p

if __name__ == "__main__":
    pics = [place_top(), place_street(), place_dock(), place_square(), place_cellar(), title(), town()]
    if "--sheet" in sys.argv:
        out = sys.argv[sys.argv.index("--sheet") + 1]
        sheet = Image.new("RGB", (len(pics) * (W + 6), H), (40, 40, 60))
        for i, pc in enumerate(pics): sheet.paste(pc.im if pc.w == W else pc.im.resize((W, H), Image.NEAREST), (i * (W + 6), 0))
        sheet = sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
        sheet.save(out)
    print(len(pics), "scenes")
