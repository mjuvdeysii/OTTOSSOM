"""Table tops, seen straight down: 4 × 4 cells, 256 px a cell, seamless both ways, with a faint seam on every cell
edge so the grid reads without drawn lines. Also the front edges (the table's thickness) and the night bridge tile.
  python3 Tools/art/surfaces.py OUT_DIR
"""
import sys, os, math
import numpy as np
from PIL import Image, ImageFilter

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
C = 256; N = 4; S = C * N
rng = np.random.default_rng(7)
y, x = np.mgrid[0:S, 0:S].astype(np.float32) / S          # 0..1, periodic

def hexrgb(h): return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], np.float32) / 255

def pnoise(freqs, amp=1.0, fxmax=12, fymax=12):
    """Periodic noise from integer-frequency sinusoids (seamless by construction)."""
    out = np.zeros((S, S), np.float32)
    for k in range(freqs):
        fx, fy = rng.integers(1, fxmax), rng.integers(1, fymax)
        ph = rng.random() * 2 * math.pi
        out += np.sin(2 * math.pi * (fx * x + fy * y) + ph) / (1 + 0.3 * k)
    return out / np.abs(out).max() * amp

def wood(base, dark, light, grain=60, plank='h', seam=0.18):
    # long, nearly straight grain along x: the warp varies slowly along the plank
    warp = pnoise(8, 0.012, fxmax=3, fymax=8)
    t = (y + warp) * grain
    g = 0.5 + 0.5 * np.sin(2 * math.pi * t + 0.8 * pnoise(5, 1.0, fxmax=3, fymax=6))
    fine = 0.5 + 0.5 * np.sin(2 * math.pi * t * 5.1 + 0.6 * pnoise(6, 1.0, fxmax=4, fymax=12))
    pores = pnoise(20, 1.0, fxmax=40, fymax=160) * 0.5 + 0.5
    v = 0.55 * g + 0.3 * fine + 0.15 * pores
    col = base[None, None] + (dark - base)[None, None] * (v[..., None] ** 3) * 0.55 + (light - base)[None, None] * ((1 - v[..., None]) ** 3) * 0.45
    # each cell row is its own plank: a slightly different tone, a seam at its top edge, staggered butt joints
    row = np.floor(y * N).astype(int); colx = np.floor(x * N).astype(int)
    tone = rng.normal(0, 0.035, (N, N)).astype(np.float32)
    col = col * (1 + tone[row, colx])[..., None]
    fy = (y * N) % 1; fx = (x * N) % 1
    edge = np.minimum(fy, 1 - fy); edgex = np.minimum(fx, 1 - fx)
    shade = 1 - seam * np.exp(-edge * 90) - seam * 0.8 * np.exp(-edgex * 90)
    col = col * shade[..., None]
    return np.clip(col, 0, 1)

def linen(base, stitch):
    n = pnoise(14, 1.0)
    weave = 0.5 + 0.25 * np.sin(2 * math.pi * x * S / 3) + 0.25 * np.sin(2 * math.pi * y * S / 3)
    col = base[None, None] * (0.94 + 0.04 * n[..., None] + 0.04 * weave[..., None])
    fy = (y * N) % 1; fx = (x * N) % 1
    # each cell a soft quilted puff: lighter in the middle, a sunken stitched edge
    puff = np.sin(math.pi * fx) * np.sin(math.pi * fy)
    col = col * (0.86 + 0.18 * puff[..., None])
    edge = np.minimum(np.minimum(fy, 1 - fy), np.minimum(fx, 1 - fx))
    dash = ((np.floor((x + y) * S / 10) % 2) == 0)
    st = (edge < 0.012) & dash
    col[st] = stitch
    return np.clip(col, 0, 1)

def save(name, arr):
    Image.fromarray((arr * 255).astype(np.uint8)).save(os.path.join(OUT, name))

TOPS = {
    "table": wood(hexrgb("#C99563"), hexrgb("#8E5B33"), hexrgb("#E2B887"), grain=26),
    "shelf": wood(hexrgb("#E3CFA8"), hexrgb("#B89A6B"), hexrgb("#F2E4C8"), grain=34, seam=0.14),
    "cushion": linen(hexrgb("#B88E95"), hexrgb("#E8D3D6")),
    "desk": wood(hexrgb("#6B4A33"), hexrgb("#3E2717"), hexrgb("#8A6446"), grain=22, seam=0.22),
}
for name, arr in TOPS.items():
    save(f"surface_{name}.png", arr)
    # the front edge: the top's own colour in the shade below, darker towards the bottom
    e = Image.fromarray((arr[: C // 2] * 255).astype(np.uint8)).resize((S, 128)).filter(ImageFilter.GaussianBlur(1))
    ea = np.asarray(e).astype(np.float32) / 255
    k = np.linspace(0.62, 0.38, 128, dtype=np.float32)[:, None, None]
    save(f"edge_{name}.png", np.clip(ea * k, 0, 1))

# the night bridge: three violet planks of shadow, glowing at their edges
B = 256
img = np.zeros((B, B, 4), np.float32)
yy, xx = np.mgrid[0:B, 0:B].astype(np.float32) / B
for i in range(3):
    cy = 0.2 + 0.3 * i
    d = np.maximum(np.abs(xx - 0.5) - 0.42, 0) + np.maximum(np.abs(yy - cy) - 0.1, 0)
    a = np.clip(1 - d * 40, 0, 1)
    glow = np.clip(1 - (np.abs(yy - cy) / 0.13), 0, 1) ** 2
    img[..., 0] = np.maximum(img[..., 0], a * (0.42 + 0.25 * glow))
    img[..., 1] = np.maximum(img[..., 1], a * (0.3 + 0.2 * glow))
    img[..., 2] = np.maximum(img[..., 2], a * (0.82 + 0.15 * glow))
    img[..., 3] = np.maximum(img[..., 3], a * 0.88)
halo = Image.fromarray((img * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6))
out = Image.alpha_composite(halo, Image.fromarray((img * 255).astype(np.uint8)))
out.save(os.path.join(OUT, "prop_bridge.png"))
