"""Candidate generator: random boards, solved exhaustively, kept only when the chapter's idea is necessary.
Usage: python3 Tools/gen.py KIND COUNT SEED OUT.json   (KIND: light | box | shadow | pair)
"""
import sys, random, math, json
sys.path.insert(0, 'Tools')
from engine import Level, explore, step, won, ORDER


def analyse(L):
    r = explore(L, 120000)
    if r is None: return None
    s0, edges, dist = r
    if s0 not in dist: return None
    # walk the optimal line; at each state count how many swipes keep an optimal line
    s = s0; hard = 0.0; path = []; otto_turns = 0; pushes = 0
    while dist[s]:
        nxt = [(mv, n) for mv, n in edges[s]]
        good = [(mv, n) for mv, n in nxt if dist.get(n) == dist[s] - 1]
        hard += -math.log(len(good) / len(nxt))
        mv, n = good[0]
        if mv[0] == 'O' and n[1] == s[1]: otto_turns += 1
        if n[4] != s[4]: pushes += 1
        path.append(mv); s = n
    lost = sum(1 for x in edges if x not in dist) / len(edges)
    return dict(len=len(path), states=len(edges), hard=round(hard, 2), turns=otto_turns, pushes=pushes,
                lost=round(lost, 2), path=path)


def board(rng, w, h, kind):
    g = [['.'] * w for _ in range(h)]
    for _ in range(rng.randint(1, 3)):
        if rng.random() < 0.6:
            y = rng.randrange(1, h - 1); x0 = rng.randrange(0, w - 1); x1 = rng.randrange(x0 + 1, w + 1)
            for x in range(x0, x1): g[y][x] = '_'
        else:
            x = rng.randrange(0, w); y0 = rng.randrange(0, h - 1); y1 = rng.randrange(y0 + 1, h + 1)
            for y in range(y0, y1): g[y][x] = '_'
    for _ in range(rng.randint(0, 3)): g[rng.randrange(h)][rng.randrange(w)] = '_'
    for _ in range(rng.randint(2, 6)): g[rng.randrange(h)][rng.randrange(w)] = 'T'
    if kind != 'light':
        for _ in range(rng.randint(1 if kind == 'box' else 0, 3)):
            y, x = rng.randrange(h), rng.randrange(w)
            if g[y][x] == '.': g[y][x] = 'B'
    if kind in ('shadow', 'pair'):
        for _ in range(rng.randint(0, 3)):
            y, x = rng.randrange(h), rng.randrange(w)
            if g[y][x] == '_': g[y][x] = '='
    floors = [(x, y) for y in range(h) for x in range(w) if g[y][x] == '.']
    if len(floors) < 9: return None
    floors.sort(key=lambda p: -p[1] - rng.random() * 3)
    m, o = floors[0], floors[1]
    g[m[1]][m[0]] = 'M'; g[o[1]][o[0]] = 'O'
    rest = floors[2:]
    if kind != 'shadow':
        b = min(rest, key=lambda p: p[1] + rng.random() * 3); rest.remove(b); g[b[1]][b[0]] = '*'
    if kind in ('shadow', 'pair'):
        x = rng.choice(rest); rest.remove(x); g[x[1]][x[0]] = 'X'
    if kind == 'pair':
        c = rng.choice(rest); rest.remove(c); g[c[1]][c[0]] = 'C'
    mode = {'shadow': 'shadow', 'pair': 'pair'}.get(kind, 'none')
    return Level([''.join(r) for r in g], rng.choice(ORDER), mode)


def necessary(L, kind, a):
    if kind == 'light': return a['turns'] >= 2
    if kind == 'box':
        if a['pushes'] < 1: return False
        L2 = Level([r.replace('B', '.') for r in L.rows], L.facing, L.mode)
        a2 = analyse(L2)
        return a2 is None or a2['len'] > a['len'] + 2
    if kind == 'shadow': return a['len'] >= 6
    if kind == 'pair': return a['len'] >= 6
    return True


if __name__ == '__main__':
    kind, N, seed, out = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
    rng = random.Random(seed); res = []
    for i in range(N):
        w = rng.choice([5, 6]); h = rng.choice([6, 7, 8])
        L = board(rng, w, h, kind)
        if not L: continue
        a = analyse(L)
        if not a or not necessary(L, kind, a): continue
        res.append(dict(rows=L.rows, facing=L.facing, mode=L.mode, **a))
    res.sort(key=lambda d: d['hard'])
    json.dump(res, open(out, 'w'))
    print(kind, len(res), 'of', N)
