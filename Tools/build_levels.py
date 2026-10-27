"""Build Game/Resources/levels.json from the designed boards in Tools/levels.txt: each board is solved by the
reference engine, and its shortest solution and par are written next to it.

levels.txt: one block per bead —
    # <id> <chapter> <facing> <mode>
    rows…
"""
import json, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from engine import Level, explore, solve

def read(path):
    out, cur = [], None
    for line in open(path, encoding='utf-8'):
        line = line.rstrip('\n')
        if line.startswith('#'):
            p = line[1:].split()
            cur = dict(id=int(p[0]), chapter=int(p[1]), facing=p[2], mode=p[3], rows=[])
            out.append(cur)
        elif line.strip() and cur is not None and not line.startswith(';'):
            cur['rows'].append(line.strip())
    return out

if __name__ == '__main__':
    src = sys.argv[1] if len(sys.argv) > 1 else 'Tools/levels.txt'
    dst = sys.argv[2] if len(sys.argv) > 2 else 'Game/Resources/levels.json'
    levels = read(src)
    res = []
    for d in levels:
        L = Level(d['rows'], d['facing'], d['mode'])
        path = solve(L, 400000)
        assert path is not None, f"level {d['id']} has no solution"
        s0, edges, dist = explore(L, 400000)
        res.append(dict(id=d['id'], chapter=d['chapter'], rows=d['rows'], facing=d['facing'], mode=d['mode'], par=len(path), solution=path))
        print(f"{d['id']:>2}  ch{d['chapter']}  {d['mode']:<6}  par {len(path):>2}  states {len(edges):>6}  {' '.join(path)}")
    ids = [d['id'] for d in res]
    assert ids == list(range(len(ids))), ids
    json.dump(res, open(dst, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
