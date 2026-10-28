"""Round-two candidates for Mosto's silhouette, rendered with the game camera beside the current design.
  V0 current · V1 no wings, crown slipped to one side (≥ 25°) · V2 = V1 + a shadow-drop body (narrow top, spread base)
  python3 Tools/art/mosto_variants.py OUT_DIR
"""
import math, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "kb"))
OUT = os.path.abspath(sys.argv[1]); sys.argv = [sys.argv[0]]
import bpy
import mosto3d as MO
import ip3d as B
from mathutils import Vector

_crown, _wing = MO.crown, MO.wing
def slipped_crown(top, tilt=-14, material=None):
    parts = _crown(top, tilt, material)
    root = parts[0]
    root.location = (root.location.x + 0.15, root.location.y, root.location.z - 0.07)
    root.rotation_euler = (math.radians(-6), math.radians(34), math.radians(8))
    return parts
def no_wing(name, s, material):
    o = bpy.data.objects.new(name, None); bpy.context.collection.objects.link(o); return o

VARIANTS = {
    "V0": dict(),
    "V1": dict(crown=slipped_crown, wing=no_wing),
    "V2": dict(crown=slipped_crown, wing=no_wing, body=dict(rx=0.55, ry=0.47, rz=0.43, cz=0.4, n=2.1, taper=0.36)),
    # a long shadow standing up: taller than wide, a soft point on top, the base spread like a shadow on the table
    "V3": dict(crown=slipped_crown, wing=no_wing, body=dict(rx=0.47, ry=0.42, rz=0.6, cz=0.52, n=2.0, taper=0.5)),
}
ONLY = os.environ.get("ONLY")
base_body = dict(MO.MOSTO)
TILT, ORTHO, AIM = 35, 2.2, (0, 0, 0.62)
for name, v in VARIANTS.items():
    if ONLY and name not in ONLY.split(','): continue
    MO.crown = v.get("crown", _crown); MO.wing = v.get("wing", _wing)
    MO.MOSTO.clear(); MO.MOSTO.update(base_body); MO.MOSTO.update(v.get("body", {}))
    for view in ("front", "game"):
        s = B.reset(); s.render.film_transparent = True; B.materials(); MO.mosto_materials(); B.sprite_lights()
        s.render.resolution_x = s.render.resolution_y = 512
        MO.build_mosto(moss_eye=dict(look=(0.2, -0.2), lid=0.25, pupil=0.55), otto_eye=dict(look=(0, -0.2), lid=0.35, pupil=0.55), evil=0.5, perk=0.9)
        t = math.radians(TILT if view == "game" else 6)
        bpy.ops.object.camera_add(location=(0, -10 * math.cos(t), AIM[2] + 10 * math.sin(t))); c = bpy.context.object
        c.rotation_euler = (math.radians(90) - t, 0, 0); c.data.type = "ORTHO"; c.data.ortho_scale = ORTHO; s.camera = c
        B.render(os.path.join(OUT, f"mosto_{name}_{view}.png"), 512, 512)
