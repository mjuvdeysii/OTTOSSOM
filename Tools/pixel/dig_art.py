"""Pixel art for the dig and the lamp shop: the ground tiles (8 × 8, a few variants each, laid out in one sheet),
the crystals and trinkets as icons, the lamp, the surface above the shaft, the shop, and the memory panels of
《影子》. Same palette and rules as sprites.py / scenes.py.

  python3 Tools/pixel/dig_art.py [--sheet preview.png]
"""
import math, os, random, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
from scenes import Pic, hx, INK, SKY, SEA, STONE, WOOD, BRICK, ROOF, MOSS, GOLD, BAYER, stars, sea, lighthouse, far_sun, window, OUT

T = 16
# tile ids — must match Tile in Game/Pixel/Dig.swift
AIR, SOIL, CLAY, STONE_T, ROCK, BEDROCK, AMBER, BLUE, RED, TRINKET, MEMORY, MEMREAD, MOTE, GRASS = range(14)
VARIANTS = 4

SOIL_R = [hx(c) for c in ("#1a120e", "#2a1c14", "#3a281c", "#4c3626", "#5e4632")]
CLAY_R = [hx(c) for c in ("#1e100e", "#341a16", "#4a2620", "#5e342a", "#744436")]
STONE_R = [hx(c) for c in ("#14141c", "#22222e", "#323244", "#46465c", "#5c5c76")]
ROCK_R = [hx(c) for c in ("#0e0c16", "#1a1626", "#262036", "#342c48", "#443a5c")]
BED_R = [hx(c) for c in ("#06060a", "#0c0c12", "#14141c", "#1c1c26", "#24242e")]
CRYSTAL = {
    "amber": [hx(c) for c in ("#5a3a14", "#a86a18", "#e8a020", "#ffd36b", "#fff1c4")],
    "blue": [hx(c) for c in ("#16285a", "#2a52a8", "#4a8ae8", "#8ac4ff", "#e0f2ff")],
    "red": [hx(c) for c in ("#4a1420", "#922838", "#d8485a", "#ff8a8a", "#ffe0dc")],
}

def material(c, ramp, seed, rough=0.5, pebbles=0.08):
    """Fill a tile with a material: mid tone, a few lighter and darker pixels in clumps, the odd pebble."""
    r = random.Random(seed)
    for y in range(T):
        for x in range(T):
            v = 2
            n = r.random()
            if n < rough * 0.25: v = 1
            elif n > 1 - rough * 0.18: v = 3
            c.put(x, y, ramp[v])
    for _ in range(int(pebbles * 64)):
        x, y = r.randrange(T - 1), r.randrange(T - 1)
        c.put(x, y, ramp[3]); c.put(x + 1, y + 1, ramp[1]); c.put(x + 1, y, ramp[2])

def shard(c, x0, y0, h, ramp):
    """A crystal shard standing up from (x0, y0): 3 wide, pointed top, light face left."""
    for j in range(h):
        for i in range(3):
            if j == h - 1 and i != 1: continue
            c.put(x0 + i, y0 - j, ramp[4] if (i == 0 and j > h - 4) else ramp[3] if i == 0 else ramp[2] if i == 1 else ramp[1])
    c.put(x0 - 1, y0, INK); c.put(x0 + 3, y0, INK)
    for j in range(h - 1): c.put(x0 - 1, y0 - j, INK) if c.get(x0 - 1, y0 - j) not in ramp else None

def tile_cell(kind, var):
    c = Pic(T, T, fill=(0, 0, 0))
    seed = kind * 31 + var * 7
    if kind == AIR:
        return c
    if kind in (SOIL, GRASS, MOTE):
        material(c, SOIL_R, seed, 0.6, 0.05)
        if kind == GRASS:
            for x in range(T):
                h = 2 + (x * 7 + var * 3) % 3
                for y in range(h): c.put(x, y, MOSS[2] if y == 0 else MOSS[1])
                if (x * 5 + var) % 6 == 0: c.put(x, h, MOSS[0])
        if kind == MOTE:
            r = random.Random(seed)
            for _ in range(2):
                x, y = r.randrange(3, 13), r.randrange(3, 13)
                for (dx, dy, k) in ((0, 0, 4), (1, 0, 3), (0, 1, 3), (-1, 0, 2), (0, -1, 2), (2, 0, 1), (0, 2, 1), (-2, 0, 1), (0, -2, 1)): c.put(x + dx, y + dy, GOLD[k])
    elif kind == CLAY:
        material(c, CLAY_R, seed, 0.5, 0.03)
        for x in range(T):
            y = (var * 5 + x // 3) % T
            c.put(x, y, CLAY_R[1]); c.put(x, (y + 8) % T, CLAY_R[3] if x % 2 else CLAY_R[1])
    elif kind == STONE_T:
        material(c, STONE_R, seed, 0.3, 0.0)
        cx = 5 + var % 4 * 2
        for y in range(T): c.put(cx if y < 8 else (cx + 6) % T, y, STONE_R[0])
        for x in range(T): c.put(x, 8, STONE_R[0]); c.put(x, 9, STONE_R[3] if x % 3 else STONE_R[2])
        for x in range(T): c.put(x, 0, STONE_R[3] if x % 4 else STONE_R[2])
    elif kind == ROCK:
        material(c, ROCK_R, seed, 0.45, 0.1)
        r = random.Random(seed)
        for _ in range(4):
            x, y = r.randrange(2, T - 2), r.randrange(2, T - 2)
            c.put(x, y, ROCK_R[4]); c.put(x + 1, y, ROCK_R[3]); c.put(x, y + 1, ROCK_R[0])
    elif kind == BEDROCK:
        material(c, BED_R, seed, 0.3, 0.0)
    elif kind in (AMBER, BLUE, RED):
        host = SOIL_R if kind == AMBER else STONE_R if kind == BLUE else ROCK_R
        material(c, host, seed, 0.4, 0.0)
        ramp = CRYSTAL[{AMBER: "amber", BLUE: "blue", RED: "red"}[kind]]
        sets = [((3, 13, 7), (7, 14, 10), (11, 13, 6)), ((2, 13, 6), (6, 14, 11)), ((5, 14, 9), (9, 13, 7)), ((3, 14, 8), (8, 13, 6), (11, 14, 9))]
        for (x0, y0, h) in sets[var % 4]: shard(c, x0, y0, h, ramp)
    elif kind == TRINKET:
        material(c, SOIL_R if var < 2 else CLAY_R, seed, 0.5, 0.0)
        ic = Image.open(os.path.join(OUT, "icon_" + ["button", "coin", "cap", "bead"][var % 4] + ".png")).convert("RGBA")
        ip = ic.load()
        for j in range(12):
            for i in range(12):
                if ip[i, j][3] > 128 and j < 9: c.put(2 + i, 4 + j, ip[i, j][:3])
        for i in range(2, 14): c.put(i, 12, SOIL_R[1])
    elif kind in (MEMORY, MEMREAD):
        material(c, STONE_R, seed, 0.2, 0.0)
        for y in range(2, T):
            for x in range(2, T - 2):
                c.put(x, y, STONE_R[3] if x < 7 else STONE_R[2])
        for x in range(3, 13): c.put(x, 1, STONE_R[4])
        for y in range(2, T): c.put(1, y, INK); c.put(T - 2, y, INK)
        c.put(2, 1, INK); c.put(13, 1, INK)
        glyph = GOLD[3] if kind == MEMORY else STONE_R[1]
        # a little stone with two leaves: Moss's mark
        for (x, y) in ((6, 9), (7, 8), (8, 8), (9, 9), (9, 10), (8, 11), (7, 11), (6, 10), (7, 6), (8, 6), (6, 5), (9, 5)): c.put(x, y, glyph)
    return c

def tiles():
    kinds = 14
    sheet = Image.new("RGB", (T * VARIANTS, T * kinds), (0, 0, 0))
    for k in range(kinds):
        for v in range(VARIANTS):
            sheet.paste(tile_cell(k, v).im, (v * T, k * T))
    sheet.save(os.path.join(OUT, "tiles.png"))
    # cracks: 3 stages, ink on transparent
    cr = Image.new("RGBA", (T * 3, T), (0, 0, 0, 0))
    base = [(7, 7), (8, 8), (6, 9), (9, 6), (10, 5), (5, 10), (11, 5), (4, 11), (8, 9), (9, 10), (6, 6), (5, 5), (10, 9), (11, 11), (3, 12), (12, 3), (7, 10), (6, 12), (10, 7), (12, 7)]
    for s in range(3):
        for (x, y) in base[: 4 + s * 8]: cr.putpixel((s * T + x, y), (11, 10, 24, 255))
    cr.save(os.path.join(OUT, "cracks.png"))
    return sheet

def icon(kind):
    """12 × 12 inventory icons."""
    c = Pic(12, 12, fill=(0, 0, 0))
    im = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
    px = im.load()
    def put(x, y, col):
        if 0 <= x < 12 and 0 <= y < 12: px[x, y] = col + (255,)
    if kind in CRYSTAL:
        r = CRYSTAL[kind]
        shape = ["....##....", "...####...", "..######..", ".########.", ".########.", "..######..", "...####...", "....##...."]
        for j, row in enumerate(shape):
            for i, ch in enumerate(row):
                if ch == "#":
                    x, y = i + 1, j + 2
                    col = r[4] if (i < 5 and j < 3) else r[3] if i < 5 else r[2] if j < 5 else r[1]
                    put(x, y, col)
        for j, row in enumerate(shape):
            for i, ch in enumerate(row):
                if ch == "#":
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ii, jj = i + dx, j + dy
                        if not (0 <= jj < len(shape) and 0 <= ii < len(row)) or shape[jj][ii] != "#":
                            if px[ii + 1, jj + 2][3] == 0 if 0 <= ii + 1 < 12 and 0 <= jj + 2 < 12 else False: put(ii + 1, jj + 2, INK)
    elif kind == "button":
        for y in range(12):
            for x in range(12):
                d = (x - 5.5) ** 2 + (y - 5.5) ** 2
                if d <= 20: put(x, y, hx("#e892a4") if d < 12 else hx("#b86a84"))
                elif d <= 27: put(x, y, INK)
        for (x, y) in ((4, 4), (7, 4), (4, 7), (7, 7)): put(x, y, hx("#5a2a40"))
    elif kind == "coin":
        for y in range(12):
            for x in range(12):
                d = (x - 5.5) ** 2 + (y - 5.5) ** 2
                if d <= 20: put(x, y, GOLD[3] if x + y < 10 else GOLD[2])
                elif d <= 27: put(x, y, INK)
        for y in range(3, 9): put(6, y, GOLD[1])
    elif kind == "cap":
        for x in range(1, 11):
            for y in range(4, 9): put(x, y, hx("#c4d0e0") if y < 6 else hx("#8a9ab0"))
        for x in range(1, 11, 2): put(x, 9, hx("#5a6a80"))
        for x in range(0, 12): put(x, 3, INK); put(x, 10, INK)
        for y in range(3, 11): put(0, y, INK); put(11, y, INK)
    elif kind == "bead":
        for y in range(12):
            for x in range(12):
                d = (x - 5.5) ** 2 + (y - 5.5) ** 2
                if d <= 18: put(x, y, hx("#b07a48") if (x + y * 2) % 5 else hx("#8a5a30"))
                elif d <= 25: put(x, y, INK)
        put(4, 4, hx("#f0d0a0"))
    im.save(os.path.join(OUT, f"icon_{kind}.png"))
    return im

def lamp():
    """The lamp a customer brings: 16 × 22, glass left clear (the game tints it with the light it gets)."""
    im = Image.new("RGBA", (16, 22), (0, 0, 0, 0)); px = im.load()
    def put(x, y, c): px[x, y] = c + (255,)
    for x in range(6, 10): put(x, 0, INK)
    put(5, 1, INK); put(10, 1, INK)
    for x in range(3, 13): put(x, 3, INK); put(x, 4, WOOD[3]); put(x, 18, WOOD[3]); put(x, 19, INK)
    for y in range(5, 18):
        put(2, y, INK); put(13, y, INK); put(3, y, WOOD[2]); put(12, y, WOOD[2])
        pass   # the glass is left clear: the game puts the light behind it
    for x in range(4, 12): put(x, 2, WOOD[2])
    for x in range(5, 11): put(x, 20, WOOD[1]); put(x, 21, INK)
    im.save(os.path.join(OUT, "lamp.png"))
    return im

def surface():
    """What's above the shaft: the night sky, the lighthouse on the left, the town's lights, the ground line.
    200 wide × 72 tall; the ground (row 8 of tiles = y 64) is at its bottom."""
    p = Pic(192, 80)
    p.grad(0, 0, 192, 80, SKY[0:4]); stars(p, 0, 60, 40, 70)
    for x in range(0, 192, 2):
        h = 8 + int(3 * math.sin(x * 0.11)) + (5 if 110 < x < 186 else 0)
        p.rect(x, 80 - h, 2, h, ROOF[1])
    for x in (122, 133, 150, 166, 178): p.put(x, 80 - 10, GOLD[2])
    lighthouse(p, 22, 79, 56, lit=False)
    p.save("dig_surface")
    return p

def shop():
    """The lamp shop inside the lighthouse's base: stone walls, shelves of dark lamps, the counter at the bottom.
    200 × 440, counter top at y = 300."""
    p = Pic(200, 440, fill=STONE[1])
    for y in range(0, 300, 9):
        off = (y // 9) % 2 * 10
        for x in range(-off, 200, 20):
            p.rect(x, y, 19, 8, STONE[2] if (x // 20 + y // 9) % 3 else STONE[1]); p.rect(x, y, 19, 1, STONE[3])
    # a round window with the night outside
    p.ellipse(100, 70, 30, 30, INK); p.ellipse(100, 70, 27, 27, SKY[1]); stars(p, 73, 97, 0, 0)
    for k in range(40):
        a = k / 40 * 2 * math.pi
        if random.Random(k).random() < 0.3: p.put(100 + math.cos(a) * 14 * random.Random(k * 3).random(), 70 + math.sin(a) * 14, SKY[4])
    p.rect(99, 43, 2, 54, INK); p.rect(73, 69, 54, 2, INK)
    # shelves with dark lamps
    for sy in (130, 190):
        p.rect(10, sy, 180, 4, WOOD[3]); p.rect(10, sy + 4, 180, 2, INK)
        for i, lx in enumerate(range(22, 190, 28)):
            p.rect(lx - 5, sy - 16, 11, 14, INK); p.rect(lx - 4, sy - 15, 9, 12, hx("#1c2238") if (i + sy) % 3 else hx("#2a2a3a"))
            p.rect(lx - 3, sy - 19, 7, 3, WOOD[2]); p.put(lx, sy - 20, INK)
    # the counter
    p.rect(0, 296, 200, 144, WOOD[1])
    p.rect(0, 296, 200, 4, WOOD[4]); p.rect(0, 300, 200, 2, INK)
    for x in range(0, 200, 25): p.rect(x, 302, 1, 138, WOOD[0])
    for y in range(310, 440, 14):
        for x in range(0, 200):
            if (x * 7 + y) % 37 == 0: p.put(x, y, WOOD[2])
    p.save("shop_bg")
    return p

# ---------------------------------------------------------------- memories of 《影子》

WALL = [hx(c) for c in ("#1a1426", "#221a32", "#2a2040")]
DESK = [hx(c) for c in ("#2a1810", "#3e2618", "#563620", "#6e4a2c", "#8a6038")]

def room(p, top):
    """The wall (faint stripes) and the desk top seen a little from above."""
    for y in range(top):
        for x in range(p.w):
            p.put(x, y, WALL[1] if (x // 6) % 2 else WALL[2])
    for x in range(p.w): p.put(x, top - 1, WALL[0])
    for y in range(top, p.h):
        for x in range(p.w):
            k = 3 if y < top + 2 else 2
            if (x + (y - top) * 9) % 23 == 0: k = 1
            p.put(x, y, DESK[k])
    for x in range(p.w): p.put(x, top, DESK[4])

def desk_lamp2(p, x, top):
    """A green desk lamp: round base, a jointed arm, a cone shade tipped toward the middle."""
    for i in range(-7, 8): p.put(x + i, top - 1, INK); 
    for i in range(-6, 7): p.put(x + i, top - 2, STONE[3]); p.put(x + i, top - 3, INK if abs(i) == 6 else STONE[2])
    p.line(x, top - 3, x - 3, top - 22, INK); p.line(x + 1, top - 3, x - 2, top - 22, STONE[3])
    p.line(x - 3, top - 22, x + 8, top - 34, INK); p.line(x - 2, top - 22, x + 9, top - 33, STONE[3])
    for j in range(9):
        w = 3 + j
        for i in range(-w, w + 1):
            p.put(x + 12 + i + j // 2, top - 38 + j, hx("#2a6a52") if i < w - 1 else hx("#1a4a3a"))
        p.put(x + 12 - w - 1 + j // 2, top - 38 + j, INK); p.put(x + 12 + w + 1 + j // 2, top - 38 + j, INK)
    for i in range(-11, 12): p.put(x + 16 + i, top - 29, GOLD[4] if abs(i) < 6 else GOLD[3])
    return (x + 16, top - 28)

def light_room(p, bulb, top, warm=1.0):
    """Lamplight: bright under the shade, falling off in bands with a dither, warm; the rest in blue dark."""
    bx, by = bulb
    for y in range(p.h):
        for x in range(p.w):
            c = p.get(x, y)
            dx, dy = x - bx, (y - by) * 1.1
            d = math.hypot(dx, dy)
            below = y >= by - 1
            l = max(0.0, 1 - d / 95) * (1.0 if below else 0.45)
            v = l * 3.3 + BAYER[y % 4][x % 4] / 16 * 0.9
            band = min(3, int(v))
            m = [0.42, 0.62, 0.82, 1.0][band]
            r, g, b = c
            wr = 1 + 0.18 * warm * band / 3
            p.put(x, y, (min(255, int(r * m * wr)), min(255, int(g * m * (1 + 0.06 * band / 3))), int(b * (m * 0.85 + 0.12))))

def mint(p, x, top):
    p.rect(x - 6, top - 10, 12, 10, hx("#7a4a3a")); p.rect(x - 7, top - 11, 14, 2, hx("#9a5a44")); p.rect(x - 6, top - 1, 12, 1, INK)
    p.rect(x - 7, top - 11, 1, 11, INK); p.rect(x + 6, top - 11, 1, 11, INK)
    for (dx, h) in ((-4, 10), (-1, 15), (2, 12), (4, 8)):
        p.line(x + dx, top - 12, x + dx, top - 12 - h, MOSS[2])
        p.put(x + dx - 1, top - 12 - h + 2, hx("#7fd3a8")); p.put(x + dx + 1, top - 12 - h + 4, hx("#46a07a")); p.put(x + dx - 1, top - 12 - h + 6, hx("#46a07a"))

def wall_shadow(p, sprite, cx, base, scale, crown=False, wave=False, flip=False, hug=False):
    s = Image.open(os.path.join(OUT, sprite + ".png")).convert("RGBA")
    if flip: s = s.transpose(Image.FLIP_LEFT_RIGHT)
    w, h = int(s.width * scale), int(s.height * scale)
    s = s.resize((w, h), Image.NEAREST); sp = s.load()
    col = hx("#0c0816")
    x0, y0 = cx - w // 2, base - h
    for j in range(h):
        for i in range(w):
            if sp[i, j][3] > 128: p.put(x0 + i, y0 + j, col)
    if wave:
        # an arm raised from the side of the body, a hand open
        ax, ay = x0 + w - int(3 * scale), y0 + int(h * 0.45)
        for k in range(int(9 * scale)):
            p.put(ax + k // 3, ay - k, col); p.put(ax + k // 3 + 1, ay - k, col)
        hx_, hy = ax + int(9 * scale) // 3, ay - int(9 * scale)
        for i in range(-2, 3):
            for j in range(-2, 2): p.put(hx_ + i, hy + j, col)
    if crown:
        cxx, cy = x0 + w // 2 + int(2 * scale), y0 + int(1 * scale)
        for i in range(-int(4 * scale), int(4 * scale) + 1): p.put(cxx + i, cy, col); p.put(cxx + i, cy - 1, col)
        for i in (-int(4 * scale), 0, int(4 * scale)):
            for j in range(2, 2 + int(3 * scale)): p.put(cxx + i, cy - j, col)
        p.put(cxx + int(2 * scale), cy - 3, col); p.put(cxx - int(2 * scale), cy - 3, col)

def pile2(p, x, base, n, seed=1):
    r = random.Random(seed)
    icons = ["button", "coin", "cap", "coin", "button"]
    spots = []
    for k in range(n):
        row = 0 if k < 6 else 1 if k < 10 else 2
        spots.append((x - 16 + (k % 6 if row == 0 else (k - 6) % 4 + 1 if row == 1 else (k - 10) % 3 + 2) * 6 + r.randrange(-1, 2), base - 8 - row * 5))
    for k, (ox, oy) in enumerate(spots):
        ic = Image.open(os.path.join(OUT, f"icon_{icons[k % 5]}.png")).convert("RGBA").resize((8, 8), Image.NEAREST); ip = ic.load()
        for j in range(8):
            for i in range(8):
                if ip[i, j][3] > 128: p.put(ox + i, oy + j, ip[i, j][:3])


def dark_memory(n):
    """The deepest dark: no desk, no lamp — only what Moss and Mosto give off."""
    p = Pic(120, 100, fill=hx("#06050c"))
    r = random.Random(n)
    for _ in range(40):
        p.put(r.randrange(120), r.randrange(100), hx("#0e0c18"))
    floor = 80
    for x in range(120):
        for y in range(floor, 100):
            p.put(x, y, hx("#0c0a14") if (x + y) % 5 else hx("#120f1e"))
    if n == 8:
        p.sprite("mosto_carry_1", 84, floor + 2)
        # he shivers: two little tremble marks
        for (x, y) in ((70, floor - 22), (98, floor - 24)): p.put(x, y, hx("#a68cf2")); p.put(x, y + 2, hx("#a68cf2"))
        p.sprite("moss_idle_0", 36, floor + 3)
        for k in range(8): p.put(44 + k // 3, floor - 12 - k, hx("#55905c")); p.put(45 + k // 3, floor - 12 - k, hx("#3a6a44"))
        for i in range(-1, 2): p.put(47 + i, floor - 21, hx("#55905c"))
        lights = [((36, floor - 10), 34, 0.9), ((80, floor - 14), 30, 0.8)]
    else:
        # together: the bead between them, the stolen light floating up above
        p.sprite("moss_idle_1", 48, floor + 3)
        p.sprite("mosto_fly_0", 74, floor + 2, flip=True)
        p.ellipse(61, floor - 4, 3, 3, hx("#b07a48"), INK); p.put(60, floor - 5, hx("#f0d0a0"))
        for j in range(-6, 7):
            for i in range(-6, 7):
                d = i * i + j * j
                if d <= 36: p.put(61 + i, 26 + j, GOLD[4] if d < 9 else GOLD[3] if d < 20 else GOLD[2])
        for y in range(34, floor - 20, 3): p.put(61, y, GOLD[3])
        lights = [((61, 26), 70, 1.0), ((61, floor - 8), 30, 0.8)]
    for y in range(100):
        for x in range(120):
            l = 0.0
            for (cx, cy), rad, k in lights:
                d = math.hypot(x - cx, (y - cy) * 1.1)
                if d < rad: l = max(l, k * (1 - d / rad))
            v = l * 3.3 + BAYER[y % 4][x % 4] / 16 * 0.9
            band = min(3, int(v))
            m = [0.35, 0.6, 0.82, 1.0][band]
            c = p.get(x, y)
            p.put(x, y, (int(c[0] * m), int(c[1] * m), int(c[2] * (m * 0.85 + 0.15))))
    for x in range(120): p.put(x, 0, INK); p.put(x, 99, INK)
    for y in range(100): p.put(0, y, INK); p.put(119, y, INK)
    p.save(f"memory_{n}")
    return p

def memory(n):
    """Panels of 《影子》: 120 × 100. The lamp on the left throws the shadow onto the wall on the right."""
    p = Pic(120, 100)
    top = 72
    if n >= 8:
        return dark_memory(n)
    room(p, top)
    bulb = desk_lamp2(p, 14, top)
    if n == 1:
        # the mint pot, and a little stone that has just stood up
        mint(p, 96, top + 2)
        p.sprite("moss_blink", 58, top + 3)
        for (x, y) in ((53, top - 22), (64, top - 24), (59, top - 27)): p.put(x, y, GOLD[3])
        wall_shadow(p, "moss_idle_0", 76, top - 6, 1.1)
    elif n == 2:
        p.sprite("moss_idle_1", 50, top + 3)
        p.line(57, top - 12, 61, top - 18, hx("#3a6a44")); p.put(61, top - 19, hx("#55905c")); p.put(62, top - 19, hx("#55905c"))
        wall_shadow(p, "moss_idle_1", 82, top - 6, 1.35, wave=True)
    elif n == 3:
        pile2(p, 58, top + 3, 9, 3)
        p.sprite("moss_mine", 38, top + 3, flip=True)
        wall_shadow(p, "moss_idle_1", 90, top - 6, 1.5, wave=True)
    elif n == 4:
        pile2(p, 66, top + 3, 13, 4)
        p.sprite("moss_mine", 44, top + 3, flip=True)
        p.ellipse(39, top - 9, 3, 3, hx("#b07a48"), INK); p.put(38, top - 10, hx("#f0d0a0"))
        wall_shadow(p, "moss_mine", 92, top - 4, 2.0, crown=True, flip=True)
    elif n == 5:
        pile2(p, 62, top + 3, 16, 5)
        pile2(p, 76, top + 3, 8, 6)
        p.sprite("moss_mine", 42, top + 3, flip=True)
        wall_shadow(p, "moss_mine", 94, top - 2, 2.35, crown=True, flip=True)
    elif n == 6:
        # the shadow has come down off the wall: a little crowned thing runs off behind the lamp with the bead
        pile2(p, 64, top + 3, 14, 7)
        p.sprite("moss_idle_1", 82, top + 3)
        p.line(75, top - 8, 70, top - 6, hx("#3a6a44"))
        p.sprite("mosto_fly_1", 46, top - 22, flip=True)
        p.ellipse(38, top - 30, 3, 3, hx("#b07a48"), INK)
    elif n == 7:
        # no shadow; the things left along the desk; she goes off empty-handed into the dark
        pile2(p, 30, top + 3, 4, 8)
        pile2(p, 58, top + 3, 2, 9)
        p.sprite("moss_run_1", 96, top + 3)
    if n <= 7:
        light_room(p, bulb, top)
    # a frame line so the panel reads as a remembered picture
    for x in range(p.w): p.put(x, 0, INK); p.put(x, p.h - 1, INK)
    for y in range(p.h): p.put(0, y, INK); p.put(p.w - 1, y, INK)
    p.save(f"memory_{n}")
    return p

if __name__ == "__main__":
    for k in ("amber", "blue", "red", "button", "coin", "cap", "bead"): icon(k)
    out = [tiles()]
    lamp()
    pics = [surface(), shop()] + [memory(n) for n in range(1, 10)]
    if "--sheet" in sys.argv:
        path = sys.argv[sys.argv.index("--sheet") + 1]
        W = 4 + sum(pc.w * 2 + 4 for pc in pics) + T * VARIANTS * 4 + 4
        sheet = Image.new("RGB", (W, 880), (40, 40, 60))
        x = 2
        t = out[0].resize((out[0].width * 4, out[0].height * 4), Image.NEAREST); sheet.paste(t, (x, 2)); x += t.width + 4
        for pc in pics:
            im = pc.im.resize((pc.w * 2, pc.h * 2), Image.NEAREST); sheet.paste(im, (x, 2)); x += im.width + 4
        sheet.save(path)
    print("ok")
