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
        for x in range(4, 12): put(x, y, (200, 200, 200))   # glass (tinted at runtime)
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

def desk(p, top=78):
    """A desk top in lamplight, the wall behind."""
    p.grad(0, 0, p.w, top, [hx("#1c1830"), hx("#24203c"), hx("#2c2646")])
    p.rect(0, top, p.w, p.h - top, WOOD[2]); p.rect(0, top, p.w, 1, WOOD[4]); p.rect(0, top + 1, p.w, 1, INK)
    for x in range(0, p.w, 13): p.rect(x, top + 2, 1, p.h, WOOD[1])

def desk_lamp(p, x, top, on=True):
    p.rect(x - 1, top - 34, 2, 30, INK); p.rect(x - 7, top - 4, 14, 4, INK); p.rect(x - 6, top - 3, 12, 2, STONE[3])
    for j in range(10):
        w = 4 + j
        p.rect(x - w + 6, top - 44 + j, 2 * w - 4, 1, hx("#2a6a52") if j < 9 else INK)
    if on:
        for j in range(30):
            for i in range(-j, j + 1):
                X, Y = x + 6 + i, top - 34 + j
                if (X + Y) % 2 == 0 and 0 <= X < p.w:
                    c = p.get(X, Y)
                    if c: p.put(X, Y, tuple(min(255, int(v * 1.25 + 14)) for v in c))
        p.rect(x + 2, top - 35, 8, 1, GOLD[4])

def mint(p, x, top):
    p.rect(x - 6, top - 10, 12, 10, hx("#7a4a3a")); p.rect(x - 7, top - 11, 14, 2, hx("#9a5a44")); p.rect(x - 6, top - 1, 12, 1, INK)
    for (dx, h) in ((-4, 10), (-1, 14), (2, 12), (4, 8)):
        p.line(x + dx, top - 11, x + dx, top - 11 - h, MOSS[2])
        p.put(x + dx - 1, top - 11 - h + 2, hx("#7fd3a8")); p.put(x + dx + 1, top - 11 - h + 4, hx("#46a07a"))

def shadow_on_wall(p, x, base, scale=1.0, crown=False, wave=False, back=False):
    """Moss's shadow on the wall: her shape in flat dark violet, bigger as it grows."""
    s = Image.open(os.path.join(OUT, "moss_idle_0.png")).convert("RGBA")
    if back: s = s.transpose(Image.FLIP_LEFT_RIGHT)
    w, h = int(s.width * scale), int(s.height * scale)
    s = s.resize((w, h), Image.NEAREST)
    sp = s.load()
    col = hx("#120e22")
    for j in range(h):
        for i in range(w):
            if sp[i, j][3] > 128: p.put(x - w // 2 + i, base - h + j, col)
    if wave:
        for k in range(int(6 * scale)): p.put(x + w // 2 + k // 2, base - h + 4 - k, col); p.put(x + w // 2 + k // 2 + 1, base - h + 4 - k, col)
    if crown:
        cx, cy = x + int(2 * scale), base - h - 1
        for i in range(-3, 4): p.put(cx + i, cy, col)
        for i in (-3, 0, 3): p.put(cx + i, cy - 1, col); p.put(cx + i, cy - 2, col)
        p.put(cx - 2, cy - 1, col); p.put(cx + 2, cy - 1, col)

def pile(p, x, base, n):
    r = random.Random(n)
    icons = ["button", "coin", "cap", "button", "coin"]
    for k in range(n):
        ic = Image.open(os.path.join(OUT, f"icon_{icons[k % 5]}.png")).convert("RGBA").resize((8, 8), Image.NEAREST)
        ip = ic.load()
        ox, oy = x - 14 + (k * 7) % 28 + r.randrange(-1, 2), base - 8 - (k // 4) * 4
        for j in range(8):
            for i in range(8):
                if ip[i, j][3] > 128: p.put(ox + i, oy + j, ip[i, j][:3])

def memory(n):
    """Panels of 《影子》, 120 × 100, shown 2× in the game."""
    p = Pic(120, 100)
    top = 74
    desk(p, top)
    if n == 1:
        desk_lamp(p, 24, top); mint(p, 88, top)
        p.sprite("moss_blink", 64, top + 2)
        for (x, y) in ((58, top - 24), (70, top - 24)): p.put(x, y, GOLD[3])
    elif n == 2:
        desk_lamp(p, 16, top)
        shadow_on_wall(p, 82, top - 4, 1.0, wave=True)
        p.sprite("moss_idle_1", 50, top + 2)
        for k in range(5): p.put(64 + k // 2, top - 18 - k, MOSS[2]); p.put(65 + k // 2, top - 18 - k, MOSS[2])
    elif n == 3:
        desk_lamp(p, 16, top)
        shadow_on_wall(p, 94, top - 4, 1.15, wave=True)
        pile(p, 52, top + 2, 9)
        p.sprite("moss_mine", 36, top + 2, flip=True)
    elif n == 4:
        desk_lamp(p, 16, top)
        shadow_on_wall(p, 84, top - 4, 1.6, crown=True, back=True)
        pile(p, 58, top + 2, 14)
        p.sprite("moss_mine", 42, top + 2, flip=True)
        p.ellipse(46, top - 10, 3, 3, hx("#b07a48"), INK)
    p.save(f"memory_{n}")
    return p

if __name__ == "__main__":
    for k in ("amber", "blue", "red", "button", "coin", "cap", "bead"): icon(k)
    out = [tiles()]
    lamp()
    pics = [surface(), shop()] + [memory(n) for n in (1, 2, 3, 4)]
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
