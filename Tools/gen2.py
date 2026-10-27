"""Structured level search. Boards are a few clean table tops (islands) parted by straight gaps, with a handful of
things on them — so a level reads at a glance, and every thing on it is there for a reason. Each layout is then
climbed: only the things move (tall things, blocks, night bridges, the companions, the goals), one at a time, and a
move is kept when the level gets harder to read without getting longer to walk. The chapter's idea must carry
the solution (see necessary()).

Usage: python3 Tools/gen2.py KIND N SEED OUT.json [--lmax 16 --iters 160]
"""
import sys, json, random, math
sys.path.insert(0, 'Tools')
from fast import analyse as fast_analyse

ARGS = sys.argv[5:]
def arg(n, d): return type(d)(ARGS[ARGS.index(n) + 1]) if n in ARGS else d

KIND = sys.argv[1]
MODE = {'shadow': 'shadow', 'pair': 'pair'}.get(KIND, 'none')


def layout(rng, w, h):
    g = [['.'] * w for _ in range(h)]
    t = rng.choice(['h', 'h', 'v', 'cross', 'hole', 'hh', 'step'])
    if t in ('h', 'hh', 'cross'):
        rows = [rng.randrange(2, h - 2)] if t != 'hh' else sorted(rng.sample(range(2, h - 2), 2))
        if t == 'hh' and rows[1] - rows[0] < 2: rows = rows[:1]
        for r in rows:
            for x in range(w): g[r][x] = '_'
            for _ in range(rng.choice([0, 1, 1, 2])): g[r][rng.randrange(w)] = '.'   # a plank across
    if t in ('v', 'cross'):
        c = rng.randrange(1, w - 1)
        for y in range(h): g[y][c] = '_'
        for _ in range(rng.choice([0, 1, 1])): g[rng.randrange(h)][c] = '.'
    if t == 'hole':
        x0, y0 = rng.randrange(1, w - 2), rng.randrange(2, h - 3)
        for y in range(y0, y0 + 2):
            for x in range(x0, x0 + rng.choice([1, 2])): g[y][x] = '_'
    if t == 'step':
        # two tables offset like a staircase
        r = rng.randrange(2, h - 2); c = rng.randrange(1, w - 1)
        for x in range(w): g[r][x] = '_'
        for y in range(r): g[y][c] = '_' if rng.random() < 0.5 else g[y][c]
        g[r][rng.randrange(w)] = '.'
    return g


def place(rng, g, ch, count):
    floors = [(y, x) for y in range(len(g)) for x in range(len(g[0])) if g[y][x] == '.']
    rng.shuffle(floors)
    for (y, x) in floors[:count]: g[y][x] = ch


def board(rng):
    w = rng.choice([5, 5, 6]); h = rng.choice([6, 7, 7, 8])
    g = layout(rng, w, h)
    place(rng, g, 'T', rng.randint(1, 3))
    if KIND != 'light': place(rng, g, 'B', rng.randint(1 if KIND == 'box' else 0, 2))
    if KIND in ('shadow', 'pair'):
        gaps = [(y, x) for y in range(h) for x in range(w) if g[y][x] == '_']
        rng.shuffle(gaps)
        for (y, x) in gaps[: rng.randint(1, 3)]: g[y][x] = '='
    floors = [(y, x) for y in range(h) for x in range(w) if g[y][x] == '.']
    if len(floors) < 10: return None
    floors.sort(key=lambda p: -p[0] - rng.random() * 2.5)
    (my, mx), (oy, ox) = floors[0], floors[1]
    g[my][mx] = 'M'; g[oy][ox] = 'O'
    rest = floors[2:]
    if KIND != 'shadow':
        b = min(rest, key=lambda p: p[0] + rng.random() * 2.5); rest.remove(b); g[b[0]][b[1]] = '*'
    if KIND in ('shadow', 'pair'):
        p = rng.choice(rest); rest.remove(p); g[p[0]][p[1]] = 'X'
    if KIND == 'pair':
        p = rng.choice(rest); rest.remove(p); g[p[0]][p[1]] = 'C'
    return [''.join(r) for r in g], rng.choice('NESW')


def usage(L, a):
    s = L.start(); beam = pushes = mm = 0
    for mv in a['path']:
        ns = step(L, s, mv[0], mv[1])
        if mv[0] == 'M' and ns[0] != s[0]:
            ox, oy = s[1]; mx, my = ns[0]
            if max(abs(ox - mx), abs(oy - my)) > 1: beam += 1
        if ns[4] != s[4] or ns[5] != s[5]: pushes += 1
        if s[3] is not None and ns[3] is not None and ns[3] != s[3]: mm += 1
        s = ns
    return dict(beam=beam, pushes=pushes, mosto=mm)


def strip(rows, chars):
    return [''.join('.' if c in chars else c for c in r) for r in rows]


def necessary(rows, facing, a, u):
    if KIND == 'light': return u['beam'] >= 2 and a['turns'] >= 1
    if KIND == 'box':
        if u['pushes'] < 1: return False
        a2 = fast_analyse(strip(rows, 'B'), facing, MODE)
        return a2 is None or a2['len'] > a['len'] + 1
    if KIND == 'shadow': return u['mosto'] >= 3
    if KIND == 'pair': return u['mosto'] >= 3
    return True


def valid(rows):
    t = ''.join(rows)
    return t.count('M') == 1 and t.count('O') == 1 and t.count('X') == (MODE != 'none') and t.count('*') == (MODE != 'shadow') and t.count('C') == (MODE == 'pair')


def fitness(rows, facing):
    if not valid(rows): return None
    a = fast_analyse(rows, facing, MODE, 300000)
    if not a: return None
    lmax = arg('--lmax', 16)
    if a['len'] < 6 or a['len'] > lmax + 3: return None
    u = dict(beam=a['beam'], pushes=a['pushes'], mosto=a['mosto'])
    if not necessary(rows, facing, a, u): return None
    f = a['hard'] - 3.0 * max(0, a['len'] - lmax)
    talls = sum(r.count('T') for r in rows)
    f -= 0.6 * max(0, talls - 3)
    return f, a, u


def mutate(rows, facing, rng):
    g = [list(r) for r in rows]
    h, w = len(g), len(g[0])
    r = rng.random()
    if r < 0.1: return rows, rng.choice('NESW')
    items = [(y, x) for y in range(h) for x in range(w) if g[y][x] in 'TBMOX*C']
    floors = [(y, x) for y in range(h) for x in range(w) if g[y][x] == '.']
    if r < 0.85 and items and floors:
        (y0, x0), (y1, x1) = rng.choice(items), rng.choice(floors)
        g[y1][x1], g[y0][x0] = g[y0][x0], '.'
    elif r < 0.93 and floors:
        y, x = rng.choice(floors); g[y][x] = 'T' if KIND == 'light' or rng.random() < 0.5 else 'B'
    else:
        ts = [(y, x) for y in range(h) for x in range(w) if g[y][x] in 'TB']
        if ts: y, x = rng.choice(ts); g[y][x] = '.'
    if KIND in ('shadow', 'pair') and rng.random() < 0.2:
        gaps = [(y, x) for y in range(h) for x in range(w) if g[y][x] in '_=']
        if gaps: y, x = rng.choice(gaps); g[y][x] = '=' if g[y][x] == '_' else '_'
    return [''.join(r) for r in g], facing


if __name__ == '__main__':
    N, seed, out = int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
    rng = random.Random(seed)
    res = []
    tries = 0
    while len(res) < N and tries < N * 60:
        tries += 1
        b = board(rng)
        if not b: continue
        rows, facing = b
        cur = fitness(rows, facing)
        if not cur: continue
        best = (cur[0], rows, facing, cur[1], cur[2])
        for _ in range(arg('--iters', 160)):
            nr, nf = mutate(best[1], best[2], rng)
            f = fitness(nr, nf)
            if f and f[0] >= best[0]: best = (f[0], nr, nf, f[1], f[2])
        f, rows, facing, a, u = best
        res.append(dict(rows=rows, facing=facing, mode=MODE, fit=round(f, 2), **{k: a[k] for k in ('len', 'hard', 'states', 'lost', 'turns', 'path')}, **u))
        print(len(res), round(f, 2), a['len'], a['hard'], u, flush=True)
        json.dump(res, open(out, 'w'))
