"""CI: solve every level in levels.json again with the reference engine; the par and the shortest solution must be
exactly what the file says (the Swift test target checks the same against its own engine)."""
import json, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from engine import Level, solve
levels = json.load(open(sys.argv[1], encoding='utf-8'))
bad = 0
for d in levels:
    p = solve(Level(d['rows'], d['facing'], d['mode']), 400000)
    ok = p is not None and len(p) == d['par'] and p == d['solution']
    bad += not ok
    print(f"{d['id']:>2} {d['mode']:<6} par {d['par']:>2} {'ok' if ok else 'MISMATCH'}")
print(f"{len(levels)} levels, {bad} mismatches")
sys.exit(1 if bad or len(levels) != 37 else 0)
