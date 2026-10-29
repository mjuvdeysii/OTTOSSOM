"""A studio sheet of the three characters side by side, neutral light, for checking the IP against the character bible.
  python3 Tools/art/ip_sheet.py OUT.png [--samples 48]"""
import math, os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import bpy
import ip3d as B
sys.path.insert(0, os.path.join(HERE, "kb")); import mosto3d as MO
OUT = os.path.abspath(sys.argv[1]); ARGS = sys.argv[2:]
samples = int(ARGS[ARGS.index("--samples") + 1]) if "--samples" in ARGS else 48
s = B.reset(); s.cycles.samples = samples; B.materials(); MO.mosto_materials(); B.sprite_lights()
def place(build, x, turn=0, **kw):
    before = set(bpy.data.objects); build(**kw)
    bpy.ops.object.empty_add(location=(0, 0, 0)); p = bpy.context.object
    for o in set(bpy.data.objects) - before:
        if o is not p and o.parent is None and o.type != "CAMERA": o.parent = p
    p.location = (x, 0, 0); p.rotation_euler = (0, 0, math.radians(turn))
B.studio("#E8E1D5") if hasattr(B, "studio") else None
place(B.build_otto, -1.25, 15, glow=1.0, lid=0.55, look=(0.2, -0.1), slouch=0.8, droop=0.6, bags=True)
place(B.build_moss, 0.0, 0, lid=0.08, look=(0.15, 0.1), er=0.12, pupil=0.56, perk=0.6)
place(MO.build_mosto, 1.25, -15, moss_eye=dict(look=(-0.2, -0.1), lid=0.25), otto_eye=dict(look=(-0.2, -0.1), lid=0.35), evil=0.5, perk=0.9)
bpy.ops.object.camera_add(location=(0, -7.5, 1.6)); c = bpy.context.object
c.rotation_euler = (math.radians(84), 0, 0); c.data.lens = 55; s.camera = c
B.render(OUT, 1500, 800)
