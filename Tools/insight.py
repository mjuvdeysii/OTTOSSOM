"""What a level asks the player to see: the 'insight' its shortest solution cannot do without, read off the solution
by replaying it with the reference rules. Used to name every level (Tools/levels.txt) and to keep a chapter's
levels from repeating one idea.

Each feature is a moment in the solution:
  gap_beam     Moss steps where only the beam reaches, across a gap from Otto
  turn_away    Otto turns the lamp away from where Moss is heading
  lamp_back    Otto walks away from the goal so the beam reaches further
  fill_gap     a block pushed into a gap becomes floor
  unshade      a push lets light reach cells the block was shading
  make_dark    a push (or Otto's move) darkens cells Mosto then uses
  freeze       Moss steps while Mosto, held in the light, cannot follow
  pin          Moss steps while Mosto, against a wall or a thing, cannot follow
  bridge       Mosto crosses on a night bridge
  cut_bridge   the lamp removes a bridge Mosto is about to need
  mosto_push   Mosto pushes a block
  lead         the one the player moves walks away from its own goal so the mirror can catch up
"""
import sys
sys.path.insert(0, 'Tools')
from engine import Level, step, MIRROR, DIRS

LABEL = {
    'gap_beam': '灯照过缝', 'turn_away': '先把灯转开', 'lamp_back': '灯退一步照得更远', 'fill_gap': '积木填缝',
    'unshade': '挪开挡光的积木', 'make_dark': '为他造一片暗', 'freeze': '用光定住他', 'pin': '把他逼到墙边',
    'bridge': '暗处的桥', 'cut_bridge': '照断他的桥', 'mosto_push': '他也会推积木', 'lead': '先走远，再一起到',
}
RARITY = ['cut_bridge', 'make_dark', 'freeze', 'lead', 'mosto_push', 'unshade', 'lamp_back', 'turn_away', 'pin',
          'bridge', 'fill_gap', 'gap_beam']


def md(a, b): return abs(a[0] - b[0]) + abs(a[1] - b[1])


def features(rows, facing, mode, path):
    L = Level(rows, facing, mode)
    s = L.start(); f = {}
    def add(k): f[k] = f.get(k, 0) + 1
    goal = L.bead or L.mosto
    walker = 3 if mode == 'mirror' else 0
    walker_goal = L.crown if mode == 'mirror' else L.bead
    for mv in path:
        who, d = mv[0], mv[1]
        ns = step(L, s, who, d)
        lit0, lit1 = L.lit(s), L.lit(ns)
        if who in 'MX':
            if ns[4] != s[4] or ns[5] != s[5]:
                if ns[5] != s[5]: add('fill_gap')
                if len(lit1) > len(lit0): add('unshade')
                if len(lit1) < len(lit0): add('make_dark')
                pushed_by_mosto = (who == 'X') or (s[3] is not None and ns[3] != s[3] and (ns[3] in s[4]))
                if pushed_by_mosto: add('mosto_push')
            if who == 'M' and ns[0] != s[0]:
                ox, oy = s[1]; mx, my = ns[0]
                between = [(x, y) for x in range(min(ox, mx), max(ox, mx) + 1) for y in range(min(oy, my), max(oy, my) + 1)]
                if max(abs(ox - mx), abs(oy - my)) > 1 and any(L.ground(s, c) in '_=' for c in between): add('gap_beam')
            # the mirrored one could not follow
            if mode in ('shadow', 'pair') and s[3] is not None and ns[3] == s[3] and ns[3] is not None:
                q = (s[3][0] + DIRS[MIRROR[d]][0], s[3][1] + DIRS[MIRROR[d]][1])
                add('freeze' if q in lit1 or q in lit0 else 'pin')
            if mode in ('shadow', 'pair', 'mirror') and ns[3] is not None and s[3] is not None and ns[3] != s[3] and L.base.get(ns[3]) == '=' and ns[3] not in ns[5]:
                add('bridge')
            me = ns[walker] if walker < 3 else ns[3]
            prev = s[walker] if walker < 3 else s[3]
            if mode in ('pair', 'mirror') and walker_goal and me != prev and md(me, walker_goal) > md(prev, walker_goal): add('lead')
        else:
            if ns[1] == s[1]:
                fx, fy = DIRS[d]
                tgt = L.bead or (s[3] if s[3] else s[0])
                if tgt and (tgt[0] - s[1][0]) * fx + (tgt[1] - s[1][1]) * fy < 0: add('turn_away')
            elif L.bead and md(ns[1], L.bead) > md(s[1], L.bead): add('lamp_back')
            if mode in ('shadow', 'pair', 'mirror'):
                gone = [c for c in lit1 - lit0 if L.base.get(c) == '=' and c not in ns[5]]
                if gone: add('cut_bridge')
                if len(lit1) < len(lit0) and mode != 'shadow': add('make_dark')
        s = ns
    return f


def insight(f):
    for k in RARITY:
        if f.get(k): return k
    return None


if __name__ == '__main__':
    import json
    for d in json.load(open(sys.argv[1])):
        f = features(d['rows'], d['facing'], d['mode'], d['solution'])
        k = insight(f)
        print(d['id'], d['mode'], d['par'], LABEL.get(k, '-'), f)
