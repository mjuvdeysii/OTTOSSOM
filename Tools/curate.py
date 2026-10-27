"""Pick each chapter's levels from the generator's candidates, by the red-team measures:
  - the chapter's idea must carry the solution (light: Moss steps where only the beam reaches; box: blocks matter;
    shadow/pair: Mosto's mirrored steps matter),
  - no walking filler: decision density (hardness per move) high, solution 6–24 moves,
  - a rising curve: each chapter's picks sorted by hardness, spread across the range,
  - variety: no two picks with nearly the same board.
Usage: python3 Tools/curate.py KIND N [cands.json ...]  → prints the picks as JSON lines
"""
import sys, json, math
sys.path.insert(0, 'Tools')
from engine import Level, step, ORDER


def beam_steps(d):
    L = Level(d['rows'], d['facing'], d['mode'])
    s = L.start(); n = 0
    for mv in d['path']:
        ns = step(L, s, mv[0], mv[1])
        if mv[0] == 'M' and ns[0] != s[0]:
            ox, oy = s[1]; mx, my = ns[0]
            if max(abs(ox - mx), abs(oy - my)) > 1: n += 1
        s = ns
    return n


def mosto_moves(d):
    L = Level(d['rows'], d['facing'], d['mode'])
    s = L.start(); n = 0
    for mv in d['path']:
        ns = step(L, s, mv[0], mv[1])
        if ns[3] is not None and s[3] is not None and ns[3] != s[3]: n += 1
        s = ns
    return n


def similar(a, b):
    if len(a['rows']) != len(b['rows']) or len(a['rows'][0]) != len(b['rows'][0]): return False
    same = sum(1 for ra, rb in zip(a['rows'], b['rows']) for x, y in zip(ra, rb) if x == y)
    total = sum(len(r) for r in a['rows'])
    return same / total > 0.8


def score(d, kind):
    density = d['hard'] / max(1, d['len'])
    return density


def pick(cands, kind, n, lo, hi):
    ok = []
    for d in cands:
        if not (lo <= d['len'] <= hi): continue
        if kind == 'light' and beam_steps(d) < 3: continue
        if kind == 'box' and d['pushes'] < 2: continue
        if kind in ('shadow', 'pair') and mosto_moves(d) < 3: continue
        d['density'] = round(score(d, kind), 3)
        ok.append(d)
    ok.sort(key=lambda d: -d['density'])
    pool = ok[: max(n * 6, 30)]
    pool.sort(key=lambda d: d['hard'])
    picks = []
    # spread over the hardness range of the best-density pool
    for k in range(n):
        target = pool[int(k * (len(pool) - 1) / max(1, n - 1))]['hard'] if pool else 0
        best = None
        for d in pool:
            if d in picks or any(similar(d, p) for p in picks): continue
            if best is None or abs(d['hard'] - target) < abs(best['hard'] - target): best = d
        if best: picks.append(best)
    picks.sort(key=lambda d: d['hard'])
    return picks, len(ok)


if __name__ == '__main__':
    kind, n = sys.argv[1], int(sys.argv[2])
    lo, hi = int(sys.argv[3]), int(sys.argv[4])
    cands = []
    for f in sys.argv[5:]: cands += json.load(open(f))
    picks, total = pick(cands, kind, n, lo, hi)
    print(f'# {kind}: {total} usable, {len(picks)} picked', file=sys.stderr)
    for d in picks:
        print(json.dumps(dict(rows=d['rows'], facing=d['facing'], mode=d['mode'], len=d['len'], hard=d['hard'],
                              density=d['density'], states=d['states'], lost=d['lost']), ensure_ascii=False))
