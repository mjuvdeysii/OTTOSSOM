"""The three companions as game sprites: the same 3D models as the app (Moss and Otto: ip3d.py, Mosto: kb/mosto3d.py),
seen by the game's camera — orthographic, looking down 35°, as at a figure standing on a table — on a transparent
background under the product-photo light. The game tints them for night itself (lit warm, unlit moon-blue).

Every sprite shares one scale: SIZE px across ORTHO world units, the figure's feet at the origin. The origin's pixel
position is written to characters.json, so the game can stand each sprite on its cell.

  python3 Tools/art/characters.py moss  OUT_DIR [--samples 64 --size 512 --only idle,left]
  python3 Tools/art/characters.py otto  OUT_DIR
  python3 Tools/art/characters.py mosto OUT_DIR
"""
import json, math, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
WHO = sys.argv[1]
OUT = os.path.abspath(sys.argv[2])
sys.path.insert(0, os.path.join(HERE, "kb") if WHO == "mosto" else HERE)
import bpy
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
if WHO == "mosto":
    import mosto3d as MO
    import ip3d as B
else:
    import ip3d as B

ARGS = sys.argv[3:]
def arg(name, default):
    return type(default)(ARGS[ARGS.index(name) + 1]) if name in ARGS else default

TILT = 35          # degrees the camera looks down
ORTHO = 2.2        # world units across the frame
AIM = (0.0, 0.0, 0.62)
FACE = {"S": 0, "E": 62, "N": 180, "W": -62}   # three-quarter turns keep his eye in view
TIRED = dict(slouch=0.8, droop=0.6, bags=True)

MOSS = {
    "idle": dict(lid=0.08, look=(0.15, -0.2), er=0.12, pupil=0.56, perk=0.6, lean=-3),
    "left": dict(lid=0.05, look=(-0.95, -0.1), er=0.12, pupil=0.56, perk=0.8, lean=8),
    "right": dict(lid=0.05, look=(0.95, -0.1), er=0.12, pupil=0.56, perk=0.8, lean=-8),
    "up": dict(lid=0.0, look=(0.1, 0.8), er=0.12, pupil=0.52, perk=1.0),
    "down": dict(lid=0.15, look=(0, -0.7), er=0.12, pupil=0.56, perk=0.4, lean=-4),
    "blink": dict(shut="flat", perk=0.6, lean=-3),
    "wide": dict(lid=0.0, look=(0, 0.0), er=0.135, pupil=0.44, perk=1.0),
    "glee": dict(shut="up", perk=1.0, lean=-5),
    "sleep": dict(shut="down", perk=-0.3),
    "hop": dict(lid=0.0, look=(0.1, 0.2), er=0.12, pupil=0.5, perk=1.0, lean=-6),
}
OTTO = {
    "idle": dict(lid=0.6, look=(0, -0.2), **TIRED),
    "blink": dict(shut="flat", **TIRED),
    "yawn": dict(shut="flat", yawn=True, slouch=1.0, droop=0.9, bags=True),
    "glee": dict(lid=0.5, look=(0, -0.1), smirk=True, **TIRED),
    "wide": dict(lid=0.3, look=(0, 0.0), slouch=0.3, droop=0.2, bags=True),
    "sleep": dict(shut="down", slouch=1.2, droop=1.0, bags=True),
}
MOSTO = {
    # in the dark he is awake and scheming: gold irises, the spade glowing
    "idle": dict(moss_eye=dict(look=(0.2, -0.2), lid=0.25, pupil=0.55), otto_eye=dict(look=(0.0, -0.2), lid=0.35, pupil=0.55), evil=0.7, perk=0.9),
    "left": dict(moss_eye=dict(look=(-0.9, -0.1), lid=0.2), otto_eye=dict(look=(-0.8, -0.1), lid=0.3), evil=0.7, lean=4, perk=0.8),
    "right": dict(moss_eye=dict(look=(0.9, -0.1), lid=0.2), otto_eye=dict(look=(0.8, -0.1), lid=0.3), evil=0.7, lean=-4, perk=0.8),
    "blink": dict(shut="day", evil=0.5, perk=0.8),
    # in the light: he is seen. Eyes screwed shut, crown and horns droop a little
    "seen": dict(shut="day", evil=0.0, perk=0.1, droop=0.6, lean=-3),
    # caught, at last looked at: eyes open and wide, nothing scheming left
    "found": dict(moss_eye=dict(look=(0.0, 0.1), lid=0.0, pupil=0.66), otto_eye=dict(look=(0.0, 0.1), lid=0.0, pupil=0.66), evil=0.0, perk=1.0),
    "day": dict(),
}

def lights():
    B.sprite_lights()

def camera():
    s = bpy.context.scene
    t = math.radians(TILT)
    d = 10
    loc = Vector((AIM[0], AIM[1] - d * math.cos(t), AIM[2] + d * math.sin(t)))
    bpy.ops.object.camera_add(location=loc); c = bpy.context.object
    c.rotation_euler = (math.radians(90) - t, 0, 0)
    c.data.type = "ORTHO"; c.data.ortho_scale = ORTHO
    s.camera = c
    return c

def project(p):
    s = bpy.context.scene; bpy.context.view_layer.update()
    v = world_to_camera_view(s, s.camera, Vector(p))
    return [round(v.x, 4), round(1 - v.y, 4)]

def main():
    os.makedirs(OUT, exist_ok=True)
    size = arg("--size", 512)
    only = arg("--only", "").split(",") if "--only" in ARGS else None
    meta_path = os.path.join(OUT, "characters.json")
    meta = json.load(open(meta_path)) if os.path.exists(meta_path) else {}
    meta.update(dict(tilt=TILT, ortho=ORTHO, size=size))
    jobs = []
    if WHO == "moss":
        jobs = [(f"moss_{k}", k, None) for k in MOSS]
    elif WHO == "otto":
        jobs = [(f"otto_{k}_{f}", k, f) for k in OTTO for f in "SENW"]
    else:
        jobs = [(f"mosto_{k}", k, None) for k in MOSTO]
    for name, st, face in jobs:
        if only and name not in only and st not in only: continue
        s = B.reset(); s.render.film_transparent = True; B.materials()
        if WHO == "mosto": MO.mosto_materials()
        lights()
        s.render.resolution_x = s.render.resolution_y = size
        if WHO == "moss":
            root = None; B.build_moss(**MOSS[st])
        elif WHO == "otto":
            B.build_otto(glow=0.0, **OTTO[st])
        else:
            MO.build_mosto(**MOSTO[st])
        # turn the whole figure (every top-level object) about its feet
        if face and FACE[face]:
            bpy.ops.object.empty_add(location=(0, 0, 0)); pivot = bpy.context.object
            for o in list(bpy.data.objects):
                if o is not pivot and o.parent is None and o.type != "LIGHT" and o.type != "CAMERA":
                    o.parent = pivot
            pivot.rotation_euler = (0, 0, math.radians(FACE[face]))
        camera()
        entry = dict(feet=project((0, 0, 0)))
        if WHO == "otto":
            entry["bead"] = project(bpy.data.objects["otto_bead"].matrix_world.translation)
        if WHO == "mosto":
            entry["bead"] = project(bpy.data.objects["mosto_bead"].matrix_world.translation)
        B.render(os.path.join(OUT, name + ".png"), size, size)
        meta[name] = entry
        json.dump(meta, open(meta_path, "w"), indent=1)

main()
