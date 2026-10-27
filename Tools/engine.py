"""OTTOSSOM — reference rules and solver. Game/Engine/*.swift implements exactly the same rules;
Tools/check_levels.py and the Swift test target both solve every level and must agree on the shortest solution.

Board legend
  .  floor             _  gap (nobody can walk it)        T  tall thing (blocks light and walking)
  B  wooden block      =  night bridge over a gap (there only while it is dark; only Mosto walks it)
  *  bead (Moss's goal)    C  crown (Mosto's goal, chapter 4)
  M  Moss   O  Otto   X  Mosto (each stands on floor)
A level also gives Otto's facing (N E S W) and the Mosto mode:
  none   Mosto is not on the board
  shadow Mosto mirrors Moss (east and west swapped) and only steps into the dark. Moss wins by stepping onto him
         while the lamp shows him.                                                     (chapter 3: 面对)
  pair   the same mirror, but both have a goal: Moss on the bead and Mosto on the crown at once. (chapter 4: 同行)

Who moves
  Moss   one step onto a lit cell; pushes a block one cell (into a gap it fills the gap). Never onto a bridge.
  Otto   a swipe in a new direction turns the lamp; in the direction he already faces, he steps. He never pushes
         anything: Otto lights the way and does not touch for Moss.
  Mosto  never moved directly; after each step Moss takes, he tries the mirrored step (dark cells only; he pushes
         blocks too). If that step is not possible he stays.
Light
  Otto's own cell and the 8 around it (the bead's glow), plus a 90° cone in his facing direction, stopped by tall
  things and blocks (their faces are lit).
"""
from collections import deque

DIRS = {'N': (0, -1), 'E': (1, 0), 'S': (0, 1), 'W': (-1, 0)}
ORDER = 'NESW'
MIRROR = {'N': 'N', 'S': 'S', 'E': 'W', 'W': 'E'}


class Level:
    def __init__(self, rows, facing='N', mode='none', name=''):
        self.rows = list(rows)
        self.h = len(rows); self.w = max(len(r) for r in rows)
        self.facing = facing; self.mode = mode; self.name = name
        self.base = {}; boxes = set(); self.moss = self.otto = self.mosto = None
        self.bead = self.crown = None
        for y, r in enumerate(rows):
            for x in range(self.w):
                c = r[x] if x < len(r) else '_'
                p = (x, y)
                if c in 'MOX.*CB': self.base[p] = '.'
                elif c in '_ ': self.base[p] = '_'
                elif c in 'T=': self.base[p] = c
                else: raise ValueError(repr(c))
                if c == 'M': self.moss = p
                elif c == 'O': self.otto = p
                elif c == 'X': self.mosto = p
                elif c == '*': self.bead = p
                elif c == 'C': self.crown = p
                elif c == 'B': boxes.add(p)
        self.boxes = frozenset(boxes)
        assert self.moss and self.otto, rows
        assert (self.mosto is not None) == (mode != 'none'), rows
        assert mode == 'shadow' or self.bead, rows
        assert (mode == 'pair') == (self.crown is not None), rows
        self._lit = {}

    def start(self):
        return (self.moss, self.otto, ORDER.index(self.facing), self.mosto, self.boxes, frozenset())

    def inb(self, p): return 0 <= p[0] < self.w and 0 <= p[1] < self.h

    def ground(self, s, p):
        if not self.inb(p): return 'X'
        b = self.base[p]
        if b in '_=' and p in s[5]: return '.'
        return b

    def lit(self, s):
        key = (s[1], s[2], s[4], s[5])
        r = self._lit.get(key)
        if r is None:
            r = self._lit[key] = frozenset(self._compute_lit(s))
        return r

    def _blocks(self, s, p):
        return self.ground(s, p) == 'T' or p in s[4]

    def _compute_lit(self, s):
        (ox, oy), d = s[1], s[2]
        out = set()
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                q = (ox + dx, oy + dy)
                if self.inb(q): out.add(q)
        fx, fy = DIRS[ORDER[d]]
        lx, ly = -fy, fx
        for f in range(1, max(self.w, self.h) + 1):
            for l in range(-f, f + 1):
                q = (ox + fx * f + lx * l, oy + fy * f + ly * l)
                if self.inb(q) and q not in out and self._los(s, (ox, oy), q):
                    out.add(q)
        return out

    def _los(self, s, a, b):
        (ax, ay), (bx, by) = a, b
        n = 4 * max(abs(bx - ax), abs(by - ay))
        for i in range(1, n):
            # integer arithmetic so Swift and Python round identically: cell = floor((a*n + (b-a)*i)/n + 1/2)
            cx = (2 * (ax * n + (bx - ax) * i) + n) // (2 * n)
            cy = (2 * (ay * n + (by - ay) * i) + n) // (2 * n)
            q = (cx, cy)
            if q != a and q != b and self._blocks(s, q): return False
        return True


def _push(L, s, q, dname, occupied):
    """Push the block at q in direction dname. Returns (boxes, filled) or None."""
    dx, dy = DIRS[dname]
    r = (q[0] + dx, q[1] + dy)
    if not L.inb(r) or r in s[4] or r in occupied: return None
    g = L.ground(s, r)
    nb = set(s[4]); nb.discard(q); nf = s[5]
    if g == '.' and r != L.bead and r != L.crown:
        nb.add(r)
    elif g in '_=':
        nf = s[5] | {r}
    else:
        return None
    return frozenset(nb), nf


def _mosto_step(L, s, dname):
    moss, otto, d, mosto, boxes, filled = s
    dx, dy = DIRS[dname]
    q = (mosto[0] + dx, mosto[1] + dy)
    lit = L.lit(s)
    if not L.inb(q) or q in (moss, otto) or q in lit: return s
    if q in boxes:
        r = _push(L, s, q, dname, {moss, otto, mosto})
        if r is None: return s
        return (moss, otto, d, q, r[0], r[1])
    g = L.ground(s, q)
    if g in '.=':
        return (moss, otto, d, q, boxes, filled)
    return s


def step(L, s, who, dname):
    """The state after one swipe, or None when the swipe does nothing."""
    moss, otto, d, mosto, boxes, filled = s
    dx, dy = DIRS[dname]
    if who == 'O':
        nd = ORDER.index(dname)
        if nd != d: return (moss, otto, nd, mosto, boxes, filled)
        q = (otto[0] + dx, otto[1] + dy)
        if not L.inb(q) or q == moss or q == mosto or q in boxes or L.ground(s, q) != '.': return None
        return (moss, q, d, mosto, boxes, filled)
    # Moss
    q = (moss[0] + dx, moss[1] + dy)
    lit = L.lit(s)
    if not L.inb(q) or q == otto or q not in lit: return None
    if q == mosto:
        if L.mode == 'shadow' and L.ground(s, q) == '.':
            return (q, otto, d, None, boxes, filled)        # caught, in the light
        return None
    if q in boxes:
        r = _push(L, s, q, dname, {otto, mosto} - {None})
        if r is None: return None
        ns = (q, otto, d, mosto, r[0], r[1])
    else:
        if L.ground(s, q) != '.': return None
        ns = (q, otto, d, mosto, boxes, filled)
    if ns[3] is not None:
        ns = _mosto_step(L, ns, MIRROR[dname])
    return ns


def won(L, s):
    if L.mode == 'shadow': return s[3] is None
    if L.mode == 'pair': return s[0] == L.bead and s[3] == L.crown
    return s[0] == L.bead


def moves(L, s):
    for who in 'MO':
        for dn in ORDER:
            n = step(L, s, who, dn)
            if n is not None and n != s:
                yield who + dn, n


def explore(L, limit=300000):
    """Every reachable state with its successors, and each state's distance to the nearest win (None if lost)."""
    s0 = L.start()
    seen = {s0: None}; q = deque([s0]); edges = {}
    while q:
        s = q.popleft()
        if len(seen) > limit: return None
        e = []
        for mv, n in moves(L, s):
            e.append((mv, n))
            if n not in seen: seen[n] = (s, mv); q.append(n)
        edges[s] = e
    rev = {}
    for s, es in edges.items():
        for mv, n in es: rev.setdefault(n, []).append(s)
    dist = {}
    q = deque()
    for s in edges:
        if won(L, s): dist[s] = 0; q.append(s)
    while q:
        s = q.popleft()
        for p in rev.get(s, []):
            if p not in dist: dist[p] = dist[s] + 1; q.append(p)
    return s0, edges, dist


def solve(L, limit=300000):
    r = explore(L, limit)
    if r is None: return None
    s0, edges, dist = r
    if s0 not in dist: return None
    path = []; s = s0
    while dist[s]:
        for mv, n in edges[s]:
            if dist.get(n) == dist[s] - 1:
                path.append(mv); s = n; break
    return path
