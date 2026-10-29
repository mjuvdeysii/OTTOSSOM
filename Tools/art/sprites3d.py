"""Every moving thing in the game as a transparent sprite, rendered by the same camera and night light as the room
backgrounds (scene3d.py): orthographic, looking down TILT degrees, PC pixels to a cell. Figures lean back toward the
camera so their faces read from above. Each sprite comes in two lights: "n" under the moon, and "w" with a warm
light in front (drawn over "n" in the game where a lamp, Otto's bulb or the spark is near).

A sprite's feet (the cell centre on the ground) and any glow points are written to sprites.json in pixels.

  python3 Tools/art/sprites3d.py OUT_DIR [--only otto,moss] [--samples 48]
"""
import json, math, os, random, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy
import ip3d as B
sys.path.insert(0, os.path.join(HERE, "kb"))
import mosto3d as MO
from town3d import townsfolk
import foes3d as FO
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

ARGS = sys.argv[1:]
OUT = os.path.abspath(ARGS[0])
def arg(name, default):
    return type(default)(ARGS[ARGS.index(name) + 1]) if name in ARGS else default

TILT = 48          # must match scene3d.py
S = 1.5            # world units per cell, as scene3d.py
PC = 110           # pixels per cell
LEAN = TILT - 22   # figures lean back by this much
CW, CH = 2.0, 2.6  # sprite canvas, in cells (screen units)
FEET_V = 0.80      # the feet sit this far down the canvas

def setup(warm):
    s = B.reset(); s.view_settings.look = "AgX - Punchy"; s.view_settings.exposure = 1.0
    s.cycles.samples = arg("--samples", 48); s.render.film_transparent = True
    B.materials(); MO.mosto_materials()
    world = bpy.data.worlds.new("night"); s.world = world; world.use_nodes = True
    bg = world.node_tree.nodes["Background"]; bg.inputs["Color"].default_value = B.hexcol("#1A2040"); bg.inputs["Strength"].default_value = 0.6
    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(50), math.radians(-20), math.radians(25))); m = bpy.context.object
    m.data.energy = 2.6; m.data.color = B.hexcol("#A4AEDC")[:3]; m.data.angle = math.radians(3)
    # a soft cool fill from the camera side: figures read in their own colours by moonlight, a touch brighter than the land
    bpy.ops.object.light_add(type="AREA", location=(-0.8, -3.2, 3.0), rotation=(math.radians(50), 0, math.radians(-14))); fl = bpy.context.object
    fl.data.energy = 260; fl.data.size = 3.0; fl.data.color = B.hexcol("#C8D2FF")[:3]
    if warm:
        bpy.ops.object.light_add(type="POINT", location=(0.5, -1.3, 1.7)); l = bpy.context.object
        l.data.energy = 90; l.data.color = B.hexcol("#FFB45A")[:3]; l.data.shadow_soft_size = 0.3
    return s

def camera():
    s = bpy.context.scene; t = math.radians(TILT); d = 30
    up = Vector((0, math.sin(t), math.cos(t)))
    aim = up * ((FEET_V - 0.5) * CH * S)
    bpy.ops.object.camera_add(location=aim + Vector((0, -d * math.cos(t), d * math.sin(t)))); c = bpy.context.object
    c.rotation_euler = (math.radians(90) - t, 0, 0); c.data.type = "ORTHO"; c.data.ortho_scale = CH * S
    s.render.resolution_x = int(CW * PC); s.render.resolution_y = int(CH * PC)
    s.camera = c

def px(p):
    s = bpy.context.scene; bpy.context.view_layer.update()
    v = world_to_camera_view(s, s.camera, Vector(p))
    return [round(v.x * s.render.resolution_x, 1), round((1 - v.y) * s.render.resolution_y, 1)]

def figure(build, turn=0.0, lean=True, **kw):
    before = set(bpy.data.objects)
    build(**kw)
    bpy.ops.object.empty_add(location=(0, 0, 0)); pivot = bpy.context.object
    for o in set(bpy.data.objects) - before:
        if o is not pivot and o.parent is None and o.type != "CAMERA":
            o.parent = pivot
    pivot.rotation_euler = (0, 0, math.radians(turn))           # turn first, about the feet
    bpy.ops.object.empty_add(location=(0, 0, 0)); outer = bpy.context.object
    pivot.parent = outer
    outer.rotation_euler = (math.radians(-LEAN) if lean else 0, 0, 0)   # then lean back toward the camera
    return outer

# ---------- the cast ----------
TIRED = dict(slouch=0.8, droop=0.6, bags=True)
FACE = {"S": 0, "E": 24, "W": -24, "N": 180}

def otto_jobs():
    for f in "SEWN":
        yield f"otto_idle_{f}", lambda f=f: figure(B.build_otto, FACE[f], glow=0.0, lid=0.55, look=(0, -0.1), **TIRED)
    for f in "SEW":
        yield f"otto_blink_{f}", lambda f=f: figure(B.build_otto, FACE[f], glow=0.0, shut="flat", **TIRED)
    yield "otto_glee_S", lambda: figure(B.build_otto, 0, glow=0.0, lid=0.5, look=(0, 0), smirk=True, **TIRED)
    yield "otto_wide_S", lambda: figure(B.build_otto, 0, glow=0.0, lid=0.2, look=(0, 0.1), slouch=0.3, droop=0.2, bags=True)
    yield "otto_yawn_S", lambda: figure(B.build_otto, 0, glow=0.0, shut="flat", yawn=True, slouch=1.0, droop=0.9, bags=True)
    yield "otto_sleep_S", lambda: figure(B.build_otto, 0, glow=0.0, shut="down", slouch=1.2, droop=1.0, bags=True)

MOSS = {
    "idle": dict(lid=0.08, look=(0.15, 0.1), er=0.12, pupil=0.56, perk=0.6, lean=-3),
    "blink": dict(shut="flat", perk=0.6, lean=-3),
    "left": dict(lid=0.05, look=(-0.95, 0.1), er=0.12, pupil=0.56, perk=0.8, lean=8),
    "right": dict(lid=0.05, look=(0.95, 0.1), er=0.12, pupil=0.56, perk=0.8, lean=-8),
    "up": dict(lid=0.0, look=(0.1, 0.9), er=0.12, pupil=0.52, perk=1.0),
    "down": dict(lid=0.15, look=(0, -0.6), er=0.12, pupil=0.56, perk=0.4, lean=-4),
    "wide": dict(lid=0.0, look=(0, 0.2), er=0.135, pupil=0.44, perk=1.0),
    "glee": dict(shut="up", perk=1.0, lean=-5),
    "sad": dict(lid=0.35, look=(0, -0.7), er=0.12, pupil=0.6, perk=-0.4),
    "sleep": dict(shut="down", perk=-0.3),
    # "mine!": drawn up tall, leaves pressed up together, eyes set on the thing
    "mine": dict(lid=0.32, look=(0, 0.0), er=0.12, pupil=0.5, perk=2.1, hop=0.1),
}
def moss_jobs():
    for k, kw in MOSS.items():
        yield f"moss_{k}", lambda kw=kw: figure(B.build_moss, 0, **kw)
    yield "moss_back", lambda: figure(B.build_moss, 180, **MOSS["idle"])

MOSTO = {
    "idle": dict(moss_eye=dict(look=(0.2, -0.1), lid=0.25, pupil=0.55), otto_eye=dict(look=(0.0, -0.1), lid=0.35, pupil=0.55), evil=0.5, perk=0.9),
    "blink": dict(shut="day", evil=0.3, perk=0.8),
    "left": dict(moss_eye=dict(look=(-0.9, -0.1), lid=0.2), otto_eye=dict(look=(-0.8, -0.1), lid=0.3), evil=0.5, lean=4, perk=0.8),
    "right": dict(moss_eye=dict(look=(0.9, -0.1), lid=0.2), otto_eye=dict(look=(0.8, -0.1), lid=0.3), evil=0.5, lean=-4, perk=0.8),
    "glee": dict(moss_eye=dict(look=(0.0, 0.0), lid=0.45, pupil=0.5), otto_eye=dict(look=(0.0, 0.0), lid=0.5, pupil=0.5), evil=1.0, perk=1.0),
    "caught": dict(moss_eye=dict(look=(0.0, 0.1), lid=0.0, pupil=0.66), otto_eye=dict(look=(0.0, 0.1), lid=0.0, pupil=0.66), evil=0.0, perk=0.1, droop=0.6),
    "sleep": dict(shut="day", evil=0.0, perk=0.0, droop=0.8),
}
def mosto_jobs():
    for k, kw in MOSTO.items():
        yield f"mosto_{k}", lambda kw=kw: figure(MO.build_mosto, 0, **kw)
    yield "mosto_back", lambda: figure(MO.build_mosto, 180, **MOSTO["idle"])

def object_jobs():
    def boulder():
        m = B.rubber("boulder", "#7A7488", rough=0.7)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4, location=(0, 0, 0.44)); o = bpy.context.object
        r = random.Random(3)
        for v in o.data.vertices: v.co *= 1 + 0.07 * (r.random() - 0.5)
        o.scale = (0.56, 0.52, 0.46); o.data.materials.append(m); B.smooth(o, 1)
    def shadow(shut=False):
        m = B.mat("shadowBody", "#06070C", rough=0.85)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, location=(0, 0, 0.42)); o = bpy.context.object
        o.scale = (0.44, 0.38, 0.5); o.data.materials.append(m); B.smooth(o, 1)
        eye = B.mat("seye", "#CFD6FF", emit="#CFD6FF", emit_strength=2.5)
        for s in (-1, 1):
            B.sphere(f"se{s}", (s * 0.13, -0.35, 0.58), (0.055, 0.02, 0.01 if shut else 0.04), eye)
        figure_lean([o] + [ob for ob in bpy.data.objects if ob.name.startswith("se")])
    def lantern(lit):
        m = B.mat("lantern", "#FFD27A", emit="#FFD27A", emit_strength=12) if lit else B.mat("lanternOff", "#2A2A30", rough=0.2, coat=0.6)
        B.sphere("lantern", (0, 0.1, 1.28), (0.16, 0.16, 0.2), m)
        metal = B.mat("metal", "#3A3A44", rough=0.4)
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.17, depth=0.06, location=(0, 0.1, 1.5)); bpy.context.object.data.materials.append(metal)
    def bars():
        metal = B.mat("metal", "#5A5E70", rough=0.35, coat=0.3)
        for k in range(4):
            bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.045, depth=1.1, location=((k - 1.5) * S * 0.22, 0, 0.55))
            bpy.context.object.data.materials.append(metal)
    yield "boulder", boulder
    yield "shadow", lambda: shadow(False)
    yield "shadow_blink", lambda: shadow(True)
    yield "lantern_on", lambda: lantern(True)
    yield "lantern_off", lambda: lantern(False)
    yield "bars", bars
    yield "npc_h", lambda: figure(lambda: townsfolk("#8A6A5A", "#3A3A44", who="hank"), 0)
    yield "npc_d", lambda: figure(lambda: townsfolk("#E08A5A", "#E8C24A", small=True, who="dora"), 0)
    yield "npc_dl", lambda: figure(lambda: townsfolk("#E08A5A", "#E8C24A", small=True, who="dora", lit=True), 0)
    yield "npc_n", lambda: figure(lambda: townsfolk("#6A7AA8", "#5A3A5A", scarf="#C04A4A", who="lynn"), 0)

def foe_jobs():
    for k in ("shade", "shell", "moth", "fang", "bigshade", "maw"):
        yield f"foe_{k}", lambda k=k: figure(getattr(FO, k), 0)
    yield "chest", lambda: figure(lambda: FO.chest(False), 0)
    yield "chest_open", lambda: figure(lambda: FO.chest(True), 0)

def figure_lean(objs):
    bpy.ops.object.empty_add(location=(0, 0, 0)); pivot = bpy.context.object
    for o in objs: o.parent = pivot
    pivot.rotation_euler = (math.radians(-LEAN), 0, 0)

def spark_jobs():
    """The spark in six frames of flicker: a toy flame, yellow root to red tips, a white-hot core."""
    for i in range(6):
        def build(i=i):
            r = random.Random(100 + i)
            at = Vector((0, 0, 0.0))
            def fm(name, root, mid, tip, strength):
                m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree
                for n in list(nt.nodes): nt.nodes.remove(n)
                o = nt.nodes.new("ShaderNodeOutputMaterial"); e = nt.nodes.new("ShaderNodeEmission")
                tc = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ")
                ramp = nt.nodes.new("ShaderNodeValToRGB"); cr = ramp.color_ramp
                cr.elements[0].position = 0.25; cr.elements[0].color = B.hexcol(root)
                cr.elements[1].position = 0.92; cr.elements[1].color = B.hexcol(tip)
                cr.elements.new(0.55).color = B.hexcol(mid)
                nt.links.new(tc.outputs["Generated"], sep.inputs[0]); nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
                nt.links.new(ramp.outputs["Color"], e.inputs["Color"]); e.inputs["Strength"].default_value = strength
                nt.links.new(e.outputs[0], o.inputs["Surface"]); return m
            def tear(at, rr, hh, mat, lean):
                bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=24, location=at); o = bpy.context.object
                for v in o.data.vertices:
                    z = v.co.z; k = (z + 1) / 2
                    sq = ((1 - k) / 0.7) ** 0.55 if k > 0.3 else 1.0
                    v.co.x *= sq; v.co.y *= sq; v.co.z = z if z < 0 else z * 1.9
                    v.co.x += lean[0] * k * k * 2; v.co.y += lean[1] * k * k * 2
                o.scale = (rr, rr, hh / 3.4); o.data.materials.append(mat)
                for p in o.data.polygons: p.use_smooth = True
            sc = 1.9; w = r.uniform(-0.05, 0.05)
            B.sphere("core", at + Vector((0, -0.12 * sc, -0.02 * sc)), (0.06 * sc,) * 3, B.mat("coreM", "#FFF8E0", emit="#FFF8E0", emit_strength=12))
            tear(at + Vector((0, -0.06 * sc, -0.02 * sc)), 0.1 * sc, (0.36 + r.uniform(-0.04, 0.06)) * sc, fm("fi", "#FFE680", "#FFB820", "#FF8A10", 1.6), (w, 0))
            tear(at + Vector((0, 0, -0.05 * sc)), 0.17 * sc, (0.62 + r.uniform(-0.06, 0.08)) * sc, fm("fo", "#FFA010", "#FF5A00", "#D02000", 1.3), (0.04 + w, 0))
            for j, dx in enumerate((-0.09, 0.1)):
                tear(at + Vector((dx * sc, 0.02, -0.04 * sc)), 0.07 * sc, (0.32 + r.uniform(-0.08, 0.08)) * sc, fm(f"fs{j}", "#FF9000", "#F04800", "#C01800", 1.2), (dx * 0.6 + r.uniform(-0.03, 0.03), 0))
        yield f"spark_{i}", build

def main():
    os.makedirs(OUT, exist_ok=True)
    only = arg("--only", "").split(",") if "--only" in ARGS else None
    meta_path = os.path.join(OUT, "sprites.json")
    meta = json.load(open(meta_path)) if os.path.exists(meta_path) else {}
    meta.update(dict(pc=PC, tilt=TILT, cw=CW, ch=CH))
    jobs_only = arg("--jobs", "").split(",") if "--jobs" in ARGS else None
    groups = {"otto": otto_jobs, "moss": moss_jobs, "mosto": mosto_jobs, "objects": object_jobs, "spark": spark_jobs, "foes": foe_jobs}
    for g, jobs in groups.items():
        if only and g not in only: continue
        for name, build in jobs():
            if jobs_only and name not in jobs_only: continue
            for light in ("n", "w"):
                if g == "spark" and light == "w": continue
                setup(light == "w")
                build()
                camera()
                entry = dict(feet=px((0, 0, 0)))
                if "otto_bead" in bpy.data.objects: entry["bead"] = px(bpy.data.objects["otto_bead"].matrix_world.translation)
                if "mosto_bead" in bpy.data.objects: entry["tail"] = px(bpy.data.objects["mosto_bead"].matrix_world.translation)
                if name.startswith("mosto"):
                    piv = [o for o in bpy.data.objects if o.type == "EMPTY" and o.parent is None and o.name.startswith("Empty")]
                    hold = Vector((0, -0.55, 0.55))
                    if piv: hold = piv[0].matrix_world @ hold
                    entry["hold"] = px(hold)
                B.render(os.path.join(OUT, f"{name}_{light}.png" if g != "spark" else f"{name}.png"), int(CW * PC), int(CH * PC))
                meta[name] = entry
                json.dump(meta, open(meta_path, "w"), indent=1)

main()
