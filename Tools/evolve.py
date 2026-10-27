"""Tighten candidate levels by hill climbing: mutate one cell at a time and keep the change when the board gets
harder to read (decision difficulty) without getting longer to walk, and the chapter's idea still carries it.
Usage: python3 Tools/evolve.py KIND SEEDS.json OUT.json [--iters 250 --keep 30 --lmax 18]
"""
import sys, json, random, math
sys.path.insert(0, 'Tools')
from engine import Level, step
from gen import analyse

ARGS = sys.argv[4:]
def arg(n, d): return type(d)(ARGS[ARGS.index(n) + 1]) if n in ARGS else d

KIND = sys.argv[1]
MODE = {'shadow': 'shadow', 'pair': 'pair'}.get(KIND, 'none')
ALLOWED = {'light': '._T', 'box': '._TB', 'shadow': '._TB=', 'pair': '._TB='}[KIND]


def mechanic(L, a):
    s = L.start(); beam = pushes = mm = 0
    for mv in a['path']:
        ns = step(L, s, mv[0], mv[1])
        if mv[0] == 'M' and ns[0] != s[0]:
            ox, oy = s[1]; mx, my = ns[0]
            if max(abs(ox - mx), abs(oy - my)) > 1: beam += 1
        if ns[4] != s[4] or ns[5] != s[5]: pushes += 1
        if s[3] is not None and ns[3] is not None and ns[3] != s[3]: mm += 1
        s = ns
    return beam, pushes, mm


def fitness(rows, facing):
    try:
        L = Level(rows, facing, MODE)
    except AssertionError:
        return None
    a = analyse(L)
    if not a: return None
    beam, pushes, mm = mechanic(L, a)
    lmax = arg('--lmax', 18)
    if a['len'] < 5 or a['len'] > lmax + 4: return None
    f = a['hard'] - 3.0 * max(0, a['len'] - lmax)
    if KIND == 'light':
        if beam < 3 or a['turns'] < 2: return None
        f += 0.5 * min(beam, 6)
    if KIND == 'box':
        if pushes < 2: return None
        # the blocks must matter: without them it is unsolvable or much longer
        L2 = Level([r.replace('B', '.') for r in rows], facing, MODE)
        a2 = analyse(L2)
        if a2 and a2['len'] <= a['len'] - 0: return None
        f += 0.8 * min(pushes, 5)
    if KIND in ('shadow', 'pair'):
        if mm < 3: return None
        f += 0.6 * min(mm, 8)
    # clutter costs a little: every tall thing should be doing something
    talls = sum(r.count('T') for r in rows)
    f -= 0.15 * talls
    return f, a, dict(beam=beam, pushes=pushes, mosto=mm)


def mutate(rows, facing, rng):
    g = [list(r) for r in rows]
    h, w = len(g), len(g[0])
    r = rng.random()
    if r < 0.12:
        return rows, rng.choice('NESW')
    if r < 0.35:
        # move one of the actors / goals to another floor cell
        movable = [(y, x) for y in range(h) for x in range(w) if g[y][x] in 'MOX*C']
        floors = [(y, x) for y in range(h) for x in range(w) if g[y][x] == '.']
        if movable and floors:
            (y0, x0), (y1, x1) = rng.choice(movable), rng.choice(floors)
            g[y1][x1], g[y0][x0] = g[y0][x0], '.'
    else:
        cells = [(y, x) for y in range(h) for x in range(w) if g[y][x] in ALLOWED]
        y, x = rng.choice(cells)
        g[y][x] = rng.choice([c for c in ALLOWED if c != g[y][x]])
        if g[y][x] == '=' and KIND in ('light', 'box'): g[y][x] = '_'
    return [''.join(r) for r in g], facing


def climb(seed, rng, iters):
    rows, facing = seed['rows'], seed['facing']
    cur = fitness(rows, facing)
    if not cur: return None
    best = (cur[0], rows, facing, cur[1], cur[2])
    for _ in range(iters):
        nr, nf = mutate(best[1], best[2], rng)
        f = fitness(nr, nf)
        if f and f[0] >= best[0]:
            best = (f[0], nr, nf, f[1], f[2])
    return best


if __name__ == '__main__':
    seeds = json.load(open(sys.argv[2]))
    rng = random.Random(arg('--seed', 1))
    seeds = [d for d in seeds if d['len'] <= arg('--lmax', 18) + 4]
    seeds.sort(key=lambda d: -d['hard'] / max(1, d['len']))
    seeds = seeds[: arg('--keep', 30)]
    out = []
    for i, s in enumerate(seeds):
        b = climb(s, rng, arg('--iters', 250))
        if not b: continue
        f, rows, facing, a, m = b
        out.append(dict(rows=rows, facing=facing, mode=MODE, fit=round(f, 2), **{k: a[k] for k in ('len', 'hard', 'states', 'lost', 'turns', 'path')}, **m))
        print(i, round(f, 2), a['len'], a['hard'], m, flush=True)
    json.dump(out, open(sys.argv[3], 'w'))
