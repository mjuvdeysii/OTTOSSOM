"""ctypes binding for fast.c: analyse(rows, facing, mode) -> dict like gen.analyse (search only)."""
import ctypes, os, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
LIB = os.path.join(HERE, 'libfast.so')
if not os.path.exists(LIB) or os.path.getmtime(LIB) < os.path.getmtime(os.path.join(HERE, 'fast.c')):
    subprocess.check_call(['gcc', '-O2', '-shared', '-fPIC', '-o', LIB, os.path.join(HERE, 'fast.c'), '-lm'])
_lib = ctypes.CDLL(LIB)
_lib.analyse.argtypes = [ctypes.c_char_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_char_p, ctypes.POINTER(ctypes.c_double)]
_lib.analyse.restype = ctypes.c_int
MODES = {'none': 0, 'shadow': 1, 'pair': 2}

def analyse(rows, facing, mode, limit=400000):
    w = max(len(r) for r in rows); h = len(rows)
    flat = ''.join(r.ljust(w, '_') for r in rows).encode()
    path = ctypes.create_string_buffer(2048)
    stats = (ctypes.c_double * 8)()
    par = _lib.analyse(flat, w, h, 'NESW'.index(facing), MODES[mode], limit, path, stats)
    if par < 0: return None
    p = path.value.decode()
    return dict(len=par, states=int(stats[0]), lost=round(stats[1], 2), hard=round(stats[2], 2), turns=int(stats[3]),
                pushes=int(stats[4]), beam=int(stats[5]), mosto=int(stats[6]), path=[p[i:i + 2] for i in range(0, len(p), 2)])
