"""The table's things and surfaces, rendered with the same camera and light as the companions (characters.py):
orthographic, 35° down, 512 px across 2.2 world units, the thing's foot at the origin, transparent background.
One world unit is one cell of the board.

  python3 Tools/art/props.py OUT_DIR [--samples 64 --only cup,book]
Surfaces (surface_<name>.png, 1024 px for 4 × 4 cells, seen straight down) and edges (edge_<name>.png) as well.
"""
import math, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy
from mathutils import Vector
import ip3d as B

OUT = os.path.abspath(sys.argv[1])
ARGS = sys.argv[2:]
def arg(name, default):
    return type(default)(ARGS[ARGS.index(name) + 1]) if name in ARGS else default

TILT, ORTHO, AIM = 35, 2.2, (0.0, 0.0, 0.62)
mat = B.mat

def camera():
    s = bpy.context.scene; t = math.radians(TILT)
    bpy.ops.object.camera_add(location=(AIM[0], AIM[1] - 10 * math.cos(t), AIM[2] + 10 * math.sin(t))); c = bpy.context.object
    c.rotation_euler = (math.radians(90) - t, 0, 0); c.data.type = "ORTHO"; c.data.ortho_scale = ORTHO; s.camera = c

def top_camera(width):
    s = bpy.context.scene
    bpy.ops.object.camera_add(location=(0, 0, 10)); c = bpy.context.object
    c.rotation_euler = (0, 0, 0); c.data.type = "ORTHO"; c.data.ortho_scale = width; s.camera = c

def rbox(name, size, loc, material, bevel=0.06, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot); o = bpy.context.object; o.name = name
    o.scale = size; bpy.ops.object.transform_apply(scale=True)
    m = o.modifiers.new("bevel", "BEVEL"); m.width = bevel; m.segments = 6
    o.data.materials.append(material)
    for p in o.data.polygons: p.use_smooth = True
    return o

def cyl(name, r, h, loc, material, verts=64, rot=(0, 0, 0), bevel=0.02):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot); o = bpy.context.object; o.name = name
    if bevel:
        m = o.modifiers.new("bevel", "BEVEL"); m.width = bevel; m.segments = 4
    o.data.materials.append(material)
    for p in o.data.polygons: p.use_smooth = True
    return o

def wood(name, a, b, scale=1.6, rough=0.5, coat=0.25):
    m = mat(name, a, rough=rough, coat=coat, bump=(18, 0.08))
    nt = m.node_tree; p = nt.nodes["Principled BSDF"]
    w = nt.nodes.new("ShaderNodeTexWave"); w.inputs["Scale"].default_value = scale; w.inputs["Distortion"].default_value = 5; w.inputs["Detail"].default_value = 3
    r = nt.nodes.new("ShaderNodeValToRGB"); r.color_ramp.elements[0].color = B.hexcol(a); r.color_ramp.elements[1].color = B.hexcol(b)
    nt.links.new(w.outputs["Fac"], r.inputs["Fac"]); nt.links.new(r.outputs["Color"], p.inputs["Base Color"])
    return m

def contact_shadow():
    # a shadow catcher under the thing, so it sits on the table instead of floating
    bpy.ops.mesh.primitive_plane_add(size=3, location=(0, 0, 0)); p = bpy.context.object
    p.is_shadow_catcher = True

# ---------- things ----------

def bead():
    m = mat("bead", "#E8862A", rough=0.25, coat=0.8)
    s = B.sphere("bead", (0, 0, 0.29), (0.27, 0.27, 0.27), m)
    hole = mat("hole", "#5A3417", rough=0.6)
    B.sphere("hole", (0, -0.255, 0.31), (0.06, 0.03, 0.06), hole)
    # a short loop of string coming out of the hole
    B.tube("string", [(0, -0.25, 0.29), (0.1, -0.33, 0.2), (0.22, -0.3, 0.06), (0.32, -0.18, 0.02)], 0.012, mat("string", "#C9483A", rough=0.8))

def crown():
    sys.path.insert(0, os.path.join(HERE, "kb"))
    cushion = mat("velvet", "#4A2E8F", rough=0.85, sheen=0.6)
    rbox("cushion", (0.62, 0.62, 0.16), (0, 0, 0.08), cushion, bevel=0.07)
    gold = mat("gold", "#E3B24A", rough=0.35, coat=0.3)
    # three points, as Mosto's own crown
    pts = []
    n = 48; r = 0.17
    verts, faces = [], []
    for i in range(n):
        a = 2 * math.pi * i / n
        h = 0.1 + 0.12 * max(0, math.cos(3 * a)) ** 3
        verts += [(r * math.cos(a), r * math.sin(a), 0.16), (r * math.cos(a), r * math.sin(a), 0.16 + h)]
    for i in range(n):
        j = (i + 1) % n
        faces.append((2 * i, 2 * j, 2 * j + 1, 2 * i + 1))
    me = bpy.data.meshes.new("crown"); me.from_pydata(verts, [], faces)
    o = bpy.data.objects.new("crown", me); bpy.context.collection.objects.link(o)
    sol = o.modifiers.new("s", "SOLIDIFY"); sol.thickness = 0.025
    o.data.materials.append(gold); B.smooth(o, 2)
    o.rotation_euler = (math.radians(-10), math.radians(8), 0)

def block():
    rbox("block", (0.74, 0.74, 0.74), (0, 0, 0.37), wood("beech", "#E2BE88", "#D2A86E", scale=2.2), bevel=0.07)

def tower():
    cols = [("#E2BE88", "#D2A86E"), ("#4FA3A0", "#43908D"), ("#F2C14E", "#E0AE3C")]
    z = 0
    for i, (a, b) in enumerate(cols):
        s = 0.66 - i * 0.08
        rbox(f"t{i}", (s, s, 0.3), (0.02 * (i % 2), -0.01 * i, z + 0.15), wood(f"tw{i}", a, b, scale=2.4), bevel=0.05, rot=(0, 0, math.radians(8 * (i - 1))))
        z += 0.3

def cup():
    glaze = mat("glaze", "#F1E6D2", rough=0.25, coat=0.5)
    stripe = mat("stripe", "#3D6FA8", rough=0.3, coat=0.4)
    o = cyl("cup", 0.25, 0.56, (0, 0, 0.28), glaze, bevel=0.03)
    cyl("stripe", 0.252, 0.07, (0, 0, 0.4), stripe, bevel=0)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.13, minor_radius=0.035, location=(0.27, 0, 0.3), rotation=(math.radians(90), 0, 0))
    h = bpy.context.object; h.data.materials.append(glaze); B.smooth(h, 1)
    cyl("tea", 0.215, 0.02, (0, 0, 0.53), mat("tea", "#6B3A1C", rough=0.1), bevel=0)

def book():
    # a picture book standing half open, as on a child's table
    cover = mat("cover", "#E2644B", rough=0.6)
    back = mat("cover2", "#F2C14E", rough=0.6)
    pages = mat("pages", "#FBF6EA", rough=0.8)
    for s, m in ((-1, cover), (1, back)):
        rbox(f"board{s}", (0.42, 0.04, 0.62), (s * 0.18, 0, 0.31), m, bevel=0.015, rot=(0, 0, math.radians(s * 28)))
        rbox(f"pages{s}", (0.38, 0.05, 0.58), (s * 0.17, 0.03, 0.31), pages, bevel=0.01, rot=(0, 0, math.radians(s * 28)))
    B.sphere("sun", (-0.19, -0.14, 0.42), (0.07, 0.01, 0.07), mat("sun", "#F2C14E", rough=0.5))

def rings():
    B.ring_stacker((0, 0, 0), 1.25)

def jar():
    clay = mat("jar", "#8FA98A", rough=0.45, coat=0.3)
    o = cyl("jar", 0.25, 0.5, (0, 0, 0.25), clay, bevel=0.06)
    cyl("lid", 0.2, 0.08, (0, 0, 0.54), wood("lidw", "#C99A62", "#B98450", scale=3), bevel=0.02)
    B.sphere("knob", (0, 0, 0.6), (0.05, 0.05, 0.04), wood("knobw", "#C99A62", "#B98450", scale=3))

def knob():
    fab = mat("knit", "#C98F8A", rough=0.95, sheen=0.8)
    B.sphere("pouf", (0, 0, 0.26), (0.36, 0.36, 0.27), fab)
    B.sphere("button", (0, 0, 0.53), (0.06, 0.06, 0.025), mat("btn", "#7C4A63", rough=0.6))

def roll():
    a = mat("blanket", "#E8D6B8", rough=0.95, sheen=0.6); b = mat("blanketS", "#B5594F", rough=0.95, sheen=0.6)
    cyl("roll", 0.27, 0.8, (0, 0, 0.27), a, rot=(0, math.radians(90), 0), bevel=0.08)
    for x in (-0.22, 0.22):
        cyl(f"band{x}", 0.275, 0.08, (x, 0, 0.27), b, rot=(0, math.radians(90), 0), bevel=0.02)

def key(dark=False):
    cap = mat("cap", "#3A3F4A" if dark else "#E9E6DF", rough=0.55, coat=0.15)
    o = rbox("cap", (0.78, 0.78, 0.4), (0, 0, 0.2), cap, bevel=0.1)
    # the dish on top
    B.sphere("dish", (0, 0, 0.43), (0.3, 0.3, 0.05), mat("dish", "#33373F" if dark else "#DEDAD2", rough=0.5))
    mark = mat("mark", "#F4EBDD" if dark else "#5B45B0", rough=0.5)
    if dark:
        rbox("bar", (0.22, 0.05, 0.02), (0, 0, 0.47), mark, bevel=0.01)
    else:
        B.sphere("dot", (0, 0, 0.475), (0.05, 0.05, 0.012), mark)

def mug():
    m = mat("mug", "#26304F", rough=0.35, coat=0.5)
    cyl("mug", 0.26, 0.6, (0, 0, 0.3), m, bevel=0.03)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.14, minor_radius=0.04, location=(0.28, 0, 0.32), rotation=(math.radians(90), 0, 0))
    h = bpy.context.object; h.data.materials.append(m); B.smooth(h, 1)
    cyl("coffee", 0.22, 0.02, (0, 0, 0.57), mat("coffee", "#2B170C", rough=0.1), bevel=0)

THINGS = dict(bead=bead, crown=crown, block=block, tower=tower, cup=cup, book=book, rings=rings, jar=jar, knob=knob,
              roll=roll, key=lambda: key(False), key2=lambda: key(True), mug=mug)

# ---------- surfaces (straight down, flat light) ----------

def flat_light():
    w = bpy.data.worlds.new("w"); bpy.context.scene.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (1, 1, 1, 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0

def surface_mat(name):
    if name == "table": return wood("table", "#C08A55", "#D6A873", scale=1.1, coat=0.2)
    if name == "shelf": return wood("shelf", "#E2C79C", "#D3B482", scale=0.9, coat=0.1)
    if name == "desk": return wood("desk", "#5A3A26", "#6E4A31", scale=1.3, coat=0.2)
    if name == "cushion":
        m = mat("linen", "#B98C93", rough=0.95, bump=(160, 0.25))
        nt = m.node_tree; p = nt.nodes["Principled BSDF"]
        n = nt.nodes.new("ShaderNodeTexNoise"); n.inputs["Scale"].default_value = 60
        r = nt.nodes.new("ShaderNodeValToRGB"); r.color_ramp.elements[0].color = B.hexcol("#AE828A"); r.color_ramp.elements[1].color = B.hexcol("#C49AA0")
        nt.links.new(n.outputs["Fac"], r.inputs["Fac"]); nt.links.new(r.outputs["Color"], p.inputs["Base Color"])
        return m

def surfaces():
    from PIL import Image, ImageEnhance
    for name in ("table", "shelf", "cushion", "desk"):
        s = B.reset(); s.view_settings.look = "None"
        flat_light()
        bpy.ops.mesh.primitive_plane_add(size=4, location=(0, 0, 0)); p = bpy.context.object
        p.data.materials.append(surface_mat(name))
        top_camera(4)
        out = os.path.join(OUT, f"surface_{name}.png")
        B.render(out, 1024, 1024)
        im = Image.open(out).convert("RGB")
        # the front edge: the same material, in the shade under the table top
        e = ImageEnhance.Brightness(im.resize((1024, 128))).enhance(0.55)
        e.save(os.path.join(OUT, f"edge_{name}.png"))

def tiles():
    """Tiles seen straight down: a block sunk into a gap (its top now level with the table), and a night bridge."""
    s = B.reset(); s.render.film_transparent = True; s.view_settings.look = "None"
    flat_light()
    rbox("top", (0.96, 0.96, 0.2), (0, 0, -0.1), wood("beechT", "#D9B37C", "#C99F68", scale=2.2), bevel=0.05)
    top_camera(1.0)
    B.render(os.path.join(OUT, "prop_blockTop.png"), 256, 256)
    s = B.reset(); s.render.film_transparent = True; s.view_settings.look = "None"
    flat_light()
    m = mat("night", "#6E4FD0", rough=0.6, emit="#8B6BFF", emit_strength=1.6)
    for i in range(3):
        rbox(f"plank{i}", (0.9, 0.26, 0.05), (0, (i - 1) * 0.3, 0), m, bevel=0.03)
    top_camera(1.0)
    B.render(os.path.join(OUT, "prop_bridge.png"), 256, 256)

def main():
    os.makedirs(OUT, exist_ok=True)
    only = arg("--only", "").split(",") if "--only" in ARGS else None
    for name, build in THINGS.items():
        if only and name not in only: continue
        s = B.reset(); s.render.film_transparent = True
        B.materials(); B.sprite_lights()
        s.render.resolution_x = s.render.resolution_y = 512
        build(); camera()   # the contact shadow is drawn by the game, the same under every thing
        B.render(os.path.join(OUT, f"prop_{name}.png"), 512, 512)
    if not only or "surfaces" in only: surfaces()
    if not only or "tiles" in only: tiles()

main()
