"""Round-two level search: small boards (≤ 6 × 7), short solutions (5–12 moves), one named insight each, and proof
by simulated players that the obvious play fails:
  - greedy: a player who takes whatever looks closest to done, never repeating a position
  - look3: a player who looks three moves ahead
A level is kept only when the insight it is searched for appears in its shortest solution (Tools/insight.py),
the greedy player mostly fails and the look-ahead player often fails, while the solver's line is short.

Usage: python3 Tools/gen3.py MODE ELEMENTS TARGET N SEED OUT.json [--pmin 5 --pmax 12 --iters 220]
  MODE      none | shadow | pair | mirror
  ELEMENTS  any of T B = (things on the board besides gaps)
  TARGET    an insight from Tools/insight.py (gap_beam, turn_away, …) or 'any'
"""
import sys, json, random
sys.path.insert(0, 'Tools')
from fast import analyse, bot
from insight import features

MODE, ELEM, TARGET = sys.argv[1], sys.argv[2], sys.argv[3]
N, SEED, OUT = int(sys.argv[4]), int(sys.argv[5]), sys.argv[6]
ARGS = sys.argv[7:]
def arg(n, d): return type(d)(ARGS[ARGS.index(n) + 1]) if n in ARGS else d
PMIN, PMAX = arg('--pmin', 5), arg('--pmax', 12)
rng = random.Random(SEED)


def layout(w, h):
    g = [['.'] * w for _ in range(h)]
    t = rng.choice(['h', 'h', 'v', 'cross', 'hole', 'none', 'L'])
    if t in ('h', 'cross'):
        r = rng.randrange(1, h - 1)
        for x in range(w): g[r][x] = '_'
        for _ in range(rng.choice([0, 1, 1, 2])): g[r][rng.randrange(w)] = '.'
    if t in ('v', 'cross'):
        c = rng.randrange(1, w - 1)
        for y in range(h): g[y][c] = '_'
        for _ in range(rng.choice([0, 1])): g[rng.randrange(h)][c] = '.'
    if t == 'hole':
        x0, y0 = rng.randrange(0, w - 1), rng.randrange(1, h - 2)
        for y in range(y0, y0 + 2):
            for x in range(x0, x0 + rng.choice([1, 2])): g[y][x] = '_'
    if t == 'L':
        r = rng.randrange(1, h - 1); c = rng.randrange(1, w - 1)
        for x in range(c, w): g[r][x] = '_'
        for y in range(0, r): g[y][c] = '_'
    return g


def board():
    w = rng.choice([4, 5, 5, 6]); h = rng.choice([5, 6, 6, 7])
    g = layout(w, h)
    floors = lambda: [(y, x) for y in range(h) for x in range(w) if g[y][x] == '.']
    def put(ch, k):
        f = floors(); rng.shuffle(f)
        for (y, x) in f[:k]: g[y][x] = ch
    if 'T' in ELEM: put('T', rng.randint(0, 2))
    if 'B' in ELEM: put('B', rng.randint(1, 2))
    if '=' in ELEM:
        gaps = [(y, x) for y in range(h) for x in range(w) if g[y][x] == '_']
        rng.shuffle(gaps)
        for (y, x) in gaps[: rng.randint(1, 2)]: g[y][x] = '='
    f = floors()
    if len(f) < 7: return None
    rng.shuffle(f)
    marks = ['M', 'O'] + (['*'] if MODE != 'shadow' else []) + (['X'] if MODE != 'none' else []) + (['C'] if MODE in ('pair', 'mirror') else [])
    for m, (y, x) in zip(marks, f): g[y][x] = m
    return [''.join(r) for r in g], rng.choice('NESW')


def valid(rows):
    t = ''.join(rows)
    return (t.count('M') == 1 and t.count('O') == 1 and t.count('X') == (MODE != 'none') and t.count('*') == (MODE != 'shadow')
            and t.count('C') == (MODE in ('pair', 'mirror')))


def judge(rows, facing):
    if not valid(rows): return None
    a = analyse(rows, facing, MODE, 250000)
    if not a or not (PMIN <= a['len'] <= PMAX + 2): return None
    f = features(rows, facing, MODE, a['path'])
    if TARGET != 'any' and not f.get(TARGET): return None
    g = bot(rows, facing, MODE, 1, trials=24, par=a['len'], seed=7)
    l3 = bot(rows, facing, MODE, 3, trials=16, par=a['len'], seed=9)
    talls = sum(r.count('T') for r in rows)
    size = len(rows) * len(rows[0])
    score = (4 * (1 - g) + 4 * (1 - l3) + 1.5 * a['hard'] / a['len'] + (2.5 * min(f.get(TARGET, 0), 2) if TARGET != 'any' else 0)
             - 2.5 * max(0, a['len'] - PMAX) - 0.4 * max(0, talls - 2) - 0.03 * size)
    return score, dict(rows=rows, facing=facing, mode=MODE, par=a['len'], hard=a['hard'], states=a['states'], lost=a['lost'],
                       greedy=round(g, 2), look3=round(l3, 2), features=f, target=TARGET, path=a['path'], score=round(score, 2))


def mutate(rows, facing):
    g = [list(r) for r in rows]
    h, w = len(g), len(g[0])
    r = rng.random()
    if r < 0.1: return rows, rng.choice('NESW')
    items = [(y, x) for y in range(h) for x in range(w) if g[y][x] in 'TBMOX*C']
    floors = [(y, x) for y in range(h) for x in range(w) if g[y][x] == '.']
    if r < 0.7 and items and floors:
        (y0, x0), (y1, x1) = rng.choice(items), rng.choice(floors)
        g[y1][x1], g[y0][x0] = g[y0][x0], '.'
    elif r < 0.82:
        cells = [(y, x) for y in range(h) for x in range(w) if g[y][x] in '._=TB']
        y, x = rng.choice(cells)
        opts = ['.', '_'] + [e for e in ELEM]
        g[y][x] = rng.choice([o for o in opts if o != g[y][x]])
    else:
        ts = [(y, x) for y in range(h) for x in range(w) if g[y][x] in 'TB']
        if ts: y, x = rng.choice(ts); g[y][x] = '.'
    return [''.join(r) for r in g], facing


out, tries = [], 0
while len(out) < N and tries < N * 400:
    tries += 1
    b = board()
    if not b: continue
    cur = judge(*b)
    if not cur: continue
    best = (cur[0], b[0], b[1], cur[1])
    for _ in range(arg('--iters', 220)):
        nr, nf = mutate(best[1], best[2])
        j = judge(nr, nf)
        if j and j[0] >= best[0]: best = (j[0], nr, nf, j[1])
    d = best[3]
    if d['greedy'] > 0.34: continue
    out.append(d)
    print(len(out), d['score'], 'par', d['par'], 'g', d['greedy'], 'l3', d['look3'], d['features'], flush=True)
    json.dump(out, open(OUT, 'w'), ensure_ascii=False)
