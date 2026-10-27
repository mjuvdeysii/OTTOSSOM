"""Solve a board given on stdin: first line 'facing mode', then rows."""
import sys
sys.path.insert(0, 'Tools')
from engine import Level, explore, solve
from gen import analyse
lines = [l.strip() for l in sys.stdin if l.strip()]
facing, mode = lines[0].split()
L = Level(lines[1:], facing, mode)
a = analyse(L)
print(a and {k: a[k] for k in ('len', 'hard', 'states', 'lost', 'turns')}, a and ' '.join(a['path']))
